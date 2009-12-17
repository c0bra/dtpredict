#!/usr/bin/perl

use lib qw( ../lib );

use strict;
use Data::Dumper;

use DateTime::Event::Predict;

my $dtp = new DateTime::Event::Predict( profile => 'holiday' );

#warn Dumper($dtp); exit;

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

my @predictions = $dtp->predict( max_predictions => 5 );

print "PREDICTIONS:\n";
foreach my $d (@predictions) {
	print $d->mdy('/') . ' : ' . $d->{_date_deviation} . "\n";
}
