#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

package Test1 {
  use DeploymentManagerDSL;

  resource r1 => 'type1', {
    prop1 => 'r1prop1value',
  };

  resource r2 => 'type2', {
    prop1 => 'r2prop1value',
  }, {
    dependsOn => [ 'r1' ],
  };
}

{
  my $t = Test1->new;

  is_deeply(
    $t->as_hashref,
    {
      resources => [
        { name => 'r1', type => 'type1', properties => { prop1 => 'r1prop1value' } },
        { name => 'r2', type => 'type2', properties => { prop1 => 'r2prop1value' }, metadata => { dependsOn => [ 'r1' ] } },
      ],
    }
  );
}

done_testing;
