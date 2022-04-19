package File::KeePass::KDBX::Tie::EntryList;
# ABSTRACT: Database entry list

use warnings;
use strict;

use File::KDBX::Loader::KDB;

use parent 'Tie::Array';

our $VERSION = '999.999'; # VERSION

sub TIEARRAY {
    my $class = shift;
    my $self = bless [@_], $class;
    splice(@$self, 1, 0, 'entries') if @$self == 2;
    return $self;
}

sub FETCH {
    my ($self, $index) = @_;
    my ($thing, $method, $k) = @$self;
    my $entry = $thing->$method->[$index] or return;
    return $k->_tie({}, 'Entry', $k->kdbx->_wrap_entry($entry));
}

sub FETCHSIZE {
    my ($self) = @_;
    my ($thing, $method) = @$self;
    return scalar @{$thing->$method};
}

sub STORE {
    my ($self, $index, $value) = @_;
    return if !$value;
    my ($thing, $method, $k) = @$self;
    my $entry_info = File::KDBX::Loader::KDB::_convert_keepass_to_kdbx_entry($value);
    %$value = ();
    return $k->_tie($value, 'Entry', $thing->$method->[$index] = $k->kdbx->_wrap_entry($entry_info));
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
