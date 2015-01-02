#!/usr/bin/perl

use strict;
use warnings;
use v5.10;

use JSON;
use Test::More;

chdir '..';
my $json;

$json = decode_json `./mon --nocolor insert host set use = generic-host and name = footest01.server.lan and host_name = footest01.server.lan and address = 127.0.0.1`;
cmp_ok($json->{message}, 'eq', '1 changes successfully commited', 'Testing insert');

$json = decode_json `./mon --nocolor insert host set use = generic-host and name = footest02.server.lan and host_name = footest02.server.lan and address = 127.0.0.1`;
cmp_ok($json->{message}, 'eq', '1 changes successfully commited', 'Testing insert');

$json = decode_json `./mon --nocolor delete host where name like 'footest01.server.lan'`;
cmp_ok($json->{message}, 'eq', '1 changes successfully commited', 'Testing delete');

$json = decode_json `./mon --nocolor delete host where name like 'footest02.server.lan'`;
cmp_ok($json->{message}, 'eq', '1 changes successfully commited', 'Testing delete');

$json = decode_json `./mon --nocolor get  host where name matches 'footest..\\.server\\.lan'`;
cmp_ok(scalar @$json, 'eq', 0, 'Testing get after delete');

done_testing();
