#!/usr/bin/perl

use strict;
use warnings;
use v5.10;

use JSON;
use Test::More;

chdir '..';
my $json;

$json = decode_json `./mon --nocolor insert host set use = generic-host and  name = footest01.server.lan and host_name = footest01.server.lan and address = 127.0.0.1 and _FOO = foo and _BAR = bar`;
cmp_ok($json->{message}, 'eq', '1 changes successfully commited', 'Testing insert');

$json = decode_json `./mon --nocolor insert host set use = generic-host and  name = footest02.server.lan and host_name = footest02.server.lan and address = 127.0.0.1 and _FOO = foo and _BAR = bar`;
cmp_ok($json->{message}, 'eq', '1 changes successfully commited', 'Testing insert');

$json = decode_json `./mon --nocolor -m update host set _BEER = '\@_FOO' and _PIZZA = '\$_BAR' and _COLA = '\${_FOO}foo\@{_BAR}bar' where name like footest and host_name like server.lan`;
cmp_ok($json->{message}, 'eq', '2 changes successfully commited', 'Testing expression in update ... set');

$json = decode_json `./mon --nocolor -m get host where name like footest and host_name like server.lan`;
cmp_ok($json->[0]{_BEER}, 'eq', 'foo', 'Testing get after a update');
cmp_ok($json->[1]{_BEER}, 'eq', 'foo', 'Testing get after a update');
cmp_ok($json->[0]{_PIZZA}, 'eq', 'bar', 'Testing get after a update');
cmp_ok($json->[1]{_PIZZA}, 'eq', 'bar', 'Testing get after a update');
cmp_ok($json->[0]{_COLA}, 'eq', 'foofoobarbar', 'Testing get after a update');
cmp_ok($json->[1]{_COLA}, 'eq', 'foofoobarbar', 'Testing get after a update');

$json = decode_json `./mon --nocolor delete host where name like footest01.server.lan`;
cmp_ok($json->{message}, 'eq', '1 changes successfully commited', 'Testing put');

$json = decode_json `./mon --nocolor delete host where name like footest02.server.lan`;
cmp_ok($json->{message}, 'eq', '1 changes successfully commited', 'Testing put');

done_testing();

