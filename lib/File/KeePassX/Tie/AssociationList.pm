package File::KeePassX::Tie::AssociationList;
# ABSTRACT: INTERNAL ONLY, nothing to see here

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
    return $k->_tie('File::KeePassX::Tie::Association', $association);
}

sub FETCHSIZE {
    my ($self) = @_;
    my ($entry) = @$self;
    return scalar @{$entry->auto_type->{associations} || []};
}

# sub STORE { ... }       # mandatory if elements writeable
# sub STORESIZE { ... }   # mandatory if elements can be added/deleted
# sub EXISTS { ... }      # mandatory if exists() expected to work
# sub DELETE { ... }      # mandatory if delete() expected to work

1;
