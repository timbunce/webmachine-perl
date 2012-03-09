package Web::Machine::Util::MediaType;

use strict;
use warnings;

use Carp         qw[ confess ];
use Scalar::Util qw[ blessed ];

use overload '""' => 'to_string', fallback => 1;

sub new {
    my $class = shift;
    my ($type, @params) = @_;

    confess "You must specify a type" unless $type;
    confess "Params must be an even sized list" unless (((scalar @params) % 2) == 0);

    my @param_order;
    for ( my $i = 0; $i < $#params; $i += 2 ) {
        push @param_order => $params[ $i ];
    }

    bless {
        type        => $type,
        params      => { @params },
        param_order => \@param_order
    } => $class;
}

sub type   { (shift)->{'type'}   }
sub params { (shift)->{'params'} }

sub _param_order { (shift)->{'param_order'} }

sub new_from_string {
    my ($class, $media_type) = @_;
    if ( $media_type =~ /^\s*([^;\s]+)\s*((?:;\s*\S+\s*)*)\s*$/ ) {
        my ($type, $raw_params) = ($1, $2);
        my @params = ($raw_params =~ /;\s*([^=]+)=([^;=\s]+)/g);
        return $class->new( $type => @params );
    }
    confess "Unable to parse media type from '$media_type'"
}

sub major { (split '/' => (shift)->type)[0] }
sub minor { (split '/' => (shift)->type)[1] }

sub add_param {
    my ($self, $k, $v) = @_;
    $self->params->{ $k } = $v;
    push @{ $self->_param_order } => $k;
}

sub remove_param {
    my ($self, $k) = @_;
    $self->{'param_order'} = [ grep { $_ ne $k } @{ $self->{'param_order'} } ];
    return delete $self->params->{ $k };
}

sub to_string {
    my $self = shift;
    join ';' => $self->type, map { join '=' => $_, $self->params->{ $_ } } @{ $self->_param_order };
}

sub matches_all {
    my $self = shift;
    $self->type eq '*/*' && $self->params_are_empty
        ? 1 : 0;
}

## ...

# must be exactly the same
sub equals {
    my ($self, $other) = @_;
    $other = (ref $self)->new_from_string( $other ) unless blessed $other;
    $other->type eq $self->type && _compare_params( $self->params, $other->params )
        ? 1 : 0;
}

# types must be compatible and params much match exactly
sub exact_match {
    my ($self, $other) = @_;
    $other = (ref $self)->new_from_string( $other ) unless blessed $other;
    $self->type_matches( $other ) && _compare_params( $self->params, $other->params )
        ? 1 : 0;
}

# types must be be compatible and params should align
sub match {
    my ($self, $other) = @_;
    $other = (ref $self)->new_from_string( $other ) unless blessed $other;
    $self->type_matches( $other ) && $self->params_match( $other->params )
        ? 1 : 0;
}

## ...

sub type_matches {
    my ($self, $other) = @_;
    return 1 if $other->type eq '*' || $other->type eq '*/*' || $other->type eq $self->type;
    $other->major eq $self->major && $other->minor eq '*'
        ? 1 : 0;
}

sub params_match {
    my ($self, $other) = @_;
    my $params = $self->params;
    foreach my $k ( keys %$other ) {
        return 0 if not exists $params->{ $k };
        return 0 if $params->{ $k } ne $other->{ $k };
    }
    return 1;
}

sub params_are_empty {
    my $self = shift;
    (scalar keys %{ $self->params }) == 0 ? 1 : 0
}

## ...

sub _compare_params {
    my ($left, $right) = @_;
    my @left_keys  = sort keys %$left;
    my @right_keys = sort keys %$right;

    return 0 unless (scalar @left_keys) == (scalar @right_keys);

    foreach my $i ( 0 .. $#left_keys ) {
        return 0 unless $left_keys[$i] eq $right_keys[$i];
        return 0 unless $left->{ $left_keys[$i] } eq $right->{ $right_keys[$i] };
    }

    return 1;
}

1;

__END__

# ABSTRACT: A Media Type

=head1 SYNOPSIS

  use Web::Machine::Util::MediaType;

=head1 DESCRIPTION

