#!/usr/bin/perl

use lib qw( ../lib );

use Data::Dumper;

use Date::Parse;
use DateTime::Event::Predict;

my $dtp = new DateTime::Event::Predict;

open(my $fh, '<', 'last_frost_dates.txt');
while (my $line = <$fh>) {
	chomp $line;
	next if ! $line;
	
	my ($month, $day, $year) = $line =~ m!(\d{2})/(\d{2})/(\d{4})!;
	
	my $dt = new DateTime(
		month => $month,
		day   => $day,
		year  => $year,
	);
	
	$dtp->add_date($dt);
}
close($fh);

$dtp->train();
	print "DTP: " . Dumper($dtp) . "\n"; exit;

$dtp->print_dates();
#$dtp->regress_predict_buckets();
$dtp->poisson_predict_days();
#$dtp->average_predict_days();
