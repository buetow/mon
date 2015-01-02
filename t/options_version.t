#!/usr/bin/perl

# Testing --version, -V

use strict;
use warnings;
use v5.10;

use JSON;
use Test::More;

chdir '..';
my $json;
my $ret;

my $version = `cat .version`;
chomp $version;

$ret = `./mon --version`;
chomp $ret;
cmp_ok($ret, 'eq', $version, 'Testing version');

$ret = `./mon -V`;
chomp $ret;
cmp_ok($ret, 'eq', $version, 'Testing version');


done_testing();
