
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

use warnings;
use strict;

#use 5.006; #*Need this?

use Carp qw(carp croak);
use DateTime;
#use Params::Check;
use Params::Validate qw(:all);

use Math::Counting;
use Math::Round qw(round);

use Data::Dumper;

our $VERSION = '0.01';

use constant e => 2.71828182845905; #Euler's number

#Define period types
our %periods = (
	# Something here for milliseconds with Time::HiRes?
	second => 1,
	minute => 60,
	hour   => 60 * 60,
	day    => 24 * 60 * 60,
	week   => 7 * 24 * 60 * 60,
	month  => 30 * 24 * 60 * 60, #***WTF to do here?
	year   => 365 * 24 * 60 * 60, #***Also WTF to do here? Minimum value maybe? (365 for year, 28 for month? Or 30?)
);

#***We'll also need to define if buckets interfere with each other, like if there's a difference in quarters between dates, does that mean
#   we don't check for a difference between months?
#Distinct point-in-time buckets
our %distinct_buckets = (	
    second_of_minute => {
    	accessor => 'second', #DateTime accessor method for this bucket
    	on		 => 0,        #Whether this bucket is on by default
    	weight   => 0,        #The influence this bucket has on results,
    	buckets  => { map { $_ => 0 } (0 .. 66) }, #Possible values that can be incremented in the bucket (Leap seconds!)
    	#*** Need to define precendence or weights here (OR ELSEWHERE!), as well as whether each bucket is turned on by default #* leap seconds
    },
    minute_of_hour => {
    	accessor => 'minute',
    	on   	 => 0,
    	weight   => 0,
    	buckets  => { map { $_ => 0 } (0 .. 59) },
   	},
    hour_of_day => {
    	accessor => 'hour',
    	on   	 => 0,
    	weight   => 1,
    	buckets  => { map { $_ => 0 } (0 .. 23) },
    },
    day_of_week      => {
    	accessor => 'day_of_week',
    	on       => 1,
    	weight   => 1,
    	buckets  => { map { $_ => 0 } (1 .. 7) }, #Monday is first day of week #check local_day_of_week() 
    },
    day_of_month => {
    	accessor => 'day',
    	on       => 1,
    	weight   => 1,
    	buckets  => { map { $_ => 0 } (1 .. 31) }, #**How do we handle different month end days? (there is a last_day_of_month or something accessor in DT)
    },
    day_of_quarter => {
    	accessor => 'day_of_quarter',
    	on       => 0,
    	weight   => 1,
    	buckets  => { map { $_ => 0 } (1 .. 91) }, #**How do we handle different month end days? (there is a last_day_of_month or something accessor in DT)
    },
    weekday_of_month => {
    	accessor => 'weekday_of_month', #Returns a number from 1..5 indicating which week day of the month this is. For example, June 9, 2003 is the second Monday of the month, and so this method returns 2 for that day.
    	on       => 0,
    	weight   => 1,
    	buckets  => { map { $_ => 0 } (1 .. 5) }, #**How do we handle different month end days? (there is a last_day_of_month or something accessor in DT)
    },
    week_of_month => {
    	accessor => 'week_of_month',
    	on       => 0,
    	weight   => 0,
    	buckets  => { map { $_ => 0 } (0 .. 5) },
    },	
    day_of_year => {
    	accessor => 'day_of_year',
    	on       => 1,
    	weight   => 0,
    	buckets  => { map { $_ => 0 } (1 .. 366) }, #**How do we handle leap years?
    },
    month_of_year => {
    	accessor => 'month',
    	on       => 0,
    	weight   => 0,
    	buckets  => { map { $_ => 0 } (1 .. 12) },
    },
    quarter_of_year => {
    	accessor => 'quarter',
    	on       => 0,
    	weight   => 0,
    	buckets  => { map { $_ => 0 } (1 .. 4) },
    },
    
    #Maybe define special buckets here? For "last_day_of_month" or "last_day_of_year", etc?
    #day_of_quarter?
    #Year of century?
    #Century of millenia?
);


#***We'll need an order of precedence here, so that when we find a difference in months we don't increment any of the differences smaller
#   than that (weeks, days). *OR do we want to increment the difference but leave the weight so small that it has a smaller effect? I can't see why that
#   would be useful
#Interval buckets
our %interval_buckets = (
	nanoseconds => {
		accessor   => 'nanoseconds', #Accessor in the DateTime::Duration object that we use to get the difference value
    	on         => 0,             #Whether or not this bucket is used by default
    	weight     => 0,             #Weight of this bucket's influence on prediction
    	order      => 0,             #Order of precedence of this bucket (larger means it takes precedence)
	},
    seconds => {
    	accessor   => 'seconds',
    	on         => 1,
    	weight     => 0,
    	order      => 1,
    },
    minutes => {
    	accessor   => 'minutes',
    	on         => 1,
    	weight     => 0,
    	order      => 2,
    },
    hours => {
    	accessor   => 'hours',
    	on         => 1,
    	weight     => 0,
    	order      => 3,
    },
    days => {
    	accessor   => 'days',
    	on         => 1,
    	weight     => 0,
    	order      => 4,
    },
    weeks => {
    	accessor   => 'weeks',
    	on         => 1,
    	weight     => 0,
    	order      => 5,
    },
    months => {
    	accessor   => 'months',
    	on         => 1,
    	weight     => 0,
    	order      => 6,
    },
    years => {
    	accessor   => 'years',
    	on         => 1,
    	weight     => 0,
    	order      => 7,
    },
);

our @distinct_bucket_accessors = map { $_->{accessor} } values %distinct_buckets; #Make a list of all the accessors so we can check for can() on each DateTime passed to us (***we'll only want to check accessors for buckets that have been turned on)
our @interval_bucket_accessors = map { $_->{accessor} } values %interval_buckets;                                                                                          

our $default_profile = {
	proximity => 1,
};

################################################################################

sub new {
    my $proto = shift;
    my %opts  = @_;
    
    validate(@_, {
    	dates   => { type => ARRAYREF, optional => 1 },
    	profile => { type => SCALAR,   optional => 1 },
    });
    
    my $class = ref( $proto ) || $proto;
    my $self = { #Will need to allow for params passed to constructor
    	dates   		 => [],
    	distinct_buckets => {},
    	interval_buckets => {},
    	epoch_intervals  => [],
    	total_epoch      => 0,
    	largest_epoch_interval  => 0,
    	smallest_epoch_interval => 0,
    	
    	#Whether this data set has been trained or not
    	trained => 0,
    };
    bless($self, $class);
    
    #Add the buckets
    while (my ($name, $bucket) = each %distinct_buckets) {
    	next unless $bucket->{on}; #Skip buckets that are turned off
    	$self->{distinct_buckets}->{ $name } = {
    		accessor => $bucket->{accessor},
    		weight   => $bucket->{weight},
    		buckets  => $bucket->{buckets},
    	};
    }
    
    while (my ($name, $bucket) = each %interval_buckets) {
    	next unless $bucket->{on}; #Skip buckets that are turned off
    	$self->{interval_buckets}->{ $name } = {
    		accessor => $bucket->{accessor},
    		weight   => $bucket->{weight},
    		buckets  => {},
    	};
    }
    
    $self->{profile} = $default_profile;
    
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
	
	validate_pos(@_, { isa => 'DateTime' }); #Or we could attempt to parse the date, or use can( epoch() );
	
	push(@{ $self->{dates} }, $date);
	
	return 1;
}

#Get or set the profile for this predictor
sub profile {
	
}

#sub predict {
sub train { #*** Maybe predict() should be train(), that is, have the training part that discovers intervals separate from the prediction method. This would let us do different types of predictions on the same training model
	my $self = shift;
	#***Add optional dates array param to predict from here, plus other config params?
	
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
		push(@{ $self->{epoch_intervals} }, $epoch_interval);
		$self->{total_epoch} += $epoch_interval;
		
		$cur_date = $date;
	}
	
	$self->{trained}++;
}

#Run through a set of poisson probabilities for the dates
sub poisson_predict_epoch {
	my $self = shift;
	
	#warn Dumper($self->{epoch_intervals}); exit;
	
	unless ($self->is_trained) { $self->train(); $self->{trained}++; }
	
	my $interval_count = scalar( @{ $self->{epoch_intervals} } );
	
	my $avg_diff = ($self->{total_epoch} / $interval_count);
	
	#Get the standard deviation of the epoch intervals
	my $total_deviation;
	foreach my $diff (@{ $self->{epoch_intervals} }) {
		my $dev = $diff - $avg_diff;
		$total_deviation += $dev ** 2;
	}
	my $standard_deviation = sqrt( $total_deviation / ($interval_count - 1) );
	
	print "Calculating poisson probabilities\n" if $ENV{'DEBUG'};
	
	my $x = $avg_diff;
	my $tot = 0;
	#foreach my $n ( 0 .. round($avg_diff) * 5  ) {
	foreach my $n ( @{$self->{epoch_intervals}} ) {
	        my $pn = ((e ** -$x) * ($x ** $n)) / factorial($n);
	        #my $pn = e ** -$x;
	        $tot += $pn; # if $n >= 13;
	        print "P($n): " . $pn . "\n";
	}
};

sub poisson_predict_days {
	my $self = shift;
	
	#warn Dumper($self->{epoch_intervals}); exit;
	
	unless ($self->is_trained) { $self->train(); $self->{trained}++; }
	
	my %buckets = %{ $self->{interval_buckets}->{days}->{buckets} };
	
	#Inflate the buckets, right now they're counters on each interval
	my @intervals = ();
	my %keyed_intervals = ();
	my $total_interval = 0;
	while (my ($interval, $count) = each %buckets) {
		next unless $count > 0;
		$keyed_intervals{ $interval } = 1;
		print "Pushing $interval: ";
		for (1 .. $count) {
			print "$_ ";
			push(@intervals, $interval);
			$total_interval += $interval;
		}
		print "\n";
	}
	
	#warn Dumper(\%keyed_intervals); exit;
	print "Total interval: $total_interval\n";
	print "Intervals: " . scalar(@intervals) . "\n";
	my $avg_diff = ($total_interval / scalar(@intervals));
	
	print "Average difference: $avg_diff\n" if $ENV{'DEBUG'};
	
	#Get the standard deviation of the day intervals
	my $total_deviation = 0;
	foreach my $interval (@intervals) {
		my $dev = $interval - $avg_diff;
		$total_deviation += $dev ** 2;
	}
	my $standard_deviation = sqrt( $total_deviation / scalar(@intervals));
	
	print "Total deviation: $total_deviation\n" if $ENV{'DEBUG'};
	print "Standard deviation: $standard_deviation\n" if $ENV{'DEBUG'};
	print "Calculating poisson probabilities\n" if $ENV{'DEBUG'};
	
	my $x = $avg_diff;
	#my $tot = 0;
	#foreach my $n ( 0 .. round($avg_diff) * 5  ) {
	foreach my $n ( sort keys %keyed_intervals ) {
        my $pn = ((e ** -$x) * ($x ** $n)) / factorial($n);
        #my $pn = e ** -$x;
        #$tot += $pn; # if $n >= 13;
        #print "P($n): " . $pn . "\n";
        
        $keyed_intervals{ $n } = $pn;
	}
	
	#Go through the predictions by order of probability, create the next date with is <interval> units from the latest date
	# then in the buckets for that date's data and see if it corresponds to any large buckets
	my $last_date = $self->{last_date};
	my @pdates = ();
	print "--- With intervals:\n";
	foreach my $interval (sort { $keyed_intervals{ $b } <=> $keyed_intervals{ $a } } keys %keyed_intervals) {
		my $dur = new DateTime::Duration( days => $interval );
		my $new_date = $last_date + $dur;
		
		my $datehash = { date => $new_date, interval => $interval, probability => $keyed_intervals{ $interval } };
		push(@pdates, $datehash);
		
		while (my ($name, $dbucket) = each %{ $self->{distinct_buckets} }) {
			#next if (! $dbucket->{on}); #Skip buckets that are turned off
			
			my $cref = $new_date->can( $dbucket->{accessor} );
				croak "Can't call accessor '" . $dbucket->{accessor} . "' on " . ref($new_date) . " object" unless $cref;
			my $dvalue = &$cref($new_date);
			my $dnum = $dbucket->{buckets}->{ $dvalue };
			#warn Dumper($dbucket);
			print "  adding distinct '$name' : $dvalue : $dnum\n";
			#$datehash->{distincts}->{ $name } = { $dnum
			$datehash->{distinct_sum} += $dnum;
		}
		
		print $new_date->mdy('/') . ' ' . $new_date->hms . " ($interval days : " . $keyed_intervals{$interval}  . ")\n";
	}
	
	print "--- With distincts:\n";
	foreach my $pdate (sort { $b->{probability} <=> $a->{probability} || $b->{distinct_sum} <=> $a->{distinct_sum} } @pdates) {
		print $pdate->{date}->mdy('/') . ' ' . $pdate->{date}->hms . " (" . $pdate->{interval} . " interval days : " . $keyed_intervals{ $pdate->{interval} }  . ") (distinct sum: " . $pdate->{distinct_sum} . ")\n";
	}
};

sub regress_predict_days {
	my $self = shift;
	
	#warn Dumper($self->{epoch_intervals}); exit;
	
	unless ($self->is_trained) { $self->train(); $self->{trained}++; }
	
	#my $minday =  DateTime::Duration->new(days => -1);
	#my $outlier = $self->{first_date} + $minday;
	
	print "FIRST: " . $self->{first_date}->mdy('/') . ' ' . $self->{first_date}->hms . "\n";
	
	my @xs       = ();
	my @ys       = ();
	my $sum_x    = 0;
	my $sum_y    = 0;
	my $sum_xy   = 0;
	my $sum_sq_x = 0;
	my $sum_sq_y = 0;
	my $c        = 0;
	foreach my $date (sort { $a->hires_epoch() <=> $b->hires_epoch() } @{ $self->{dates} }) {
		#print $date->mdy('/') . ' ' . $date->hms . " -- ";
		$c++;
		
		my $dur = $date->delta_days( $self->{first_date} );
		
		$sum_x    += $c;
		$sum_y 	  += $dur->delta_days;
		$sum_sq_x += ($c ** 2);
		$sum_sq_y += ($dur->delta_days ** 2);
		$sum_xy   += ($c * $dur->delta_days);
		
		push(@xs, $c);
		push(@ys, $dur->delta_days);
		
		#print $dur->delta_days . "\n";
	}
	
	my $avg_x = $sum_x / $c;
	my $avg_y = $sum_y / $c;
	
	print "AVG X: $avg_x\n";
	print "AVG Y: $avg_y\n";
	print "COUNT: $c\n";
	
	my $ssx = $sum_sq_x - (( $sum_x ** 2 )     / $c);
	my $sxy = $sum_xy   - (( $sum_x * $sum_y ) / $c);
	
	my $a = $sxy / $ssx;
	my $b = $avg_y - ($a * $avg_x);

	my $p = ($a * ($c+1)) + $b;
	$p = round($p);
	
	print "Line: ${a}x + $b\n";
	
	##Get the standard deviation for both x and y
	my $x_total_deviation = 0;
	foreach my $x (@xs) {
		my $dev = $x - $avg_x;
		$x_total_deviation += $dev ** 2;
	}
	my $x_standard_deviation = sqrt( $x_total_deviation / ($c - 1));
	
	my $y_total_deviation = 0;
	foreach my $y (@ys) {
		my $dev = $y - $avg_y;
		$y_total_deviation += $dev ** 2;
	}
	my $y_standard_deviation = sqrt( $y_total_deviation / ($c - 1));
	
	print "---\n";
	
	print "X std deviation: $x_standard_deviation\n";
	print "Y std deviation: $y_standard_deviation\n";
	
	#warn Dumper(\@xs, \@ys); exit;
	
	#Get the correlation coefficient
	#print "{";
	my $cor_co_sum = 0;
	for (my $i = 0; $i < $c; $i++) {
		my $x = $xs[$i];
		my $y = $ys[$i];
		
		#print "{$x,$y},";
		
		my $x_dev = $x - $avg_x;
		my $y_dev = $y - $avg_y;
		
		my $x_std_dev_div = $x_dev / $x_standard_deviation;
		my $y_std_dev_div = $y_dev / $y_standard_deviation;
		
		$cor_co_sum += ($x_std_dev_div * $y_std_dev_div);
	}
	#print "}\n";
	my $r = my $correlation_coefficient = $cor_co_sum / ($c - 1);
	
	print "r = $r\n";
	print "r^2 = " . $r ** 2 . "\n";
	
	print "---\n";
	
	my $ndur = DateTime::Duration->new(days => $p);
	my $ndate = $self->{first_date} + $ndur;
	print "PREDICTED DATE: " . $ndate->mdy('/') . ' ' . $ndate->hms . ' : ' . "p = $p\n";
}

# Do a multiple linear regression based on each enabled bucket (just the distinct ones for now)
sub regress_predict_buckets {
	my $self = shift;
	
	#print Dumper($self); exit;
	
	#warn Dumper($self->{epoch_intervals}); exit;
	
	unless ($self->is_trained) { $self->train(); $self->{trained}++; }
	
	#my $minday =  DateTime::Duration->new(days => -1);
	#my $outlier = $self->{first_date} + $minday;
	
	print "FIRST: " . $self->{first_date}->mdy('/') . ' ' . $self->{first_date}->hms . "\n";
	
	my @buckets = ( $self->{distinct_buckets}->{day_of_year} );
		#print "BUCKETS: " . Dumper(\%buckets); exit;
	
	foreach my $bucket (@buckets) {
		#print "BUCKETS: " . Dumper(\%buckets); exit;
		
		my @xs       = ();
		my @ys       = ();
		my $sum_x    = 0;
		my $sum_y    = 0;
		my $sum_xy   = 0;
		my $sum_sq_x = 0;
		my $sum_sq_y = 0;
		my $c        = 0;
		
		foreach my $date (sort { $a->hires_epoch() <=> $b->hires_epoch() } @{ $self->{dates} }) {
		#while (my ($value, $count) = each $bucket->{buckets}) {
			#print $date->mdy('/') . ' ' . $date->hms . " -- ";
			$c++;
			
			my $cref = $date->can( $bucket->{accessor} );
			my $value = &$cref($date);
			
			$sum_x    += $c;
			$sum_y 	  += $value;
			$sum_sq_x += ($c ** 2);
			$sum_sq_y += ($value ** 2);
			$sum_xy   += ($c * $value);
			
			push(@xs, $c);
			push(@ys, $value);
			
			print "DOY: " . $date->doy() . "\n";
			
			#print $dur->delta_days . "\n";
		}
		
		my $avg_x = $sum_x / $c;
		my $avg_y = $sum_y / $c;
		
		print "AVG X: $avg_x\n";
		print "AVG Y: $avg_y\n";
		print "COUNT: $c\n";
		
		my $ssx = $sum_sq_x - (( $sum_x ** 2 )     / $c);
		my $sxy = $sum_xy   - (( $sum_x * $sum_y ) / $c);
		
		my $a = $sxy / $ssx;
		my $b = $avg_y - ($a * $avg_x);
	
		my $p = ($a * ($c+1)) + $b;
		$p = round($p);
		
		print "Line: ${a}x + $b\n";
		
		##Get the standard deviation for both x and y
		my $x_total_deviation = 0;
		foreach my $x (@xs) {
			my $dev = $x - $avg_x;
			$x_total_deviation += $dev ** 2;
		}
		my $x_standard_deviation = sqrt( $x_total_deviation / ($c - 1));
		
		my $y_total_deviation = 0;
		foreach my $y (@ys) {
			my $dev = $y - $avg_y;
			$y_total_deviation += $dev ** 2;
		}
		my $y_standard_deviation = sqrt( $y_total_deviation / ($c - 1));
		
		print "---\n";
		
		print "X std deviation: $x_standard_deviation\n";
		print "Y std deviation: $y_standard_deviation\n";
		
		#warn Dumper(\@xs, \@ys); exit;
		
		#Get the correlation coefficient
		#print "{";
		my $cor_co_sum = 0;
		for (my $i = 0; $i < $c; $i++) {
			my $x = $xs[$i];
			my $y = $ys[$i];
			
			#print "{$x,$y},";
			
			my $x_dev = $x - $avg_x;
			my $y_dev = $y - $avg_y;
			
			my $x_std_dev_div = $x_dev / $x_standard_deviation;
			my $y_std_dev_div = $y_dev / $y_standard_deviation;
			
			$cor_co_sum += ($x_std_dev_div * $y_std_dev_div);
		}
		#print "}\n";
		my $r = my $correlation_coefficient = $cor_co_sum / ($c - 1);
		
		print "r = $r\n";
		print "r^2 = " . $r ** 2 . "\n";
		
		print "---\n";
		
		#my $ndur = DateTime::Duration->new(days => $p);
		#my $ndate = $self->{first_date} + $ndur;
		#print "PREDICTED DATE: " . $ndate->mdy('/') . ' ' . $ndate->hms . ' : ' . "p = $p\n";
	}
}

sub average_predict_days {
	my $self = shift;
	
	#warn Dumper($self->{epoch_intervals}); exit;
	
	unless ($self->is_trained) { $self->train(); $self->{trained}++; }
	
	#my %buckets = %{ $self->{interval_buckets}->{days}->{buckets} };
	my %buckets = %{ $self->{distinct_buckets}->{day_of_year}->{buckets} };
	
	#Inflate the buckets, right now they're counters on each interval
	#my @intervals = ();
	my %keyed_intervals = ();
	my $total_interval = 0;
	my $interval_count = 0;
	while (my ($interval, $count) = each %buckets) {
		next unless $count > 0;
		#$keyed_intervals{ $interval } = 1;
		#print "Pushing $interval: ";
		for (1 .. $count) {
			$interval_count++;
			#print "$_ ";
			#push(@intervals, $interval);
			$total_interval += $interval;
			$keyed_intervals{ $interval }->{count} += 1;
		}
	}
	
	#warn Dumper(\%keyed_intervals); exit;
	print "Total interval: $total_interval\n";
	print "Intervals: " . $interval_count . "\n";
	my $avg_diff = ($total_interval / $interval_count);
	
	my @interval_avgs = ();
	foreach my $interval (keys %keyed_intervals) {
		my $count = $keyed_intervals{ $interval }->{count};
		my $i_avg = $count / $interval_count;
		$keyed_intervals{ $interval }->{probability} = $i_avg;
	}
	
	my @pdates = ();
	print "--- With intervals:\n";
	foreach my $interval (sort { $keyed_intervals{ $b }->{probability} <=> $keyed_intervals{ $a }->{probability} } keys %keyed_intervals) {
		#print "Interval '$interval' (" . $keyed_intervals{ $interval }->{count} . ") : " . $keyed_intervals{ $interval }->{probability} . "\n";
		
		my $dur = new DateTime::Duration( days => $interval );
		my $new_date = $self->{last_date} + $dur;
		
		my $datehash = { date => $new_date, interval => $interval, probability => $keyed_intervals{ $interval }->{probability} };
		push(@pdates, $datehash);
		
		while (my ($name, $dbucket) = each %{ $self->{distinct_buckets} }) {
			#next if (! $dbucket->{on}); #Skip buckets that are turned off
			
			my $cref = $new_date->can( $dbucket->{accessor} );
				croak "Can't call accessor '" . $dbucket->{accessor} . "' on " . ref($new_date) . " object" unless $cref;
			my $dvalue = &$cref($new_date);
			my $dnum = $dbucket->{buckets}->{ $dvalue };
			#warn Dumper($dbucket);
			print "  adding distinct '$name' : $dvalue : $dnum\n";
			#$datehash->{distincts}->{ $name } = { $dnum
			$datehash->{distinct_sum} += $dnum;
		}
		
		print $new_date->mdy('/') . ' ' . $new_date->hms . " ($interval days : " . $keyed_intervals{$interval}->{probability}  . ")\n";
	}
	
	print "--- With distincts:\n";
	foreach my $pdate (sort { $b->{probability} <=> $a->{probability} || $b->{distinct_sum} <=> $a->{distinct_sum} } @pdates) {
		print $pdate->{date}->mdy('/') . ' ' . $pdate->{date}->hms . " (" . $pdate->{interval} . " interval days : " . $keyed_intervals{ $pdate->{interval} }->{probability}  . ") (distinct sum: " . $pdate->{distinct_sum} . ")\n";
	}
}

sub print_dates {
	my $self = shift;
	
	foreach my $date (sort { $a->hires_epoch() <=> $b->hires_epoch() } @{ $self->{dates} }) {
		print $date->mdy('/') . ' ' . $date->hms . "\n";
	}
}

sub is_trained {
	my $self = shift;
	
	return ($self->{trained} > 0) ? 1 : 0;
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

Set the profile for which buckets will be turned on and what their weights will be

	my $profile = (
		buckets => {},
		proximity => 1, #Whether dates in close proximity to one another cause each other to be weighted more heavily
	);

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

=item *

The predict method should take an argument that specifies how the result(s) are returned, and how many. For instance, we should be able to
say we want the 5 best predictions, or all predictions that are at least n, where n is a measure of accuracy. We should also be able to
specify that 

=back

=head1 IDEAS

  DateTime::Event::Predict::Profile could be a subclass that defines bucket and weight profiles for certain types of predictions. For
  instance, there could be a profile for log files (or different types of log files), for weather events, etc.

  There could be a method similar to predict that you would give the expected prediction to. If the method does not predict that date
  then maybe it could figure out what tinkering of weights (or other options) would be required to produce that prediction. *This would
  probably be very hard.
  
  Maybe one way to do comparisons would be to take each date and do a diff between it and the dates before and after it (if there are any), then do
  some kind of filtering based on that.
  
  NOTE: Okay, so we calculate all the poisson probabilities for the intervals that we want to predict for (days, months, etc), and then finding the best
  fits (highest probabilities) we find the next date for that interval (add the interval onto the most recent date) and match it against the buckets to
  see if it's a fit on any of them. Then we can add weights to the distinct buckets so that certain matches can be preferred over others.

  IDEA: Create a custom accessor for "Week-segment", or even "work-week-segment", which would split the week up into parts, like Mon-Wed would be
  beginning of work week, Tues-Thurs would be middle of work week, and Wed-Fri would be end of work week. Some dates would of course end up in multiple
  places (i.e. Tues is both beginning and middle) however I think regression would allow a best-fit line to be made.
  
  *IDEA*: Maybe we can use distribution math for all the buckets, both distinct and interval, and use the standard deviation
  of the values for each bucket to sort them (and maybe provide weights?), and then scan for new dates. We could also use the
  variance of each scanned new date to determine if it falls within the margin of error, i.e. if we're search for the next date
  of Easter and the standard deviation for "day_of_week" is 0, because all of them are on Sunday, then we know that any date
  offered as a prediction but fall within that standard deviation, i.e. 0, and therefore MUST be Sunday.
  
  	NOTE: Predicting Easter completely accurately will be impossible because it depends on the moon phase. Without taking that
  	into account (possible?) we won't get an accurate date
  	
  IDEA: It should be possible to pass in any (reasonable) number n of arbitrary attributes with which to identify dates. We just add them
  on to the dimensions we already have in order to operate over them.
  
  IDEA: For finding a beginning search point in the future we can optionally prevent searching before the current date, so if,
  say, there was an equal possibility of a predicted date being in a near-current cluster or a future cluster, if that current
  cluster occured in the past and the option was set then the date would HAVE to be in the new cluster.

  IDEA: If we assume that for any date-part, the data points follow a normal distribution, then for any given prediction
  (supplied by the module or by the end-user) we can calculate the probability that that date part is correct (by its standard
  deviation), and then for all the date parts we can use Bayes Theorem to combine their probabilities to determine the
  complete probability for that particular date.

  NOTE: Actual cluster centroids (and comparisons to them) will have to defined through hires epoch time, but that should be OK.

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
