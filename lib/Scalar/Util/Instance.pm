package Scalar::Util::Instance;

use 5.008_001;
use strict;
use warnings FATAL => 'all';

our $VERSION = '0.001';

use XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

sub import {
    my $class  = shift;

    $class->_install_into(scalar(caller), @_);
    return;
}

sub _install_into{
    my($class, $into, @args) = @_;

    foreach my $config(@args){
        my $as = $config->{as};
        if(!defined $as){
            require Carp;
            Carp::croak("You must define an predicate name by 'as'");
        }
        if($as !~ /::/){
            $as = $into . '::' . $as;
        }
        $class->generate_for($config->{for}, $as);
    }
    return;
}

1;
__END__

=head1 NAME

Scalar::Util::Instance - Generates is-a checking predicates

=head1 VERSION

This document describes Scalar::Util::Instance version 0.001.

=head1 SYNOPSIS

    use Scalar::Util::Instance
        { for => 'Foo', as => 'is_a_Foo' },
        { for => 'Bar', as => 'is_a_Bar' },
    ;

    # ...
    if(is_a_Foo($thing)){
        # ...
    }
    elsif(is_a_Bar($thing)){
        # ...
    }

=head1 DESCRIPTION

Scalar::Util::Instance provides

=head1 INTERFACE

=head2 Functions

=head3 C<< Scalar::Util::Instance->generate_for(ClassName, ?PredicateName) -> CODE >>

=head1 DEPENDENCIES

Perl 5.8.1 or later, and a C compiler.

=head1 BUGS

No bugs have been reported.

Please report any bugs or feature requests to the author.

=head1 SEE ALSO

=head1 AUTHOR

Goro Fuji (gfx) E<lt>gfuji(at)cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2009, Goro Fuji (gfx). Some rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
