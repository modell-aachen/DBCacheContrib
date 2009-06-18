#
# Copyright (C) Motorola 2003 - All rights reserved
# Copyright (C) Crawford Currie 2004 - All rights reserved
#
package Foswiki::Contrib::DBCacheContrib;

#use base 'Foswiki::Contrib::DBCacheContrib::Map';

use strict;

use Foswiki::Attrs ();
use Assert;

=pod

---++ class DBCacheContrib

General purpose cache that treats topics as hashes. Useful for
rapid read and search of the database. Only works on one web.

Typical usage:
<verbatim>
  use Foswiki::Contrib::DBCacheContrib;

  $db = new Foswiki::Contrib::DBCacheContrib( $web ); # always done
  $db->load(); # may be always done, or only on demand when a tag is parsed that needs it

  # the DB is a hash of topics keyed on their name
  foreach my $topic ($db->getKeys()) {
     my $attachments = $db->get($topic)->get("attachments");
     # attachments is an array
     foreach my $val ($attachments->getValues()) {
       my $aname = $attachments->get("name");
       my $acomment = $attachments->get("comment");
       my $adate = $attachments->get("date");
       ...
     }
  }
</verbatim>
As topics are loaded, the readTopicLine method gives subclasses an opportunity to apply special processing to indivual lines, for example to extract special syntax such as %ACTION lines, or embedded tables in the text. See FormQueryPlugin for an example of this.

=cut

use vars qw( $initialised $storable $VERSION $RELEASE );

$initialised = 0;    # Not initialised until the first new

$VERSION = '$Rev$';
$RELEASE = '18 Jun 2009';

=pod

---+++ =new($web, $cacheName[, $standardSchema])=
Construct a new DBCache object.
   * =$web= name of web to create the object for.
   * =$cacheName= name of cache file (default "_DBCache")
   * =$standardSchema= Set to 1 this will load the cache using the
     'standard' Foswiki schema, rather than the original DBCacheContrib
     extended schema.

=cut

sub new {
    my ( $class, $web, $cacheName, $standardSchema ) = @_;
    $cacheName ||= '_DBCache';

    # Backward compatibility
    unless ( $Foswiki::cfg{DBCacheContrib}{Archivist} ) {
        $Foswiki::cfg{DBCacheContrib}{Archivist} =
          'Foswiki::Contrib::DBCacheContrib::Archivist::Storable';
    }
    eval "use $Foswiki::cfg{DBCacheContrib}{Archivist}";
    die $@ if ($@);

    my $this = bless(
        {
            _cache     => undef,        # pointer to the DB, load on demand
            _web       => $web,
            _cachename => $cacheName,
            _standardSchema  => $standardSchema,
        },
        $class
    );

    # Create the archivist. This will connect to an existing DB or create
    # a new DB if required.
    my $workDir   = Foswiki::Func::getWorkArea('DBCacheContrib');
    my $cacheFile = "$workDir/$web.$cacheName";

    $this->{archivist} =
      $Foswiki::cfg{DBCacheContrib}{Archivist}->new($cacheFile);
    return $this;
}

sub cache {
    my $this = shift;
    return $this->{_cache};
}

######################################################################
# In order for this class to operate as documented it has to implement
# Foswiki::Map. However it no longer directly subclasses Map since the
# move to BerkeleyDB. So we have to facade the cache instead. Note that
# this will *not* make this class tieable, as it doesn't inherit.

sub getKeys {
    my $this = shift;
    return $this->{_cache}->getKeys();
}

sub getValues {
    my $this = shift;
    return $this->{_cache}->getValues();
}

sub fastget {
    my $this = shift;
    return $this->{_cache}->fastget(@_);
}

sub equals {
    my $this = shift;
    return $this->{_cache}->equals(@_);
}

sub get {
    my $this = shift;
    return $this->{_cache}->get(@_);
}

sub set {
    my $this = shift;
    return $this->{_cache}->set(@_);
}

sub size {
    my $this = shift;
    return $this->{_cache}->size(@_);
}

sub remove {
    my $this = shift;
    return $this->{_cache}->remove(@_);
}

sub search {
    my $this = shift;
    return $this->{_cache}->search(@_);
}

sub toString {
    my $this = shift;
    return $this->{_cache}->toString(@_);
}

## End of facade
######################################################################

# PRIVATE load a single topic from the given data directory. This
# ought to be replaced by Foswiki::Func::readTopic -> {$meta, $text) but
# this implementation is more efficient for just now.
# returns 1 if the topic was loaded successfully, 0 otherwise
sub _loadTopic {
    my ( $this, $web, $topic ) = @_;

    my ($tom, $text) = Foswiki::Func::readTopic( $web, $topic );
    my $standardSchema = $this->{_standardSchema};

    my $meta = $this->{archivist}->newMap();
    $meta->set( 'name',  $topic );
    if ($standardSchema) {
        $meta->set( 'web', $web );
    } else {
        $meta->set( 'topic', $topic );
    }
    # SMELL: core API
    my $time;
    if ($Foswiki::Plugins::SESSION->can('getApproxRevTime')) {
        $time = $Foswiki::Plugins::SESSION->getApproxRevTime($web, $topic);
    } else {
        # This is here for TWiki
        $time = $Foswiki::Plugins::SESSION->{store}->
          getTopicLatestRevTime($web, $topic);
    }
    $meta->set( '.cache_path', "$web.$topic" );
    $meta->set( '.cache_time', $time );

    my $lookup;
    my $atts;
    if ($standardSchema) {
        # Add a fast lookup table for fields. This must be present
        # for QueryAcceleratorPlugin
        $lookup = $this->{archivist}->newMap();
        $meta->set( '.fields', $lookup );
        $meta->set( '.form_name', '' );
        # Create an empty array for the attachments. We have to have this
        # due to a deficiency in the 1.0.5 query algorithm
        $atts = $this->{archivist}->newArray();
        $meta->set( 'META:FILEATTACHMENT', $atts );
    }

    my $form;
    my $hash;

    if ($hash = $tom->get('FORM')) {
        my ( $formWeb, $formTopic ) =
          Foswiki::Func::normalizeWebTopicName( '', $hash->{name} );
        $form = $this->{archivist}->newMap();
        if ($standardSchema) {
            $form->set( 'name', "$formWeb.$formTopic" );
            $meta->set( 'META:FORM', $form );
            $meta->set( '.form_name', "$formWeb.$formTopic" );
        } else {
            $form->set( 'name', "$formWeb.$formTopic" );
            $form->set( '_up',  $meta );
            $form->set( '_web', $this->{_cache} );
            $meta->set( 'form', $formTopic );
        }
        $meta->set( $formTopic, $form );
    }
    if ( $hash = $tom->get('TOPICPARENT') ) {
        if ($standardSchema) {
            my $parent = $this->{archivist}->newMap( initial => $hash );
            $meta->set( 'META:TOPICPARENT', $parent );
        } else {
            $meta->set( 'parent', $hash->{name} );
        }
    }
    if ( $hash = $tom->get('TOPICINFO') ) {
        my $att = $this->{archivist}->newMap( initial => $hash );
        if ($standardSchema) {
            $meta->set( 'META:TOPICINFO', $att );
        } else {
            $att->set( '_up',  $meta );
            $att->set( '_web', $this->{_cache} );
            $meta->set( 'info', $att );
        }
    }
    if ( $hash = $tom->get('TOPICMOVED')) {
        my $att = $this->{archivist}->newMap( initial => $hash );
        if ($standardSchema) {
            $meta->set( 'META:TOPICMOVED', $att );
        } else {
            $att->set( '_up',  $meta );
            $att->set( '_web', $this->{_cache} );
            $meta->set( 'moved', $att );
        }
    }
    my @fields = $tom->find('FIELD');
    if ( scalar(@fields)) {
        my $fields;
        if ($standardSchema) {
            $fields = $this->{archivist}->newArray();
            $meta->set( 'META:FIELD', $fields );
        }
        foreach my $field (@fields) {
            if ($standardSchema) {
                my $att = $this->{archivist}->newMap( initial => $field );
                $fields->add( $att );
                $lookup->set( $field->{name}, $att );
            } else {
                unless ($form) {
                    $form = $this->{archivist}->newMap() ;
                    $form->set( '_web', $this->{_cache} );
                }
                $form->set( $field->{name}, $field->{value} );
            }
        }
    }
    my @attachments =  $tom->find('FILEATTACHMENT');
    foreach my $attachment (@attachments) {
        my $att = $this->{archivist}->newMap( initial => $attachment );
        if (!$standardSchema) {
            $att->set( '_up',  $meta );
            $att->set( '_web', $this->{_cache} );
            $atts = $meta->get('attachments');
            if ( !defined($atts) ) {
                $atts = $this->{archivist}->newArray();
                $meta->set( 'attachments', $atts );
            }
        }
        $atts->add($att);
    }
    my @preferences =  $tom->find('PREFERENCE');
    foreach my $preference (@preferences) {
        my $prefs;
        my $pref = $this->{archivist}->newMap( initial => $preference );
        if ($standardSchema) {
            $prefs = $meta->get('META:PREFERENCE');
            if ( !defined($prefs) ) {
                $prefs = $this->{archivist}->newArray();
                $meta->set( 'META:PREFERENCE', $prefs );
            }
        } else {
            $pref->set( '_up',  $meta );
            $pref->set( '_web', $this->{_cache} );
            $prefs = $meta->get('preferences');
            if ( !defined($prefs) ) {
                $prefs = $this->{archivist}->newArray();
                $meta->set( 'preferences', $prefs );
            }
        }
        $prefs->add($pref);
    }

    my $processedText = '';
    if ( $this->can('readTopicLine') ) {
        my @lines = split(/\r?\n/, $text);
        while (scalar(@lines)) {
            my $line = shift(@lines);
            $text .= $this->readTopicLine( $topic, $meta, $line, \@lines );
        }
    } else {
        $processedText = $text;
    }
    $meta->set( 'text', $processedText );
    $meta->set( 'all',  $tom->getEmbeddedStoreForm() ) unless $standardSchema;

    return $meta;
}

=pod

---+++ readTopicLine($topic, $meta, $line, $lines)
   * $topic - name of the topic being read
   * $meta - reference to the hash object for this topic
   * line - the line being read
   * $lines - reference to array of remaining lines after the current line
The function may modify $lines to cause the caller to skip lines.
=cut

#sub readTopicLine {
#    my ( $this, $topic, $meta, $line, $data ) = @_;
#}

=pod

---+++ onReload($topics)
   * =$topics= - perl array of topic names that have just been loaded (or reloaded)
Designed to be overridden by subclasses. Called when one or more topics had to be
read from disc rather than from the cache. Passed a list of topic names that have been read.

=cut

sub onReload {

    #my ( $this, @$topics) = @_;
}

sub _onReload {
    my $this = shift;

    unless ($this->{_standardSchema}) {
        foreach my $topic ( $this->{_cache}->getValues() ) {

            # Fill in parent relations
            unless ( $topic->FETCH('parent') ) {
                $topic->set( 'parent', $Foswiki::cfg{HomeTopicName} );

                # last parent is WebHome
            }
            unless ( $topic->FETCH('_up') ) {
                my $parent = $topic->FETCH('parent');
                $parent = $this->{_cache}->FETCH($parent) if $parent;

                # prevent the _up to be undefined in case of
                # a parent info to a non-existing topic;
                # the parent chain ends at the web hash
                if ($parent) {
                    $topic->set( '_up', $parent );
                }
                else {
                    $topic->set( '_up', $this->{_cache} );
                }
            }

            # set pointer to web
            $topic->set( '_web', $this->{_cache}, 1 );
            $topic->set( 'web', $this->{_web} );
        }
    }

    $this->onReload(@_);
}

=pod

---+++ load( [updateCache]  ) -> ($readFromCache, $readFromFile, $removed)

Load the web into the database.
Returns a list containing 3 numbers that give the number of topics
read from the cache, the number read from file, and the number of previously
cached topics that have been removed.

if  $Foswiki::cfg{DBCacheContrib}{AlwaysUpdateCache}  is set to FALSE (defaults to TRUE for compatibility)
then avoid calling _updateCache unless requested. DBCachePlugin now only asked for it from
the afterSaveHandler and from the new REST updateCache handler

=cut

sub load {
    my $this        = shift;
    my $updateCache = shift
      || $Foswiki::cfg{DBCacheContrib}{AlwaysUpdateCache};
    $updateCache = 1 unless ( defined($updateCache) );

    #print STDERR "Called load($updateCache)\n";

    return ( 0, 0, 0 ) if ( $this->{_cache} );    # already loaded?

    my $web = $this->{_web};
    $web =~ s/\//\./g;

    $this->{_cache} = $this->{archivist}->getRoot();

    ASSERT( $this->{_cache} ) if DEBUG;

    # Check what's there already
    my $readFromCache = $this->{_cache}->size();
    my $readFromFile  = 0;
    my $removed       = 0;

    if ( $updateCache || $this->{_cache}->size() == 0 ) {
        eval {
            ( $readFromCache, $readFromFile, $removed ) =
              $this->_updateCache($web);
        };

        if ($@) {
            ASSERT( 0, $@ ) if DEBUG;
            print STDERR "Cache read failed $@...\n" if DEBUG;
            Foswiki::Func::writeWarning("DBCache: Cache read failed: $@");
            $this->{_cache} = undef;
        } elsif ( $readFromFile || $removed ) {
            $this->{archivist}->sync( $this->{_cache} );
        }
    }

#print STDERR "DBCacheContrib: Loaded $readFromCache from cache, $readFromFile from file, $removed removed\n";

    return ( $readFromCache, $readFromFile, $removed );
}

# PRIVATE update the cache from files
# return the number of files changed in a tuple
sub _updateCache {
    my ( $this, $web ) = @_;

    my $readFromCache = $this->{_cache}->size();
    foreach my $cached ( $this->{_cache}->getValues() ) {
        $cached->set( '.fresh', 0 );
    }

    my $readFromFile = 0;
    my @readTopic;

    $web =~ s/\./\//g;

    #print STDERR "_updateCache for $web\n";

    # load topics that are missing from the cache
    foreach my $topic ( Foswiki::Func::getTopicList($web) ) {
        my $topcache = $this->{_cache}->FETCH($topic);
        if (
            $topcache
            && !uptodate(
                $topcache->FETCH('.cache_path'),
                $topcache->FETCH('.cache_time')
            )
          )
        {
            #print STDERR "$web.$topic is out of date\n";
            $this->{_cache}->remove($topic);
            $readFromCache--;
            $topcache = undef;
        }
        if ( !$topcache ) {

            #print STDERR "$web.$topic is not in the cache\n";
            # Not in cache
            $topcache = $this->_loadTopic( $web, $topic );
            $this->{_cache}->set( $topic, $topcache );
            if ($topcache) {
                $readFromFile++;
                push( @readTopic, $topic );
            }
        }
        $topcache->set( '.fresh', 1 ) if $topcache;

        #don't disadvantage users just because the cache is off
        last
          if defined( $Foswiki::cfg{DBCacheContrib}{LoadFileLimit} )
              && ( $Foswiki::cfg{DBCacheContrib}{LoadFileLimit} > 0 )
              && ( $readFromFile >
                  $Foswiki::cfg{DBCacheContrib}{LoadFileLimit} );
    }

    # Find smelly topics in the cache
    my $removed = 0;
    foreach my $cached ( $this->{_cache}->getValues() ) {
        if ( $cached->FETCH('.fresh') ) {
            $cached->remove('.fresh');
        }
        else {
            $this->{_cache}->remove( $cached->FETCH('name') );
            $readFromCache--;
            $removed++;
        }
    }

    if ( $readFromFile || $removed ) {

        # refresh relations
        $this->_onReload( \@readTopic );
    }

    return ( $readFromCache, $readFromFile, $removed );
}

=begin text

---+++ =uptodate($topic, $time)= -> boolean
Check the file time against what is seen on disc. Return 1 if consistent, 0 if inconsistent.

=cut

sub uptodate {
    my ( $path, $time ) = @_;
    my ($web, $topic) = split(/\./, $path, 2);
    ASSERT($web, $path) if DEBUG;
    ASSERT($topic, $path) if DEBUG;
    # SMELL: core API
    my $fileTime;
    if ($Foswiki::Plugins::SESSION->can('getApproxRevTime')) {
        $fileTime = $Foswiki::Plugins::SESSION->getApproxRevTime($web, $topic);
    } else {
        # This is here for TWiki
        $fileTime = $Foswiki::Plugins::SESSION->{store}->
          getTopicLatestRevTime($web, $topic);
    }
    return ( $fileTime == $time ) ? 1 : 0;
}

1;
