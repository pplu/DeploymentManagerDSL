requires 'Moose';
requires 'MooseX::Getopt';
requires 'Path::Tiny';
requires 'boolean';
requires 'Ref::Util';

on 'test' => sub {
  requires 'Test::More';
  requires 'Test::Exception';
};
