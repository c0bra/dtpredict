
#==================================================================== -*-perl-*-
#
# DateTime::Event::Predict::Profile
#
# DESCRIPTION
#   Provides default profiles and mechanisms for creating custom profiles
#
# AUTHORS
#   Brian Hann
#
#===============================================================================

package DateTime::Event::Predict::Profile;

use Params::Validate qw(:all);
use Carp qw( croak confess );
use Data::Dumper;

our %PROFILES = (
	default => {
		buckets => [
			'day_of_week',
			'day_of_month',
			'day_of_year',
		],
	},
	holiday => {
		buckets => [
			'day_of_year'
		],
	},
	daily => {
		buckets => [
			'day_of_year'
		],
	},
);

our %BUCKETS = (
	nanosecond => DateTime::Event::Predict::Profile::Bucket->new(
		name     => 'nanosecond',
		accessor => 'nanosecond',
		duration => 'nanoseconds',
		trimmable => 1,
		order    => 1,
	),
	#microsecond => DateTime::Event::Predict::Profile::Bucket->new(
	#	name     => 'microsecond',
	#	accessor => 'microsecond',
	#	duration => 'microseconds',
	#	order    => 2,
	#),
	#millisecond => DateTime::Event::Predict::Profile::Bucket->new(
	#	name	 => 'millisecond',
	#	accessor => 'millisecond',
	#	duration => 'milliseconds',
	#	order    => 3,
	#),
    second => DateTime::Event::Predict::Profile::Bucket->new(
    	name	 => 'second',
    	accessor => 'second',
    	duration => 'seconds',
    	trimmable => 1,
    	order    => 4,
    ),
    #fractional_second => DateTime::Event::Predict::Profile::Bucket->new(
	#	accessor => 'fractional_second',
	#	order    => 5,
	#),
    minute => DateTime::Event::Predict::Profile::Bucket->new(
    	name	 => 'minute',
    	accessor => 'minute',
    	duration => 'minutes',
    	trimmable => 1,
    	order    => 6,
   	),
    hour => DateTime::Event::Predict::Profile::Bucket->new(
    	name	 => 'hour',
    	accessor => 'hour',
    	duration => 'hours',
    	trimmable => 1,
    	order    => 7,
    ),
    day_of_week => DateTime::Event::Predict::Profile::Bucket->new(
    	name	 => 'day_of_week',
    	accessor => 'day_of_week',
    	duration => 'days',
    	trimmable => 0,
    	order    => 8,
    ),
    day_of_month => DateTime::Event::Predict::Profile::Bucket->new(
    	name	 => 'day_of_month',
    	accessor => 'day',
    	duration => 'days',
    	trimmable => 1,
    	order    => 9,
    ),
    day_of_quarter => DateTime::Event::Predict::Profile::Bucket->new(
    	name	 => 'day_of_quarter',
    	accessor => 'day_of_quarter',
    	duration => 'days',
    	trimmable => 0,
    	order    => 10,
    ),
    weekday_of_month => DateTime::Event::Predict::Profile::Bucket->new(
    	name	 => 'weekday',
    	accessor => 'weekday', #Returns a number from 1..5 indicating which week day of the month this is. For example, June 9, 2003 is the second Monday of the month, and so this method returns 2 for that day.
    	duration => 'days',
    	trimmable => 0,
    	order    => 11,
    ),
    week_of_month => DateTime::Event::Predict::Profile::Bucket->new(
    	name	 => 'week_of_month',
    	accessor => 'week_of_month',
    	duration => 'weeks',
    	trimmable => 0,
    	order    => 12,
    ),
    day_of_year => DateTime::Event::Predict::Profile::Bucket->new(
    	name	 => 'day_of_year',
    	accessor => 'day_of_year',
    	duration => 'days',
    	trimmable => 0,
    	order    => 13,
    ),
    week_number => DateTime::Event::Predict::Profile::Bucket->new(
    	name	 => 'week_number',
    	accessor => 'week_number',
    	duration => 'weeks',
    	trimmable => 0,
    	order    => 14,
    ),
    month_of_year => DateTime::Event::Predict::Profile::Bucket->new(
    	name	 => 'month_of_year',
    	accessor => 'month',
    	duration => 'months',
    	trimmable => 1,
    	order    => 15,
    ),
    quarter_of_year => DateTime::Event::Predict::Profile::Bucket->new(
    	name	 => 'quarter_of_year',
    	accessor => 'quarter',
    	duration => 'quarters', #I don't think this duration exists
    	trimmable => 0,
    	order    => 16,
    ),
    year => DateTime::Event::Predict::Profile::Bucket->new(
    	name	 => 'year',
    	accessor => 'year',
    	duration => 'years', #I don't think this duration exists
    	trimmable => 0,
    	order    => 17,
    ),
);

#Aliases
$BUCKETS{'second_of_minute'} = $BUCKETS{'second'};
$BUCKETS{'minute_of_hour'}   = $BUCKETS{'minute'};
$BUCKETS{'hour_of_day'}   	 = $BUCKETS{'hour'};
$BUCKETS{'week_of_year'}   	 = $BUCKETS{'week_number'};


#===============================================================================#

sub new {
    my $proto = shift;
    my %opts  = @_;
    
    validate(@_, {
    	profile => { type => SCALAR, optional   => 1 }, #Preset profile
    	buckets => { type => ARRAYREF, optional => 1 }, #Custom bucket definitions
    });
    
    my $class = ref( $proto ) || $proto;
    
    my $self = {};
    
    $self->{buckets} = {};
    
    if ( $opts{'profile'} ) {
    	if ( exists $PROFILES{ $opts{'profile'} } ) {
    		$opts{'buckets'} = $PROFILES{ $opts{'profile'} }->{buckets};
    	}
    	else {
    		confess("Undefined profile: '" . $opts{profile} . "' provided");
    	}
    }
    elsif ( ! $opts{'buckets'} ) {
    	confess("Must specify either a profile or a custom set of buckets");
    }
    
    foreach my $bucket_name (@{ $opts{'buckets'} }) {
		my $bucket = $BUCKETS{ $bucket_name }->clone;
		
		$self->{buckets}->{ $bucket_name } = $bucket;
	}
    
    bless($self, $class);
    
    return $self;
}

sub bucket {
	my $self   = shift;
	my $bucket = shift;
	
	validate_pos(@_, { type => SCALAR, optional => 1 });
	
	if (! defined $self->{buckets}->{ $bucket } || ! $self->{buckets}->{ $bucket }) {
		return;
	}
	
	return $self->{buckets}->{ $bucket };
}

sub buckets {
	my $self    = shift;
	my @buckets = @_;
	
	my @to_return = ();
	if (@buckets) {
		@to_return = @{ $self->{buckets} }{ @buckets };
	}
	else {
		@to_return = values %{$self->{buckets}};
	}
	
	return wantarray ? @to_return : \@to_return;
}

1;

package DateTime::Event::Predict::Profile::Bucket;

use Params::Validate qw(:all);
use Carp qw( croak confess );

sub new {
    my $proto = shift;
    my %opts  = @_;
    
    %opts = validate(@_, {
    	name      => { type => SCALAR },
    	order     => { type => SCALAR }, 
    	accessor  => { type => SCALAR }, 
    	duration  => { type => SCALAR },
    	trimmable => { type => SCALAR },
    	on        => { type => SCALAR, default => 1 },
    });
    
    my $class = ref( $proto ) || $proto;
    
    #unless (exists $BUCKETS{ $opts{'name'} }) {
	#	confess("Undefined bucket: '" . $opts{'name'} . "' provided");
	#}
    
    my $self = \%opts;
    
    #$self->{bucket} = $BUCKETS{ $opts{'name'} };
	$self->{weight} = ""; #Not used yet
    
    bless($self, $class);
    
    return $self;
}

sub name {
	my $self = shift;
	
	return $self->{name};
}

sub accessor {
	my $self = shift;
	
	return $self->{accessor};
}

sub order {
	my $self = shift;
	
	return $self->{order};
}

sub duration {
	my $self = shift;
	
	return $self->{duration};
}

sub trimmable {
	my $self = shift;
	
	return $self->{trimmable};
}

sub weight {
	my $self = shift;
	
	return $self->{weight};
}

#Get or set whether this bucket is on or not
sub on {
	my $self = shift;
	my ($on) = @_;
	
	if (defined $on) {
		$self->{on} = ($on) ? 1 : 0;
	}
	else {
		return ($self->{on}) ? 1 : 0;
	}
}

#Reverse of on()
sub off {
	my $self = shift;
	my ($off) = @_;
	
	if (defined $off) {
		$self->{on} = ($off) ? 0 : 1;
	}
	else {
		return ($self->{on}) ? 0 : 1;
	}
}

sub clone { bless { %{ $_[0] } }, ref $_[0] }

1;

__END__

=pod

=head1 NAME

DateTime::Event::Predict::Profile - Provides default profiles for use with DateTime::Event::Predict,
and mechanisms for making custom profiles

=head1 SYNOPSIS

	use DateTime::Event::Predict::Profile;

	my $profile = new DateTime::Event::Predict::Profile(
		buckets => [qw/ day_of_month /],
	);

	$profile->bucket('day_of_month')->off(1);

=head1 AUTHOR

Brian Hann, C<< <brian.hann at gmail.com> >>

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
