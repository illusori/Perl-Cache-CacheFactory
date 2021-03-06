use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name        => 'Cache::CacheFactory',
    license            => 'perl',
    dist_author        => 'Sam Graham <libcache-cachefactory-perl@illusori.co.uk>',
    dist_version_from  => 'lib/Cache/CacheFactory.pm',
    build_requires => {
        'Module::Build'    => 0.07,
        'Test::More'       => 0,
        },
    requires => {
        'Carp'             => 0,
        'Scalar::Util'     => 0,
        'Storable'         => 1.014,
        'Cache::Cache'     => 1.00,
        'Cache::Object'    => 0,
        'Cache::BaseCache' => 0,
        'Class::Factory'   => 0,
        },
    recommends => {
        'Cache::FileCache'         => 0,
        'Cache::MemoryCache'       => 0,
        'Cache::SharedMemoryCache' => 0,
        'Cache::FastMemoryCache'   => 0.01,
        'Devel::Size'              => 0.69,
        'File::Path'               => 0,
        'File::Temp'               => 0,
        'File::Basename'           => 0,
        },
    meta_merge => {
        'resources' => {
            'repository' => 'http://github.com/illusori/Perl-Cache-CacheFactory',
            },
        },
    add_to_cleanup      => [ 'Cache-CacheFactory-*' ],
    create_readme => 1,
    dynamic_config => 0,
    sign => 1,
);

$builder->create_build_script;
