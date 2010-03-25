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
#my @s = (1, 9, 10, 203, 152, 78, 264, 1, 10, 132, 219, 104, 232, 65, 31, 106, 149, 107, 231, 18, 64, 232, 224, 97);
my @s = (1, 1, 36, 63, 178, 27, 161, 26, 34, 32, 31, 84, 178, 45, 189, 17, 25, 46, 126, 249, 28, 31, 16, 45, 111, 139, 11);



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