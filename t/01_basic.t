#!/usr/bin/env perl

use Test::More;

package MyInfra {
  use DeploymentManagerDSL;

  resource x => 'type', {

  };
}

{
  my $i = MyInfra->new;
  cmp_ok($i->stub, '==', 42);
}

done_testing;
