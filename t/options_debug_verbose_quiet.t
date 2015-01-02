#!/usr/bin/perl

# Testing --debug, -D, --verbose, -v and --quiet, -q

use strict;
use warnings;
use v5.10;

use JSON;
use Test::More;

chdir '..';
my $json;
my $ret;

$ret = `./mon -q insert host set use = generic-host and  name = footest.server.lan and host_name = footest.server.lan and address = 127.0.0.1`;
cmp_ok($ret, 'eq', '', 'Testing quiet insert');

$json = decode_json `./mon --nocolor get host where name like footest.server.lan`;
cmp_ok($json->[0]{address}, 'eq', '127.0.0.1', 'Testing get');

$json = decode_json `./mon --nocolor get host`;
cmp_ok(scalar @$json, '>', '1', 'Testing get');

$ret = `./mon -D --nocolor get host >/dev/null 2>/tmp/montest.tmp;cat /tmp/montest.tmp`;
like($ret, qr/MON::Filter/, 'Testing debug get');

$ret = `./mon --debug --nocolor get host >/dev/null 2>/tmp/montest.tmp;cat /tmp/montest.tmp`;
like($ret, qr/MON::Filter/, 'Testing debug get');

$ret = `./mon -v --nocolor get host >/dev/null 2>/tmp/montest.tmp;cat /tmp/montest.tmp`;
like($ret, qr/Reading config/, 'Testing verbose get');

$ret = `./mon --verbose --nocolor get host >/dev/null 2>/tmp/montest.tmp;cat /tmp/montest.tmp`;
like($ret, qr/Reading config/, 'Testing verbose get');

$ret = `./mon --quiet --nocolor delete host where name like footest.server.lan`;
cmp_ok($ret, 'eq', '', 'Testing quiet delete');

$json = decode_json `./mon --nocolor get host where name like footest.server.lan`;
cmp_ok(scalar @$json, '<', '1', 'Testing get');

done_testing();
