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

  output o1 => '$(ref.r2.HisProp)';
}

{
  my $t = Test1->new(
    property_values => {},
  );

  my $config_file_content;
  {
    local $/=undef;
    open (my $file, '<', $t->config_file_name);
    $config_file_content = <$file>;
    close $file;
  }
  like($t->config_file_name, qr|^/tmp|);
  like($t->config_file_name, qr|\.yaml$|);
  cmp_ok($config_file_content, 'eq', $t->config_content, 'The file was dumped into the file');

  my $jinja_file_content;
  {
    local $/=undef;
    open (my $file, '<', $t->jinja_full_path);
    $jinja_file_content = <$file>;
    close $file;
  }
  like($t->jinja_full_path, qr|^/tmp|);
  like($t->jinja_path_relative, qr|^\w+\.jinja|);
  cmp_ok($jinja_file_content, 'eq', $t->jinja_content, 'The file was dumped into the file');
}

done_testing;
