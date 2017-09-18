#!/usr/bin/env python
# -*- coding: utf-8 -*-

#import pdb
# use pdb.set_trace() break

import os
import re
import sys
import codecs
import getpass
import hashlib
import unicodedata
import json

import ottodb

import chardet
import mutagen
import mutagen.mp3
import mutagen.mp4
import mutagen.flac

import StringIO
#import Image
from PIL import Image

import struct

#COVER_SIZES = ['orig', '300', '120', '40']
COVER_SIZES = ['orig', '120', '40']

# if the music dir isn't specified on the command line,
# otto will use the first directory it finds in this list:
MUSIC_DIR_SEARCH_ORDER = [
    '~/Music',
    ]

important_extensions = [
    'mp4',
    'mp3',
    'mp2',
    'mpg',
    'mpeg',
    'm4a',
    'm4b',
    #'m4p', # not useful
    'flac',
    #'wav', # not yet
    'ape',
    'mpc',
    'ofr',
    'ofs',
    'tta',
    'ogg',
    #'flv', # not yet
    'wma',
    ]

directories_to_ignore = [
    '.git',
    '.svn',
    '.hg',
    'CVS', # hopefully nobody names their band after the pharmacy. ha! allmusic has an entry!
    'RCS',
    '__MACOSX',
    #'.DS_Store', # not a dir
    #':2eDS_Store',
    ]


    # completely untested
    #    if sys.platform == 'darwin':
    #        ROOT = os.path.expanduser('~/Library/Otto')
    #    else:
    #        ROOT = os.path.dirname(os.path.abspath(__file__))
    #    jsonfile = ROOT + '/var/otto.json'


def to_unicode(val):
    if isinstance(val, unicode):
        #print ":already unicode, returning it"
        return val
    if hasattr(val, '__unicode__'):
        #print ":has __unicode__ method, using unicode()"
        return unicode(val)
    if not isinstance(val, basestring):
        #print ":not a string, using repr()"
        return repr(val)
    try:
        #print ":string, using decode()"
        encoding = 'utf-8'
        val = val.decode(encoding, 'strict')
    except (UnicodeDecodeError, UnicodeEncodeError), e:
        #print 'decoding as', encoding, 'failed:', e
        #print 'value that failed:', repr(val)
        try:
            encoding = 'iso-8859-1'  # aka 'latin-1'
            # i believe this cannot fail for iso-8859-1 as all 256 bytes of
            # iso-8859-1 may to unicode cleanly (but that doesn't mean it's a correct encoding)
            #print 'trying iso-8859-1'
            val = val.decode(encoding, 'strict')
        except (UnicodeDecodeError, UnicodeEncodeError), e:
            # even though i don't think the above can fail, but just in case:
            # (plus i wanted to preserve this chardet logic somewhere)
            print 'inconceivable: decoding as', encoding, 'failed:', e
            print 'value that failed:', repr(val)
            try:
                info = chardet.detect(val)
                encoding = info['encoding']
                print 'guessing encoding as', encoding, 'attempting to decode...'
                try:
                    val = val.decode(encoding, 'strict')
                except LookupError:
                    #print 'that failed'
                    raise UnicodeError('guessed encoding as '+encoding+' but that encoding is not available')
                except UnicodeEncodeError:
                    # i give up
                    print 'i give up'
                    val = ''

                #print 'that worked!'
            except (UnicodeDecodeError, IndexError):
                # i give up
                print 'i give up'
                val = ''
    return val


def unique_list(list):
    seen = {} 
    unique = [] 
    for item in list: 
        if item not in seen:
            unique.append(item) 
            seen[item] = True
    return unique


def pathexplode(path):
    dirs=[]
    while 1:
        path, d = os.path.split(path)
        if d != '':
            dirs.append(d)
        else:
            if path != '':
                dirs.append(path)
            break
    dirs.reverse()
    return dirs


def get_ext(filename):  # ext w/o '.'
    return os.path.splitext(filename)[1].lstrip('.')
def get_non_ext(filename):  # full path w/o ext
    return os.path.splitext(filename)[0]
def get_file(filename):  # just the filename w/o path
    return pathexplode(filename)[-1]
def get_root(filename):  # just the root of the filename w/o path or ext
    return os.path.splitext( get_file(filename) )[0]


# md5 is old school, try sha1. (wait! md5 is faster and fine for our purposes)
def md5_for_file(filename, block_size=2**24):
    md5 = hashlib.md5()
    f = open(filename, 'rb')
    while True:
        data = f.read(block_size)
        if not data:
            break
        md5.update(data)
    return md5.hexdigest()


class Progress(object):
    def __init__(self, total, start=True):
        self.total = total
        if start:
            self.start()

    def start(self, update=True):
        self.count = 0
        self.lastupdate = None
        if update:
            self.update()

    def increment(self, amount=1, update=True):
        for i in range(amount):
            self.count += 1
            if update:
                self.update()

    def finish(self):
        if (self.count <= self.total):
            self._output(100)
            # this prevents us from updating any more
            # (nobody wants a progress bar that says '101%')
            self.count = self.total+1

    # update progress bar
    def update(self):
        if self.lastupdate == None:
            self._output(0)
            self.lastupdate = self.count
        # only update every 10% or so
        if self.count < self.total and (self.count - self.lastupdate) > (self.total / 10):
            percent = (float(self.count) / float(self.total)) * 100
            self._output(percent)
            self.lastupdate = self.count
        # update every time in json output mode
        if emitJSON:
            print_json({ 'count': self.count, 'total': self.total })

    def _output(self, percent):
        # prints '0% 10% 20% ... 100%'
        print '%d%%' % percent,
        if percent < 100:
            sys.stdout.flush()
        else:
            print  # tack on the final EOL


def parse_song_info(db, filename):
    ext = get_ext(filename)
    extlc = ext.lower()

    tags = None
    try:
        if extlc in ['mp3', 'mp2', 'mpg', 'mpeg']:
            tags = mutagen.mp3.MP3(filename)
        elif extlc in ['m4a', 'm4b', 'm4p']:
            tags = mutagen.mp4.MP4(filename)
        elif extlc in ['flac']:
            tags = mutagen.flac.FLAC(filename)
        elif extlc in ['wav']:
            # gonna have to extract from the filename
            print 'skipping wav file for now %s' % filename.encode('utf-8')
        elif extlc in important_extensions:
            tags = mutagen.File(filename)
        # uncomment this if you want to check every file regardless of extension
        #else:
        #    tags = mutagen.File(filename)
    except mutagen.mp3.HeaderNotFoundError:
        pass
    except mutagen.mp4.MP4StreamInfoError:
        # mutagen.mp4.MP4StreamInfoError reports 'moov not found' on some of joe's m4a files
        print 'problem parsing mp4 file', filename.encode('utf-8')
    #except mutagen:
        #print 'mutagen has a problem with', filename.encode('utf-8')
    except IOError as (errno, strerror):
        print "IOError({0}): {1}".format(errno, strerror)
        print 'skipping', filename.encode('utf-8')

    if tags is None:
        if extlc in important_extensions:
            #print 'can\'t parse %s, skipping' % filename.encode('utf-8')
            pass
        return None

    #ottodb.oprint(tags)
    #import pprint
    #tags.pprint()

    song = ottodb.DBObject(otype=10)

    # yuck. is this really the best way for me to get the format?
    audioformat = re.match("<class 'mutagen[.]([^.]*).*'>", str(type(tags))).group(1)
    setattr(song, 'format', audioformat)
    #print 'format = %s' % audioformat

    #how do i get the ID3 tag versions (esp. to see if the names are truncated)

    # i really should move these into an info subdocument FIXME
    for key, value in tags.info.__dict__.iteritems():
        if key == 'md5_signature': # big ass integer that mongo can't handle (> 8 bytes)
            value = str(value)
        setattr(song, key, value)

    songname = None
    artist = None
    album = None
    year = None
    genre = None
    cover = None
    images = []

    if hasattr(tags, 'ID3'):
        songname = tags.get('TIT2', [None])[0]
        artist = tags.get('TPE1', [None])[0]
        album = tags.get('TALB', [None])[0]
        if tags.get('TDRC'):
            year = str(tags['TDRC'][0])[:4]
        elif tags.get('TDAT'):  # just a best guess
            year = str(tags['TDAT'][0])[:4]
        if tags.get('genre'):
            genre = tags['genre'][0]
    elif isinstance(tags, mutagen.mp4.MP4):
        songname = tags.get('\xA9nam', [None])[0]
        artist = tags.get('\xA9ART', [None])[0]
        album = tags.get('\xA9alb', [None])[0]
        if tags.get('\xA9day'):
            year = tags['\xA9day'][0][:4]
        if tags.get('\xA9gen'):  # what about 'genre'? https://code.google.com/p/mp4v2/wiki/iTunesMetadata FIXME
            genre = tags['\xA9gen'][0]
    elif extlc in ['wma']:
        songname = to_unicode(tags.get('Title', [None])[0])
        artist = to_unicode(tags.get('Author', [None])[0])
        album = to_unicode(tags.get('WM/AlbumTitle', [None])[0])
        if tags.get('WM/Year'):
            year = to_unicode(tags['WM/Year'][0])
        if tags.get('WM/Genre'):
            genre = to_unicode(tags['WM/Genre'][0])
    else:
        songname = tags.get('title', [None])[0]
        artist = tags.get('artist', [None])[0]
        album = tags.get('album', [None])[0]
        if tags.get('date'):
            year = tags['date'][0][:4]
        if tags.get('genre'):
            genre = tags['genre'][0]
    #else:
    #    song.notags = True

    if not songname:
        songname = os.path.basename(filename)
        song.nosongname = True

    song.song = songname
    song.artist = artist
    song.album = album
    song.filename = filename
    if year:
        song.year = year
    if genre:
        song.genre = genre

    # save the file extension
    song.ext = ext

    try:
        stat = os.stat(filename)
    except IOError, e:
        stat = None
    if stat:
        song.stat = {}
        # os.stat returns a special object, so copy it into a dict
        for st_item in dir(stat):
            if st_item.startswith('st_'):
                song.stat[st_item] = getattr(stat, st_item)
        song.mtime = stat.st_mtime  # more convenient and consistant with the images collection

    # hashing the entire file seems to be too slow
    # perhaps we should do it after everything is loaded
    ##md5hash = md5_for_file(filename)
    ##setattr(s, 'md5hash', md5hash)

    mime = tags.mime
    if type(mime) == list:
        for i in range(0, len(mime)):
            mime[i] = to_unicode(mime[i])
    else:
        mime = to_unicode(mime)
    setattr(song, 'mime', mime)

    #print 'mime = %s' % tags.mime

    utags = {}
    imagesdata = []
    for key, value in tags.iteritems():
        # some tags have pesky bytes in them like \xA9
        # this next line is all crap, but i wanted to keep the replace logic somewhere for later reference
        #ukey = key.('latin-1').encode('utf-8', errors='replace').replace(u'\ufffd', '?')
        # mongodb doesn't do keys that start with '$' or that have a '.' or null in them
        ukey = to_unicode(key) # this is probably a no-op
        if ukey.startswith('$'):
            ukey[0] = '?'
        ukey = ukey.replace('.', '?')
        ukey = ukey.replace('\x00', '?')

        # strip any trailing colon (which seems to be needed for APIC for some reason)
        # (i think we might not want to do this anymore now that we check for startswith('APIC')
        #if len(ukey) > 1 and ukey.endswith(':'):
        #    ukey = ukey[:-1]

        # we should consider stripping or reducing the ginormous amazon tag(s)
        # perhaps store them in another object?
        # i also wonder if they have useful cover images in there?

        # we don't want to store any image data in the song or album objects
        # we remove the image data and store it in the images collection
        # so just set the image data tag values to the mime type
        # need to make this deal with multiple images in one file FIXME
        if ukey.startswith('APIC'):
            imagesdata.append(value.data)
            value = value.mime
        if ukey.startswith('covr'):
            for data in listy(value):
                imagesdata.append(data)
            value = 'yes' # is there a way to get the mime type? FIXME
        if ukey.startswith('WM/Picture'):
            for data in listy(value):
                wma_pic = bin_to_pic(data)
                imagesdata.append(wma_pic['data'])
                value = wma_pic['mime']
        utags[ukey] = to_unicode(value)

    setattr(song, 'tags', utags)

    # the mutagen FLAC object has a different way of getting images
    if hasattr(tags, 'pictures') and tags.pictures:  # flac
        for pic in tags.pictures:
            imagesdata.append(pic.data)
            # we should save the other parameters from picture(s) (mime, height, etc... see flac.py in mutagen) FIXME

    imageids = []
    if imagesdata:
        for data in imagesdata:
            id = convert_and_save_image(filename, data)
        if id:
            imageids.append(id)

    if imageids:
        setattr(song, 'cover', imageids[0])
        # i may regret this, but i only save the images array if it has more than just the cover image in it
        if len(imageids) > 1:
            setattr(song, 'images', imageids)

    return song

#From picard
def bin_to_pic(image):
    data = image.value
    (type, size) = struct.unpack_from("<bi", data)
    pos = 5
    mime = ""
    while data[pos:pos+2] != "\x00\x00":
        mime += data[pos:pos+2]
        pos += 2
    pos += 2
    description = ""
    while data[pos:pos+2] != "\x00\x00":
        description += data[pos:pos+2]
        pos += 2
    pos += 2
    image_data = data[pos:pos+size]
    return {
        'mime': mime.decode("utf-16-le"),
        'data': image_data,}

def listy(items):
    if type(items) != list:
        items = [items]
    return items


def load_otto_json(filename):
    js = {}
    if os.path.isfile(filename):
        try:
            fp = open(filename)
            js = json.load(fp)
            # files not named otto.json keep stuff in an 'otto' dict to avoid name collisions
            if not get_file(filename) == 'otto.json':
                print pathexplode(filename)
                print get_file(filename)
                print 'not otto.json:', filename
                if js.has_key('otto'):
                    js = js['otto']
                else:
                    js = {}
        except IOError:
            pass
    return js


def apply_external_info(song, json_stack):
    # apply any supplied external otto.json files, in order
    # this should probably look in the parent json files and apply sections based on filename
    # perhaps with a global section that applies to all FIXME
    for js in json_stack:
        song.update(js)


artist_cache = {}
def find_artist(artistname):
    if artistname in artist_cache:
        return artist_cache[artistname]
    artist = db.find_artist(artistname)
    artist_cache[artistname] = artist
    return artist

def find_or_create_artist(artistname):
    artist = find_artist(artistname)
    if not artist:
        artist = ottodb.DBObject(otype=30)
        artist.artist = artistname
        artist.oid = db.save_object(artist)
        artist_cache[artistname] = artist
    return artist


album_cache = {}
def find_album(albumname, dirpath):
    if (albumname,dirpath) in album_cache:
        return album_cache[(albumname,dirpath)]
    album = db.find_album(albumname, dirpath)
    album_cache[(albumname,dirpath)] = album
    return album

def find_or_create_album(albumname, dirpath, cover=None, images=None, year=None, years=None, genre=None, genres=None):
    isnew = False
    album = find_album(albumname, dirpath)
    if not album:
        isnew = True
        album = ottodb.DBObject(otype=20)
        album.album = albumname
        album.dirpath = dirpath
        if cover: album.cover = cover
        if images: album.images = images
        if year: album.year = year
        if years: album.years = years
        if genre: album.genre = genre
        if genres: album.genres = genres
        album.oid = db.save_object(album)
        album_cache[(albumname,dirpath)] = album
    return (album, isnew)


dir_cache = {}
def find_dir(dirpath):
    if dirpath in dir_cache:
        return dir_cache[dirpath]
    dir = db.find_dir(dirpath)
    dir_cache[dirpath] = dir
    return dir

def find_or_create_dir(dirpath):
    dir = find_dir(dirpath)
    if not dir:
        dir = ottodb.DBObject(otype=5)
        dir.filename = dirpath
        dir.dir = os.path.basename(dirpath)
        dir.oid = db.save_object(dir)
        dir_cache[dirpath] = dir
    return dir


owner_cache = {}
def find_owner(ownername):
    if ownername in owner_cache:
        return owner_cache[ownername]
    owner = db.find_owner(ownername)
    owner_cache[ownername] = owner
    return owner

def find_or_create_owner(ownername):
    owner = find_owner(ownername)
    if not owner:
        owner = ottodb.DBObject(otype=1)
        owner.owner = ownername
        owner.oid = db.save_object(owner)
        owner_cache[ownername] = owner
    return owner


def remove_diacritic(input):
    '''
    Accept a unicode string, and return a normal string (bytes in Python 3)
    without any diacritical marks.
    from http://code.activestate.com/recipes/576648-remove-diatrical-marks-including-accents-from-stri/
    '''
    return unicodedata.normalize('NFKD', input).encode('ascii', 'ignore')


def fileunder_key(name):
    key = remove_diacritic(unicode(name)).lower()
    if key.find('the ') == 0 and key != 'the the':
        #key = key[4:]+', the'
        key = key[4:]
    if key.find('dj ') == 0:
        key = key[3:]+', dj'
    return key


fileunder_cache = {}
def find_fileunder(name, key=None):
    key = fileunder_key(name) if not key else key
    if key in fileunder_cache:
        return fileunder_cache[key]
    fileunder = db.find_fileunder(key)
    fileunder_cache[key] = fileunder
    return fileunder

def find_or_create_fileunder(name):
    key = fileunder_key(name)
    fileunder = find_fileunder(name, key)
    if not fileunder:
        fileunder = ottodb.DBObject(otype=40)
        fileunder.key = key
        fileunder.name = name
        fileunder.oid = db.save_object(fileunder)
        fileunder_cache[key] = fileunder
    return fileunder


def matchstrings(text, strings):
    for s in listy(strings):
        if text.find(s) > -1:
            return True
    return False


def what_fileunders(albumname, artistnames):
    albumnamelc = albumname.lower() if albumname else ''
    fileunders = []

    if matchstrings(albumnamelc, 'various') or len(artistnames) > 3:
        fileunder = find_or_create_fileunder('Various')
        fileunders.append(fileunder)
    elif matchstrings(albumnamelc, ['soundtrack', 'sound track', 'film']):
        fileunder = find_or_create_fileunder('Soundtrack')
        fileunders.append(fileunder)
    elif len(artistnames) == 0 or matchstrings(artistnames[0].lower(), 'unknown'):
        fileunder = find_or_create_fileunder('Unknown')
        fileunders.append(fileunder)

    for artistname in artistnames:
        fileunder = find_or_create_fileunder(artistname)
        fileunders.append(fileunder)

    #print fileunder
    return fileunders


def make_serializable_copy(document):
    # make a copy of the document so we can replace any binary ObjectId attributes
    # with their string equivalents so they can be JSON serialized without error
    if isinstance(document, dict):
        copy = document.copy()
        for k,v in copy.iteritems():
            if type(v) not in [int, str, unicode] and not isinstance(v, list) and not isinstance(v, dict):
                copy[k] = str(v)
            if isinstance(v, list) or isinstance(v, dict):
                copy[k] = make_serializable_copy(v)
    elif isinstance(document, list):
        copy = list(document)
        for i in xrange(len(copy)):
            v = copy[i]
            if type(v) not in [int, str, unicode] and not isinstance(v, list) and not isinstance(v, dict):
                copy[i] = str(v)
            if isinstance(v, list) or isinstance(v, dict):
                copy[i] = make_serializable_copy(v)
    else:
        raise Exception("don't know how to copy objects of type " + str(type(document)))
    return copy


def print_json(document):
    sys.stdout.stream.write(json.dumps( [ document ] ))
    sys.stdout.stream.write('\n')
    sys.stdout.stream.flush()  # because of this we probably don't need the -u flag to python anymore


class JSONout:
   def __init__(self, stream):
       self.stream = stream
   def write(self, data):
       if data == '\n':
           return
       print_json( {'stdout': data} )
   def __getattr__(self, attr):
       return getattr(self.stream, attr)


images_processed = {}
def convert_and_save_image(filename, data, sizes=COVER_SIZES):
    #!# return False #!# # i do this when debugging loading to speed things up
    md5 = hashlib.md5()
    md5.update(data)
    imagehash = md5.hexdigest()
    if images_processed.get(imagehash):
        return images_processed[imagehash]
            
    #!# return False
    try:
        origimage = Image.open(StringIO.StringIO(data))
    except IOError, e:
        print 'error:', e, 'skipping invalid image:', filename.encode('utf-8'),
        return False

    (origwidth, origheight) = origimage.size

    images = {}
    for size in sizes:
        if size == 'orig':
            newimage = origimage
        else:
            # parse out width and height, e.g. 100x200
            m = re.match('^(?P<width>[0-9]*)(x?(?P<height>[0-9]*))?$', size)
            if not m:
                raise Exception

            newwidth  = m.group('width')
            newheight = m.group('height')

            if newheight == '':
                #only one edge specified, so make the shortest edge that size
                #while retaining the aspect ratio of the original image
                newedge = int(newwidth)
                if origwidth > origheight:
                    newheight = newedge
                    newwidth = int(newedge * (origwidth / origheight))
                else:
                    newwidth = newedge
                    newheight = int(newedge * (origheight / origwidth))
            else:
                newwidth = int(newwidth)
                newheight = int(newheight)

            #print '%s x %s' % (newwidth, newheight)

            #resize the image. pick a method based on if we are down sizing or up sizing
            if (newheight > origheight) or (newwidth > origwidth):
                # some possible choices:
                # NEAREST  - use nearest neighbour
                # BILINEAR - linear interpolation in a 2x2 environment
                # BICUBIC  - cubic spline interpolation in a 4x4 environment
                newimage = origimage.resize((newwidth, newheight), Image.BICUBIC)
            else:
                # i hear ANTIALIAS is best for down sizing:
                newimage = origimage.resize((newwidth, newheight), Image.ANTIALIAS)

        newimagedata = StringIO.StringIO()
        try:
            newimage.save(newimagedata, 'PNG')
            images[size] = newimagedata.getvalue()
        except (IOError, SyntaxError), e:
            print 'failed to convert image to PNG:', filename.encode('utf-8'), e
            return False

    # don't store the orig if it's bigger than 10M (mongodo has a 16M document limit and we need to save room for our preconverted sizes)
    if len(images['orig']) > 10 * 1024 * 1024:
        print 'not storing large original image (%s>10M)' % len(images['orig']), imagehash, filename.encode('utf-8')
        del images['orig']

    try:
        mtime = os.stat(filename).st_mtime
    except (IOError, AttributeError), e:
        print 'error:', e, ' could not get mtime for', filename.encode('utf-8')
        mtime = None

    id = db.save_image(imagehash, images, mtime)
    images_processed[imagehash] = id
    return id


def add_new_songs(checklist, loaded_filenames, search_path, default_ownername):
    progress = Progress(filecount)
    
    for dirpath, dirs, files in checklist:
        notifiedthisdir = False
        otto_json = load_otto_json(dirpath + '/otto.json')
        if otto_json:
            print 'otto.json:', otto_json

        filenames = []
        for f in files:
            filenames.append( os.path.join(dirpath, f) )

        # make a list of the new songs in this directory
        # adding them to the database if necessary
        songlist = []
        for filename in filenames:
            if filename not in loaded_filenames:
                if not notifiedthisdir:
                    print 'new', dirpath.encode('utf-8')
                    notifiedthisdir = True

                song = parse_song_info(db, filename)
                if not song:
                    # couldn't parse it, ignore it
                    print "error: could not parse %s" % (filename.encode('utf-8'))
                    continue

                file_json = load_otto_json(get_non_ext(filename) + '.json')
                apply_external_info(song, [otto_json, file_json])

                song.oid = db.save_object(song)
                songlist.append(song)

        # list and add the artists if they are not already in the database
        artistlist = []
        for song in songlist:
            for artistname in listy(song.artist):
                if artistname not in artistlist:
                    artist = find_or_create_artist(artistname)
                    artistlist.append(artistname)

        # list and add the albums if they are not already in the database
        # most directories should only have one album in them, but not always
        albumlist = []
        newalbumslist = []
        for song in songlist:
            for albumname in listy(song.album):
                if albumname not in albumlist:
                    imagelist = []
                    yearlist = []
                    genrelist = []
                    # let's associate all the song images with the album
                    # the first image found (in song order) will become the album cover
                    for song2 in songlist:
                        if albumname in listy(song2.album):
                            # .images will also contain the cover as the first image
                            # but .images only exists if there are more images than just the cover
                            if song2.images:
                                imagelist.extend(song2.images)
                            elif song2.cover:
                                imagelist.append(song2.cover)
                            if song2.year: yearlist.append(song2.year)
                            if song2.genre: genrelist.append(song2.genre)
                    cover = None
                    images = None
                    if imagelist:
                        cover = imagelist[0]
                        imagelist = unique_list(imagelist) # eliminate duplicates
                        if len(imagelist) > 1: images = imagelist
                    year = None
                    years = None
                    genre = None
                    genres = None
                    if yearlist:
                        year = yearlist[0]
                        yearlist = unique_list(yearlist) # eliminate duplicates
                        for y in yearlist[1:]:
                            try:
                                if int(year) < int(y): year = y
                            except ValueError:
                                pass
                    if len(yearlist) > 1: years = yearlist
                    if genrelist:
                        genre = genrelist[0]
                        genrelist = unique_list(genrelist) # eliminate duplicates
                        if len(genrelist) > 1: genres = genrelist
            
                    (album, isnew) = find_or_create_album(albumname, dirpath, cover, images, year, years, genre, genres)

                    albumlist.append(albumname)
                    if isnew:
                        newalbumslist.append(album)
                        

        ### now let's make the connections

        # add dir
        (dirhead, dirtail) = os.path.split(dirpath)
        dir = find_or_create_dir(dirpath)
        if dirpath != search_path:
            dirparent = find_or_create_dir(dirhead)
            # connect dirs to dirs
            db.add_to_connections(dirparent['oid'], dir['oid'], 10, duplicates=False)


        # connect files (songs) to directory
        for song in songlist:
            db.add_to_connections(dir['oid'], song['oid'], 11)

        
        # look in the path for dirs that look like email addresses to use as the ownername
        ownername = None
        dirs = pathexplode(dirpath)
        n = 0
        for d in dirs:
            n += 1
            #if n > 1 and n < len(dirs)-1:  # don't check the last two (album and song presumably)
            if n > 1 and n < len(dirs):  # don't check the last two (album and song presumably)
            #if True:  # override depth check
                # this solves the 'Heart' problem but
                # without the -1 it might find albums/artists that have email addresses as titles
                if re.match('^[^@ ]+[@][a-zA-Z0-9._-]*$', d):
                    ownername = d
                    #break # nah, keep searching, there might be a more specific sub dir
        if not ownername:
            if 'owner' in otto_json:
                ownername = otto_json['owner']   # i suspect the logic above means this fails if owner is set by dir name in path FIXME
            else:
                ownername = default_ownername
        owner = find_or_create_owner(ownername)

        # connect dirs to owner
        db.add_to_connections(owner['oid'], dir['oid'], 1, duplicates=False)
        if dirpath != search_path:
            db.add_to_connections(owner['oid'], dirparent['oid'], 1, duplicates=False)

        # connect songs to owner
        for song in songlist:
            db.add_to_connections(owner['oid'], song['oid'], 1, duplicates=False)

        # connect albums to owner
        for albumname in albumlist:
            album = find_album(albumname, dirpath)
            db.add_to_connections(owner['oid'], album['oid'], 1, duplicates=False)

        # connect artists to owner
        for artistname in artistlist:
            artist = find_artist(artistname)
            db.add_to_connections(owner['oid'], artist['oid'], 1, duplicates=False)

        # connect songs to albums
        for albumname in albumlist:
            album = find_album(albumname, dirpath)
            rank = 0
            for song in songlist:
                for albumname in listy(song['album']):
                    if albumname == album['album']:
                        rank += 1
                        # need to pick some real ctype values
                        db.add_to_connections(album['oid'], song['oid'], 2, rank=rank)

        # connect songs to artists
        for artistname in artistlist:
            artist = find_artist(artistname)
            for song in songlist:
                for artistname in listy(song['artist']):
                    if artistname == artist['artist']:
                        # need to pick some real ctype values
                        db.add_to_connections(artist['oid'], song['oid'], 3)

        # connect artists to albums
        artists_processed = {}
        for albumname in albumlist:
            album = find_album(albumname, dirpath)
            for song in songlist:
                for albumname in listy(song['album']):
                    if albumname == album['album']:
                        for artistname in listy(song['artist']):
                            artist = find_artist(artistname)
                            if artist['oid'] not in artists_processed:
                                # need to pick some real ctype values
                                db.add_to_connections(artist['oid'], album['oid'], 4)
                                artists_processed[artist['oid']] = True

        # connect albums to artists and/or 'various'
        # new file under type? it would go here
        for albumname in albumlist:
            album = find_album(albumname, dirpath)
            albumartists = []
            for song in songlist:
                for albumname in listy(song['album']):
                    if song['artist'] and albumname == album['album']:
                        for artistname in listy(song['artist']):
                            found = find_artist(artistname)
                            if found not in albumartists:
                                albumartists.append(found)
            if albumartists:
                if len(albumartists) < 3:
                    # it just has one or two artists, pick the first one as primary
                    # and add any additional as secondary
                    ctype = 5
                    for artist in albumartists:
                        db.add_to_connections(artist['oid'], album['oid'], ctype)
                        ctype = 6  # 5 is primary, 6 is secondary (for now, need to pick real values)
                else:
                    #i'm thinking 'various' and 'soundtrack' (and maybe 'unknown') might want to be their own otype
                    #but for now:
                    various = find_or_create_artist('Various')
                    db.add_to_connections(various['oid'], album['oid'], 5)

                    for artist in albumartists:
                        db.add_to_connections(artist['oid'], album['oid'], 6)
            else:
                # no artists listed for this album
                # what should i do with it? put it under 'unknown'? or maybe 'Various'?
                print 'album with no artists, oid =', album.get('oid'), album.get('dirname')
                unknown = find_or_create_artist('Unknown')
                db.add_to_connections(unknown['oid'], album['oid'], 5) # 5?
                    
            # we probably need to do more with 'Soundtracks' here
            if album['album']:
                albumlc = album['album'].lower()
                if albumlc.find('soundtrack') > -1 or albumlc.find('sound track') > -1:
                    soundtrack = find_or_create_artist('Soundtrack')
                    db.add_to_connections(soundtrack['oid'], album['oid'], 5)
                
            # iTunes has a secondary artists field 'aART' and a collections field
            # we should do something with them here someday

        fileunders = []
        # connect albums to fileunder
        for albumname in albumlist:
            album = find_album(albumname, dirpath)
            albumartistnames = []
            for song in songlist:
                for albumname in listy(song['album']):
                    if song['artist'] and albumname == album['album']:
                        for artistname in listy(song['artist']):
                            albumartistnames.append(artistname)
            albumartistnames = unique_list(albumartistnames)

            fileunders = what_fileunders(album['album'], albumartistnames)

            done = {} # keep from upserting multiple times
            if fileunders:
                ctype = 7
                for fileunder in fileunders:
                    key = "%s-%s-%s" % (fileunder['oid'], album['oid'], ctype)
                    if key not in done:
                        db.add_to_connections(fileunder['oid'], album['oid'], ctype)
                        done[key] = True
                    else:
                        #print 'skipped upsert (fileunder)'
                        pass
                    ctype = 8  # 7 is primary, 8 is secondary (for now, need to pick real values)

                # stash the fileunders in the newalbums object (if the album is in the list)
                # not so that they'll be saved (the save has already happened), but so
                # that they will be sent with the JSON in emitJSON below for the ui to use
                for newalbum in newalbumslist:
                    if albumname is newalbum.albumname:
                        newalbum['fileunders'] = fileunders
                        break

        if emitJSON:
            for newalbum in newalbumslist:
                info = make_serializable_copy(newalbum)
                info['fileunder'] = make_serializable_copy(fileunders)
                songs = []
                for song in songlist:
                    if album['album'] in listy(song['album']):
                        songs.append(make_serializable_copy(song))
                info['songs'] = songs
                print_json(info)


        progress.increment(len(files))

    progress.finish()


def build_list_of_files(search_dir):
    """
    build of a list of files to be checked, skipping files and directories we don't care about
    also skips files and directories that don't encode to unicode cleanly
    uses os.walk() to find all files and directories of interest
    returns an array of tuples containing (dirpath, dirs, files), and a count of files found
    just like os.walk() does, except we filter out stuff we are not interested in
    """

    checklist = []
    filecount = 0

    fsencoding = sys.getfilesystemencoding()
    print 'using %s as the file system encoding' % fsencoding

    #search_dir = search_dir.encode('utf-8')
    """
    os.walk returns unicode if passed a unicode string.
    but this breaks os.walk (posixpath.py actually) if filenames are encoded funny
    (an exception is thrown, thus losing your place in the directory walking).
    so we can't really use it. instead we do the unicode conversions
    ourselves and skip the filenames that don't convert cleanly.
    we need to do this even if the filesystem encoding is already utf-8 or unicode
    as some filenames might have been copied from somewhere else and might
    not be encoded correctly. a different approach would be to keep all
    filename and directories as raw byte strings, but that causes other problems,
    especially with storing and retrieving from various databases which want utf-8,
    or where it's painful to work with binary data elements (perhaps i'll regret not
    doing it this way).
    going from byte strings to anything else seems to be a one way process in python 2.7
    as far as i can tell, so even if we store the raw bytes in the database, i don't
    know how to get it back to something python can use to open the file later
    (python 3 should help here).
    (i now know this is wrong, str are 8-bit strings, see unicode.py)
    some things to remember: windows uses mbcs encoding sometimes
    convmv is a potentially useful utility for fixing or finding badly encoded filenames
    repr() might be a way to convert back to bytestrings in python 2.7 (it let's you print
    them out intact at least)
    """

    for dirpath, dirs, files in os.walk(search_dir, topdown=True, followlinks=False):
        # sort the directories so the songs are in order based on their filenames (01... 02... etc)
        dirs.sort(key=str.lower)  # these sorts might be unnecessary
        files.sort(key=str.lower) # wait! needed in linux but not macos. hmm.
        # these will need to be converted to unicode.lower if we ask os.walk to return unicode

        # we need 'topdown' specified in os.walk for this to have any effect in os.walk
        for ignoredir in directories_to_ignore:
            if ignoredir in dirs:
                dirs.remove(ignoredir)

        # you could comment this out to scan every file regardless of ext
        # (but parse_song_info() will need tweaking too)
        # walk the list backwards so the indexes stay valid as we delete items
        for i in xrange(len(files) - 1, -1, -1):
            if get_ext(files[i]).lower() not in important_extensions:
                del files[i]

        # convert things to unicode
        try:
            udirpath = dirpath.decode(fsencoding, 'strict')
        except UnicodeError:
            # this should only ever happen on the very first directory, as
            # the subdirs will be checked below before we go in to them
            print "skipping directory %s, can't convert it to unicode" % dirpath
            next

        udirs = []
        for dir in dirs:
            try:
                udir = dir.decode(fsencoding, 'strict')
                udirs.append(udir)
            except UnicodeError:
                print "skipping directory %s, can't convert it to unicode" % os.path.join(dirpath, dir)
                dirs.remove(dir)

        ufiles = []
        for file in files:
            try:
                ufile = file.decode(fsencoding, 'strict')
                ufiles.append(ufile)
            except UnicodeError:
                print "skipping file %s, can't convert it to unicode" % os.path.join(dirpath, file)
                files.remove(file)

        checklist.append( ( udirpath, udirs, ufiles ) )
        filecount += len(files)

    return (checklist, filecount)


############################################################


emitJSON = False

if __name__ == '__main__':
    #if (sys.stdout.encoding is None or sys.stdout.encoding == 'ascii'):
    #    # we could try setting PYTHONIOENCODING=UTF-8 and then re-running ourself, but let's try this for now:
    #    sys.stdout = codecs.getwriter('utf8')(sys.stdout)
    #    sys.stderr = codecs.getwriter('utf8')(sys.stderr)

    if len(sys.argv) > 1:
        if sys.argv[1] == '-j':
          emitJSON = True
          sys.argv.pop(1)

    if emitJSON:
        sys.stdout=JSONout(sys.stdout)

    db = ottodb.DB()

    search_dir = None
    if len(sys.argv) == 2:
        search_dir = sys.argv[1]
    else:
        search_dir = db.load_musicsearchdir()
        if search_dir:
            search_dir = str(search_dir)
            print 'loaded search_dir', search_dir, 'from preferences'
        else:
            for check_dir in MUSIC_DIR_SEARCH_ORDER:
                check_dir = os.path.expanduser(check_dir)
                if os.path.isdir(check_dir):
                    search_dir = check_dir
                    print 'defaulting to %s as the search_dir' % search_dir.encode('utf-8')
                    break
    if not search_dir:
        print 'error: <search_dir> not specified, no previous default found, and none of the default dirs were found.'
        sys.exit(1)

    db.save_musicsearchdir(search_dir)
    
    print 'looking for songs in %s...' % search_dir.encode('utf-8')
    (checklist, filecount) = build_list_of_files(search_dir)
    print 'found %s songs in %s' % (filecount, search_dir.encode('utf-8'))

    loaded_filenames = db.dict_all_filenames()
    print '%s songs currently in the database' % (len(loaded_filenames))

    newlist = []
    oldfiles = {}
    olddirs = {}
    newcount = 0
    for dirpath, dirs, files in checklist:
        newfiles = []
        for f in files:
            filename = os.path.join(dirpath, f)
            if filename not in loaded_filenames:
                newfiles.append( f )
            else:
                try:
                    oldfiles[filename] += 1
                except KeyError:
                    oldfiles[filename] = 1
        if newfiles:
            newlist.append( (dirpath, dirs, newfiles) )
        newcount += len(newfiles)
        try:
            olddirs[dirpath] += 1
        except KeyError:
            oldfiles[dirpath] = 1
        
    print 'found %s new song%s' % (newcount, 's' if newcount != 1 else '')

    missing = 0
    for f in loaded_filenames:
        if f not in oldfiles and f not in olddirs:
            missing += 1
            #print 'missing %s' % (f)
    if missing:
        print 'warning: %s songs in database not found in %s' % (missing, search_dir.encode('utf-8'))

    find_or_create_dir(search_dir)
    add_new_songs(checklist, loaded_filenames, search_dir, getpass.getuser())
    
    print 'done.'
