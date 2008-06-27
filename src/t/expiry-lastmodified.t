use Test::More;
use Cache::CacheFactory;
eval "use Cache::MemoryCache";
plan skip_all => "Cache::MemoryCache required for testing expiry policies" if $@;

plan tests => 5;

my ( $cache, $key, $file );
my %vals = (
    'valid' => 'value for valid key',
    );

ok( $cache = Cache::CacheFactory->new(
    storage  => 'memory',
    validity => 'lastmodified',
    ), "construct cache" );

#  TODO: should be some temp filename really.
$file = 'test-expiry-lastmodified.tmp';

system( 'touch', $file );
sleep( 1 ); #  So that the last modified time is definitely in the past.

$key = 'valid';
$cache->set(
    key          => $key,
    data         => $vals{ $key },
    dependencies => $file,
    );

$key = 'valid';
is( $cache->get( $key ), $vals{ $key }, "immediate $key fetch" );

$cache->purge();

$key = 'valid';
is( $cache->get( $key ), $vals{ $key }, "post-purge immediate $key fetch" );

system( 'touch', $file );

$key = 'valid';
is( $cache->get( $key ), undef, "post-touch $key fetch" );

$cache->purge();

$key = 'valid';
is( $cache->get( $key ), undef, "post-purge post-touch $key fetch" );

unlink( $file );
