#!perl

# Predict a date using years that ought to be clustered

use strict;
use Test::More tests => 2;

use DateTime;
use DateTime::Event::Predict;

my $dtp = DateTime::Event::Predict->new(
	clustering => 1,
	profile => {
		interval_buckets => ['days', 'hours'],
	}
);

my $first_date = DateTime->new(
	year  => 1965,
);

# 3x: add 3 dates each one day apart. The cluster of 3 dates should be [10 * $cluster] days before $first_date
my $year_inc = 6;
foreach my $cluster (1 .. 3) {
	foreach my $nyear (0 .. 2) {
		$dtp->add_date(
			$first_date->clone->add(
				years => ( ($cluster * $year_inc) + $nyear ),
			)
		);
	}
	
	#$year_inc += 3;
}

# Date list should be this, 3 clusters of 3 datetimes, each cluster separated by 4 years and each date in
# a cluster separated from its cluster bretheren by 1 year

# 01/01/1971 00:00:00
# 01/01/1972 00:00:00
# 01/01/1973 00:00:00
# 01/01/1977 00:00:00
# 01/01/1978 00:00:00
# 01/01/1979 00:00:00
# 01/01/1983 00:00:00
# 01/01/1984 00:00:00
# 01/01/1985 00:00:00

$dtp->_print_dates(); exit;

my $prediction = $dtp->predict( clustering => 1 );

ok(defined $prediction, 'Got a defined prediction back');

SKIP: {
	skip "No prediction returned from predict()", 1 if ! $prediction;
	is($prediction->datetime, '1989-01-01T00:00:00', "Prediction is " . $prediction->datetime . ", should be 1989-01-01T00:00:00");
}
