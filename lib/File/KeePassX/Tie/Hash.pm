package File::KeePassX::Tie::Hash;
# ABSTRACT: Hash base class

use warnings;
use strict;

use parent 'Tie::Hash';

our $VERSION = '999.999'; # VERSION

sub getters { +{} }
sub setters { +{} }

sub keys {
    my $self = shift;
    return [keys %{$self->getters}];
}

sub default_getter {}
sub default_setter {}

sub TIEHASH {
    my $class = shift;
    return bless [@_], $class;
}

sub FIRSTKEY {
    my ($self) = @_;
    return $self->keys->[0];
}

sub NEXTKEY {
    my ($self, $last_key) = @_;
    my @keys = @{$self->keys};
    for (my $i = 0; $i < @keys; ++$i) {
        return $keys[$i + 1] if $keys[$i] eq $last_key;
    }
}

sub EXISTS {
    my ($self, $key) = @_;
    return !!grep { $_ eq $key } @{$self->keys};
}

sub FETCH {
    my ($self, $key) = @_;
    return $self->[0] if $key eq '__object';
    my $getter = $self->getters->{$key} // $self->default_getter($key);
    return $getter->(@$self) if $getter;
}

sub STORE {
    my ($self, $key, $value) = @_;
    my $setter = $self->setters->{$key} // $self->default_setter($key);
    local $_ = $value;
    $setter->(@$self) if $setter;
}

1;
__END__

=for Pod::Coverage getters setters keys default_getter default_setter

=cut
