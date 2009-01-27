#
# Copyright (C) 2009 Crawford Currie, http://c-dot.co.uk
#
# Mixin to add archivability to a collection object
#
package Foswiki::Contrib::DBCacheContrib::Archivable;
use Scalar::Util;

sub setArchivist {
    my $this = shift;
    my $archivist = shift;
    my $done = shift;

    $done ||= {};
    if ($archivist) {
        $this->{archivist} = $archivist;
        Scalar::Util::weaken($this->{archivist});
    } else {
        delete $this->{archivist};
    }
    $done->{$this} = 1;
    foreach my $value (@_) {
        if ($value
              && UNIVERSAL::isa($value, __PACKAGE__)
                && !$done->{$value}) {
            $value->setArchivist($archivist, $done);
        }
    }
}

sub getArchivist {
    my $this = shift;
    return $this->{archivist};
}

1;
