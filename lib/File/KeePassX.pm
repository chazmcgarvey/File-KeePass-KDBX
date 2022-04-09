package File::KeePassX;
# ABSTRACT: Read and write KDBX files (File::KeePass compatibility shim)

use utf8;
use warnings;
use strict;

use Crypt::PRNG qw(irand);
use Crypt::Misc 0.029 qw(decode_b64 encode_b64);
use Devel::GlobalDestruction;
use File::KDBX::Constants qw(:header :magic :version);
use File::KDBX::Loader::KDB;
use File::KDBX::Util qw(generate_uuid load_optional);
use Module::Load;
use Scalar::Util qw(blessed looks_like_number refaddr weaken);
use boolean;
use namespace::clean;

our $VERSION = '999.999'; # VERSION

my %KDBX;
my %TIED;

BEGIN {
    our @ISA;
    @ISA = qw(File::KeePass) if $INC{'File/KeePass.pm'};
}

=method new

    $k = File::KeePassX->new(%attributes);

    $k = File::KeePassX->new($legacy_keepass);

Construct a new KeePass 2 database.

=cut

sub new {
    my $class = shift;

    # copy constructor
    return $_[0]->clone if @_ == 1 && (blessed $_[0] // '') eq __PACKAGE__;

    if (@_ == 1 && blessed $_[0] && $_[0]->isa('File::KeePass')) {
        my $kdbx = File::KDBX::Loader::KDB::convert_keepass_to_kdbx($_[0]);
        my $self = bless {}, $class;
        $self->kdbx($kdbx);
        return $self;
    }

    if (@_ == 1 && blessed $_[0] && $_[0]->isa('File::KDBX')) {
        my $self = bless {}, $class;
        $self->kdbx($_[0]);
        return $self;
    }

    my $args = ref $_[0] ? {%{$_[0]}} : {@_};
    my $self = bless $args, $class;
    exists $args->{kdbx} and $self->kdbx(delete $args->{kdbx});
    return $self;
}

sub DESTROY { !in_global_destruction and $_[0]->clear }

=method clone

    $k_copy = $k->clone;
    OR
    $k_copy = File::KeePassX->new($k);

Make a copy.

=cut

sub clone {
    my $self = shift;
    require Storable;
    return Storable::dclone($self);
}

sub STORABLE_freeze {
    my $self = shift;
    return '', $KDBX{refaddr($self)};
}

sub STORABLE_thaw {
    my $self    = shift;
    my $cloning = shift;
    my $empty   = shift;
    my $kdbx    = shift;

    $self->kdbx($kdbx) if $kdbx;
}

=method clear

    $k->clear;

Reset the database to a freshly initialized state.

See L<File::KeePass/clear>.

=cut

sub clear {
    my $self = shift;
    delete $KDBX{refaddr($self)};
    delete $TIED{refaddr($self)};
    delete @$self{qw(header groups)};
}

=attr kdbx

    $kdbx = $k->kdbx;
    $k->kdbx($kdbx);

Get or set the L<File::KDBX> instance. The C<File::KDBX> is the object that actually contains the database
data, so setting this will implicitly replace all of the data with data from the new database.

Getting the C<File::KDBX> associated with a C<File::KeePassX> grants you access to new functionality that
C<File::KeePassX> doesn't have any interface for, including:

=for :list
* KDBX4-exclusive data (e.g. KDF parameters and public custom data headers)
* L<File::KDBX/Placeholders>
* One-time passwords
* Search using "Simple Expressions"
* and more

=cut

sub kdbx {
    my $self = shift;
    $self = $self->new if !ref $self;
    if (@_) {
        $self->clear;
        $KDBX{refaddr($self)} = shift;
    }
    $KDBX{refaddr($self)} //= do {
        require File::KDBX;
        File::KDBX->new;
    };
}

=method load_db

    $k = $k->load_db($filepath, $key);
    $k = File::KeePassX->load_db($filepath, $key, \%args);

Load a database from a file. C<$key> is a master key, typically a password or passphrase and might also
include a keyfile path (e.g. C<[$password, $keyfile]>). C<%args> are the same as for L</new>.

See L<File::KeePass/load_db>.

=cut

sub load_db {
    my $self = shift;
    my $file = shift or die "Missing file\n";
    my $pass = shift or die "Missing pass\n";
    my $args = shift || {};

    open(my $fh, '<:raw', $file) or die "Could not open $file: $!\n";
    $self->_load($fh, $pass, $args);
}

=method parse_db

    $k = $k->parse_db($string, $key);
    $k = File::KeePassX->parse_db($string, $key, \%args);

Load a database from a string. C<$key> is a master key, typically a password or passphrase and might also
include a keyfile path (e.g. C<[$password, $keyfile]>). C<%args> are the same as for L</new>.


See L<File::KeePass/parse_db>.

=cut

sub parse_db {
    my ($self, $buf, $pass, $args) = @_;

    my $ref = ref $buf ? $buf : \$buf;

    open(my $fh, '<:raw', $ref) or die "Could not open buffer: $!\n";
    $self->_load($fh, $pass, $args);
}

sub _load {
    my ($self, $fh, $pass, $args) = @_;

    $self = $self->new($args) if !ref $self;

    my $unlock = defined $args->{auto_lock} ? !$args->{auto_lock} : !$self->auto_lock;

    $self->kdbx->load_handle($fh, $pass);
    $self->kdbx->unlock if $unlock;
    return $self;
}

=method parse_header

    \%head = $k->parse_header($string);

Parse only the header.

See L<File::KeePass/parse_header>.

=cut

sub parse_header {
    my ($self, $buf) = @_;

    open(my $fh, '<:raw', \$buf) or die "Could not open buffer: $!\n";

    # detect filetype and version
    my $loader = File::KDBX::Loader->new;
    my ($sig1, $sig2, $version) = $loader->read_magic_numbers($fh);

    if ($sig2 == KDBX_SIG2_1 || $version < KDBX_VERSION_2_0) {
        close($fh);

        load_optional('File::KeePass');
        return File::KeePass->parse_header($buf);
    }

    my %header_transform = (
        HEADER_COMMENT()                    => ['comment'],
        HEADER_CIPHER_ID()                  => ['cipher', sub { $self->_cipher_name($_[0]) }],
        HEADER_COMPRESSION_FLAGS()          => ['compression'],
        HEADER_MASTER_SEED()                => ['seed_rand'],
        HEADER_TRANSFORM_SEED()             => ['seed_key'],
        HEADER_TRANSFORM_ROUNDS()           => ['rounds'],
        HEADER_ENCRYPTION_IV()              => ['enc_iv'],
        HEADER_INNER_RANDOM_STREAM_KEY()    => ['protected_stream_key'],
        HEADER_STREAM_START_BYTES()         => ['start_bytes'],
        HEADER_INNER_RANDOM_STREAM_ID()     => ['protected_stream', sub { $self->_inner_random_stream_name($_[0]) }],
        HEADER_KDF_PARAMETERS()             => ['kdf_parameters'],
        HEADER_PUBLIC_CUSTOM_DATA()         => ['public_custom_data'],
    );

    my %head;

    while (my ($type, $val) = $loader->_read_header($fh)) {
        last if $type == HEADER_END;
        my ($name, $filter) = @{$header_transform{$type} || ["$type"]};
        $head{$name} = $filter ? $filter->($val) : $val;
    }

    return \%head;
}

=method save_db

    $k->save_db($filepath, $key);

Save the database to a file. C<$key> is a master key, typically a password or passphrase and might also
include a keyfile path (e.g. C<[$password, $keyfile]>).

See L<File::KeePass/save_db>.

=cut

sub save_db {
    my ($self, $file, $pass, $head) = @_;
    die "Missing file\n" if !$file;
    die "Missing pass\n" if !$pass;

    shift if @_ % 2 == 1;
    my %args = @_;

    local $self->kdbx->{headers} = $self->_gen_headers($head);

    $args{randomize_seeds} = 0 if $head && $head->{reuse_header};

    $self->kdbx->dump_file($file, $pass, %args);
    return 1;
}

=method gen_db

    $db_string = $k->gen_db($key);

Save the database to a string. C<$key> is a master key, typically a password or passphrase and might also
include a keyfile path (e.g. C<[$password, $keyfile]>).

See L<File::KeePass/gen_db>.

=cut

sub gen_db {
    my ($self, $pass, $head) = @_;
    die "Missing pass\n" if !$pass;

    shift if @_ % 2 == 1;
    my %args = @_;

    local $self->kdbx->{headers} = $self->_gen_headers($head);

    $args{randomize_seeds} = 0 if $head && $head->{reuse_header};

    my $dump = $self->kdbx->dump_string($pass, %args);
    return $$dump;
}

sub _gen_headers {
    my $self = shift;
    my $head = shift || {};

    my $v = $head->{'version'} || $self->header->{'version'};
    my $reuse = $head->{'reuse_header'}                        # explicit yes
                || (!exists($head->{'reuse_header'})           # not explicit no
                    && ($self->{'reuse_header'}                # explicit yes
                        || !exists($self->{'reuse_header'}))); # not explicit no
    if ($reuse) {
        ($head, my $args) = ($self->header || {}, $head);
        @$head{keys %$args} = values %$args;
    }
    $head->{'version'} = $v ||= $head->{'version'} || '1';
    delete @$head{qw(enc_iv seed_key seed_rand protected_stream_key start_bytes)} if $reuse && $reuse < 0;

    if ($head->{version} == 1) {
        $head->{enc_type} = 'rijndael';
        $head->{cipher} = 'aes';
    }

    my $temp_kdbx = File::KDBX::Loader::KDB::_convert_keepass_to_kdbx_headers($head, File::KDBX->new);
    return $temp_kdbx->headers;
}

=method header

    \%header = $k->header;

Get the database file headers and KDBX metadata.

See L<File::KeePass/header>.

=cut

sub header {
    my $self = shift;
    return if !exists $KDBX{refaddr($self)};
    $self->{header} //= $self->_tie({}, 'Header', $self->kdbx);
}

=method groups

    \@groups = $k->groups;

Get the groups and entries stored in a database. This is the same data that L<File::KDBX/groups> provides but
in a shape compatible with L<File::KeePass/groups>.

=cut

sub groups {
    my $self = shift;
    return if !exists $KDBX{refaddr($self)};
    $self->{groups} //= $self->_tie([], 'GroupList', $self->kdbx);
}

=method dump_groups

    $string = $k->dump_groups;
    $string = $k->dump_groups(\%query);

Get a string representation of the groups in the database.

See L<File::KeePass/dump_groups>.

=cut

# Copied from File::KeePass - thanks paul
sub dump_groups {
    my ($self, $args, $groups) = @_;
    my $t = '';
    my %gargs; for (keys %$args) { $gargs{$2} = $args->{$1} if /^(group_(.+))$/ };
    foreach my $g ($self->find_groups(\%gargs, $groups)) {
        my $indent = '    ' x $g->{'level'};
        $t .= $indent.($g->{'expanded'} ? '-' : '+')."  $g->{'title'} ($g->{'id'}) $g->{'created'}\n";
        local $g->{'groups'}; # don't recurse while looking for entries since we are already flat
        $t .= "$indent    > $_->{'title'}\t($_->{'id'}) $_->{'created'}\n" for $self->find_entries($args, [$g]);
    }
    return $t;
}

=method add_group

    $group = $k->add_group(\%group_info);

Add a new group.

See L<File::KeePass/add_group>.

=cut

sub add_group {
    my $self = shift;
    my $group = shift;

    my $parent = delete local $group->{group};
    $parent = $parent->{id} if ref $parent;

    $group->{expires} //= $self->default_exp;

    my $group_info = File::KDBX::Loader::KDB::_convert_keepass_to_kdbx_group($group);
    my $group_obj = $self->kdbx->add_group($group_info, parent => $parent);
    return $self->_tie({}, 'Group', $group_obj);
}

=method find_groups

    @groups = $k->find_groups(\%query);

Find groups.

See L<File::KeePass/find_groups>.

=cut

# Copied from File::KeePass - thanks paul
sub find_groups {
    my ($self, $args, $groups, $level) = @_;
    my @tests = $self->finder_tests($args);
    my @groups;
    my %uniq;
    my $container = $groups || $self->groups;
    for my $g (@$container) {
        $g->{'level'} = $level || 0;
        $g->{'title'} = '' if ! defined $g->{'title'};
        $g->{'icon'}  ||= 0;
        if ($self->{'force_v2_gid'}) {
            $g->{'id'} = $self->uuid($g->{'id'}, \%uniq);
        } else {
            $g->{'id'} = irand while !defined($g->{'id'}) || $uniq{$g->{'id'}}++; # the non-v2 gid is compatible with both v1 and our v2 implementation
        }

        if (!@tests || !grep{!$_->($g)} @tests) {
            push @groups, $g;
            push @{ $self->{'__group_groups'} }, $container if $self->{'__group_groups'};
        }
        push @groups, $self->find_groups($args, $g->{'groups'}, $g->{'level'} + 1) if $g->{'groups'};
    }
    return @groups;
}

=method find_group

    $group = $k->find_group(\%query);

Find one group. If the query matches more than one group, an exception is thrown. If there is no matching
group, C<undef> is returned

See L<File::KeePass/find_group>.

=cut

# Copied from File::KeePass - thanks paul
sub find_group {
    my $self = shift;
    local $self->{'__group_groups'} = [] if wantarray;
    my @g = $self->find_groups(@_);
    die "Found too many groups (@g)\n" if @g > 1;
    return wantarray ? ($g[0], $self->{'__group_groups'}->[0]) : $g[0];
}

=method delete_group

    $group = $k->delete_group(\%query);

Delete a group.

See L<File::KeePass/delete_group>.

=cut

sub delete_group {
    my $self = shift;
    my $group_info = shift;

    my $group = $self->find_group($group_info) or return;
    $group->{__object}->remove;
    return $group;
}

=method add_entry

    $entry = $k->add_entry(\%entry_info);

Add a new entry.

See L<File::KeePass/add_entry>.

=cut

sub add_entry {
    my $self = shift;
    my $entry = shift;

    my $parent = delete local $entry->{group};
    $parent = $parent->{id} if ref $parent;

    $entry->{expires} //= $self->default_exp;

    my $entry_info = File::KDBX::Loader::KDB::_convert_keepass_to_kdbx_entry($entry);
    if (!$parent && $self->kdbx->_is_implicit_root) {
        $parent = $self->kdbx->root->groups->[0];
    }
    my $entry_obj = $self->kdbx->add_entry($entry_info, parent => $parent);
    return $self->_tie({}, 'Entry', $entry_obj);
}

=method find_entries

    @entries = $k->find_entries(\%query);

Find entries.

See L<File::KeePass/find_entries>.

=cut

# Copied from File::KeePass - thanks paul
sub find_entries {
    my ($self, $args, $groups) = @_;
    local @{ $args }{'expires gt', 'active'} = ($self->now, undef) if $args->{'active'};
    my @tests = $self->finder_tests($args);
    my @entries;
    foreach my $g ($self->find_groups({}, $groups)) {
        foreach my $e (@{ $g->{'entries'} || [] }) {
            local $e->{'group_id'}    = $g->{'id'};
            local $e->{'group_title'} = $g->{'title'};
            if (!@tests || !grep{!$_->($e)} @tests) {
                push @entries, $e;
                push @{ $self->{'__entry_groups'} }, $g if $self->{'__entry_groups'};
            }
        }
    }
    return @entries;
}

=method find_entry

    $entry = $k->find_entry(\%query);

Find one entry. If the query matches more than one entry, an exception is thrown. If there is no matching
entry, C<undef> is returned

See L<File::KeePass/find_entry>.

=cut

# Copied from File::KeePass - thanks paul
sub find_entry {
    my $self = shift;
    local $self->{'__entry_groups'} = [] if wantarray;
    my @e = $self->find_entries(@_);
    die "Found too many entries (@e)\n" if @e > 1;
    return wantarray ? ($e[0], $self->{'__entry_groups'}->[0]) : $e[0];
}

=method delete_entry

    $entry = $k->delete_entry(\%query);

Delete an entry.

See L<File::KeePass/delete_entry>.

=cut

sub delete_entry {
    my $self = shift;
    my $entry_info = shift;

    my $entry = $self->find_entry($entry_info) or return;
    $entry->{__object}->remove;
    return $entry;
}

##############################################################################

=method finder_tests

    @tests = $k->finder_tests(\%query);

This is the query engine used to find groups and entries.

See L<File::KeePass/finder_tests>.

=cut

# Copied from File::KeePass - thanks paul
sub finder_tests {
    my ($self, $args) = @_;
    my @tests;
    foreach my $key (keys %{ $args || {} }) {
        next if ! defined $args->{$key};
        my ($field, $op) = ($key =~ m{ ^ (\w+) \s* (|!|=|!~|=~|gt|lt) $ }x) ? ($1, $2) : die "Invalid find match criteria \"$key\"\n";
        push @tests,  (!$op || $op eq '=') ? sub {  defined($_[0]->{$field}) && $_[0]->{$field} eq $args->{$key} }
                    : ($op eq '!')         ? sub { !defined($_[0]->{$field}) || $_[0]->{$field} ne $args->{$key} }
                    : ($op eq '=~')        ? sub {  defined($_[0]->{$field}) && $_[0]->{$field} =~ $args->{$key} }
                    : ($op eq '!~')        ? sub { !defined($_[0]->{$field}) || $_[0]->{$field} !~ $args->{$key} }
                    : ($op eq 'gt')        ? sub {  defined($_[0]->{$field}) && $_[0]->{$field} gt $args->{$key} }
                    : ($op eq 'lt')        ? sub {  defined($_[0]->{$field}) && $_[0]->{$field} lt $args->{$key} }
                    : die "Unknown op \"$op\"\n";
    }
    return @tests;
}

=attr default_exp

    $string = $k->default_exp;

Get the default value to use as the expiry time.

=cut

sub default_exp { $_[0]->{default_exp} || '2999-12-31 23:23:59' }

sub now {
    my ($self, $time) = @_;
    my ($sec, $min, $hour, $day, $mon, $year) = gmtime($time || time);
    return sprintf '%04d-%02d-%02d %02d:%02d:%02d', $year+1900, $mon+1, $day, $hour, $min, $sec;
}

sub encode_base64 { encode_b64($_[1]) }
sub decode_base64 { decode_b64($_[1]) }

sub gen_uuid { generate_uuid(printable => 1) }

# Copied from File::KeePass - thanks paul
sub uuid {
    my ($self, $id, $uniq) = @_;
    $id = $self->gen_uuid if !defined($id) || !length($id);
    return $uniq->{$id} ||= do {
        if (length($id) != 16) {
            $id = substr($self->encode_base64($id), 0, 16) if $id !~ /^\d+$/ || $id > 2**32-1;
            $id = sprintf '%016s', $id if $id ne '0';
        }
        $id = $self->gen_uuid while $uniq->{$id}++;
        $id;
    };
}

##############################################################################

=attr auto_lock

Get and set whether the database will be locked initially after load. Regardless, the database can always be
manually locked and unlocked at any time.

See L<File::KeePass/auto_lock>.

=cut

sub auto_lock {
    my $self = shift;
    $self->{auto_lock} = shift if @_;
    $self->{auto_lock} //= 1;
}

=method is_locked

    $bool = $k->is_locked;

Get whether or not a database is locked (i.e. memory-protected passwords).

See L<File::KeePass/is_locked>.

=cut

sub is_locked { $_[0]->kdbx->is_locked }

=method lock

    $k->lock;

Lock a database.

See L<File::KeePass/lock>.

=cut

sub lock { $_[0]->kdbx->lock }

=method unlock

    $k->unlock;

Unlock a database.

See L<File::KeePass/unlock>.

=cut

sub unlock { $_[0]->kdbx->unlock }

=method locked_entry_password

    $password = $k->locked_entry_password($entry);

Get a memory-protected password.

See L<File::KeePass/locked_entry_password>.

=cut

sub locked_entry_password {
    my $self = shift;
    my $entry = shift;

    $self->is_locked or die "Passwords are not locked\n";

    $entry = $self->find_entry({id => $entry}) if !ref $entry;
    return if !$entry;

    my $entry_obj = $entry->{__object} or return;

    my $cleanup = $self->kdbx->unlock_scoped;
    return $entry_obj->password;
}

##############################################################################

sub _tie {
    my $self    = shift;
    my $ref     = shift // \my %h;
    my $class   = shift;
    my $obj     = shift;

    my $cache = $TIED{refaddr($self)} //= {};

    $class = __PACKAGE__."::Tie::$class" if $class !~ s/^\+//;
    my $key = "$class:" . refaddr($obj);
    my $hit = $cache->{$key};
    return $hit if defined $hit;

    load $class;
    tie((ref $ref eq 'ARRAY' ? @$ref : %$ref), $class, $obj, @_, $self);
    $hit = $cache->{$key} = $ref;
    weaken $cache->{$key};
    return $hit;
}

### convert datetime from KDBX to KeePass format
sub _decode_datetime {
    local $_ = shift or return;
    return $_->strftime('%Y-%m-%d %H:%M:%S');
}

### convert datetime from KeePass to KDBX format
sub _encode_datetime {
    local $_ = shift or return;
    return Time::Piece->strptime($_, '%Y-%m-%d %H:%M:%S');
}

### convert UUID from KeePass to KDBX format
sub _encode_uuid {
    local $_ = shift // return;
    # Group IDs in KDB files are 32-bit integers
    return sprintf('%016x', $_) if length($_) != 16 && looks_like_number($_);
    return $_;
}

### convert tristate from KDBX to KeePass format
sub _decode_tristate {
    local $_ = shift // return;
    return $_ ? 1 : 0;
}

### convert tristate from KeePass to KDBX format
sub _encode_tristate {
    local $_ = shift // return;
    return boolean($_);
}

1;
__END__

=for Pod::Coverage STORABLE_freeze STORABLE_thaw decode_base64 encode_base64 gen_uuid now uuid

=head1 SYNOPSIS

    use File::KeePassX;

    my $k = File::KeePassX->new($kdbx);
    # OR
    my $k = File::KeePassX->load_db($filepath, $password);

    print Dumper $k->header;
    print Dumper $k->groups; # passwords are locked

    $k->unlock;
    print Dumper $k->groups; # passwords are now visible

See L<File::KeePass> for a more complete synopsis.

=head1 DESCRIPTION

This is a L<File::KeePass> compatibility shim for L<File::KDBX>. It presents the same interface as
B<File::KeePass> (mostly, see L</"Known discrepancies">) but uses B<File::KDBX> for database storage, file
parsing, etc. It is meant to be a drop-in replacement for B<File::KeePass>. Documentation I<here> might be
somewhat thin, so just refer to the B<File::KeePass> documentation since everything should work the same.

This shim has some overhead which should make it generally slower than using either B<File::KeePass> or
B<File::KDBX> directly, but it is a quick way to gain the advantages of the newer B<File::KDBX> (KDBX4
support, better UTF-8 handling, security improvements, etc.) without having to rewrite any significant portion
of your application.

Unlike B<File::KDBX> itself, I<this> module is EXPERIMENTAL. How it works might change in the future --
although by its nature it will aim to be as compatible as possible with the B<File::KeePass> interface, so
it's stable enough to start using without fear of interface changes. Just don't depend on any of its guts
(which you shouldn't do even if it were completely "stable").

B<File::KeePassX> incorporates some of the code from B<File::KeePass> but it is not a required dependency and
need not be installed for basic functionality. If B<File::KeePass> is installed, it will be used as a backend
parser and generator for working with older KDB (KeePass 1) files since B<File::KDBX> has no native KDB
parser.

=head1 CAVEATS

=head2 Known discrepancies

This I<is> supposed to be a drop-in replacement for L<File::KeePass>. If you're sticking to the
B<File::KeePass> public interface you probably won't have to rewrite any code. If you do, it could be
considered a B<File::KeePassX> bug. But there are some differences that some code might notice and even could
get tripped up on:

B<File::KeePassX> does not provide any of the L<File::KeePass/"UTILITY METHODS"> or
L<File::KeePass/"OTHER METHODS"> unless incidentally, with two exceptions: L</now> and L</default_exp>.
I judge these other methods to not be useful for I<users> of B<File::KeePass> and so probably aren't used by
anyone, but if I'm wrong you can get them by using B<File::KeePass>:

    use File::KeePass;  # must use before File::KeePassX
    use File::KeePassX;

You might also need to do this if the answer to C<< File::KeePassX->new->isa('File::KeePass') >> is important
to your code.

B<File::KeePassX> does not take any pains to replicate
L<File::KeePass bugs|https://rt.cpan.org/Public/Dist/Display.html?Name=File-KeePass>. If your code has any
workarounds, you might need or want to undo those. Issues known to be fixed (or not applicable) are:
L<#85012|https://rt.cpan.org/Ticket/Display.html?id=85012>,
L<#82582|https://rt.cpan.org/Ticket/Display.html?id=82582>,
L<#124531|https://rt.cpan.org/Ticket/Display.html?id=124531>,
L<#123330|https://rt.cpan.org/Ticket/Display.html?id=123330>,
L<#120224|https://rt.cpan.org/Ticket/Display.html?id=120224>,
L<#117836|https://rt.cpan.org/Ticket/Display.html?id=117836>,
L<#97055|https://rt.cpan.org/Ticket/Display.html?id=97055>,
L<#96049|https://rt.cpan.org/Ticket/Display.html?id=96049>,
L<#94753|https://rt.cpan.org/Ticket/Display.html?id=94753> and
L<#87109|https://rt.cpan.org/Ticket/Display.html?id=87109>.

B<File::KeePass> provides the C<header_size> field in the L</header>, which is the size of the file header in
number of bytes. B<File::KeePassX> does not.

B<File::KeePass> supports a C<keep_xml> option on L</load_db> to retain a copy of the XML of a KDBX file from
the parser as a string. B<File::KeePassX> does not support this option. To do something similar with
B<File::KDBX>:

    my $kdbx = File::KDBX->load($filepath, $key, inner_format => 'Raw');
    my $xml = $kdbx->raw;

There might be idiosyncrasies related to default values and when they're set. Fields within data structures
might exist but be undefined in one where they just don't exist in the other. You should check for values
using L<perlfunc/defined> instead of L<perlfunc/exists>.

B<File::KeePassX> might be stricter or fail earlier in some cases. For example, setting a date & time or UUID
with an invalid format might fail immediately rather than later on in a query or at file generation. To avoid
problems, stop trying to do invalid things. 😃

Some methods have different performance profiles from their B<File::KeePass> counterparts (besides any general
overhead). Operations that are constant time in B<File::KeePass> might be linear in B<File::KeePassX>, for
example. Or some things in B<File::KeePassX> might be faster than B<File::KeePass>.

=cut
