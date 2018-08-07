package DeploymentManagerDSL::Object {
  use Moose;

  has object_model => (
    is => 'ro',
    isa => 'DeploymentManager::Template::Jinja',
    lazy => 1,
    builder => 'build_om'
  );

  sub build_om {
    my $self = shift;

    # gather all the resources and outputs to generate a Deployme
    return DeploymentManager::Template::Jinja->new(
      resources => [
        map { $_->get_value($self) } 
          sort { $a->name cmp $b->name } 
            grep { $_->does('CCfnX::Meta::Attribute::Trait::DeploymentManagerResource') }
              $self->meta->get_all_attributes
      ],
    );
  }

  sub as_hashref {
    my $self = shift;
    return $self->object_model->as_hashref;
  }

  sub stub { 42 }
}
package DeploymentManagerDSL {
  use Moose ();
  use Moose::Exporter;
  use Moose::Util::MetaRole ();
  use DeploymentManager;

  Moose::Exporter->setup_import_methods(
    with_meta => [qw/parameter resource output/],
    as_is => [qw//],
    also => 'Moose',
  );

  sub init_meta {
    shift;
    my %args = @_;

    return Moose->init_meta(%args, base_class => 'DeploymentManagerDSL::Object');
  }

  sub parameter {

  }

  sub resource {
    my ($meta, $name, $type, $properties, $base_properties) = @_;

    die "Must specify a name for a resource NAME => 'TYPE', { property1 => '...' }[, { base_property1 => '...' }];" if (not defined $name);
    die "Must specify a type for a resource NAME => 'TYPE', { property1 => '...' }[, { base_property1 => '...' }];" if (not defined $type);

    _die_if_already_declared_in_class($meta, $name);

    my $r = DeploymentManager::Resource->new(
      type => $type,
      name => $name,
      (defined $properties) ? (properties => $properties) : (),
      (defined $base_properties) ? (metadata => $base_properties) : (),
    );

    _plant_attribute(
      $meta,
      $name,
      'DeploymentManager::Resource',
      'CCfnX::Meta::Attribute::Trait::DeploymentManagerResource',
      sub { $r }
    );
  }

  sub output {

  }

  sub _plant_attribute {
    my ($meta, $name, $type, $traits, $generator) = @_;

    $traits = [ $traits ] if (ref($traits) ne 'ARRAY');

    $meta->add_attribute(
      $name,
      is => 'rw',
      isa => $type,
      traits => $traits,
      default => $generator
    );
  }

  sub _die_if_already_declared_in_class {
    my ($meta, $name) = @_;

    if ($meta->find_attribute_by_name($name)) {
      Moose->throw_error("$name is already declared as a resource, parameter, variable or output")
    }
  }
}
package CCfnX::Meta::Attribute::Trait::DeploymentManagerResource {
  use Moose::Role;
}
1;
