package File::KeePass::KDBX::Tie::Strings;
# ABSTRACT: Entry strings

use warnings;
use strict;

use parent 'File::KeePass::KDBX::Tie::Hash';

our $VERSION = '999.999'; # VERSION

my %STANDARD = map { $_ => 1 } qw(Notes Password Title UserName URL);

sub keys {
    my $self = shift;
    my ($entry) = @$self;
    return [grep { !$STANDARD{$_} } keys %{$entry->strings}];
}

sub default_getter { my $key = $_[1]; sub { $_[0]->string_value($key) } }
sub default_setter { my $key = $_[1]; sub { $_[0]->string_value($key, $_) } }

1;
