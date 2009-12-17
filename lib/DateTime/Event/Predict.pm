
#==================================================================== -*-perl-*-
#
# DateTime::Event::Predict
#
# DESCRIPTION
#   Predict new dates from a set of dates
#
# AUTHORS
#   Brian Hann
#
#===============================================================================

package DateTime::Event::Predict;

use strict;

use 5.006;

use Carp qw(carp croak confess);
use DateTime;
use Params::Validate qw(:all);
use Scalar::Util;

use POSIX qw(ceil);
use Data::Dumper;
#use Smart::Comments;

use DateTime::Event::Predict::Profile;

our $VERSION = '0.01';                                                                                     


#===============================================================================#

sub new {
    my $proto = shift;
    my %opts  = @_;
    
    validate(@_, {
    	dates   => { type => ARRAYREF, optional => 1 },
    	profile => { type => SCALAR | OBJECT, optional => 1 },
    });
    
    my $class = ref( $proto ) || $proto;
    my $self = { #Will need to allow for params passed to constructor
    	dates   		 => [],
    	distinct_buckets => {},
    	interval_buckets => {},
    	total_epoch_interval    => 0,
    	largest_epoch_interval  => 0,
    	smallest_epoch_interval => 0,
    	mean_epoc_interval      => 0,
    	
    	#Whether this data set has been trained or not
    	trained => 0,
    };
    bless($self, $class);
    
    $opts{profile} = 'default' if ! $opts{profile};
    
    $self->profile( $opts{profile} );
    
    return $self;
}

#Get or set list of dates ***NOTE: Should make this validate for 'can' on the DateTime methods we need and on 'isa' for DateTime
sub dates {
	my $self   = shift;
	my ($dates) = @_;
	
	validate_pos(@_, { type => ARRAYREF, optional => 1 });
	
	if (! defined $dates) { return $self->{dates}; }
	elsif (defined $dates) {
		foreach my $date (@$dates) {
			$self->add_date($date);
		}
	}
	
	return 1;
}

#Add a date to the list of dates
sub add_date {
	my $self   = shift;
	my ($date) = @_;
	
	validate_pos(@_, { isa => 'DateTime' }); #***Or we could attempt to parse the date, or use can( epoch() );
	
	push(@{ $self->{dates} }, $date);
	
	return 1;
}

#Get or set the profile for this predictor
sub profile {
	my $self      = shift;
	my ($profile) = @_; #$profile can be a string specifying a profile name that is provided by default, or a profile object
	
	validate_pos(@_, { type => SCALAR | OBJECT, optional => 1 });
	
	#Get the profile
	if (! defined $profile || ! $profile) { return $self->{profile}; }
	
	#Validate & set the profile
	
	my $new_profile;
	
	if (Scalar::Util::blessed($profile) && $profile->can('bucket')) {
		$new_profile = $profile;
	}
	else {
		$new_profile = DateTime::Event::Predict::Profile->new( profile => $profile );
	}
	
	#Add the buckets
    foreach my $bucket ( $new_profile->buckets() ) {
    	$self->{distinct_buckets}->{ $bucket->name } = {
    		accessor => $bucket->accessor,
    		duration => $bucket->duration,
    		weight   => $bucket->weight,
    		buckets  => {},
    	};
    }
	
	$self->{profile} = $new_profile;
	
	return 1;
}

sub train {
	my $self = shift;
	#***Add optional dates array param to predict from here, plus other config params?
	
	#warn Dumper($self);
	
	### Training
	
	#Sort the dates chronologically (*** Really? Do we want the user to impose the order?)
	my $cur_date;
	#foreach my $date (sort { $b->hires_epoch() <=> $a->hires_epoch() } @{ $self->{dates} }) {
	my @dates = sort { $a->hires_epoch() <=> $b->hires_epoch() } @{ $self->{dates} }; #*** Need to convert this to DateTime->compare($dt1, $dt2)
	$self->{last_date} = $dates[$#dates];
	$self->{first_date} = $dates[0];
	foreach my $index (0 .. $#{ $self->{dates} }) {
		my $date = $dates[ $index ];
		my ($before, $after);
		if ($index > 0) { $before = $dates[ $index - 1 ]; }
		if ($index < $#{ $self->{dates} }) { $after = $dates[ $index + 1 ]; }
		
		#Increment the distinct point buckets
		while (my ($name, $dbucket) = each %{ $self->{distinct_buckets} }) {
			my $cref = $date->can( $dbucket->{accessor} );
				croak "Can't call accessor '" . $dbucket->{accessor} . "' on " . ref($date) . " object" unless $cref;
			$dbucket->{buckets}->{ &$cref($date) }++;
		}
		
		#If this is the first date we have nothing to diff, so we'll skip on to the next one
		if (! $cur_date) { $cur_date = $date; next; }
		
		my $dur = $cur_date->subtract_datetime( $date ); #Get DateTime::Duration object representing the diff between the dates
		
		##Increment the interval buckets
		#Intervals: here we default to the largest interval that we can see. So, for instance, if there is a difference of months we will not increment anything smaller than that.
		while (my ($name, $lbucket) = each %{ $self->{interval_buckets} }) {
			my $cref = $dur->can( $lbucket->{accessor} );
				croak "Can't call accessor '" . $lbucket->{accessor} . "' on " . ref($dur) . " object" unless $cref;
			my $interval = &$cref($dur);
			#if ($interval) { $lbucket->{buckets}->{ $interval }++; }
			$lbucket->{buckets}->{ $interval }++;
		}
		
		#Add the epoch difference for poisson probabilities
		my $epoch_interval = $date->hires_epoch() - $cur_date->hires_epoch();
		$self->{total_epoch_interval} += $epoch_interval;
		
		$cur_date = $date;
	}
	
	#Average interval between dates in epoch seconds
	$self->{mean_epoch_interval} = $self->{total_epoch_interval} / (scalar @dates);
	
	$self->{trained}++;
}

sub predict {
	my $self = shift;
	my %opts = @_;
	
	validate(@_, {
		max_predictions => { type => SCALAR, optional => 1 }, #How many predictions to return
		hooks => { type => ARRAYREF, optional => 1 },
	});
	
	#Train this set of dates if they're not already trained
	unless ($self->_is_trained) { $self->train(); $self->{trained}++; }
	
	### Beginning prediction
	
	#Make a copy of the buckets so we can mess with them
	my %buckets = %{ $self->{distinct_buckets} };
	
	#Figure the mean, variance, and standard deviation for each bucket
	foreach my $bucket (values %buckets) {
		my ($mean, $variance, $stdev) = $self->_bucket_statistics($bucket);
		
		$bucket->{mean}     = $mean;
		$bucket->{variance} = $variance;
		$bucket->{stdev}    = $stdev;
	}
	
	my $most_recent_date = (sort { $b->hires_epoch() <=> $a->hires_epoch() } @{ $self->{dates} })[0];
	
	### Make a starting search date that has been moved ahead by the average interval beteween dates (in epoch seconds)
	my $duration = new DateTime::Duration(
		seconds => $self->{mean_epoch_interval}, #Might need to round off hires second info here?
	);
	my $start_date = $most_recent_date + $duration;
	
	#Limit the number of standard deviations to look through
	my $stdev_limit = 2;
	
	#A hash of predictions, dates are keyed by their hires_epoch() value
	my %predictions = ();
	
	### #Get a list of buckets after sorting the buckets from largest interval to smallest (i.e. year->month->day->hour ... microsecond, etc)
	my @bucket_keys = (sort { $self->{distinct_buckets}->{ $b }->{order} cmp $self->{distinct_buckets}->{ $a }->{order} } keys %buckets)[0];
	#Get the first bucket name 
	my $first_bucket_name = shift @bucket_keys;
	
	### Start recursively descending down into the various date parts, searching in each one
	$self->_date_descend($start_date, $first_bucket_name, \%buckets, \@bucket_keys, $stdev_limit, \%predictions, $opts{'max_predictions'});
	
	#Sort the predictions by their total deviation
	my @predictions = sort { $a->{_date_deviation} <=> $b->{_date_deviation} } values %predictions;
	
	if ( $opts{'max_predictions'} ) {
		#@predictions = @predictions[0 .. $opts{'max_predictions'}];
	}
	
	return wantarray ? @predictions : $predictions[0];
}

#Descend down into the date parts
sub _date_descend {
	my $self = shift;
	my ($date, $bucket_name, $buckets, $bucket_keys, $stdev_limit, $predictions, $max_predictions) = @_;
	
	return if (scalar keys %$predictions) >= $max_predictions;
	
	### Operating on bucket: $bucket_name
	
	### Starting at: $date->mdy('/') . ' ' . $date->hms
	
	#Get the actual bucket for this bucket name
	my $bucket = $buckets->{ $bucket_name };
	
	my $search_range = ceil( $bucket->{stdev} * $stdev_limit );
	
	### Search range: $search_range
	
	#The next bucket to search down into
	my $next_bucket_name = "";
	if (scalar @$bucket_keys > 0) {
		$next_bucket_name = shift @$bucket_keys;
	}
	
	foreach my $search_inc ( 0 .. $search_range ) {
		# Make an inverted search increment
		my $neg_search_inc = $search_inc * -1;
		
		# Search forwards and backwards
		foreach my $increment ($search_inc, $neg_search_inc) {
			return if (scalar keys %$predictions) >= $max_predictions;
			
			#Make a duration object using the accessor for this bucket
			my $duration_increment = new DateTime::Duration( $bucket->{duration} => $increment );
			
			#Get the new date
			my $new_date = $date + $duration_increment;
			
			### Checking forward new date: $new_date->mdy('/') . ' ' . $new_date->hms
			
			#If we have no more buckets to search into, determine if this date is a good prediction
			# by going through each bucket and comparing this date's deviation from that bucket's mean.
			# If it is within the standard deviation for each bucket then consider it a good match
			if (! $next_bucket_name) {
				my $good = 1;
				my $date_deviation = 0;
				foreach my $bucket (values %$buckets) {
					### Checking bucket: $bucket->{accessor}
					
					#Get the value for this bucket's access for the $new_date
					my $cref = $new_date->can( $bucket->{accessor} );
					my $datepart_val = &$cref($new_date);
					
					#If the deviation of this datepart from the mean is within the standard deviation, 
					# this date ain't good.
					
					my $deviation = abs($datepart_val - $bucket->{mean});
					$date_deviation += $deviation;
					
					if ($deviation > $bucket->{stdev} )  {
						### Outside of stdev: $bucket->{stdev}
						### Outside by: abs($datepart_val - $bucket->{mean})
						$good = 0;
					}
				}
				
				#All the dateparts were within their standard deviations, check for hooks and push this date into the set of predictions
				if ($good == 1) {
					### Found prediction: $new_date->mdy('/')
					
					$new_date->{_date_deviation} = $date_deviation;
					$predictions->{ $new_date->hires_epoch() } = $new_date;
				}
			}
			#If we're not at the smallest bucket, keep searching!
			else {
				$self->_date_descend($new_date, $next_bucket_name, $buckets, $bucket_keys, $stdev_limit, $predictions, $max_predictions);
			}
		}
	}
	
	return 1;
}

sub _search_increment {
	my $self        = shift;
	my $increment   = shift; #Increment to search by
	my $bucket      = shift; #Bucket to search in
	my $buckets     = shift; #A list of all buckets, in case we get a match
	my $predictions = shift; #The predictions arrayref, in case we get a match
	
	
}

#Get the mean, variance, and standard deviation for a bucket
sub _bucket_statistics {
	my $self   = shift;
	my $bucket = shift;
	
	my $total = 0;
	my $count = 0;
	while (my ($value, $occurances) = each %{ $bucket->{buckets} }) {
		#Gotta loop for each time the value has been found
		for (1 .. $occurances) {
			$total += $value;
			$count++;
		}
	}
	
	my $mean = $total / $count;
	
	#Get the variance
	my $total_variance = 0;
	while (my ($value, $occurances) = each %{ $bucket->{buckets} }) {
		#Gotta loop for each time the value has been found
		my $this_variance = ($value - $mean) ** 2;
		
		$total_variance += $this_variance * $occurances;
	}
	
	my $variance = $total_variance / $count;
	my $stdev = sqrt($variance);
	
	return ($mean, $variance, $stdev);
}

sub _is_trained {
	my $self = shift;
	
	return ($self->{trained} > 0) ? 1 : 0;
}  

sub _print_dates {
	my $self = shift;
	
	foreach my $date (sort { $a->hires_epoch() <=> $b->hires_epoch() } @{ $self->{dates} }) {
		print $date->mdy('/') . ' ' . $date->hms . "\n";
	}
} 
    
1; # End of DateTime::Event::Predict
    
__END__
    
=pod
    
=head1 NAME

DateTime::Event::Predict - Predict new dates from a set of dates

=head1 SYNOPSIS

Given a set of dates this module will predict the next date or dates to follow.

Perhaps a little code snippet.

    use DateTime::Event::Predict;

    my $dtp = DateTime::Event::Predict->new();
    
    my $date = new DateTime->today();
    
    $dtp->add_date($date);
    
    $dtp->predict;

=head1 METHODS

=head2 new

Constructor

	my $dtp = DateTime::Event::Predict->new();

=head2 dates

Arguments: none | \@dates

Return value: \@dates

Called with no argument this method will return an arrayref to the list of the dates currently in the instance.

Called with an arrayref to a list of L<DateTime|DateTime> objects (C<\@dates>) this method will set the dates for this instance to C<\@dates>.

=head2 add_date

Arguments: $date

Return value: 

Adds a date on to the list of dates in the instance, where C<$date> is a L<DateTime|DateTime> object.

=head2 profile

Arguments: $profile

Set the profile for which date-parts will be 
	
	
	$dtp->profile($profile);

=head2 predict

Predict the next date from the dates in this instance

	my $next_date = $dtp->predict();
	
	
=head1 TODO

=over

=item *

It would be be cool if you could pass your own buckets in with a certain type, so you could, say, look for recurrence based
on intervals of 6 seconds, or 18 days, whatever.

=item *

We need to be able to handle recording more than one interval per diff. If the dates are all offset from each other by 1 day 6 hours (May 1, 3:00; May 2, 6:00),
we can't be predicting a new date that's exactly 1 day after the most recent one.
  ^ The best way to do this is probably to record intervals as epoch seconds, so everything is taken into account. Maybe record epoch seconds in addition
    to whole regular intervals like days & hours.

=back
 
=head1 AUTHOR

Brian Hann, C<< <brian.hann+dtp at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-datetime-event-predict at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=DateTime-Event-Predict>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc DateTime::Event::Predict


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=DateTime-Event-Predict>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/DateTime-Event-Predict>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/DateTime-Event-Predict>

=item * Search CPAN

L<http://search.cpan.org/dist/DateTime-Event-Predict/>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Brian Hann, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
