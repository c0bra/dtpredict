#!perl

use Test::More tests => 1;

use DateTime;
use DateTime::Event::Predict;
use DateTime::Event::Predict::Profile;

my $dtp = DateTime::Event::Predict->new(
	profile => {
		buckets => [qw/ year /],
	},
);

# Add todays date
for ( 1966, 1969 ) {
	my $victory = DateTime->new( year => $_ );
	$dtp->add_date($victory);
}

# Predict the next date
my $predicted_date = $dtp->predict;

print $predicted_date->year . "\n";

#use Data::Dumper; warn Dumper($dtp); exit;

ok(defined $predicted_date, 'Got a defined prediction back');