package File::KeePassX::Tie::Protected;
# ABSTRACT: Entry memory protection flags

use warnings;
use strict;

use boolean;
use namespace::clean;

use parent 'File::KeePassX::Tie::Hash';

our $VERSION = '999.999'; # VERSION

my %GET = (
    comment     => sub { $_[0]->string('Notes')     ->{protect} ? 1 : 0 },
    password    => sub { $_[0]->string('Password')  ->{protect} ? 1 : 0 },
    title       => sub { $_[0]->string('Title')     ->{protect} ? 1 : 0 },
    url         => sub { $_[0]->string('URL')       ->{protect} ? 1 : 0 },
    username    => sub { $_[0]->string('UserName')  ->{protect} ? 1 : 0 },
);
my %SET = (
    comment     => sub { $_[0]->string('Notes')     ->{protect} = boolean($_) },
    password    => sub { $_[0]->string('Password')  ->{protect} = boolean($_) },
    title       => sub { $_[0]->string('Title')     ->{protect} = boolean($_) },
    url         => sub { $_[0]->string('URL')       ->{protect} = boolean($_) },
    username    => sub { $_[0]->string('UserName')  ->{protect} = boolean($_) },
);

sub getters { \%GET }
sub setters { \%SET }
sub default_getter { my $key = $_[1]; sub { $_[0]->string($key)->{protect} ? 1 : 0 } }
sub default_setter { my $key = $_[1]; sub { $_[0]->string($key)->{protect} = boolean($_) } }

sub keys {
    my $self = shift;
    my ($entry) = @$self;
    my @keys;
    while (my ($key, $string) = each %{$entry->strings}) {
        $key = 'comment' if $key eq 'Notes';
        $key = lc($key) if $key =~ /^(?:Password|Title|URL|UserName)$/;
        push @keys, $key if $string->{protect};
    }
    return \@keys;
}

1;
