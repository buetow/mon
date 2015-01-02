#!/usr/bin/perl

use strict;
use warnings;
use v5.10;

use File::Temp qw(tempfile);
use JSON;
use Test::More;

my $json1 = <<JSON1;
[
   {
      "address" : "127.0.0.1",
      "host_name" : "footest.server.lan",
      "hostgroups" : "",
      "name" : "footest.server.lan",
      "register" : "0"
   }
]
JSON1

my $json2 = <<JSON2;
[
   {
      "address" : "127.0.0.2",
      "name" : "footest.server.lan"
   }
]
JSON2

chdir '..';

my ($jsonfh1, $jsonfile1) = tempfile( undef, SUFFIX => '.json' );
print $jsonfh1 $json1;

my ($jsonfh2, $jsonfile2) = tempfile( undef, SUFFIX => '.json' );
print $jsonfh2 $json2;

my $json;

$json = decode_json `./mon --nocolor post host < $jsonfile1`;
cmp_ok($json->{message}, 'eq', '1 changes successfully commited', 'Testing post');

$json = decode_json `./mon --nocolor get host where name like footest.server.lan`;
cmp_ok($json->[0]{address}, 'eq', '127.0.0.1', 'Testing get');

$json = decode_json `./mon --nocolor put host < $jsonfile2`;
cmp_ok($json->{message}, 'eq', '1 changes successfully commited', 'Testing put');

$json = decode_json `./mon --nocolor get host where name like footest.server.lan`;
cmp_ok($json->[0]{address}, 'eq', '127.0.0.2', 'Testing get after a put');

$json = decode_json `./mon --nocolor delete host where name like footest.server.lan`;
cmp_ok($json->{message}, 'eq', '1 changes successfully commited', 'Testing delete');

unlink $jsonfile1;
unlink $jsonfile2;

done_testing();
