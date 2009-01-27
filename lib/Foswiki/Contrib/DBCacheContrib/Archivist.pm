#
# Copyright (C) 2009 Crawford Currie, http://c-dot.co.uk
#
# An archivist handles the storage of data on disc. It serves up
# maps and arrays that obey the Foswiki::Contrib::DBCacheContrib::Array and
# Foswiki::Contrib::DBCacheContrib::Map interfaces.
#
package Foswiki::Contrib::DBCacheContrib::Archivist;

use strict;
use Assert;

# Factory for new Map objects
sub newMap {
    ASSERT("Pure virtual method not implemented");
}

# Factory for new Array objects
sub newArray {
    ASSERT("Pure virtual method not implemented");
}

# Sync data to disc
sub sync {
    ASSERT("Pure virtual method not implemented");
}

# Get the DB root (always a Map)
sub getRoot {
    ASSERT("Pure virtual method not implemented");
}

# Completely clear down the DB; removes all data and
# creates a new root.
sub clear {
    ASSERT("Pure virtual method not implemented");
}

1;
