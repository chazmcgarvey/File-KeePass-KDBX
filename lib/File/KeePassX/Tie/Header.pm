package File::KeePassX::Tie::Header;
# ABSTRACT: Database headers

use warnings;
use strict;

use File::KDBX::Constants qw(:magic :version :cipher :random_stream);
use File::KDBX::Util qw(snakify);
use File::KeePassX;
use Time::Piece;
use namespace::clean;

use parent 'File::KeePassX::Tie::Hash';

our $VERSION = '999.999'; # VERSION

my @META_FIELDS = qw(
    Generator
    HeaderHash
    DatabaseName
    DatabaseNameChanged
    DatabaseDescription
    DatabaseDescriptionChanged
    DefaultUserName
    DefaultUserNameChanged
    MaintenanceHistoryDays
    Color
    MasterKeyChanged
    MasterKeyChangeRec
    MasterKeyChangeForce
    RecycleBinUUID
    RecycleBinChanged
    EntryTemplatesGroup
    EntryTemplatesGroupChanged
    LastSelectedGroup
    LastTopVisibleGroup
    HistoryMaxItems
    HistoryMaxSize
    SettingsChanged
    RecycleBinEnabled
);
# MemoryProtection - flattened in KeePass
# Binaries - distributed to entries in KeePass
# CustomIcons - handled by File::KeePassX::Tie::CustomIcons
# CustomData - handled by File::KeePassX::Tie::CustomData

my %GET = (
    sig1        => sub { $_[0]->sig1 },
    sig2        => sub { $_[0]->sig2 },
    ver         => sub { $_[0]->version },
    version     => sub { $_[0]->sig2 == KDBX_SIG2_1 ? 1 : 2 },
    comment     => sub { $_[0]->comment },
    enc_iv      => sub { $_[0]->encryption_iv },
    enc_type    => sub {
        my %enc_type = (
            CIPHER_UUID_AES128()    => 'rijndael',
            CIPHER_UUID_AES256()    => 'rijndael',
            CIPHER_UUID_CHACHA20()  => 'chacha20',
            CIPHER_UUID_SALSA20()   => 'salsa20',
            CIPHER_UUID_SERPENT()   => 'serpent',
            CIPHER_UUID_TWOFISH()   => 'twofish',
        );
        $enc_type{$_[0]->cipher_id || ''} || 'rijndael';
    },
    flags       => sub {
        my $cipher_id = $_[0]->cipher_id || '';
        $cipher_id eq CIPHER_UUID_AES128 || $cipher_id eq CIPHER_UUID_AES256
            ? 2
            : $cipher_id eq CIPHER_UUID_TWOFISH
                ? 8
                : undef;
    },
    checksum    => sub { undef },
    n_entries   => sub { scalar @{$_[0]->all_entries} },
    n_groups    => sub { scalar @{$_[0]->all_groups} - ($_[0]->_is_implicit_root ? 1 : 0) },
    header_size => sub { undef },   # not available from KDBX
    raw         => sub { undef },   # not available from KDBX
    rounds      => sub { $_[0]->transform_rounds },
    seed_key    => sub { $_[0]->transform_seed },
    seed_rand   => sub { $_[0]->master_seed },
    cipher      => sub {
        my %cipher = (
            CIPHER_UUID_AES128()    => 'aes',
            CIPHER_UUID_AES256()    => 'aes',
            CIPHER_UUID_CHACHA20()  => 'chacha20',
            CIPHER_UUID_SALSA20()   => 'salsa20',
            CIPHER_UUID_SERPENT()   => 'serpent',
            CIPHER_UUID_TWOFISH()   => 'twofish',
        );
        $cipher{$_[0]->cipher_id || ''} || 'aes';
    },
    compression => sub { $_[0]->compression_flags },
    protected_stream => sub {
        my %protected_stream = (
            STREAM_ID_RC4()         => 'rc4',
            STREAM_ID_SALSA20()     => 'salsa20',
            STREAM_ID_CHACHA20()    => 'chacha20',
        );
        $protected_stream{$_[0]->inner_random_stream_id} || 'unknown',
    },
    protected_stream_key => sub { $_[0]->inner_random_stream_key },
    start_bytes => sub { $_[0]->stream_start_bytes },
    0           => sub { "\r\n\r\n" },
    # META
    protect_notes       => sub { $_[0]->protect_notes    ? 1 : 0 },
    protect_password    => sub { $_[0]->protect_password ? 1 : 0 },
    protect_title       => sub { $_[0]->protect_title    ? 1 : 0 },
    protect_url         => sub { $_[0]->protect_url      ? 1 : 0 },
    protect_username    => sub { $_[0]->protect_username ? 1 : 0 },
    recycle_bin_enabled => sub { $_[0]->recycle_bin_enabled ? 1 : 0 },
    custom_data         => sub { $_[-1]->_tie({}, 'CustomData', $_[0]) },
    custom_icons        => sub { $_[-1]->_tie({}, 'CustomIcons', $_[0]) },
);
for my $meta_key (@META_FIELDS) {
    my $key = snakify($meta_key);
    next if $GET{$key};
    if ($key =~ /_changed$/) {
        $GET{$key} = sub { File::KeePassX::_decode_datetime($_[0]->meta->{$key}) };
    }
    else {
        $GET{$key} = sub { $_[0]->meta->{$key} };
    }
}

my %SET = (
    sig1        => sub { $_[0]->sig1($_) },
    sig2        => sub { $_[0]->sig2($_) },
    ver         => sub { $_[0]->version($_) },
    version     => sub { $_[0]->sig2($_ == 1 ? KDBX_SIG2_1 : $_ == 2 ? KDBX_SIG2_2 : undef) },
    comment     => sub { $_[0]->comment($_) },
    enc_iv      => sub { $_[0]->encryption_iv($_) },
    enc_type    => sub {
        my %enc_type = (
            chacha20    => CIPHER_UUID_CHACHA20,
            rijndael    => CIPHER_UUID_AES256,
            salsa20     => CIPHER_UUID_SALSA20,
            serpent     => CIPHER_UUID_SERPENT,
            twofish     => CIPHER_UUID_TWOFISH,
        );
        $_[0]->cipher_id($enc_type{$_} || CIPHER_UUID_AES256);
    },
    flags       => sub {
        my %cipher = (
            2   => CIPHER_UUID_AES256,
            8   => CIPHER_UUID_TWOFISH,
        );
        $_[0]->cipher_id($cipher{$_}) if $cipher{$_};
    },
    checksum    => sub { }, # readonly
    n_entries   => sub { }, # readonly
    n_groups    => sub { }, # readonly
    header_size => sub { }, # not available
    raw         => sub { }, # not available
    rounds      => sub { $_[0]->transform_rounds($_) },
    seed_key    => sub { $_[0]->transform_seed($_) },
    seed_rand   => sub { $_[0]->master_seed($_) },
    cipher      => sub {
        my %cipher = (
            aes         => CIPHER_UUID_AES256,
            chacha20    => CIPHER_UUID_CHACHA20,
            salsa20     => CIPHER_UUID_SALSA20,
            serpent     => CIPHER_UUID_SERPENT,
            twofish     => CIPHER_UUID_TWOFISH,
        );
        $_[0]->cipher_id($cipher{$_} || CIPHER_UUID_AES256);
    },
    compression => sub { $_[0]->compression_flags($_) },
    protected_stream => sub {
        my %protected_stream = (
            rc4         => STREAM_ID_RC4,
            salsa20     => STREAM_ID_SALSA20,
            chacha20    => STREAM_ID_CHACHA20,
        );
        my $default_id = $_[0]->version < KDBX_VERSION_4_0 ? STREAM_ID_SALSA20 : STREAM_ID_CHACHA20;
        my $id = $protected_stream{$_} || $default_id;
        $_[0]->inner_random_stream_id($id);
    },
    protected_stream_key => sub { $_[0]->inner_random_stream_key($_) },
    start_bytes => sub { $_[0]->stream_start_bytes($_) },
    0           => sub { }, # readonly
    # META
    protect_notes       => sub { $_[0]->protect_notes($_) },
    protect_password    => sub { $_[0]->protect_password($_) },
    protect_title       => sub { $_[0]->protect_title($_) },
    protect_url         => sub { $_[0]->protect_url($_) },
    protect_username    => sub { $_[0]->protect_username($_) },
    recycle_bin_enabled => sub { $_[0]->recycle_bin_enabled($_) },
    custom_data         => sub { }, # TODO - Replace all custom data
    custom_icons        => sub { }, # TODO - Replace all icons
);
for my $meta_key (@META_FIELDS) {
    my $key = snakify($meta_key);
    next if $SET{$key};
    if ($key =~ /_changed$/) {
        $SET{$key} = sub { $_[0]->meta->{$key} = File::KeePassX::_encode_datetime($_) };
    }
    else {
        $SET{$key} = sub { $_[0]->meta->{$key} = $_ };
    }
}

sub getters { \%GET }
sub setters { \%SET }

1;
