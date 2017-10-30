package Baz;

use lib 'lib';

use Moo::Role;

use MooX::Form::Field;
use Types::Standard -types;

use namespace::autoclean;

has_field that => (
    is      => 'rw',
    isa     => Str,
    );

1;

package Bar;

use lib 'lib';

use Moo;
extends 'MooX::Form::Field';

use Types::Standard -types;

use namespace::autoclean;

has tag => (
    is => 'ro',
    isa => Str,
    default => 'bar',
);

has attributes => (
    is      => 'rw',
    isa     => HashRef[Str],
    default => sub { {} },
);

sub markup_attributes {
    my ($self) = @_;

    join(' ', map { sprintf('%s="%s"', $_, $self->attributes->{$_} ) }
         (keys %{$self->attributes})
        )
}

sub markup_open {
    my ($self) = @_;

}


1;

package Foo;

use Moo;
with 'Baz';

use lib 'lib';

use MooX::Form::Field;

use Types::Standard -types;

#use namespace::autoclean;

has_field this => (
    is      => 'rw',
    isa     => Int,
    builder => 1,
    wrapped => 1,
    writer  => '_set_this',
    wrapper => 'Bar',
    trigger => 1,
);

sub _build_this {
    return  time;
}

sub _trigger_this {
    use DDP; p @_;
};


package main;

my $x = Foo->new( this => 26, that => 'xyz' );


use DDP;
p $x;

p $x->this;

$x->this('x');

p $x->this;

$x->_set_this(14);
p $x->this;

my $v = $x->this;
print "$v\n";

p $x->that;

#p $x->field_attrs;
