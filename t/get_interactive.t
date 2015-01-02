#!/usr/bin/perl

use strict;
use warnings;
use v5.10;

use JSON;
use Test::More;

chdir '..';
my $json;

$json = decode_json `./mon --nocolor insert host set use = generic-host and  name = footest.server.lan and host_name = footest.server.lan and address = 127.0.0.1`;
cmp_ok($json->{message}, 'eq', '1 changes successfully commited', 'Testing insert');

$json = decode_json `./mon --nocolor get host where name like footest.server.lan`;
cmp_ok($json->[0]{address}, 'eq', '127.0.0.1', 'Testing get');

$json = decode_json `./mon --nocolor get host`;
cmp_ok(scalar @$json, '>', '1', 'Testing get');

$json = decode_json `./mon --nocolor delete host where name like footest.server.lan`;
cmp_ok($json->{message}, 'eq', '1 changes successfully commited', 'Testing delete');

done_testing();
