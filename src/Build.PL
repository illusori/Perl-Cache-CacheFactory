#!/usr/bin/perl -w

use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new(
    module_name  => 'Cache::CacheFactory',
    license      => 'perl',
    dist_author  => 'Sam Graham <libcache-cachefactory-perl@illusori.co.uk>',
    dist_version => '1.04_01',
    requires => {
        'Test::More'       => 0,
        'Carp'             => 0,
        'Scalar::Util'     => 0,
        'Storable'         => 1.014,
        'Cache::Cache'     => 0,
        'Cache::Object'    => 0,
        'Cache::BaseCache' => 0,
        'Class::Factory'   => 0,
        },
    recommends => {
        'Cache::FileCache'         => 0,
        'Cache::MemoryCache'       => 0,
        'Cache::SharedMemoryCache' => 0,
        'Devel::Size'              => 0.69,
        'File::Path'               => 0,
        'File::Temp'               => 0,
        'File::Basename'           => 0,
        },
    sign => 1,
    );
$build->create_build_script;
