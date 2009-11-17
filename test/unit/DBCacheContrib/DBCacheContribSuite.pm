package DBCacheContribSuite;
use base qw(Unit::TestSuite);

sub name { 'DBCacheContrib' }

sub include_tests {
  #qw(ArrayTest MapTest SearchTest DBCacheTest);
  qw(SearchTest);
}

1;
