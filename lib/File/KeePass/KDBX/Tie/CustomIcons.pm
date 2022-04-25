package File::KeePass::KDBX::Tie::CustomIcons;
# ABSTRACT: Database custom icons

use warnings;
use strict;

use parent 'File::KeePass::KDBX::Tie::Hash';

our $VERSION = '999.999'; # VERSION

sub keys {
    my $self = shift;
    my ($kdbx) = @$self;
    return [map { $_->{uuid} } @{$kdbx->custom_icons}];
}

sub default_getter { my $uuid = $_[1]; sub { $_[0]->custom_icon($uuid)->{data} } }
sub default_setter { my $uuid = $_[1]; sub { $_[0]->custom_icon($uuid, $_) } }

1;
