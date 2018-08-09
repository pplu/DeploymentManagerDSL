requires 'Moose';
requires 'MooseX::Getopt';

on 'test' => sub {
  requires 'Test::More';
  requires 'Test::Exception';
};
