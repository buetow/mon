package MON::Options;

use strict;
use warnings;
use v5.10;
use autodie;

use Data::Dumper;
use Scalar::Util qw(looks_like_number);

use MON::Utils;

sub new {
  my ( $class, %opts ) = @_;

  my $self = bless \%opts, $class;

  $self->init();
  $self->parse();

  return $self;
}

sub init {
  my ($self) = @_;

  my %opts = (
    opts => {
      config      => '',
      debug       => 0,
      dry         => 0,
      help        => 0,
      interactive => 0,
      meta        => 0,
      nocolor     => 0,
      quiet       => 0,
      syslog      => 0,
      unique      => 0,
      verbose     => 0,
      version     => 0,
      errfile     => '',
    },
    opts_short => {
      c => 'config',
      D => 'debug',
      d => 'dry',
      i => 'interactive',
      h => 'help',
      m => 'meta',
      n => 'nocolor',
      q => 'quiet',
      s => 'syslog',
      u => 'unique',
      v => 'verbose',
      V => 'version',
      R => 'errfile',
    },
    unknown => [],
  );

  $self->{$_} = $opts{$_} for keys %opts;

  return undef;
}

sub parse {
  my ($self) = @_;

  my $opts_passed = $self->{opts_passed};

  for my $opt (@$opts_passed) {
    my ( $k, $v ) = split /=/, $opt;

    # Longopt
    if ( $k =~ s/^--// && isin $k, keys %{ $self->{opts} } ) {
      if ( defined $v ) {
        $self->{opts}{$k} = $v;
      }
      else {
        $self->{opts}{$k} = 1;
      }
    }

    # Shortopt
    elsif ( $k =~ s/^-// && isin $k, keys %{ $self->{opts_short} } ) {
      if ( defined $v ) {
        $self->{opts}{ $self->{opts_short}{$k} } = $v;
      }
      else {
        $self->{opts}{ $self->{opts_short}{$k} } = 1;
      }

    }
    elsif ( $k !~ /\./ ) {

      # If key is not separated by dot, it is unknown
      push @{ $self->{unknown} }, $opt;

    }
    else {

      # Otherise it might overwrite a value of mon.conf
      $self->{opts}{$k} = $v;
    }
  }

  # Help implies dry mode
  $self->{opts}{dry} = 1 if $self->{opts}{help};

  # Debug implies verbose mode
  $self->{opts}{verbose} = 1 if $self->{opts}{debug};

  return undef;
}

sub get_keys {
  my ($self) = @_;
  my @keys;

  while ( my ( $k, $v ) = each %{ $self->{opts_short} } ) {
    if ( looks_like_number( $self->{opts}{$v} ) ) {
      push @keys, "--$v -$k";
    }
    else {
      push @keys, "--$v=VAL -$k=VAL";
    }
  }

  return @keys;
}

sub store {
  my ( $self, $config ) = @_;

  $self->store_first($config);
  $self->store_after($config);

  return undef;
}

# Only store values which are not separated by dots
sub store_first {
  my ( $self, $config ) = @_;

  for ( grep !/\./, keys %{ $self->{opts} } ) {
    $config->{$_} = $self->{opts}{$_};
  }

  return undef;
}

# Only store values which are separated by dots
sub store_after {
  my ( $self, $config ) = @_;

  for ( grep /\./, keys %{ $self->{opts} } ) {
    $config->{$_} = $self->{opts}{$_};
  }

  return undef;
}

1;
