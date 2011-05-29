package Cache::CacheFactory::Expiry;

# ABSTRACT: Factory class for expiry policies for Cache::CacheFactory.

use warnings;
use strict;

use Class::Factory;

use base qw/Class::Factory/;

$Cache::CacheFactory::Expiry::VERSION = '1.10';

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

__END__

=pod

=head1 NAME

Cache::CacheFactory::Expiry - Factory class for expiry policies for Cache::CacheFactory.

=head1 VERSION

version 1.10

=head1 DESCRIPTION

L<Cache::CacheFactory::Expiry> is a class factory for
expiry (pruning and validity) policies used by
L<Cache::CacheFactory>.

You will only need to know about this module if you're
writing your own expiry policy modules, documented in
L<Cache::CacheFactory/"WRITING NEW POLICIES">.

=head1 METHODS

=over

=item $policy = Cache::CacheFactory::Expiry->new( $type, @param );

Construct an expiry policy of the specified type, supplying C<@param>
to the constructor of the policy object.

=back

=head1 SEE ALSO

L<Cache::CacheFactory>, L<Class::Factory>

=head1 COPYRIGHT

Copyright 2008-2010 Sam Graham.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 AUTHOR

Sam Graham <libcache-cachefactory-perl BLAHBLAH illusori.co.uk>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2008-2011 by Sam Graham <libcache-cachefactory-perl BLAHBLAH illusori.co.uk>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
