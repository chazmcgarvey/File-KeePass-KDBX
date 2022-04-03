package File::KeePassX::Tie::Header;
# ABSTRACT: INTERNAL ONLY, nothing to see here

use warnings;
use strict;

use File::KDBX::Constants qw(:magic :version :header :inner_header :cipher :random_stream);
use File::KDBX::Util qw(snakify);
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
);
# RecycleBinEnabled - boolean handled explicitly below
# MemoryProtection - flattened in KeePass
# Binaries - distributed to entries in KeePass
# CustomIcons - handled by File::KeePassX::Tie::CustomIcons
# CustomData - handled by File::KeePassX::Tie::CustomData

my %GET = (
    sig1        => sub { $_[0]->sig1 },
    sig2        => sub { $_[0]->sig2 },
    ver         => sub { $_[0]->version },
    version     => sub { $_[0]->sig2 == KDBX_SIG2_1 ? 1 : 2 },
    comment     => sub { $_[0]->headers->{+HEADER_COMMENT} },
    enc_iv      => sub { $_[0]->headers->{+HEADER_ENCRYPTION_IV} },
    enc_type    => sub {
        my %enc_type = (
            CIPHER_UUID_AES128()    => 'rijndael',
            CIPHER_UUID_AES256()    => 'rijndael',
            CIPHER_UUID_CHACHA20()  => 'chacha20',
            CIPHER_UUID_SALSA20()   => 'salsa20',
            CIPHER_UUID_SERPENT()   => 'serpent',
            CIPHER_UUID_TWOFISH()   => 'twofish',
        );
        $enc_type{$_[0]->headers->{+HEADER_CIPHER_ID} || ''} || 'rijndael';
    },
    flags       => sub {
        my $cipher_id = $_[0]->headers->{+HEADER_CIPHER_ID};
        $cipher_id eq CIPHER_UUID_AES128 || $cipher_id eq CIPHER_UUID_AES256  ? 2
                                          : $cipher_id eq CIPHER_UUID_TWOFISH ? 8 : undef;
    },   # KeePass 1
    checksum    => sub { undef },   # KeePass 1
    n_entries   => sub { scalar @{$_[0]->all_entries} },    # KeePass 1
    n_groups    => sub { scalar @{$_[0]->all_groups} },     # KeePass 1
    header_size => sub { undef },   # FIXME not available from KDBX - could be recalculated
    raw         => sub { undef },   # FIXME not available from KDBX - could be recalculated
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
        $cipher{$_[0]->headers->{+HEADER_CIPHER_ID} || ''} || 'aes';
    },
    compression => sub { $_[0]->headers->{+HEADER_COMPRESSION_FLAGS} },
    protected_stream => sub {
        my %protected_stream = (
            STREAM_ID_RC4()         => 'rc4',
            STREAM_ID_SALSA20()     => 'salsa20',
            STREAM_ID_CHACHA20()    => 'chacha20',
        );
        $protected_stream{$_[0]->inner_random_stream_id} || 'unknown',
    },
    protected_stream_key => sub { $_[0]->headers->{+HEADER_INNER_RANDOM_STREAM_KEY}
                        // $_[0]->inner_headers->{+INNER_HEADER_INNER_RANDOM_STREAM_KEY} }, # FIXME
    start_bytes => sub { $_[0]->headers->{+HEADER_STREAM_START_BYTES} },
    0           => sub { "\r\n\r\n" },
    # META
    protect_notes       => sub { $_[0]->meta->{memory_protection}{protect_notes} ? 1 : 0 },
    protect_password    => sub { $_[0]->meta->{memory_protection}{protect_password} ? 1 : 0 },
    protect_title       => sub { $_[0]->meta->{memory_protection}{protect_title} ? 1 : 0 },
    protect_url         => sub { $_[0]->meta->{memory_protection}{protect_url} ? 1 : 0 },
    protect_username    => sub { $_[0]->meta->{memory_protection}{protect_username} ? 1 : 0 },
    recycle_bin_enabled => sub { $_[0]->meta->{recycle_bin_enabled} ? 1 : 0 },
    custom_data         => sub { $_[-1]->_tie('File::KeePassX::Tie::CustomData', $_[0]) },
    custom_icons        => sub { $_[-1]->_tie('File::KeePassX::Tie::CustomIcons', $_[0]) },
);
for my $meta_key (@META_FIELDS) {
    my $key = snakify($meta_key);
    if ($key =~ /_changed$/) {
        $GET{$key} = sub { _encode_datetime($_[0]->meta->{$key}) };
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
    comment     => sub { $_[0]->headers->{+HEADER_COMMENT} = $_ },
    enc_iv      => sub { $_[0]->headers->{+HEADER_ENCRYPTION_IV} = $_ },
    enc_type    => sub {
        my %enc_type = (
            chacha20    => CIPHER_UUID_CHACHA20,
            rijndael    => CIPHER_UUID_AES256,
            salsa20     => CIPHER_UUID_SALSA20,
            serpent     => CIPHER_UUID_SERPENT,
            twofish     => CIPHER_UUID_TWOFISH,
        );
        $_[0]->headers->{+HEADER_CIPHER_ID} = $enc_type{$_} || CIPHER_UUID_AES256;
    },
    flags       => sub { }, # TODO KeePass v1
    checksum    => sub { }, # TODO KeePass v1
    n_entries   => sub { }, # readonly TODO
    n_groups    => sub { }, # readonly TODO
    header_size => sub { }, # not available
    raw         => sub { }, # not available KeePass v2
    rounds      => sub {
        $_[0]->headers->{+HEADER_TRANSFORM_ROUNDS} = $_;   # TODO - really set both?
        $_[0]->headers->{+HEADER_KDF_PARAMETERS}->{R} = $_; # FIXME
    },
    seed_key    => sub { $_[0]->headers->{+HEADER_TRANSFORM_SEED} = $_ },
    seed_rand   => sub { $_[0]->headers->{+HEADER_MASTER_SEED} = $_ },
    cipher      => sub {
        my %cipher = (
            aes         => CIPHER_UUID_AES256,
            chacha20    => CIPHER_UUID_CHACHA20,
            salsa20     => CIPHER_UUID_SALSA20,
            serpent     => CIPHER_UUID_SERPENT,
            twofish     => CIPHER_UUID_TWOFISH,
        );
        $_[0]->headers->{+HEADER_CIPHER_ID} = $cipher{$_} || CIPHER_UUID_AES256;
    },
    compression => sub { $_[0]->headers->{+HEADER_COMPRESSION_FLAGS} = $_ },
    protected_stream => sub {
        my %protected_stream = (
            rc4         => STREAM_ID_RC4,
            salsa20     => STREAM_ID_SALSA20,
            chacha20    => STREAM_ID_CHACHA20,
        );
        my $default_id = $_[0]->version < KDBX_VERSION_4_0 ? STREAM_ID_SALSA20 : STREAM_ID_CHACHA20;
        my $id = $protected_stream{$_} || $default_id;
        # TODO - really set both?
        $_[0]->headers->{+HEADER_INNER_RANDOM_STREAM_ID} = $id;
        $_[0]->inner_headers->{+INNER_HEADER_INNER_RANDOM_STREAM_ID} = $id;
    },
    protected_stream_key => sub {
        $_[0]->headers->{+HEADER_INNER_RANDOM_STREAM_ID} = $_; # TODO - really set both?
        $_[0]->inner_headers->{+INNER_HEADER_INNER_RANDOM_STREAM_ID} = $_;
    },
    start_bytes => sub {
        $_[0]->headers->{+HEADER_STREAM_START_BYTES} = $_;
        $_[0]->meta->{start_bytes} = $_;    # TODO - really set both?
    },
    0           => sub { }, # readonly
    # META
    protect_notes       => sub { $_[0]->meta->{memory_protection}{protect_notes} = boolean($_) },
    protect_password    => sub { $_[0]->meta->{memory_protection}{protect_password} = boolean($_) },
    protect_title       => sub { $_[0]->meta->{memory_protection}{protect_title} = boolean($_) },
    protect_url         => sub { $_[0]->meta->{memory_protection}{protect_url} = boolean($_) },
    protect_username    => sub { $_[0]->meta->{memory_protection}{protect_username} = boolean($_) },
    recycle_bin_enabled => sub { $_[0]->meta->{recycle_bin_enabled} = boolean($_) },
    custom_data         => sub { }, # TODO
    custom_icons        => sub { }, # TODO
);
for my $meta_key (@META_FIELDS) {
    my $key = snakify($meta_key);
    if ($key =~ /_changed$/) {
        $SET{$key} = sub { $_[0]->meta->{$key} = _decode_datetime($_) };
    }
    else {
        $SET{$key} = sub { $_[0]->meta->{$key} = $_ };
    }
}

sub getters { \%GET }
sub setters { \%SET }

sub _decode_datetime {
    local $_ = shift or return;
    return Time::Piece->strptime($_, '%Y-%m-%d %H:%M:%S');
}

sub _encode_datetime {
    local $_ = shift or return;
    return $_->strftime('%Y-%m-%d %H:%M:%S');
}

1;
