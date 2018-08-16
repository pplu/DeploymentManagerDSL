#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

package Test1 {
  use DeploymentManagerDSL;

  resource 'r1' => 'type1', {};
  resource RawName('r2') => 'type2', {};
  resource { name => 'r3', template => Env('deployment') . '-%s' } => 'type3', {};

  output o1 => Ref('r1', 'selfLink');
  output o2 => Ref('r2', 'selfLink');
  output o3 => Ref('r3', 'selfLink');
}

{
  my $t = Test1->new;

  cmp_ok($t->r1->name, 'eq', "r1-{{ env[\"deployment\"] }}");
  cmp_ok($t->r2->name, 'eq', "r2");
  cmp_ok($t->r3->name, 'eq', "{{ env[\"deployment\"] }}-r3");
}

done_testing;
