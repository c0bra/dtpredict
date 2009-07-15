#!/usr/bin/perl

use warnings;
use POSIX;
use Data::Dumper;

our $debug = $ENV{DEBUG};
local($|) = 1;

#Data elements
#my @s = (1, 2, 3, 4, 5, 6, 7, 8, 9, 10);
my @s = (1, 2, 3, 21, 22, 23, 41, 42, 43);
#my @s = (1, 2, 3, 4, 35, 36, 37);
#my @s = (112,91,94,110,98,106,103,109,107,123,117,129,135,123,122,116,122,98,115,134,93,101,125,111,116,119,123,108,129,59,120,109,112,119,30,91,117,83,103,111,106,113,100,100,102,109,88,100,110,127,95,102,106,105,109,116,107,102,110,124,97,115,104,119,103,121,107,106,121,100,118,118,114,96,89,95,100,100,103,95,102,124,96);

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
print "VARIANCE: $variance\n";

#Cluster them!
my %clusters      = ();
my @distortions   = (0);
my @Js = (0);
my $Y = (scalar @s / 2);
my %final_cluster = ();
#foreach my $k (1 .. scalar @s - 1) {
foreach my $k (1 .. $#s+1) {
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
		if (scalar keys %{ $cluster->{elements} } == 0) { next; }
	}

	#print Dumper(\%centroids);
	#print Dumper(\%cmap);
	$clusters{ $k } = \%cmap;
	
	### Determine the distortion for this number of clusters. When we see the distortion start
	###  to fall off we'll know we've reached the right number
	# Go through each cluster, finding the distortion. Keep the smallest
	my $smallest;
	while (my ($cid, $val) = each %cmap) {
		#Get the variance for the elements of this cluster
		my $centered_total = 0;
		#my $count = 0;
		my $count = scalar keys %{ $val->{elements} };
		
		#my $xmean = 0;
		#map { $xmean += $_ } keys %{ $val->{elements} };
		#$xmean = $xmean / (scalar keys %{ $val->{elements} });
		
		#print "Xmean: $xmean\n";
		
		
		foreach my $x (keys %{ $val->{elements} }) {
			$centered_total += (($x - $val->{centroid}) ** 2);
			#$count++;
		}
		
		#$count++ if ($count <= 1);
		#print "K$k count for centroid $val->{centroid}: $count\n";
		#my $variance = 0;
		#if ($count == 1) {
		#	$variance = $centered_total;
		#}
		#elsif ($count > 0) {
		#	my $variance = $centered_total / ($count); ####Uncomment this line for per-cluster variance
		#}
		#else {
		#	$smallest = 0;
		#	next;
		#}
		#print "Variance for centroid $val->{centroid} with $k clusters: $variance\n";
		
		#$count++ if ($count <= 1);
		#Get the expected value
		my $exp_value;
		#if ($count == 0) {
		#	$exp_value = 0;
		#}
		#else {
			my $exp_total = 0;
			foreach my $x (keys %{ $val->{elements} }) {
				$exp_total += ( (($x - $val->{centroid}) ** 2) * ($variance ** -1) );
				#$exp_total += ( ($x - $val->{centroid}) * ($variance ** -1) * ($x - $val->{centroid}) );
				#$exp_total += ( ($x - $val->{centroid} ** 2) );
			}
			
			$exp_value = $exp_total / ($count - 1);
		#}
		
		print "Centroid $val->{centroid} expected value: $exp_value\n";
		
		if (! defined $smallest) {
			$smallest = $exp_value;
		}
		elsif ($exp_value < $smallest) {
			$smallest = $exp_value;
		}
	}
	
	my $distortion = (1 / $scount) * $smallest;
	
	print "Distortion for $k K-clusters: $distortion\n";
	
	my $D = $distortions[$k] = $distortion ** ($Y * -1);
	
	print "D for K$k: " . $distortions[$k] . " ($distortion ** -$Y)\n";
	
	my $J = ($distortions[$k] - $distortions[$k-1]);
	$Js[$k] = $J;
	print "K$k J: $J\n";
	#	next if ($k == 1); #Don't bother checking the previous cluster difference against the one before it, it's 0 and there isn't any
	my $prev_J = ($distortions[$k-1] - $distortions[$k-2]);
	my $prev_D = $distortions[$k-1];
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
