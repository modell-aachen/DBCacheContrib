#
# Copyright (C) Motorola 2003 - All rights reserved
# Copyright (C) Crawford Currie 2004
#
package Foswiki::Contrib::DBCacheContrib::MemMap;
use base 'Foswiki::Contrib::DBCacheContrib::Map';

use strict;

use Foswiki::Contrib::DBCacheContrib::MemArray;
use Assert;

sub setArchivist {
    my ( $this, $archivist, $done ) = @_;
    $this->SUPER::setArchivist( $archivist, $done, $this->getValues() );
}

sub DESTROY {
    my $this = shift;

    # prevent recursive destruction
    return if $this->{_destroying};
    $this->{_destroying} = 1;

    $this->SUPER::setArchivist(undef);

    # destroy sub objects
    map {
        $_->DESTROY()
          if $_
              && $_ ne $this
              && ref($_)
              && !Scalar::Util::isweak($_)
              && UNIVERSAL::can( $_, 'DESTROY' );
    } values %{ $this->{keys} };

    $this->{keys} = undef;
}

sub STORE {
    my ( $this, $key, $value ) = @_;
    $this->{keys}{$key} = $value;
    Scalar::Util::weaken( $this->{keys}{$key} )
        if ( ref($value) && $key =~ /^_/ );
}

sub FETCH {
    my ( $this, $key ) = @_;
    return $this->{keys}{$key};
}

sub FIRSTKEY {
    my $this = shift;
    return each %{ $this->{keys} };
}

sub NEXTKEY {
    my ( $this, $lastkey ) = @_;
    return each %{ $this->{keys} };
}

sub EXISTS {
    my ( $this, $key ) = @_;
    return exists $this->{keys}{$key};
}

sub DELETE {
    my ( $this, $key ) = @_;
    return delete $this->{keys}{$key};
}

sub CLEAR {
    my ($this) = @_;
    $this->{keys} = ();
}

sub SCALAR {
    my ($this) = @_;
    return scalar %{ $this->{keys} };
}

sub getKeys {
    my $this = shift;
    return keys %{ $this->{keys} };
}

sub getValues {
    my $this = shift;
    return values %{ $this->{keys} };
}

1;
