use Test::More;
use Cache::CacheFactory;
use Cache::CacheFactory::Storage;

my @storage_types = Cache::CacheFactory::Storage->get_registered_types();

my %vals = (
    'scalar'   => 'value for scalar key',
    'arrayref' => [ qw/value for arrayref key/ ],
    'hashref'  => { value => 'for', hashref => 'key' },
    );

my $tests_per_data_type    = 3;
my $tests_per_storage_type =
    1 + ( $tests_per_data_type * scalar( keys( %vals ) ) );

plan tests => ( $tests_per_storage_type * scalar( @storage_types ) );

foreach my $storage_type ( @storage_types )
{
    SKIP:
    {
        my ( $storage_module, $cache );

        $storage_module = Cache::CacheFactory::Storage->get_registered_class( $storage_type );
        eval "use $storage_module";
        skip "$storage_module required for testing $storage_type storage policies" => $tests_per_storage_type if $@;

        ok( $cache = Cache::CacheFactory->new(
            storage  => $storage_type,
            ), "construct $storage_type cache" );

        foreach my $key ( qw/scalar arrayref hashref/ )
        {
            $cache->set(
                key          => $key,
                data         => $vals{ $key },
                );

            if( $storage_type eq 'null' )
            {
                is( $cache->get( $key ), undef, "$storage_type $key fetch" );
            }
            elsif( $key eq 'scalar' )
            {
                is( $cache->get( $key ), $vals{ $key },
                    "$storage_type $key fetch" );
            }
            else
            {
                is_deeply( $cache->get( $key ), $vals{ $key },
                    "$storage_type $key fetch" );
            }

            $cache->remove( $key );

            is( $cache->get( $key ), undef,
                "$storage_type post-remove $key fetch" );

            $cache->set(
                key          => $key,
                data         => $vals{ $key },
                );

            $cache->clear();

            is( $cache->get( $key ), undef,
                "$storage_type post-clear $key fetch" );
        }
    }
}
