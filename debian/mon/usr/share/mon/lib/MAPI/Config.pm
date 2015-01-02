package MON::Config;

use strict;
use warnings;
use v5.10;
use autodie;

use IO::File;
use Data::Dumper;

use MON::Display;
use MON::Utils;

#use MON::Options;

use MIME::Base64 qw( decode_base64 );

our @ISA = ('MON::Display');

sub new {
  my ( $class, %opts ) = @_;

  my $self = bless \%opts, $class;
  my $options = $self->{options};

  $options->store_first($self);

  $self->SUPER::init(%opts);

  for ( @{ $options->{unknown} } ) {
    $self->error("Unknown option: $_");
  }

  if ( $self->{'config'} ne '' ) {
    $self->read_config( $self->{'config'} );

  }
  elsif ( exists $ENV{MON_CONFIG} ) {
    $self->read_config( $ENV{MON_CONFIG} );

  }
  else {
    $self->read_config('/etc/mon.conf');
    $self->read_config($_) for sort glob("/etc/mon.d/*.conf");

    $self->read_config("$ENV{HOME}/.mon.conf");
    $self->read_config($_) for sort glob("$ENV{HOME}/.mon.d/*.conf");
  }

  $options->store_after($self);

  unless ( exists $self->{config_was_read} ) {
    $self->verbose("No config file found, but this might be OK");
  }

  $self->_set_defaults();

  return $self;
}

sub _set_defaults {
  my ($self) = @_;

  my $set_default = sub {
    my ( $key, $val ) = @_;

    unless ( exists $self->{$key} ) {
      $self->{$key} = $val;
      $self->verbose(
        "Since $key is not specified setting its default value to $val");
    }
  };

  $set_default->( 'backups.dir'           => "$ENV{HOME}/.mon" );
  $set_default->( 'backups.disable'       => 1 );
  $set_default->( 'backups.keep.days'     => 7 );
  $set_default->( 'restlos.api.port'      => '443' );
  $set_default->( 'restlos.api.protocol'  => 'https' );
  $set_default->( 'restlos.auth.realm'    => 'Login Required' );
  $set_default->( 'restlos.auth.username' => $ENV{USER} );
}

sub read_config {
  my ( $self, $config_file ) = @_;

  return undef if not defined $config_file or not -f $config_file;

  my $fh = IO::File->new( $config_file, 'r' );
  $self->error("Could not open file $config_file") unless defined $fh;

  $self->verbose("Reading config $config_file");

  while ( my $line = $fh->getline() ) {
    next if $line =~ /^#/;

    # Ignore comments
    $line =~ s/(.*);.*/$1/;

    # Parse only matching lines
    if ( $line =~ /^(.*):(.*)/ ) {
      my ( $key, $val ) = ( lc trim $1, trim $2);
      $self->verbose("Reading conf value $key");

      # Handle ~
      $val =~ s/~/$ENV{HOME}/g;
      $self->set( $key, $val );
    }
  }

  $fh->close();
  $self->{config_was_read} = 1;

  return undef;
}

sub get {
  my ( $self, $key ) = @_;
  $key = lc $key;

  $self->{$key} //= do {
    my $key = uc $key;
    $key =~ s/\./_/g;

    exists $ENV{$key} ? $ENV{$key} : undef;
  };

  if ( not exists $self->{$key}
    or not defined $self->{$key}
    or $self->{$key} eq '' )
  {
    $self->error("$key not configured");
  }

  return $self->{$key};
}

sub get_maybe_encoded {
  my ( $self, $key ) = @_;

  return $self->get($key) if exists $self->{$key};

  $self->error("$key or $key.enc not configured")
    unless exists $self->{"$key.enc"};

  my $enc = $self->get("$key.enc");

  return decode_base64($enc);
}

sub bool {
  my ( $self, $key ) = @_;

  my $val = $self->get($key);

  return $val != 0;
}

sub array {
  my ( $self, $key ) = @_;

  my $val = $self->get($key);

  return map { trim $_ } split ',', $val;
}

sub set {
  my ( $self, $key, $val ) = @_;
  $key = lc $key;

  $self->verbose("$key already configured, overwriting it with its new value")
    if exists $self->{$key};

  return $self->{$key} = $val;
}

1;
