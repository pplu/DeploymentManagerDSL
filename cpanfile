requires 'Moose';
requires 'MooseX::Getopt';
requires 'Path::Tiny';
requires 'boolean';

on 'test' => sub {
  requires 'Test::More';
  requires 'Test::Exception';
};
