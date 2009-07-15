#!/usr/bin/perl

use strict;
no warnings;
use Data::Dumper;
use Date::Parse;
use Date::Calc qw(Delta_Days);
use DateTime;

#Predict last frost dates from USUClimateData.csv

# Date,Maximum_Temperature in F,Minimum_Temperature in F,Observation_Temperature in F,Precipitation in inches,Snow_Fall in inches,Snow_Depth in inches,

my @headers = qw( Date TemperatureHighF TemperatureLowF ObsvTempF PrecipIn SnowFallIn SnowDepthIn );

# 2008-1-1,29,20,11,22,10,2,77,66,53,30.75,30.33,13,4,13,0.00

#Get the dining data
my @wd = ();
open(my $file, '<', 'USUClimateData_no_1893.csv') || die "WTF: $!";
#open(my $file, '<', 'snip.csv') || die "WTF: $!";
while (my $line = <$file>) {
	next if $. == 1;
	chomp $line;
	#print "$line\n";
		#next if $line =~ /^#/;
	my %data = ();
        @data{ @headers } = split(',', $line);

	my ($ss,$mm,$hh,$day,$month,$year,$zone) = strptime( $data{Date} );
	$month++;
	if ($year < 1000) { $year += 1900; }
		#print '($ss,$mm,$hh,$day,$month,$year,$zone) = ' . "($ss,$mm,$hh,$day,$month,$year,$zone)\n";

	($ss,$mm,$hh,$day,$month) = map { $_ ||= 0; sprintf("%d", $_); } ($ss,$mm,$hh,$day,$month);
		#print '($ss,$mm,$hh,$day,$month,$year,$zone) = ' . "($ss,$mm,$hh,$day,$month,$year,$zone)\n";

	($ss,$mm,$hh) = map { $_ || '0' } ($ss,$mm,$hh);
	#$data{local} = timelocal($ss,$mm,$hh,$day,$month,$year);
	@data{ qw( year month day ) } = ( $year, $month, $day );
	#warn Dumper(\%data);
	eval { $data{dt} = DateTime->new( year   => $year,
                       month  => $month,
                       day    => $day,
                       hour   => $hh,
                       minute => $mm,
                       second => $ss,
                     ); }; if ($@) { die "Fail on file line $. ($data{Date})\n"; }

	#print $data{dt}->mdy('/') . "\n";

	push(@wd, \%data);
        #my ($ss,$mm,$hh,$day,$month,$year,$zone) = strptime($date);
        #push(@dates, [ $day, $month+1, $year+1900 ]);

	print "Processed line $.\n" if $ENV{'DEBUG'};
}
close($file);

#warn Dumper(\@wd); exit;

my @rains = ();
my $prev_year = 0;
my @diffs = ();
my %dh    = ();
my %years = (); #Hashmap of last frost for each year
foreach my $w (sort { $a->{dt}->hires_epoch() <=> $b->{dt}->hires_epoch() } @wd) {
	if ($w->{dt}->year != $prev_year) { $prev_year = $w->{dt}->year };
	
	my $july_diff = DateTime->new( year => $prev_year, month => 7, day => 31) - $w->{dt};
	
	if ($w->{TemperatureLowF} <= 32 && $july_diff->delta_days > 0 ) {
		$years{ $prev_year } = $w->{dt};
	}
}

#warn Dumper(\%years);

#map { print $_->mdy('/') . "\n"; } sort { $a->hires_epoch() <=> $b->hires_epoch() } values %years;
map { print $_->doy() . "\n"; } sort { $a->hires_epoch() <=> $b->hires_epoch() } values %years;

#my ($com) =  sort keys %dh;
#print "$com\n";

#warn Dumper(\%dh);
