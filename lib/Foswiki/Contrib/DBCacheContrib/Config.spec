#---+ DBCache
# This extension is a database cache, used by the DBCachePlugin
# and FormQueryPlugin.

# **SELECTCLASS Foswiki::Contrib::DBCacheContrib::Archivist::* **
# The extension can use one of a number of different methods for
# storing the cache. Which one you choose depends mainly on what you
# have installed, and what your data looks like. If you have a realtively
# small number of topics (< 5000) and lots of memory, you should use the
# 'Storable' module. This module loads all topic data into memory for fast
# searching. On the other hand if you have a large number of topics, or tight
# memory constraints, you should use 'BerkeleyDB' which stores the cache in
# an external database. This is slightly slower to search, but is scalable
# up to very large numbers of topics. The 'File' implementation is used for
# testing only, and should not be used in a production system.
$Foswiki::cfg{DBCacheContrib}{Archivist} =
    'Foswiki::Contrib::DBCacheContrib::Archivist::Storable';

# **BOOLEAN**
# If set to 0, then do not update the cache from the .txt files unless
# explicitly requested by the calling code. The default is to update it
# automatically whenever the database is opened.
# Normally this should be set according to the directions given for
# installing whatever extension is providing the interface to the DBCache.
$Foswiki::cfg{DBCacheContrib}{AlwaysUpdateCache} = $TRUE;

# **NUMBER**
# Can be used to prevent the cache update from parsing all of the changed
# and new files in one hit, thus reducing the impact on individual topic
# views by spreading the update over several requests.
# Normally this should be set according to the directions given for
# installing whatever extension is providing the interface to the DBCache.
$Foswiki::cfg{DBCacheContrib}{LoadFileLimit} = 0;
