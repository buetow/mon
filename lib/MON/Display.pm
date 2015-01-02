package MON::Display;

use strict;
use warnings;
use v5.10;
use autodie;

use Data::Dumper;
use Term::ANSIColor;

use MON::Config;
use MON::JSON;
use MON::Utils;

our $VERBOSE     = 0;
our $DEBUG       = 0;
our $COLORFUL    = 0;
our $QUIET       = 0;
our $LOGGER      = undef;
our $INTERACTIVE = undef;

sub init {
  my ( $self, %opts ) = @_;

  $VERBOSE     = $self->{'verbose'} == 1;
  $DEBUG       = $self->{'debug'} == 1;
  $QUIET       = $self->{'quiet'} == 1;
  $LOGGER      = $opts{logger};
  $INTERACTIVE = $opts{interactive};

  $self->{logglevel} = 'info';

  if ( $self->{'nocolor'} == 1 ) {
    $COLORFUL = 0;
  }
  else {
    $COLORFUL = $ENV{MON_COLORFUL} // 1;
  }

  $VERBOSE = $DEBUG = $COLORFUL = 0 if $QUIET == 1;

  return undef;
}

sub is_verbose {
  my ($self) = @_;

  return $VERBOSE == 1;
}

sub is_debug {
  my ($self) = @_;

  return $DEBUG == 1;
}

sub is_quiet {
  my ($self) = @_;

  return $QUIET == 1;
}

sub _display {
  my ( $self, $msg, $fh, $level ) = @_;

  return undef unless defined $msg;

  $LOGGER->logg( $self->{logglevel}, $msg ) if defined $LOGGER;

  return undef if $QUIET;

  $fh = *STDERR unless defined $fh;

  print $fh $msg;

  return undef;
}

sub info_no_nl {
  my ( $self, $msg ) = @_;

  print STDERR color 'bold blue' if $COLORFUL;
  $self->_display($msg);
  print STDERR color 'reset' if $COLORFUL;

  return undef;
}

sub out_json {
  my ( $self, $out ) = @_;

  return undef unless defined $out;
  my $config = $self->{config};

  local $, = "\n";

  my $json = MON::JSON->new()->decode($out);
  my $num_results = ref $json eq 'ARRAY' ? @$json : undef;

  # Don't _display meta aka custom variables unless -m or --meta is specified
  unless ( $config->{'meta'} ) {
    if ( ref $json eq 'ARRAY' ) {
      @$json = map {
        if ( ref $_ eq 'HASH' )
        {
          my $h = $_;
          delete $h->{$_} for grep /^_/, keys %$h;
          $h;
        }
        else {
          $_;
        }
      } @$json;
    }
  }

  # Sort and pretty print all the JSON pretty pretty please
  unless ( defined $config->{outfile} ) {
    print MON::JSON->new()->encode_canonical($json) unless $QUIET;
  }
  else {
    my $outfile = $config->{outfile};
    print $outfile MON::JSON->new()->encode_canonical($json);
    print STDERR color 'bold green' if $COLORFUL;
    $self->_display("Wrote JSON to file\n");
    print STDERR color 'reset' if $COLORFUL;
  }

  $LOGGER->logg( 'info', JSON->new()->encode($json) ) if defined $LOGGER;

  print STDERR color 'bold green'                 if $COLORFUL;
  $self->_display("Found $num_results entries\n") if defined $num_results;
  print STDERR color 'reset'                      if $COLORFUL;

  return undef;
}

sub out_format {
  my ( $self, $format, $out ) = @_;

  return undef unless defined $out;

  my $config      = $self->{config};
  my $options     = $self->{options};
  my $json        = MON::JSON->new()->decode($out);
  my $num_results = ref $json eq 'ARRAY' ? @$json : undef;

  $self->error("Expected an JSON Array") if ref $json ne 'ARRAY';

  my @vars1 = $format =~ /\$(\w+)/g;
  my @vars2 = $format =~ /\$\{(\w+)\}/g;
  my @vars3 = $format =~ /\@(\w+)/g;
  my @vars4 = $format =~ /\@\{(\w+)\}/g;

  my %vars;
  $vars{$_} = '' for @vars1, @vars2, @vars3, @vars4;
  my @out;
  my %empty;

  for my $obj (@$json) {
    my %obj_vars   = %vars;
    my $obj_format = $format;

    for my $var ( keys %obj_vars ) {
      if ( $var eq 'HOSTNAME' ) {
        my $val = exists $obj->{host_name} ? $obj->{host_name} : '';

        if ( $val eq '' ) {
          $empty{$var} = 1;
        }
        else {
          $val =~ s/\..*//;
        }

        $obj_format =~ s/\$$var/$val/g;

      }
      else {
        my $val = exists $obj->{$var} ? $obj->{$var} : '';
        $empty{$var} = 1 if $val eq '';

        $obj_format =~ s/\$$var/$val/g;
        $obj_format =~ s/\$\{$var\}/$val/g;
        $obj_format =~ s/\@$var/$val/g;
        $obj_format =~ s/\@\{$var\}/$val/g;
      }
    }

    push @out, $obj_format if $obj_format =~ /^.*\w+.*$/;
  }

  if (@out) {

    if ( $config->{'unique'} ) {
      my %lines;
      @out = grep { exists $lines{$_} ? 0 : ( $lines{$_} = 1 ) } sort @out;
      $num_results = @out;
    }
    else {
      @out = sort @out;
    }

    if ( $QUIET == 0 ) {
      local $, = "\n";
      print @out;
      say '';
    }
    elsif ( defined $LOGGER ) {
      $LOGGER->logg( 'info', $_ ) for @out;
    }
  }

  $self->warning( "Some objects dont have such a field or have empty strings: "
      . join( ' ', sort keys %empty ) )
    if keys %empty;

  print STDERR color 'bold green'                 if $COLORFUL;
  $self->_display("Found $num_results entries\n") if defined $num_results;
  print STDERR color 'reset'                      if $COLORFUL;

  return undef;
}

sub info {
  my ( $self, $msg ) = @_;

  my $str = "$msg\n";
  $self->{logglevel} = 'info';

  print STDERR color 'bold blue' if $COLORFUL;
  $self->_display($str);
  print STDERR color 'reset' if $COLORFUL;

  return undef;
}

sub nl {
  my ($self) = @_;

  $self->_display("\n");

  return undef;
}

sub error {
  my ( $self, $msg ) = @_;

  $self->error_no_exit($msg);

  exit 3 unless $INTERACTIVE;
}

sub error_no_exit {
  my ( $self, $msg ) = @_;

  $self->{logglevel} = 'warning';
  print STDERR color 'bold red' if $COLORFUL;
  $self->_display( "! ERROR: $msg\n", *STDERR );
  print STDERR color 'reset' if $COLORFUL;

  return undef;
}

sub possible {
  my ( $self, @params ) = @_;

  my $config  = $self->{config};
  my $options = $self->{options};

  push @params, $options->get_keys()
    if $config->{'help'};

  my $msg = '';

  if (@params) {
    for ( grep !/^V_ALIAS/, @params ) {
      if ( ref $_ eq 'ARRAY' ) {
        $msg .= join "\n", @$_;
        $msg .= "\n";
      }
      else {
        $msg .= "$_\n";
      }
    }
  }
  else {
    $msg .= "\n";
  }

  $self->{logglevel} = 'info';
  $self->_display($msg);

  exit 0 unless $INTERACTIVE;
}

sub warning {
  my ( $self, $msg ) = @_;

  my $str = "! $msg\n";

  print STDERR color 'red' if $COLORFUL;
  $self->_display( $str, *STDERR );
  print STDERR color 'reset' if $COLORFUL;

  return undef;
}

sub verbose {
  my ( $self, @msgs ) = @_;

  print STDERR color 'cyan' if $COLORFUL;
  $self->{logglevel} = 'info';

  if ( $self->is_verbose() ) {
    for my $msg (@msgs) {
      if ( $self->is_debug() ) {
        my @caller = caller;
        $self->_display("@caller: $msg\n");
      }
      else {
        $self->_display("$msg\n");
      }
    }
  }

  print STDERR color 'reset' if $COLORFUL;

  return undef;
}

sub dump {
  my ( $self, $msg ) = @_;

  $self->{logglevel} = 'warning';
  $self->_display( Dumper $msg );

  return undef;
}

sub debug {
  my ( $self, @msgs ) = @_;

  my @caller = caller;

  if ( $self->is_debug() ) {
    for my $msg (@msgs) {
      $msg = Dumper $msg if ref $msg ne '';

      my $str = "@caller: $msg\n";

      $self->{logglevel} = 'debug';
      $self->_display($str);
    }
  }

  return undef;
}

1;

