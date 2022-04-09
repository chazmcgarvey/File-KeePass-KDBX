package File::KeePassX::Tie::Association;
# ABSTRACT: Auto-type window association

use warnings;
use strict;

use parent 'File::KeePassX::Tie::Hash';

our $VERSION = '999.999'; # VERSION

my %GET = (
    window  => sub { $_[0]->{window} },
    keys    => sub { $_[0]->{keystroke_sequence} },
);
my %SET = (
    window  => sub { $_[0]->{window} = $_ },
    keys    => sub { $_[0]->{keystroke_sequence} = $_ },
);

sub getters { \%GET }
sub setters { \%SET }

1;
