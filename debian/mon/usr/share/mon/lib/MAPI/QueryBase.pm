package MON::QueryBase;

use strict;
use warnings;
use v5.10;

use File::Temp qw/:mktemp/;
use Data::Dumper;
use Digest::SHA;

use MON::Display;
use MON::Config;
use MON::Utils;

our @ISA = ('MON::Display');

sub check_has {
  my ( $self, $key, $in ) = @_;

  if ( ref $in eq 'HASH' && exists $in->{$key} ) {
    return 1;

  }
  else {
    for (@$in) {
      return 1 if $_ eq $key;
    }
  }

  my @possible = sort ( ref $in eq 'HASH' ? keys %$in : @$in );
  $self->error("'$key' not expected here. Possible: @possible");
}

sub edit_path_file_send {
  my ( $self, $path, $filename ) = @_;

  my $api = $self->{api};

  open my $fh, $filename or die "$filename: $!";
  my @data = <$fh>;
  close $fh;

  $self->info("Saving data to API into $path from file $filename");
  $self->out_json(
    $api->send_path_json( $path, join( '', @data ), undef, 'PUT' ) );

  return undef;
}

sub get_sha_of_file {
  my ( $self, $filename ) = @_;

  my $sha = Digest::SHA->new();
  open my $sha_fh, $filename or die "$!\n";
  $sha->addfile($sha_fh);
  $sha = $sha->b64digest();
  close $sha_fh;

  return $sha;
}

sub edit_path_file {
  my ( $self, $path, $filename ) = @_;

  my $config = $self->{config};
  my $api    = $self->{api};

  if ( $config->{'dry'} ) {
    $self->verbose("Dry mode, don't modify anything via API.");
    return undef;
  }

  my $editor = $ENV{EDITOR} // 'vim';

  my $sha_before = $self->get_sha_of_file($filename);
  $self->verbose("Checksum of $filename before edit: $sha_before");

  for ( ; ; ) {
    system("$editor $filename");
    my $sha_after = $self->get_sha_of_file($filename);
    $self->verbose("Checksum of $filename after edit:  $sha_after");

    if ( $sha_before eq $sha_after ) {
      $self->info(
        "Dude, no changes were made. I am not sending data back to the API!");
      last;
    }

    $self->edit_path_file_send( $path, $filename );
    if ( $api->{has_error} ) {
      $self->info('An error has occured, press any key to re-edit');
      <STDIN>;
    }
    else {
      last;
    }
  }

  for ( glob("/tmp/mon*.json") ) {
    $self->verbose("Cleaning up tempfile $_");
    unlink $_;
  }

  return undef;
}

sub edit_path_data {
  my ( $self, $path, $data ) = @_;

  my $config = $self->{config};
  my $api    = $self->{api};
  my $json   = $api->{json};

  my ( $fh, $filename ) = mkstemps( "/tmp/monXXXXXX", '.json' );

  # Sort the json
  my $vals = $json->decode($data);
  print $fh $json->encode_canonical($vals);
  close $fh;

  $self->edit_path_file( $path, $filename );

  return undef;
}

sub view_data {
  my ( $self, $path, $data ) = @_;

  my $config = $self->{config};
  my $api    = $self->{api};
  my $json   = $api->{json};

  if ( $config->{'dry'} ) {
    $self->verbose("Dry mode, don't modify anything via API.");
    return undef;
  }
  my ( $fh, $filename ) = mkstemps( "/tmp/monXXXXXX", '.json' );

  # Sort the json
  my $vals = $json->decode($data);
  print $fh $json->encode_canonical($vals);
  close $fh;

  my $editor = $ENV{PAGER} // 'view';
  system("$editor $filename");

  unlink $filename;
  return undef;
}

sub insert_data {
  my ( $self, $path, $set ) = @_;

  my $config = $self->{config};
  my $api    = $self->{api};

  if ( $config->{'dry'} ) {
    $self->verbose("Dry mode, don't modify anything via API.");
    return undef;
  }

  return $api->send_path_json( $path, $api->{json}->encode($set) );
}

sub send_data {
  my ( $self, $path, $method, $fromfile ) = @_;

  my $config = $self->{config};
  my $api    = $self->{api};
  my @send_data;

  if ( defined $config->{infile} ) {
    my $infile = $config->{infile};

    # Slurp it, it's not gonna be >1mb anyway
    @send_data = <$infile>;
  }
  elsif ( defined $fromfile ) {
    open my $fh, $fromfile or do {
      $self->error("Can not open file $fromfile: $!");
      return undef;
    };

    # Slurp it, it's not gonna be >1mb anyway
    @send_data = <$fh>;
    close $fh;
  }
  else {

    # Slurp it, it's not gonna be >1mb anyway
    @send_data = <STDIN>;
  }

  unless (@send_data) {
    $self->error(
"No post data found. Use 'from datafile' or pipes to set post or put data."
    );
    return undef;
  }

  my $send_data = join '', @send_data;

  my $json = $api->{json}->decode($send_data);

  if ( ref $json eq 'ARRAY' && @$json && ref $json->[0] ne 'HASH' ) {
    $self->verbose('Transforming array style JSON into an hash style one');
    my %json = @$json;
    $json = \%json;
  }

  $self->out_json(
    $api->send_path_json( $path, $api->{json}->encode($json), undef, $method )
  );

  return undef;
}

sub verify {
  my ($self) = @_;
  my $api = $self->{api};

  $self->out_json( $api->post_verify_json() );
}

sub restart {
  my ($self) = @_;
  my $api = $self->{api};

  $self->out_json( $api->post_restart_json() );
}

1;
