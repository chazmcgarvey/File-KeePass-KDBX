package File::KeePass::KDBX::Tie::CustomData;
# ABSTRACT: Database custom data

use warnings;
use strict;

use parent 'File::KeePass::KDBX::Tie::Hash';

our $VERSION = '999.999'; # VERSION

sub keys {
    my $self = shift;
    my ($kdbx) = @$self;
    return [keys %{$kdbx->meta->{custom_data} || {}}];
}

sub default_getter { my $key = $_[1]; sub { $_[0]->meta->{custom_data}{$key}{value} } }
sub default_setter { my $key = $_[1]; sub { $_[0]->meta->{custom_data}{$key}{value} = $_ } }

1;
