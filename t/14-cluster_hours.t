#!perl

# Predict a date using where the supplied dates are clustered

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
	year  => 2010,
	month => 1,
	day   => 31,
	hour  => 5
);

# 3x: add 3 dates each one day apart. The cluster of 3 dates should be [10 * $cluster] days before $first_date
foreach my $cluster (1 .. 6) {
	foreach my $nhour (1 .. 3) {
		$dtp->add_date(
			$first_date->clone->add(
				days  => ( -1 * $cluster ),
				hours => ( -1 * $nhour ),
			)
		);
	}
}

# Date list should be this, 6 clusters of 3 datetimes, each cluster separated by a day and each cluser
#  element separated from its sibling elements by 1 hour:
# 01/25/2010 02:00:00
# 01/25/2010 03:00:00
# 01/25/2010 04:00:00
# 01/26/2010 02:00:00
# 01/26/2010 03:00:00
# 01/26/2010 04:00:00
# 01/27/2010 02:00:00
# 01/27/2010 03:00:00
# 01/27/2010 04:00:00
# 01/28/2010 02:00:00
# 01/28/2010 03:00:00
# 01/28/2010 04:00:00
# 01/29/2010 02:00:00
# 01/29/2010 03:00:00
# 01/29/2010 04:00:00
# 01/30/2010 02:00:00
# 01/30/2010 03:00:00
# 01/30/2010 04:00:00

my $prediction = $dtp->predict( clustering => 1 );

ok(defined $prediction, 'Got a defined prediction back');

SKIP: {
	skip "No prediction returned from predict()", 1 if ! $prediction;
	is($prediction->datetime, '2010-01-31T02:00:00', "Prediction is " . $prediction->datetime . ", should be 2010-01-31T02:00:00");
}