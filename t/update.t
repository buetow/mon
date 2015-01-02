#!/usr/bin/perl

use strict;
use warnings;
use v5.10;

use JSON;
use Test::More;

chdir '..';
my $json;

$json = decode_json `./mon --nocolor insert host set use = generic-host and  name = footest.server.lan and host_name = footest.server.lan and address = 127.0.0.1 and _FOO = foo and _BAR = bar`;
cmp_ok($json->{message}, 'eq', '1 changes successfully commited', 'Testing insert');

$json = decode_json `./mon --nocolor update host delete _FOO where name like footest.server.lan`;
cmp_ok($json->{message}, 'eq', '1 changes successfully commited', 'Testing update ... delete');

$json = decode_json `./mon --nocolor -m get host where name like footest.server.lan`;
cmp_ok(exists $json->[0]{_FOO}, '==', 0, 'Testing get after a update');
cmp_ok($json->[0]{_BAR}, 'eq', 'bar', 'Testing get after a update');

$json = decode_json `./mon --nocolor update host set _FOO = fuu where name like footest.server.lan`;
cmp_ok($json->{message}, 'eq', '1 changes successfully commited', 'Testing update ... set');

$json = decode_json `./mon --nocolor -m get host where name like footest.server.lan`;
cmp_ok($json->[0]{_FOO}, 'eq', 'fuu', 'Testing get after a update');

$json = decode_json `./mon --nocolor update host set _ONE = one and _TWO = two where name like footest.server.lan`;
cmp_ok($json->{message}, 'eq', '1 changes successfully commited', 'Testing update ... set with multiple objects');

$json = decode_json `./mon --nocolor -m get host where name like footest.server.lan`;
cmp_ok($json->[0]{_FOO}, 'eq', 'fuu', 'Testing get after a update');
cmp_ok($json->[0]{_BAR}, 'eq', 'bar', 'Testing get after a update');
cmp_ok($json->[0]{_ONE}, 'eq', 'one', 'Testing get after a update');
cmp_ok($json->[0]{_TWO}, 'eq', 'two', 'Testing get after a update');

$json = decode_json `./mon --nocolor update host delete _FOO and _BAR where name like footest.server.lan`;
cmp_ok($json->{message}, 'eq', '1 changes successfully commited', 'Testing update ... delete with multiple arguments');

$json = decode_json `./mon --nocolor -m get host where name like footest.server.lan`;
cmp_ok(exists $json->[0]{_FOO}, '==', 0, 'Testing get after a update');
cmp_ok(exists $json->[0]{_BAR}, '==', 0, 'Testing get after a update');

$json = decode_json `./mon --nocolor delete host where name like footest.server.lan`;
cmp_ok($json->{message}, 'eq', '1 changes successfully commited', 'Testing put');

done_testing();

