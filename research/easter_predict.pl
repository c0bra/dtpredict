#!/usr/bin/perl

use strict;
use lib qw( ../lib );
use DateTime::Event::Predict;

my $dtp = new DateTime::Event::Predict;

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

    $dtp->add_date($dt);
}

my @predictions = $dtp->predict;

print "PREDICTIONS:\n";
foreach my $d (@predictions) {
	print $d->mdy('/') . ' ' . $d->hms . "\n";
}