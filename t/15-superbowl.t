#!perl

use strict;
use Test::More tests => 2;

use DateTime;
use DateTime::Event::Predict;
use DateTime::Event::Predict::Profile;


my $dtp = DateTime::Event::Predict->new(
	profile => {
		interval_buckets => ['years'],
	},
);

# Add todays date
for ( 1966, 1969 ) {
	my $victory = DateTime->new( year => $_ );
	$dtp->add_date($victory);
}

$dtp->train();

# Predict the next date
my $predicted_date = $dtp->predict(
	#clustering => 0,
);

#use Data::Dumper; warn Dumper($dtp); exit;

ok(defined $predicted_date, 'Got a defined prediction back');

SKIP: {
	skip "No prediction returned from predict()", 1 if ! $predicted_date;
	is($predicted_date->year, 1972, 'Predicted ' . $predicted_date->year . ', should be 1972');
}