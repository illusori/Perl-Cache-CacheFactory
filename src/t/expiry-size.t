use Test::More;
use Cache::CacheFactory;
#  Need to use file caching because memory cache sizes are... odd.
eval "use Cache::FileCache";
plan skip_all => "Cache::FileCache required for testing size expiry policies" if $@;

plan tests => 5;

my ( $cache, $key );
my %vals = (
    '100b' => '1' x 100,
    '500b' => '5' x 500,
    );

ok( $cache = Cache::CacheFactory->new(
    storage   => 'file',
    namespace => 'test-expiry-size',
    pruning   => { 'size' => { max_size => 300, } },
    ), "construct cache" );

$key = '100b';
$cache->set(
    key          => $key,
    data         => $vals{ $key },
    );
is( $cache->get( $key ), $vals{ $key }, "immediate $key fetch" );
$cache->purge();
is( $cache->get( $key ), $vals{ $key }, "post-purge $key fetch" );

$cache->clear();

$key = '500b';
$cache->set(
    key          => $key,
    data         => $vals{ $key },
    );
is( $cache->get( $key ), $vals{ $key }, "immediate $key fetch" );
$cache->purge();
is( $cache->get( $key ), undef, "post-purge $key fetch" );

$cache->clear();
