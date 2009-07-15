#!/usr/bin/perl

use warnings;
use DateTime;
use Data::Dumper;

my @d = ();
my @diffs = ();
my $pdate = "";
my $tot_diff = 0;
open(my $fh, '<', 'easter_dates.txt') || die $!;
while (my $line = <$fh>) {
	next if $. == 1;
	chomp $line;
	my ($year, $dom) = split(/\s+/, $line);
	$year =~ s/\s//g;
	$dom  =~ s/\s//g;
	my ($month, $day) = split(m!/!, $dom);

	#print "$month / $day / $year\n";

	next if $year > 2009 || $year < 1975;

	my $dt = new DateTime(
		year => $year,
		month => $month,
		day => $day
	);

	push(@d, $dt);
}

foreach my $dt (sort @d) {
	if (! $pdate) { $pdate = $dt; }
	else {
		my $dur = $dt->delta_days($pdate);
		#warn Dumper($dur);

		my $diff = $dur->delta_days;

		#print "DUR: " . $diff . "\n";

		push(@diffs, $diff);

		$tot_diff += $diff;

		$pdate = $dt;
	}
}

my $mean_diff = $tot_diff / scalar(@diffs);
print "MEAN: $mean_diff\n";

#print join(",", @d);
#print join(",", @d);
