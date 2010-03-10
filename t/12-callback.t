#!perl

# Predict a date using callbacks. Note that the stdev_limit has to be increased by a ton because
# clustering hasn't been figured out all the way yet

use Test::More tests => 2;

use DateTime;
use DateTime::Event::Predict;

my $dtp = DateTime::Event::Predict->new(
	profile => {
		distinct_buckets => ['day_of_week'],
	}
);

# Add a Thursday and a Friday
my $thursday = DateTime->new(
	year  => 2010,
	month => 1,
	day   => 28
);
my $friday = DateTime->new(
	year  => 2010,
	month => 1,
	day   => 29
);
$dtp->add_dates($thursday, $friday);

# Add the previous 4 sets of Friday and Thursday
for  (1 .. 4) {
	my $new_thurs = $thursday->clone->add(
		days => ($_ * 7 * -1)
	);
	
	my $new_fri = $friday->clone->add(
		days => ($_ * 7 * -1)
	);
	
	$dtp->add_dates($new_thurs, $new_fri);
}

$dtp->train();
#$dtp->_print_dates();

#use Data::Dumper; print Dumper($dtp);

# Make a prediction, but only allow dates that are Thursdays to be predicted
my $prediction = $dtp->predict(
	stdev_limit => 5,
	callbacks   => [
		sub {
			my $d = shift;
			return ($d->dow == 4) ? 1 : 0;
		}
	],
);

ok(defined $prediction, "Got a prediction back");

SKIP: {
	skip "No prediction returned from predict()", 1 if ! $prediction;
	is($prediction->dow, 4, "Prediction is a Thursday");
}
