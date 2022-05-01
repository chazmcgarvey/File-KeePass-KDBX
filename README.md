# NAME

File::KeePass::KDBX - Read and write KDBX files (using the File::KDBX backend)

# VERSION

version 0.900

# SYNOPSIS

    use File::KeePass::KDBX;

    my $k = File::KeePass::KDBX->new($kdbx);
    # OR
    my $k = File::KeePass::KDBX->load_db($filepath, $password);

    print Dumper $k->header;
    print Dumper $k->groups; # passwords are locked

    $k->unlock;
    print Dumper $k->groups; # passwords are now visible

See [File::KeePass](https://metacpan.org/pod/File%3A%3AKeePass) for a more complete synopsis.

# DESCRIPTION

This is a [File::KeePass](https://metacpan.org/pod/File%3A%3AKeePass) compatibility shim for [File::KDBX](https://metacpan.org/pod/File%3A%3AKDBX). It presents the same interface as
**File::KeePass** (mostly, see ["Discrepancies"](#discrepancies)) but uses **File::KDBX** for database storage, file parsing,
etc. It is meant to be a drop-in replacement for **File::KeePass**. Documentation _here_ might be somewhat
thin, so just refer to the **File::KeePass** documentation since everything should look the same.

Unlike **File::KDBX** itself, _this_ module is EXPERIMENTAL. How it works might change in the future --
although by its nature it will aim to be as compatible as possible with the **File::KeePass** interface, so
it's stable enough to start using without fear of interface changes. Just don't depend on any of its guts
(which you shouldn't do even if it were completely "stable").

**File::KeePass::KDBX** incorporates some of the code from **File::KeePass** but it is not a required dependency
and need not be installed for basic functionality. If **File::KeePass** is installed, it will be used as
a backend parser and generator for working with older KDB (KeePass 1) files since **File::KDBX** has no native
KDB parser.

# ATTRIBUTES

## kdbx

    $kdbx = $k->kdbx;
    $k->kdbx($kdbx);

Get or set the [File::KDBX](https://metacpan.org/pod/File%3A%3AKDBX) instance. The `File::KDBX` is the object that actually contains the database
data, so setting this will implicitly replace all of the data with data from the new database.

Getting the `File::KDBX` associated with a `File::KeePass::KDBX` grants you access to new functionality that
`File::KeePass` doesn't have any interface for, including:

- KDBX4-exclusive data (e.g. KDF parameters and public custom data headers)
- ["Placeholders" in File::KDBX](https://metacpan.org/pod/File%3A%3AKDBX#Placeholders)
- One-time passwords
- Search using "Simple Expressions"
- and more

## default\_exp

    $string = $k->default_exp;

Get the default value to use as the expiry time.

## auto\_lock

Get and set whether the database will be locked initially after load. Regardless, the database can always be
manually locked and unlocked at any time.

See ["auto\_lock" in File::KeePass](https://metacpan.org/pod/File%3A%3AKeePass#auto_lock).

# METHODS

## new

    $k = File::KeePass::KDBX->new(%attributes);
    $k = File::KeePass::KDBX->new($kdbx);
    $k = File::KeePass::KDBX->new($keepass);

Construct a new KeePass 2 database from a set of attributes, a [File::KDBX](https://metacpan.org/pod/File%3A%3AKDBX) instance or a [File::KeePass](https://metacpan.org/pod/File%3A%3AKeePass)
instance.

## clone

    $k_copy = $k->clone;
    OR
    $k_copy = File::KeePass::KDBX->new($k);

Make a copy.

## clear

    $k->clear;

Reset the database to a freshly initialized state.

See ["clear" in File::KeePass](https://metacpan.org/pod/File%3A%3AKeePass#clear).

## to\_fkp

    $fkp = $k->to_fkp;

Convert a [File::KeePass::KDBX](https://metacpan.org/pod/File%3A%3AKeePass%3A%3AKDBX) to a [File::KeePass](https://metacpan.org/pod/File%3A%3AKeePass). The resulting object is a separate copy of the
database; each can be modified independently.

## from\_fkp

    $k = File::KeePass::KDBX->from_fkp($fkp);

Convert a [File::KeePass](https://metacpan.org/pod/File%3A%3AKeePass) to a [File::KeePass::KDBX](https://metacpan.org/pod/File%3A%3AKeePass%3A%3AKDBX). The resulting object is a separate copy of the
database; each can be modified independently.

## load\_db

    $k = $k->load_db($filepath, $key);
    $k = File::KeePass::KDBX->load_db($filepath, $key, \%args);

Load a database from a file. `$key` is a master key, typically a password or passphrase and might also
include a keyfile path (e.g. `[$password, $keyfile]`). `%args` are the same as for ["new"](#new).

See ["load\_db" in File::KeePass](https://metacpan.org/pod/File%3A%3AKeePass#load_db).

## parse\_db

    $k = $k->parse_db($string, $key);
    $k = File::KeePass::KDBX->parse_db($string, $key, \%args);

Load a database from a string. `$key` is a master key, typically a password or passphrase and might also
include a keyfile path (e.g. `[$password, $keyfile]`). `%args` are the same as for ["new"](#new).

See ["parse\_db" in File::KeePass](https://metacpan.org/pod/File%3A%3AKeePass#parse_db).

## parse\_header

    \%head = $k->parse_header($string);

Parse only the header.

See ["parse\_header" in File::KeePass](https://metacpan.org/pod/File%3A%3AKeePass#parse_header).

## save\_db

    $k->save_db($filepath, $key);

Save the database to a file. `$key` is a master key, typically a password or passphrase and might also
include a keyfile path (e.g. `[$password, $keyfile]`).

See ["save\_db" in File::KeePass](https://metacpan.org/pod/File%3A%3AKeePass#save_db).

## gen\_db

    $db_string = $k->gen_db($key);

Save the database to a string. `$key` is a master key, typically a password or passphrase and might also
include a keyfile path (e.g. `[$password, $keyfile]`).

See ["gen\_db" in File::KeePass](https://metacpan.org/pod/File%3A%3AKeePass#gen_db).

## header

    \%header = $k->header;

Get the database file headers and KDBX metadata.

See ["header" in File::KeePass](https://metacpan.org/pod/File%3A%3AKeePass#header).

## groups

    \@groups = $k->groups;

Get the groups and entries stored in a database. This is the same data that ["groups" in File::KDBX](https://metacpan.org/pod/File%3A%3AKDBX#groups) provides but
in a shape compatible with ["groups" in File::KeePass](https://metacpan.org/pod/File%3A%3AKeePass#groups).

## dump\_groups

    $string = $k->dump_groups;
    $string = $k->dump_groups(\%query);

Get a string representation of the groups in the database.

See ["dump\_groups" in File::KeePass](https://metacpan.org/pod/File%3A%3AKeePass#dump_groups).

## add\_group

    $group = $k->add_group(\%group_info);

Add a new group.

See ["add\_group" in File::KeePass](https://metacpan.org/pod/File%3A%3AKeePass#add_group).

## find\_groups

    @groups = $k->find_groups(\%query);

Find groups.

See ["find\_groups" in File::KeePass](https://metacpan.org/pod/File%3A%3AKeePass#find_groups).

## find\_group

    $group = $k->find_group(\%query);

Find one group. If the query matches more than one group, an exception is thrown. If there is no matching
group, `undef` is returned

See ["find\_group" in File::KeePass](https://metacpan.org/pod/File%3A%3AKeePass#find_group).

## delete\_group

    $group = $k->delete_group(\%query);

Delete a group.

See ["delete\_group" in File::KeePass](https://metacpan.org/pod/File%3A%3AKeePass#delete_group).

## add\_entry

    $entry = $k->add_entry(\%entry_info);

Add a new entry.

See ["add\_entry" in File::KeePass](https://metacpan.org/pod/File%3A%3AKeePass#add_entry).

## find\_entries

    @entries = $k->find_entries(\%query);

Find entries.

See ["find\_entries" in File::KeePass](https://metacpan.org/pod/File%3A%3AKeePass#find_entries).

## find\_entry

    $entry = $k->find_entry(\%query);

Find one entry. If the query matches more than one entry, an exception is thrown. If there is no matching
entry, `undef` is returned

See ["find\_entry" in File::KeePass](https://metacpan.org/pod/File%3A%3AKeePass#find_entry).

## delete\_entry

    $entry = $k->delete_entry(\%query);

Delete an entry.

See ["delete\_entry" in File::KeePass](https://metacpan.org/pod/File%3A%3AKeePass#delete_entry).

## finder\_tests

    @tests = $k->finder_tests(\%query);

This is the query engine used to find groups and entries.

See ["finder\_tests" in File::KeePass](https://metacpan.org/pod/File%3A%3AKeePass#finder_tests).

## now

    $string = $k->now;

Get a timestamp representing the current date and time.

## is\_locked

    $bool = $k->is_locked;

Get whether or not a database is locked (i.e. memory-protected passwords).

See ["is\_locked" in File::KeePass](https://metacpan.org/pod/File%3A%3AKeePass#is_locked).

## lock

    $k->lock;

Lock a database.

See ["lock" in File::KeePass](https://metacpan.org/pod/File%3A%3AKeePass#lock).

## unlock

    $k->unlock;

Unlock a database.

See ["unlock" in File::KeePass](https://metacpan.org/pod/File%3A%3AKeePass#unlock).

## locked\_entry\_password

    $password = $k->locked_entry_password($entry);

Get a memory-protected password.

See ["locked\_entry\_password" in File::KeePass](https://metacpan.org/pod/File%3A%3AKeePass#locked_entry_password).

# CAVEATS

This shim uses [perltie](https://metacpan.org/pod/perltie) magics. Some data structures look and act like regular hashes and arrays (mostly),
but you might notice some unexpected magical things happen, like hash fields that populate themselves. The
magic is only there to make matching the **File::KeePass** interface possible, since that interface assumes
some amount of interaction with unblessed data structures. Some effort was made to at least hide the magic
where reasonable; any magical behavior is incidental and not considered a feature.

You should expect some considerable overhead which makes this module generally slower than using either
**File::KeePass** or **File::KDBX** directly. In some cases this might be due to an inefficient implementation
in the shim, but largely it is the cost of transparent compatibility.

If performance is critical and you still don't want to rewrite your code to use **File::KDBX** directly but do
want to take advantage of some of the new stuff, there is also the option to go part way. The strategy here is
to use **File::KeePass::KDBX** to load a database and then immediately convert it to a **File::KeePass** object.
Use that object without any runtime overhead, and then if and when you're ready to save the database or use
any other **File::KDBX** feature, "upgrade" it back into a **File::KeePass::KDBX** object. This strategy would
require modest code modifications to your application, to change:

    my $k = File::KeePass->new('database.kdbx', 'masterpw');

to this:

    my $k = File::KeePass::KDBX->load_db('database.kdbx', 'masterpw')->to_fkp;
    # $k is a normal File::KeePass

and change:

    $k->save_db('database.kdbx', 'masterpw');

to this:

    File::KeePass::KDBX->from_fkp($k)->save_db('database.kdbx', 'masterpw');

This works because **File::KeePass::KDBX** provides methods ["to\_fkp"](#to_fkp) and ["from\_fkp"](#from_fkp) for converting to and
from **File::KeePass**. ["new"](#new) also works instead of ["from\_fkp"](#from_fkp).

## Discrepancies

This shim _is_ supposed to be a drop-in replacement for [File::KeePass](https://metacpan.org/pod/File%3A%3AKeePass). If you're sticking to the
**File::KeePass** public interface you probably won't have to rewrite any code. If you do, it could be
considered a **File::KeePass::KDBX** bug. But there are some differences that some code might notice and could
even get tripped up on:

**File::KeePass::KDBX** does not provide any of the ["UTILITY METHODS" in File::KeePass](https://metacpan.org/pod/File%3A%3AKeePass#UTILITY-METHODS) or
["OTHER METHODS" in File::KeePass](https://metacpan.org/pod/File%3A%3AKeePass#OTHER-METHODS) unless incidentally, with two exceptions: ["now"](#now) and ["default\_exp"](#default_exp).
I judge these other methods to not be useful for _users_ of **File::KeePass** and so probably aren't used by
anyone, but if I'm wrong you can get them by using **File::KeePass**:

    use File::KeePass;  # must use before File::KeePass::KDBX
    use File::KeePass::KDBX;

Using both **File::KeePass** and **File::KeePass::KDBX** in this order will make the latter a proper subclass of
the former, so all the utility methods will be available via inheritance. You might also need to do this if
the answer to `File::KeePass::KDBX->new->isa('File::KeePass')` is important to your code.

**File::KeePass::KDBX** does not take any pains to replicate
[File::KeePass bugs](https://rt.cpan.org/Public/Dist/Display.html?Name=File-KeePass). If your code has any
workarounds, you might need or want to undo those. The issues known to be fixed (or not applicable) by using
**File::KeePass::KDBX** are:
[#85012](https://rt.cpan.org/Ticket/Display.html?id=85012),
[#82582](https://rt.cpan.org/Ticket/Display.html?id=82582),
[#124531](https://rt.cpan.org/Ticket/Display.html?id=124531),
[#123330](https://rt.cpan.org/Ticket/Display.html?id=123330),
[#120224](https://rt.cpan.org/Ticket/Display.html?id=120224),
[#117836](https://rt.cpan.org/Ticket/Display.html?id=117836),
[#97055](https://rt.cpan.org/Ticket/Display.html?id=97055),
[#96049](https://rt.cpan.org/Ticket/Display.html?id=96049),
[#94753](https://rt.cpan.org/Ticket/Display.html?id=94753) and
[#87109](https://rt.cpan.org/Ticket/Display.html?id=87109).

**File::KeePass** provides the `header_size` field in the ["header"](#header), which is the size of the file header in
number of bytes. **File::KeePass::KDBX** does not.

**File::KeePass** supports a `keep_xml` option on ["load\_db"](#load_db) to retain a copy of the XML of a KDBX file from
the parser as a string. **File::KeePass::KDBX** does not support this option. To do something similar with
**File::KDBX**:

    my $kdbx = File::KDBX->load($filepath, $key, inner_format => 'Raw');
    my $xml = $kdbx->raw;

There might be idiosyncrasies related to default values and when they're set. Fields within data structures
might exist but be undefined in one where they just don't exist in the other. You might need to check for
values using ["defined" in perlfunc](https://metacpan.org/pod/perlfunc#defined) instead of ["exists" in perlfunc](https://metacpan.org/pod/perlfunc#exists).

**File::KeePass::KDBX** might have slightly different error handling semantics. It might be stricter or fail
earlier in some cases. For example, setting a date & time or UUID with an invalid format might fail
immediately rather than later on in a query or at file generation. To achieve perfect consistency, you might
need to validate your inputs and handle errors before passing them to **File::KeePass::KDBX**.

Some methods have different performance profiles from their **File::KeePass** counterparts. Operations that are
constant time in **File::KeePass** might be linear in **File::KeePass::KDBX**, for example. Or some things in
**File::KeePass::KDBX** might be faster than **File::KeePass**. Of course you are not likely to detect any
differences unless you work with very large databases, and I don't know of any application where large KDBX
databases are common. I don't think _any_ KDBX implementation is optimized for large databases.

# BUGS

Please report any bugs or feature requests on the bugtracker website
[https://github.com/chazmcgarvey/File-KeePass-KDBX/issues](https://github.com/chazmcgarvey/File-KeePass-KDBX/issues)

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

# AUTHOR

Charles McGarvey <ccm@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2022 by Charles McGarvey.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
