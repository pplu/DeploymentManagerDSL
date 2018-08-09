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

  cmp_ok($t->type, 'eq', 'Test1');
  cmp_ok($t->num_of_properties, '==', 0);
  isa_ok($t->r1, 'DeploymentManager::Resource');
  cmp_ok($t->r1->as_hashref->{ properties }{ prop1 }, 'eq', 'r1prop1value', 'Can access properties with accessors');
  isa_ok($t->r2, 'DeploymentManager::Resource');
  cmp_ok($t->r2->metadata->dependsOn->[0], 'eq', 'r1', 'Can transmit metadata via DSL');
  cmp_ok($t->r2->as_hashref->{ properties }{ prop1 }, 'eq', 'r2prop1value', 'Can access properties with accessors');
}

done_testing;
