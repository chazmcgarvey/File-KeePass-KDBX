package File::KeePassX::Tie::GroupList;
# ABSTRACT: Database group list

use warnings;
use strict;

use File::KDBX::Loader::KDB;

use parent 'Tie::Array';

our $VERSION = '999.999'; # VERSION

sub TIEARRAY {
    my $class = shift;
    my $self = bless [@_], $class;
    splice(@$self, 1, 0, '_kpx_groups') if @$self == 2;
    return $self;
}

sub FETCH {
    my ($self, $index) = @_;
    my ($thing, $method, $k) = @$self;
    my $group = $thing->$method->[$index] or return;
    return $k->_tie({}, 'Group', $k->kdbx->_group($group));
}

sub FETCHSIZE {
    my ($self) = @_;
    my ($thing, $method) = @$self;
    return scalar @{$thing->$method};
}

sub STORE {
    my ($self, $index, $value) = @_;
    my ($thing, $method, $k) = @$self;
    my %info = %$value;
    %$value = ();
    my $group_info = File::KDBX::Loader::KDB::_convert_keepass_to_kdbx_group(\%info);
    return $self->_tie($value, 'Group', $thing->$method->[$index] = $k->kdbx->_group($group_info));
}

sub STORESIZE {
    my ($self, $count) = @_;
    my ($thing, $method) = @$self;
    splice @{$thing->$method}, $count;
}

sub EXISTS {
    my ($self, $index) = @_;
    my ($thing, $method) = @$self;
    return exists $thing->$method->[$index];
}

sub DELETE {
    my ($self, $index) = @_;
    my ($thing, $method) = @$self;
    delete $thing->$method->[$index];
}

1;
