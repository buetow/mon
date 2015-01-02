#!/usr/bin/perl

use strict;
use warnings;
use v5.10;

use JSON;
use Test::More;

chdir '..';
my $json;
my $res;

$json = decode_json `./mon --nocolor insert host set use = generic-host and  name = footest.server.lan and host_name = footest.server.lan and address = 127.0.0.1`;
cmp_ok($json->{message}, 'eq', '1 changes successfully commited', 'Testing insert');

$res = `./mon --nocolor getfmt 'Foo:\$host_name' host where name like footest.server.lan`;
like($res, qr/Foo:footest.server.lan/, 'Testing getfmt');

$json = decode_json `./mon --nocolor delete host where name like footest.server.lan`;
cmp_ok($json->{message}, 'eq', '1 changes successfully commited', 'Testing delete');

done_testing();
