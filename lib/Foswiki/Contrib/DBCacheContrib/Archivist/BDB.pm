#
# Copyright (C) 2009 Crawford Currie http://c-dot.co.uk
#
# Implementation of Archivist for talking to a Berkeley DB
#
package Foswiki::Contrib::DBCacheContrib::Archivist::BDB;
use base 'Foswiki::Contrib::DBCacheContrib::Archivist';

use strict;
use BerkeleyDB;
use Assert;

use Foswiki::Contrib::DBCacheContrib::Archivist::BDB::Map;
use Foswiki::Contrib::DBCacheContrib::Archivist::BDB::Array;

# Type constants
my $PERL  = 0;
my $MAP   = 1;
my $ARRAY = 2;

sub new {
    my ( $class, $file ) = @_;
    my $this = bless( {}, $class );
    $this->{db} = tie(
        %{ $this->{tie} }, 'BerkeleyDB::Hash',
        -Flags    => DB_CREATE,
        -Filename => $file
    );
    $this->{stubs} = {};
    return $this;
}

sub getRoot {
    my $this = shift;
    unless ( $this->{root} ) {
        if ( $this->{tie}->{__ROOT__} ) {
            $this->{root} = $this->decode( $this->{tie}->{__ROOT__} );
        }
        else {
            $this->{root} = $this->newMap();
        }
    }
    return $this->{root};
}

sub clear {
    my $this = shift;
    $this->{stubs} = {};
    $this->{root}  = undef;
    if ( $this->{db} ) {
        $this->{tie} = {};
    }
}

sub DESTROY {
    my $this = shift;

    #$this->{db}->db_sync();
    $this->{db} = undef;
    untie( %{ $this->{tie} } );
    $this->{stubs} = undef;
}

sub newMap {
    my $this = shift;
    return new Foswiki::Contrib::DBCacheContrib::Archivist::BDB::Map(
        archivist => $this,
        @_
    );
}

sub newArray {
    my $this = shift;
    return new Foswiki::Contrib::DBCacheContrib::Archivist::BDB::Array(
        archivist => $this,
        @_
    );
}

sub sync {
    my ( $this, $data ) = @_;
    return unless $this->{db};
    $this->{tie}->{__ROOT__} = $this->encode($data) if $data;
    $this->{db}->db_sync();
}

sub encode {
    my ( $this, $value ) = @_;
    my $type = $PERL;
    if (
        UNIVERSAL::isa(
            $value, 'Foswiki::Contrib::DBCacheContrib::Archivist::BDB::Map'
        )
      )
    {
        $type  = $MAP;
        $value = $value->{id};
    }
    elsif (
        UNIVERSAL::isa(
            $value, 'Foswiki::Contrib::DBCacheContrib::Archivist::BDB::Array'
        )
      )
    {
        $type  = $ARRAY;
        $value = $value->{id};
    }
    elsif ( ref($value) ) {
        die "Unstorable type " . ref($value);
    }
    else {
        $value = '' unless defined $value;
    }
    $value = pack( 'ca*', $type, $value );
    return $value;
}

# Given an encoded value from the DB, decode it and if necessary create
# the stub map or array object.
# Note that this doesn't re-use stubs when the same id is referenced
# again. Perhaps it should.
sub decode {
    my ( $this, $s ) = @_;
    return $s unless defined $s && length($s);
    my ( $type, $value ) = unpack( 'ca*', $s );
    if ( $type != $PERL ) {
        if ( $type == $MAP ) {
            $this->{stubs}->{$value} ||= $this->newMap( id => $value );
        }
        elsif ( $type == $ARRAY ) {
            $this->{stubs}->{$value} ||= $this->newArray( id => $value );
        }
        else {
            die "Corrupt DB; type $type";
        }
        $value = $this->{stubs}->{$value};
    }
    return $value;
}

# If passed an ID, make sure it can't get created again.
# If not passed an id, allocate one. Nothing gets explicitly
# created in the DB; we just reserve the ID.
sub allocateID {
    my ( $this, $id ) = @_;
    my $oid = $this->{tie}->{__ID__} || 0;
    if ( defined $id ) {
        if ( $id >= $oid ) {
            $this->{tie}->{__ID__} = $id + 1;
        }
        return $id;
    }
    else {
        $this->{tie}->{__ID__} = $oid + 1;
        return $oid;
    }
}

1;
