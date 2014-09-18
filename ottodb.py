#!/usr/local/otto/bin/python
# -*- coding: utf-8 -*-

import inspect

import os
import re
import sys
import time
import random
import logging

import pymongo
from pymongo import ASCENDING, DESCENDING
import bson

import traceback
import pprint


pp = pprint.PrettyPrinter()
log = logging.getLogger('otto')


def oprint(object):
    pp.pprint(dir(object))
    pp.pprint(object)
    try:
        pp.pprint(object.__dict__)
    except AttributeError:
        print 'object has no __dict__ attribute'
    try:
        pp.pprint(object.description)
    except AttributeError:
        print 'object has no description attribute'
    try:
        for key, value in object.iteritems():
            print '%s' % key, '= %s' % value
    except AttributeError:
        print 'object has no iteritems attribute'


def listy(items):
    if type(items) != list:
        items = [items]
    return items


##############################################################################
### db #######################################################################
##############################################################################


class DBObject(dict):
    def __init__(self, oid=None, otype=None):
        self['oid'] = oid
        self['otype'] = otype
    def __getattr__(self, attr):
        try:
            return self[attr]
        except KeyError:
            return None
    def __setattr__(self, attr, value):
        self[attr] = value


class DB():
    def __init__(self):
        #self.connection = pymongo.Connection()
        if sys.platform.startswith('darwin'):
            mongod_socket = os.path.expanduser('~/Library/Otto/var/mongod.sock')
        elif sys.platform.startswith('linux'):
            mongod_socket = '/usr/local/otto/var/mongod.sock'
        else:
            mongod_socket = '/usr/local/otto/var/mongod.sock'

        self.connection = pymongo.MongoClient(mongod_socket)
        self.db = self.connection.otto

        self.db.objects.create_index('otype')
        self.db.objects.create_index('album')
        self.db.objects.create_index('artist')
        self.db.objects.create_index('fileunder')
        self.db.objects.create_index('owner')
        self.db.objects.create_index('dirpath')
        self.db.objects.create_index('filename')
        self.db.objects.create_index([ ('otype', ASCENDING), ('album', ASCENDING) ])
        self.db.objects.create_index([ ('otype', ASCENDING), ('artist', ASCENDING) ])
        self.db.objects.create_index([ ('otype', ASCENDING), ('key', ASCENDING) ])
        self.db.objects.create_index([ ('otype', ASCENDING), ('owner', ASCENDING) ])
        self.db.objects.create_index([ ('otype', ASCENDING), ('dirpath', ASCENDING) ])
        self.db.objects.create_index([ ('otype', ASCENDING), ('filename', ASCENDING) ])
        self.db.objects.create_index([ ('otype', ASCENDING), (u'tags.©wrt', ASCENDING) ])
        #self.db.objects.create_index([ ('otype', ASCENDING), ('tags.\xA9wrt', ASCENDING) ])
        self.db.objects.create_index([ ('otype', ASCENDING), ('tags.TCOM', ASCENDING) ])

        self.db.connections.create_index('child')
        self.db.connections.create_index('parent')
        self.db.connections.create_index([
                ('ctype', pymongo.ASCENDING),
                ('parent', pymongo.ASCENDING) ])
        self.db.connections.create_index([
                ('ctype', pymongo.ASCENDING),
                ('child', pymongo.ASCENDING) ])
        self.db.connections.create_index([
                ('rank', pymongo.ASCENDING),
                ('parent', pymongo.ASCENDING),
                ('ctype', pymongo.ASCENDING),
                ('child', pymongo.ASCENDING) ])

        self.db.images.create_index('hash')


    def q(self, query, parameters=(), c=None):
        if not c:
            c = self.db.cursor()
        log.debug('query = %s', query)
        start_time = time.time()
        c.execute(query, parameters)
        log.debug('query finished! %.3s%s', time.time() - start_time, 's')
        log.debug('row count = %s', c.rowcount)
        return c


    def save_object(self, o):
        if not isinstance(o, dict) or not o.get('otype'):
            raise TypeError
        oid = self.db.objects.save(o)
        return oid


    def save_image(self, imagehash, imagesizesdata, mtime=False):
        # i could probably save some time by doing this check before computing the png(s)
        # (i tweaked it so that now i'm at least not doing the same image twice in a given run)
        o = self.db.images.find_one( {'hash': imagehash}, {'_id': True})
        if o:
            print 'not saving duplicate image for', imagehash
            # we might want to enable saving (upserting) so we can update an image (e.g. add additional sizes)
            return o['_id']
        o = { 'hash': imagehash }
        sizes = {}
        for size, data in imagesizesdata.iteritems():
            sizes[size] = bson.Binary( data );
        o['sizes'] = sizes
        if mtime:
            o['mtime'] = mtime
        oid = self.db.images.save(o)
        return oid

    def load_object(self, oid=None, load_parents=False):
        # otypes:
        #  1 owner
        #  5 dir
        # 10 song
        # 20 album
        # 30 artist
        # 40 fileunder
        # 50 list

        #import ipdb; ipdb.set_trace();
        if oid is None:
            raise Exception('you must specify the oid')
            
        object = None

        object = self.find_one_object(oid)

        if load_parents:
            self.load_subobjects(object, load_parents, parents=True)
            #oprint(object)
        return object


    def load_subobjects(self, object, subotype, parents=False, filteroutctypes=(5,6)):
        c = self.db.cursor()
        if parents:
            # load parents
            c.execute('select * from collection as c'
                      ' join object as o on o.oid = c.parent and c.child = ?'
                      ' join attribute as oa on oa.oid = o.oid and o.otype = ?'
                      ' order by c.child, c.rank',
                      (object['oid'], subotype,))
        else:
            ctypefilter = ' where ctype not in %s' % (filteroutctypes,) if filteroutctypes else ''
            # load children
            c.execute('select * from collection as c'
                      ' join object as o on o.oid = c.child and c.parent = ?'
                      ' join attribute as oa on oa.oid = o.oid and o.otype = ?'
                      + ctypefilter +
                      ' order by c.child, c.rank',
                      (object['oid'], subotype,))

        subobjects = []
        rows = []
        current_oid = None
        for row in c:
            if current_oid != row['o.oid']:
                if rows:
                    subobjects.append(self.load_object(rows=rows))
                    rows = []
                current_oid = row['o.oid']
            rows.append(row)
        if rows:
            subobjects.append(self.load_object(rows=rows))

        object['items'] = subobjects
        if subotype == 40:
            object['fileunder'] = subobjects
        if subotype == 30:
            object['artists'] = subobjects
        if subotype == 20:
            object['albums'] = subobjects
        elif subotype == 10:
            object['songs'] = subobjects
        elif subotype == 5:
            object['dirs'] = subobjects
        elif subotype == 1:
            object['owners'] = subobjects

        return subobjects
                    

    def add_to_connections(self, parent, child, ctype=0, rank=None, duplicates=False):
        # ctypes:
        #  1 dirs, songs, albums, artists to owner
        #  2 songs to albums
        #  3 songs to artists
        #  4 artists to albums
        #  5 primary albums to artists and/or 'various'
        #  6 secondary albums to artists and/or 'various'
        #  7 primary albums to fileunder
        #  8 secondary albums to fileunder
        # 10 dirs to dirs
        # 11 files (songs) to directory
        # 12 lists
        document = {
            'ctype': ctype,
            'parent': parent,
            'child': child,
            'rank': rank,
            }
        if not duplicates:
            if False:
              # error: doesn't return the cid TODO
              # in theory this would let us pick the new cid (_id, actually) out of the document
              # safe might not be needed?
              #self.db.connections.update(document, document, upsert=True, manipulate=True, safe=True)
              self.db.connections.update(document, document, upsert=True) # upsert!
            if self.db.connections.find_one(document):
                frame,filename,line_number,function_name,lines,index=\
                    inspect.getouterframes(inspect.currentframe())[1]
                #print "duplicate avoided! %s:%s" % (function_name, line_number)
            else:
                self.db.connections.update(document, document, upsert=True) # upsert!
            cid = None
        else:
            cid = self.db.connections.save(document)
            # error: i don't think that'll really return the cid TODO
            # probably need to set manipulate=true (and might want safe=true?)
        return cid


    def remove_from_collection(self, parent, child, ctype=0, rank=None, duplicates=False):
        # FIXME need to extend this to handle rank and duplicates
        c.execute('select * from collection as c where c.parent = ?'
                  ' and c.child = ? and ctype = ?',
                  (parent, child, ctype))
        row = c.fetchone()
        if row:
            print row['c.cid']
            c.execute('delete from collection where cid = ?', (row['c.cid'],))
            return True
        return False


    def find_song(self, filename):
        c.execute('select o.*, oa.* from object as o, attribute as oa where o.oid = oa.oid'
                  ' and o.otype = 10 and oa.attribute = "filename" and oa.value = ?',
                  (filename,))
        row = c.fetchone()
        if row and row['o.oid']:
            song = self.load_object(oid=row['o.oid'])
        else:
            song = None
        return song
        

    def dict_all_filenames(self):
        c = self.db.objects.find({'filename': {'$exists' : True}, 'dir': {'$exists' : False}}, {'filename': 1})
        filenames = {}
        for row in c:
            #print row['filename']
            #filename = row['filename'].encode('latin-1')
            #filename = row['filename'].encode('utf8')
            filename = row['filename']
            try:
                filenames[filename] += 1
            except KeyError:
                filenames[filename] = 1
        return filenames


    def find_one_object(self, q, c=None):
        object = self.db.objects.find_one(q, c)
        if object:
            object['oid'] = object['_id']
        return object


    def find_album(self,  album, dirpath=None):
        if dirpath:
            album = self.find_one_object({'otype': 20, 'dirpath': dirpath, 'album': album})
        else:
            album = self.find_one_object({'otype': 20, 'album': album})
        return album
        

    def find_artist(self, artist):
        return self.find_one_object({'otype': 30, 'artist': artist})


    def find_dir(self, filename):
        return self.find_one_object({'otype': 5, 'filename': filename})
        

    def find_owner(self, owner):
        return self.find_one_object({'otype': 1, 'owner': owner})
        

    def find_fileunder(self, key):
        return self.find_one_object({'otype': 40, 'key': key})
        

    def list_all_albums_and_their_songs(self):
        c = self.q('select * from object as o1'
                  ' join collection as c1 on c1.parent = o1.oid and o1.otype = 20'
                  ' join object as o2 on o2.oid = c1.child and o2.otype = 10')

        albums = []
        for row in c:
            albums.append((row['o1.oid'], row['o2.oid']))

        return albums


    def load_all_albums_and_their_songs(self):
        c = self.q('select * from object as o1'
                  ' join collection as c1 on c1.parent = o1.oid and o1.otype = 20'
                  ' join object as o2 on o2.oid = c1.child and o2.otype = 10')

        albums = []
        current_album = None
        for row in c:
            if not current_album or current_album['oid'] != row['o1.oid']:
                if current_album:
                    albums.append(current_album)
                current_album = DBObject(oid=row['o1.oid'], otype=20)
                current_album['items'] = []
            song = self.load_object(row['o2.oid'])
            current_album['items'].append(song)

        if current_album:
            current_album['songs'] = current_album['items']
        if current_album:
            albums.append(current_album)

        return albums


    def load_all_artists_and_their_albums(self):
        c = self.q('select * from object as o1'
                   ' join collection as c1 on c1.parent = o1.oid'
                   ' join object as o2 on o2.oid = c1.child'
                   ' join attribute as a1 on o1.oid = a1.oid'
                   ' where o1.otype = 30 and o2.otype = 20'
                   ' and a1.attribute = "artist"'
                   ' order by a1.value')

        artists = []
        current_artist = None
        for row in c:
            #oprint(row)
            #print(row['a.oid'])
            if not current_artist or current_artist['oid'] != row['o1.oid']:
                if current_artist:
                    artists.append(current_artist)
                current_artist = self.load_object(row['o1.oid'])
                current_artist['items'] = []
            album = self.load_object(row['o2.oid'])
            current_artist['items'].append(album)
        if current_artist:
            current_artist['albums'] = current_artist['items']
        if current_artist:
            artists.append(current_artist)
        return artists


    def starts_with(self, value, attribute, otype):
        filter = ''
        params = []
        filteroutctypes = (5,6)

        if len(value) == 1 and ord(value[0].upper()) in range(ord('A'), ord('Z')+1):
            filter = ' and a1.value like ?'
            params.append(value + '%')

        if value == 'num':
            filter += ' and (a1.value like ?';
            params.append('0%')
            for n in range(1, 10):
                filter += ' or a1.value like ?'
                params.append(str(n)+'%')
            filter += ')'

        if value == 'other':
            for n in range(0, 10):
                filter += ' and a1.value not like ?'
                params.append(str(n)+'%')
            for a in range(ord('A'), ord('Z')+1):
                filter += ' and a1.value not like ?'
                params.append(chr(a)+'%')
            filter += ' or a1.value like "unknown"'
        else:
            filter += ' and a1.value not like "unknown"'

        if value == 'st':
            filter += ' and a1.value like ?'
            filteroutctypes = False
        else:
            filter += ' and a1.value not like ?'
        params.append('%soundtrack%')

        if value == 'va':
            filter += ' and (a1.value like ? or a1.value like ?)'
            filteroutctypes = False
        else:
            filter += ' and a1.value not like ? and a1.value not like ?'
        params.append('various')
        params.append('various artists')

        if value == 'all':
            filter = ''
            params = []

        print filter
        print params

        c = self.q('select * from object as o1'
                   ' join attribute as a1 on o1.oid = a1.oid'
                   ' where o1.otype = ?'
                   ' and a1.attribute = ?'
                   + filter +
                   ' order by a1.value',
                   [otype, attribute] + params)

        objects = []
        for row in c:
            object = self.load_object(row['o1.oid'])
            if otype == 40:
                self.load_subobjects(object, otype-20, filteroutctypes=filteroutctypes)
            elif otype > 10:
                self.load_subobjects(object, otype-10, filteroutctypes=filteroutctypes)
            objects.append(object)

        return objects


    def search(self, otype, value, attributes, exclude_attributes=None):
        params = [otype]
        attribute_filter = ''
        filteroutctypes = (5,6)
        if attributes:
            for attribute in listy(attributes):
                if attribute_filter:
                    attribute_filter += ' or '
                attribute_filter += 'a1.attribute = ?'
            attribute_filter = ' and (' + attribute_filter + ')'
            params += listy(attributes)
        exclude_attributes_filter = ''
        if exclude_attributes:
            for attribute in listy(exclude_attributes):
                exclude_attributes_filter += ' and a1.attribute != ?'
            params += listy(exclude_attributes)
        params += ['%%'+value+'%%']

        query = (
            'select o1.oid as oid from object as o1'
            ' join attribute as a1 on o1.oid = a1.oid'
            ' where o1.otype = ?'
            + attribute_filter + exclude_attributes_filter +
            ' and a1.value like ?'
            ' order by a1.attribute, a1.value')

        c = self.q(query, params)

        oids = []
        objects = []
        for row in c:
            oid = row['oid']
            if oid not in oids:
                oids.append(oid)
                object = self.load_object(oid)
                if otype == 40:
                    self.load_subobjects(object, otype-20, filteroutctypes=filteroutctypes)
                elif otype > 10:
                    self.load_subobjects(object, otype-10, filteroutctypes=filteroutctypes)
                objects.append(object)

        return objects


    def load_song_list(self, filenames):
        otype = 10
        attribute = 'filename'
        objects = []
        print filenames
        for filename in filenames:
            print filename
            c = self.q('select * from object as o1'
                       ' join attribute as a1 on o1.oid = a1.oid'
                       ' where o1.otype = ?'
                       ' and a1.attribute = ?'
                       ' and a1.value = ?',
                       [otype, attribute, filename])

            for row in c:
                print row['o1.oid']
                print otype
                object = self.load_object(row['o1.oid'])
                if otype == 10:
                    self.load_subobjects(object, 1, parents=True)  # owner
                if otype < 20:
                    self.load_subobjects(object, 20, parents=True)
                if otype < 30:
                    self.load_subobjects(object, 30, parents=True)
                objects.append(object)

        return objects


    def load_filenamecache(self):
        print 'loading filename cache...'
        global filenamecache
        filenamecache = {}
        c = self.q('select value, oid from attribute where attribute="filename"')
        for row in c:
            filenamecache[int(row['attribute.oid'])] = row['attribute.value']
        c.close()
        print 'done.'
        

    def get_filename(self, sid):
        if not filenamecache:
            self.load_filenamecache()
        filename = filenamecache[int(sid)]
        print filename
        return filename


    def get_filename_of_first_song(self, oid):
        c = self.q('select a1.value from collection as c1'
                   ' join object as o1 on c1.parent = ? and c1.child = o1.oid'
                   ' join attribute as a1 on a1.oid = o1.oid'
                   ' and a1.attribute = "filename"'
                   ' order by c1.rank limit 1',
                   (oid,))
        row = c.fetchone()
        if row:
            #filename = str(row['attribute.value'])  # why isn't this a1.value??? cut-n-paste error maybe?
            #let's change it and see how it goes, perhaps it just wasn't working
            #filename = row['a1.value'] # wow! it does need to be attribute.value. i don't get it.
            filename = row['attribute.value']
        else:
            filename = None
        c.close()
        print filename
        return filename


    def get_filename_of_first_song_with_cover(self, oid):
        c = self.q('select a2.value as fname from attribute as a2 where a2.oid in'
                   ' ('
                   '  select c1.child from collection as c1'
                   '  join attribute as a1 on c1.parent = ? and c1.child = a1.oid'
                   '  where a1.attribute = "hascover" and a1.value = 1'
                   '  order by c1.rank limit 1'
                   ' )'
                   ' and attribute = "filename"'
                   ' limit 1',
                   (oid,))
        row = c.fetchone()
        oid = row['fname'] if row else None
        c.close()
        return oid


    def get_all_song_ids(self):
        c = self.q('select oid from object where otype = 10')

        ids = []
        for row in c:
            ids.append(row['object.oid'])

        return ids


    def get_music_root_dirs(self):
        # find all dirs that are not a child of another dir
        c = self.q('select oid from object where otype = 5'
                   ' and oid not in'
                   ' (select child from collection where ctype = 10)')

        objects = []
        for row in c:
            oprint(row['object.oid'])
            object = self.load_object(row['object.oid'])
            objects.append(object)

        return objects


    def load_dir(self, oid):
        print oid
        dir = self.load_object(oid)
        if dir:
            self.load_subobjects(dir, 5)
            self.load_subobjects(dir, 20)
            self.load_subobjects(dir, 10)
        return dir


    def add_to_list(self, user, oid):
        print user, oid
        o = self.load_object(oid)
        if o:
          owner = self.find_owner(user)
          if not owner:
              owner = DBObject(otype=1)
              owner.owner = user
              owner.oid = db.save_object(owner)
          self.add_to_connections(owner.oid, o.oid, ctype=12)


    def remove_from_list(self, user, oid):
        print user, oid
        o = self.load_object(oid)
        if o:
          owner = self.find_owner(user)
          if owner:
              self.remove_from_collection(owner.oid, o.oid, ctype=12)


    def load_lists(self, objects=False):
        c = self.q('select * from object as o'
                   ' join attribute as oa on o.oid = oa.oid'
                   ' where o.otype = 1'
                   ' order by o.oid')

        users = []
        rows = []
        current_oid = None
        for row in c:
            if current_oid != row['o.oid']:
                if rows:
                    users.append(self.load_object(rows=rows))
                    rows = []
                current_oid = row['o.oid']
            rows.append(row)
        if rows:
            users.append(self.load_object(rows=rows))

        for user in users:
            c = self.q('select child from collection where parent = ? and ctype = 12 order by cid', [user.oid])
            user.list = []
            for row in c:
                oid = row['collection.child']
                if objects:
                    object = self.load_object(oid)
                    if object.otype == 20:
                      self.load_subobjects(object, 10)
                    user.list.append(object)
                else:
                    user.list.append(oid)

        return users


    def save_musicsearchdir(self, searchdir):
        self.db.preferences.update({'key': 'searchdir'}, {'key': 'searchdir', 'value': searchdir}, upsert=True)

    def load_musicsearchdir(self):
        o = self.db.preferences.find_one({'key': 'searchdir'})
        return o['value'] if o else None


##############################################################################
### api ######################################################################
##############################################################################

class all_albums():
    def get(self):
        results = db.load_all_albums_and_their_songs()
        template = self.get_argument('template', None)
        if template:
            self.render(template, items=results)
        else:
            self.finish(json.dumps(results))

class list_all_albums():
    def get(self):
        results = db.list_all_albums_and_their_songs()
        template = self.get_argument('template', None)
        if template:
            self.render(template, items=results)
        else:
            self.finish(json.dumps(results))

class load_object():
    def get(self):
        oid = self.get_argument('oid')
        load_parents = self.get_argument('load_parents', None)
        template = self.get_argument('template', None)
        results = db.load_object(oid=oid, load_parents=load_parents)
        if template:
            self.render(template, items=results)
        else:
            self.finish(json.dumps(results))

class album_details():
    def get(self):
        oid = self.get_argument('oid')
        template = self.get_argument('template', None)
        results = db.load_object(oid=oid)
        if (results.otype in [30, 40]):
            albums = db.load_subobjects(results, 20)
        elif (results.otype == 20):
            albums = [results]
        for album in albums:
            db.load_subobjects(album, 10)
            db.load_subobjects(album, 30, parents=True)
            db.load_subobjects(album, 1, parents=True)

        if template:
            self.render(template, items=albums)
        else:
            #self.finish(json.dumps(results))
            self.finish(results)

class all_artists():
    def get(self):
        results = db.load_all_artists_and_their_albums()
        template = self.get_argument('template', None)
        if template:
            self.render(template, items=results)
        else:
            self.finish(json.dumps(results))

class all_songs():
    def get(self):
        songs = db.get_all_songs()
        results = []
        for song in songs:
            results.append(song)
        self.finish(json.dumps(results))

class some_songs():
    def get(self):
        songs = db.get_all_songs(limit=100000)
        results = []
        #for song in songs:
        while True:
            song = songs.fetchone()
            if not song:
                break
            results.append(song)
        #results = songs.fetchall()
        template = self.get_argument('template')
        if template:
            html = self.render(template, items=results)
            results = html
        else:
            json = json.dumps(results)
            results = json
            self.finish(results)

class random_song():
    def get(self):
        ids = db.get_all_song_ids()
        max = len(ids)-1
        print 'got ids for %s songs' % (max+1)
        n = random.randint(0, max)
        print 'picking ids[%s] which is id %s' % (n, ids[n])
        song = db.load_object(oid=ids[n])
        self.finish(json.dumps(song))

class starts_with():
    def get(self):
        value = self.get_argument('value')
        attribute = self.get_argument('attribute')
        otype = self.get_argument('otype')
        template = self.get_argument('template', None)
        results = db.starts_with(value, attribute, int(otype))
        if template:
            self.render(template, items=results)
        else:
            self.finish(json.dumps(results))

class search_old():
    def get(self):
        value = self.get_argument('value')
        fileunders = db.search(40, value, ['key', 'name', 'artist'])
        albums = db.search(20, value, 'album')
        songs = db.search(10, value, 'song')
        #other = db.search(10, value, None,
        #                  ['name', 'artist', 'album', 'song', 'filename', 'title', '.nam', '.ART', '.alb'])
        #results = {'fileunders': fileunders, 'albums': albums, 'songs': songs, 'other': other}
        results = {'fileunders': fileunders, 'albums': albums, 'songs': songs}
        self.finish(json.dumps(results))

class search():
    def get(self):
        value = self.get_argument('value')
        (fileunders, albums, songs) = db.search2([[40, value, ['key', 'name', 'artist'], None],
                                                [20, value, 'album', None],
                                                [10, value, 'song', None]])
        #other = db.search(10, value, None,
        #                  ['name', 'artist', 'album', 'song', 'filename', 'title', '.nam', '.ART', '.alb'])
        #results = {'fileunders': fileunders, 'albums': albums, 'songs': songs, 'other': other}
        results = {'fileunders': fileunders, 'albums': albums, 'songs': songs}
        self.finish(json.dumps(results))

class load_songs():
    def get(self): self.post()
    def post(self):
        # this is best used via. a post to allow for lots of filenames
        filenames = self.get_arguments('filename')
        print "filenames ="
        print filenames
        results = db.load_song_list(filenames)
        self.finish(json.dumps(results))

class load_fileunder():
    def get(self):
        artistoid = self.get_argument('artistoid')
        artist = db.load_object(oid=artistoid, load_parents=40)
        results = artist.fileunder
        self.finish(json.dumps(results))

class music_root_dirs():
    def get(self):
        results = db.get_music_root_dirs()
        self.finish(json.dumps(results))

class load_dir():
    def get(self):
        oid = self.get_argument('oid')
        results = db.load_dir(oid)
        self.finish(json.dumps(results))

class add_to_list():
    def post(self):
        user = self.get_argument('user')
        oid = self.get_argument('oid')
        results = db.add_to_list(user, oid)
        self.finish(json.dumps(results))

class remove_from_list():
    def post(self):
        user = self.get_argument('user')
        oid = self.get_argument('oid')
        results = db.remove_from_list(user, oid)
        self.finish(json.dumps(results))

class load_lists():
    def get(self):
        objects = self.get_argument('objects', False)
        results = db.load_lists(objects)
        self.finish(json.dumps(results))



application = [
    (r'/all_albums', all_albums),
    (r'/list_all_albums', list_all_albums),
    (r'/load_object', load_object),
    (r'/album_details', album_details),
    (r'/all_artists', all_artists),
    (r'/all_songs', all_songs),
    (r'/some_songs', some_songs),
    (r'/random_song', random_song),
    (r'/starts_with', starts_with),
    (r'/search', search),
    (r'/load_songs', load_songs),
    (r'/load_fileunder', load_fileunder),
    (r'/music_root_dirs', music_root_dirs),
    (r'/load_dir', load_dir),
    (r'/add_to_list', add_to_list),
    (r'/remove_from_list', remove_from_list),
    (r'/load_lists', load_lists),
]


try:
    db = DB()
#except pymongo.errors.AutoReconnect:
except pymongo.errors.ConnectionFailure:
    print "error: can't connect to mongodb. is it running?"
    sys.exit(1)
filenamecache = False
