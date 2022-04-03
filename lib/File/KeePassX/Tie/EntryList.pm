package File::KeePassX::Tie::EntryList;
# ABSTRACT: INTERNAL ONLY, nothing to see here

use warnings;
use strict;

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
    my $entry = ($thing->$method || [])->[$index] or return;
    return $k->_tie('File::KeePassX::Tie::Entry', $k->kdbx->_entry($entry));
}

sub FETCHSIZE {
    my ($self) = @_;
    my ($thing, $method) = @$self;
    return scalar @{$thing->$method || []};
}

# sub STORE { ... }       # mandatory if elements writeable
# sub STORESIZE { ... }   # mandatory if elements can be added/deleted
# sub EXISTS { ... }      # mandatory if exists() expected to work
# sub DELETE { ... }      # mandatory if delete() expected to work

1;
