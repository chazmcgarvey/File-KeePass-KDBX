package File::KeePassX::Tie::Strings;
# ABSTRACT: INTERNAL ONLY, nothing to see here

use warnings;
use strict;

use parent 'File::KeePassX::Tie::Hash';

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
