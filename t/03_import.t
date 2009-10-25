#!perl -w
use strict;
use Test::More tests => 6;

use Scalar::Util::Instance
    { for => 'Foo', as => 'is_a_Foo' },
    { for => 'Bar', as => 'A::is_a_Bar' },
;

BEGIN{
    package Foo;
    sub new{ bless {}, shift }

    package Bar;
    our @ISA = qw(Foo);

    package Baz;
    sub new{ bless {}, shift }
}

ok is_a_Foo(Foo->new);
ok is_a_Foo(Bar->new);
ok!is_a_Foo(Baz->new);

ok!A::is_a_Bar(Foo->new);
ok A::is_a_Bar(Bar->new);
ok!A::is_a_Bar(Baz->new);

