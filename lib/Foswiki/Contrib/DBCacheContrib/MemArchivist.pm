#
# Copyright (C) 2009 Crawford Currie, http://c-dot.co.uk
#
# Base class that implements Archivist for in-memory representation of data
# It is subclassed by the Storable and File archivists.
#
package Foswiki::Contrib::DBCacheContrib::MemArchivist;
use base 'Foswiki::Contrib::DBCacheContrib::Archivist';

use strict;
use Assert;
use Foswiki::Contrib::DBCacheContrib::MemMap;
use Foswiki::Contrib::DBCacheContrib::MemArray;

sub new {
    my ($class, $file) = @_;
    my $this = bless( { _file => $file }, $class );
    return $this;
}

# Factory for new Map objects
sub newMap {
    my $this = shift;
    return new Foswiki::Contrib::DBCacheContrib::MemMap(
        archivist => $this, @_);
}

# Factory for new Array objects
sub newArray {
    my ($this) = @_;
    return new Foswiki::Contrib::DBCacheContrib::MemArray(
        archivist => $this);
}

# Subclasses must provide getRoot and clear.

1;
