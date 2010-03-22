#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use DateTime;
use List::Util qw(max);

our $debug = $ENV{DEBUG};
local($|) = 1;

# Data elements
#my @s = (1, 2, 3, 4, 5, 6, 7, 8, 9, 10);
#my @s = (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12);
#my @s = (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 16);
#my @s = (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 200);
#my @s = (1, 2, 3, 21, 22, 23, 41, 42, 43);
#my @s = (1, 2, 3, 4, 35, 36, 37, 91, 92, 256, 257, 258);
#my @s = (5, 12, 18, 102, 113, 116, 201, 215, 220);
#my @s = (1, 2, 3, 4, 5, 6, 5, 5, 6, 5, 80, 81, 82, 84, 80);

# Gaussian distribution 20 20
#my @s = (100, 98, 100, 98, 101, 99, 100, 98, 100, 97, 99, 100, 98, 99, 100, 100, 101, 100, 99, 99, 200, 199, 199, 199, 198, 199, 201, 200, 200, 200, 200, 199, 200, 198, 200, 198, 201, 198, 199, 200, 297, 301, 299, 301, 300, 299, 298, 299, 300, 302, 299, 299, 299, 299, 300, 300, 300, 301, 299, 299, 401, 400, 399, 399, 399, 400, 400, 400, 399, 399, 399, 399, 400, 400, 399, 399, 400, 399, 399, 399, 499, 500, 499, 500, 497, 498, 499, 500, 498, 500, 499, 500, 500, 498, 499, 499, 498, 500, 500, 501, 600, 600, 599, 600, 600, 598, 599, 599, 599, 599, 599, 600, 598, 599, 599, 600, 599, 598, 601, 599, 699, 700, 702, 702, 701, 700, 699, 700, 701, 697, 702, 699, 699, 699, 699, 702, 700, 698, 700, 698, 798, 798, 799, 801, 799, 799, 800, 799, 799, 801, 798, 800, 798, 799, 800, 798, 798, 799, 798, 801, 899, 898, 900, 903, 900, 899, 901, 900, 899, 899, 900, 898, 900, 901, 900, 900, 898, 901, 899, 899, 999, 999, 1000, 999, 1000, 1000, 999, 999, 1000, 999, 1000, 999, 999, 999, 1001, 1000, 999, 999, 1001, 999, 1100, 1099, 1101, 1099, 1099, 1101, 1098, 1100, 1101, 1100, 1099, 1099, 1098, 1100, 1098, 1100, 1100, 1099, 1099, 1099, 1201, 1200, 1200, 1201, 1199, 1199, 1200, 1200, 1197, 1200, 1200, 1198, 1199, 1201, 1199, 1199, 1200, 1198, 1199, 1199, 1298, 1300, 1300, 1299, 1300, 1298, 1299, 1298, 1300, 1298, 1300, 1299, 1301, 1298, 1302, 1299, 1298, 1299, 1300, 1300, 1400, 1400, 1399, 1398, 1400, 1399, 1399, 1398, 1399, 1399, 1400, 1401, 1397, 1399, 1398, 1399, 1399, 1399, 1400, 1399, 1500, 1501, 1500, 1500, 1498, 1499, 1500, 1499, 1500, 1501, 1499, 1498, 1500, 1499, 1501, 1499, 1499, 1500, 1499, 1500, 1601, 1597, 1598, 1600, 1600, 1599, 1599, 1599, 1600, 1600, 1601, 1598, 1600, 1602, 1598, 1600, 1601, 1599, 1600, 1598, 1700, 1699, 1700, 1699, 1699, 1700, 1700, 1700, 1701, 1699, 1701, 1700, 1699, 1701, 1699, 1699, 1700, 1698, 1698, 1700, 1800, 1800, 1801, 1800, 1800, 1800, 1800, 1797, 1799, 1800, 1798, 1801, 1800, 1799, 1798, 1799, 1799, 1799, 1798, 1800, 1899, 1900, 1901, 1900, 1902, 1900, 1899, 1902, 1901, 1900, 1901, 1900, 1900, 1898, 1898, 1898, 1900, 1900, 1898, 1899, 2000, 1999, 2000, 1998, 1998, 1998, 2001, 2001, 1998, 1999, 2001, 2001, 2000, 2000, 1999, 1999, 2002, 1999, 2000, 1999);

# Gaussian distribution 21 5
#my @s = (100, 101, 99, 100, 100, 201, 200, 199, 199, 200, 299, 300, 300, 299, 299, 399, 400, 401, 399, 400, 499, 498, 501, 501, 498, 600, 600, 599, 599, 599, 700, 699, 700, 699, 700, 800, 799, 799, 800, 800, 900, 900, 900, 899, 898, 1000, 999, 1000, 1000, 999, 1099, 1101, 1099, 1100, 1099, 1199, 1199, 1199, 1201, 1200, 1298, 1301, 1300, 1301, 1300, 1399, 1400, 1399, 1399, 1399, 1499, 1500, 1498, 1499, 1497, 1598, 1600, 1599, 1600, 1599, 1700, 1701, 1700, 1699, 1700, 1801, 1798, 1799, 1799, 1798, 1900, 1900, 1900, 1901, 1899, 1999, 2000, 1999, 1999, 2000, 2099, 2100, 2100, 2099, 2099);

my @dates;
#push(@dates, new DateTime( year => 2009, month => 5, day => 3 ));
#push(@dates, new DateTime( year => 2009, month => 5, day => 4 ));
#push(@dates, new DateTime( year => 2009, month => 5, day => 5 ));
#push(@dates, new DateTime( year => 2009, month => 5, day => 7 ));
#push(@dates, new DateTime( year => 2009, month => 5, day => 8 ));
#push(@dates, new DateTime( year => 2009, month => 6, day => 3 ));
#push(@dates, new DateTime( year => 2009, month => 6, day => 4 ));
#push(@dates, new DateTime( year => 2009, month => 6, day => 5 ));
#push(@dates, new DateTime( year => 2009, month => 7, day => 3 ));
#push(@dates, new DateTime( year => 2009, month => 7, day => 4 ));
#push(@dates, new DateTime( year => 2009, month => 7, day => 5 ));
push(@dates, new DateTime( year => 1966 ));
push(@dates, new DateTime( year => 1969 ));
my @s = sort map { $_->hires_epoch() } @dates;

my $scount = scalar @s;
my ($max,$min) = (sort { $b <=> $a } @s)[0,$#s];
my $diff = $max - $min;
my $stotal = 0;
map { $stotal += $_ } @s;
my $smean = $stotal / $scount;

#Get the variance for the data set
my $sum_variance = 0;
foreach my $x (@s) {
	$sum_variance += (($x - $smean) ** 2);
}
my $variance = $sum_variance / ($scount);
my $stdev = sqrt($variance);

print "COUNT: $scount\n";
print "VARIANCE: $variance\n";
print "STD DEV: $stdev\n";

#Get the variance and std dev for the distances between sequential elements of the data set
my $tot_diff = 0;
my @diffs = ();
foreach my $i (1 .. $#s) { #Skip the 0th element since nothing precedes it
	my $diff = $s[ $i ] - $s[ $i - 1 ];
	$tot_diff += $diff;
	push(@diffs, $diff);
}
my $mean_diff = $tot_diff / scalar @diffs;

#Get the variance & std dev
my $sum_diff_variance = 0;
foreach my $diff (@diffs) {
	$sum_diff_variance += ($diff - $mean_diff) ** 2;
}
my $diff_variance = $sum_diff_variance / scalar @diffs;
my $diff_stdev = sqrt($diff_variance);

print "DIFF MEAN: $mean_diff\n";
print "DIFF VARIANCE: $diff_variance\n";
print "DIFF STD DEV: $diff_stdev\n";


#Cluster them!
my %clusters      = ();
my %final_cluster = ();

## S-means
my $change    = 1; # Flag for whether the clusters are changing or not, stop when it's 0
my $k         = 1; # Initial number of clusters
my $threshold = $diff_stdev; # Similarity threshold

# Randomly choose [k] centroids from among the data points
# *** Could we use k-means++ here instead?
my %cmap = ();
foreach my $i (1 .. $k) {
	my $centroid = $s[rand @s];
	$cmap{ $i } = {
		i        => $i,
		centroid => $centroid,
		elements => {}
	};
}

while ($change == 1) {
	# Flag for if a new cluster was made this iteration
	my $new_cluster = 0;
	
	# For each data point
	foreach my $x (@s) {
		my $closest_dist;    # Closest distance to this data point
		my $closest_cluster; # Closest centroid to this data point
		
		# For each cluster
		while (my ($ci, $cluster) = each %cmap) {
			# Get the distance from this point to the cluster centroid
			my $dist = abs($x - $cluster->{centroid});
			
			if (! defined $closest_dist || $dist < $closest_dist) {
				$closest_dist    = $dist;
				$closest_cluster = $cluster;
			}
		}
		
		# If the distance is below the threshold, add it to this cluster
		if ($closest_dist < $threshold) {
			$closest_cluster->{elements}->{ $x } = 1;
		}
		# Otherwise create a new cluster with this data point as the centroid,
		#   also add this data point to the new cluster
		else {
			my $max_ci = max keys %cmap;
			$max_ci++;
			$cmap{ $max_ci } = {
				i 		 => $max_ci,
				centroid => $x,
				elements => {
					$x => 1,
				}
			};
		}
	}
	
	my $cluster_changed = 0;
	
	# For each cluster
	while (my ($ci, $cluster) = each %cmap) {
		# Delete clusters that have no elements
		if (scalar keys %{ $cluster->{elements} } == 0) {
			delete $cmap{ $ci };
			next;
		}

		# Calculate the distance to each of its elements (since we're one dimensional here it's just the mean)
		my $tot   = 0;
		my $count = 0;
		foreach my $x (keys %{ $cluster->{elements} }) {
			$tot += $x;
			$count++;
		}
		
		#If this newly calculated centroid is different than the current one, assign it
		my $new_c = $tot / $count;
		if ($new_c != $cluster->{centroid}) {
			$cluster->{centroid} = $new_c;
			$cluster_changed = 1;
		}
	}
	
	if (! $cluster_changed && ! $new_cluster) {
		$change = 0;
	}
}

print "K: " . (scalar keys %cmap) . "\n";

my $tot_dist = 0;
my $prev_centroid;
foreach my $cluster (sort { $a->{centroid} <=> $b->{centroid} } values %cmap) {
	if (! defined $prev_centroid) {
		$prev_centroid = $cluster->{centroid};
	}
	
	$tot_dist += ( $cluster->{centroid} - $prev_centroid );
	
	$prev_centroid = $cluster->{centroid};
}
my $avg_dist = $tot_dist / ( (scalar keys %cmap) - 1);

print "AVG DIST: $avg_dist\n";

print Dumper(\%cmap);