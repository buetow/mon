package MON::Syslogger;

use strict;
use warnings;
use v5.10;
use autodie;

use Unix::Syslog qw(:macros :subs);
use Scalar::Util qw(looks_like_number);

sub new {
  my ( $class, %opts ) = @_;

  my $self = bless \%opts, $class;

  $self->init();

  return $self;
}

sub init {
  my ($self) = @_;

  my $options = $self->{options};
  $options->store($self);

  if ( exists $self->{syslog} && $self->{syslog} ne '0' ) {
    $self->{enable} = 1;

  }
  elsif ( exists $ENV{MON_SYSLOG} && $ENV{MON_SYSLOG} ne '0' ) {
    $self->{enable} = 1;

  }
  else {
    $self->{enable} = 0;
  }

  return undef;
}

sub logg {
  my ( $self, $level, @msgs ) = @_;

  return undef unless $self->{enable};

  openlog $0, LOG_PID, LOG_LOCAL0;

  s/\n/ /g for @msgs;

  given ($level) {
    when ('debug') {
      syslog LOG_DEBUG, $_ for @msgs;
    }
    when ('warning') {
      syslog LOG_WARNING, $_ for @msgs;
    }
    when ('error') {
      syslog LOG_ERR, $_ for @msgs;
    }
    when ('notice') {
      syslog LOG_NOTICE, $_ for @msgs;
    }
    when ('info') {
      syslog LOG_INFO, $_ for @msgs;
    }
    default {
      $self->logg( 'info', @msgs )
    }
  }

  closelog

    return undef;
}

1;
