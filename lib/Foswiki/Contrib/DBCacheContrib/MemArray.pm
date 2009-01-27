#
# Copyright (C) Motorola 2003 - All rights reserved
# Copyright (C) Crawford Currie 2004
#
package Foswiki::Contrib::DBCacheContrib::MemArray;
use base 'Foswiki::Contrib::DBCacheContrib::Array';

use strict;
use Assert;

# Array object that stores arrays in memory.

use Foswiki::Contrib::DBCacheContrib::Search;
use MemTrack;

sub setArchivist {
    my ($this, $archivist, $done) = @_;
    $this->SUPER::setArchivist($archivist, $done, @{$this->{values}});
}

sub DESTROY {
    my $this = shift;

    # prevent recursive destruction
    return if $this->{_destroying};
    $this->{_destroying} = 1;

    $this->SUPER::setArchivist(undef);

    # destroy sub objects
    foreach my $value (@{$this->{values}}) {
        if ($value
              && ref($value)
                && UNIVERSAL::can($_, 'DESTROY'))  {
            $value->DESTROY();
        }
    } ;
    $this->{values} = undef;
}

sub FETCH {
    my ( $this, $key ) = @_;
    return $this->{values}[$key];
}

sub FETCHSIZE {
    my $this = shift;
    return 0 unless defined $this->{values};
    return scalar(@{$this->{values}});
}

sub STORE {
    my ($this, $index, $value) = @_;
    $this->{values}[$index] = $value;
}

sub STORESIZE {
    my ($this, $count) = @_;
    $#{$this->{values}} = $count - 1;
}

sub EXISTS {
    my ($this, $index) = @_;
    return $index < scalar(@{$this->{values}});
}

sub DELETE {
    my ($this, $index) = @_;
    return delete($this->{values}[$index]);
}

sub CLEAR {
    my $this = shift;
    $this->{values} = undef;
}

sub PUSH {
    my $this = shift;
    return push(@{$this->{values}}, @_);
}

sub POP {
    my $this = shift;
    return pop @{$this->{values}};
}

sub SHIFT {
    my $this = shift;
    return shift @{$this->{values}};
}

sub UNSHIFT {
    my $this = shift;
    return unshift(@{$this->{values}}, @_);
}

sub getValues {
    my $this = shift;
    return @{$this->{values}};
}

1;
