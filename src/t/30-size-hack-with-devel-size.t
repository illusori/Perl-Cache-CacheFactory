use Test::More;
use Cache::CacheFactory;
eval "use Cache::MemoryCache";
plan skip_all => "Cache::MemoryCache required for testing memorycache workaround" if $@;
eval "use Devel::Size";
plan skip_all => "Devel::Size required for testing Devel::Size-using memorycache workaround" if $@;

plan tests => 6;

my ( $cache, $key );
my %vals = (
    '100b' => '1' x 100,
    '900b' => '9' x 900,
    );

ok( $cache = Cache::CacheFactory->new(
    storage   => 'memory',
    pruning   => { 'size' => { max_size => 500, } },
    ), "construct cache" );

my $driver = $cache->get_policy_driver( 'pruning', 'size' );
is( $driver->using_devel_size(), 1, "is using Devel::Size." );

$key = '100b';
$cache->set(
    key          => $key,
    data         => $vals{ $key },
    );
is( $cache->get( $key ), $vals{ $key }, "immediate $key fetch" );
$cache->purge();
is( $cache->get( $key ), $vals{ $key }, "post-purge $key fetch" );

$cache->clear();

$key = '900b';
$cache->set(
    key          => $key,
    data         => $vals{ $key },
    );
is( $cache->get( $key ), $vals{ $key }, "immediate $key fetch" );
$cache->purge();
is( $cache->get( $key ), undef, "post-purge $key fetch" );

$cache->clear();
