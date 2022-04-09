package File::KeePassX::Tie::Group;
# ABSTRACT: Database group

use warnings;
use strict;

use parent 'File::KeePassX::Tie::Hash';

our $VERSION = '999.999'; # VERSION

my %GET = (
    accessed            => sub { File::KeePassX::_decode_datetime($_[0]->last_access_time) },
    usage_count         => sub { $_[0]->usage_count },
    expires_enabled     => sub { $_[0]->expires ? 1 : 0 },
    created             => sub { File::KeePassX::_decode_datetime($_[0]->creation_time) },
    expires             => sub { File::KeePassX::_decode_datetime($_[0]->expiry_time) },
    modified            => sub { File::KeePassX::_decode_datetime($_[0]->last_modification_time) },
    location_changed    => sub { File::KeePassX::_decode_datetime($_[0]->location_changed) },
    level               => sub { $_[0]->level },
    notes               => sub { $_[0]->notes },
    id                  => sub { $_[0]->uuid },
    expanded            => sub { $_[0]->is_expanded ? 1 : 0 },
    icon                => sub { $_[0]->icon_id + 0 },
    title               => sub { $_[0]->name },
    auto_type_default   => sub { $_[0]->default_auto_type_sequence },
    auto_type_enabled   => sub { File::KeePassX::_decode_tristate($_[0]->enable_auto_type) },
    enable_searching    => sub { File::KeePassX::_decode_tristate($_[0]->enable_searching) },
    groups              => sub { $_[-1]->_tie([], 'GroupList', $_[0]) },
    entries             => sub { $_[-1]->_tie([], 'EntryList', $_[0], 'entries') },
);
my %SET = (
    accessed            => sub { $_[0]->last_access_time(File::KeePassX::_encode_datetime($_)) },
    usage_count         => sub { $_[0]->usage_count($_) },
    expires_enabled     => sub { $_[0]->expires($_) },
    created             => sub { $_[0]->creation_time(File::KeePassX::_encode_datetime($_)) },
    expires             => sub { $_[0]->expiry_time(File::KeePassX::_encode_datetime($_)) },
    modified            => sub { $_[0]->last_modification_time(File::KeePassX::_encode_datetime($_)) },
    location_changed    => sub { $_[0]->location_changed(File::KeePassX::_encode_datetime($_)) },
    level               => sub { }, # readonly
    notes               => sub { $_[0]->notes($_) },
    id                  => sub { $_[0]->uuid(File::KeePassX::_encode_uuid($_)) },
    expanded            => sub { $_[0]->is_expanded($_) },
    icon                => sub { $_[0]->icon_id($_) },
    title               => sub { $_[0]->name($_) },
    auto_type_default   => sub { $_[0]->default_auto_type_sequence($_) },
    auto_type_enabled   => sub { $_[0]->enable_auto_type(File::KeePassX::_encode_tristate($_)) },
    enable_searching    => sub { $_[0]->enable_searching(File::KeePassX::_encode_tristate($_)) },
    groups              => sub { }, # TODO - Replace all subgroups
    entries             => sub { }, # TODO - Replace all entries
);

sub getters { \%GET }
sub setters { \%SET }

1;
