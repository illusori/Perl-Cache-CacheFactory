###############################################################################
# Purpose : Extension of Cache::Object.pm to support policy meta-data.
# Author  : Sam Graham
# Created : 24 Jun 2008
# CVS     : $Id: Object.pm,v 1.1 2008-06-26 20:20:06 illusori Exp $
###############################################################################

package Cache::CacheFactory::Object;

use strict;

use base qw/Cache::Object/;

use Storable;

$Cache::CacheFactory::Object::VERSION =
    sprintf"%d.%03d", q$Revision: 1.1 $ =~ /: (\d+)\.(\d+)/;

sub new_from_old
{
    my ( $class, $old_ob ) = @_;
    my ( $ob );

    $ob = $class->new();
    $ob->initialize(
        $old_ob->get_key(),
        $old_ob->get_data(),
        {
            created_at  => $old_ob->get_created_at(),
            accessed_at => $old_ob->get_accessed_at(),
            expires_at  => $old_ob->get_expires_at(),
        } );
    #  TODO: this should probably be recalculated by the policies?
    $ob->set_size( $old_ob->get_size() );
}

sub initialize
{
    my ( $self, $key, $data, $param ) = @_;

    $self->set_key( $key );
    $self->set_data( ref( $data ) ? Storable::dclone( $data ) : $data );

    #  Overrule default properties if they've been supplied.
    foreach my $property ( qw/created_at accessed_at expires_at/ )
    {
        if( exists( $param->{ $property } ) )
        {
            my ( $method );

            $method = "set_${property}";
            $self->$method( $param->{ $property } );
            delete $param->{ $property };
        }
    }
}

sub set_policy_metadata
{
    my ( $self, $policytype, $policy, $metadata ) = @_;

    $self->{ _Policy_Meta_Data } ||= {};
    $self->{ _Policy_Meta_Data }->{ $policytype } ||= {};
    $self->{ _Policy_Meta_Data }->{ $policytype }->{ $policy } = $metadata;
}

sub get_policy_metadata
{
    my ( $self, $policytype, $policy ) = @_;

    return( $self->{ _Policy_Meta_Data }->{ $policytype }->{ $policy } );
}

1;

__END__

=pod

=head1 NAME

Cache::CacheFactory::Object -- the data stored in a Cache.

=head1 DESCRIPTION

Cache::CacheFactory::Object is a subclass extending Cache::Object to
allow for per-policy meta-data needed by Cache::CacheFactory's policies.

You will not normally need to use this class for anything.

If you are already using Cache::Object then you'll find that
Cache::CacheFactory::Object only extends behaviour, it doesn't
alter existing behaviour.

=head1 SYNOPSIS

 use Cache::CacheFactory::Object;

 my $object = Cache::CacheFactory::Object( );

 $object->set_key( $key );
 $object->set_data( $data );
 $object->set_expires_at( $expires_at );
 $object->set_created_at( $created_at );
 $object->set_policy_metadata( 'expiry', 'time', $metadata );


=head1 METHODS

=over

=item B<new_from_old( $cache_object )>

Construct a new Cache::CacheFactory::Object from a Cache::Object instance,
this is done automatically by Cache::CacheFactory methods that provide
backwards compat.

=item B<set_policy_metadata( $policytype, $policy, $metadata )>

Set the meta-data for the given policytype and policy to the value
provided in $metadata, usually a hashref.

See the documentation on Cache::CacheFactory for more information
about policytypes and policies.

=item B<get_policy_metadata( $policytype, $policy )>

Retreive the meta-data stored by the policytype and policy.

See the documentation on Cache::CacheFactory for more information
about policytypes and policies.

=back

All other behaviour is inherited from and documented by Cache::Object.

=head1 SEE ALSO

Cache::CacheFactory, Cache::Object

=head1 AUTHOR

Original author: Sam Graham <libcache-cachefactory-perl BLAHBLAH illusori.co.uk>

Last author:     $Author: illusori $

Copyright 2008 Sam Graham

=cut
