package MON::JSON;

use strict;
use warnings;
use v5.10;
use autodie;

use JSON;

use MON::Display;
use MON::Utils;

our @ISA = ('MON::Display');

our $JSON_XS = JSON::XS->new();

sub new {
  my ( $class, %opts ) = @_;

  my $self = bless \%opts, $class;

  $self->init();

  return $self;
}

sub init {
  my ($self) = @_;

  return undef;
}

sub decode {
  my ( $self, $json ) = @_;

  return $JSON_XS->allow_nonref()->decode($json);
}

sub encode {
  my ( $self, $vals ) = @_;

  return $JSON_XS->pretty()->encode($vals);
}

sub encode_canonical {
  my ( $self, $vals ) = @_;

  return $JSON_XS->canonical()->pretty()->encode($vals);
}

1;
