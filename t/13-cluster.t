#!perl

# Predict a date using where the supplied dates are clustered

use strict;
use Test::More tests => 2;

use DateTime;
use DateTime::Event::Predict;

my $dtp = DateTime::Event::Predict->new(
	clustering => 1,
	profile => {
		interval_buckets => ['days'],
	}
);

my $first_date = DateTime->new(
	year  => 2010,
	month => 1,
	day   => 31,
);

# 3x: add 3 dates each one day apart. The cluster of 3 dates should be [7 * $cluster] days before $first_date
foreach my $cluster (1 .. 6) {
	foreach my $nday (1 .. 3) {
		$dtp->add_date(
			$first_date->clone->add( days => ( -1 * 7 * $cluster + $nday ) )
		);
	}
}

$dtp->_print_dates;

# Date list:
# 12/21/2009 00:00:00
# 12/22/2009 00:00:00
# 12/23/2009 00:00:00
# 12/28/2009 00:00:00
# 12/29/2009 00:00:00
# 12/30/2009 00:00:00
# 01/04/2010 00:00:00
# 01/05/2010 00:00:00
# 01/06/2010 00:00:00
# 01/11/2010 00:00:00
# 01/12/2010 00:00:00
# 01/13/2010 00:00:00
# 01/18/2010 00:00:00
# 01/19/2010 00:00:00
# 01/20/2010 00:00:00
# 01/25/2010 00:00:00
# 01/26/2010 00:00:00
# 01/27/2010 00:00:00

my $prediction = $dtp->predict( clustering => 1, max_predictions => 10 );

ok(defined $prediction, 'Got a defined prediction back');

SKIP: {
	skip "No prediction returned from predict()", 1 if ! $prediction;
	
	# Prediction should be the first element of the next cluster, 2010-02-01, not the last: 2010-02-03
	is($prediction->datetime, '2010-02-01T00:00:00', "Prediction is " . $prediction->datetime . ", should be 2010-02-01T00:00:00");
}

# Try removing the most recent date and get a prediction