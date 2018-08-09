#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;

package Test1 {
  use DeploymentManagerDSL;

  resource r1 => 'type1', {
    prop1 => 'r1prop1value',
  };

  output o1 => '$(ref.kms-key.primaryVersion)';
  output o2 => '$(ref.function-call.result)';
}

{
  my $t = Test1->new;

  cmp_ok($t->as_hashref->{ outputs }->[ 0 ]->{ name }, 'eq', 'o1');
  cmp_ok($t->as_hashref->{ outputs }->[ 0 ]->{ value }, 'eq', '$(ref.kms-key.primaryVersion)');
  cmp_ok($t->as_hashref->{ outputs }->[ 1 ]->{ name }, 'eq', 'o2');
  cmp_ok($t->as_hashref->{ outputs }->[ 1 ]->{ value }, 'eq', '$(ref.function-call.result)');
}

done_testing;
