###############################################################################
# Purpose : Cache Expiry Base Class.
# Author  : Sam Graham
# Created : 25 Jun 2008
# CVS     : $Id: Base.pm,v 1.1 2008-06-26 20:20:06 illusori Exp $
###############################################################################

package Cache::CacheFactory::Expiry::Base;

use strict;

$Cache::CacheFactory::Expiry::Base::VERSION =
    sprintf"%d.%03d", q$Revision: 1.1 $ =~ /: (\d+)\.(\d+)/;

sub new
{
    my ( $class, $param ) = @_;
    my ( $self );

    $self = {};
    bless $self, ( ref( $class ) || $class );

    $self->read_startup_options( $param );

    return( $self );
}

sub set_object_validity
{
    my ( $self, $key, $object, $param ) = @_;
}

sub set_object_pruning
{
    my ( $self, $key, $object, $param ) = @_;
}

sub should_keep
{
    my ( $self, $cache, $storage, $policytype, $object ) = @_;

    return( 1 );
}

sub is_valid
{
    my ( $self, $cache, $storage, $object ) = @_;

    return( $self->should_keep( $cache, $storage, 'validity', $object ) );
}

sub purge
{
    my ( $self, $cache ) = @_;

    #  This processes the objects in no particular order, if the order
    #  matters to you, you will need to redefine it.
    $cache->foreach_policy( 'storage',
        sub
        {
            my ( $cache, $policy, $storage ) = @_;

            foreach my $key ( $storage->get_keys() )
            {
                my ( $object );

                $object = $storage->get_object( $key );

                $storage->remove( $key )
                    unless $self->should_keep(
                        $cache, $storage, 'pruning', $object );
            }
        } );
}

1;

=pod

=head1 NAME

Cache::CacheFactory::Expiry::Base -- base class for Cache::CacheFactory expiry policies.

=head1 DESCRIPTION

L<Cache::CacheFactory::Expiry::Base|Cache::CacheFactory::Expiry::Base>
is the base class for L<Cache::CacheFactory|Cache::CacheFactory> expiry
(pruning and validity) policies.

It provides the base API to adhere to when writing your own custom
policies.

=head1 METHODS

=over

=item $policy = Cache::CacheFactory::Expiry::Base->new( $options )

Construct a new expiry policy object with the specified options supplied
as a hashref.

What options are avaiable depends on the subclass, you should check the
documentation there.

The C<new()> constructor should never need to be called directly, this
is handled for you automatically when a policy is set for a cache.

=item $policy->read_startup_options( $options )

This method is called by the base C<new()> constructor, it allows
subclasses to read and process their startup options without having
to mess around with redefining the constructor.

=item $policy->set_object_validity( $key, $object, $param )

=item $policy->set_object_pruning( $key, $object, $param )

These two methods are invoked when a piece of data is first stored
in the cache, just prior to the actual storage, this allows the
validity and pruning policies to store any neccessary meta-data
against the object for when it is fetched from the cache again.

C<$key> is the key the data is being stored against.

C<$object> is the L<Cache::CacheFactory::Object> wrapper around
the data. If you're storing meta-data against the object you will
want to look at the C<< $object->set_policy_metadata() >> method.

C<$param> is a hashref to %additional_param supplied to
C<< $cache->set() >>.

=item $boolean = $policy->should_keep( $cache, $storage, $policytype, $object );

C<< $policy->should_keep() >> is the core of a expiry policy, it should
return a true value if the object should be kept or a false value if the
object should be considered invalid or be pruned.

C<$cache> is the parent L<Cache::CacheFactory|Cache::CacheFactory>,
this may or may not be useful to you.

C<$storage> is the storage object instance in case you need it.

C<$policytype> is the policy type, for an expiry policy it will be set
to either C<'validity'> if the validity of an object is being tested,
or C<'pruning'> if we're checking if the object should be pruned. I<Most>
policies will only care about the C<$policytype> if they need to access
per-policy meta-data on the object.

C<$object> is the L<Cache::CacheFactory::Object|Cache::CacheFactory::Object>
instance for the cache entry being tested. You'll probably want to call
some methods on this to make a decision about whether it should be kept
or not. C<< $object->get_policy_metadata() >> may prove useful here if
you've stored data during C<< $policy->set_object_validity() >> or
C<< $policy->set_object_pruning() >>.

=item $boolean = $policy->is_valid( $cache, $storage, $object );

Wrapper function around C<< $policy->should_keep() >>, this is called
when the policy is being used as a validity policy. You shouldn't need
to change anything about this method.

=item $policy->purge( $cache );

This function iterates over each storage policy getting a list of all
their keys, then calls C<< $policy->should_keep() >> with C<$policytype>
set to C<'pruning'>, if the returned value is false then the key is
removed from that storage policy, if the returned value is true then no
change occurs.

If you're writing your own policy you may need to redefine this method
if you care about the order in which objects are tested for pruning.

=back

=head1 SEE ALSO

L<Cache::CacheFactory|Cache::CacheFactory>, L<Cache::Cache|Cache::Cache>, L<Cache::CacheFactory::Object|Cache::CacheFactory::Object>

=head1 AUTHORS

Original author: Sam Graham <libcache-cachefactory-perl BLAHBLAH illusori.co.uk>

Last author:     $Author: illusori $

=head1 COPYRIGHT

Copyright 2008 Sam Graham.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
