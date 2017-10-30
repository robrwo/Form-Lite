package  MooX::Form::Field;

use curry;
use mro;

use Moo;

use Carp;
use Class::Method::Modifiers qw/ install_modifier /;
use List::AllUtils qw/ pairmap /; # FIXME min version
use Package::Stash;
use PerlX::Maybe;
use Ref::Util qw/ is_hashref is_ref /;
use Role::Tiny ();
use Types::Standard -types;

# RECOMMENDS Class::MOP

use namespace::autoclean;

has input => (
    is        => 'rwp',
    predicate => 1,
);

has value => (
    is        => 'rwp',
    predicate => 1,
    clearer   => 1,
    init_args => undef,
);

around _set_value => sub {
    my ($next, $self, $value) = @_;
    $self->_set_input($value);
    if ($self->has_type) {

        if  (my $error = $self->validate($value)) {
            $self->_set_error($error);
            return $self->clear_value;
        }
        else {
            $self->clear_error;
            return $self->$next($value);
        }
    }
};

has error => (
    is     => 'rwp',
    clearer => 1,
    init_args => undef,
);

has type => (
    is        => 'rw',
    isa       => InstanceOf['Type::Tiny'],
    predicate => 1,
    handles   => [qw/ validate /],
);

# borrowed from MooX::Aliases

sub import {
  my ($class) = @_;

  my $target = caller;

  my $has   = $target->can('has');
  my $stash = Package::Stash->new( $target );

  my $fields = $stash->get_or_add_symbol( '%FIELD_ATTRIBUTES' );

  # TODO: use has instead of has_field

  my $attr_builder = sub {
      my ($attr, %opts) = @_;

      # TODO: test this

      my $name = substr($attr, 0, 1) eq '+'
          ? substr($attr, 1)
          : $attr;

      foreach my $key (qw/ builder predicate /) {
          delete $opts{$key} if $opts{$key} && $opts{$key} eq 1;
      }

      my $wrapper = delete($opts{wrapper}) // $class ;
      Moo::_load_module($wrapper) if $wrapper ne __PACKAGE__;

      my $builder   = ( $opts{builder}   //= "_build_${name}" );
      my $writer    = ( $opts{writer}    //= "_set_${name}" );
      my $predicate = ( $opts{predicate} //= "has_${name}" );

      my $isa    = delete $opts{isa};
      $opts{isa} = Object if $isa;

      unless ($stash->get_symbol( '&'.$builder )) {

          if (exists $opts{default}) {

              $opts{builder} = $builder;
              my $default    = delete $opts{default};
              if (is_ref($default)) {
                  $stash->add_symbol('&' . $builder, $default );
              }
              else {
                  $stash->add_symbol('&' . $builder, sub { return $default } );
              }

          }

      }

      my $constr = $wrapper->curry::new(
          maybe type => $isa,
      );

      if ($stash->get_symbol( '&'.$builder )) {

          install_modifier $target, 'around', $builder, sub {
              my ($next, $self) = @_;
              return $constr->( value => $self->$next );
          };
      }
      else {

          $stash->add_symbol('&' . $builder, sub {
              return $constr->();
          } );

      }

      # TODO: trigger
      # TODO: coerce
      # TODO: handles
      # TODO: clearer
      # TODO: weakref
      # TODO: reader

      $opts{predicate} //= 1;

      $has->($attr, %opts);

      unless ((exists $opts{init_arg}) &&  !(defined $opts{init_arg})) {
          $fields->{ $opts{init_arg} // $name } = {
              _new     => $constr,
          };
      }

      if ($opts{is} eq 'rw') {

          install_modifier $target, 'around', $name, sub {
              my $next = shift;
              my $self = shift;

              if (@_) {
                  $self->$next( $self->$writer( @_ ) );
              }
              else {
                  $self->$next();
              }

          };

      }

      install_modifier $target, 'around', $writer, sub {
          my ($next, $self, $value) = @_;

          if ($self->$predicate) {
              $self->$attr->_set_value($value);
              return $self->$attr;

          }
          else {
              my $this = $constr->( value => $value );
              return $self->$next( $this );
          }
      };


  };

  # Note: required has a different meaning

  Moo::_install_coderef( "${target}::has_field", "has_field" => $attr_builder );

  # TODO: is this needed for namespace cleaning?

  if ( my $info = $Role::Tiny::INFO{$target} ) {
      $info->{exports}{has_field}         = $attr_builder;
      $info->{not_methods}{$attr_builder} = $info->{exports}{has_field};
  }

  # not on a role

  unless (Role::Tiny->is_role($target)) {

      $stash->add_symbol(
          '&BUILDARGS', sub {
          my ($class, @args) = @_;

          if ( (@args == 1) && is_hashref($args[0]) ) {
              @args =  %{ $args[0] };
          }

          my $attrs = $target->field_attrs;

          return { pairmap {
                  if (my $opts = $attrs->{$a}) {
                      $b = $opts->{_new}->( value => $b );
                  }
                  return ( $a, $b );
          }  @args };

          }
      );

      my $fields_list = sub {
          my ($self) = @_;

          # TODO: state

          my %field_attrs = (
              %$fields,
              %{ $self->maybe::next::method // {} }
          );

          my @roles = map { $_->name }
             $self->meta->calculate_all_roles_with_inheritance;

          foreach my $name (@roles) {

              my $stash = Package::Stash->new($name)
                  or next;

              if (my $meta = $stash->get_symbol('%FIELD_ATTRIBUTES')) {
                  $field_attrs{ $_ } = $meta->{$_} for keys %$meta;
              }

          }

          return \%field_attrs;
      };

      Moo::_install_coderef( "${target}::field_attrs",
                             "field_attrs" => $fields_list );

  }

}

sub BUILD {
    my ($self, $args) = @_;

    if (exists $args->{value}) {
        $self->_set_value( delete $args->{value} );
    }

}

1;
