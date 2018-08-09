requires 'Moose';
requires 'MooseX::Getopt';
requires 'boolean';

on 'test' => sub {
  requires 'Test::More';
  requires 'Test::Exception';
};
