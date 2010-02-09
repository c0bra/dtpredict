
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

use 5.006;

use strict;

use DateTime;
use Params::Validate qw(:all);
use Carp qw(carp croak confess);
use Scalar::Util;
use List::Util qw(max);

use POSIX qw(ceil);

use DateTime::Event::Predict::Profile qw(:buckets);

our $VERSION = '0.01_05';


#===============================================================================#

sub new {
    my $proto = shift;
    
    my %opts = validate(@_, {
    	dates       => { type => ARRAYREF, 					optional => 1 },
    	profile     => { type => SCALAR | OBJECT | HASHREF, optional => 1 },
    	#stdev_limit => { type => SCALAR,          			default  => 2 },
    	clustering  => { type => SCALAR | HASHREF, 			optional => 1, },
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
    
    #$opts{profile} = 'default' if ! $opts{profile};
    
    if ( $opts{profile} ) {
    	$self->profile( $opts{profile} );
	}
    
    return $self;
}

# Get or set list of dates
# ***NOTE: Should make this validate for 'can' on the DateTime methods we need and on 'isa' for DateTime
sub dates {
	my $self   = shift;
	my @dates = @_;
	
	#validate_pos(@_, { type => , optional => 1 });
	
	if (! defined @dates) {
		return wantarray ? @{$self->{dates}} : $self->{dates};
	}
	else {
		$self->{dates} = [];
		foreach my $date (@dates) {
			$self->add_date($date);
		}
	}
	
	return 1;
}

# Add dates to list of dates
sub add_dates {
	my $self  = shift;
	my @dates = @_;
	
	foreach my $date (@dates) {
		$self->add_date($date);
	}
}

# Add a date to the list of dates
sub add_date {
	my $self   = shift;
	my ($date) = @_;
	
	validate_pos(@_, { isa => 'DateTime' }); #***Or we could attempt to parse the date, or use can( epoch() );
	
	my $new_date = $self->_trim_date( $date );
	
	push(@{ $self->{dates} }, $new_date);
	
	return 1;
}

#Get or set the profile for this predictor
sub profile {
	my $self      = shift;
	my ($profile) = @_; # $profile can be a string specifying a profile name that is provided by default, or a profile object, or options to create a new profile
	
	validate_pos(@_, { type => SCALAR | OBJECT | HASHREF, optional => 1 });
	
	# If no profile is provided, return the current profile
	if (! defined $profile || ! $profile) { return $self->{profile}; }
	
	my $new_profile;
	
	# Profile is an actual DTP::Profile object
	if (Scalar::Util::blessed($profile) && $profile->can('buckets')) {
		$new_profile = $profile;
	}
	# Profile is a hashref of options to create a new DTP::Profile object with
	elsif (ref($profile) eq 'HASH') {
		$new_profile = DateTime::Event::Predict::Profile->new(
			%$profile,
		);
	}
	# Profile is the name of a profile alias
	else {
		$new_profile = DateTime::Event::Predict::Profile->new( profile => $profile );
	}
	
	# Add the distinct buckets
    foreach my $bucket ( $new_profile->_distinct_buckets() ) {
    	$self->{distinct_buckets}->{ $bucket->name } = $bucket->clone();
    }
    
    # Add the interval buckets
    foreach my $bucket ( $new_profile->_interval_buckets() ) {
    	$self->{interval_buckets}->{ $bucket->name } = $bucket->clone();
    }
	
	$self->{profile} = $new_profile;
	
	return 1;
}

# Gather statistics about the dates
sub train {
	my $self = shift;
	
	# Clear out anything already in the the buckets
	foreach my $bucket (values %{$self->{distinct_buckets}}, values %{$self->{interval_buckets}} ) {
		$bucket->{buckets} = {};
		
		# Delete the statistics
		delete $bucket->{mean};
		delete $bucket->{variance};
		delete $bucket->{stdev};
	}
	
	# If no profile has been set, initialize every bucket possible for automatic determination of which ones to use
	if (! $self->profile) {
		# Add the distinct buckets
	    foreach my $bucket ( keys %DISTINCT_BUCKETS ) {
	    	$self->{distinct_buckets}->{ $bucket->name } = $bucket->clone();
	    }
	    
	    # Add the interval buckets
	    foreach my $bucket ( keys %INTERVAL_BUCKETS ) {
	    	$self->{interval_buckets}->{ $bucket->name } = $bucket->clone();
	    }
	}
	
	# Sort the dates chronologically
	my @dates = sort { $a->hires_epoch() <=> $b->hires_epoch() } @{ $self->{dates} }; #*** Need to convert this to DateTime->compare($dt1, $dt2)
	
	# Last and first dates
	$self->{last_date}  = $dates[$#dates];
	$self->{first_date} = $dates[0];
	
	my $prev_date;
	foreach my $index (0 .. $#{ $self->{dates} }) {
		# The date to work on
		my $date = $dates[ $index ];
		
		# Get which dates were before and after the date we're working on
		my ($before, $after);
		if ($index > 0) { $before = $dates[ $index - 1 ]; }
		if ($index < $#{ $self->{dates} }) { $after = $dates[ $index + 1 ]; }
		
		# Increment the date-part buckets
		while (my ($name, $dbucket) = each %{ $self->{distinct_buckets} }) {
			# Get the accessor method by using can()
			my $cref = $date->can( $dbucket->accessor );
				croak "Can't call accessor '" . $dbucket->accessor . "' on " . ref($date) . " object" unless $cref;
				
			# Increment the number of instances for the value given when we use this bucket's accessor on $date
			$dbucket->{buckets}->{ &$cref($date) }++;
		}
		
		# If this is the first date we have nothing to diff, so we'll skip on to the next one
		if (! $prev_date) { $prev_date = $date; next; }
		
		# Get a DateTime::Duration object representing the diff between the dates
		#my $dur = $date->subtract_datetime( $prev_date );
		
		# Increment the interval buckets
		# Intervals: here we default to the largest interval that we can see. So, for instance, if
		#   there is a difference of months we will not increment anything smaller than that.
		while (my ($name, $bucket) = each %{ $self->{interval_buckets} }) {
			#my $cref = $dur->can( $bucket->accessor );
			#	croak "Can't call accessor '" . $bucket->accessor . "' on " . ref($dur) . " object" unless $cref;
			#my $interval = &$cref($dur);
			#my $interval = $dur->in_units( $bucket->accessor );
			
			my $interval = $self->_get_date_interval($bucket->name, $bucket->accessor, $date, $prev_date);
			
			$bucket->{buckets}->{ $interval }++;
		}
		
		# Add the difference between dates in epoch seconds
		my $epoch_interval = $date->hires_epoch() - $prev_date->hires_epoch();
		
		### Epoch interval: $epoch_interval
		
		$self->{total_epoch_interval} += $epoch_interval;
		
		# Set the current date to this date
		$prev_date = $date;
	}
	
	# Average interval between dates in epoch seconds
	$self->{mean_epoch_interval} = $self->{total_epoch_interval} / (scalar @dates - 1); #Divide total interval by number of intervals
	
	# Figure the mean, variance, and standard deviation for each bucket
	foreach my $bucket (values %{$self->{distinct_buckets}}, values %{$self->{interval_buckets}}) {
		$self->_generate_bucket_statistics($bucket);
	}
	
	# If no profile is set, enable buckets automatically based on their statistics
	if (! $self->profile) {
		
	}
	
	# Mark this object as being trained
	$self->{trained}++;
}

sub predict {
	my $self = shift;
	
	my %opts = validate(@_, {
		max_predictions => { type => SCALAR,     	   optional => 1 }, # How many predictions to return
		stdev_limit     => { type => SCALAR,     	   default  => 1 }, # Number of standard deviations to search through, default to 2
		min_date		=> { isa  => 'DateTime', 	   optional => 1 }, # If set, make no prediction before 'min_date'
		callbacks       => { type => ARRAYREF,   	   optional => 1 }, # Arrayref of coderefs to call when making predictions
		clustering      => { type => SCALAR | HASHREF, default  => 1 }, # "1" to turn clustering on, or a hashref of cluster options
	});
	
	# Force max predictions to one if we were called in scalar context
	if (! defined $opts{'max_predictions'}) {
		$opts{'max_predictions'} = 1 if ! wantarray;
	}
	
	# Train this set of dates if they're not already trained
	$self->train if ! $self->_is_trained;
	
	# Make a copy of the distinct and interval bucket hashes so we can mess with them
	my %distinct_buckets = %{ $self->{distinct_buckets} };
	my %interval_buckets = %{ $self->{interval_buckets} };
	
	# Get the most recent of the provided dates by sorting them by their epoch seconds
	my $most_recent_date = (sort { $b->hires_epoch() <=> $a->hires_epoch() } @{ $self->{dates} })[0];
	
	# ****Cluster the dates if the clustering option is turned on
	my $start_date;
	if ($opts{clustering}) {
		# Attempt clustering
		my $clustering = $self->_cluster_dates( $self->dates );
		
		# Only proceed with clustering if _cluster_dates completed and gave us a number of clusters less than the number of dates
		if (defined $clustering && $clustering->{num_clusters} < scalar $self->dates) {
			# If addind a new date into the most recent cluster would give it a number of dates that is greater than
			#  the mean + the standard deviation, set the start date into the future by the average number of seconds
			#  between each cluster centroid ('avg_centroid_diff')
			if ( (scalar keys %{$clustering->{most_recent_cluster}}) + 1 > $clustering->{mean} + $clustering->{num_elements_stdev}) {
				my $duration = new DateTime::Duration(
					seconds => $clustering->{firstlast_diff_mean},
				);
				$start_date = $clustering->{most_recent_cluster}->{centroid} + $duration;
			}
			# Otherwise, make the start date the most recent cluster's centroid
			else {
				$start_date = $clustering->{most_recent_cluster}->{centroid};
			}
			
			# Re-train using the cluster centroids as the dates
			#$self->dates( map { $_->{centroid} } @{$clustering->{clusters}} );
			#$self->train();
			
			# Create new fake bucket with cluster interval info
			$interval_buckets{cluster} = $INTERVAL_BUCKETS{ 'seconds' }->clone;
			$interval_buckets{cluster}->{mean}     = $clustering->{firstlast_diff_mean};
			$interval_buckets{cluster}->{variance} = $clustering->{firstlast_diff_variance};
			$interval_buckets{cluster}->{stdev}    = $clustering->{firstlast_diff_stdev};
			$interval_buckets{cluster}->{name}     = 'cluster';
			$interval_buckets{cluster}->{accessor} = 'seconds';
		}
	}
	
	#use Data::Dumper; print Dumper(\%interval_buckets); exit;
	
	# If clustering is not turned on, set the start date into the future by the average number of seconds between
	#  each date
	if (! defined $start_date) {
		# Make a starting search date that has been moved ahead by the average interval beteween dates (in epoch seconds)
		my $duration = new DateTime::Duration(
			seconds => $self->{mean_epoch_interval}, # **Might need to round off hires second info here?
		);
		$start_date = $most_recent_date + $duration;
	}
	
	$start_date = $self->_trim_date($start_date);
	
	print "START DATE: $start_date\n";
	
	#use Data::Dumper; print Dumper($self);
	
	# A hash of predictions, dates are keyed by their hires_epoch() value
	my %predictions = ();
	
	# Start with using the distinct buckets to make predictions
	if (%distinct_buckets) {
		# Get a list of buckets after sorting the buckets from largest date part to smallest (i.e. year->month->day->hour ... microsecond, etc)
		my @distinct_bucket_keys = sort { $self->{distinct_buckets}->{ $b }->{order} <=> $self->{distinct_buckets}->{ $a }->{order} } keys %distinct_buckets;
		
		# Get the first bucket name 
		my $first_bucket_name = shift @distinct_bucket_keys;
		
		# Start recursively descending down into the various date parts, searching in each one
		$self->_date_descend_distinct(
			%opts,
			
			date        	 	 => $start_date,
			most_recent_date 	 => $most_recent_date,
			bucket_name 	 	 => $first_bucket_name,
			distinct_buckets 	 => \%distinct_buckets,
			distinct_bucket_keys => \@distinct_bucket_keys,
			predictions 	 	 => \%predictions,
		);
		
		# Now that we (hopefully) have some predictions, put them each through _interval_check to check
		# the predictiosn against the interval bucket statistics
		if (%interval_buckets) {
			while (my ($hires, $prediction) = each %predictions) {
				# Delete the date from the predictions hash if it's not good according to the interval statistics
				if (! $self->_interval_check( $prediction )) {
					delete $predictions{ $hires };
				}
			}
		}
	}
	# No distinct buckets, just interval buckets
	elsif (%interval_buckets) {
		#print "NEW DATES:\n"; $self->_print_dates;
		#use Data::Dumper; print "BUCKETS: " . Dumper(\%interval_buckets);
		
		# Get a list of buckets after sorting the buckets from largest interval to smallest (i.e. years->months->days->hours, etc)
		my @interval_bucket_keys = sort { $self->{interval_buckets}->{ $b }->{order} <=> $self->{interval_buckets}->{ $a }->{order} } keys %interval_buckets;
		
		# Get the first bucket name 
		my $first_bucket_name = shift @interval_bucket_keys;
		
		# Start recursively descending down into the date interval types, searching in each one
		$self->_date_descend_interval(
			%opts,
			
			date        	 	 => $start_date,
			most_recent_date 	 => $most_recent_date,
			bucket_name 	 	 => $first_bucket_name,
			interval_buckets 	 => \%interval_buckets,
			interval_bucket_keys => \@interval_bucket_keys,
			predictions 	 	 => \%predictions,
		);
	}
	# WTF, no buckets. That's bad!
	else {
		croak("No buckets supplied!");
	}
	
	# Sort the predictions by their total deviation
	my @predictions = sort { $a->{_dtp_deviation} <=> $b->{_dtp_deviation} } values %predictions;
	
	return wantarray ? @predictions : $predictions[0];
}

# Descend down into the distinct date parts, looking for predictions
sub _date_descend_distinct {
	my $self = shift;
	#my %opts = @_;
	
	# Validate the options
	validation_options( allow_extra => 1 );
	my %opts = validate(@_, {
		date        	 	 => { isa => 'DateTime' },				 # The date to start searching in
		most_recent_date 	 => { isa => 'DateTime' },               # The most recent date of the dates provided
		bucket_name 	 	 => { type => SCALAR },					 # The bucket (date-part) to start searching in
		distinct_buckets 	 => { type => HASHREF },				 # A hashref of all buckets to use when looking for good predictions
		distinct_bucket_keys => { type => ARRAYREF },				 # A list of bucket names that we shift out of to get the next bucket to use
		stdev_limit 	 	 => { type => SCALAR },					 # The limit of how many standard deviations to search through
		predictions 	 	 => { type => HASHREF },				 # A hashref of predictions we find
		max_predictions  	 => { type => SCALAR,     optional => 1 }, # The maxmimum number of predictions to return (prevents overly long searches)
		min_date		 	 => { isa  => 'DateTime', optional => 1 }, # If set, make no prediction before 'min_date'
		callbacks 	     	 => { type => ARRAYREF,   optional => 1 }, # A list of custom coderefs that are called on each possible prediction
	});
	validation_options( allow_extra => 0 );
	
	# Copy the options over into simple scalars so it's easier on my eyes
	my $date 				 = delete $opts{'date'};        # Delete these ones out as we'll be overwriting them below
	my $bucket_name 		 = delete $opts{'bucket_name'};
	my $distinct_buckets 	 = $opts{'distinct_buckets'};
	my $distinct_bucket_keys = $opts{'distinct_bucket_keys'};
	my $stdev_limit 		 = $opts{'stdev_limit'};
	my $predictions 		 = $opts{'predictions'};
	my $max_predictions 	 = $opts{'max_predictions'};
	my $callbacks       	 = $opts{'callbacks'};
	
	# We've reached our max number of predictions, return
	return 1 if defined $max_predictions && (scalar keys %$predictions) >= $max_predictions;
	
	# Get the actual bucket hash for this bucket name
	my $bucket = $distinct_buckets->{ $bucket_name };
	
	# The search range is the standard deviation multiplied by the number of standard deviations to search through
	my $search_range = ceil( $bucket->{stdev} * $stdev_limit );
	
	#The next bucket to search down into
	my $next_bucket_name = "";
	if (scalar @$distinct_bucket_keys > 0) {
		$next_bucket_name = shift @$distinct_bucket_keys;
	}
	
	foreach my $search_inc ( 0 .. $search_range ) {
		# Make an inverted search increment so we can search backwards
		my $neg_search_inc = $search_inc * -1;
		
		# Put forwards and backwards in the searches
		my @searches = ($search_inc, $neg_search_inc);
		
		# Make sure we only search on 0 once (i.e. 0 * -1 == 0)
		@searches = (0) if $search_inc == 0;
		
		foreach my $increment (@searches) {
			# We've reached our max number of predictions, return
			return 1 if defined $max_predictions && (scalar keys %$predictions) >= $max_predictions;
			
			# Make a duration object using the accessor for this bucket
			my $duration_increment = new DateTime::Duration( $bucket->{duration} => $increment );
			
			# Get the new date
			my $new_date = $date + $duration_increment;
			
			# Trim the date down to just the date parts we care about
			$new_date = $self->_trim_date( $new_date );
			
			# Skip this date if it's before or on the most recent date
			if (DateTime->compare( $new_date, $opts{'most_recent_date'} ) <= 0) { # New date is before the most recent one, or is same as most recent one
				next;
			}
			
			# Skip this date if the "min_date" option is set, and it's before or on that date
			if ($opts{'min_date'} && DateTime->compare($new_date, $opts{'min_date'}) <= 0) {
				next;
			}
			
			# If we have no more buckets to search into, determine if this date is a good prediction
			if (! $next_bucket_name) {
				if ($self->_distinct_check( %opts, date => $new_date )) {
					$predictions->{ $new_date->hires_epoch() } = $new_date;
				}
			}
			#If we're not at the smallest bucket, keep searching!
			else {
				$self->_date_descend_distinct(
					%opts,
					date        => $new_date,
					bucket_name => $next_bucket_name,
				);
			}
		}
	}
	
	return 1;
}

# Descend down into the date intervals, looking for predictions
sub _date_descend_interval {
	my $self = shift;
	
	# Validate the options
	validation_options( allow_extra => 1 );
	my %opts = validate(@_, {
		date        	 	 => { isa => 'DateTime' },				 # The date to start searching in
		most_recent_date 	 => { isa => 'DateTime' },               # The most recent date of the dates provided
		bucket_name 	 	 => { type => SCALAR },					 # The bucket (date-part) to start searching in
		interval_buckets 	 => { type => HASHREF },				 # A hashref of all buckets to use when looking for good predictions
		interval_bucket_keys => { type => ARRAYREF },				 # A list of bucket names that we shift out of to get the next bucket to use
		stdev_limit 	 	 => { type => SCALAR },					 # The limit of how many standard deviations to search through
		predictions 	 	 => { type => HASHREF },				 # A hashref of predictions we find
		max_predictions  	 => { type => SCALAR,     optional => 1 }, # The maxmimum number of predictions to return (prevents overly long searches)
		min_date		 	 => { isa  => 'DateTime', optional => 1 }, # If set, make no prediction before 'min_date'
		callbacks 	     	 => { type => ARRAYREF,   optional => 1 }, # A list of custom coderefs that are called on each possible prediction
	});
	validation_options( allow_extra => 0 );
	
	# Copy the options over into simple scalars so it's easier on my eyes
	my $date 				 = delete $opts{'date'};        # Delete these ones out as we'll be overwriting them below
	my $bucket_name 		 = delete $opts{'bucket_name'};
	my $interval_buckets 	 = $opts{'interval_buckets'};
	my $interval_bucket_keys = $opts{'interval_bucket_keys'};
	my $stdev_limit 		 = $opts{'stdev_limit'};
	my $predictions 		 = $opts{'predictions'};
	my $max_predictions 	 = $opts{'max_predictions'};
	my $callbacks       	 = $opts{'callbacks'};
	
	# We've reached our max number of predictions, return
	return 1 if defined $max_predictions && (scalar keys %$predictions) >= $max_predictions;
	
	# Get the actual bucket hash for this bucket name
	my $bucket = $interval_buckets->{ $bucket_name };
	print "BUCKET: $bucket_name\n";
	
	# The search range is the standard deviation multiplied by the number of standard deviations to search through
	#my $search_range = ceil( $bucket->{stdev} * $stdev_limit );
	my $mean_interval_units = $self->_convert_seconds($self->{mean_epoch_interval}, $bucket->accessor);
	print "\MEAN INTERVAL UNITS: $mean_interval_units\n";
	my $search_range = ceil( $bucket->{stdev} * $stdev_limit );
	$search_range = 1 if $search_range < 1;
	
	print "SEARCH RANGE: $search_range\n";
	
	#The next bucket to search down into
	my $next_bucket_name = "";
	if (scalar @$interval_bucket_keys > 0) {
		$next_bucket_name = shift @$interval_bucket_keys;
	}
	
	foreach my $search_inc ( 0 .. $search_range ) {
		# Make an inverted search increment so we can search backwards
		my $neg_search_inc = $search_inc * -1;
		
		# Put forwards and backwards in the searches
		my @searches = ($search_inc, $neg_search_inc);
		
		print "\nSEARCHES: " . join(', ', @searches) . "\n";
		
		# Make sure we only search on 0 once (i.e. 0 * -1 == 0)
		@searches = (0) if $search_inc == 0;
		
		foreach my $increment (@searches) {
			# We've reached our max number of predictions, return
			return 1 if defined $max_predictions && (scalar keys %$predictions) >= $max_predictions;
			
			# Make a duration object using the accessor for this bucket
			my $duration_increment = new DateTime::Duration( $bucket->accessor => $increment );
			
			# Get the new date
			my $new_date = $date + $duration_increment;
			
			# Trim the date down to just the date parts we care about
			$new_date = $self->_trim_date( $new_date );
			
			# Skip this date if it's before or on the most recent date
			if (DateTime->compare( $new_date, $opts{'most_recent_date'} ) <= 0) { # New date is before the most recent one, or is same as most recent one
				next;
			}
			
			# Skip this date if the "min_date" option is set, and it's before or on that date
			if ($opts{'min_date'} && DateTime->compare($new_date, $opts{'min_date'}) <= 0) {
				next;
			}
			
			# If we have no more buckets to search into, determine if this date is a good prediction
			if (! $next_bucket_name) {
				if ($self->_interval_check( %opts, date => $new_date )) {
					print "We have a prediction!\n";
					$predictions->{ $new_date->hires_epoch() } = $new_date;
				}
			}
			#If we're not at the smallest bucket, keep searching!
			else {
				$self->_date_descend_interval(
					%opts,
					date        => $new_date,
					bucket_name => $next_bucket_name,
				);
			}
		}
	}
	
	return 1;
}

# Check to see if a given date is good according to the supplied distinct buckets by going through each bucket
# and comparing this date's deviation from that bucket's mean. If it is within the standard deviation for
# each bucket then consider it a good match.
sub _distinct_check {
	my $self = shift;
	
	# Temporarily allow extra options
	validation_options( allow_extra => 1 );
	my %opts = validate(@_, {
		date        	 	 => { isa => 'DateTime' },				   # The date to check
		distinct_buckets 	 => { type => HASHREF },				   # List of enabled buckets
		callbacks 	     	 => { type => ARRAYREF,   optional => 1 }, # A list of custom coderefs that are called on each possible prediction
	});
	validation_options( allow_extra => 0 );
	
	my $date             = $opts{'date'};
	my $distinct_buckets = $opts{'distinct_buckets'};
	my $callbacks        = $opts{'callbacks'};
	
	my $good = 1;
	my $date_deviation = 0;
	foreach my $bucket (values %$distinct_buckets) {
		# Get the value for this bucket's access for the $new_date
		my $cref = $date->can( $bucket->accessor );
		my $datepart_val = &$cref($date);
		
		# If the deviation of this datepart from the mean is within the standard deviation, 
		# this date ain't good.
		
		my $deviation = abs($datepart_val - $bucket->{mean});
		$date_deviation += $deviation;
		
		if ($deviation > $bucket->{stdev} )  {
			$good = 0;
			last;
		}
	}
	
	# All the dateparts were within their standard deviations, check for callbacks and push this date into the set of predictions
	if ($good == 1) {
		# Stick the date's total deviation into the object so it can be used for sorting in predict()
		$date->{_dtp_deviation} += $date_deviation;
		
		# Run each hook we were passed
		foreach my $callback (@$callbacks) {
			# If any hook returns false, this date is a no-go and we can stop processing it
			if (! &$callback($date)) {
				$good = 0;
				last;
			}
		}
		
		# If the date is still considered good, return true
		if ($good == 1) {
			return 1;
		}
		# Otherwise return false
		else {
			return 0;
		}
	}
}

# Check to see if a given date is good according to the supplied interval buckets by going through each bucket
# and comparing this date's deviation from that bucket's mean. If it is within the standard deviation for
# each bucket then consider it a good match.
sub _interval_check {
	my $self = shift;
	
	# Temporarily allow extra options
	validation_options( allow_extra => 1 );
	my %opts = validate(@_, {
		date        	 	 => { isa => 'DateTime' },				   # The date prediction to check
		most_recent_date 	 => { isa => 'DateTime' },                 # The most recent date of the dates provided
		interval_buckets 	 => { type => HASHREF },				   # List of enabled interval buckets
		callbacks 	     	 => { type => ARRAYREF,   optional => 1 }, # A list of custom coderefs that are called on each possible prediction
	});
	validation_options( allow_extra => 0 );
	
	my $date             = $opts{'date'};
	my $most_recent_date = $opts{'most_recent_date'};
	my $interval_buckets = $opts{'interval_buckets'};
	my $callbacks        = $opts{'callbacks'};
	
	# Flag specifying whether the predicted date is "good" (within the standard deviation) or not
	my $good = 1;
	
	# Total deviation of the predicted date from each of the bucket standard deviations
	my $date_deviation = 0;
	
	# Get a duration object for the span between the most recent date supplied and the predicted date
	#my $dur = $date->subtract_datetime( $most_recent_date );
	
	foreach my $bucket (values %$interval_buckets) {
		#my $cref = $dur->can( $bucket->accessor );
		#	croak "Can't call accessor '" . $bucket->accessor . "' on " . ref($dur) . " object" unless $cref;
		#my $interval = &$cref($dur);
		#my $interval = $dur->in_units( $bucket->accessor );
		
		my $interval = $self->_get_date_interval($bucket->name, $bucket->accessor, $date, $most_recent_date);
		
		my $deviation = abs($interval - $bucket->{mean});
		$date_deviation += $deviation;
		
		print "DATE: $date\n";
		print "NAME: " . $bucket->name . "\n";
		print "INTERVAL: $interval\n";
		print "MEAN: " . $bucket->{mean} . "\n";
		print "BUCKET STDEV: " . $bucket->{stdev} . "\n";
		print "THIS DEVIATION: $deviation\n";
		
		if ($deviation > $bucket->{stdev} )  {
			print "Not good!\n";
			$good = 0;
			last;
		}
	}
	
	# All the dateparts were within their standard deviations, check for callbacks and push this date into the set of predictions
	if ($good == 1) {
		# Stick the date's total deviation into the object so it can be used for sorting in predict()
		$date->{_dtp_deviation} += $date_deviation;
		
		# Run each hook we were passed
		foreach my $callback (@$callbacks) {
			# If any hook returns false, this date is a no-go and we can stop processing it
			if (! &$callback($date)) {
				$good = 0;
				last;
			}
		}
		
		# If the date is still considered good, return true
		if ($good == 1) {
			return 1;
		}
		# Otherwise return false
		else {
			return 0;
		}
	}
}

# Get the interval between two dates for a certain bucket ('days', 'hours', etc).
sub _get_date_interval {
	my $self = shift;
	my ($bucket_name, $bucket_accessor, $date1, $date2) = @_;
	
	my $interval;
	
	# Special hackiness for fake cluster bucket
	if ($bucket_name eq 'cluster') {
		$interval = $date1->hires_epoch() - $date2->hires_epoch();
	}
	# All other date parts
	else {
		my $dur = $date1->subtract_datetime( $date2 );
	
		my $cref = $dur->can( $bucket_accessor );
			croak "Can't call accessor '" . $bucket_accessor . "' on " . ref($dur) . " object" unless $cref;
		$interval = &$cref($dur);
	}
	
	return $interval;
}

# Generate the bucket statistics with _bucket_statistics and stick it in the bucket
sub _generate_bucket_statistics {
	my $self = shift;
	my ($bucket) = @_;
	
	validate_pos(@_, { type => HASHREF });
	
	my ($mean, $variance, $stdev) = $self->_bucket_statistics($bucket);
	
	$bucket->{mean}     = $mean;
	$bucket->{variance} = $variance;
	$bucket->{stdev}    = $stdev;
	
	return $bucket;
}

# Get the mean, variance, and standard deviation for a bucket
sub _bucket_statistics {
	my $self   = shift;
	my $bucket = shift;
	
	my $total = 0;
	my $count = 0;
	while (my ($value, $occurances) = each %{ $bucket->{buckets} }) {
		# Gotta loop for each time the value has been found, incrementing the total by the value
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

# Cluster the dates with the S-means algorithm. Returns a hashref of cluster information
sub _cluster_dates {
	my $self  = shift;
	my @dates = @_;
	
	return if ! (@dates);
	
	# Get the variance and std dev for the distances between sequential dates
	my $tot_diff = 0;
	my @diffs    = ();
	foreach my $i (1 .. $#dates) { #Skip the 0th element since nothing precedes it
		my $diff = $dates[ $i ]->hires_epoch - $dates[ $i - 1 ]->hires_epoch;
		$tot_diff += $diff;
		push(@diffs, $diff);
	}
	
	my $mean_diff = $tot_diff / scalar @diffs;
	
	# Get the variance & std dev
	my $sum_diff_variance = 0;
	foreach my $diff (@diffs) {
		$sum_diff_variance += ($diff - $mean_diff) ** 2;
	}
	my $diff_variance = $sum_diff_variance / scalar @diffs;
	my $diff_stdev = sqrt($diff_variance);
	
	#Cluster them!
	my %clusters = ();
	
	## S-means
	my $change    = 1; # Flag for whether the clusters are changing or not, stop when it's 0
	my $k         = 1; # Initial number of clusters
	my $threshold = $diff_stdev; # Similarity threshold
	
	# Randomly choose [k] centroids from among the data points
	# *** Could we use k-means++ here instead?
	my %cluster_map = ();
	foreach my $i (1 .. $k) {
		my $centroid = $dates[rand @dates]->clone;
		$cluster_map{ $i } = {
			i        => $i,
			centroid => $centroid,
			elements => {}
		};
	}
	
	while ($change == 1) {
		# Flag for if a new cluster was made this iteration
		my $new_cluster = 0;
		
		# For each data point
		foreach my $date (@dates) {
			my $closest_dist;    # Closest distance to this data point
			my $closest_cluster; # Closest centroid to this data point
			
			# For each cluster
			while (my ($ci, $cluster) = each %cluster_map) {
				# Get the distance from this point to the cluster centroid
				my $dist = abs($date->hires_epoch - $cluster->{centroid}->hires_epoch);
				
				# If this distance is closer than the closest recorded distance, reset the closest
				#   distance and cluster
				if (! defined $closest_dist || $dist < $closest_dist) {
					$closest_dist    = $dist;
					$closest_cluster = $cluster;
				}
			}
			
			# If the distance is below the threshold, add it to this cluster
			if ($closest_dist < $threshold) {
				$closest_cluster->{elements}->{ $date->hires_epoch } = $date;
			}
			# Otherwise create a new cluster with this data point as the centroid,
			#   also add this data point to the new cluster
			else {
				my $max_ci = max keys %cluster_map;
				$max_ci++;
				$cluster_map{ $max_ci } = {
					i 		 => $max_ci,
					centroid => $date->clone,
					elements => {
						$date->hires_epoch => $date,
					}
				};
			}
		}
		
		my $cluster_changed = 0;
		
		# For each cluster
		while (my ($ci, $cluster) = each %cluster_map) {
			# Delete clusters that have no elements
			if (scalar keys %{ $cluster->{elements} } == 0) {
				delete $cluster_map{ $ci };
				next;
			}
	
			# Calculate the average Euclidean distance to each of its elements (since we're one dimensional here it's just the mean)
			my $tot   = 0;
			my $count = 0;
			foreach my $date (values %{ $cluster->{elements} }) {
				$tot += $date->hires_epoch;
				$count++;
			}
			my $new_centroid = $tot / $count;
			
			#If this newly calculated centroid is different than the current one, assign it
			if ($new_centroid != $cluster->{centroid}->hires_epoch) {
				$cluster->{centroid} = DateTime->from_epoch( epoch => $new_centroid );
				
				# Flip the cluster changed flag
				$cluster_changed = 1;
			}
		}
		
		# If no cluster was changed and no new cluster was created, we're done clustering
		if (! $cluster_changed && ! $new_cluster) {
			$change = 0;
		}
	}
	
	#use Data::Dumper; print Dumper(\%cluster_map);
	
	
	# Get the average difference between each cluster centroid, as well as the average difference
	#   between the first and last element of each centroid
	my $centroid_tot_diff  = 0;
	my $firstlast_tot_diff = 0;
	my $prev_cluster;
	foreach my $cluster (sort { $a->{centroid}->hires_epoch <=> $b->{centroid}->hires_epoch } values %cluster_map) {
		if (! defined $prev_cluster) {
			$prev_cluster = $cluster;
			next;
		}
		
		# Add onto the total centroid difference
		$centroid_tot_diff += ( $cluster->{centroid}->hires_epoch - $prev_cluster->{centroid}->hires_epoch );
		
		# Add onto the total difference between the first and last elements of each neighbor cluster
		my @sorted_cluster      = (sort {$a <=> $b } keys %{$cluster->{elements}});
		my @sorted_prev_cluster = (sort {$a <=> $b } keys %{$prev_cluster->{elements}});
		
		my $diff = $sorted_cluster[0] - $sorted_prev_cluster[ $#sorted_prev_cluster ];
		$firstlast_tot_diff += $diff;
		
		$prev_cluster = $cluster;
	}
	my $centroid_diff_mean  = $centroid_tot_diff  / ((scalar keys %cluster_map) - 1);
	my $firstlast_diff_mean = $firstlast_tot_diff / ((scalar keys %cluster_map) - 1);
	
	# Get the variance and standard deviation in cluster interval differences
	my $firstlast_diff_tot_variance = 0;
	undef $prev_cluster;
	foreach my $cluster (sort { $a->{centroid}->hires_epoch <=> $b->{centroid}->hires_epoch } values %cluster_map) {
		if (! defined $prev_cluster) {
			$prev_cluster = $cluster;
			next;
		}
		
		# Add onto the total variance between the first and last elements of each neighbor cluster and the mean
		my @sorted_cluster      = (sort {$a <=> $b } keys %{$cluster->{elements}});
		my @sorted_prev_cluster = (sort {$a <=> $b } keys %{$prev_cluster->{elements}});
		
		my $diff = (($sorted_cluster[0] -
			        $sorted_prev_cluster[ $#sorted_prev_cluster ]) - $firstlast_diff_mean) ** 2;
		            
		
		$firstlast_diff_tot_variance += $diff;
			
		$prev_cluster = $cluster;
	}
	my $firstlast_diff_variance = $firstlast_diff_tot_variance / ((scalar keys %cluster_map) - 1);
	my $firstlast_diff_stdev    = sqrt($firstlast_diff_variance);
	
	# Get the most recent cluster based on its centroid
	my $most_recent_cluster = (sort { $b->{centroid}->hires_epoch <=> $a->{centroid}->hires_epoch } values %cluster_map)[0];
	
	## Get some statistics on the clusters (average number of elements, standard deviation, etc)
	# Get the mean
	my $num_elements_total = 0;
	foreach my $cluster (values %cluster_map) {
		$num_elements_total += (scalar keys %{$cluster->{elements}});
	}
	my $num_elements_mean = $num_elements_total / scalar keys %cluster_map;
	
	# Get the variance and then the standard deviation
	my $sum_num_elements_variance = 0;
	foreach my $cluster (values %cluster_map) {
		$sum_num_elements_variance += ((scalar keys %{$cluster->{elements}}) - $num_elements_mean) ** 2;
	}
	my $num_elements_variance = $sum_num_elements_variance / scalar keys %cluster_map;
	my $num_elements_stdev = sqrt($num_elements_variance);
	
	#print "AVG FIRST LAST DIFF: $avg_firstlast_diff\nAVG CENTROID DIFF: $avg_centroid_diff\n";
	
	# Return a hashref of cluster info
	return {
		firstlast_diff_mean     => $firstlast_diff_mean,
		firstlast_diff_variance => $firstlast_diff_variance,
		firstlast_diff_stdev    => $firstlast_diff_stdev,
		centroid_diff_mean      => $centroid_diff_mean,
		clusters                => [values %cluster_map],
		num_clusters            => (scalar keys %cluster_map),
		most_recent_cluster     => $most_recent_cluster,
		num_elements_mean       => $num_elements_mean,
		num_elements_variance   => $num_elements_variance,
		num_elements_stdev      => $num_elements_stdev,
	};
}

# Whether this instance has been trained by train() or not
sub _is_trained {
	my $self = shift;
	
	return ($self->{trained} > 0) ? 1 : 0;
}  

# Utility method to print out the dates added to this instance
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
	my $smallest_bucket = $buckets[0];
	
	if (! defined $smallest_bucket || ! $smallest_bucket || ! @buckets) {
		return @dates;
	}
	
	my @new_dates = ();
	foreach my $date (@dates) {
		confess "Can't trim a non-DateTime value" unless $date->isa( 'DateTime' );
		
		my $new_date = $date->clone->truncate( to => $smallest_bucket->trim_to );
		
		push(@new_dates, $new_date);
	}
	
	return (wantarray) ? @new_dates : $new_dates[0];
}

# Useless syntactic sugar
sub _trim_date {
	return (wantarray) ? &_trim_dates(@_) : (&_trim_dates(@_))[0];
}

# Convert seconds to other datetime units. We don't care about precision
sub _convert_seconds {
	my $self    = shift;
	my $seconds = shift;
	my $units   = shift;
	
	return if ! $seconds || ! $units;
	
	if ($units eq 'nanoseconds') {
		return $seconds * 1_000_000_000;
	}
	elsif ($units eq 'seconds' || $units eq 'cluster') {
		return $seconds;
	}
	elsif ($units eq 'minutes') {
		return $seconds / 60;
	}
	elsif ($units eq 'hours') {
		return $seconds / 60 / 60;
	}
	elsif ($units eq 'days') {
		return $seconds / 60 / 60 / 24;
	}
	elsif ($units eq 'weeks') {
		return $seconds / 60 / 60 / 24 / 7;
	}
	elsif ($units eq 'months') {
		return $seconds / 60 / 60 / 24 / 30;
	}
	elsif ($units eq 'years') {
		return $seconds / 60 / 60 / 24 / 365;
	}
	else {
		confess("Improper units '$units' provided");
	}
}


1; # End of DateTime::Event::Predict
    
__END__
    
=pod
    
=head1 NAME

DateTime::Event::Predict - Predict new dates from a set of dates

=head1 SYNOPSIS

Given a set of dates this module will predict the next date or dates to follow.

  use DateTime;
  use DateTime::Event::Predict;

  my $dtp = DateTime::Event::Predict->new(
      profile => {
          interval_buckets => ['days'],
      },
  );

  # Add today's date: 2009-12-17
  my $date = new DateTime->today();
  $dtp->add_date($date);

  # Add the previous 14 days
  for  (1 .. 14) {
      my $new_date = $date->clone->add(
          days => ($_ * -1),
      );

      $dtp->add_date($new_date);
  }

  # Predict the next date
  my $predicted_date = $dtp->predict;

  print $predicted_date->ymd;

  # 2009-12-18

Here we create a new C<DateTime> object with today's date (it being December 17th, 2009 currently). We
then use L<add_date|"add_date"> to add it onto the list of dates that C<DateTime::Event::Predict> (hereafter DTP)
will use to make the prediction.

Then we take the 14 previous days (December 16-2) and them on to same list one by one. This gives us a
good set to make a prediction out of.

Finally we call L<predict|"predict"> which returns a C<DateTime> object representing the date that DTP has
calculated will come next.

=head1 HOW IT WORKS

Predicting the future is not easy, as anyone except, perhaps, Nostradamus will tell you. Events can occur
with perplexing randomness and discerning any pattern in the noise is nigh unpossible.

However, if you have a set of data to work with that you know for certain contains some sort of
regularity, and you have enough information to discover that regularity, then making predictions from
that set can be possible. The main issue with our example above is the tuning we did with this sort
of information.

When you configure your instance of DTP, you will have to tell what sorts of date-parts to keep
track of so that it has a good way of making a prediction. Date-parts can be things like
"day of the week", "day of the year", "is a weekend day", "week on month", "month of year", differences
between dates counted by "week", or "month", etc. DTP will collect these identifiers from all the
provided dates into "buckets" for processing later on. For more on buckets see L<DateTime::Event::Predict::Profile/Buckets>.

=head1 EXAMPLES

=over 4

=item Predicting the Average First Frost

=item Predicting Easter

=back

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

Adds a date on to the list of dates in the instance, where C<$date> is a L<DateTime|DateTime> object.

=head2 add_dates

Arguments: @dates

Add a list of dates onto the list of dates in this instance.

=head2 profile

Arguments: $profile

Set the profile for which date-parts will be 

  # Pass in preset profile by its alias
  $dtp->profile( profile => 'default' );
  $dtp->profile( profile => 'holiday' );

  # Create a new profile
  my $profile = new DateTime::Event::Predict::Profile(
      buckets => [qw/ minute hour day_of_week day_of_month /],
  );

  $dtp->profile( profile => $profile );

=head3 Provided profiles

The following profiles are provided for use by-name:

  default
  holiday
  daily

=head2 predict

Arguments: %options

Return Value: $next_date | @next_dates

Predict the next date(s) from the dates supplied.

  my $predicted_date = $dtp->predict();
  
If list context C<predict> returns a list of all the predictions, sorted by their probability:

  my @predicted_dates = $dtp->predict();

The number of predictions can be limited with the C<max_predictions> option.

  $dtp->predict(
      max_predictions => 4, # Once 4 predictions are found, return back
      callbacks => [
          sub { return ($_->second % 4) ? 0 : 1 } # Only predict dates with second values that are divisible by four.
      ],
  );
  
=over 4

=item max_predictions

Maximum number of predictions to find.

=item callbacks

Arrayref of subroutine callbacks. If any of them return a false value the date will not be returned as a prediction.

=back

=head2 train

Train this instance of DTP

=head1 TODO
 
=head1 AUTHOR

Brian Hann, C<< <brian.hann at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests through the web interface at Lhttp://github.com/c0bra/dtpredict/issues>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc DateTime::Event::Predict


You can also look for information at:

=over 4

=item * Github's Issue Tracker

L<http://github.com/c0bra/dtpredict/issues>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/DateTime-Event-Predict>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/DateTime-Event-Predict>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2010 Brian Hann, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<DateTime>, L<DateTime::Event::Predict::Profile>

=cut
