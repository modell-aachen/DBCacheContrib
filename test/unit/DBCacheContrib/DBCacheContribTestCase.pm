package DBCacheContribTestCase;
use base 'FoswikiFnTestCase';

use strict;
use Assert;
use File::Temp;
use Devel::Cycle;

use Foswiki::Contrib::DBCacheContrib::Archivist::Storable;
use Foswiki::Contrib::DBCacheContrib::Archivist::BDB;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
}

sub tear_down {
    my $this = shift;

    Devel::Cycle::find_cycle( $this->{ar} ) if $this->{ar};

    # Clear out any existing data from the archive
    $this->{ar}->clear() if $this->{ar};

    $this->SUPER::tear_down();
}

sub setArchivist {
    my ( $this, $archivist ) = @_;
    $this->{archivist} = $archivist;
    my $tmpfile = new File::Temp( UNLINK => 1 );
    $this->{ar}     = $archivist->new( $tmpfile->filename );
    $this->{tempfn} = $tmpfile->filename;
}

sub StorableArchivist {
    my $this = shift;
    $this->setArchivist(
        'Foswiki::Contrib::DBCacheContrib::Archivist::Storable');
}

our $bdb;

{

    package DBCacheContribTestCase::FakeArchivist;

    sub new {
        $bdb->{stubs} = {};
        return $bdb;
    }
};

sub BDBArchivist {
    my $this = shift;
    if ( !$bdb ) {
        $this->setArchivist('Foswiki::Contrib::DBCacheContrib::Archivist::BDB');
        $bdb = $this->{ar};
    }
    else {
        $this->{ar}   = $bdb;
        $bdb->{stubs} = {};
    }
    $this->{archivist} = 'DBCacheContribTestCase::FakeArchivist';
}

sub fixture_groups {
    return ( [ 'StorableArchivist', 'BDBArchivist' ] );
}

1;
