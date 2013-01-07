package DBCacheContribSuite;
use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'DBCacheContrib' }

sub include_tests {
    qw(ArrayTest MapTest SearchTest DBCacheTest);
}

1;
