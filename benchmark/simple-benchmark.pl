#!perl -w

use strict;
use Benchmark qw(:all);

use FindBin qw($Bin);
use lib $Bin;
use Common;

use Scalar::Util qw(blessed);
use Scalar::Util::Instance;

*is_a_Foo = Scalar::Util::Instance::generate_isa_checker_for('Foo');

signature
    'Scalar::Util' => \&blessed,
    'Scalar::Util::Instance' => \&is_a_Foo,
;

sub noop { }

BEGIN{
    package Base;
    sub new{
        bless {} => shift;
    }
    
    package Foo;
    our @ISA = qw(Base);
    package Foo::X;
    our @ISA = qw(Foo);
    package Foo::X::X;
    our @ISA = qw(Foo::X);
    package Foo::X::X::X;
    our @ISA = qw(Foo::X::X);

    package Unrelated;
    our @ISA = qw(Base);

    package SpecificIsa;
    our @ISA = qw(Base);
    sub isa{
        $_[1] eq 'Foo';
    }
}

foreach my $x (Foo->new, Foo::X::X::X->new, Unrelated->new, undef){
    print 'For ', defined($x) ? $x : 'undef', "\n";

    my $i = 0;

    cmpthese -1 => {
        'blessed' => sub{
            for(1 .. 10){
                $i++ if blessed($x) && $x->isa('Foo');
            }
        },
        'is_a_Foo' => sub{
            for(1 .. 10){
                $i++ if is_a_Foo($x);
            }
        },
        'noop' => sub{
            for(1 .. 10){
                $i++ if noop($x);
            }
        },
    };

    print "\n";
}
