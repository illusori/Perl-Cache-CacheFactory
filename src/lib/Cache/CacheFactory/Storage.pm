###############################################################################
# Purpose : Cache Storage Policy Factory.
# Author  : Sam Graham
# Created : 23 Jun 2008
# CVS     : $Id: Storage.pm,v 1.1 2008-06-26 20:20:06 illusori Exp $
###############################################################################

package Cache::CacheFactory::Storage;

use strict;

use Class::Factory;

use base qw/Class::Factory/;

$Cache::CacheFactory::Storage::VERSION =
    sprintf"%d.%03d", q$Revision: 1.1 $ =~ /: (\d+)\.(\d+)/;

sub new
{
    my ( $this, $type, @params ) = @_;
    my ( $class );

    $class = $this->get_factory_class( $type );
    return( undef ) unless $class;
    return( $class->new( @params ) );
}

__PACKAGE__->register_factory_type(
    memory       => 'Cache::MemoryCache' );
__PACKAGE__->register_factory_type(
    sharedmemory => 'Cache::SharedMemoryCache' );
__PACKAGE__->register_factory_type(
    file         => 'Cache::FileCache' );
__PACKAGE__->register_factory_type(
    null         => 'Cache::NullCache' );

1;
