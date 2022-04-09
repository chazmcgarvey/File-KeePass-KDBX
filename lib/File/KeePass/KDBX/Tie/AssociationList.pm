package File::KeePass::KDBX::Tie::AssociationList;
# ABSTRACT: Auto-type window association list

use warnings;
use strict;

use parent 'Tie::Array';

our $VERSION = '999.999'; # VERSION

sub TIEARRAY {
    my $class = shift;
    return bless [@_], $class;
}

sub FETCH {
    my ($self, $index) = @_;
    my ($entry, $k) = @$self;
    my $association = $entry->auto_type->{associations}[$index] or return;
    return $k->_tie({}, 'Association', $association);
}

sub FETCHSIZE {
    my ($self) = @_;
    my ($entry) = @$self;
    return scalar @{$entry->auto_type->{associations} || []};
}

sub STORE {
    my ($self, $index, $value) = @_;
    my ($entry) = @$self;
    my %info = %$value;
    %$value = ();
    my $association = $entry->auto_type->{associations}[$index] = {
        window              => $info{window},
        keystroke_sequence  => $info{keys},
    };
    return $self->_tie($value, 'Association', $association);
}

sub STORESIZE {
    my ($self, $count) = @_;
    my ($entry) = @$self;
    splice @{$entry->auto_type->{associations}}, $count;
}

sub EXISTS {
    my ($self, $index) = @_;
    my ($entry) = @$self;
    return exists $entry->auto_type->{associations}[$index];
}

sub DELETE {
    my ($self, $index) = @_;
    my ($entry) = @$self;
    delete $entry->auto_type->{associations}[$index];
}

1;
