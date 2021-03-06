package DeploymentManagerDSL::Object {
  use Moose;
  use Path::Tiny;
  use YAML::PP;

  has object_model => (
    is => 'ro',
    isa => 'DeploymentManager::Template::Jinja',
    lazy => 1,
    builder => 'build_om',
    handles => {
      as_hashref => 'as_hashref',
      num_of_properties => 'num_of_properties',
    }
  );

  has config_model => (
    is => 'ro',
    isa => 'DeploymentManager::Config',
    lazy => 1,
    builder => 'build_cm',
  );

  # Return the name of the class
  sub type {
    my $self = shift;
    return $self->meta->name;
  }

  has _temp_jinja_file => (is => 'ro', isa => 'Path::Tiny', lazy => 1, default => sub {
    my $self = shift;
    Path::Tiny->tempfile( TEMPLATE => 'deploymentmanager_dsl_jinja_XXXXXX', SUFFIX => '.jinja' );
  });
  has _temp_config_file => (is => 'ro', isa => 'Path::Tiny', lazy => 1, default => sub {
    my $self = shift;
    Path::Tiny->tempfile( TEMPLATE => 'deploymentmanager_dsl_config_XXXXXX', SUFFIX => '.yaml' );
  });

  has jinja_content => (is => 'ro', isa => 'Str', lazy => 1, default => sub {
    my $self = shift;
    return YAML::PP->new->dump_string($self->object_model->as_hashref);
  });
  has config_content => (is => 'ro', isa => 'Str', lazy => 1, default => sub {
    my $self = shift;
    return YAML::PP->new->dump_string($self->config_model->as_hashref);
  });

  has jinja_full_path => (is => 'ro', isa => 'Str', lazy => 1, default => sub {
    my $self = shift;
    $self->_temp_jinja_file->spew($self->jinja_content);
    return $self->_temp_jinja_file->stringify;
  });
  has jinja_path_relative => (is => 'ro', isa => 'Str', lazy => 1, default => sub {
    my $self = shift;
    # Generate the jinja file too...
    $self->jinja_full_path;
    $self->_temp_jinja_file->relative($self->_temp_config_file->parent)->stringify;
  });
  has config_file_name => (is => 'ro', isa => 'Str', lazy => 1, default => sub {
    my $self = shift;
    $self->_temp_config_file->spew($self->config_content);
    return $self->_temp_config_file->stringify;
  });
 
  has property_values => (is => 'rw', isa => 'HashRef');

  sub build_cm {
    my $self = shift;

    die "Can't generate a config yaml if property_values isn't set" if (not defined $self->property_values);

    return DeploymentManager::Config->from_hashref({
      imports => [ { path => $self->jinja_path_relative } ],
      resources => [
        {
          name => 'deployment',
          type => $self->jinja_path_relative,
          properties => $self->property_values,
        },
      ],
      outputs => [
        map { 
          {
            name => $_->name,
            value => $_->value,
          }
        } @{ $self->object_model->outputs }
      ],
    });
  }

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
      outputs => [
         map { $_->get_value($self) } 
          sort { $a->name cmp $b->name } 
            grep { $_->does('CCfnX::Meta::Attribute::Trait::DeploymentManagerOutput') }
              $self->meta->get_all_attributes
      ]
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
}
package DeploymentManagerDSL {
  use Moose ();
  use Moose::Exporter;
  use Moose::Util::MetaRole ();
  use DeploymentManager;
  use boolean ();
  use Ref::Util qw/is_hashref/;

  Moose::Exporter->setup_import_methods(
    with_meta => [qw/parameter resource output true false/],
    as_is => [qw/RawName Ref Env/],
    also => 'Moose',
  );

  sub RawName {
    my $name = shift;
    { name => $name,
      template => "%s",
    }
  }

  sub Ref {
    my ($ref, $path) = @_;
    die "Ref must have two parameters" if (not defined $path);
    return qq|\$(ref.$ref.$path)|;
  }

  sub Env {
    my $env = shift;
    qq|{{ env["$env"] }}|
  }

  sub init_meta {
    shift;
    my %args = @_;

    return Moose->init_meta(%args, base_class => 'DeploymentManagerDSL::Object');
  }

  sub true { boolean::true }
  sub false { boolean::false }

  sub parameter {
    my ($meta, $name, $type, $properties) = @_;

    _die_if_already_declared_in_class($meta, $name);

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

    my $name_data;
    if (is_hashref($name)) {
      $name_data = $name;
    } else {
      $name_data = {
        name => $name,
        template => "%s-" . Env('deployment')
      }
    }

    die "Can't create a resource without a name" if (not defined $name_data->{ name });
    die "Can't create a resource without a template" if (not defined $name_data->{ template });
    die "Name templates have to have a %s in them" if ($name_data->{ template } !~ m/\%s/);

    $name_data->{ final_name } = sprintf($name_data->{ template }, $name_data->{ name });

    _die_if_already_declared_in_class($meta, $name_data->{ name });

    my $r = DeploymentManager::Resource->from_hashref({
      type => $type,
      name => $name_data->{ final_name },
      (defined $properties) ? (properties => $properties) : (),
      (defined $base_properties) ? (metadata => $base_properties) : (),
    });

    _plant_attribute(
      $meta,
      $name_data->{ name },
      'DeploymentManager::Resource',
      'CCfnX::Meta::Attribute::Trait::DeploymentManagerResource',
      sub { $r }
    );
  }

  sub output {
    my ($meta, $name, $value) = @_;

    _die_if_already_declared_in_class($meta, $name);

    my $r = DeploymentManager::Output->from_hashref({
      name => $name,
      value => $value,
    });

    _plant_attribute(
      $meta,
      $name,
      'DeploymentManager::Output',
      'CCfnX::Meta::Attribute::Trait::DeploymentManagerOutput',
      sub { $r }
    );
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
package CCfnX::Meta::Attribute::Trait::DeploymentManagerOutput {
  use Moose::Role;
}
package CCfnX::Meta::Attribute::Trait::DeploymentManagerParameter {
  use Moose::Role;
}
1;
