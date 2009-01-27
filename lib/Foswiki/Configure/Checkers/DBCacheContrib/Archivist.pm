#
# Copyright (C) 2007 Crawford Currie, http://c-dot.co.uk
#
package Foswiki::Configure::Checkers::DBCacheContrib::Archivist;

use strict;

use Foswiki::Configure::Checker;

use base 'Foswiki::Configure::Checker';

sub check {
    my $this = shift;

    my $mess = '';
    eval "use $Foswiki::cfg{DBCacheContrib}{Archivist}";
    if ($@) {
        $mess = $this->ERROR(
            "Could not load $Foswiki::cfg{DBCacheContrib}{Archivist}: $@");
    }

    return $mess;
};

1;
