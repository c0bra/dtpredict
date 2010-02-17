#!perl

# Test to see if specifying an accessor for a datepart that isn't
#  used in the date causes a failure. For example, specify
#   nanoseconds for two dates that are just month and year.

use strict;
use Test::More tests => 1;

use DateTime;
use DateTime::Event::Predict;

my $dtp = DateTime::Event::Predict->new(
	profile => {
		interval_buckets => ['nanoseconds'],
	}
);

my $first_date = DateTime->new(
	year  => 2010,
	month => 1,
);

my $second_date = DateTime->new(
	year  => 2011,
	month => 1,
);

$dtp->add_dates($first_date, $second_date);

my $p = $dtp->predict();

ok(defined $p, "Got a defined prediction back");

SKIP: {
	skip "No prediction returned from predict()", 1 if ! $p;
	diag("Prediction is $p\n");
}