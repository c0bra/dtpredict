#!perl

use Test::More tests => 11;

BEGIN { use_ok('DateTime::Event::Predict::Profile', qw(:buckets)) };

# Make sure bucket hashes exported correctly
ok(defined %DISTINCT_BUCKETS, 'Distinct buckets imported');
ok(defined %INTERVAL_BUCKETS, 'Interval buckets imported');

# Profile with preset profile name
$profile = new DateTime::Event::Predict::Profile( profile => 'default' );

isa_ok( $profile, 'DateTime::Event::Predict::Profile' );

my @buckets = $profile->buckets();

ok( @buckets, 'Buckets for preset profile are defined' );

# Profile with distinct buckets
$profile = new DateTime::Event::Predict::Profile(
	distinct_buckets => ['day_of_year'],
);

isa_ok( $profile, 'DateTime::Event::Predict::Profile' );

@buckets = $profile->buckets();

ok( @buckets, 'Buckets for custom profile with distinct buckets are defined' );

TODO: {
	# Make sure buckets we specify are there
};

# Profile with interval buckets
$profile = new DateTime::Event::Predict::Profile(
	interval_buckets => ['years'],
);

isa_ok( $profile, 'DateTime::Event::Predict::Profile' );

@buckets = $profile->buckets();

ok( @buckets, 'Buckets for custom profile with interval buckets are defined' );

# Both interval and distinct buckets
$profile = new DateTime::Event::Predict::Profile(
	distinct_buckets => ['day_of_year'],
	interval_buckets => ['years'],
);

isa_ok( $profile, 'DateTime::Event::Predict::Profile' );

@buckets = $profile->buckets();

ok( @buckets, 'Buckets for custom profile with both distinct and interval buckets are defined' );

# Make sure bad bucket names result in error