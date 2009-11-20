#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use DateTime;

our $debug = $ENV{DEBUG};
local($|) = 1;

#Data elements
#my @s = (1, 2, 3, 4, 5, 6, 7, 8, 9, 10);
#my @s = (1, 2, 4, 5, 6, 7, 8, 9, 10, 12);
#my @s = (1, 2, 3, 21, 22, 23, 41, 42, 43, 61, 62, 63, 81, 82, 83);
#my @s = (1, 2, 3, 21, 22, 23, 41, 42, 43);
#my @s = (5, 12, 18, 102, 113, 116, 201, 215, 220);
#my @s = (1, 2, 3, 4, 5, 6, 5, 5, 6, 5, 80, 81, 82, 84, 80);
#my @s = (112,91,94,110,98,106,103,109,107,123,117,129,135,123,122,116,122,98,115,134,93,101,125,111,116,119,123,108,129,59,120,109,112,119,30,91,117,83,103,111,106,113,100,100,102,109,88,100,110,127,95,102,106,105,109,116,107,102,110,124,97,115,104,119,103,121,107,106,121,100,118,118,114,96,89,95,100,100,103,95,102,124,96);
#my @s = (100, 98, 102, 100, 100, 201, 202, 203, 201, 200, 299, 301, 302, 301, 305, 402, 400, 398, 400, 397, 495, 499, 498, 497, 501);
#my @s = (99, 99, 100, 98, 100, 97, 98, 101, 104, 97, 101, 94, 100, 98, 100, 99, 99, 95, 96, 98, 200, 202, 196, 201, 203, 198, 200, 198, 200, 196, 196, 197, 200, 199, 202, 201, 200, 201, 199, 199, 301, 299, 300, 300, 299, 295, 297, 299, 300, 299, 301, 296, 298, 299, 306, 300, 297, 301, 298, 298, 397, 399, 402, 403, 403, 399, 401, 399, 407, 397, 401, 400, 401, 401, 397, 402, 399, 402, 396, 401, 499, 500, 495, 501, 496, 498, 498, 501, 505, 499, 501, 500, 503, 505, 494, 502, 500, 498, 500, 498, 602, 598, 600, 596, 596, 599, 599, 600, 600, 600, 596, 600, 599, 603, 602, 601, 597, 601, 596, 603, 699, 700, 706, 698, 700, 698, 699, 700, 698, 704, 699, 702, 702, 703, 695, 701, 701, 697, 703, 702, 800, 801, 805, 799, 802, 799, 799, 796, 804, 800, 800, 797, 799, 803, 801, 804, 802, 800, 796, 801, 903, 901, 900, 895, 900, 898, 899, 898, 902, 901, 900, 898, 902, 900, 899, 901, 900, 898, 897, 897, 998, 1001, 998, 996, 1001, 1003, 1001, 994, 996, 999, 1002, 1001, 1000, 1001, 998, 999, 1004, 999, 1002, 999, 1103, 1099, 1101, 1099, 1101, 1102, 1100, 1093, 1098, 1097, 1103, 1097, 1102, 1102, 1097, 1100, 1098, 1097, 1095, 1097, 1200, 1199, 1198, 1199, 1200, 1194, 1202, 1202, 1204, 1199, 1198, 1199, 1200, 1197, 1199, 1203, 1198, 1197, 1201, 1199, 1299, 1300, 1301, 1295, 1301, 1297, 1303, 1302, 1300, 1304, 1295, 1303, 1301, 1299, 1301, 1299, 1301, 1296, 1299, 1297, 1399, 1400, 1398, 1400, 1403, 1399, 1401, 1399, 1403, 1400, 1402, 1398, 1398, 1402, 1401, 1400, 1402, 1401, 1397, 1402, 1499, 1499, 1501, 1499, 1500, 1497, 1493, 1501, 1500, 1501, 1499, 1500, 1498, 1496, 1498, 1499, 1499, 1500, 1500, 1503, 1598, 1600, 1600, 1601, 1595, 1601, 1604, 1599, 1600, 1600, 1597, 1603, 1597, 1599, 1596, 1598, 1598, 1597, 1598, 1600, 1699, 1698, 1701, 1698, 1700, 1699, 1699, 1698, 1697, 1700, 1698, 1701, 1699, 1698, 1700, 1699, 1705, 1694, 1702, 1702, 1799, 1802, 1802, 1796, 1798, 1804, 1797, 1799, 1800, 1798, 1801, 1796, 1800, 1799, 1800, 1798, 1799, 1798, 1801, 1799, 1901, 1901, 1897, 1897, 1900, 1899, 1897, 1899, 1900, 1900, 1898, 1898, 1901, 1892, 1901, 1900, 1900, 1897, 1900, 1900, 1999, 1993, 1995, 2000, 1999, 2000, 1997, 1996, 2002, 2001, 1995, 1996, 2000, 2001, 2001, 1997, 2000, 1997, 1998, 2004);

my @dates;
push(@dates, new DateTime( year => 2009, month => 5, day => 3 ));
push(@dates, new DateTime( year => 2009, month => 5, day => 4 ));
push(@dates, new DateTime( year => 2009, month => 5, day => 5 ));
push(@dates, new DateTime( year => 2009, month => 5, day => 7 ));
push(@dates, new DateTime( year => 2009, month => 5, day => 8 ));
push(@dates, new DateTime( year => 2009, month => 6, day => 3 ));
push(@dates, new DateTime( year => 2009, month => 6, day => 4 ));
push(@dates, new DateTime( year => 2009, month => 6, day => 5 ));
push(@dates, new DateTime( year => 2009, month => 7, day => 3 ));
push(@dates, new DateTime( year => 2009, month => 7, day => 4 ));
push(@dates, new DateTime( year => 2009, month => 7, day => 5 ));
my @s = sort map { $_->hires_epoch() } @dates;
#print Dumper(\@s); exit;

my $scount = scalar @s;
my ($max,$min) = (sort { $b <=> $a } @s)[0,$#s];
my $diff = $max - $min;
my $stotal = 0;
map { $stotal += $_ } @s;
my $smean = $stotal / $scount;
my $Y = ($scount / 2);
#my $Y = (1 / 2);

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


#my $centered_total = 0;
#foreach my $x (keys %{ $val->{elements} }) {
#	$centered_total += ($x ** 2);
#}

my $exp_total = 0;
foreach my $x (@s) {
	$exp_total += sqrt( (abs($x - $smean) ** 2) * ($variance ** -1) );
}

my $exp_value = $exp_total / ($scount);
my $total_mahal_distance += $exp_value;
my $avg_distance = $total_mahal_distance;

my $distortion = $avg_distance ** ($Y * -1);

print "NO CLUSTER MAHAL: $distortion\n";


#Cluster them!
my %clusters      = ();
my @distortions   = (0);
my @Js = (0);
my $jcount = 0;
my %final_cluster = ();
#foreach my $k (1 .. scalar @s - 1) {
MLOOP: foreach my $k (1 .. $scount) {
#MLOOP: foreach my $k (4) {
	#print "--------------------------\n";
	#print "----   K$k Clusters    ----\n";
	#print "--------------------------\n";
	
	#foreach my $k (3) {
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
	
	#Skip this number of clusters if it has a cluster with no data elements, that's bad mojo
	foreach my $cluster (values %cmap) {
		if (scalar keys %{ $cluster->{elements} } == 0) { next MLOOP; }
	}
	
	$jcount++;

	#print Dumper(\%centroids);
	#print Dumper(\%cmap) if $k == 3;
	$clusters{ $k } = \%cmap;
	
	### Determine the distortion for this number of clusters. When we see the distortion start
	###  to fall off we'll know we've reached the right number
	# Go through each cluster, finding the distortion. Keep the smallest
	my $largest;
	my $total_mahal_distance = 0;
	while (my ($cid, $val) = each %cmap) {
		#Get the variance for the elements of this cluster
		my $variance;
		my $centered_total = 0;
		#my $count = 0;
		my $count = scalar keys %{ $val->{elements} };
		
		#***This appears to wildly skew results when the number of clusters approaches the number of data elements
		#next if ($count == 1); #Skip clusters where the single data element IS the centroid
		
		#my $xmean = 0;
		#map { $xmean += $_ } keys %{ $val->{elements} };
		#$xmean = $xmean / (scalar keys %{ $val->{elements} });
		
		#print "Xmean: $xmean\n";
		
		
		foreach my $x (keys %{ $val->{elements} }) {
			$centered_total += (($x - $val->{centroid}) ** 2);
			#$count++;
		}
		
		#$count++ if ($count <= 1);
		print "K$k count for centroid $val->{centroid}: $count, centered total: $centered_total\n" if $debug;
		#my $variance = 0;
		#if ($count == 1) {
		#	$variance = $centered_total;
		#}
		#elsif ($count > 0) {
			$variance = $centered_total / ($count); ####Uncomment this line for per-cluster variance
		#}
		#else {
		#	$smallest = 0;
		#	$variance = 0;
		#	next;
		#}
		print "Variance for centroid $val->{centroid} with $k clusters: $variance\n" if $debug;
		
		#$count++ if ($count <= 1);
		#Get the expected value
		my $exp_value;
		if ($count == 1) {
			$exp_value = 1;
		}
		else {
			my $exp_total = 0;
			foreach my $x (keys %{ $val->{elements} }) {
				$exp_total += sqrt( (($x - $val->{centroid}) ** 2) * ($variance ** -1) );
				#$exp_total += ( ($x - $val->{centroid}) * ($variance ** -1) * ($x - $val->{centroid}) );
				#$exp_total += ( ($x - $val->{centroid} ** 2) );
			}
			
			$exp_value = $exp_total / ($count);
		}
		
		print "Centroid $val->{centroid} expected value: $exp_value\n" if $debug;
		
		if (! defined $largest) {
			$largest = $exp_value;
		}
		elsif ($exp_value > $largest) {
			$largest = $exp_value;
		}
		
		$total_mahal_distance += $exp_value;
	}
	
	my $avg_distance = $total_mahal_distance / $k;
	
	#my $distortion = (1 / $scount) * $smallest;
	#my $distortion = (1 / $scount) * $avg_distance;
	my $distortion = $avg_distance;
	#my $distortion = $largest;
	
	print "Distortion for $k K-clusters: $distortion ($total_mahal_distance / $k)\n" if $debug;
	
	#my $D = $distortions[$jcount] = int($distortion ** ($Y * -1));
	my $D = $distortions[$jcount] = $distortion ** ($Y * -1);
	
	print "D for K$k: " . $D . " ($distortion ** -$Y)\n";
	
	my $J = ($distortions[$jcount] - $distortions[$jcount - 1]);
	#$Js[$k] = $J;
	print "K$k J: $J\n" if $debug;
	
	#	next if ($k == 1); #Don't bother checking the previous cluster difference against the one before it, it's 0 and there isn't any
	#my $prev_J = ($distortions[$k-1] - $distortions[$k-2]);
	#my $prev_D = $distortions[$k-1];
	#if ($J <= $prev_J) {
	#if ($D <= $prev_D) {
	#	%final_cluster = %{ $clusters{ $k-1 } };
	#	last;
	#}
}

#warn Dumper(\@Js);

#my @blah =  sort { $Js[$b] <=> $Js[$a] } 0 .. $#Js; # (sort { $Js[$b] <=> $Js[$a] } 0 .. $#Js);
#print @blah;

#my $good_k = (sort { $Js[$b] <=> $Js[$a] } 0 .. $#Js)[0];
#print "GOODKL: $good_k\n";

print "FINAL CLUSTERING:\n";
print Dumper(\%final_cluster);
#print Dumper($clusters{ $good_k });
