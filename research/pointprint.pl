#!/usr/bin/perl

use strict;
use Data::Dumper;

my $dates = shift @ARGV;
my @dates = split(/,/, $dates);


#my @dates = (112,91,94,110,98,106,103,109,107,123,117,129,135,123,122,116,122,98,115,134,93,101,125,111,116,119,123,108,129,59,120,109,112,119,30,91,117,83,103,111,106,113,100,100,102,109,88,100,110,127,95,102,106,105,109,116,107,102,110,124,97,115,104,119,103,121,107,106,121,100,118,118,114,96,89,95,100,100,103,95,102,124,96,111,96,104,82,111,109,96,99,112,95,90,101,102,89,93,95,97,95,97,104,80,85,99,107,95,100,103,93,84,105,106);

#print "DATES: " . scalar @dates . "\n";
my $count = scalar @dates;
my $total = 0;
map { $total += $_ } @dates;
my $mean = $total / $count;

my %dh = map { $_ => 0 } @dates;

my $tot_dev = 0;
foreach my $d (@dates) {
	$dh{$d}++;

	$tot_dev += ($d - $mean) ** 2;
}
my $std_dev = sqrt($tot_dev / $count);

my @arr = ();
my $max_y = 0;
my $tot_y = 0;
$count = 0;
while (my ($d, $c) = each %dh) {
	push(@arr,"[$d, $c]");
	$max_y = $c if $c > $max_y;
	$tot_y += $c;
	$count++;
}
my $avg_y = $tot_y / $count;

print join(',', @arr) . "\n";

#warn Dumper(\@dates); exit;

my @sort = sort { $a <=> $b } @dates;
#print Dumper(\@sort);

print "MIN: " . $sort[0] . "\n";
print "MAX: " . $sort[$#sort] . "\n";
print "MAXY: $max_y\n";
print "AVGY: $avg_y\n";
print "MEAN: $mean\n";
print "STD DEV: $std_dev\n";

#warn Dumper(\%dh);
