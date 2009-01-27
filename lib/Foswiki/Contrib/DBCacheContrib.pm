#
# Copyright (C) Motorola 2003 - All rights reserved
# Copyright (C) Crawford Currie 2004 - All rights reserved
#
package Foswiki::Contrib::DBCacheContrib;
#use base 'Foswiki::Contrib::DBCacheContrib::Map';

use strict;

use Foswiki::Attrs;
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

$initialised = 0; # Not initialised until the first new

$VERSION = '$Rev$';
$RELEASE = 'Foswiki-1';

=pod

---+++ =new($web, $cacheName)=
   * =$web= name of web to create the object for.
   * =$cacheName= name of cache file (default "_DBCache")

Construct a new DBCache object.

=cut

sub new {
    my ( $class, $web, $cacheName ) = @_;
    $cacheName ||= '_DBCache';

    # Backward compatibility
    unless( $Foswiki::cfg{DBCacheContrib}{Archivist} ) {
        $Foswiki::cfg{DBCacheContrib}{Archivist} =
          'Foswiki::Contrib::DBCacheContrib::Archivist::Storable';
    }
    eval "use $Foswiki::cfg{DBCacheContrib}{Archivist}";
    die $@ if ( $@ );

    my $this = bless( {
        _cache => undef, # pointer to the DB, load on demand
        _web => $web,
        _cachename => $cacheName,
    }, $class);

    # Create the archivist. This will connect to an existing DB or create
    # a new DB if required.
    my $workDir = Foswiki::Func::getWorkArea('DBCacheContrib');
    my $cacheFile = "$workDir/$web.$cacheName";
    $this->{archivist} = $Foswiki::cfg{DBCacheContrib}{Archivist}->new(
        $cacheFile);
    return $this;
}

sub cache {
    my $this = shift;
    return $this->{_cache};
}

# PRIVATE load a single topic from the given data directory. This
# ought to be replaced by Foswiki::Func::readTopic -> {$meta, $text) but
# this implementation is more efficient for just now.
# returns 1 if the topic was loaded successfully, 0 otherwise
sub _loadTopic {
    my ( $this, $dataDir, $topic ) = @_;
    my $filename = "$dataDir/$topic.txt";
    my $fh;
    #print STDERR "DBCacheContrib::_loadTopic($filename)\n";

    unless (open( $fh, "<$filename" )) {
        print STDERR "WARNING: Failed to open $filename\n";
        return 0;
    }

    my $meta = $this->{archivist}->newMap();
    $meta->set( 'name', $topic );
    $meta->set( 'topic', $topic );
    my @s = stat($filename);
    my $time = $s[9];
    $meta->set( '.cache_file', $filename );
    $meta->set( '.cache_time', $time );

    my $line;
    my $text = '';
    my $form;
    my $tailMeta = 0;
    local $/;
    my $all = <$fh>;
    close( $fh );
    my @lines = split(/\r?\n/, $all);
    while (scalar(@lines)) {
        my $line = shift(@lines);
        if ( $line =~ m/^%META:FORM{name=\"([^\"]*)\"}%/o ) {
            $form = $this->{archivist}->newMap() unless $form;
            my( $web, $topic ) = Foswiki::Func::normalizeWebTopicName('', $1);
            $form->set('name', $web.'.'.$topic);
            $form->set('_up', $meta);
            $form->set('_web', $this);
            $meta->set('form', $topic);
            $meta->set($topic, $form);
            $tailMeta = 1;
        } elsif ( $line =~ m/^%META:TOPICPARENT{name=\"([^\"]*)\"}%/o ) {
            $meta->set('parent', $1);
            $tailMeta = 1;
        } elsif ( $line =~ m/^%META:TOPICINFO{(.*)}%/o ) {
            my $att = $this->{archivist}->newMap(initial => $1);
            $att->set( '_up', $meta);
            $att->set( '_web', $this);
            $meta->set( 'info', $att );
        } elsif ( $line =~ m/^%META:TOPICMOVED{(.*)}%/o ) {
            my $att = $this->{archivist}->newMap(initial => $1);
            $att->set( '_up', $meta);
            $att->set( '_web', $this);
            $meta->set( 'moved', $att );
            $tailMeta = 1;
        } elsif ( $line =~ m/^%META:FIELD{(.*)}%/o ) {
            my $fs = new Foswiki::Attrs($1);
            $form = $this->{archivist}->newMap() unless $form;
            $form->set( '_web', $this, 1 );
            $form->set( $fs->get('name'), $fs->get('value'));
            $tailMeta = 1;
        } elsif ( $line =~ m/^%META:FILEATTACHMENT{(.*)}%/o ) {
            my $att = $this->{archivist}->newMap(initial => $1);
            $att->set( '_up', $meta);
            $att->set( '_web', $this);
            my $atts = $meta->get( 'attachments' );
            if ( !defined( $atts )) {
                $atts = $this->{archivist}->newArray();
                $meta->set( 'attachments', $atts );
            }
            $atts->add( $att );
            $tailMeta = 1;
        } elsif ( $line =~ m/^%META:PREFERENCE{(.*)}%/o ) {
            my $pref = $this->{archivist}->newMap(initial => $1);
            $pref->set( '_up', $meta);
            $pref->set( '_web', $this);
            my $prefs = $meta->get('preferences');
            if (!defined($prefs)) {
                $prefs = $this->{archivist}->newArray();
                $meta->set('preferences', $prefs);
            }
            $prefs->add($pref);
            $tailMeta = 1;
        } else {
            if ($this->can('readTopicLine')) {
                $text .= $this->readTopicLine( $topic, $meta, $line, \@lines );
            } else {
                $text .= $line if $line && $line !~ /%META:[A-Z].*?}%/o;
            }
        }
    }
    $text =~ s/\n$//s if $tailMeta;
    $meta->set( 'text', $text );
    $meta->set( 'all', $all );
    $this->{_cache}->set( $topic, $meta );

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

    foreach my $topic ( $this->{_cache}->getValues() ) {
        # Fill in parent relations
        unless ($topic->FETCH('parent')) {
          $topic->set('parent', $Foswiki::cfg{HomeTopicName});
          # last parent is WebHome
        }
        unless ( $topic->FETCH( '_up' )) {
            my $parent = $topic->FETCH( 'parent' );
            $parent = $this->{_cache}->FETCH( $parent ) if $parent;

            # prevent the _up to be undefined in case of
            # a parent info to a non-existing topic;
            # the parent chain ends at the web hash
            if ($parent) {
              $topic->set( '_up', $parent );
            } else {
              $topic->set( '_up', $this );
            }
        }

        # set pointer to web
        $topic->set( '_web', $this, 1 );
        $topic->set( 'web', $this->{_web} );
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
    my $this = shift;
    my $updateCache = shift
      || $Foswiki::cfg{DBCacheContrib}{AlwaysUpdateCache};
    $updateCache = 1 unless (defined($updateCache));
    #print STDERR "called load($updateCache)\n";

    return (0, 0, 0) if ( $this->{_cache} ); # already loaded?

    my $web = $this->{_web};
    $web =~ s/\//\./g;

    $this->{_cache} = $this->{archivist}->getRoot();

    # Check what's there already
    my $readFromCache = $this->{_cache}->size();
    my $readFromFile = 0;
    my $removed = 0;

    if ( $updateCache || $this->{_cache}->size() == 0 ) {
        eval {
            ( $readFromCache, $readFromFile, $removed ) =
              $this->_updateCache( $web );
        };

        if ( $@ ) {
            print STDERR "Cache read failed $@...\n" if DEBUG;
            Foswiki::Func::writeWarning("DBCache: Cache read failed: $@");
            $this->{_cache} = undef;
        }

        if ( $readFromFile || $removed ) {
            $this->{archivist}->sync();
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
    foreach my $cached ( $this->{_cache}->getValues()) {
        $cached->set( '.fresh', 0 );
    }

    my $readFromFile = 0;
    my @readTopic;

    $web =~ s/\./\//g;
    my $dataDir = Foswiki::Func::getDataDir()."/$web";

    #print STDERR "_updateCache from $dataDir\n";

    # load topics that are missing from the cache
    opendir(D, $dataDir) || return (0, 0, 0);
    foreach my $topic ( readdir(D) ) {
        next unless $topic =~ s/\.txt$//;
        my $topcache = $this->{_cache}->FETCH( $topic );
        if ($topcache && !uptodate( $topcache->FETCH( '.cache_file' ),
                                    $topcache->FETCH( '.cache_time' ))) {
            $this->{_cache}->remove( $topic );
            $readFromCache--;
            $topcache = undef;
        }
        if ( !$topcache ) {
            # Not in cache
            $topcache = $this->_loadTopic( $dataDir, $topic );
            if ($topcache) {
                $readFromFile++;
                push( @readTopic, $topic );
            }
        }
        $topcache->set( '.fresh', 1 ) if $topcache;

        #don't disadvantage users just because the cache is off
        last if defined($Foswiki::cfg{DBCacheContrib}{LoadFileLimit}) && 
          ( $Foswiki::cfg{DBCacheContrib}{LoadFileLimit} > 0 ) && 
            ( $readFromFile > $Foswiki::cfg{DBCacheContrib}{LoadFileLimit} );
    }
    closedir(D);

    # Find smelly topics in the cache
    my $removed = 0;
    foreach my $cached ( $this->{_cache}->getValues()) {
        if( $cached->FETCH( '.fresh' )) {
            $cached->remove( '.fresh' );
        } else {
            $this->{_cache}->remove( $cached->FETCH( 'name' ) );
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

---+++ =uptodate($file, $time)= -> boolean
Check the file time against what is seen on disc. Return 1 if consistent, 0 if inconsistent.

=cut

sub uptodate {
    my ($file, $time) = @_;
    if ( -f $file && defined( $time )) {
        my @sinfo = stat( $file );
        my $fileTime = $sinfo[9];
        if ( defined( $fileTime) && $fileTime == $time ) {
            return 1;
        }
    }
    return 0;
}

1;
