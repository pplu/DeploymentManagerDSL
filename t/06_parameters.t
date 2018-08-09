#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;

package Test1 {
  use DeploymentManagerDSL;

  parameter p1 => 'string', {
    default => 123,
  };

  parameter p2 => 'string', {
    required => 1,
    in_template => 1,
  };

  parameter i1 => 'integer';

  parameter b1 => 'boolean';

  parameter n1 => 'number';

  resource r1 => 'type1', {
    prop1 => 'r1prop1value',
  };
}

my $t = Test1->new;
my $params = $t->params_class;

{
  ok($params->does('MooseX::Getopt'));
  can_ok($params, 'p1');
  can_ok($params, 'p2');

  ok(
    not($params->meta->get_attribute('p1')->does('CCfnX::Meta::Attribute::Trait::DeploymentManagerParameter')),
    'p1 isn\'t marked for inclusion in the template'
  );

  ok(
    $params->meta->get_attribute('p2')->does('CCfnX::Meta::Attribute::Trait::DeploymentManagerParameter'),
    'p2 is marked for inclusion in the template'
  );

  throws_ok(sub {
    # skip a required parameter
    $params->new(p1 => 'value');
  }, 'Moose::Exception::AttributeIsRequired');

  lives_ok(sub {
    # normal consruction (specify all required parametersm with no optional ones)
    $params->new(p2 => 'value');
  });
}
{
  my $param_obj = $params->new(p1 => 'value1', p2 => 'value2');
  cmp_ok($param_obj->p1, 'eq', 'value1');
  cmp_ok($param_obj->p2, 'eq', 'value2');
}

{
  throws_ok(sub {
    $params->new(i1 => 'illegalstringvalue');
  }, 'Moose::Exception::ValidationFailedForTypeConstraint');
}

{
  throws_ok(sub {
    $params->new(i1 => 3.1415);
  }, 'Moose::Exception::ValidationFailedForTypeConstraint');
}

{
  throws_ok(sub {
    $params->new(n1 => 'illegalstringvalue');
  }, 'Moose::Exception::ValidationFailedForTypeConstraint');
}

{
  throws_ok(sub {
    $params->new(b1 => 'illegalstringvalue');
  }, 'Moose::Exception::ValidationFailedForTypeConstraint');
}

done_testing;
