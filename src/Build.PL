#!/usr/bin/perl -w

use Module::Build;
my $build = Module::Build->new(
    module_name  => 'Cache::CacheFactory',
    dist_version => 1.01,
    license  => 'perl',
    requires => {
        'Cache::Cache'     => 0,
        'Cache::Object'    => 0,
        'Cache::BaseCache' => 0,
        'Class::Factory'   => 0,
        },
    recommends => {
        'Cache::FileCache'         => 0,
        'Cache::MemoryCache'       => 0,
        'Cache::SharedMemoryCache' => 0,
        }
    );
$build->create_build_script;
