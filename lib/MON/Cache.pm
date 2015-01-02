package MON::Cache;

use strict;
use warnings;
use v5.10;
use autodie;

use Data::Dumper;

use MON::Display;
use MON::Config;
use MON::Utils;

our @ISA = ('MON::Display');

sub new {
  my ( $class, %opts ) = @_;

  my $self = bless \%opts, $class;

  $self->init();

  return $self;
}

sub init {
  my ($self) = @_;

  $self->clear();

  return undef;
}

sub clear {
  my ($self) = @_;

  $self->{cache} = {};

  return undef;
}

sub magic {
  my ( $self, $key, $sub ) = @_;

  my $cache = $self->{cache};

  if ( exists $cache->{$key} ) {
    $self->verbose("Delivering '$key' from cache");
    return $cache->{$key};
  }

  return $cache->{$key} = $sub->();
}

1;
