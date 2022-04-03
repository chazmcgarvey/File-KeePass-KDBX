package File::KeePassX::Tie::Group;
# ABSTRACT: INTERNAL ONLY, nothing to see here

use warnings;
use strict;

use Crypt::Digest qw(digest_data);
use Scalar::Util qw(looks_like_number);
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
    level               => sub { $_[0]->level },
    notes               => sub { $_[0]->notes },
    id                  => sub { $_[0]->uuid },
    expanded            => sub { $_[0]->is_expanded },
    icon                => sub { $_[0]->icon_id + 0 },
    title               => sub { $_[0]->name },
    auto_type_default   => sub { $_[0]->default_auto_type_sequence },
    auto_type_enabled   => sub { _encode_trinary($_[0]->enable_auto_type) },
    enable_searching    => sub { _encode_trinary($_[0]->enable_searching) },
    groups              => sub { $_[-1]->_tie('File::KeePassX::Tie::GroupList', $_[0]) },
    entries             => sub { $_[-1]->_tie('File::KeePassX::Tie::EntryList', $_[0], 'entries') },
);
my %SET = (
    accessed            => sub { $_[0]->last_access_time(_decode_datetime($_)) },
    usage_count         => sub { $_[0]->usage_count($_) },
    expires_enabled     => sub { $_[0]->expires(boolean($_)) },
    created             => sub { $_[0]->creation_time(_decode_datetime($_)) },
    expires             => sub { $_[0]->expiry_time(_decode_datetime($_)) },
    modified            => sub { $_[0]->last_modification_time(_decode_datetime($_)) },
    location_changed    => sub { $_[0]->location_changed(_decode_datetime($_)) },
    level               => sub { }, # TODO readonly
    notes               => sub { $_[0]->notes($_) },
    id                  => sub { $_[0]->uuid(_decode_uuid($_)) },
    expanded            => sub { $_[0]->is_expanded($_) },
    icon                => sub { $_[0]->icon_id($_) },
    title               => sub { $_[0]->name($_) },
    auto_type_default   => sub { $_[0]->default_auto_type_sequence($_) },
    auto_type_enabled   => sub { $_[0]->enable_auto_type(_decode_tristate($_)) },
    enable_searching    => sub { $_[0]->enable_searching(_decode_tristate($_)) },
    groups              => sub { }, # TODO
    entries             => sub { }, # TODO
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
    # return digest_data('MD5', $_) if length($_) != 16;
    # Group IDs in KDB files are 32-bit integers
    return sprintf('%016x', $_) if length($_) != 16 && looks_like_number($_);
    return $_;
}

sub _encode_boolean {
    local $_ = shift;
    return $_ ? 1 : 0;
}

sub _encode_trinary {
    local $_ = shift // return;
    return $_ ? 1 : 0;
}

sub _decode_tristate {
    local $_ = shift // return;
    return boolean($_);
}

1;
