package File::KeePassX::Tie::Binary;
# ABSTRACT: Entry binary

use warnings;
use strict;

use parent 'File::KeePassX::Tie::Hash';

our $VERSION = '999.999'; # VERSION

sub keys {
    my $self = shift;
    my ($entry) = @$self;
    return [keys %{$entry->binaries}];
}

sub default_getter { my $key = $_[1]; sub { $_[0]->binary_value($key) } }
sub default_setter { my $key = $_[1]; sub { $_[0]->binary_value($key, $_) } }

1;
