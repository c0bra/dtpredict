#!perl

use strict;
use Test::More tests => 1;

use DateTime;
use DateTime::Event::Predict;
use DateTime::Event::Predict::Profile;

TODO: {
	#todo_skip "Interval buckets not working yet", 1;
		
	my $dtp = DateTime::Event::Predict->new(
		profile => {
			distinct_buckets => ['year'],
			interval_buckets => ['years'],
		},
	);
	
	# Add todays date
	for ( 1962, 1966, 1969 ) {
		my $victory = DateTime->new( year => $_ );
		$dtp->add_date($victory);
	}
	
	$dtp->train();
	
	use Data::Dumper; print Dumper($dtp);
	
	# Predict the next date
	my $predicted_date = $dtp->predict;
	
	print $predicted_date->year . "\n";
	
	#use Data::Dumper; warn Dumper($dtp); exit;
	
	ok(defined $predicted_date, 'Got a defined prediction back');
};