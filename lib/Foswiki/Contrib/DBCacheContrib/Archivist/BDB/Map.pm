#
# Copyright (C) Crawford Currie 2009 http://c-dot.co.uk
#
# Each map stored in the DB has a unique handle
# The data in the map is stored using the handle
# So, we tie a Map to the particular key we are interested in.
# When a FETCH is done on a referenced object, we need to convert that to a key.
# When a STORE is with a Map or Array type object, we need to convert that
# to a key.

package Foswiki::Contrib::DBCacheContrib::Archivist::BDB::Map;
use base 'Foswiki::Contrib::DBCacheContrib::Map';
# Mixin collections code
use Foswiki::Contrib::DBCacheContrib::Archivist::BDB::Collection;
push(@ISA, 'Foswiki::Contrib::DBCacheContrib::Archivist::BDB::Collection');

use strict;
use Assert;

# Create a new hash, or bind to an existing hash if id is passed
sub new {
    my $class = shift;
    my %args = @_;
    my $initial;
    if ($args{initial}) {
        # Delay parsing until we are bound
        $initial = $args{initial};
        delete $args{initial};
    }
    my $this = $class->SUPER::new(%args);
    if (defined $args{id}) {
        # Binding to existing record
        $this->{id} = $this->{archivist}->allocateID($args{id});
    } else {
        # Creating new record
        $this->{id} = $this->{archivist}->allocateID();
    }
    if ($initial) {
        $this->parse($initial);
    }
    return $this;
}

sub STORE {
    my ($this, $key, $value) = @_;
    my $id = $this->getID($key);
    my %keys = map { $_ => 1 } $this->getKeys();
    unless ($keys{$key}) {
        push(@{$this->{keys}}, $key);
        $this->{archivist}->{tie}->{"__K__$this->{id}"} =
          join("\0", @{$this->{keys}});
    }
    $this->{archivist}->{tie}->{$id} = $this->{archivist}->encode($value);
}

sub FIRSTKEY {
    my $this = shift;
    $this->getKeys();
    return each %{$this->{keys}};
}

sub NEXTKEY {
    my ( $this, $lastkey ) = @_;
    return each %{$this->{keys}};
}

sub EXISTS {
    my ( $this, $key ) = @_;
    return exists $this->{archivist}->{tie}->{$this->getID($key)};
}

sub DELETE {
    my ( $this, $key ) = @_;
    delete $this->{archivist}->{tie}->{$this->getID($key)};
    $this->getKeys();
    my %keys = map { $_ => 1 } $this->getKeys();
    delete($keys{$key});
    $this->{archivist}->{tie}->{"__K__$this->{id}"} = join("\0", keys %keys);
    $this->{keys} = undef;
}

sub SCALAR {
    my ( $this ) = @_;
    my %keys = map { $_ => 1 } $this->getKeys();
    return scalar %keys;
}

sub equals {
    my ($this, $that) = @_;
    return 0 unless ref($that) eq ref($this);
    return $that->{id} eq $this->{id};
}

sub getKeys {
    my $this = shift;

    unless (defined $this->{keys}) {
        @{$this->{keys}} = split(
            "\0", $this->{archivist}->{tie}->{"__K__$this->{id}"} || '');
    }

    return @{$this->{keys}};
}

sub getValues {
    my $this = shift;

    my @values;
    foreach my $k ($this->getKeys()) {
        push(@values, $this->FETCH($k));
    }
    return @values;
}

1;
