#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use DateTime;
use List::Util qw(max);

our $debug = $ENV{DEBUG};
local($|) = 1;

# Number of clusters
our $k = 2;

# Examinetics!
my @s;
#@s = (1, 9, 10, 203, 152, 78, 264, 1, 10, 132, 219, 104, 232, 65, 31, 106, 149, 107, 231, 18, 64, 232, 224, 97);
#my @s = (1, 1, 36, 63, 178, 27, 161, 26, 34, 32, 31, 84, 178, 45, 189, 17, 25, 46, 126, 249, 28, 31, 16, 45# 111, 139, 11);
#@s = (83, 1, 283, 2, 5, 2, 9, 132, 2, 3, 5,#21, 3, 118, 42);
#@s = (189, 4, 224, 83, 1, 283, 2, 5, 2, 9, 132, 2, 3, 5# 21, 351, 406, 51, 77, 40, 50, 107, 265, 39, 78, 113, 129, 171, 91, 42, 48, 39, 90, 83, 26, 28, 170, 108, 26, 34, 34, 139, 35, 33, 12, 29, 30, 140, 35, 39, 28, 35, 35, 67, 39, 36, 22, 18, 21, 43, 24, 109, 651, 360, 23, 37, 156, 82, 186, 90, 13, 29, 21, 14, 10, 16, 10, 25, 9, 14, 18, 27, 25, 19, 25, 31, 26, 24, 21, 17, 20, 18, 17, 29, 27, 23, 83, 67, 18, 1, 32, 18, 27, 12, 17, 18, 22, 21, 15, 21, 11, 19, 23, 9, 23, 16, 17, 27, 26, 10, 35, 21, 18, 17, 18, 25, 8, 29, 23, 13, 29, 30, 21, 7, 14, 21, 19, 18, 19, 36, 19, 23, 31, 20, 21, 15, 16, 18, 27, 23, 18, 4, 9, 30, 25, 19, 22, 24, 28, 23, 28, 15, 29, 23, 27, 26, 39, 21, 26, 15, 24, 31, 25, 27, 24, 24, 33, 29, 24, 29, 39, 21, 37, 21, 28, 27, 14, 31, 37, 27, 33, 28, 30, 142, 41, 152, 56, 38, 40, 45, 55, 127, 30, 236, 23, 30, 31, 34, 117, 22, 66, 23, 33, 29, 158, 137, 30, 33, 61, 231, 17, 30, 59, 70, 57, 274, 199, 84, 131, 118, 67, 126, 75, 75, 160, 83, 106, 81, 167, 11, 113, 45, 101, 54, 207, 46, 70, 36, 213, 49, 53, 62, 22, 292, 28, 145, 79, 40, 35, 48, 42, 22, 55, 160, 72, 86, 42, 48, 117, 117, 202, 24, 104, 65, 42, 6, 24, 10
@s = (405, 101, 85, 2, 3, 56, 1, 2, 2, 1, 1, 1, 3, 373, 105, 3, 56, 12, 71, 96, 38, 1, 2, 76, 3, 18, 13, 1, 36, 1, 20, 66, 1, 1, 1, 30, 1, 2, 266, 39, 98, 109, 23, 2, 61, 6, 13);

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



my %centroids = ();

## K-means++ to find centroids ##
#Grab a random data point and use it as the first center
my $c1 = $s[rand @s];
$centroids{ $c1 } = 1;

K: foreach my $kplus (2 .. $k) {
	my %dists = (); #Distances
	#For each data point $x, calculate its distance from each centroid $c
	foreach my $x (@s) {
		next if exists $centroids{ $x };
		my $closest = "";
		my $cpoint = "";
		foreach my $c (keys %centroids) {
			#next if $x == $c; #Skip centroids we've already chosen
			my $dist = abs($x - $c);

			if (! $cpoint || $dist < $closest) {
				$cpoint  = $c;
				$closest = $dist;
			}
		}
		
		$dists{ $x } = $closest;
	}

	my $nc = (sort { $dists{$b} <=> $dists{$a} } keys %dists)[0];

	$centroids{$nc} =  1;
}

#Map of cluster centroids and their elements, use an incremental value as the cluster "id",
# this will allow us to find if k-means is finished changing centroid locations or not
my $i = 0;
my %cmap = map { ++$i => { centroid => $_, elements => {} } } keys %centroids;
#Map of the data elements and their centroids
my %xmap = map { $_ => undef } @s;

#Continuously reassign data points to clusters, and move the centroids around 
# until the centroids stop moving (and thus data points are assigned to their
# final cluster
while (1) {
	#Whether any data point has changed clusters or not
	my $x_changed = 0;

	#For each data point
	foreach my $x (@s) {
		#Compare it to a cluster centroid	
		my $newc = "";
		my $nearest_dist = $max * 2;
		while (my ($cid, $val) = each %cmap) {
			my $centroid = $val->{centroid};

			#If this data point hasn't been assigned to a centroid, assign it to the first one
			if (! defined $xmap{ $x }) {
				$newc = $cid;
				$nearest_dist = abs($x - $centroid);
			}
			#Otherwise, computer the distance to each cluster centroid, assign this point to the nearest one
			else {
				my $dist = abs($x - $centroid);
				$dist = (defined $dist) ? $dist : 0;

				if ($dist <= $nearest_dist) {
					$newc = $cid;
					$nearest_dist = $dist;
				}
			}
		}

		#Assign this point to a new cluster, if we've found one, and switch the flag so we
		# know points have been reassigned
		if ((! defined $xmap{ $x }) || ($newc && $newc != $xmap{ $x })) {
			#Remove this data point from its current cluster if it's assigned
			my $curc = $xmap{ $x };
			if (defined $curc) {
				delete $cmap{ $curc }->{elements}->{$x};
			}

			#Assign it to the new cluster
			$cmap{ $newc }->{elements}->{$x} = 1;
			$xmap{ $x } = $newc;
			
			#Mark the flag
			$x_changed = 1;
		}
	}
	
	#For each cluster
	my $cluster_changed = 0;
	while (my ($cid, $val) = each %cmap) {
		#Skip clusters that have no elements
		next if (scalar keys %{ $val->{elements} } == 0);

		#Calculate the distance to each of its elements (since we're one dimensional here it's just the mean)
		my $centroid = $cmap{ $cid }->{centroid};
		my $tot   = 0;
		my $count = 0;
		foreach my $x (keys %{ $val->{elements} }) {
			$tot += $x;
			$count++;
		}
		
		#If this newly calculated centroid is different than the current one, assign it
		my $newc = $tot / $count;
		if ($newc != $centroid) {
			$cmap{ $cid }->{centroid} = $newc;
			$cluster_changed = 1;
		}
	}

	#Quit if no data elements have changed clusters
	last if $x_changed == 0;
}

print Dumper(\%cmap);