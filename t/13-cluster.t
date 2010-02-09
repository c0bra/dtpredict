#!perl

# Predict a date using where the supplied dates are clustered

use strict;
use Test::More tests => 1;

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

#$dtp->add_date($first_date);

# Add 2 dates, each [1..2] days back from $first_date
#for (1 .. 2) {
#	$dtp->add_date(
#		$first_date->clone->add( days => ($_) )
#	);
#}

# 3x: add 3 dates each one day apart. The cluster of 3 dates should be [10 * $cluster] days before $first_date
foreach my $cluster (1 .. 6) {
	foreach my $nday (1 .. 3) {
		$dtp->add_date(
			$first_date->clone->add( days => ( -1 * 10 * $cluster + $nday ) )
		);
	}
}

$dtp->train();

my $prediction = $dtp->predict( clustering => 1 );

ok(defined $prediction, 'Got a defined prediction back');

print $prediction . "\n";