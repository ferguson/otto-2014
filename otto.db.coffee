_ = require 'underscore'
fs = require 'fs'
net = require 'net'
mongodb = require 'mongodb'
child_process = require 'child_process'

otto = global.otto


module.exports = global.otto.db = do ->  # note the 'do' causes the function to be called
  db = {}


  mongo = null
  c = {}
  #collections_inuse = ['objects', 'connections', 'images', 'accesslog', 'listeners', 'queues', 'events']
  collections_inuse = ['objects', 'connections', 'images', 'events']
  filenamecache = null


  db.assemble_dbconf = ->
    db.dbconf =
      db: 'otto'
      host: otto.OTTO_VAR + '/mongod.sock'
      domainSocket: true
      #host: 'localhost'
      #port: 8777
      #username: 'admin'   # optional
      #password: 'secret'  # optional
      collection: 'sessions'  # only for connect-mongo, optional, default: sessions

      file:              "#{otto.OTTO_VAR}/mongodb.conf"
      db_directory:      "#{otto.OTTO_VAR_MONGODB}"
      #log_file:          "#{otto.OTTO_VAR}/mongod.log"
      pid_file:          "#{otto.OTTO_VAR}/mongod.pid"
      socket_file:       "#{otto.OTTO_VAR}/mongod.sock"  # must end in .sock for pymongo to work
      #bind_ip:           "localhost"
      port:              8777 # not really used when using a unix domain socket (but still required?)
      mongod_executable: "#{otto.MONGOD_EXECUTABLE}"

    db.dbconf.text = """
      # auto generated (and regenerated) by otto, don't edit

      dbpath = #{db.dbconf.db_directory}
      pidfilepath = #{db.dbconf.pid_file}
      bind_ip = #{db.dbconf.socket_file}
      #bind_ip = #{db.dbconf.bind_ip}
      port = #{db.dbconf.port} # not really used, socket file on previous line is used instead
      nounixsocket = true  # suppresses creation of a second socket in /tmp
      nohttpinterface = true
      journal = on
      noprealloc = true
      noauth = true
      #verbose = true
      quiet = true
      profile = 0  # don't report slow queries
      slowms = 2000  # it still prints them to stdout though, this'll cut that down

      """  # blank line at the end is so conf file has a closing CR (but not a blank line)

    return db.dbconf


  db.spawn = (callback) ->
    # see if there is an existing mongod by testing a connection to the socket
    testsocket = net.connect db.dbconf.socket_file, ->
      # mongod process already exists, don't spawn another one
      console.log "using existing mongod on #{db.dbconf.socket_file}"
      testsocket.destroy()

      callback()

    testsocket.on 'error', (err) ->
      #console.log 'error', err
      testsocket.destroy()
      console.log "no existing mongod found, spawning a new one on #{db.dbconf.socket_file}"
      console.log "...using executable #{db.dbconf.mongod_executable}"
      # we wait until now to write the conf file so we don't step on existing conf files for an existing mongod
      fs.writeFile db.dbconf.file, db.dbconf.text, (err) ->
        if err then throw err
        opts =
          #stdio: [ 'ignore', 'ignore', 'ignore' ]
          detached: true
          #env :
          #  DYLD_FALLBACK_LIBRARY_PATH: otto.OTTO_LIB
          #  LD_LIBRARY_PATH: otto.OTTO_LIB
        if otto.OTTO_SPAWN_AS_UID
          opts.uid = otto.OTTO_SPAWN_AS_UID
        child = child_process.spawn db.dbconf.mongod_executable, ['-f', db.dbconf.file], opts
        child.unref()
        mongod_says = (data) ->
          process.stdout.write 'mongod: ' + data # i could also color this differently, fun!
        child.stdout.on 'data', mongod_says
        child.stderr.on 'data', mongod_says
        child.on 'exit', (code, signal) ->
          return if otto.exiting
          console.log "mongod exited with code #{code}"
          if signal then console.log "...and signal #{signal}"

          throw new Error 'mongod went away!'  # i guess we could wait and try reconnecting? FIXME

        otto.misc.wait_for_socket db.dbconf.socket_file, 1500, (err) ->  # needed to be > 500 for linux
          if err then throw new Error err
          callback()


  db.kill_mongodSync = ->
    # needs to be Sync so we finish before event loop exits
    otto.misc.kill_from_pid_fileSync otto.OTTO_VAR + '/mongod.pid'


  db.init = (callback) ->
    db.assemble_dbconf()
    db.spawn ->
      db.connect db.dbconf.db, db.dbconf.host, db.dbconf.port, (err) ->
        if err
          "mongodb does not appear to be running"
          throw err
        #process.nextTick ->  # not sure this is really necessary
        callback()


  db.connect = (database='otto', hostname='localhost', port=27017, callback=no) ->
    mongo = new mongodb.Db(database, new mongodb.Server(hostname, port, {}), {safe:true, strict:false})

    mongo.open (err, p_client) ->
      if err
        if callback then callback "error trying to open database #{database} on #{hostname}:#{port}: #{err}"
        return
      attach_collections collections_inuse, ->
        c.objects.count (err, count) ->
          if err then throw new Error "database error trying to count 'objects' collection: #{err}"
          console.log "connected to database #{database} on #{hostname}:#{port}"
          s = if count != 1 then 's' else ''
          console.log "#{count} object#{s}"
          if count < 5
            console.log 'we have an empty database!'
            db.emptydatabase = true
          else
            db.emptydatabase = false
          if count > 200000
            console.log 'we have a large database!'
            db.largedatabase = true
          else
            db.largedatabase = false

          #if not c.events.isCapped()
          #  console.log 'events collection is not capped'
          #else
          #  console.log 'events collection is capped'

          # couldn't get this to work. perhaps runCommand is missing from my mongodb driver?
          #if not c.events.isCapped
          #  console.log 'capping events collection'
          #  p_client.runCommand {"convertToCapped": "events", size: 100000}

          #console.dir p_client
          #p_client.createCollection 'events', {'capped':true, 'size':100000}, ->
          #p_client.createCollection 'events', ->
          #  if not c.events.isCapped
          #    console.log 'events collection is not capped'
          #  else
          #    console.log 'events collection is capped'

          if callback
            callback()


  # lookup a list of connections by name and assign them to c.<collection_name>
  attach_collections = (collection_names, callback) ->
    lookupcount = collection_names.length
    if lookupcount
      for name in collection_names
        do (name) ->
          mongo.collection name, (err, collection) ->
            if err then throw new Error "database error trying to attach to collection '#{name}': #{err}"
            c[name] = collection
            if --lookupcount is 0
              callback()
    else
      callback()


  db.save_event = (e, callback) ->
    _id = c.events.save e, (err, eSaved) ->
      callback eSaved._id


  db.save_object = (o, callback) ->
    if not o.otype? and o.otype
      throw new Error 'object need an otype to be saved'
    oid = c.objects.save o, (err, oSaved) ->
      callback oSaved._id


  db.load_object = (ids=null, load_parents=no, callback) ->
    # otypes:
    #  1 owner
    #  5 dir
    # 10 song
    # 20 album
    # 30 artist
    # 40 fileunder
    # 50 list
    if not ids
      console.log "load_object: no id(s) given"
      ids = []
    if ids instanceof Array
      returnarray = true
    else
      returnarray = false
      ids = [ids]
    bids = ids.map (id) -> new mongodb.ObjectID(String(id)) # get_random_songs needed this for some odd reason!
    q = { '_id': { '$in': bids } }
    c.objects.find(q).toArray (err, objects) ->
      if err then throw new Error "database error trying to load objects #{ids}: #{err}"
      if not objects
        callback null
        return
      for object in objects
        object.oid = object['_id']  # for backwards compatability
      if load_parents
        lookupcount = objects.length
        for object in objects
          db.load_subobjects object, load_parents, yes, [5,6], ->
            lookupcount--
            if lookupcount is 0
              if returnarray
                callback objects
              else
                callback objects[0]
       else
          if returnarray
            callback objects
          else
            callback objects[0]


  # alias because i keep mistyping it
  db.load_objects = db.load_object

  db.load_subobjects = (objectlist, subotype, parents=no, filteroutctypes=[5,6], callback) ->
    if not objectlist then throw new Error "load_object: you must supply the object(s)"
    objects = [].concat objectlist  # make array of array or single object
    lookupcount = objects.length
    # we should optimize this to be a single query instead of this loop FIXME
    if not objects.length
      callback objectlist
    else
      for o in objects
        do (o) ->  # makes a closure so we can preserve each version of 'o' across the async calls below
          if parents
            q = { child: o._id }
          else
            q = { parent: o._id }
          # sort on _id, rank here? or do we need to sort after since they are not joined? TODO
          c.connections.find(q).toArray (err, results) ->
            if err then throw new Error "database error fetching list of subobjects for #{o._id}: #{err}"
            subids = results.map (i) -> if parents then i.parent else i.child
            q = { '_id': { '$in': subids } }
            if subotype
              q.otype = Number(subotype)
            c.objects.find(q).toArray (err, subobjects) ->
              if err then throw new Error "database error loading subobjects for #{o._id}: #{err}"
              for subobject in subobjects
                subobject.oid = subobject['_id']  # for backward compability
              switch Number(subotype)
                when 40 then o.fileunder = subobjects
                when 30 then o.artists = subobjects
                when 20 then o.albums = subobjects
                when 10 then o.songs = subobjects
                when  5 then o.dirs = subobjects
                when  1 then o.owners = subobjects

              lookupcount--
              if lookupcount is 0
                callback objectlist


  db.load_image = (id, size, callback) ->
      bid = new mongodb.ObjectID(id)
      if not size then size = 'orig'
      fields = {}
      fields["sizes.#{size}"] = 1
      c.images.findOne { _id: bid }, fields, (err, image) ->
        if err
          callback null
          return
        if image and image.sizes and image.sizes[size]
          callback image.sizes[size].buffer
          return
        if size == 'orig'
          callback null
          return
        console.log "image size #{size} not found, trying orig"
        c.images.findOne { _id: bid }, { 'sizes.orig': 1 }, (err, image) ->
          if err
            callback null
            return
          if image and image.sizes and image.sizes.orig
            callback image.sizes.orig.buffer
            return
          callback null


  db.add_to_connections = (parent, child, ctype, rank, callback) ->
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

    # FIXME need to extend this to handle rank and duplicates
    # upsert pattern yanked from https://github.com/mongodb/node-mongodb-native/issues/29

    #id = mongodb.bson_serializer.ObjectID(null)
    id = mongodb.ObjectID(null)
    doc =
      '_id':    id
      'ctype':  ctype
      'parent': parent
      'child':  child
      'rank':   rank
    c.connections.update {'_id': id}, doc, upsert: true, (err, connection) ->
      if err
        callback null
      else
        console.log 'connection._id', connection._id  # this isn't the way to get the new _id
        callback connection


  db.remove_from_connections = (id, callback) ->
    c.connections.remove {'_id': id}, (err, num) ->
      if err then throw new Error err
      callback num


  # load album (or artist, or fileunder) details
  db.album_details = (oid, callback) ->
    result = null
    lookupcount = 1
    # lookup the id, see if it's an album or an artist or a fileunder
    db.load_object oid, false, (object) ->
      result = object
      if not result
        callback result
        return
      if result.otype in [30, 40]  # artist or fileunder
        db.load_subobjects result, 20, no, [5,6], phasetwo
      else if result.otype == 20
        phasetwo [result]
      else
        phasetwo result
    phasetwo = (subobjects) ->
      if result.otype in [30, 40]
        further = result.albums
      else
        further = [result]
      lookupcount = 3*further.length
      if not further.length
        callback result
      else
        for o in further
            db.load_subobjects o, 10, no,  [5,6], phasethree
            db.load_subobjects o, 30, yes, [5,6], phasethree
            db.load_subobjects o, 1,  yes, [5,6], phasethree
    phasethree = (subobjects) ->
      lookupcount--
      if lookupcount is 0
        callback result


  db.starts_with = (value, attribute, otype, nochildren, callback) ->
    elapsed = new otto.misc.Elapsed()
    filter = {}
    params = []
    filteroutctypes = [4,6]

    order = {}
    order[attribute] = 1

    if value.length == 1 and value.toLowerCase() in 'abcdefghijklmnopqrstuvwxyz0123456789'
      filter[attribute] = ///^#{value}///i
    else switch value

      when 'num'
        filter[attribute] = ///^[0-9]///

      when 'other'
        filter[attribute] = {'$in': [ ///^[^0-9a-z]///i, 'unknown' ]}

      when 'st'
        filter[attribute] = ///\bsoundtrack\b///i
        filteroutctypes = False

      when 'va'
        filter[attribute] = {
          '$in': [
            ///\bvarious\b///i,
            ///\bartists\b///i,
            ///\bvarious artists\b///i
          ]
        } # why yes, i *do* know the third regexp is redundant
        filteroutctypes = False

      when 'all'
        filter = {}
        order = {year: 1, album: 1}

    filter['otype'] = otype

    # i don't think this does anything when used on the objects collection (only connections have ctypes)
    if filteroutctypes
      filter['ctype'] = { '$nin': filteroutctypes }

    objects = []
    object_lookup = {}
    # maybe someday we can figure out how to 'stream' these results (or maybe page 'em)
    # ...actually, the bottleneck seems to be in rendering large result sets on the client
    # side, not in getting the results from mongo or transmitting them to the client
    c.objects.find(filter).sort(order).each (err, object) ->
      if err then throw new Error "error searching for objects with #{attribute} #{value}: #{err}"

      if object
        object.oid = object['_id']
        objects.push(object)
        object_lookup[object._id] = object
      else
        console.log "#{elapsed.seconds()} objects loaded"
        subotype = no
        if otype == 40
          subotype = 20
        else if otype > 10
          subotype = otype - 10
        else
          subotype = null

        if !subotype or nochildren
          callback objects
          return

        oids = objects.map (o) -> o._id

        parents = no  # huh? perhaps overriding the value from above?
        if parents
          q = { 'child': {'$in': oids} }
        else
          q = { 'parent': {'$in': oids} }
        if filteroutctypes then q.ctype = {'$nin': filteroutctypes}

        c.connections.find(q).toArray (err, connections) ->
          if err then throw new Error "database error fetching list of subobjects for starts_with #{attribute} #{value} #{err}"
          console.log "#{elapsed.seconds()} connections loaded"

          subattribute = db.attach_point subotype

          suboids = connections.map (i) -> if parents then i.parent else i.child
          subobjects = []
          subobject_lookup = {}
          #missing sorting on rank here? FIXME
          c.objects.find({ '_id': { '$in': suboids }, 'otype': subotype }).each (err, subobject) ->
            if err then throw new Error "database error loading subobjects for starts_with #{attribute} #{value}: #{err}"

            if subobject
              subobject.oid = subobject['_id']
              subobjects.push(subobject)
              subobject_lookup[subobject._id] = subobject
            else
              for connection in connections
                if parents
                  obj = object_lookup[connection.child]
                  sub = subobject_lookup[connection.parent]
                else
                  obj = object_lookup[connection.parent]
                  sub = subobject_lookup[connection.child]
                if not sub
                  continue
                if obj[subattribute]
                  obj[subattribute].push(sub)
                else
                  obj[subattribute] = [sub]

              console.log "#{elapsed.seconds()} subobjects loaded"
              console.log subobjects && subobjects.length

              callback objects


  db.attach_point = (otype) ->
    switch Number(otype)
      when 40 then return 'fileunder'
      when 30 then return 'artists'
      when 20 then return 'albums'
      when 10 then return 'songs'
      when  5 then return 'dirs'
      when  1 then return 'owners'
    return ''


  db.attach_parents = (objects, options, callback) ->
    ids = objects.map (o) -> o._id
    # match connections against child to find parents
    find = { 'child': {'$in': ids}, 'ctype': {'$nin':[4,6]} }
    c.connections.find(find).toArray (err, connections) ->
      if err then throw new Error "error fetching parent connections: #{err}"
      console.log connections.length, 'connections'
      parentids = connections.map (i) -> i.parent
      otypes = [].concat (options.otype || 40)
      find = { '_id': { '$in': parentids }, 'otype': {'$in':otypes} }
      sort = { 'child': 1, 'rank':1 }
      c.objects.find(find).sort(sort).toArray (err, parents) ->
        if err then throw new Error "error loading parent objects: #{err}"
        #console.log parents.length, 'parents'
        object_lookup = {}
        for object in objects
          object_lookup[object._id] = object
        parent_lookup = {}
        for parent in parents
          parent_lookup[parent._id] = parent

        # attach 'em
        for connection in connections
          object = object_lookup[connection.child]
          parent = parent_lookup[connection.parent]
          if not parent
            continue
          attribute = db.attach_point parent.otype
          if attribute
            if not object[attribute]
              object[attribute] = []
            object[attribute].push parent

        callback objects


  db.attach_children = (objects, options, callback) ->
    ids = objects.map (o) -> o._id
    # match connections against parent to find children
    find = { 'parent': {'$in': ids}, 'ctype': {'$nin':[4,6]} }
    c.connections.find(find).toArray (err, connections) ->
      if err then throw new Error "error fetching child connections: #{err}"
      #console.log connections.length, 'connections'
      childids = connections.map (i) -> i.child
      otypes = [].concat (options.otype || 1)
      find = { '_id': { '$in': childids }, 'otype': {'$in':otypes} }
      sort = { 'child': 1, 'rank':1 }
      c.objects.find(find).sort(sort).toArray (err, children) ->
        if err then throw new Error "error loading child objects: #{err}"
        #console.log children.length, 'children'
        object_lookup = {}
        for object in objects
          object_lookup[object._id] = object
        child_lookup = {}
        for child in children
          child_lookup[child._id] = child

        # attach 'em
        for connection in connections
          object = object_lookup[connection.parent]
          child = child_lookup[connection.child]
          if not child
            continue
          attribute = db.attach_point child.otype
          if attribute
            if not object[attribute]
              object[attribute] = []
            object[attribute].push child

        callback objects


  db.all_albums = (callback) ->
    c.objects.find( { otype: 20 } ).toArray (err, results) ->
      throw err if err
      callback results

  db.all_albums_by_year = (callback) ->
    filter = {}
    filter['otype'] = 20
    order = {year: 1, album: 1}
    #order = {album: 1}
    #order = {genre: 1, album: 1}
    c.objects.find(filter).sort(order).toArray (err, objects) ->
      if err then throw new Error "error loading all_albums: #{err}"
      db.attach_parents objects, { otype: [40,1] }, ->
        console.log objects.length, 'objects'
        console.log 'swapping yearless albums to the end'
        for o, i in objects
          break if o.year?
        if i < objects.length
          objects = [].concat objects[i..], objects[...i]
        callback objects

  db.all_albums_by_fileunder = (callback) ->
    filter = {}
    filter['otype'] = 20
    c.objects.find(filter).toArray (err, objects) ->
      if err then throw new Error "error loading all_albums: #{err}"
      db.attach_parents objects, { otype: [40,1] }, ->
        console.log objects.length, 'objects'
        console.log 'sorting by fileunder'
        objects.sort (a, b) ->
          if not a.fileunder or not a.fileunder[0] or not a.fileunder[0].key
            return 1
          if not b.fileunder or not b.fileunder[0] or not b.fileunder[0].key
            return -1
          if a.fileunder[0].key is b.fileunder[0].key
            return 0
          else if a.fileunder[0].key > b.fileunder[0].key
            return 1
          else
            return -1
        console.log 'done'
        callback objects


  db.get_filename = (id, callback) ->
    bid = new mongodb.ObjectID(id)
    if filenamecache
      callback filenamecache[bid] # [parseInt(id)] <- not anymore!
    else
      console.log 'loading filename cache...'
      # if anyone else calls this while it is loading the cache the first time, it
      # will have a race condition and return undefined FIXME
      filenamecache = {}
      tempcache = {}
      c.objects.find({ filename: {'$exists':1} }, {_id:1, filename:1}).each (err, items) ->
        if item
          tempcache[item._id] = item.filename
          #if bid == _id
          #  console.log "<<<<<<<<< #{item.filename}"
        else
          filenamecache = tempcache
          console.log 'finished loading filename cache'
          callback filenamecache[bid]


  db.load_songs_by_filenames = (filenames, callback) ->
    # this doesn't return the results in order which fuxxors the queue display FIXME
    filter = { 'otype': 10, 'filename': {'$in': filenames} }
    c.objects.find(filter).toArray (err, objects) ->
      if err then throw new Error "database error trying to load_songs_by_filenames #{filenames}: #{err}"

      for object in objects
        object.oid = object['_id']

      if objects and objects.length # was crashing when queue was empty
        otype = object.otype
        lookupcount = 0
        if otype is 10 then lookupcount += objects.length
        if otype < 20  then lookupcount += objects.length
        if otype < 30  then lookupcount += objects.length

        debug_limit = 20;

        finisher = ->
          lookupcount--
          if lookupcount is 0
            # now we need to put the results back in the order they were asked for
            ordered = []
            for filename in filenames
              found = false
              for object,i in objects
                if object.filename is filename
                  found = true
                  ordered.push object
                  objects.splice i, 1
                  break
              if not found
                #console.log 'warning: mpd queue item not found in database:', filename
                console.log 'warning: mpd queue item not found in database'
                # should be make a fake object to return so the queue prints something?
                object =
                  filename: filename
                  song: filename
                  _id: 0
                ordered.push object
            # objects really should be empty now
            for object in objects
              console.log 'could not match result object with requested filename!'
              #console.log object.filename
              #console.log filenames
            callback ordered

        for object in objects
          if otype is 10 then db.load_subobjects object,  1, yes, [5,6], finisher # owner
          if otype < 20  then db.load_subobjects object, 20, yes, [5,6], finisher # album
          if otype < 30  then db.load_subobjects object, 30, yes, [5,6], finisher # artist
      else
        callback objects # empty


  class Sequence
    constructor: (@items, @each_callback) ->
      @n = 0
    next: ->
      if @n<@items.length
        @each_callback @items[@n++]
      else
        @done_callback @items
    go: (@done_callback) -> @next()


  db.count_otypes = (ids, otype, callback) ->
    c.objects.find( {_id: {'$in': ids}, otype: otype} ).count (err, howmany) ->
      throw err if err
      callback howmany


  db.load_ownerX = (username, callback) ->
    if username
      c.objects.findOne { otype: 1, owner: username }, {}, (err, owner) ->
        if err then throw err
        callback owner
    else # none specified, load 'em all
      c.objects.find( { otype: 1 } ).sort( { owner: 1 } ).toArray (err, owners) ->
        if err then throw err
        seq = new Sequence owners, (owner) ->
          c.connections.find({ parent: owner._id, ctype: 1 }).toArray (err, connections) =>
            ids = for connection in connections then connection.child  # don't use 'c'!
            ###
            # use map/reduce here FIXME
            tally = {}
            db.count_otypes ids, 5, (count) =>
              tally.dirs = count
              db.count_otypes ids, 10, (count) =>
                tally.songs = count
                db.count_otypes ids, 20, (count) =>
                  tally.albums = count
                  db.count_otypes ids, 30, (count) =>
                    tally.artists = count
                    db.count_otypes ids, 40, (count) =>
                      tally.fileunders = count
                      db.count_otypes ids, 50, (count) =>
                        tally.lists = count
                        _.extend owner, tally
            ###
            mapFunc = -> emit this.otype, 1
            reduceFunc = (key, values) ->
              count = 0
              count += values[i] for i of values
              return count
            c.objects.mapReduce mapFunc, reduceFunc, { query: {_id: {'$in': ids}}, out: { inline: 1 }}, (err, results) =>
              for result in results
                name = false
                switch String(result._id)
                  when '5'  then name = 'dirs'
                  when '10' then name = 'songs'
                  when '20' then name = 'albums'
                  when '30' then name = 'artists'
                if name
                  owner[name] = result.value
              c.connections.find( { parent: owner._id, ctype: 12 } ).count (err, howmany) =>
                throw err if err
                owner.stars = howmany
                @next()
        seq.go ->
          callback owners


  db.load_owner_list = (callback) ->
    c.objects.find( { otype: 1 } ).sort( { owner: 1 } ).toArray (err, owners) ->
      throw err if err
      callback owners


  # still slow, let's try again
  db.load_owner = (username, callback) ->
    if username
      q = { otype: 1, owner: username }
    else
      q = { otype: 1}
    #c.objects.findOne q, {}, (err, owner) ->  #oops
    c.objects.find(q, {}).toArray (err, owner) ->
      if err then throw err
      callback owner


  db.load_users = (callback) ->
    # load list of owners
    elapsed = new otto.misc.Elapsed()
    db.load_owner_list (owners) ->
      console.log "#{elapsed.seconds()} owners loaded"
      console.log 'owners.length', owners.length
      c.connections.find { ctype: 1 }, (err, cursor) =>
        throw err if err
        console.log "#{elapsed.seconds()} connections loaded"
        #console.log 'connections.length', connections.length
        owner_lookup = {}
        owner_stats = {}
        cursor.each (err, connection) ->
          throw err if err
          if connection
            owner_lookup[connection.child] = connection.parent
          else
            console.log "#{elapsed.seconds()} owner_lookup built"
            c.objects.find {}, {_id: 1, otype: 1, length: 1}, (err, cursor) ->
            #c.objects.find({}, {_id: 1, otype: 1, length: 1}).toArray (err, objects) ->
              throw err if err
              console.log "#{elapsed.seconds()} objects loaded"
              #console.log 'objects.length', objects.length
              cursor.each (err, object) ->
                if object
                  owner_id = owner_lookup[object._id]
                  if owner_id
                    if not owner_stats[owner_id]
                      owner_stats[owner_id] = {}
                    name = false
                    switch object.otype
                      when 5  then name = 'dirs'
                      when 10 then name = 'songs'
                      when 20 then name = 'albums'
                      when 30 then name = 'artists'
                    if name
                      owner_stats[owner_id][name] = 0 if not owner_stats[owner_id][name]
                      owner_stats[owner_id][name] += 1
                    if object.otype is 10 and object['length']
                      owner_stats[owner_id].seconds = 0 if not owner_stats[owner_id].seconds
                      owner_stats[owner_id].seconds += object['length']
                else
                  for owner in owners
                    if owner_stats[owner._id]
                      _.extend owner, owner_stats[owner._id]
                  console.log "#{elapsed.seconds()} stats totaled"
                  seq = new Sequence owners, (owner) ->
                    c.connections.find( { parent: owner._id, ctype: 12, rank: {'$gt': 0} } ).count (err, howmany) =>
                      throw err if err
                      owner.stars = howmany
                      @next()
                  seq.go ->
                    console.log "#{elapsed.seconds()} stars totaled. done."
                    callback owners


  db.find_or_create_owner = (username, callback) ->
    db.load_owner username, (owner) ->
      if owner[0]
        callback owner[0]
      else
        c.objects.save { otype: 1, owner: username }, (err, newowner) ->
          if err then throw err
          callback newowner


  db.load_list = (listname, callback) ->
    if listname
      c.objects.findOne { otype: 50, listname: listname }, {}, (err, list) ->
        if err then throw err
        callback list
    else # non specified, load 'em all
      c.objects.find( { otype: 1 } ).sort( { owner: 1 } ).toArray (err, lists) ->
        if err then throw err
        callback lists


  db.find_or_create_list = (listname, callback) ->
    db.load_list listname, (list) ->
      if list
        callback list
      else
        c.objects.save { otype: 50, listname: listname }, (error, newlist) ->
          if err then throw err
          callback newlist


  db.load_all_lists = (loadobjectstoo, callback) ->
    _build_results = (alllistitems, objects) ->
      lists = {}
      for item in alllistitems
        if not lists[item._id]?
          lists[item._id] = []
        if objects
          for object in objects
            if item.child is object._id
              lists[item._id].push object
              break
        else
          lists[item._id].push item.child
      return lists

    c.connections.find( { ctype: 12 } ).sort( { parent: 1, rank: 1 } ).toArray (err, alllistitems) ->
      if err then throw err
      if loadobjectstoo
        loadids = []
        for item in alllistitems
          loadids.push item.child
        load_object loadids, no, (objects) ->
          callback _build_results(alllistitems, objects)
      else
        callback _build_results(alllistitems)


  db.load_stars = (username, loadobjectstoo, callback) ->
    console.log 'load_stars', username
    db.load_owner username, (owners) ->
      if not owners
        return callback({})
      ownerids = []
      if owners not instanceof Array
        owners = [owners]
      for owner in owners
        ownerids.push owner._id
      #console.log 'ownerids', ownerids
      q = ctype: 12, parent: { $in: ownerids }
      c.connections.find( q ).sort( { ownerids: 1, rank: -1 } ).toArray (err, allstarreditems) ->
        #console.log 'allstarreditems', allstarreditems
        if err then throw err
        if loadobjectstoo
          loadids = []
          for item in allstarreditems
            loadids.push item.child
          db.load_object loadids, no, (objects) ->
            callback db._load_stars_build_results(owners, allstarreditems, objects)
        else
          callback db._load_stars_build_results(owners, allstarreditems)

  db._load_stars_build_results = (owners, allstarreditems, objects) ->
    #console.log 'owners', owners
    #console.log 'allstarreditems', allstarreditems
    #console.log 'objects', objects
    stars = {}
    for owner in owners
      stars[owner.owner] = []
      for item in allstarreditems
        if owner._id.equals(item.parent)
          if objects
            for object in objects
              if object._id.equals(item.child)
                _.extend item, object
                break
          stars[owner.owner].push item
    return stars


  db.add_to_user_list = (username, _id, rank, callback) ->
    db.find_or_create_owner username, (owner) ->
      db.load_object _id, no, (object) ->
        if object
          c.connections.findOne { ctype: 12, parent: owner._id, child: object._id }, (err, connection) ->
            if err then throw err
            if connection
              connection.rank = rank
              c.connections.update {'_id': connection._id}, connection, (err) ->
                if err then throw err
                callback(true)
            else
              db.add_to_connections owner._id, object._id, 12, rank, ->
                callback(true)
        else
          callback(false)


  db.remove_from_user_list = (username, oid, callback) ->
    db.load_owner username, (owner) ->
      if owner
        db.remove_from_connections owner[0]._id, oid, 12, ->
          callback true
      else
        callback false


  # too slow (mainly because of toArray it seems)  (<- really?)
  db.Xget_all_song_ids = (callback) ->
    c.objects.find( { otype: 10 }, { '_id': 1 } ).toArray (err, results) ->
      ids = []
      for row in results
        ids.push row._id
      callback ids


  # too slow, see above
  db.Xget_random_songs = (howmany=1, callback) ->
    console.log 'get_random_songs', howmany
    db.get_all_song_ids (ids) ->
      console.log 'got all song ids'
      picked_ids = []
      while howmany--
        console.log 'pick', howmany
        picked = Math.floor Math.random() * ids.length
        picked_ids.push ids[picked]
      console.log 'loading song objects', picked_ids
      db.load_object oids=picked_ids, no, (picked_songs) ->
        console.log 'loaded.'
        # we now shuffle the order of the returned songs since mongodb will
        # not return them in the order we asked (which was random), but in
        # 'natural' order. thus there will be a bias in the order of the random
        # picks being in the order in which they were loaded into the database
        shuffle = []
        console.log 'shuffling picks'
        while picked_songs.length
          console.log 'shuffle', picked_songs.length
          n = Math.floor Math.random() * picked_songs.length
          shuffle.push picked_songs[n]
          picked_songs.splice(n, 1)
        console.log 'done picking random songs'
        callback shuffle


  db.count_all_song_ids = (callback) ->
    c.objects.find({ otype: 10 }, { '_id': 1 }).count (err, count) ->
      callback count


  db.get_song_id_n = (n, callback) ->
    c.objects.find({ otype: 10 }, { '_id': 1 }).skip(n).limit(1).toArray (err, song) ->
      callback song[0]._id


  db.Xget_random_songs = (howmany=1, callback) ->
    console.log 'get_random_songs', howmany
    elapsed = new otto.misc.Elapsed()
    song_ids = []
    c.objects.find({ otype: 10 }, {_id: 1}).each (err, song) ->
      if song
        song_ids.push song._id
      else
        console.log "#{elapsed} all song_ids"
        count = song_ids.length
        console.log 'song ids count', count
        return [] if not count
        picked_ids = []
        howmany = if howmany < count then howmany else count
        while howmany
          picked = Math.floor Math.random() * count
          if song_ids[picked] not in picked_ids
            picked_ids.push(song_ids[picked])
            howmany--
        console.log "#{elapsed} picked 'em"
        db.load_object oids=picked_ids, no, (picked_songs) ->
          console.log "#{elapsed} song objects loaded"
          db.attach_parents picked_songs, { otype: 1 }, ->
            console.log "#{elapsed} parents attached"
            # we now shuffle the order of the returned songs since mongodb will
            # not return them in the order we asked (which was random), but in
            # 'natural' order. thus there will be a bias in the order of the random
            # picks being in the order in which they were loaded into the database
            shuffle = []
            console.log 'shuffling picks'
            while picked_songs.length
              n = Math.floor Math.random() * picked_songs.length
              shuffle.push picked_songs[n]
              picked_songs.splice(n, 1)
            console.log "#{elapsed} shuffeled results. done."
            callback shuffle


  db.cursor_skip_each = (positions, cursor, callback, position=0) ->
    process.nextTick ->
      s = new Date
      if position is 0
        cursor.skip(positions[position])
        new_position = position + 1
      else if position is positions.length
        cursor.close
        return
      else
        cursor.skip(positions[position] - positions[position - 1])
        new_position = position + 1
      cursor.nextObject (err, item) ->
        if err?
          return callback(err, null)
        if item?
          callback null, item
          db.cursor_skip_each(positions, cursor, callback, position)
        else
          cursor.close
          callback err, null
        return
      return


  db.cursor_skip_toArray = (positions, cursor, callback) ->
    items = []
    db.cursor_skip_each positions, cursor, (err, item) ->
     if err?
       return callback(err, null)
     if item? and Array.isArray(items)
       items.push item
     else
       resultItems = items
       items = null
       callback err, resultItems
     return


  db.get_random_songs = (howmany=1, callback) ->
    console.log 'get_random_songs', howmany
    elapsed = new otto.misc.Elapsed()
    song_ids = []
    # pick a slate of random songs, skipping anything over 15mins long
    c.objects.find({ otype: 10, length: {$lt: 900} }, { _id: 1 }).count (err, count) ->
      console.log "#{elapsed} count songs: #{count}"
      positions = []
      for i in [0...howmany - 1] by 1
        positions.push(Math.floor(Math.random() * count))
      positions.sort((a,b)->return a - b)
      cursor = c.objects.find( {otype: 10, length: {$lt: 900} })
      db.cursor_skip_toArray positions, cursor, (err, picked_songs) ->
        throw err if err
        console.log "#{elapsed} randomWhere done, #{picked_songs.length} picked_songs"
        db.attach_parents picked_songs, { otype: 1 }, ->
          console.log "#{elapsed} parents attached"
          # shuffle the order of the returned songs since mongodb will
          # return them in 'natural' order. thus there will be a bias in the order of the random
          # picks being in the order in which they were loaded into the database
          shuffle = []
          while picked_songs.length
            n = Math.floor Math.random() * picked_songs.length
            shuffle.push picked_songs[n]
            picked_songs.splice(n, 1)
          callback shuffle


  db.get_random_starred_songs = (howmany=1, username, callback) ->
    #console.log 'get_random_starred_songs', howmany, 'for', username
    db.load_stars username, true, (stars) ->
      objects = stars[username]
      if not objects
      	return callback []
      #console.log objects.length, 'objects'
      songs = []
      for object in objects
        if not object.rank > 0 then continue
        if object.otype is 10
          songs.push object
      # expand albums into songs (still need to handle artists also)
      async_count = 0;
      for object in objects
        if not object.rank > 0 then continue
        if object.otype is 20
          async_count += 1
          db.load_subobjects object, 10, no, [5,6], (object) ->
            async_count -= 1
            if object.songs?
              for song in object.songs
                songs.push song
            if async_count is 0
              callback db.pick_random_songs_from_array howmany, songs
        if object.otype is 40  # not actually working yet
          async_count += 1
          db.load_subobjects object, 10, no, [5,6], (objects) ->
            console.log '^^^^^^^^^^^^^^ otype 40 objects', objects
            async_count -= 1
            if object.songs?
              for song in object.songs
                songs.push song
            if async_count is 0
              callback db.pick_random_songs_from_array howmany, songs

      if async_count is 0
        callback db.pick_random_songs_from_array howmany, songs


  db.pick_random_songs_from_array = (howmany, songs) ->
    #console.log 'picking random', howmany, 'songs from', songs.length, 'total songs'
    if howmany > songs.length then howmany = songs.length
    picked = []
    attempts = 0
    while picked.length < howmany and attempts < songs.length
      attempts++
      #console.log 'picking'
      candidate = songs[Math.floor Math.random() * songs.length]
      alreadypicked = false
      for pick in picked
        if candidate.id is pick.id
          alreadypicked = true
          break
      if alreadypicked
        #console.log 'already'
        continue
      #console.log 'picked'
      picked.push candidate
    #console.log 'done. got', picked.length
    return picked


  db.get_newest_albums = (callback) ->
    c.objects.find( {otype : 20} ).sort( {_id:-1} ).limit(1000).toArray (err, albums) ->
      throw err if err
      for album in albums
        album.timestamp = Number(album._id.getTimestamp())
      db.attach_parents albums, { otype: [1, 30] }, ->
        callback albums


  db.get_album = (albumname, callback) ->
    #console.log 'get_album for', albumname
    c.objects.findOne {otype: 20, album: albumname}, (err, album)->
      if err then throw new Error "error: db.get_album - #{err}"
      if album
        db.load_subobjects album, 10, no, [5,6], ->
          callback album
      else
        callback album


  db.search = (value, callback) ->
    #    (fileunders, albums, songs) = db.search2([[40, value, ['key', 'name', 'artist'], None],
    #                                            [20, value, 'album', None],
    #                                            [10, value, 'song', None]])
    #    #other = db.search(10, value, None,
    #    #                  ['name', 'artist', 'album', 'song', 'filename', 'title', '.nam', '.ART', '.alb'])
    #    #results = {'fileunders': fileunders, 'albums': albums, 'songs': songs, 'other': other}
    #    results = {'fileunders': fileunders, 'albums': albums, 'songs': songs}
    #    self.finish(json.dumps(results))

    regexp = RegExp("\\b#{value}", 'i')
    c.objects.find({otype: 40, name: regexp}).sort({name: 1}).toArray (err, fileunders)->
      if err then throw new Error "error: db.search - #{err}"
      db.load_subobjects fileunders, 20, no, [5,6], ->
        c.objects.find({otype: 20, album: regexp}).sort({album: 1}).toArray (err, albums)->
          if err then throw new Error "error: db.search - #{err}"
          # err! this doesn't take a list of objects (yet)
          db.load_subobjects albums, 30, yes, [5,6], ->
            c.objects.find({otype: 10, song: regexp}).sort({song: 1}).toArray (err, songs)->
              if err then throw new Error "error: db.search - #{err}"
              for song in songs
                song.oid = song._id  # for backwards compatability
              c.objects.find({otype: 10, "tags.©wrt": regexp}).sort({"tags.©wrt": 1}).toArray (err, songcomposers)->
                if err then throw new Error "error: db.search - #{err}"
                c.objects.find({otype: 10, "tags.TCOM": regexp}).sort({"tags.TCOM": 1}).toArray (err, songcomposers2)->
                  if err then throw new Error "error: db.search - #{err}"
                  songcomposers = songcomposers.concat songcomposers2
                  for song in songcomposers
                    song.oid = song._id  # for backwards compatability
                  callback null, fileunders: fileunders, albums: albums, songs: songs, songcomposers: songcomposers


  db.load_fileunder = (artistid, callback) ->
    #console.log 'load_fileunder', artistid
    db.load_object artistid, load_parents=40, (artist) ->
      callback artist.fileunder


  return db
