package MON::RESTlos;

use strict;
use warnings;
use v5.10;
use autodie;

use POSIX 'strftime';
use IO::File;
use IO::Dir;
use HTTP::Headers;
use LWP::UserAgent;
use Data::Dumper;

use MON::Cache;
use MON::Config;
use MON::Display;
use MON::Filter;
use MON::Utils;
use MON::JSON;

our @ISA = ('MON::Display');

sub new {
  my ( $class, %opts ) = @_;

  my $self = bless \%opts, $class;

  $self->init();

  return $self;
}

sub init {
  my ($self) = @_;

  my $config = $self->{config};

  my $host     = $config->get('restlos.api.host');
  my $port     = $config->get('restlos.api.port');
  my $protocol = $config->get('restlos.api.protocol');

  $self->{url_base}  = "$protocol://$host:$port/";
  $self->{cache}     = MON::Cache->new( config => $config );
  $self->{filter}    = MON::Filter->new( config => $config );
  $self->{json}      = MON::JSON->new( config => $config );
  $self->{has_error} = 0;
  $self->{had_error} = 0;

  my $url  = $self->{url_base};
  my $vals = $self->{json}->decode( $self->fetch_json($url) );

  my $all = $self->{all} = $vals->{endpoints};
  my @top;
  push @top, $_ for sort keys %$all;
  $self->{all_possible_paths} = \@top;

  return undef;
}

# Easy getter methods
sub get_possible_paths {
  my ($self) = @_;

  return $self->{all_possible_paths};
}

sub get_path_params {
  my ( $self, $path ) = @_;

  return $self->{all}{$path};
}

# Helper methods
sub set_credentials {
  my ( $self, $ua ) = @_;

  my $config = $self->{config};

  my $host     = $config->get('restlos.api.host');
  my $port     = $config->get('restlos.api.port');
  my $protocol = $config->get('restlos.api.protocol');
  my $password = $config->get_maybe_encoded('restlos.auth.password');
  my $realm    = $config->get('restlos.auth.realm');
  my $username = $config->get('restlos.auth.username');

  $ua->credentials( "$host:$port", $realm, $username, $password );

  return undef;
}

sub create_request {
  my ( $self, $method, $url ) = @_;

  my $req = HTTP::Request->new( $method, $url );
  $req->header( 'Accept',       'application/json' );
  $req->header( 'Content-Type', 'application/json' );

  return $req;
}

sub handle_http_error_if {
  my ( $self, $response ) = @_;

  my $config = $self->{config};

  unless ( $response->is_success() ) {

    #$self->out_json( $response->decoded_content() );
    $self->warning( $response->status_line() . ' ==> switching to dry mode' );
    $self->{has_error} = 1;
    $self->{had_error} = 1;
  }
  else {
    $self->{has_error} = 0;
  }

  return undef;
}

# Fetch methods
sub fetch_json {
  my ( $self, $url ) = @_;

  my $config = $self->{config};
  my $cache  = $self->{cache};

  my $response = $cache->magic(
    $url,
    sub {
      $self->verbose("Requesting '$url' via GET");

      my $req = $self->create_request( 'GET', $url );

      my $ua = LWP::UserAgent->new();
      $self->set_credentials($ua);

      my $response = $ua->request($req);
      $self->handle_http_error_if($response);

      return $response;
    }
  );

  return $response->decoded_content();
}

sub fetch_path_json {
  my ( $self, $path, $params ) = @_;

  my $config = $self->{config};
  my $filter = $self->{filter};
  $filter->compute($params);

  my $content =
    $self->fetch_json( $self->{url_base} . $path . $filter->{query_string} );

  return $self->{json}
    ->encode( $filter->filter( $self->{json}->decode($content) ) );
}

# Delete methods
sub delete_json {
  my ( $self, $url ) = @_;

  my $config = $self->{config};
  my $filter = $self->{filter};

  if ( $config->{'dry'} ) {
    $self->verbose("Dry mode, don't modify anything via API.");
    return undef;
  }

  $self->verbose("Requesting '$url' via DELETE");
  my $req = $self->create_request( 'DELETE', $url );

  my $ua = LWP::UserAgent->new();
  $self->set_credentials($ua);

  my $response = $ua->request($req);
  $self->handle_http_error_if($response);

  return $response->decoded_content();
}

sub delete_path_json {
  my ( $self, $path, $params, $no_backup ) = @_;

  my $config = $self->{config};
  my $filter = $self->{filter};
  my $json   = $self->{json};

  if ( $config->{'dry'} ) {
    $self->verbose("Dry mode, don't modify anything via API.");
    return undef;
  }

  $filter->compute($params);
  $self->backup_path_json( $path, $params ) unless defined $no_backup;

  if ( $filter->{num_filters} > 0 ) {
    my $jsonstr = $self->fetch_path_json( $path, $params );
    my $data = $json->decode($jsonstr);
    my @ret;

    for my $obj (@$data) {
      my $url = $self->{url_base} . $path . "?name.eq=$obj->{name}";
      push @ret, $json->decode( $self->delete_json($url) );
    }

    return $json->encode( \@ret );

  }
  else {
    my $url = $self->{url_base} . $path . $filter->{query_string};
    return $self->delete_json($url);
  }
}

# Post methods
sub send_json {
  my ( $self, $url, $send_data, $method ) = @_;

  $method //= 'POST';

  my $config = $self->{config};

  if ( $config->{'dry'} ) {
    $self->verbose("Dry mode, don't modify anything via API.");
    return undef;
  }

  $send_data = '' unless defined $send_data;

  $self->verbose("Using URL $url and $method data:\n$send_data");

  my $req = $self->create_request( $method, $url );
  $req->content($send_data);

  my $ua = LWP::UserAgent->new();
  $self->set_credentials($ua);

  my $response = $ua->request($req);
  $self->handle_http_error_if($response);

  return $response->decoded_content();
}

sub send_path_json {
  my ( $self, $path, $send_data, $no_backup, $method ) = @_;

  # If $method == undef, then $method = 'POST'

  my $config = $self->{config};

  if ( $config->{'dry'} ) {
    $self->verbose("Dry mode, don't modify anything via API.");
    return undef;
  }

  my $url = $self->{url_base} . $path;
  $self->backup_path_json($path) unless defined $no_backup;

  return $self->send_json( $url, $send_data, $method );
}

# Post methods
sub post_verify_json {
  my ($self) = @_;

  my $config = $self->{config};

  if ( $config->{'dry'} ) {
    $self->verbose("Dry mode, don't modify anything via API.");
    return undef;
  }

  $self->info("Verifying configuration.");
  return $self->send_json( $self->{url_base} . 'control?verify' );
}

sub post_restart_json {
  my ($self) = @_;

  my $config = $self->{config};

  if ( $config->{'dry'} ) {
    $self->verbose("Dry mode, don't modify anything via API.");
    return undef;
  }

  $self->info("Restarting monitoring core.");
  return $self->send_json( $self->{url_base} . 'control?restart=true' );
}

# Allow variables like this:
#  m -v update host set __FOO = '$host_name $name' where host_name like paul
sub vars {
  my ( $self, $elem, $v ) = @_;

  $v =~ s/\\\$/:ESCAPE_DOLLAR/g;
  $v =~ s/\\@/:ESCAPE_AT/g;
  $v =~ s/\@(\w+)/\$$1/g;
  $v =~ s/\@(\{\w+\})/\$$1/g;

  my @vars1 = $v =~ /\$(\w+)/g;
  my @vars2 = $v =~ /\$\{(\w+)\}/g;

  $v =~ s/\$\{(\w+)\}/\$$1/g;
  $v =~ s/\\\$/\$/g;

  for ( @vars1, @vars2 ) {
    unless ( exists $elem->{$_} ) {
      my @possible = map { "\$$_" } keys %$elem;
      $self->error(
        "Variable \$$_ (aka \@$_) does not exist. Possible: @possible");
    }

    $self->verbose("Evaluating variable '\$$_' to '$elem->{$_}'");
    $v =~ s/\$$_/$elem->{$_}/;
  }

  $v =~ s/:ESCAPE_DOLLAR/\$/g;
  $v =~ s/:ESCAPE_AT/\@/g;

  return $v;
}

# Update methods
sub update_path_json {
  my ( $self, $path, $params, $set ) = @_;

  my $config = $self->{config};
  my $filter = $self->{filter};

  if ( $config->{'dry'} ) {
    $self->verbose("Dry mode, don't modify anything via API.");
    return undef;
  }

  $filter->compute($params);
  my $url = $self->{url_base} . $path . $filter->{query_string};

  my $json = $self->fetch_path_json( $path, $params );

  $self->backup_path_json( $path, $params, $json );
  my $vals = $self->{json}->decode($json);

  for my $elem (@$vals) {
    while ( my ( $k, $v ) = each %$set ) {
      $elem->{$k} = $self->vars( $elem, $v );
    }
  }

  $json = $self->{json}->encode($vals);

  return $self->send_path_json( $path, $json, 1 );
}

sub update_remove_path_json {
  my ( $self, $path, $params, $remove ) = @_;

  my $config = $self->{config};

  if ( $config->{'dry'} ) {
    $self->verbose("Dry mode, don't modify anything via API.");
    return undef;
  }

  my $json = $self->fetch_path_json( $path, $params );

  $self->backup_path_json( $path, $params, $json );
  my $vals = $self->{json}->decode($json);

  for my $removekey (@$remove) {
    my $flag = 0;

    for my $elem (@$vals) {
      if ( exists $elem->{$removekey} ) {
        delete $elem->{$removekey};
        $flag = 1;
      }
    }

    $self->warning("No key '$removekey' to remove found.") unless $flag;
  }

  $json = $self->{json}->encode($vals);
  return $self->send_path_json( $path, $json, 1, 'PUT' );
}

# Backup methods
sub backup_cleanup {
  my ( $self, $path, $params ) = @_;

  my $config   = $self->{config};
  my $location = $config->get('backups.dir');

  if ( $config->{'dry'} ) {
    $self->verbose(
      "Dry mode, don't modify anything via API, backup irrelevant.");
    return undef;
  }

  my $dir = IO::Dir->new($location);

  if ( defined $dir ) {
    my $days = $config->get('backups.keep.days');

    while ( defined( $_ = $dir->read() ) ) {
      my $backfile = "$location/$_";
      my $age      = -M $backfile;

      #$self->verbose("'$backfile' has age $age");
      if ( $backfile =~ /backup_.*\.json/ && $days <= $age ) {
        $self->verbose("Deleting '$backfile', it's older than $days days");
        unlink $backfile;
      }
    }

    $dir->close();
  }

  return undef;
}

sub backup_path_json {
  my ( $self, $path, $params, $json ) = @_;

  my $config = $self->{config};

  if ( $config->{'dry'} ) {
    $self->verbose(
      "Dry mode, don't modify anything via API, backup irrelevant.");
    return undef;
  }

  return undef if $config->bool('backups.disable');

  my $days     = $config->get('backups.keep.days');
  my $location = $config->get('backups.dir');

  unless ( -d $location ) {
    $self->info("Creating '$location' for backups");
    $self->info("Backups older than $days days will be automatically deleted");
    mkdir $location;
  }

  my $backfile =
    $location . strftime( "/backup_%Y%m%d_%H%M%S_$path.json", localtime );

  #$self->info("To rollback run: $0 post $path < $backfile");

  my $fh = IO::File->new( $backfile, 'w' );
  $self->error("Could not open file $backfile for writing a backup")
    unless defined $fh;

  unless ( defined $json ) {
    $self->verbose("Retrieving data for backup");
    $json = $self->fetch_path_json( $path, $params );
  }

  print $fh $json;

  $fh->close();
  $self->backup_cleanup();

  return undef;
}

1;
