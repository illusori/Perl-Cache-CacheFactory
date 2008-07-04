use Test::More;
use Cache::CacheFactory qw/:best_available/;

plan tests => 3;

ok( best_available_storage_policy( 'memory', 'file' ), "best available storage policy exported" );
ok( best_available_pruning_policy( 'time', 'size' ), "best available pruning policy exported" );
ok( best_available_validity_policy( 'time', 'size' ), "best available validity policy exported" );
