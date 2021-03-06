package DDGC::Web::Role::Meta::Form;
# ABSTRACT: TODO - dont use

use Moose::Role;
use Class::Load;

has form_name => (
  is => 'rw',
  isa => 'Str',
  lazy => 1,
  default => sub {
    my $form_name = $_[0]->name;
    $form_name =~ s/::/_/g;
    return lc($form_name);
  },
);

has form_class => (
  is => 'rw',
  isa => 'Str',
  lazy => 1,
  default => sub { 'DDGC::Web::Form' },
);

has form_finish_code => (
  is => 'rw',
  isa => 'CodeRef',
  predicate => 'has_form_finish_code',
);

has default_form_field_class => (
  is => 'rw',
  isa => 'Str',
  lazy => 1,
  default => sub { 'DDGC::Web::Form::Field' },
);

has form_field_definitions => (
  traits  => ['Array'],
  is => 'ro',
  isa => 'ArrayRef[HashRef]',
  lazy => 1,
  default => sub { [] },
  handles => {
    add_form_field_definition => 'push',
    map_form_field_definitions => 'map',
    has_form_field_definitions => 'count',
  },
);

sub get_form {
  my ( $self, $c, $with, %args ) = @_;
  my @field_definitions;
  for my $field_definition (@{$self->form_field_definitions}) {
    my $add = 1;
    if (defined $field_definition->{cond}) {
      my $cond = delete $field_definition->{cond};
      $add = $cond->($c,$with,%args) for ($field_definition);
    }
    if ($add) {
      push @field_definitions, $field_definition;
    }
  }
  $args{obj} = $with if ref $with;
  $args{obj} = $with->new if defined $INC{$with} and $with->can('new');
  my $form_name = defined $args{form_name}
    ? delete $args{form_name}
    : $self->form_name;
  my $form_class = defined $args{form_class}
    ? delete $args{form_class}
    : $self->form_class;
  Class::Load::load_class($form_class);
  $form_class->new_via_definitions($c, $form_name, \@field_definitions,
    $self->has_form_finish_code ? ( finish_code => $self->form_finish_code ) : (),
  );
}

1;
