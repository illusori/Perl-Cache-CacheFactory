###############################################################################
# Purpose : Cache Size Expiry Policy Class.
# Author  : Sam Graham
# Created : 25 Jun 2008
# CVS     : $Id: Size.pm,v 1.1 2008-07-04 21:12:13 illusori Exp $
###############################################################################

package Cache::CacheFactory::Expiry::Size;

use warnings;
use strict;

use Scalar::Util;

use Cache::Cache;
use Cache::BaseCache;

use Cache::CacheFactory::Expiry::Base;

use base qw/Cache::CacheFactory::Expiry::Base/;

$Cache::CacheFactory::Expiry::Size::VERSION =
    sprintf"%d.%03d", q$Revision: 1.1 $ =~ /: (\d+)\.(\d+)/;

my ( $use_devel_size );

BEGIN
{
    #  TODO: check for configurations with known Devel::Size issues?
    #  See if we have Devel::Size available.  We don't make it a requirement
    #  because it doesn't seem to work with 5.6 perls.
    eval "use Devel::Size";
    $use_devel_size = 1 unless $@;
}

sub read_startup_options
{
    my ( $self, $param ) = @_;

    $self->{ max_size } = $param->{ max_size }
        if exists $param->{ max_size };
    $self->{ no_devel_size } = $param->{ no_devel_size }
        if exists $param->{ no_devel_size };
    $self->{ no_overrule_memorycache_size } =
        $param->{ no_overrule_memorycache_size }
        if exists $param->{ no_overrule_memorycache_size };
}

sub set_object_validity
{
    my ( $self, $key, $object, $param ) = @_;

}

sub set_object_pruning
{
    my ( $self, $key, $object, $param ) = @_;

}

sub guestimate_size
{
    my ( $self, $data ) = @_;
    my ( $totalsize, @queue, %seen );

    if( $use_devel_size and not $self->{ no_devel_size } )
    {
        return( Devel::Size::total_size( $data ) );
    }

    #  Fallback in case we're on a system without Devel::Size.
    #  These are highly invented numbers just to give something
    #  better than that in Cache::MemoryCache.
    #  ie: the result may be wrong but it should at least be
    #  somewhat consistently proportional to the right value.

    $totalsize = 0;
    %seen      = ();
    @queue     = ( $data );

    while( @queue )
    {
        my ( $item, $type );

        $item = shift( @queue );
        $type = Scalar::Util::reftype( $item );

        #  Each value has some overhead, let's say two bytes,
        #  this is total invention on my part but...
        $totalsize += 2;

        if( !defined( $type ) )
        {
            #  Yep, wrong if it's a number, tough.
            $totalsize += length( $item );
        }
        else
        {
            #  Only count size of contents of circular references the once.
            next if $seen{ $item }++;
            if( $type eq 'ARRAY' )
            {
                push @queue, @{$item};
            }
            elsif( $type eq 'HASH' )
            {
                push @queue, keys( %{$item} ), values( %{$item} );
            }
            else
            {
                #  HellifIknow.
            }
        }
    }

    return( $totalsize );
}

sub overrule_size
{
    my ( $self, $storage ) = @_;
    my ( $totalsize );

    $totalsize = 0;
    #  Get every object in the cache, not expensive at all, nooooo. :)
    foreach my $key ( $storage->get_keys() )
    {
        my ( $ob );

        $ob = $storage->get_object( $key );
        $totalsize += $self->guestimate_size( $ob );
    }

    return( $totalsize );
}

sub should_keep
{
    my ( $self, $cache, $storage, $policytype, $object ) = @_;
    my ( $cachesize );

    if( not $self->{ no_overrule_memorycache_size } and
        $storage->isa( 'Cache::MemoryCache' ) )
    {
        $cachesize = $self->{ _cache_size } || $self->overrule_size( $storage );
    }
    else
    {
        $cachesize = $self->{ _cache_size } || $storage->size();
    }

    return( 1 ) if $cachesize <= $self->{ max_size };
    return( 0 );
}

1;

=pod

=head1 NAME

Cache::CacheFactory::Expiry::Size - size-based expiry policy for Cache::CacheFactory.

=head1 DESCRIPTION

L<Cache::CacheFactory::Expiry::Size>
is a size-based expiry (pruning and validity) policy for
L<Cache::CacheFactory>.

It provides similar functionality and backwards-compatibility with
the C<max_size> option of L<Cache::SizeAwareFileCache> and variants.

It's highly recommended that you B<DO NOT> use this policy as a
validity policy, as calculating the size of the contents of the
cache on each read can be quite expensive, and it's semantically
ambiguous as to just what behaviour is intended by it anyway.

Note that in its current implementation L<Cache::CacheFactory::Expiry::Size>
is "working but highly inefficient" when it comes to purging.
It is provided mostly for completeness while a revised version
is being worked on.

=head1 SIZE SPECIFICATIONS

Currently all size values must be specified as numbers and will be
interpreted as bytes. Future versions reserve the right to supply
the size as a string '10 M' for ease of use, but this is not currently
implemented.

=head1 STARTUP OPTIONS

The following startup options may be supplied to 
L<Cache::CacheFactory::Expiry::Size>,
see the L<Cache::CacheFactory> documentation for
how to pass options to a policy.

=over

=item max_size => $size

This sets the maximum size that the cache strives to keep under,
any items that take the cache over this size will be pruned (for
a pruning policy) at the next C<< $cache->purge() >>.

See the L</"SIZE SPECIFICATIONS"> section above for details on
what values you can pass in as C<$size>.

Note that by default pruning policies are not immediately enforced,
they are only applied when a C<< $cache->purge() >> occurs. This
means that it is possible (likely even) for the size of the cache
to exceed C<max_size> at least on a temporary basis. When the next
C<< $cache->purge() >> occurs, the cache will be reduced back down
below C<max_size>.

If you make use of the C<auto_purge_on_set> option to
L<Cache::CacheFactory>, you'll cause a C<< $cache->purge() >>
on a regular basis depending on the value of C<auto_purge_interval>.

However, even with the most aggressive values of C<auto_purge_interval>
there will still be a best-case scenario of the cache entry being
written to the cache, taking it over C<max_size>, and the purge
then reducing the cache below C<max_size>. This is essentially
unavoidable since it's impossible to know the size an entry will
take in the cache until it has been written.

=item no_overrule_memorycache_size => 0 | 1

By default L<Cache::CacheFactory::Expiry::Size> will attempt a
workaround for the problems mentioned in "Memory cache inaccuracies"
in the L</"KNOWN ISSUES AND BUGS"> section.

If this behaviour is undesirable, supply a true value to the
C<no_overrule_memorycache_size> option.

=item no_devel_size => 0 | 1

If the above workaround is in effect it will attempt to use L<Devel::Size>
if it is available, since this module delves into the internals of perl
it can be fragile on perl version changes and you may wish to disable
it if this is causing you problems, to do that set the C<no_devel_size>
option to a true value.

=back

=head1 STORE OPTIONS

There are no per-key options for this policy.

=head1 METHODS

You shouldn't need to call any of these methods directly.

=over

=item $size = $policy->overrule_size( $storage );

This method is used to overrule the usual C<< $storage->size() >>
method when comparing against C<max_size>, it attempts to
analyze every object in the cache and sum their memory footprint
via C<< $policy->guestimate_size() >>.

By default this is used when trying to workaround issues with
the C<size()> method of L<Cache::MemoryCache>.

=item $size = $policy->guestimate_size( $data );

This method provides a rough (very rough sometimes) estimate of
the memory footprint of the data structure C<$data>.

This is used internally by the L<Cache::MemoryCache> workaround.

=back

=head1 KNOWN ISSUES AND BUGS

=over

=item Memory cache inaccuracies

Due to the way that L<Cache::MemoryCache> and L<Cache::SharedMemoryCache>
implement the C<size()> method, the values returned do not actually
reflect the memory used by a cache entry, in fact it's likely to return
a somewhat arbitrary value linear to the number of entries in the cache
and independent of the size of the data in the entries.

This means that a 'size' pruning policy applied to storage policies of
'memory' or 'sharedmemory' would not keep the size of the cache
under C<max_size> bytes.

So, by default L<Cache::CacheFactory::Expiry::Size> will ignore and overrule
the value of C<< Cache::MemoryCache->size() >> or
C<< CacheSharedMemoryCache->size() >> when checking against C<max_size> and
will attempt to use its own guestimate of the memory taken up.

To do this it will make use of L<Devel::Size> if available, or
failing that use a very simplistic calculation that should at least be
proportional to the size of the data in the cache rather than the number
of entries.

Since L<Devel::Size> doesn't appear to be successfully tested on
perls of 5.6 vintage or earlier and the bug only effects memory
caches, L<Devel::Size> hasn't been made a requirement of this module.

This may all be considered as a bug, or at the least a gotcha.

=back

=head1 SEE ALSO

L<Cache::CacheFactory>, L<Cache::Cache>, L<Cache::SizeAwareFileCache>,
L<Cache::SizeAwareCache>, L<Cache::CacheFactory::Object>,
L<Cache::CacheFactory::Expiry::Base>

=head1 AUTHORS

Original author: Sam Graham <libcache-cachefactory-perl BLAHBLAH illusori.co.uk>

Last author:     $Author: illusori $

=head1 COPYRIGHT

Copyright 2008 Sam Graham.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
