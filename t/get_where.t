#!/usr/bin/perl

use strict;
use warnings;
use v5.10;

use JSON;
use Test::More;

chdir '..';
my $json;

for my $num (1..10) {
  $json = decode_json `./mon --nocolor insert host set use = generic-host and  name = footest${num}.server.lan and host_name = footest${num}.server.lan and address = 127.0.0.${num}`;
  cmp_ok($json->{message}, 'eq', '1 changes successfully commited', "Testing insert $num");
}

$json = decode_json `./mon --nocolor get host where name like footest1.server.lan`;
cmp_ok($json->[0]{address}, 'eq', '127.0.0.1', 'Testing get like');

$json = decode_json `./mon --nocolor get host where name matches footest1.server.lan`;
cmp_ok($json->[0]{address}, 'eq', '127.0.0.1', 'Testing get matches');

$json = decode_json `./mon --nocolor get host where name nmatches footest1.server.lan and name like footest`;
cmp_ok(scalar @$json, '==', '9', 'Testing get nmatches');

$json = decode_json `./mon --nocolor get host where name eq footest2.server.lan`;
cmp_ok($json->[0]{address}, 'eq', '127.0.0.2', 'Testing get eq');

$json = decode_json `./mon --nocolor get host where name ne footest1.server.lan and name like footest`;
cmp_ok(scalar @$json, '==', '9', 'Testing get ne');

$json = decode_json `./mon --nocolor get host where name lt 2 and name like footest`;
cmp_ok(scalar @$json, '==', '1', 'Testing get lt');

$json = decode_json `./mon --nocolor get host where name le 2 and name like footest`;
cmp_ok(scalar @$json, '==', '2', 'Testing get le');

$json = decode_json `./mon --nocolor get host where name gt 2 and name like footest`;
cmp_ok(scalar @$json, '==', '8', 'Testing get gt');

$json = decode_json `./mon --nocolor get host where name ge 2 and name like footest`;
cmp_ok(scalar @$json, '==', '9', 'Testing get ge');

$json = decode_json `./mon --nocolor delete host where name like footest and host_name like server.lan`;
cmp_ok($json->{message}, 'eq', '10 changes successfully commited', 'Testing delete');

done_testing();
