#!perl-T

use Test::More tests => 4;

use_ok( 'DateTime::Event::Predict::Profile' );

$profile = new DateTime::Event::Predict::Profile( profile => 'default' );

isa_ok( $profile, 'DateTime::Event::Predict::Profile' );

my %buckets = $profile->buckets();

ok( %buckets );

my $profile = new DateTime::Event::Predict::Profile(
	buckets => {
		day_of_year => 1,
	},
);

isa_ok( $profile, 'DateTime::Event::Predict::Profile' );

my %buckets = $profile->buckets();

ok( %buckets );