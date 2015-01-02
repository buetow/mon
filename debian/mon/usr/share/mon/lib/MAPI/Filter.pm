package MON::Filter;

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

  $self->{query_string} = '';
  $self->{filters}      = {};
  $self->{num_filters}  = 0;
  $self->{is_computed}  = 0;
  $self->{or}           = [];

  return undef;
}

# Create filters with params
sub compute {
  my ( $self, $params ) = @_;

  $self->debug( 'Computing filter using', $params );
  return undef if $self->{is_computed};

  my %likes;

  if ( defined $params and ref $params eq 'ARRAY' ) {
    while (@$params) {
      my $op_token = pop @$params;
      given ($op_token) {
        when (/^OP_LIKE$/) {
          my $arg2 = pop @$params;
          my $arg1 = pop @$params;

          if ( exists $likes{$arg1} ) {
            $self->error(
"Can not run multiple 'like's on '$arg1', since it is used for the API query_string"
            );
          }
          else {
            $likes{$arg1} = "$arg1=$arg2";
          }

        }
        when (/^OP_/) {
          $self->{filters}{$_} = [] unless exists $self->{filters}{$_};
          my $arg2 = pop @$params;
          my $arg1 = pop @$params;
          push @{ $self->{filters}{$_} }, [ $arg1, $arg2 ];
          $self->{num_filters}++;
        }
        default {
          $self->error("Inernal error: Operator expected instead of $_");
        }
      }
    }
  }

  $self->{query_string} = '?' . join( '&', values %likes );
  $self->{is_computed} = 1;

  $self->debug( 'Computed filter:', $self->{filters} );
  $self->verbose( "Computed query string is: " . $self->{query_string} );

  return undef;
}

sub filter {
  my ( $self, $objects ) = @_;

  my $config = $self->{config};
  my $json   = $self->{json};

  return $objects unless $self->{num_filters};

  my $num = sub {
    my $str = shift;
    $str =~ s/\D//g;
    $str = 0 if $str eq '';
    return int $str;
  };

  while ( my ( $op, $vals ) = each %{ $self->{filters} } ) {
    for my $val (@$vals) {
      my ( $key, $val ) = @$val;

      @$objects = grep {
        my $object = $_;

        if ( exists $object->{$key} ) {
          if ( $op eq 'OP_MATCHES' and $object->{$key} =~ /$val/ ) {
            1;

          }
          elsif ( $op eq 'OP_NMATCHES' and $object->{$key} !~ /$val/ ) {
            1;

          }
          elsif ( $op eq 'OP_EQ' and $object->{$key} eq $val ) {
            1;

          }
          elsif ( $op eq 'OP_NE' and $object->{$key} ne $val ) {
            1;

          }
          elsif ( $op eq 'OP_LT'
            and $num->( $object->{$key} ) < $num->($val) )
          {
            1;

          }
          elsif ( $op eq 'OP_LE'
            and $num->( $object->{$key} ) <= $num->($val) )
          {
            1;

          }
          elsif ( $op eq 'OP_GT'
            and $num->( $object->{$key} ) > $num->($val) )
          {
            1;

          }
          elsif ( $op eq 'OP_GE'
            and $num->( $object->{$key} ) >= $num->($val) )
          {
            1;

          }
          else {
            0;
          }
        }
        else {
          0;
        }
      } @$objects;
    }
  }

  return $objects;
}

1;

