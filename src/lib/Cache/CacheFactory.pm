###############################################################################
# Purpose : Generic Cache Factory with various policy factories.
# Author  : Sam Graham
# Created : 23 Jun 2008
# CVS     : $Id: CacheFactory.pm,v 1.1 2008-06-26 20:20:06 illusori Exp $
###############################################################################

package Cache::CacheFactory;

use strict;

use Cache::Cache;

use Cache::CacheFactory::Storage;
use Cache::CacheFactory::Expiry;
use Cache::CacheFactory::Object;

use base qw/Cache::Cache/;

$Cache::CacheFactory::VERSION =
    sprintf"%d.%03d", q$Revision: 1.1 $ =~ /: (\d+)\.(\d+)/;

sub new
{
    my $class = shift;
    my ( $self, %options );

    %options = ref( $_[ 0 ] ) ? %{$_[ 0 ]} : @_;

    $self = { policies => {}, compat => {}, };
    bless $self, ( ref( $class ) || $class );

    #
    #  Compat options with Cache::Cache subclasses.
    $self->{ namespace } = $options{ namespace } || 'Default';

    #  Compat with Cache::Cache.
    foreach my $option ( qw/default_expires_in auto_purge_interval
        auto_purge_on_set auto_purge_on_get/ )
    {
        next unless $options{ $option };
        $self->{ compat }->{ $option } = $options{ $option };
    }

    #
    #  Grab our policies from the options.
    $self->set_storage_policies(  $options{ storage  } );
    $self->set_pruning_policies(  $options{ pruning  } )
        if $options{ pruning  };
    $self->set_validity_policies( $options{ validity } )
        if $options{ validity };

    return( $self );
}

sub new_cache_entry_object
{
    my ( $self ) = @_;

    return( Cache::CacheFactory::Object->new() );
}

sub set
{
    my $self = shift;
    my ( $param, $object, $key, $data );

    #  Aiii, backwards-compat with Cache::Cache->set().
    if( $self->{ compat }->{ positional_set } and
        ( ( $self->{ compat }->{ positional_set } ne 'auto' ) or
          ( $_[ 0 ] ne 'key' ) ) )
    {
        my ( $expires_in );

        $key        = shift;
        $data       = shift;
        $expires_in = shift;
        $param = {};
        $param->{ expires_in } = $expires_in if defined( $expires_in = shift );
        #  TODO: warn if expires set and not time pruning/validity policy?
    }
    else
    {
        $param = ref( $_[ 0 ] ) ? { %{$_[ 0 ]} } : { @_ };
        if( exists( $param->{ key } ) )
        {
            $key  = $param->{ key };
            delete $param->{ key };
        }
        if( exists( $param->{ data } ) )
        {
            $data = $param->{ data };
            delete $param->{ data };
        }
    }

    $param->{ created_at } = time() unless $param->{ created_at };

    #  Create Cache::CacheFactory::Object instance.
    $object = $self->new_cache_entry_object();

    #  Initialize it from the param.
    $object->initialize( $key, $data, $param );

    $self->foreach_driver( 'validity', 'set_object_validity',
        $key, $object, $param );
    $self->foreach_driver( 'pruning',  'set_object_pruning',
        $key, $object, $param );
    $self->foreach_driver( 'storage',  'set_object',
        $key, $object, $param );
}

sub get
{
    my ( $self, $key ) = @_;
    my ( $object );

    $self->foreach_policy( 'storage',
        sub
        {
            my ( $self, $policy, $storage ) = @_;

            $object = $storage->get_object( $key );
            return unless defined $object;

            $self->foreach_policy( 'validity',
                sub
                {
                    my ( $self, $policy, $validity ) = @_;

                    return if $validity->is_valid( $self, $storage, $object );

                    undef $object;
                    #  TODO: should remove from this storage. optionally?
                    $self->last();
                } );

            $self->last() if defined $object;
        } );

    return( $object->get_data() ) if defined $object;
    return( undef );
}

sub get_object
{
    my ( $self, $key ) = @_;
    my ( $object );

    $self->foreach_policy( 'storage',
        sub
        {
            my ( $self, $policy, $storage ) = @_;

            $object = $storage->get_object( $key );
            $self->last() if defined $object;
        } );

    return( $object );
}

sub set_object
{
    my ( $self, $key, $object ) = @_;

    #  Backwards compat with Cache::Object objects.
    unless( $object->isa( 'Cache::CacheFactory::Object' ) )
    {
        $object = Cache::CacheFactory::Object->new_from_old( $object );
        #  TODO: compat with expires_at
    }

    $self->foreach_driver( 'storage', 'set_object', $key, $object );
}

sub remove
{
    my ( $self, $key ) = @_;

    $self->foreach_driver( 'storage', 'remove', $key );
}

sub Clear
{
    my ( $self ) = @_;

    $self->foreach_driver( 'storage', 'Clear' );
}

sub clear
{
    my ( $self ) = @_;

    $self->foreach_driver( 'storage', 'clear' );
}

sub Purge
{
    my ( $self ) = @_;

    $self->purge();
}

sub purge
{
    my ( $self ) = @_;

    $self->foreach_driver( 'pruning', 'purge', $self );
}

sub Size
{
    my ( $self ) = @_;
    my ( $size );

    $size = 0;
    $self->foreach_policy( 'storage',
        sub
        {
            my ( $self, $policy, $driver ) = @_;

            $size += $driver->Size();
        } );

    return( $size );
}

sub size
{
    my ( $self ) = @_;
    my ( $size );

    $size = 0;
    $self->foreach_policy( 'storage',
        sub
        {
            my ( $self, $policy, $driver ) = @_;

            $size += $driver->size();
        } );

    return( $size );
}

sub get_namespaces
{
    my ( $self ) = @_;
    my ( %namespaces );

    %namespaces = ();
    $self->foreach_policy( 'storage',
        sub
        {
            my ( $self, $policy, $driver ) = @_;

            foreach my $namespace ( $driver->get_namespaces() )
            {
                $namespaces{ $namespace }++;
            }
        } );

    return( keys( %namespaces ) );
}

sub get_keys
{
    my ( $self ) = @_;
    my ( %keys );

    %keys = ();
    $self->foreach_policy( 'storage',
        sub
        {
            my ( $self, $policy, $driver ) = @_;

            foreach my $key ( $driver->get_keys() )
            {
                $keys{ $key }++;
            }
        } );

    return( keys( %keys ) );
}

#set/get_namespace
#get_default_expires_in
#get_keys
#get_identifiers
#get/set_auto_purge_interval
#get/set_auto_purge_on_set
#get/set_auto_purge_on_get

#  Coerce the policy arg into a hashref and ordered param list.
sub _normalize_policies
{
    my ( $self, $policies ) = @_;

    return( {
        order => [ $policies ],
        param => { $policies => {} },
        } )
        unless ref( $policies );
    return( {
        order => [ keys( %{$policies} ) ],
        param => $policies,
        } )
        if ref( $policies ) eq 'HASH';
    if( ref( $policies ) eq 'ARRAY' )
    {
        my ( $ret );

        $self->error( "Policy arg wasn't even-sized arrayref" )
            unless $#{$policies} % 2;

        $ret = { order => [], param => {} };
        for( my $i = 0; $i <= $#{$policies}; $i += 2 )
        {
            push @{$ret->{ order }}, $policies->[ $i ];
            $ret->{ param }->{ $policies->[ $i ] } = $policies->[ $i + 1 ];
        }

        return( $ret );
    }
    $self->error( "Unknown policy format: " . ref( $policies ) );
}

sub set_policy
{
    my ( $self, $policytype, $policies ) = @_;
    my ( $factoryclass );

    $self->error( "No $policytype policy set" ) unless $policies;

    $policies = $self->_normalize_policies( $policies );
    $self->{ policies }->{ $policytype } = $policies;

    $factoryclass = 'Cache::CacheFactory::' .
        ( $policytype eq 'storage' ? 'Storage' : 'Expiry' );

    #  Handle compat param.
    $policies->{ param }->{ time }->{ default_expires_in } =
        $self->{ compat }->{ default_expires_in }
        if exists $self->{ compat }->{ default_expires_in } and
           $policies->{ param }->{ time } and
           not exists $policies->{ param }->{ time }->{ default_expires_in };

    $policies->{ drivers } = {};
    foreach my $policy ( @{$policies->{ order }} )
    {
        my ( $driver, $param );

        $param = $policies->{ param }->{ $policy };
        delete $policies->{ param }->{ $policy };
        {
            #  TODO: no strict 'refs';?
            $driver = $factoryclass->new( $policy, $param );
        }
        $self->error( "Unable to load driver for $policytype policy: $policy" )
            unless $driver;
        $policies->{ drivers }->{ $policy } = $driver;
    }
}

sub get_policy_driver
{
    my ( $self, $policytype, $policy ) = @_;

    return( $self->{ policies }->{ $policytype }->{ drivers }->{ $policy } );
}
sub get_policy_drivers
{
    my ( $self, $policytype ) = @_;

    return( $self->{ policies }->{ $policytype }->{ drivers } );
}

#
#
#  Next few methods run a closure against each policy or invoke a
#  method against each policy's driver.  It's a bit inefficient but
#  saves on duplicating the same ordering and looping code everywhere
#  and keeps me sane(ish).  Oh for a native ordered-hashref.
sub last
{
    my ( $self ) = @_;

    $self->{ _last } = 1;
}

sub foreach_policy
{
    my ( $self, $policytype, $closure ) = @_;
    my ( $policies );

    $policies = $self->{ policies }->{ $policytype };
    foreach my $policy ( @{$policies->{ order }} )
    {
        $closure->( $self, $policy, $policies->{ drivers }->{ $policy } );
        next unless $self->{ _last };
        delete $self->{ _last };
        last;
    }
}

sub foreach_driver
{
    my ( $self, $policytype, $method, @args ) = @_;
    my ( $policies );

    $policies = $self->{ policies }->{ $policytype };
    foreach my $policy ( @{$policies->{ order }} )
    {
        $policies->{ drivers }->{ $policy }->$method( @args );
        next unless $self->{ _last };
        delete $self->{ _last };
        last;
    }
}

sub set_storage_policies
{
    my ( $self, $policies ) = @_;

    $self->set_policy( 'storage', $policies );
}

sub set_pruning_policies
{
    my ( $self, $policies ) = @_;

    $self->set_policy( 'pruning', $policies );
}

sub set_validity_policies
{
    my ( $self, $policies ) = @_;

    $self->set_policy( 'validity', $policies );
}

1;

__END__

=pod

=head1 NAME

Cache::CacheFactory -- factory class for L<Cache::Cache|Cache::Cache> and other modules.

=head1 SYNOPSIS

 use Cache::CacheFactory;

 my $cache = Cache::CacheFactory->new( storage => 'file' );

 $cache->set( 'customer', 'Fred' );
 ... Later ...
 print $cache->get( 'customer' );
 ... prints "Fred"

=head1 DESCRIPTION

Cache::CacheFactory is a drop-in replacement for the L<Cache::Cache|Cache::Cache> subclasses
allowing you to access a variety of caching policies from a single place,
mixing and matching as you choose rather than having to search for the
cache module that provides the exact combination you want.

In a nutshell you specify a policy for storage, for pruning and for
validity checks and CacheFactory hooks you up with the right modules
to provide that behaviour while providing you with the same API you're
used to from Cache::Cache - the only thing you need to change is
your call to the constructor.

More advanced use allows you to set multiple policies for pruning and
validity checks, and even for storage although that's currently of
limited use.

=head1 METHODS

=over

=item $cache = Cache::CacheFactory->new( %options )

=item $cache = Cache::CacheFactory->new( $options )

Construct a new cache object with the specified options supplied as
either a hash or a hashref.

See L</"OPTIONS"> below for more details on possible options.

=item $cache->set( key => $key, data => $data, [ expires_in => $expires_in, %additional_args ] )

=item $cache->set( $key, $data, [ $expires_in ] ) (only in compat-mode)

Associates C<$data> with C<$key> in the cache.

C<$expires_in> indicates the time in seconds until this data should be
erased, or the constant C<$EXPIRES_NOW>, or the constant C<$EXPIRES_NEVER>.
Defaults to C<$EXPIRES_NEVER>. This variable can also be in the extended
format of "[number] [unit]", e.g., "10 minutes". The valid units are s,
second, seconds, sec, m, minute, minutes, min, h, hour, hours, d, day,
days, w, week, weeks, M, month, months, y, year, and years. Additionally,
C<$EXPIRES_NOW> can be represented as "now" and C<$EXPIRES_NEVER> can be
represented as "never".

C<$expires_in> is silently ignored (future versions may warn) if
the cache didn't choose a 'time' pruning or validity policy at setup.

Any additional args will be passed on to the policies chosen at setup
time (and documented by those policy modules.)

B<IMPORTANT:> The positional args version of this method is only
available if the compat flag C<positional_set> was supplied as an
option when the cache was created.

If C<positional_set> is a true value but not set to C<'auto'> then the
hash format is disabled and C<set()> acts as if it is always given
positional args - this will do unwanted things if you pass it hash
args.

If C<positional_set> was given C<'auto'> as a value then C<set()> will
attempt to auto-detect when you're supplying positional args and
when you're supplying hash args, it does this by the rather-breakable
means of asking if the first arg is called 'key', if so then it
assumes you're passing a hash, otherwise it'll fall back to using
positional args.

Examples:

  $cache->set(
      key        => 'customer',
      data       => 'Fred',
      expires_in => '10 minutes',
      );

  $created_at = time();
  $template = build_my_template( '/path/to/webpages/index.html' );
  $cache->set(
      key          => 'index',
      data         => $template,
      created_at   => $time,
      dependencies => [ '/path/to/webpages/index.html', ],
      );

=item $data = $cache->get( $key )

Gets the data associated with C<$key> from the first storage policy
that contains a fresh cached copy.

=item $cache->remove( $key )

Removes the data associated with C<$key> from each of the storage policies
in this cache.

=item $object = $cache->get_object( $key )

Returns the L<Cache::CacheFactory::Object|Cache::CacheFactory::Object> used to store the underlying
data associated with C<$key>. This behaves much the same as the
L<Cache::Object|Cache::Object> returned by C<< Cache::Cache->get_object() >>.

=item $cache->set_object( $key, $object )

Associates C<$key> with L<Cache::CacheFactory::Object|Cache::CacheFactory::Object> C<$object>. If you
supply a L<Cache::Object|Cache::Object> in C<$object> instead, L<Cache::CacheFactory|Cache::CacheFactory> will
create a new L<Cache::CacheFactory::Object|Cache::CacheFactory::Object> instance as a copy before
storing the copy.

=item $cache->Clear()

Clears all caches using each of the storage policies. This does
not just clear caches with the exact same policies: it calls
C<Clear()> on each policy in turn.

=item $cache->clear()

Removes all cached data for this instance's namespace from each
of the storage policies.

=item $cache->Purge()

B<COMPAT BUSTER:> C<Purge()> now does the same thing as C<purge()>
since it isn't clear quite what it should do with multiple
caches with different pruning and storage policies. Its use
is strongly deprecated.

=item $cache->purge()

Applies the pruning policy to all data in this namepace.

=item $size = $cache->Size()

Returns the total size of all objects in all caches with any
of the storage policies of this cache.

=item $size = $cache->size()

Returns the total size of all objects in this namespace in any of
the storage policies of this cache.

=item @namespaces = $cache->get_namespaces()

Returns a list of all namespaces in any of the storage policies of
this cache.

=back

=head1 OPTIONS

The following options may be passed to the C<new()> constructor:

=over

=item storage => $storage_policy

=item storage => { $storage_policy1 => $policy1_options, $storage_policy2 => $policy2_options, ... }

=item storage => [ $storage_policy1 => $policy1_options, $storage_policy2 => $policy2_options, ... ]

=item pruning => $pruning_policy

=item pruning => { $expry_policy1 => $policy1_options, $pruning_policy2 => $policy2_options, ... }

=item pruning => [ $pruning_policy1 => $policy1_options, $pruning_policy2 => $policy2_options, ... ]

=item validity => $validity_policy

=item validity => { $validity_policy1 => $policy1_options, $validity_policy2 => $policy2_options, ... }

=item validity => [ $validity_policy1 => $policy1_options, $validity_policy2 => $policy2_options, ... ]

Chooses a storage, pruning, or validity policy (or policies) possibly
passing in a hashref of options to each policy.

Passing a hashref of policies is probably a bad idea since you have
no control over the order in which policies are processed, if you
supply them as an arrayref then they will be run in order.

See L</"POLICIES"> below for more information on policies.

=item auto_purge_interval => $interval

=item auto_purge_on_set   => 0 | 1

=item auto_purge_on_get   => 0 | 1

=item default_expires_in  => $expiry_time

This option is for backwards compatibility with L<Cache::Cache|Cache::Cache>.

If set it is passed on to the C<'time'> pruning and/or validity policy
if you have chosen either of them.

B<WARNING:> if you do NOT have an pruning or validity policy of 'time',
this option is silently ignored. This may raise a warning in future
versions.

=item positional_set => 0 | 1 | 'auto'

This option is for backwards compatibility with L<Cache::Cache|Cache::Cache>.

If set to a true value that isn't 'auto' it indicates that
C<< $cache->set() >> should behave exactly as that in
L<Cache::Cache|Cache::Cache>, accepting only positional
parameters. If you set this option you will be unable to
supply parameters to policies other than C<expires_in> to
the C<'time'> pruning or validity policy.

If set to a value of 'auto' L<Cache::CacheFactory|Cache::CacheFactory>
will attempt to auto-detect whether you're supplying positional
or named parameters to C<< $cache->set() >>. This mechanism is
not very robust: it simply looks to see if the first parameter
is the value 'key', if so it assumes you're supplying named
parameters.

The default behaviour, or if you set C<positional_set> to a false
value, is to assume that named parameters are being supplied.

Generally speaking, if you know for sure that all your code is
using positional parameters you should set it to true, if you
know all your code is using the new named parameters syntax
you should set it false (or leave it undefined), and if you're
uncertain or migrating from one to the other, you should set it
to 'auto' and be careful that you always supply the C<key> param
first.

=back

=head1 POLICIES

There are three types of policy you can set: storage, pruning and
validity.

L<Storage|/"Storage Policies"> determines what mechanism is used to store
the data.

L<Pruning|"Pruning and Validity Policies"> determines what mechanism is used
to reap or prune the cache.

L<Validity|"Pruning and Validity Policies"> determines what mechanism is
used to determine if a cache entry is still up-to-date.

=head2 Storage Policies

Some common storage policies:

=over

=item file

Implemented using L<Cache::FileCache|Cache::FileCache>, this provides
on-disk caching.

=item memory

Implemented using L<Cache::MemoryCache|Cache::MemoryCache>, this provides
per-process in-memory caching.

=item sharedmemory

Implemented using L<Cache::SharedMemoryCache|Cache::SharedMemoryCache>,
this provides in-memory caching with the cache shared between processes.

=item null

Implemented using L<Cache::NullCache|Cache::NullCache>, this cache is
used to provide a fake cache that never stores anything.

=back

=head2 Pruning and Validity Policies

All I<pruning> and I<validity> policies are interchangable, the difference
between the two is when the policy is applied:

An pruning policy is applied when you C<purge()> or periodically if
C<auto_purge_on_set> or C<autopurge_on_get> is set, it removes all
entries that fail the policy from the cache. Note that an item can
be I<eligible> to be pruned but still be in the cache and fetched
successfully from the cache - it won't be removed until C<purge()>
is called either manually or automatically.

A validity policy is applied when an entry is retreived to ensure
that it's still valid (or fresh or up-to-date if you prefer). If the entry
isn't still valid then it's ignored as if it was never in the cache.
Unlike pruning, validity always applies - you will never be able
to fetch an item from the cache if it is invalid according to the
policies you have chosen.

A handy shorthand is that pruning determines how long we keep the
data lying around in case we need it again, validity determines
whether we trust that it's still accurate.

=over

=item time

This provides pruning and validity policies similar to those
built into L<Cache::Cache|Cache::Cache> using the C<expires_at>
param.

It allows you to check for entries that are over a certain age.

=item size

This policy prunes the cache to attempt to keep it under a
supplied size, much like
L<Cache::SizeAwareFileCache|Cache::SizeAwareFileCache>
and the other C<Cache::SizeAware*> modules.

This policy probably doesn't make much sense as a validity
policy, although you can use it.

=item lastmodified

This policy compares the created date of the cache entry
to the last-modified date of a list of file dependencies.

If the create date is older than any of the file last-modified
dates the entry is pruned or regarded as invalid.

This is useful if you have data compiled or parsed from
source data-files that may change, such as HTML templates
or XML files.

=item forever

This debugging policy never regards items as invalid or
prunable, it's implemented as the default behaviour in
L<Cache::CacheFactory::Expiry::Base|Cache::CacheFactory::Expiry::Base>.

=back

=head1 WRITING NEW POLICIES

It's possible to write custom policy modules of your own, all
policies are constructed using the
L<Cache::CacheFactory::Storage|Cache::CacheFactory::Storage>
or L<Cache::CacheFactory::Expiry|Cache::CacheFactory::Expiry>
class factories. C<Storage> provides the storage policies and
C<Expiry> provides both the pruning and validity policies.

New storage policies should conform to the L<Cache::Cache|Cache::Cache>
API, in particular they need to implement C<set_object> and
C<get_object>.

New expiry policies (both pruning and validity) should follow
the API defined by
L<Cache::CacheFactory::Expiry::Base|Cache::CacheFactory::Expiry::Base>,
ideally by subclassing it.

Once you've written your new policy module you'll need to
register it with L<Cache::CacheFactory|Cache::CacheFactory>
as documented in L<Class::Factory|Class::Factory>, probably
by placing one of the the following lines (depending on type)
somewhere in your module:

  Cache::CacheFactory::Storage->register_factory_type(
      mypolicyname => 'MyModules::MyPolicyName' );

  Cache::CacheFactory::Expiry->register_factory_type(
      mypolicyname => 'MyModules::MyPolicyName' );

Then you just need to make sure that your application has a

  use MyModules::MyPolicyName;

before you ask L<Cache::CacheFactory|Cache::CacheFactory> to
create a cache with 'mypolicyname' as a policy.

=head1 INTERNAL METHODS

The following methods are mostly for internal use, but may be useful
to redefine if you're subclassing L<Cache::CacheFactory|Cache::CacheFactory> for some
reason.

=over

=item $object = $cache->new_cache_entry_object()

Returns a new and uninitialized object to use for a cache entry,
by default this object will be a L<Cache::CacheFactory::Object|Cache::CacheFactory::Object>,
if for some reason you want to overrule that decision you can
return your own object.

=item $cache->set_policy( $policytype, $policies )

Used as part of the C<new()> constructor, this sets the policy
type C<$policytype> to use the policies defined in C<$policies>,
this may do strange things if you do it to an already used cache
instance.

=item $cache->set_storage_policies( $policies )

=item $cache->set_pruning_policies( $policies )

=item $cache->set_validity_policies( $policies )

Convenience wrappers around C<set_policy>.

=item $cache->get_policy_driver( $policytype, $policy )

Gets the driver object instance for the matching C<$policytype> and
C<$policy>, useful if it has non-standard extensions to the API
that you can't access through L<Cache::CacheFactory|Cache::CacheFactory>.

=item $cache->get_policy_drivers( $policytype )

Returns a hashref of policies to driver object instances for policy
type C<$policytype>, you should probably use C<get_policy_driver()>
instead to get a specific driver though.

=item $cache->foreach_policy( $policytype, $closure )

Runs the closure/coderef C<$closure> over each policy of type
C<$policytype> supplying args: C<Cache::CacheFactory> instance,
policy name, and policy driver.

The closure is run over each policy in order, or until the closure
calls the C<last()> method on the C<Cache::CacheFactory> instance.

  use Data::Dumper;
  use Cache::CacheFactory;

  $cache = Cache::CacheFactory->new( ... );
  $cache->foreach_policy( 'storage',
      sub
      {
          my ( $cache, $policy, $driver ) = @_;

          print "Storage policy '$policy' has driver: ",
              Data::Dumper::Dumper( $driver ), "\n";
          return $cache->last() if $policy eq 'file';
      } );

This will print the policy name and driver object for each storage
policy in turn until it encounters a C<'file'> policy.

=item $cache->foreach_driver( $policytype, $method, @args )

Much like C<foreach_policy()> above, this method iterates over
each policy, this time invoking method C<$method> on the driver
with the arguments specified in C<@args>.

  $cache->foreach_driver( 'storage', 'do_something', 'with', 'args' );

will call:

  $driver->do_something( 'with', 'args' );

on each storage driver in turn.

The return value of the method called is discarded, if it's
important to you then you should use C<foreach_policy> and
call the method on the driver arg provided, collating the
results however you wish.

=item $cache->last()

Indicates that C<foreach_policy()> or C<foreach_driver> should
exit at the end of the current iteration. C<last()> does B<NOT>
exit your closure for you, if you want it to behave like perl's
C<last> construct you will want to do C<< return $cache->last() >>.

=back

=head1 KNOWN ISSUES AND BUGS

=over

=item Pruning and validity policies are per-cache rather than per-storage

Pruning and validity policies are set on a per-cache basis rather than
on a per-storage-policy basis, this makes multiple storage policies
largely pointless for most purposes where you'd find it useful.

If you wanted the cache to transparently use a small fast memory cache
first and fall back to a larger slower file cache as backup: you can't
do it, becase the size pruning policy would be the same for both storage
policies.

About the only current use of multiple storage policies is to have a
memory cache and a file cache so that processes that haven't pulled
a copy into their memory cache yet will retreive it from the copy
another process has placed in the file cache. This might be slightly
more useful than a shared memory cache since the on-file cache will
persist even if there's no running processes unlike the shared memory
cache.

Per-storage pruning and validity settings may make it into a future
version if they prove useful and won't over-complicate matters - for
now it's best to create a wrapper module that internally creates the
caches seperately but presents the Cache::Cache API externally.

=back

=head1 SEE ALSO

L<Cache::Cache|Cache::Cache>, L<Cache::CacheFactory::Object|Cache::CacheFactory::Object>

=head1 AUTHORS

Original author: Sam Graham <libcache-cachefactory-perl BLAHBLAH illusori.co.uk>

Last author:     $Author: illusori $

=head1 COPYRIGHT

Copyright 2008 Sam Graham.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
