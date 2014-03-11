fs = require 'fs'
path = require 'path'
zappajs = require 'zappajs'
jsonreq = require 'jsonreq'
zipstream = require 'zipstream'
querystring = require 'querystring'
connectmongo = require 'connect-mongo'
connect = require 'zappajs/node_modules/express/node_modules/connect'
Session = connect.middleware.session.Session

require './otto.livedev' if process.env.NODE_ENV is 'development'

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


#############################################
## the zappa application function starts here
#############################################
server_go = ->
  # @ = zappa in this context

  # from http://stackoverflow.com/questions/6819911/nodejs-expressjs-session-handling-with-mongodb-mongoose
  MongoStore = connectmongo(@express)
  otto.sessionStore = new MongoStore(otto.db.dbconf)

  ourlisteners = new otto.listeners.Listeners()

  @use 'cookieParser'
  #@use session: { store: otto.sessionStore, secret: otto.SECRET, key: 'express.sid'}, =>
  #  # we should wait for this callback before proceeding FIXME
  #  # otherwise we risk getting a "Error setting TTL index on collection" error
  #  # see https://github.com/kcbanner/connect-mongo/pull/58#issuecomment-32148111
  #  console.log 'session db connection established'
  @use {session: { store: otto.sessionStore, secret: otto.SECRET, key: 'express.sid'}}
  @app.configure 'development', =>
    @app.use otto.misc.debug_request
  @app.use '/static', @express.static(__dirname + '/static')
  @app.use @express.favicon(__dirname + '/static/images/favicon.ico')
  @app.use otto.misc.authenticate_user
  @app.use (req, res, next) ->
    ourlisteners.set_user req.session, req.sessionID
    next()
  @enable 'serve jquery', 'serve sammy', 'serve zappa'
  @use 'partials'

  # we define our own layout (so we can have <links> in the <head> and <scripts> at the bottom)
  #@enable 'default layout'

  @io.set 'log level', 2
  @io.set 'authorization', otto.misc.socket_authenticate_user


  @on 'connection': ->
    console.log 'socket.io connection'
    @client.channelname = @client.channelname || 'main'
    @join(@client.channelname)

    @client.handshake = @io.handshaken[@id]
    handshake = @client.handshake
    ourlisteners.add_socket @id, handshake.session, handshake.sessionID, @client.channelname

    # now we wait for the client to say 'hello'


  @on 'disconnect': (socket) ->
    console.log 'socket.io disconnection!'
    handshake = @client.handshake
    if handshake and handshake.session
      ourlisteners.remove_socket @id, handshake.sessionID


  @on 'hello': ->
    console.log 'hello client!'
    data = {}
    data.channellist = otto.channelinfolist
    otto.db.load_all_lists false, (lists) =>
      data.lists = lists
      handshake = @client.handshake
      if handshake.session and handshake.session.user and /[^0-9.]/.test(handshake.session.user)
        data.myusername = handshake.session.user
      #otto.db.load_stars handshake.session.user, false, (stars) =>  # only if sesion.user?
      if true  # didn't want to unindent
        #data.stars = stars
        #console.log 'emitting welcome packet', data
        @emit 'welcome', data
        ourlisteners.update()


  @on 'login': ->
    name = @data
    console.log 'login', name
    handshake = @client.handshake
    if handshake.sessionID
      session = handshake.session
      sessionid = handshake.sessionID
      console.log sessionid
      otto.sessionStore.get sessionid, (err, session2) =>
        if err or not session2
          console.log 'error: no session found in database - ', err
          console.log session2
        else
          session.user = name
          session2.user = name
          otto.sessionStore.set sessionid, session2, ->
          console.log "telling the client their username #{session.user}, #{session2.user}"
          @emit 'myusername', session.user
          otto.db.load_stars session.user, false, (stars) =>
            console.log 'about to emit preloaded stars'
            @emit 'stars', stars
          ourlisteners.change_user session, sessionid
          ourlisteners.update()


  # not used
  @get '/login': ->
    name = @req.query.user
    console.log 'login', name
    return @res.json {ok: false} if not @req.session
    session = @req.session
    console.log 'session', session
    session.user = name
    console.log "telling the client their username #{session.user}"
    for socketID in ourlisteners.list_socketids @req.sessionID
      socket = zappa.io.sockets.socket(socketID)
      socket.emit 'myusername', session.user
      otto.db.load_stars session.user, false, (stars) =>
        console.log 'about to emit preloaded stars'
        socket.emit 'stars', stars
    ourlisteners.change_user @req.session, @req.sessionID
    ourlisteners.update()
    @res.json {ok: true}


  @on 'logout': ->
    console.log 'logout'
    handshake = @client.handshake
    if handshake.sessionID
      session = handshake.session
      sessionid = handshake.sessionID
      console.log sessionid
      session.user = null
      otto.sessionStore.get sessionid, (err, session2) =>
        if err or not session2
          console.log 'error: no session found in database - ', err
          console.log session2
        else
          session2.user = null
          otto.sessionStore.set sessionid, session2, ->
          console.log 'telling the client they are logged out'
          @emit 'loggedout'
          #otto.db.load_stars session.user, false, (stars) =>
          #  console.log 'about to emit preloaded stars'
          #  @emit 'stars', stars
          ourlisteners.change_user session, sessionid
          ourlisteners.update()


  @get '/logout': ->
    console.log 'logout'
    if @req.session
      session = @req.session
      session.user = null
      console.log "telling the client they are logged out"
      for socketID in ourlisteners.list_socketids @req.sessionID
        socket = zappa.io.sockets.socket(socketID)
        socket.emit 'loggedout'
        #otto.db.load_stars session.user, false, (stars) =>
        #  console.log 'about to emit preloaded stars'
        #  @emit 'stars', stars
      ourlisteners.change_user @req.session, @req.sessionID
      ourlisteners.update()
      @res.json {ok: true}
    else
      @res.json {ok: false}


  @on 'updateme': ->
    # initiated by the client so that someday multiple socket.io
    # disconnects and reconnects become a non-event and can be debounced
    # i'm sure this causes all clients to be updated, perhaps we can FIXME someday
    if otto.channels.channel_list[@client.channelname]
      otto.channels.channel_list[@client.channelname].refresh()
    #channellist = [{name:'one', fullname:'One!'},{name:'two',fullname:'Two.'}]
    channellist = []
    for own channelname of otto.channels.channel_list
      channel = otto.channels.channel_list[channelname]
      channellist.push {name: channel.name, fullname: channel.fullname}
    #@emit 'channellist', channellist
    #console.log 'otto.channelinfolist', otto.channelinfolist
    @emit 'channellist', otto.channelinfolist
    otto.db.load_all_lists false, (err, data) =>
      @emit 'lists', data
    handshake = @client.handshake
    if handshake.session and handshake.session.user and /[^0-9.]/.test(handshake.session.user)
      console.log "telling the client their username #{handshake.session.user}"
      @emit 'myusername', handshake.session.user
      otto.db.load_stars handshake.session.user, false, (stars) =>
        @emit 'stars', stars
    # hack to force a listeners update
    ourlisteners.update()


  @on 'changechannel': ->
    newchannelname = @data
    console.log 'changing channel to', newchannelname
    channel = otto.channels.channel_list[newchannelname]
    if channel
      @leave(@client.channelname)
      @client.channelname = channel.name
      @join(@client.channelname)
      @emit 'changechannel', name: channel.name, fullname: channel.fullname
    else
      console.log 'not a valid channel name'


  @on 'play': (socket) ->
    if otto.channels.channel_list[@client.channelname]
      otto.channels.channel_list[@client.channelname].play @data, ->
      #zappa.io.sockets.in(@client.channelname).emit 'state', 'play'

  @on 'pause': (socket) ->
    console.log 'pause!'
    if otto.channels.channel_list[@client.channelname]
      otto.channels.channel_list[@client.channelname].pause ->
      #zappa.io.sockets.in(@client.channelname).emit 'state', 'pause'

  # next is not currently used
  @on 'next': (socket) ->
    console.log 'next!'
    if otto.channels.channel_list[@client.channelname]
      otto.channels.channel_list[@client.channelname].next ->
  @get '/next': ->
    otto.channels.channel_list['main'].next ->

  @on 'seek': (socket) ->
    console.log 'seek!', @data
    if otto.channels.channel_list[@client.channelname]
      otto.channels.channel_list[@client.channelname].seek @data, ->

  @on 'outputs': (socket) ->
    if otto.channels.channel_list[@client.channelname]
      otto.channels.channel_list[@client.channelname].outputs @data, ->

  @on 'lineout': (socket) ->
    if otto.channels.channel_list[@client.channelname]
      otto.channels.channel_list[@client.channelname].lineout @data, ->

  @on 'setvol': (socket) ->
    if otto.channels.channel_list[@client.channelname]
      otto.channels.channel_list[@client.channelname].setvol @data, ->

  @on 'reloadme': (socket) ->
    @emit 'reload'


  @on 'reloadall': (socket) ->
    if @client.handshake.session and @client.handshake.session.user
      user = @client.handshake.session.user
      if user is 'jon'
        console.log 'reload all'
        zappa.io.sockets.emit 'reload'
      else
        console.log "#{user} tried to .reloadall! awesome."


  @on 'deleteid': (socket) ->
    console.log('deleteid! ' + @data)
    if !@client.handshake.session or !@client.handshake.session.user
      console.log 'error: don\'t know the user, ignoring socket event'
      #@emit 'reload'
      return
    user = @client.handshake.session.user
    if otto.channels.channel_list[@client.channelname]
      otto.channels.channel_list[@client.channelname].remove_from_queue @data, user


  @on 'enqueue': (socket) ->
    if !@client.handshake.session or !@client.handshake.session.user
      console.log 'error: do not know the user, ignoring socket event'
      #@emit 'reload'
      return
    user = @client.handshake.session.user
    client_channel = otto.channels.channel_list[@client.channelname]
    if client_channel
      client_channel.add_to_queue @data, user


  @on 'stars': (socket) ->
    if !@client.handshake.session or !@client.handshake.session.user
      console.log 'error: do not know the user, ignoring socket event'
      #@emit 'reload'
      return
    user = @client.handshake.session.user
    if not user or not /[^0-9.]/.test(user)
      return
    otto.db.add_to_user_list user, @data.id, @data.rank, (success) ->
      if success
        otto.db.load_stars user, no, (stars) ->
          console.log 'stars', stars
          zappa.io.sockets.emit 'stars', stars


  @on 'unlist': (socket) ->
    if !@client.handshake.session or !@client.handshake.session.user
      console.log 'error: do not know the user, ignoring socket event'
      #@emit 'reload'
      return
    user = @client.handshake.session.user
    if not user or not /[^0-9.]/.test(user)
      return
    jsonreq.post_with_body 'http://localhost:8778/remove_from_list', querystring.stringify({ user: user, oid: @data }), (err, data) ->
      jsonreq.get 'http://localhost:8778/load_lists', (err, data) ->
        zappa.io.sockets.emit 'lists', data


  @on 'chat': (socket) ->
    otto.report_event 'chat', @client.channelname, 0, @client.handshake.session.user, @data


  @on 'inchat': (socket) ->
    ourlisteners.set_state @client.handshake.sessionID, @id, 'inchat', @data
    if @data
      [eventname, message] = ['joinedchat', 'joined the chat']
    else
      [eventname, message] = ['leftchat', 'left the chat']
    otto.report_event eventname, @client.channelname, 0, @client.handshake.session.user, message


  @on 'typing': (socket) ->
    ourlisteners.set_state @client.handshake.sessionID, @id, 'typing', @data


  @on 'focus': (socket) ->
    ourlisteners.set_state @client.handshake.sessionID, @id, 'focus', @data


  @on 'idle': (socket) ->
    val = if @data then (new Date()).getTime() else 0
    ourlisteners.set_state @client.handshake.sessionID, @id, 'idle', val


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
    return ';zappa.run(' + otto.client + ');'

  @get '/otto.client.templates.js': ->
    @res.setHeader('Content-Type', 'text/javascript')
    js = """
      window.otto = window.otto || {};
      otto.large_database = #{otto.db.large_database}; /* there are better ways to do this FIXME */
      otto.haslineout = #{process.platform is 'darwin'};
    """
    return js + ';(' + otto.client.templates + ')();'

  @get '/Xotto.client.templates.js': ->
    @res.setHeader('Content-Type', 'text/javascript')
    js = """
      window.otto = window.otto || {};
      otto.large_database = #{otto.db.large_database}; /* there are better ways to do this FIXME */
      otto.templates = (function() {
        templates = {};
        templates.x = {};
         """
    for own template of otto.client.templates
      if template is 'x' then continue
      js += "templates.#{template} = #{otto.client.templates[template]};\n"
    for own x of otto.client.templates.x
      js += "templates.x.#{x} = #{otto.client.templates.x[x]};\n"
    js += """
        return(templates);
      }());
          """
    return js


  @get '/otto.client.:modulename.js': ->
    modulename = @req.params.modulename
    if otto.client[modulename]
      @res.setHeader('Content-Type', 'text/javascript')
      return ';(' + otto.client[modulename] + ')();'
    else
      @res.status(404).send('Not found')


  @get '/': ->
    otto.index.render bodyclasses: '.disconnected'

  @get '/starts_with': ->
    query = @req.query
    otto.db.starts_with query.value, query.attribute, parseInt(query.otype), query.nochildren, (objects) =>
      @res.json(objects)


  @get '/all_albums': ->
    otto.db.all_albums (objects) =>
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
    otto.db.load_object query.oid, query.load_parents, (object) =>
      @res.json(object)


  @get '/album_details': ->
    query = @req.query
    otto.db.album_details query.oid, (object) =>
      @res.json(object)


  @get '/search': ->
    value = @req.query.value
    otto.db.search value, (err, results) =>
      @res.json(results)


  # still to be converted to mongodb
  #@get
    #'/music_root_dirs': proxy_api_request
    #'/load_dir': proxy_api_request
    #'/load_fileunder': proxy_api_request
    #'/load_lists': proxy_api_request


  @get '/load_owners': ->
    query = @req.query
    otto.db.load_owner null, (owners) =>
      @res.json(owners)


  @get '/load_stars': ->
    query = @req.query
    otto.db.load_stars null, yes, (stars) =>
      @res.json(stars)


  @get '/load_newest_albums': ->
    query = @req.query
    otto.db.get_newest_albums (albums) =>
      @res.json(albums)


  proxy_stream = (format) ->
    host = @req.headers.host
    add_stream_callback = (@req, channel, format) =>
      ourlisteners.add_stream @req.session, @req.sessionID
    remove_stream_callback = (@req, channel, format) =>
      ourlisteners.remove_stream @req.sessionID
    console.dir @req.params
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


  @get '/download/:oid': ->
    if not @req.user or not /[^0-9.]/.test(@req.user)
      return @res.send('not logged in', 403)
    oid = @req.params.oid # parseInt(@req.params.oid) <- not anymore!
    jsonreq.get 'http://localhost:8778/load_lists?objects=1', (err, data) =>
      filenames = []
      archivename = no
      for user in data
        console.log "oid #{oid}, user.oid #{user.oid}"
        if oid == user.oid
          archivename = "#{user.owner}.zip"
          console.log "archiving #{archivename} for oid #{user.oid}"
          for item in user.list
            if item.otype == 10
              filename = path.join(user.owner, path.basename(item.filename))
              filenames.push( [item.filename, filename] )
              console.log "adding song #{item.filename} as #{filename}"
            else if item.otype == 20
              albumdirname = path.basename(item.dirpath)
              console.log "adding album #{albumdirname}"
              if item.items and item.items.length
                for song in item.items
                  filename = path.join(user.owner, albumdirname, path.basename(song.filename))
                  filenames.push( [song.filename, filename] )
                  console.log "adding album song #{song.filename} as #{filename}"
      if archivename
        console.log 'writeHead'
        @res.writeHead 200,
          'Pragma': 'public'
          'Expires': '0'
          'Cache-Control': 'must-revalidate, post-check=0, pre-check=0'
          #'Cache-Control': 'public'   # twice? FIXME
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
    http://#{host}/stream/1/#{@req.user}/#{host}
    """


  @get '/otto.pls': ->
    host = @req.headers.host
    @res.setHeader('Content-Type', 'audio/x-scpls')
    """
    [playlist]
    numberofentries=1
    File1=http://#{host}/stream/1/#{@req.user}/Otto%20(#{host})
    Title1=Otto (#{host})
    Length1=-1
    Version=2
    """

  @get '/loader': ->
    otto.loader.load(@req, @res, zappa)


  # a node_webkit hook
  @get '/phase': ->
    @render phaser: {}
  #@view layout: ->  # 'layout' is a magic name
  @view phaser: ->
    script ->
      """
        console.log('in phaser:');
        gui = require('nw.gui');
        console.log('gui = ', gui);
        setTimeout( function() {
          win = gui.Window.open('http://localhost:8778', {
            'width': 1200,
            'height': 1000,
            'show': true,
            'toolbar': true,
            'frame': true });
        }, 3000);
      """


  ########################################


  otto.channels.set_global_event_handler (eventname, channel, args...) ->
    switch eventname
      when 'update'
        zappa.io.sockets.in(channel.name).emit 'playlistinfo', channel.queue

      when 'state'
        zappa.io.sockets.in(channel.name).emit 'state', channel.state

      when 'time'
        zappa.io.sockets.in(channel.name).emit 'time', channel.time

      when 'finished'
        previously_playing = args[0]
        message = 'finished song'
        if previously_playing.requestor
          message += " requested by #{previously_playing.requestor}"
        message += " #{previously_playing.song}"
        otto.report_event 'finished', channel.name, previously_playing.oid, undefined, message

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
        otto.report_event eventname, channel.name, song.oid, user, message


  listeners_event_handler = (eventname, listeners, data) ->
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

  ourlisteners.on '*', listeners_event_handler


  #eventlog = fs.createWriteStream 'static/html/events.html', 'flags': 'a', ->
  #  # not working:
  #  otto.report_event 'ottostarted', undefined, undefined, undefined, (new Date).toUTCString()

  otto.report_event = (name, channelname, oid, user, message) =>
    event =
      timestamp: new Date()
      oid: oid
      user: user
      name: name
      channel: channelname
      message: message
    if channelname
      @io.sockets.in(channelname).emit 'chat', event
    else
      @io.sockets.emit 'chat', event
#!#    eventlog.write otto.client.templates.event event: event
    #eventlog.write '\n'
