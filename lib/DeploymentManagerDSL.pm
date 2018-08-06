package DeploymentManagerDSL::Object {
  use Moose;


  sub stub { 42 }
}
package DeploymentManagerDSL {
  use Moose ();
  use Moose::Exporter;
  use Moose::Util::MetaRole ();

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

  }

  sub output {

  }
}
1;
