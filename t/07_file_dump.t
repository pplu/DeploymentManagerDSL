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

my $expected_yaml = <<YAML;
---
resources:
- name: r1
  properties:
    prop1: r1prop1value
  type: type1
- metadata:
    dependsOn:
    - r1
  name: r2
  properties:
    prop1: r2prop1value
  type: type2
YAML

{
  my $t = Test1->new;

  my $file_content;
  {
    local $/=undef;
    open (my $file, '<', $t->file);
    $file_content = <$file>;
    close $file;
  }
  cmp_ok($t->jinja_content, 'eq', $expected_yaml);
  like($t->file, qr|^/tmp|);
  cmp_ok($file_content, 'eq', $t->jinja_content, 'The file was dumped into the file');
}

done_testing;
