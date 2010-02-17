#!perl

# Test to see that specifying a non-existent bucket results in
#  a graceful failure

use strict;
use Test::More tests => 2;

use DateTime;
use DateTime::Event::Predict;

eval {
	my $dtp = new DateTime::Event::Predict(
		profile => {
			interval_buckets => ['iblah'],
		}
	);
};
ok($@, "Supplying bad interval bucket caused code to die");
#if ($@) { diag("Message: " . $@); }

eval {
	my $dtp = new DateTime::Event::Predict(
		profile => {
			distinct_buckets => ['dblah'],
		}
	);
};
ok($@, "Supplying bad distinct bucket caused code to die");
#if ($@) { diag("Message: " . $@); }