#!/usr/bin/perl

use strict;
use Benchmark qw(:all);

cmpthese(-30, {
	'jump'       => \&jump,
	'silhouette' => \&silhouette,
});

sub jump {
	my @s = (1, 2, 3, 4, 35, 36, 37, 91, 92, 256, 257, 258);
	
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
	
	my $exp_total = 0;
	foreach my $x (@s) {
		$exp_total += sqrt( (abs($x - $smean) ** 2) * ($variance ** -1) );
	}
	
	my $exp_value = $exp_total / ($scount);
	my $total_mahal_distance += $exp_value;
	my $avg_distance = $total_mahal_distance;
	
	my $distortion = $avg_distance ** ($Y * -1);
	
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
			if (scalar keys %{ $cluster->{elements} } == 0) {
				#print "Bad K ($k): " . Dumper($cluster);
				next MLOOP;
			}
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
		
		#my $D = $distortions[$jcount] = int($distortion ** ($Y * -1));
		my $D = $distortions[$jcount] = $distortion ** ($Y * -1);
		
		my $J = ($distortions[$jcount] - $distortions[$jcount - 1]);
	}
}

sub silhouette {
	#Data elements
	my @s = (1, 2, 3, 4, 35, 36, 37, 91, 92, 256, 257, 258);
	
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
		#print "CMAP: " . Dumper(\%cmap);
		$clusters{ $k } = \%cmap;
		
		## Silhouettes
		## 1. Find the similarity for each point 
		next if (scalar keys %cmap == 1); #Skip if we only have one cluster
		
		my $total_dissimilarity = 0;
		my %cmap2 = %cmap; #Make a copy for internal loop interation
		
		while (my ($cid, $val) = each %cmap) {
			my $pts      = $val->{elements};
			my $centroid = $val->{centroid};
			#For each data point
			foreach my $pt (keys %$pts) {
				#Calculate the distance from this point's centroid
				my $ai = abs($pt - $centroid);
				
				#Now calculate the similarity vs every other centroid
				my $lowest_bi;
				foreach my $val (values %cmap2) {
					my $other_ctrd = $val->{centroid};
						next if $other_ctrd == $centroid;
					
					my $bi = abs($pt - $other_ctrd);
					$lowest_bi = $bi if (! defined $lowest_bi || $bi < $lowest_bi);
				}
				#print "	$pt - $ai : $lowest_bi\n";
				
				my $max_ai_bi;
				if ($lowest_bi) {
					$max_ai_bi = ($lowest_bi > $ai) ? $lowest_bi : $ai;
				}
				else {
					$max_ai_bi = $ai;
				}
				
				#Silhouette for this pt
				my $si;
				if ($lowest_bi) {
					$si = ($lowest_bi - $ai) / $max_ai_bi;
				}
				else {
					$si = $ai / $max_ai_bi;
				}
				
				$total_dissimilarity += $si;
			}
		}		
	}
}