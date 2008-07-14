use Test::More;
use Cache::CacheFactory;
eval "use Cache::MemoryCache";
plan skip_all => "Cache::MemoryCache required for testing expiry policies" if $@;

plan tests => 9;

my ( $cache, $key );
my %vals = (
    'valid-2 prune-10' => 'value for valid-2 prune-10 key',
    'valid-10 prune-2' => 'value for valid-10 prune-2 key',
    );

ok( $cache = Cache::CacheFactory->new(
    storage  => 'memory',
    pruning  => 'time',
    validity => 'time',
    ), "construct cache" );

$key = 'valid-2 prune-10';
$cache->set(
    key         => $key,
    data        => $vals{ $key },
    valid_until => '2 seconds',
    prune_after => '10 seconds',
    );
$key = 'valid-10 prune-2';
$cache->set(
    key         => $key,
    data        => $vals{ $key },
    valid_until => '10 seconds',
    prune_after => '2 seconds',
    );

$key = 'valid-2 prune-10';
is( $cache->get( $key ), $vals{ $key }, "immediate $key fetch" );

$key = 'valid-10 prune-2';
is( $cache->get( $key ), $vals{ $key }, "immediate $key fetch" );

$cache->purge();

$key = 'valid-2 prune-10';
is( $cache->get( $key ), $vals{ $key }, "post-purge immediate $key fetch" );

$key = 'valid-10 prune-2';
is( $cache->get( $key ), $vals{ $key }, "post-purge immediate $key fetch" );

sleep( 3 );

$key = 'valid-2 prune-10';
is( $cache->get( $key ), undef, "delayed $key fetch" );

$key = 'valid-10 prune-2';
is( $cache->get( $key ), $vals{ $key }, "delayed $key fetch" );

$cache->purge();

$key = 'valid-2 prune-10';
is( $cache->get( $key ), undef, "post-purge delayed $key fetch" );

$key = 'valid-10 prune-2';
is( $cache->get( $key ), undef, "post-purge delayed $key fetch" );

#  Clean-up.
foreach $key ( keys( %vals ) )
{
    $cache->remove( $key );
}
