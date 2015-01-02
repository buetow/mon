package MON::Query;

use strict;
use warnings;
use v5.10;

use Data::Dumper;

use MON::Display;
use MON::Config;
use MON::Utils;
use MON::QueryBase;

our @ISA = ('MON::QueryBase');

sub new {
  my ( $class, %opts ) = @_;

  my $self = bless \%opts, $class;

  $self->init();

  return $self;
}

sub init {
  my ($self) = @_;

  $self->{querystack} = [];
  $self->{args} = [ map { s/^V_/:V_/; $_ } @{ $self->{args} } ];

  return undef;
}

sub tree {
  my ($self) = @_;

  my $api   = $self->{api};
  my $paths = $api->get_possible_paths();

  my ( $s, $r ) = ( $self, $api );

  my $arr = sub {
    my ( $keys, $vals ) = @_;
    map { $_ => shift @$vals } @$keys;
  };

# _ => By default to run anonymous sub if no other key is specified in command line
# __ => Always to run anonymous sub in the beginning of the current recursion
# ___ => Always to run anonymous sub before next recursion
# __DO => Process recursion right away, only do __ if exists
# V_FOO => Declare variable FOO

  my $where = {
    _ => sub {
      my $d = shift;
      $s->possible( $r->get_path_params( $d->{V_PATH} ) );
    },
    V_KEY => {
      __ => sub {
        my $d = shift;
        $s->check_has( $d->{V_KEY}, $r->get_path_params( $d->{V_PATH} ) );
      },
      like => {
        V_VAL => {
          _ => sub {
            my $d    = shift;
            my $path = $d->{V_PATH};
            $s->out_json( $d->{where_action}($path) );
          },
        },
        ___ => sub { $s->push_querystack('OP_LIKE') }
      },
      matches => {
        V_VAL => {
          _ => sub {
            my $d    = shift;
            my $path = $d->{V_PATH};
            $s->out_json( $d->{where_action}($path) );
          },
        },
        ___ => sub { $s->push_querystack('OP_MATCHES') }
      },
      nmatches => {
        V_VAL => {
          _ => sub {
            my $d    = shift;
            my $path = $d->{V_PATH};
            $s->out_json( $d->{where_action}($path) );
          },
        },
        ___ => sub { $s->push_querystack('OP_NMATCHES') }
      },
      eq => {
        V_VAL => {
          _ => sub {
            my $d    = shift;
            my $path = $d->{V_PATH};
            $s->out_json( $d->{where_action}($path) );
          },
        },
        ___ => sub { $s->push_querystack('OP_EQ') }
      },
      ne => {
        V_VAL => {
          _ => sub {
            my $d    = shift;
            my $path = $d->{V_PATH};
            $s->out_json( $d->{where_action}($path) );
          },
        },
        ___ => sub { $s->push_querystack('OP_NE') }
      },
      lt => {
        V_VAL => {
          _ => sub {
            my $d    = shift;
            my $path = $d->{V_PATH};
            $s->out_json( $d->{where_action}($path) );
          },
        },
        ___ => sub { $s->push_querystack('OP_LT') }
      },
      le => {
        V_VAL => {
          _ => sub {
            my $d    = shift;
            my $path = $d->{V_PATH};
            $s->out_json( $d->{where_action}($path) );
          },
        },
        ___ => sub { $s->push_querystack('OP_LE') }
      },
      gt => {
        V_VAL => {
          _ => sub {
            my $d    = shift;
            my $path = $d->{V_PATH};
            $s->out_json( $d->{where_action}($path) );
          },
        },
        ___ => sub { $s->push_querystack('OP_GT') }
      },
      ge => {
        V_VAL => {
          _ => sub {
            my $d    = shift;
            my $path = $d->{V_PATH};
            $s->out_json( $d->{where_action}($path) );
          },
        },
        ___ => sub { $s->push_querystack('OP_GE') }
      },
    },
  };

  for my $op ( sort qw(like matches nmatches eq ne lt le gt ge) ) {
    $where->{V_KEY}{$op}{V_VAL}{and}{__DO} = $where;
    $where->{V_KEY}{$op}{V_VAL}{'V_ALIAS:a'} = $where->{V_KEY}{$op}{V_VAL}{and};
  }

  $where->{V_KEY}{'V_ALIAS:l'}  = $where->{V_KEY}{like};
  $where->{V_KEY}{'V_ALIAS:~'}  = $where->{V_KEY}{like};
  $where->{V_KEY}{'V_ALIAS:=='} = $where->{V_KEY}{eq};
  $where->{V_KEY}{'V_ALIAS:!='} = $where->{V_KEY}{ne};
  $where->{V_KEY}{'V_ALIAS:=~'} = $where->{V_KEY}{matches};
  $where->{V_KEY}{'V_ALIAS:!~'} = $where->{V_KEY}{nmatches};

  my $set_where = {
    _ => sub {
      my $d = shift;
      $s->possible( $r->get_path_params( $d->{V_PATH} ) );
    },
    V_SETKEY => {
      '=' => {
        V_SETVAL => {
          __ => sub {
            my $d = shift;
            $d->{where_action} = $d->{set_action};
          },
          where => $where,
        },
      },
    },
  };
  $set_where->{V_SETKEY}{'='}{V_SETVAL}{and} = $set_where;
  $set_where->{V_SETKEY}{'='}{V_SETVAL}{'V_ALIAS::'} =
    $set_where->{V_SETKEY}{'='}{V_SETVAL}{where};
  $set_where->{V_SETKEY}{'='}{V_SETVAL}{'V_ALIAS:a'} =
    $set_where->{V_SETKEY}{'='}{V_SETVAL}{and};

  my $set = {
    _ => sub {
      my $d = shift;
      $s->possible( $r->get_path_params( $d->{V_PATH} ) );
    },
    V_SETKEY => {
      '=' => {
        V_SETVAL => {
          _ => sub {
            my $d    = shift;
            my $path = $d->{V_PATH};

            $s->out_json( $d->{set_action}($path) );
          },
        },
      },
    },
  };
  $set->{V_SETKEY}{'='}{V_SETVAL}{and} = $set;
  $set->{V_SETKEY}{'='}{V_SETVAL}{'V_ALIAS:a'} =
    $set->{V_SETKEY}{'='}{V_SETVAL}{and};

  my $remove = {
    _ => sub {
      my $d = shift;
      $s->possible( $r->get_path_params( $d->{V_PATH} ) );
    },
    V_REMOVEKEY => {
      __ => sub {
        my $d = shift;
        $d->{where_action} = $d->{remove_action};
      },
      where => $where,
    },
  };
  $remove->{V_REMOVEKEY}{and} = $remove;
  $remove->{V_REMOVEKEY}{'V_ALIAS:a'} = $remove->{V_REMOVEKEY}{and};

  my $tree = {
    get => {
      _      => sub { $s->possible(@$paths) },
      V_PATH => {
        __ => sub {
          my $d = shift;
          $s->check_has( $d->{V_PATH}, $paths );
          $d->{where_action} = sub {
            my ($path) = @_;
            $r->fetch_path_json( $path, $s->get_querystack() );
          };
        },
        _ => sub {
          my $d = shift;
          $s->out_json(
            $r->fetch_path_json( $d->{V_PATH}, $s->get_querystack() ) );
        },
        where => $where,
      },
    },
    getfmt => {
      V_FORMAT => {
        _      => sub { $s->possible(@$paths) },
        V_PATH => {
          __ => sub {
            my $d = shift;
            $s->check_has( $d->{V_PATH}, $paths );
            $d->{where_action} = sub {
              my ($path) = @_;
              $s->out_format( $d->{V_FORMAT},
                $r->fetch_path_json( $path, $s->get_querystack() ) );
            };
          },
          _ => sub {
            my $d = shift;
            $s->out_format( $d->{V_FORMAT},
              $r->fetch_path_json( $d->{V_PATH}, $s->get_querystack() ) );
          },
          where => $where,
        },
      },
    },
    edit => {
      _      => sub { $s->possible(@$paths) },
      V_PATH => {
        __ => sub {
          my $d = shift;
          $s->check_has( $d->{V_PATH}, $paths );
          $d->{where_action} = sub {
            my ($path) = @_;
            $s->edit_path_data( $path,
              $r->fetch_path_json( $path, $s->get_querystack() ) );
          };
        },
        _ => sub {
          my $d = shift;
          $s->edit_path_data( $d->{V_PATH},
            $r->fetch_path_json( $d->{V_PATH} ) );
        },
        where => $where,
      },
    },
    view => {
      _      => sub { $s->possible(@$paths) },
      V_PATH => {
        __ => sub {
          my $d = shift;
          $s->check_has( $d->{V_PATH}, $paths );
          $d->{where_action} = sub {
            my ($path) = @_;
            $s->view_data( $path,
              $r->fetch_path_json( $path, $s->get_querystack() ) );
          };
        },
        _ => sub {
          my $d = shift;
          $s->view_data( $d->{V_PATH}, $r->fetch_path_json( $d->{V_PATH} ) );
        },
        where => $where,
      },
    },
    delete => {
      _      => sub { $s->possible(@$paths) },
      V_PATH => {
        __ => sub {
          my $d = shift;
          $s->check_has( $d->{V_PATH}, $paths );
          $d->{where_action} = sub {
            my ($path) = @_;
            $s->out_json( $r->delete_path_json( $path, $s->get_querystack() ) );
          };
        },
        _ => sub {
          my $d = shift;
          $s->out_json( $r->fetch_path_json( $d->{V_PATH} ) );
        },
        where => $where,
      },
    },
    update => {
      _      => sub { $s->possible(@$paths) },
      V_PATH => {
        __ => sub {
          my $d = shift;
          $s->check_has( $d->{V_PATH}, $paths );
          $d->{set_action} = sub {
            my ($path) = @_;
            my %set = $arr->( $d->{ALL_V_SETKEY}, $d->{ALL_V_SETVAL} );
            $s->out_json(
              $r->update_path_json( $path, $s->get_querystack(), \%set ) );
          };
          $d->{remove_action} = sub {
            my ($path) = @_;
            my $remove = $d->{ALL_V_REMOVEKEY};
            $s->out_json(
              $r->update_remove_path_json(
                $path, $s->get_querystack(), $remove
              )
            );
          };
        },
        set      => $set_where,
        'delete' => $remove,
      },
    },
    insert => {
      _      => sub { $s->possible(@$paths) },
      V_PATH => {
        __ => sub {
          my $d = shift;
          $s->check_has( $d->{V_PATH}, $paths );
          $d->{set_action} = sub {
            my ($path) = @_;
            my %set = $arr->( $d->{ALL_V_SETKEY}, $d->{ALL_V_SETVAL} );
            $s->out_json( $self->insert_data( $path, \%set ) );
          };
        },
        set => $set,
      },
    },
    post => {
      _      => sub { $s->possible(@$paths) },
      V_PATH => {
        __ => sub {
          my $d = shift;
          $s->check_has( $d->{V_PATH}, $paths );
        },
        _ => sub {
          my $d = shift;
          $s->send_data( $d->{V_PATH}, 'POST' );
        },
        from => {
          V_FILEPATH => {
            _ => sub {
              my $d = shift;
              $s->send_data( $d->{V_PATH}, 'POST', $d->{V_FILEPATH} );
              }
          }
        }
      },
    },
    put => {
      _      => sub { $s->possible(@$paths) },
      V_PATH => {
        __ => sub {
          my $d = shift;
          $s->check_has( $d->{V_PATH}, $paths );
        },
        _ => sub {
          my $d = shift;
          $s->send_data( $d->{V_PATH}, 'PUT' );
        },
        from => {
          V_FILEPATH => {
            _ => sub {
              my $d = shift;
              $s->send_data( $d->{V_PATH}, 'PUT', $d->{V_FILEPATH} );
              }
          }
        }
      },
    },
    verify      => sub { $s->verify() },
    restart     => sub { $s->restart() },
    reload      => sub { $s->restart() },
    'V_ALIAS:y' => sub { $s->verify() },
    'V_ALIAS:r' => sub { $s->restart() },
  };

  $tree->{delete}{V_PATH}{'V_ALIAS::'} = $tree->{delete}{V_PATH}{where};
  $tree->{'V_ALIAS:d'} = $tree->{delete};

  $tree->{edit}{V_PATH}{'V_ALIAS::'} = $tree->{edit}{V_PATH}{where};
  $tree->{'V_ALIAS:e'} = $tree->{edit};

  $tree->{get}{V_PATH}{'V_ALIAS::'} = $tree->{get}{V_PATH}{where};
  $tree->{'V_ALIAS:g'} = $tree->{get};

  $tree->{getfmt}{V_FORMAT}{V_PATH}{'V_ALIAS::'} =
    $tree->{getfmt}{V_FORMAT}{V_PATH}{where};
  $tree->{'V_ALIAS:f'} = $tree->{getfmt};

  $tree->{insert}{V_PATH}{'V_ALIAS:s'} = $tree->{insert}{V_PATH}{set};
  $tree->{'V_ALIAS:i'} = $tree->{insert};

  $tree->{'V_ALIAS:p'} = $tree->{post};

  $tree->{'V_ALIAS:t'} = $tree->{put};

  $tree->{update}{V_PATH}{'V_ALIAS:d'} = $tree->{update}{V_PATH}{delete};
  $tree->{update}{V_PATH}{'V_ALIAS:s'} = $tree->{update}{V_PATH}{set};
  $tree->{'V_ALIAS:u'}                 = $tree->{update};

  $tree->{view}{V_PATH}{'V_ALIAS::'} = $tree->{view}{V_PATH}{where};
  $tree->{'V_ALIAS:v'} = $tree->{view};

  $self->debug( 'Abstract syntax tree:', $tree );

  return $tree;
}

sub parse {
  my ($self) = @_;

  my $config = $self->{config};
  my $args   = $self->{args};

  # Get > and < operators (only needed by interactive mode)
  $config->{outfile} = $config->{infile} = undef;
  if ( defined $args->[-2] ) {
    given ( $args->[-2] ) {
      when ('>') {
        my ( undef, $file ) = splice @$args, -2, 2;
        open $config->{outfile}, '>', $file or $self->warning("$file: $!");
      }
      when ('<') {
        my ( undef, $file ) = splice @$args, -2, 2;
        open $config->{infile}, '<', $file or $self->warning("$file: $!");
      }
    }
  }

  my $ret = $self->traverse( $args, $self->tree(), {} );

  close $config->{infile}  if defined $config->{infile};
  close $config->{outfile} if defined $config->{outfile};

  return $ret;
}

sub traverse {
  my ( $self, $args, $tree, $data ) = @_;

  $self->debug( 'Traversing args: ' . Dumper $args);
  $self->debug( 'Traversing data: ' . Dumper $data);

  if ( ref $tree eq 'CODE' ) {
    $tree->($data);
    return undef;
  }

  $tree->{__}->($data) if exists $tree->{__};

  if ( exists $tree->{__DO} ) {
    $self->traverse( $args, $tree->{__DO}, $data );
    return undef;
  }

  my @possible = grep !/^__?$/, sort keys %$tree;
  my $token = $possible[0];

  unless (@$args) {
    if ( exists $tree->{_} ) {
      $tree->{_}->($data);
    }
    else {
      $self->possible(@possible);
    }
  }
  else {
    my $arg = shift @$args;

    if ( exists $tree->{$arg} ) {
      $tree->{___}->($data) if exists $tree->{___};
      $self->traverse( $args, $tree->{$arg}, $data );
    }
    elsif ( exists $tree->{"V_ALIAS:$arg"} ) {
      $tree->{___}->($data) if exists $tree->{___};
      $self->traverse( $args, $tree->{"V_ALIAS:$arg"}, $data );
    }
    elsif ( defined $token && $token =~ /^V_/ && $token !~ /^V_ALIAS:/ ) {
      $data->{$token} = $arg;
      $self->push_querystack($arg) if $token =~ /^V_(?:KEY|VAL)/;

      unless ( exists $data->{"ALL_$token"} ) {
        $data->{"ALL_$token"} = [$arg];
      }
      else {
        push @{ $data->{"ALL_$token"} }, $arg;
      }

      $tree->{___}->($data) if exists $tree->{___};
      $self->traverse( $args, $tree->{$token}, $data );
    }
    else {
      $self->error("'$arg' unexpected here");
    }
  }

  return undef;
}

sub push_querystack {
  my ( $self, $token ) = @_;

  $self->debug("Pushing token '$token' to querystack");
  push @{ $self->{querystack} }, $token;

  return undef;
}

sub get_querystack {
  my ($self) = @_;

  return $self->{querystack};
}

1;
