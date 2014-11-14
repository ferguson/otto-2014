fs = require 'fs'
path = require 'path'
zappajs = require 'zappajs'
jsonreq = require 'jsonreq'
zipstream = require 'zipstream'
querystring = require 'querystring'
compression = require 'compression'
connectmongo = require 'connect-mongo'
connect = require 'zappajs/node_modules/express/node_modules/connect'
Session = connect.middleware.session.Session

zappa = null

otto.server = ->
  console.log 'we think we are installed in', otto.OTTO_ROOT
  console.log 'zappa version', zappajs.version
  zappa = zappajs.app server_go
  otto.zappa = zappa
  otto.port = 8778  # 8778 fo'eva
  console.log 'otto on port', otto.port

  zappa.server.listen otto.port   #note! it's server.listen, not app.listen!

  zappa.server.on 'listening', ->
    otto.listening = true
    otto.on_listening_hook() if otto.on_listening_hook

  otto.zeroconf.createMDNSAdvertisement()

  otto.sessionlist = {}
  otto.sessioniplist = {}
  otto.socketlist = {}


#############################################
## the zappa application function starts here
#############################################
server_go = ->
  # @ = zappa in this context

  # from http://stackoverflow.com/questions/6819911/nodejs-expressjs-session-handling-with-mongodb-mongoose
  MongoStore = connectmongo(@express)
  otto.sessionStore = new MongoStore(otto.db.dbconf)

  otto.ourlisteners = new otto.listeners.Listeners()

  @use 'cookieParser'
  #@use session: { store: otto.sessionStore, secret: otto.SECRET, key: 'express.sid'}, =>
  #  # we should wait for this callback before proceeding FIXME <- wait!
  #  #   it seems to trigger on each connection? or maybe each socket.io message?
  #  # otherwise we risk getting a "Error setting TTL index on collection" error
  #  # see https://github.com/kcbanner/connect-mongo/pull/58#issuecomment-32148111
  #  console.log 'session db connection established'
  @use {session: {store: otto.sessionStore, secret: otto.SECRET, key: 'express.sid', cookie: {maxAge: 365 * 24 * 60 * 60 * 1000}}}
  #@app.configure 'development', =>
  #  @app.use otto.misc.debug_request
  @app.use compression()  # wondering how much this helps, esp. locally
  @app.use '/static', @express.static(__dirname + '/static')
  @app.use @express.favicon(__dirname + '/static/images/favicon.ico')
  @app.use otto.misc.authenticate_user
  @app.use (req, res, next) ->
    req.session.sessionID = req.sessionID
    next()
  @app.use (req, res, next) ->
    otto.ourlisteners.set_user req.session
    next()
  @app.use (req, res, next) ->
    otto.sessionlist[req.sessionID] = req.session
    next()
  @io.set 'authorization', otto.misc.socket_authenticate_user
  @enable 'serve jquery', 'serve sammy', 'serve zappa'
  @use 'partials'

  # we define our own layout (so we can have <links> in the <head> and <scripts> at the bottom)
  #@enable 'default layout'

  @io.set 'log level', 2


  @on 'connection': ->
    console.log 'sio connection'
    otto.socketlist[@id] = @socket
    session = socket_get_session @
    #console.log 'session is', session
    if not session
      console.log 'telling client to resession'
      @emit 'resession'
    else
      @emit 'proceed'
      # now we wait for the client to say 'hello'


  @on 'disconnect': ->
    console.log 'sio disconnection!'
    session = socket_get_session @
    if session
      otto.ourlisteners.remove_socket session, @


  @on 'hello': ->
    console.log 'sio hello client!'
    if not session = socket_get_session @ then return

    data = {}
    data.channellist = otto.channelinfolist
    sessionip = socket_get_sessionip @
    console.log 'sessionip', sessionip

    # the [^0-9.] test is checking if the user name is just an ip address
    if session.user and /[^0-9.]/.test(session.user)
      username = session.user
    else if sessionip and sessionip.localhost
      # auto login the local app
      username = process.env['USER'] || ''
    else
      username = ''

    channelname = session.channelname || 'main'

    sessionSet session, user: username, channelname: channelname, =>
      otto.ourlisteners.change_user session

      data.myusername = session.user
      console.log 'telling client their username is', data.myusername

      otto.ourlisteners.add_socket session, @
      # prime the client state
      for state,val of @data
        if state is 'idle'
          val = if @data then (new Date()).getTime() else 0
        otto.ourlisteners.set_state session.sessionID, @id, state, val

      data.mychannel = session.channelname
      console.log 'telling client their channel is', data.mychannel
      if sessionip
        data.localhost = sessionip.localhost
      otto.ourlisteners.change_channel session
      @join(data.mychannel)
      data.haslineout = process.platform is 'darwin'
      data.largedatabase = otto.db.largedatabase
      data.emptydatabase = otto.db.emptydatabase
      data.musicroot = '/Users/' + process.env['USER'] + '/Music'  # FIXME
      #console.log 'emitting welcome packet', data
      @emit 'welcome', data


  @on 'updateme': ->
    console.log 'sio updateme'
    # initiated by the client
    # i'm sure parts of this causes all clients to be updated, perhaps we can FIXME someday

    if not session = socket_get_session @ then return

    channellist = []
    for own channelname of otto.channels.channel_list
      channel = otto.channels.channel_list[channelname]
      channellist.push {name: channel.name, fullname: channel.fullname}
    # hmmm... we don't even use what we just built FIXME
    @emit 'channellist', otto.channelinfolist

    channelinfo = otto.channels.channel_list[session.channelname]
    if channelinfo
      #otto.channels.channel_list[session.channelname].refresh()
      @emit 'queue',    channelinfo.queue
      @emit 'state',    channelinfo.state
      @emit 'time',     channelinfo.time
      allstatus = {}
      alllineout = {}
      alloutputs = {}
      allreplaygain = {}
      for name,channel of otto.channels.channel_list
        allstatus[name] = channel.status
        alllineout[name] = channel.lineout
        alloutputs[name] = channel.outputs
        allreplaygain[name] = channel.replaygain
      @emit 'status',  allstatus
      @emit 'lineout', alllineout
      @emit 'outputs', alloutputs
      @emit 'replaygain', allreplaygain

    if session.user and /[^0-9.]/.test(session.user)
      #console.log "telling the client their username #{session.user}"
      #@emit 'myusername', session.user
      otto.db.load_stars session.user, false, (stars) =>
        @emit 'stars', stars
    otto.db.load_all_lists false, (err, data) =>
      @emit 'lists', data
    # hack to force a listeners update
    otto.ourlisteners.update()


  @on 'begin': ->
    console.log 'sio begin'
    if not session = socket_get_session @ then return
    channel = otto.channels.channel_list[session.channelname]
    if channel
      zappa.io.sockets.in(session.channelname).emit 'begun'
      channel.autofill_queue ->
        channel.play 0, ->


  @on 'selectfolder': ->
    console.log 'sio selectfolder'
    if not session = socket_get_session @ then return
    # bounce this message from the webview client to Otto.py
    #zappa.io.sockets.in(session.channelname).emit 'selectfolder'  # sends to everyone, for now FIXME
    @broadcast 'selectfolder'  # sends to everyone (except self), for now FIXME


  @on 'changechannel': ->
    console.log 'sio changechannel'
    if not session = socket_get_session @ then return
    newchannelname = @data
    console.log 'changing channel to', newchannelname
    channel = otto.channels.channel_list[newchannelname]
    if channel
      oldchannelname = session.channelname
      sessionSet session, channelname: newchannelname, =>
        if session.channelname != oldchannelname
          otto.ourlisteners.change_channel session
          apply_across_all_tabs session, ->
            @leave(oldchannelname)
            @join(session.channelname)
            @emit 'mychannel', name: channel.name, fullname: channel.fullname
          otto.ourlisteners.update()
    else
      console.log 'not a valid channel name'


  @on 'login': ->
    name = @data
    console.log 'sio login', name
    if not session = socket_get_session @ then return
    if session
      console.log session.sessionID
      sessionSet session, user: name, =>
        console.log "telling the client their username #{session.user}"
        @emit 'myusername', session.user
        otto.db.load_stars session.user, false, (stars) =>
          console.log 'about to emit preloaded stars'
          @emit 'stars', stars
        otto.ourlisteners.change_user session
        otto.ourlisteners.update()


  @on 'logout': ->
    console.log 'sio logout'
    if not session = socket_get_session @ then return
    if session.sessionID
      console.log session.sessionID
      sessionSet session, user: '', =>
        console.log 'telling the client they are logged out'
        @emit 'myusername', session.user
        otto.ourlisteners.change_user session
        otto.ourlisteners.update()


  @on 'play': (socket) ->
    console.log 'sio play'
    if not session = socket_get_session @ then return
    if otto.channels.channel_list[session.channelname]
      otto.channels.channel_list[session.channelname].play @data, ->
      #zappa.io.sockets.in(session.channelname).emit 'state', 'play'


  # pause also unpauses
  @on 'pause': (socket) ->
    console.log 'sio pause'
    if not session = socket_get_session @ then return
    if otto.channels.channel_list[session.channelname]
      otto.channels.channel_list[session.channelname].pause ->
      #zappa.io.sockets.in(session.channelname).emit 'state', 'pause'


  # this just pauses, Otto.py uses it for 'stop'
  # don't want to use mpd command stop as that might disconnect things
  @on 'pauseifnot': (socket) ->
    console.log 'sio pauseifnot'
    if not session = socket_get_session @ then return
    if otto.channels.channel_list[session.channelname]
      otto.channels.channel_list[session.channelname].pauseifnot ->
      #zappa.io.sockets.in(session.channelname).emit 'state', 'pause'


  @on 'toggleplay': (socket) ->
    console.log 'sio toggleplay'
    if not session = socket_get_session @ then return
    channelname = @data || session.channelname
    console.log 'channel', channelname
    if otto.channels.channel_list[channelname]
      otto.channels.channel_list[channelname].toggleplay ->


  @on 'seek': (socket) ->
    console.log 'sio seek', @data
    if not session = socket_get_session @ then return
    if otto.channels.channel_list[session.channelname]
      otto.flush_streams(session.channelname)
      otto.channels.channel_list[session.channelname].seek @data, ->


  # no longer used
  @on 'lineout': (socket) ->
    console.log 'sio lineout', @data
    if not session = socket_get_session @ then return
    if otto.channels.channel_list[session.channelname]
      otto.channels.channel_list[session.channelname].set_lineout @data, ->


  @on 'togglelineout': ->
    console.log 'sio togglelineout', @data
    channelname = @data.channelname
    alt = @data.alt
    if otto.channels.channel_list[channelname]
      if otto.channels.channel_list[channelname].lineout == '1'
        otto.channels.channel_list[channelname].set_lineout 0
      else
        if not alt
          for name,channel of otto.channels.channel_list
            if channel.lineout == '1'
              channel.set_lineout 0
        otto.channels.channel_list[channelname].set_lineout 1


  @on 'togglecrossfade': ->
    console.log 'sio togglecrossfade'
    channelname = @data.channelname
    if otto.channels.channel_list[channelname]
      otto.channels.channel_list[channelname].toggle_crossfade()


  @on 'togglereplaygain': ->
    console.log 'sio togglereplaygain', @data
    channelname = @data.channelname
    if otto.channels.channel_list[channelname]
      otto.channels.channel_list[channelname].toggle_replaygain()


  @on 'setvol': (socket) ->
    console.log 'sio setvol'
    if not session = socket_get_session @ then return
    channelname = @data.channelname
    volume = @data.volume
    if otto.channels.channel_list[channelname]
      otto.channels.channel_list[channelname].setvol volume, ->


  @on 'reloadme': (socket) ->
    console.log 'sio reloadme'
    @emit 'reload'


  @on 'reloadall': (socket) ->
    console.log 'sio reloadall'
    if not session = socket_get_session @ then return
    if session and session.user
      if session.user is 'jon'
        console.log 'reload all'
        zappa.io.sockets.emit 'reload'
      else
        console.log "#{session.user} tried to .reloadall! awesome."


  # mpd's next is not currently used, it's not very useful
  # it only works once playing has started, and it resumes play if paused

  @on 'deleteid': (socket) ->
    console.log 'sio deleteid', @data
    if not session = socket_get_session @ then return
    if not session or not session.user
      console.log 'error: don\'t know the user, ignoring socket event'
      #@emit 'reload'
      return
    if otto.channels.channel_list[session.channelname]
      otto.channels.channel_list[session.channelname].remove_from_queue @data, session.user


  # used by 'next' in Otto.py
  @on 'delete': (socket) ->
    console.log 'sio delete'
    if not session = socket_get_session @ then return
    if not session or not session.user
      console.log 'error: don\'t know the user, ignoring socket event'
      #@emit 'reload'
      return
    if otto.channels.channel_list[session.channelname]
      otto.channels.channel_list[session.channelname].remove_from_queue '', session.user


  @on 'enqueue': (socket) ->
    console.log 'sio enqueue', @data
    if not session = socket_get_session @ then return
    if not session or not session.user
      console.log 'error: do not know the user, ignoring socket event'
      #@emit 'reload'
      return
    client_channel = otto.channels.channel_list[session.channelname]
    if client_channel
      client_channel.add_to_queue @data, session.user


  @on 'stars': (socket) ->
    console.log 'sio stars'
    if not session = socket_get_session @ then return
    if not session or not session.user
      console.log 'error: do not know the user, ignoring socket event'
      #@emit 'reload'
      return
    if not session.user or not /[^0-9.]/.test(session.user)
      return
    otto.db.add_to_user_list session.user, @data.id, @data.rank, (success) ->
      if success
        otto.db.load_stars session.user, no, (stars) ->
          #console.log 'stars', stars
          zappa.io.sockets.emit 'stars', stars


  @on 'unlist': (socket) ->
    console.log 'sio unlist'
    if not session = socket_get_session @ then return
    if not session or not session.user
      console.log 'error: do not know the user, ignoring socket event'
      #@emit 'reload'
      return
    if not session.user or not /[^0-9.]/.test(session.user)
      return
    jsonreq.post_with_body 'http://localhost:8778/remove_from_list', querystring.stringify({ user: session.user, id: @data }), (err, data) ->
      jsonreq.get 'http://localhost:8778/load_lists', (err, data) ->
        zappa.io.sockets.emit 'lists', data


  @on 'loadmusic': (socket) ->
    console.log 'sio loadmusic', @data
    otto.loader.load(zappa, @data)


  @on 'loadmusiccancel': (socket) ->
    console.log 'sio loadmusiccancel'
    otto.loader.cancel(zappa)


  @on 'chat': (socket) ->
    console.log 'sio chat'
    if not session = socket_get_session @ then return
    otto.report_event 'chat', session.channelname, 0, session.user, @data


  @on 'inchat': (socket) ->
    console.log 'sio inchat'
    if not session = socket_get_session @ then return
    otto.ourlisteners.set_state session.sessionID, @id, 'inchat', @data
    if @data
      [eventname, message] = ['joinedchat', 'joined the chat']
    else
      [eventname, message] = ['leftchat', 'left the chat']
    otto.report_event eventname, session.channelname, 0, session.user, message


  @on 'typing': (socket) ->
    if not session = socket_get_session @ then return
    otto.ourlisteners.set_state session.sessionID, @id, 'typing', @data


  @on 'focus': (socket) ->
    if not session = socket_get_session @ then return
    otto.ourlisteners.set_state session.sessionID, @id, 'focus', @data


  @on 'idle': (socket) ->
    if not session = socket_get_session @ then return
    val = if @data then (new Date()).getTime() else 0
    otto.ourlisteners.set_state session.sessionID, @id, 'idle', val

  @on 'console.log': (socket) ->
    console.log.apply @data
  @on 'console.dir': (socket) ->
    console.dir.apply @data


  ########################################


  @get '/': ->
    otto.index.render bodyclasses: '.disconnected'


  @get '/starts_with': ->
    query = @req.query
    otto.db.starts_with query.value, query.attribute, parseInt(query.otype), query.nochildren, (objects) =>
      @res.json(objects)


  @get '/all_albums': ->
    otto.db.all_albums (objects) =>
      @res.json(objects)

  @get '/all_albums_by_year': ->
    otto.db.all_albums_by_year (objects) =>
      @res.json(objects)

  @get '/all_albums_by_fileunder': ->
    otto.db.all_albums_by_fileunder (objects) =>
      @res.json(objects)


  @get '/image(/:extra?)?': ->
    id = @req.query.id
    size = false
    if @req.params.extra
      size = @req.params.extra.replace(/^[/]/, '')
    otto.db.load_image id, size, (image) =>
      if !image
        #return @req.redirect '/static/images/gray.png'
        if not otto.graypixel
          otto.graypixel = fs.readFileSync('static/images/gray.png')
        image = otto.graypixel

      #im = gd.createFromPngPtr(imagedata)
      #w = Math.floor (im.width + 2)
      #h = Math.floor (im.height + 2)
      #w = 100
      #h = 100
      #target_png = gd.createTrueColor(w, h)
      #im.copyResampled(target_png, 0,0,0,0, w, h, im.width, im.height)

      @res.setHeader 'Content-Type', 'image/png'
      #image = target_png.pngPtr()
      @res.write image, 'binary'
      @res.end()


  @get '/load_object': ->
    query = @req.query
    otto.db.load_object query.id, query.load_parents, (object) =>
      @res.json(object)


  @get '/album_details': ->
    query = @req.query
    otto.db.album_details query.id, (object) =>
      @res.json(object)


  @get '/search': ->
    value = @req.query.value
    otto.db.search value, (err, results) =>
      @res.json(results)


  # still to be converted to mongodb
  #@get
    #'/music_root_dirs': proxy_api_request
    #'/load_dir': proxy_api_request
    #'/load_lists': proxy_api_request


  @get '/load_users': ->
    query = @req.query
    otto.db.load_users (users) =>
      @res.json(users)


  @get '/load_stars': ->
    query = @req.query
    otto.db.load_stars null, yes, (stars) =>
      @res.json(stars)


  @get '/load_newest_albums': ->
    query = @req.query
    otto.db.get_newest_albums (albums) =>
      @res.json(albums)


  @get '/load_fileunder': ->
    artistid = @req.query.artistid
    otto.db.load_fileunder artistid, (results) =>
      @res.json(results)


  # we ask the client to hit this when we need to reload their session cookie
  @get '/resession': ->
    console.log '/resession'
    return ''


  #@coffee '/shared.js': ... # use @coffee if you want the code to be shared between server and client
  # these seem to cache the outgoing results! plus they wrap everything in zappa.run
  #@client '/otto.client.js': otto.client
  #@client '/otto.client.cubes.js': otto.client.cubes
  #@client '/otto.client.soundfx.js': otto.client.soundfx
  #@client '/otto.client.templates.js': otto.client.templates
  @client 'shunt.js': otto.client  # seems something must use @client for zappa.js to be served


  @get '/otto.client.js': ->
    @res.setHeader('Content-Type', 'text/javascript')
    #return ';(' + otto.client + ')();'
    return ';window.otto = window.otto || {};zappa.run(' + otto.client + ');'


  @get '/otto.client.templates.js': ->
    @res.setHeader('Content-Type', 'text/javascript')
    return ';window.otto = window.otto || {};(' + otto.client.templates + ')();'


  @get '/otto.client.:modulename.js': ->
    modulename = @req.params.modulename
    if otto.client[modulename]
      @res.setHeader('Content-Type', 'text/javascript')
      return ';(' + otto.client[modulename] + ')();'
    else
      @res.status(404).send('Not found')


  proxy_stream = (format) ->
    host = @req.headers.host
    add_stream_callback = (@req, channel, format) =>
      otto.ourlisteners.add_stream @req.session
    remove_stream_callback = (@req, channel, format) =>
      otto.ourlisteners.remove_stream @req.session
    #console.dir @req.params
    channelname = @req.params.channelname || 'main'
    format = format || @req.params.format || 'mp3'
    console.log 'channelname', channelname, 'format', format
    if otto.channels.channel_list[channelname]
      if format in ['mp3', 'ogg', 'wav']
        otto.channels.channel_list[channelname].proxy_stream @req, @res, add_stream_callback, remove_stream_callback, format
      else
        throw new Error 'unknown format'
    else
      throw new Error 'stream not found'

  @get '/stream/:channelname/:format': proxy_stream
  @get '/stream/mp3': -> proxy_stream.call(@, 'mp3')
  @get '/stream/ogg': -> proxy_stream.call(@, 'ogg')
  @get '/stream/wav': -> proxy_stream.call(@, 'wav')
  @get '/stream/:channelname': proxy_stream
  @get '/stream': proxy_stream


  @get '/download/:id': ->
    return #!#
    if not @req.session.user or not /[^0-9.]/.test(@req.session.user)
      return @res.send('not logged in', 403)
    id = @req.params.id
    jsonreq.get 'http://localhost:8778/load_lists?objects=1', (err, data) =>
      filenames = []
      archivename = no
      for user in data
        console.log "id #{id}, user.id #{user.id}"
        if id == user.id
          archivename = "#{user.owner}.zip"
          console.log "archiving #{archivename} for id #{user.id}"
          for item in user.list
            if item.otype == 10
              filename = path.join(user.owner, path.basename(item.filename))
              filenames.push( [item.filename, filename] )
              #console.log "adding song #{item.filename} as #{filename}"
            else if item.otype == 20
              albumdirname = path.basename(item.dirpath)
              #console.log "adding album #{albumdirname}"
              if item.items and item.items.length
                for song in item.items
                  filename = path.join(user.owner, albumdirname, path.basename(song.filename))
                  filenames.push( [song.filename, filename] )
                  #console.log "adding album song #{song.filename} as #{filename}"
      if archivename
        console.log 'writeHead'
        @res.writeHead 200,
          'Pragma': 'public'
          'Expires': '0'
          'Cache-Control': 'must-revalidate, post-check=0, pre-check=0'
          #'Cache-Control': 'public'   # twice?
          'Content-Description': 'File Transfer'
          'Content-Type': 'application/octet-stream'
          'Content-Disposition': "attachment; filename=\"#{archivename}\""
          'Content-Transfer-Encoding': 'binary'

        zip = zipstream.createZip level: 1
        zip.pipe( @res )
        nextfile = =>
          if filenames.length
            entry = filenames.shift()
            fullfilename = entry[0]
            shortfilename = entry[1]
            zip.addFile fs.createReadStream(fullfilename), name: shortfilename, store: true, nextfile
          else
            zip.finalize (bytes) =>
              @res.end()
              @req.connection.destroy()
              console.log "zip file downloaded, #{bytes} bytes total"
        nextfile()


  @get '/otto.m3u': ->
    host = @req.headers.host
    @res.setHeader('Content-Type', 'audio/x-mpegurl')
    """
    #EXTM3U
    #EXTINF:-1,otto.local-
    http://#{host}/stream/1/#{@req.session.user}/#{host}
    """


  @get '/otto.pls': ->
    host = @req.headers.host
    @res.setHeader('Content-Type', 'audio/x-scpls')
    """
    [playlist]
    numberofentries=1
    File1=http://#{host}/stream/1/#{@req.session.user}/Otto%20(#{host})
    Title1=Otto (#{host})
    Length1=-1
    Version=2
    """


  ########################################


  socket_get_session = (s) -> otto.sessionlist[s.io.handshaken[s.id].sessionID]
  socket_get_sessionip = (s) -> otto.sessioniplist[s.io.handshaken[s.id].sessionID]

  # loop across all socket.io connections for a given session and call func with @ set to each socket
  apply_across_all_tabs = (session, func) ->
    sessionsockets = otto.ourlisteners.get_sockets session
    for id of sessionsockets
      func.apply otto.socketlist[id]


  sessionSet = (session, dict, callback) ->
    console.log 'sessionSet'
    otto.sessionStore.get session.sessionID, (err, session2) =>
      if err or not session2
        console.log 'error: no session found in database? - ', err
        console.log session
        # not sure if we should call the callback or not on err
        # at least the in memory session doesn't get changed
        callback()
      else
        for key,val of dict
          session[key] = val
          session2[key] = val
        otto.sessionStore.set session.sessionID, session2, ->
          callback()


  otto.channels.set_global_event_handler (eventname, channel, args...) ->
    switch eventname
      when 'queue'
        zappa.io.sockets.in(channel.name).emit 'queue', channel.queue

      when 'state'
        zappa.io.sockets.in(channel.name).emit 'state', channel.state

      when 'status'
        allstatus = {}
        for name,channel of otto.channels.channel_list
          allstatus[name] = channel.status
        zappa.io.sockets.emit 'status', allstatus

      when 'time'
        zappa.io.sockets.in(channel.name).emit 'time', channel.time

      when 'lineout'
        #zappa.io.sockets.in(channel.name).emit 'lineout', channel.lineout
        alllineout = {}
        for name,channel of otto.channels.channel_list
          alllineout[name] = channel.lineout
        zappa.io.sockets.emit 'lineout', alllineout

      when 'replaygain'
        #zappa.io.sockets.in(channel.name).emit 'lineout', channel.lineout
        allreplaygain = {}
        for name,channel of otto.channels.channel_list
          allreplaygain[name] = channel.replaygain
        zappa.io.sockets.emit 'replaygain', allreplaygain

      when 'outputs'
        #zappa.io.sockets.in(channel.name).emit 'outputs', channel.outputs
        alloutputs = {}
        for name,channel of otto.channels.channel_list
          alloutputs[name] = channel.outputs
        zappa.io.sockets.emit 'outputs', alloutputs

      when 'started'
        message = "playing #{args[0].song}"
        otto.report_event 'started', channel.name, args[0], user, message

      when 'finished'
        previously_playing = args[0]
        message = 'finished song'
        if previously_playing.requestor
          message += " requested by #{previously_playing.requestor}"
        message += " #{previously_playing.song}"
        otto.report_event 'finished', channel.name, previously_playing.id, undefined, message

      when 'addtoqueue'
        song = args[0]
        user = args[1]
        message = "picked song #{song.song}"
        otto.report_event 'enqueue', channel.name, song, user, message

      when 'killed', 'removed'
        song = args[0]
        user = args[1]
        if song.requestor?
          if song.requestor is user
            message = "#{eventname} their own request #{song.song}"
          else
            message = "#{eventname} song requested by #{song.requestor}"
        else
          message = "#{eventname} song #{song.song}"
        otto.report_event eventname, channel.name, song.id, user, message
        if eventname is 'killed'
          otto.flush_streams(channel.name)


  otto.ourlisteners.on '*', (eventname, listeners, data) ->
    switch eventname
      when 'update'
        zappa.io.sockets.emit 'listeners', data

      when 'userjoin'
        otto.report_event 'joinedchannel', 'main', 0, data.user, 'joined the channel'

      when 'userchange'
        otto.report_event 'userchange', 'main', 0, data.user, 'changed user'

      when 'userleft'
        otto.report_event 'leftchannel', 'main', 0, data.user, 'left the channel'

      when 'streamingstart'
        otto.report_event 'startstreaming', 'main', 0, data.user, 'started streaming'

      when 'streamingstop'
        otto.report_event 'stopstreaming', 'main', 0, data.user, 'stopped streaming'


  #eventlog = fs.createWriteStream 'static/html/events.html', 'flags': 'a', ->
  #  # not working:
  #  otto.report_event 'ottostarted', undefined, undefined, undefined, (new Date).toUTCString()

  otto.report_event = (name, channelname, id, user, message) =>
    event =
      timestamp: new Date()
      id: id
      user: user
      name: name
      channel: channelname
      message: message
    if channelname
      @io.sockets.in(channelname).emit 'chat', event
    else
      @io.sockets.emit 'chat', event
    #eventlog.write otto.client.templates.event event: event
    #eventlog.write '\n'
    otto.db.save_event event, ->

  otto.flush_streams = (channelname) =>
    console.log 'flushstreams'
    if channelname
      @io.sockets.in(channelname).emit 'flushstream'
    else
      @io.sockets.emit 'flushstream'
