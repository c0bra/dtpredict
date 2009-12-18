
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
    
    my %opts = validate(@_, {
    	dates       => { type => ARRAYREF,        optional => 1 },
    	profile     => { type => SCALAR | OBJECT, optional => 1 },
    	#stdev_limit => { type => SCALAR,          default  => 2 },
    });
    
    my $class = ref( $proto ) || $proto;
    my $self = { #Will need to allow for params passed to constructor
    	dates   		 => [],
    	distinct_buckets => {},
    	interval_buckets => {},
    	total_epoch_interval    => 0,
    	largest_epoch_interval  => 0,
    	smallest_epoch_interval => 0,
    	mean_epoch_interval     => 0,
    	
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
			$self->_trim_dates( $date );
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
	
	$self->_trim_dates( $date );
	
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
    		order    => $bucket->order,
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
	
	my %opts = validate(@_, {
		max_predictions => { type => SCALAR,   optional => 1 }, # How many predictions to return
		stdev_limit     => { type => SCALAR,   default  => 2 }, # Number of standard deviations to search through
		callbacks       => { type => ARRAYREF, optional => 1 }, # Arrayref of coderefs to call when making predictions
	});
	
	# Force max predictions to one if we were called in scalar context
	if (! defined $opts{'max_predictions'}) {
		$opts{'max_predictions'} = 1 if ! wantarray;
	}
	
	# Train this set of dates if they're not already trained
	unless ($self->_is_trained) { $self->train(); $self->{trained}++; }
	
	### Beginning prediction
	
	# Make a copy of the buckets so we can mess with them
	my %buckets = %{ $self->{distinct_buckets} };
	
	# Figure the mean, variance, and standard deviation for each bucket
	foreach my $bucket (values %buckets) {
		my ($mean, $variance, $stdev) = $self->_bucket_statistics($bucket);
		
		$bucket->{mean}     = $mean;
		$bucket->{variance} = $variance;
		$bucket->{stdev}    = $stdev;
	}
	
	# Get the most recent of the provided dates by sorting them by their epoch seconds
	my $most_recent_date = (sort { $b->hires_epoch() <=> $a->hires_epoch() } @{ $self->{dates} })[0];
	
	### Most recent date: $most_recent_date->ymd
	
	### Make a starting search date that has been moved ahead by the average interval beteween dates (in epoch seconds)
	my $duration = new DateTime::Duration(
		seconds => $self->{mean_epoch_interval}, #Might need to round off hires second info here?
	);
	my $start_date = $most_recent_date + $duration;
	
	### Starting search at: $start_date->ymd
	
	# A hash of predictions, dates are keyed by their hires_epoch() value
	my %predictions = ();
	
	### Get a list of buckets after sorting the buckets from largest interval to smallest (i.e. year->month->day->hour ... microsecond, etc)
	my @bucket_keys = sort { $self->{distinct_buckets}->{ $b }->{order} <=> $self->{distinct_buckets}->{ $a }->{order} } keys %buckets;
	
	# Get the first bucket name 
	my $first_bucket_name = shift @bucket_keys;
	
	### Start recursively descending down into the various date parts, searching in each one
	$self->_date_descend(
		%opts,
		
		date        	 => $start_date,
		most_recent_date => $most_recent_date,
		bucket_name 	 => $first_bucket_name,
		buckets     	 => \%buckets,
		bucket_keys 	 => \@bucket_keys,
		predictions 	 => \%predictions,
	);
	
	#Sort the predictions by their total deviation
	my @predictions = sort { $a->{_date_deviation} <=> $b->{_date_deviation} } values %predictions;
	
	return wantarray ? @predictions : $predictions[0];
}

# Descend down into the date parts, looking for predictions
sub _date_descend {
	my $self = shift;
	#my %opts = @_;
	
	# Validate the options
	my %opts = validate(@_, {
		date        	 => { isa => 'DateTime' },				 # The date to start searching in
		most_recent_date => { isa => 'DateTime' },               # The most recent date of the dates provided
		bucket_name 	 => { type => SCALAR },					 # The bucket (date-part) to start searching in
		buckets     	 => { type => HASHREF },				 # A hashref of all buckets to use when looking for good predictions
		bucket_keys 	 => { type => ARRAYREF },				 # A list of bucket names that we shift out of to get the next bucket to use
		stdev_limit 	 => { type => SCALAR },					 # The limit of how many standard deviations to search through
		predictions 	 => { type => HASHREF },				 # A hashref of predictions we find
		max_predictions  => { type => SCALAR,   optional => 1 }, # The maxmimum number of predictions to return (prevents overly long searches)
		callbacks 	     => { type => ARRAYREF, optional => 1 }, # A list of custom coderefs that are called on each possible prediction
	});	
	
	# Copy the options over into simple scalars so it's easier on my eyes
	my $date 			= delete $opts{'date'};        # Delete these ones out as we'll be overwriting them below
	my $bucket_name 	= delete $opts{'bucket_name'};
	my $buckets 		= $opts{'buckets'};
	my $bucket_keys 	= $opts{'bucket_keys'};
	my $stdev_limit 	= $opts{'stdev_limit'};
	my $predictions 	= $opts{'predictions'};
	my $max_predictions = $opts{'max_predictions'};
	my $callbacks       = $opts{'callbacks'};
	
	# We've reached our max number of predictions, return
	return 1 if defined $max_predictions && (scalar keys %$predictions) >= $max_predictions;
	
	# Get the actual bucket hash for this bucket name
	my $bucket = $buckets->{ $bucket_name };
	
	# The search range is the standard deviation multiplied by the number of standard deviations to search through
	my $search_range = ceil( $bucket->{stdev} * $stdev_limit );
	
	### Searching bucket: $bucket_name
	### Search range: $search_range
	
	#The next bucket to search down into
	my $next_bucket_name = "";
	if (scalar @$bucket_keys > 0) {
		$next_bucket_name = shift @$bucket_keys;
	}
	
	### Next bucket: $next_bucket_name
	
	foreach my $search_inc ( 0 .. $search_range ) {
		# Make an inverted search increment so we can search backwards
		my $neg_search_inc = $search_inc * -1;
		
		# Put forwards and backwards in the searches
		my @searches = ($search_inc, $neg_search_inc);
		
		# Make sure we only search on 0 once (i.e. 0 * -1 == 0)
		@searches = (0) if $search_inc == 0;
		
		foreach my $increment (@searches) {
			### Searching increment: $increment
			
			# We've reached our max number of predictions, return
			return 1 if defined $max_predictions && (scalar keys %$predictions) >= $max_predictions;
			
			# Make a duration object using the accessor for this bucket
			my $duration_increment = new DateTime::Duration( $bucket->{duration} => $increment );
			
			# Get the new date
			my $new_date = $date + $duration_increment;
			$self->_trim_date( $new_date );
			
			# Skip this date if it's before the most recent date
			if (DateTime->compare( $new_date, $opts{'most_recent_date'} ) <= 0) { # New date is before the most recent one, or is same as most recent one
				next;
			}
			
			### Checking new date: $new_date->ymd
			
			# If we have no more buckets to search into, determine if this date is a good prediction
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
						last;
					}
					else {
						### Inside stdev: $bucket->{stdev}
						### Inside by: abs($datepart_val - $bucket->{mean})
					}
				}
				
				#All the dateparts were within their standard deviations, check for callbacks and push this date into the set of predictions
				if ($good == 1) {
					### Found good date: $new_date->ymd
					$new_date->{_date_deviation} = $date_deviation;
					
					# Run each hook we were passed
					foreach my $callback (@$callbacks) {
						# If any hook returns false, this date is a no-go and we can stop processing it
						if (! &$callback($new_date)) {
							$good = 0;
							last;
						}
					}
					
					# If the date is still considered good, put it date into the hash of predictions
					if ($good == 1) {
						$predictions->{ $new_date->hires_epoch() } = $new_date;
					}
				}
			}
			#If we're not at the smallest bucket, keep searching!
			else {
				$self->_date_descend(
					%opts,
					date        => $new_date,
					bucket_name => $next_bucket_name,
				);
			}
		}
	}
	
	return 1;
}

# Get the mean, variance, and standard deviation for a bucket
sub _bucket_statistics {
	my $self   = shift;
	my $bucket = shift;
	
	my $total = 0;
	my $count = 0;
	while (my ($value, $occurances) = each %{ $bucket->{buckets} }) {
		# Gotta loop for each time the value has been found
		for (1 .. $occurances) {
			$total += $value;
			$count++;
		}
	}
	
	my $mean = $total / $count;
	
	# Get the variance
	my $total_variance = 0;
	while (my ($value, $occurances) = each %{ $bucket->{buckets} }) {
		# Gotta loop for each time the value has been found
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

# Trim the date parts that are smaller than the smallest one we care about. If we only care about
# the year, month, and day, and during the initial search create an offset date that has an hour
# or minute that is off from the most recent given date, then when we do a comparison to see if
# we're predicting a date we've already been given it's possible that we could have that same
# date, just with the hour and second set forward a bit.
sub _trim_dates {
	my $self    = shift;
	my (@dates) = @_;
	
	# Get the smallest bucket we have turned on
	my @buckets = (sort { $a->order <=> $b->order } grep { $_->on && $_->trimmable } $self->profile->buckets)[0];
	my $smallest_bucket = @buckets[0];
	
	return if ! defined $smallest_bucket || ! $smallest_bucket || ! @buckets;
	
	foreach my $date (@dates) {
		confess "Can't trim a non-DateTime value" unless $date->isa( 'DateTime' );
		
		foreach my $bucket (grep { $_->trimmable && ($_->order < $smallest_bucket->order) } values %DateTime::Event::Predict::Profile::BUCKETS) {
			$date->set( $bucket->accessor => 0 );
		}
	}
}
sub _trim_date { return &_trim_dates(@_); }
    
1; # End of DateTime::Event::Predict
    
__END__
    
=pod
    
=head1 NAME

DateTime::Event::Predict - Predict new dates from a set of dates

=head1 SYNOPSIS

Given a set of dates this module will predict the next date or dates to follow.

  use DateTime::Event::Predict;

  my $dtp = DateTime::Event::Predict->new();

  # Add todays date: 2009-12-17
  my $date = new DateTime->today();
  $dtp->add_date($date);

  # Add the previous 5 days
  for  (1 .. 5) {
      my $new_date = $date->clone->add(
          days => ($_ * -1),
      );

      $dtp->add_date($new_date);
  }

  #Predict the next date
  my $predicted_date = $dtp->predict;

  print $predicted_date->ymd;

  # 2009-12-18
  
Here we create a new C<DateTime> object with today's date (it being December 17th, 2009 currently). We
then add that on the list of dates that C<DateTime::Event::Predict> will use to make the prediction.

We also tack on the 5 previous days (December 16-11). Afterwards, we call L<predict>
  
=head1 EXAMPLES

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

  # Pass in preset profile by name
  $dtp->profile( profile => 'default' );
  $dtp->profile( profile => 'holiday' );

  # Create a new profile
  my $profile = new DateTime::Event::Predict::Profile(
      buckets => [qw/ minute hour day_of_week day_of_month /],
  );

  $dtp->profile( profile => $profile );

=head3 Provided profiles

The following profiles are provided for use by-name:

=head2 predict

Arguments: %options

Return Value: $next_date | @next_dates

Predict the next date(s) from the dates supplied.

  my $predicted_date = $dtp->predict();
  
If list context C<predict> returns a list of all the predictions, sorted by their probability:

  my @predicted_dates = $dtp->predict();
  
The number of prediction can be limited with the C<max_predictions> option.
	
Possible options

  $dtp->predict(
      max_predictions => 4, # Once 4 predictions are found, return back
      callbacks => [
          sub { return ($_->second % 4) ? 0 : 1 } # Only predict dates with second values that are divisible by four.
      ],
  );

=item max_predictions

Maximum number of predictions to find.

=item callbacks

Arrayref of subroutine callbacks. If any of them return a false value the date will not be returned as a prediction.

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
