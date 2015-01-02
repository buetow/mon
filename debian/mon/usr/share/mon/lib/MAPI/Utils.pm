package MON::Utils;

use strict;
use warnings;
use v5.10;
use autodie;

use Data::Dumper;
use Exporter;

use base 'Exporter';

our @EXPORT = qw (
  d
  dumper
  get_version
  isin
  newline
  notnull
  null
  remove_spaces
  say
  sum
  trim
);

sub say (@) { print "$_\n" for @_; return undef }
sub newline () { say ''; return undef }
sub sum (@) { my $sum = 0; $sum += $_ for @_; return $sum }
sub null ($)    { defined $_[0] ? $_[0] : 0 }
sub notnull ($) { $_[0] != 0    ? $_[0] : 1 }
sub dumper (@)  { die Dumper @_ }
sub d (@)       { dumper @_ }

sub isin ($@) {
  my ( $elem, @list ) = @_;

  for (@list) {
    return 1 if $_ eq $elem;
  }

  return 0;
}

sub trim ($) {
  my $trimit = shift;

  $trimit =~ s/^[\s\t]+//;
  $trimit =~ s/[\s\t]+$//;

  return $trimit;
}

sub remove_spaces ($) {
  my $str = shift;

  $str =~ s/[\s\t]//g;

  return $str;
}

sub get_version () {
  my $versionfile = do {
    if ( -f '.version' ) {
      '.version';
    }
    else {
      '/usr/share/mon/version';
    }
  };

  open my $fh, $versionfile or error("$!: $versionfile");
  my $version = <$fh>;
  close $fh;

  chomp $version;
  return $version;
}

1;
