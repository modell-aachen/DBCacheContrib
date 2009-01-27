#
# Copyright (C) Crawford Currie 2009 http://c-dot.co.uk
#
package Foswiki::Contrib::DBCacheContrib::Archivist::BDB::Array;
use base 'Foswiki::Contrib::DBCacheContrib::Array';
# Mixin collections code
use Foswiki::Contrib::DBCacheContrib::Archivist::BDB::Collection;
push(@ISA, 'Foswiki::Contrib::DBCacheContrib::Archivist::BDB::Collection' );

use strict;
use Assert;

sub new {
    my $class = shift;
    my %args = @_;
    my $this = $class->SUPER::new(%args);
    if (defined $args{id}) {
        # Binding to existing record
        $this->{id} = $this->{archivist}->allocateID($args{id});
    } else {
        # Creating new record
        $this->{id} = $this->{archivist}->allocateID();
    }
    return $this;
}

sub STORE {
    my ($this, $index, $value) = @_;
    if ($index >= $this->FETCHSIZE()) {
        $this->STORESIZE($index + 1);
    }
    $this->{archivist}->{tie}->{$this->getID($index)} =
      $this->{archivist}->encode($value);
}

sub FETCHSIZE {
    my ($this) = @_;
    return $this->{archivist}->{tie}->{"__S__$this->{id}"} || 0;
}

sub STORESIZE {
    my ($this, $count) = @_;
    my $sz = $this->FETCHSIZE();
    if ($count > $sz) {
        for (my $i = $sz; $i < $count; $i++) {
            $this->{archivist}->{tie}->{$this->getID($i)} = '';
        }
    } elsif ($count < $sz) {
        for (my $i = $count; $i < $sz; $i++) {
            delete $this->{archivist}->{tie}->{$this->getID($i)};
        }
    }
    $this->{archivist}->{tie}->{"__S__$this->{id}"} = $count;
}

sub EXISTS {
    my ($this, $index) = @_;
    return 0 if $index < 0 || $index >= $this->FETCHSIZE();
    # Not strictly correct; should return true only if the cell has
    # been explicitly set. Unassigned pattern, maybe?
    return 1;
}

sub DELETE {
    my ($this, $index) = @_;
    $this->STORE($index, '');
}

sub equals {
    my ($this, $that) = @_;
    return 0 unless ref($that) eq ref($this);
    return $that->{id} eq $this->{id};
}

sub getValues {
    my $this = shift;
    my $n = $this->FETCHSIZE();
    my @values;
    for (my $i = 0; $i < $n; $i++) {
        push(@values, $this->FETCH($i));
    }
    return @values;
}

1;
