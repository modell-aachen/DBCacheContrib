package Foswiki::Contrib::DBCacheContrib::Archivist::BDB::Collection;

use strict;
use Assert;

# Type constants
my $PERL  = 0;
my $MAP   = 1;
my $ARRAY = 2;

sub getID {
    my ($this, $k) = @_;
    return $this->{id} unless defined $k;
    return "$this->{id}\0$k";
}

sub FETCH {
    my( $this, $key) = @_;
    return $this->{archivist}->decode(
        $this->{archivist}->{tie}->{$this->getID($key)});
}

sub DESTROY {
    my $this = shift;
    $this->{archivist} = undef;
}

1;
