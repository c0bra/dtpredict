#!/usr/bin/perl

use strict;
use Data::Dumper;

my @d = ();
foreach my $k (1 .. 20) {
	$k *= 100;
	for (1 .. 20) {
		my $n = &gaussian_rand;
		
		$n *= 1;
		$n += $k;
		$n = sprintf("%d", $n);
		
		push(@d, $n);
	}
}
print join(', ', @d) . "\n";

sub gaussian_rand {
    my ($u1, $u2);  # uniformly distributed random numbers
    my $w;          # variance, then a weight
    my ($g1, $g2);  # gaussian-distributed numbers

    do {
        $u1 = 2 * rand() - 1;
		$u2 = 2 * rand() - 1;
		$w = $u1*$u1 + $u2*$u2;
        #$w = $u1*$u1;
    } while ( $w >= 1 );

    $w = sqrt( (-2 * log($w))  / $w );
    $g2 = $u1 * $w;
	$g1 = $u2 * $w;
    # return both if wanted, else just one
    return wantarray ? ($g1, $g2) : $g1;
}

