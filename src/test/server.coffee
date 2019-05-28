fs = require 'fs'
path = require 'path'
zappajs = require 'zappajs'
zappajs_plugin_client = require 'zappajs-plugin-client'
#cookie_parser = require 'cookie-parser'
connect_mongo = require 'connect-mongo'
express_session = require 'express-session'

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

  otto.sessionlist = {}
  otto.sessioniplist = {}
  otto.socketlist = {}


#############################################
## the zappa application function starts here
#############################################
server_go = ->
  # @ = zappa in this context

  # from http://stackoverflow.com/questions/6819911/nodejs-expressjs-session-handling-with-mongodb-mongoose
  MongoStore = connect_mongo(express_session)
#  otto.sessionStore = new MongoStore(otto.db.dbconf)
  otto.sessionStore = new MongoStore(url: "mongodb://#{otto.OTTO_VAR + '/mongod.sock'}")

#  @use cookie_parser()
  #@use session: { store: otto.sessionStore, secret: otto.SECRET, key: 'express.sid'}, =>
  #  # we should wait for this callback before proceeding FIXME <- wait!
  #  #   it seems to trigger on each connection? or maybe each socket.io message?
  #  # otherwise we risk getting a "Error setting TTL index on collection" error
  #  # see https://github.com/kcbanner/connect-mongo/pull/58#issuecomment-32148111
  #  console.log 'session db connection established'
  oneYear = 365 * 24 * 60 * 60 * 1000;
  sessionOpts =
    store: otto.sessionStore
    secret: otto.SECRET
    #key: 'express.sid'
    resave: false
    saveUninitialized: false
    cookie: {maxAge: oneYear}
  @use {session: sessionOpts}
  @app.use '/static', @express.static(__dirname + '/static')

#  @app.use otto.misc.authenticate_user
#  @app.use (req, res, next) ->
#    req.session.sessionID = req.sessionID
#    next()
#  @app.use (req, res, next) ->
#    otto.sessionlist[req.sessionID] = req.session
#    next()
#  @io.set 'authorization', otto.misc.socket_authenticate_user
#  @enable 'serve jquery', 'serve sammy', 'serve zappa'
  @with zappajs_plugin_client
#  @use 'partials'

  @io.set 'log level', 2


  @on 'connection': ->
    console.log 'sio connection'
    @session.sio_count++
    otto.socketlist[@id] = @socket

  @on 'connected': ->
    console.log 'sio connected'
    console.log @id, Object.keys(otto.socketlist)
    console.log @session
    session = socket_get_session @
    console.log 'session is', session
    if not session
      console.log 'telling client to resession'
      @emit 'resession'
    else
      console.log 'telling client to proceed'
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


  ########################################


  @get '/': ->
    console.log 'GET /'
    console.log '@id', @id, '@session', @session
    @session.count++
    otto.index.render bodyclasses: '.disconnected'

  # we ask the client to hit this when we need to reload their session cookie
  @get '/resession': ->
    console.log 'GET /resession'
    console.log '@id', @id, '@session', @session
    return ''


  #@coffee '/shared.js': ... # use @coffee if you want the code to be shared between server and client
  # these seem to cache the outgoing results! plus they wrap everything in zappa.run
  #@client '/otto.client.js': otto.client
  #@client '/otto.client.cubes.js': otto.client.cubes
  #@client '/otto.client.soundfx.js': otto.client.soundfx
  #@client '/otto.client.templates.js': otto.client.templates

  #@client 'shunt.js': otto.client  # seems something must use @client for zappa.js to be served


  @get '/otto.client.js': ->
    @res.setHeader('Content-Type', 'text/javascript')
    #return ';(' + otto.client + ')();'
    return ';window.otto = window.otto || {};Zappa(' + otto.client + ');'


  @get '/otto.client.:modulename.js': ->
    modulename = @req.params.modulename
    if otto.client[modulename]
      @res.setHeader('Content-Type', 'text/javascript')
      return ';(' + otto.client[modulename] + ')();'
    else
      @res.status(404).send('Not found')

  ########################################

#  socket_get_session = (s) -> otto.sessionlist[s.io.handshaken[s.id].sessionID]
#  socket_get_sessionip = (s) -> otto.sessioniplist[s.io.handshaken[s.id].sessionID]
  socket_get_session = (s) -> otto.sessionlist[s.id]
  socket_get_sessionip = (s) -> otto.sessioniplist[s.id]

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
