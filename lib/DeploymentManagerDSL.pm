package DeploymentManagerDSL::Object {
  use Moose;

  has object_model => (
    is => 'ro',
    isa => 'DeploymentManager::Template::Jinja',
    lazy => 1,
    builder => 'build_om',
    handles => {
      as_hashref => 'as_hashref',
    }
  );

  sub build_om {
    my $self = shift;

    # gather all the resources and outputs to generate a Deployme
    return DeploymentManager::Template::Jinja->new(
      properties => [
        map { $_->name }
          grep { $_->does('CCfnX::Meta::Attribute::Trait::DeploymentManagerParameter') }
            $self->params_class->meta->get_all_attributes
      ],
      resources => [
        map { $_->get_value($self) } 
          sort { $a->name cmp $b->name } 
            grep { $_->does('CCfnX::Meta::Attribute::Trait::DeploymentManagerResource') }
              $self->meta->get_all_attributes
      ],
    );
  }

  our $moose_type_for = {
    string => 'Str',
    boolean => 'Bool',
    integer => 'Int',
    number => 'Num',
  };

  sub params_class {
    my $class = shift;
    my $class_meta = $class->meta;
    my $class_name = $class_meta->name;

    my $class_params_name = "${class_name}AutoParameters";

    my @param_list =
      grep { $_->does('CCfnX::Meta::Attribute::Trait::DMDSLParameter') }
      $class_meta->get_all_attributes;

    my @param_attrs = map {
      # Invoke the attributes default to get the DeploymentManager::Property object
      my $dm_property = $_->default->();

      my $moose_type = $moose_type_for->{ $dm_property->type };
      die "Cannot convert to Moose type" if (not defined $moose_type);

      my $attr = Moose::Meta::Attribute->new(
        $_->name,
        is  => 'ro',
        isa => $moose_type,
        (defined $dm_property->default) ? (default => $dm_property->default) : (),
        ($_->does('CCfnX::Meta::Attribute::Trait::DMDSLRequired')) ? (required => 1) : (),
      );
      # Apply StackParameter trait to the attribute dynamically
      $_->does('CCfnX::Meta::Attribute::Trait::DeploymentManagerParameter')
          ? Moose::Util::apply_all_roles($attr, 'CCfnX::Meta::Attribute::Trait::DeploymentManagerParameter')
          : $attr;
    } @param_list;

    require MooseX::Getopt;

    my $params_class = Moose::Meta::Class->create(
      $class_params_name,
      superclasses => ['Moose::Object'],
      roles        => ['MooseX::Getopt'],
      attributes   => [ @param_attrs ],
    );
    return $class_params_name;
  }

  sub stub { 42 }
}
package DeploymentManagerDSL {
  use Moose ();
  use Moose::Exporter;
  use Moose::Util::MetaRole ();
  use DeploymentManager;
  use boolean ();

  Moose::Exporter->setup_import_methods(
    with_meta => [qw/parameter resource output true false/],
    as_is => [qw//],
    also => 'Moose',
  );

  sub init_meta {
    shift;
    my %args = @_;

    return Moose->init_meta(%args, base_class => 'DeploymentManagerDSL::Object');
  }

  sub true { boolean::true }
  sub false { boolean::false }

  sub parameter {
    my ($meta, $name, $type, $properties) = @_;
    $properties = {} if (not defined $properties);

    my $r = DeploymentManager::Property->new(
      type => $type,
    );

    my $traits = [ 'CCfnX::Meta::Attribute::Trait::DMDSLParameter' ];
    if (defined $properties->{ in_template } and $properties->{ in_template } == 1) {
      push @$traits, 'CCfnX::Meta::Attribute::Trait::DeploymentManagerParameter';
    }
    if (defined $properties->{ required } and $properties->{ required } == 1) {
      push @$traits, 'CCfnX::Meta::Attribute::Trait::DMDSLRequired';
    }
    _plant_attribute(
      $meta,
      $name,
      'DeploymentManager::Property',
      $traits,
      sub { $r }
    );
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
package CCfnX::Meta::Attribute::Trait::DMDSLRequired {
  use Moose::Role;
}
package CCfnX::Meta::Attribute::Trait::DMDSLParameter {
  use Moose::Role;
}
package CCfnX::Meta::Attribute::Trait::DeploymentManagerResource {
  use Moose::Role;
}
package CCfnX::Meta::Attribute::Trait::DeploymentManagerParameter {
  use Moose::Role;
}
1;
