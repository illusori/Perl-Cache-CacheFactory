###############################################################################
# Purpose : Cache Expiry Policy Factory.
# Author  : Sam Graham
# Created : 23 Jun 2008
# CVS     : $Id: Expiry.pm,v 1.1 2008-06-26 20:20:06 illusori Exp $
###############################################################################

package Cache::CacheFactory::Expiry;

use strict;

use Class::Factory;

use base qw/Class::Factory/;

$Cache::CacheFactory::Expiry::VERSION =
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
    forever      => 'Cache::CacheFactory::Expiry::Base' );
__PACKAGE__->register_factory_type(
    time         => 'Cache::CacheFactory::Expiry::Time' );
__PACKAGE__->register_factory_type(
    size         => 'Cache::CacheFactory::Expiry::Size' );
__PACKAGE__->register_factory_type(
    lastmodified => 'Cache::CacheFactory::Expiry::LastModified' );

1;
