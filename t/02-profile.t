#!perl

use Test::More tests => 5;

use_ok( 'DateTime::Event::Predict::Profile' );

$profile = new DateTime::Event::Predict::Profile( profile => 'default' );

isa_ok( $profile, 'DateTime::Event::Predict::Profile' );

my @buckets = $profile->buckets();

ok( @buckets, 'Buckets are defined' );

my $profile = new DateTime::Event::Predict::Profile(
	buckets => ['day_of_year'],
);

isa_ok( $profile, 'DateTime::Event::Predict::Profile' );

@buckets = $profile->buckets();

ok( @buckets, 'Buckets are defined' );