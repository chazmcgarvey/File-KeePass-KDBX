package File::KeePassX::Tie::Entry;
# ABSTRACT: INTERNAL ONLY, nothing to see here

use warnings;
use strict;

use Crypt::Digest;
use Time::Piece;
use boolean;
use namespace::clean;

use parent 'File::KeePassX::Tie::Hash';

our $VERSION = '999.999'; # VERSION

my %GET = (
    accessed            => sub { _encode_datetime($_[0]->last_access_time) },
    usage_count         => sub { $_[0]->usage_count },
    expires_enabled     => sub { _encode_boolean($_[0]->expires) },
    created             => sub { _encode_datetime($_[0]->creation_time) },
    expires             => sub { _encode_datetime($_[0]->expiry_time) },
    modified            => sub { _encode_datetime($_[0]->last_modification_time) },
    location_changed    => sub { _encode_datetime($_[0]->location_changed) },
    auto_type_munge     => sub { _encode_boolean($_[0]->auto_type->{data_transfer_obfuscation}) },
    auto_type_enabled   => sub { _encode_boolean($_[0]->auto_type->{enabled}) },
    auto_type           => sub { $_[-1]->_tie('File::KeePassX::Tie::AssociationList', $_[0]) },
    comment             => sub { $_[0]->notes },
    username            => sub { $_[0]->username },
    password            => sub { $_[0]->password },
    url                 => sub { $_[0]->url },
    title               => sub { $_[0]->title },
    protected           => sub { $_[-1]->_tie('File::KeePassX::Tie::Protected', $_[0]) },
    override_url        => sub { $_[0]->override_url },
    tags                => sub { $_[0]->tags },
    icon                => sub { $_[0]->icon_id + 0 },
    id                  => sub { $_[0]->uuid },
    foreground_color    => sub { $_[0]->foreground_color },
    background_color    => sub { $_[0]->background_color },
    history             => sub { $_[-1]->_tie('File::KeePassX::Tie::EntryList', $_[0], 'history') },
    strings             => sub { $_[-1]->_tie('File::KeePassX::Tie::Strings', $_[0]) },
    binary              => sub { $_[-1]->_tie('File::KeePassX::Tie::Binary', $_[0]) },
);
my %SET = (
    accessed            => sub { $_[0]->last_access_time(_decode_datetime($_)) },
    usage_count         => sub { $_[0]->usage_count($_) },
    expires_enabled     => sub { $_[0]->expires(boolean($_)) },
    created             => sub { $_[0]->creation_time(_decode_datetime($_)) },
    expires             => sub { $_[0]->expiry_time(_decode_datetime($_)) },
    modified            => sub { $_[0]->last_modification_time(_decode_datetime($_)) },
    location_changed    => sub { $_[0]->location_changed(_decode_datetime($_)) },
    override_url        => sub { $_[0]->override_url($_) },
    auto_type_munge     => sub { $_[0]->auto_type->{data_transfer_obfuscation} = boolean($_) },
    auto_type           => sub { }, # TODO
    auto_type_enabled   => sub { $_[0]->auto_type->{enabled} = boolean($_) },
    comment             => sub { $_[0]->notes($_) },
    tags                => sub { $_[0]->tags($_) },
    protected           => sub { }, # TODO
    title               => sub { $_[0]->title($_) },
    icon                => sub { $_[0]->icon_id($_) },
    id                  => sub { $_[0]->uuid(_decode_uuid($_)) },
    foreground_color    => sub { $_[0]->foreground_color($_) },
    background_color    => sub { $_[0]->background_color($_) },
    url                 => sub { $_[0]->url($_) },
    username            => sub { $_[0]->username($_) },
    password            => sub { $_[0]->password($_) },
    history             => sub { }, # TODO
    strings             => sub { }, # TODO
    binary              => sub { }, # TODO
);

sub getters { \%GET }
sub setters { \%SET }

sub _decode_datetime {
    local $_ = shift;
    return Time::Piece->strptime($_, '%Y-%m-%d %H:%M:%S');
}

sub _encode_datetime {
    local $_ = shift;
    return $_->strftime('%Y-%m-%d %H:%M:%S');
}

sub _decode_uuid {
    local $_ = shift // return;
    return digest_data('MD5', $_) if length($_) != 16;
    return $_;
}

sub _encode_boolean {
    local $_ = shift;
    return $_ ? 1 : 0;
}

1;
