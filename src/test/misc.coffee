fs = require 'fs'
os = require 'os'
net = require 'net'
glob = require 'glob'
#cookie_parser = require 'cookie-parser'
#connect = require 'zappajs/node_modules/express/node_modules/connect'
#Session = connect.middleware.session.Session

global.otto = otto = global.otto || {}


module.exports = global.otto.misc = do ->  # note the 'do' causes the function to be called
  misc = {}

  # more coffeescript friendly versions of setTimeout and setInterval
  misc.timeoutSet = (ms, func) -> setTimeout(func, ms)
  misc.intervalSet = (ms, func) -> setInterval(func, ms)


  # from http://stackoverflow.com/questions/280634/endswith-in-javascript
  misc.endsWith = (str, suffix) ->
    return str.indexOf(suffix, str.length - suffix.length) isnt -1


  misc.is_dirSync = (path) ->
    try
      stat = fs.lstatSync path
      if stat then return stat.isDirectory() else return no
    catch err
      if err.code? and err.code is 'ENOENT'
        return no
      else
        throw err


  # check if a path is an existing directory or throw an exception
  misc.assert_is_dirSync = (path) ->
    err = null
    try
      stats = fs.statSync path
    catch error
      err = error
    if err or not stats.isDirectory()
      throw new Error "error: otto needs #{path} to be a directory and it is not"


  # check if a path is an existing directory, create it if not, or throw an exception if it can't be created
  misc.assert_is_dir_or_create_itSync = (path) ->
    err = null
    try
      stats = fs.statSync path
    catch error
      err = error
    if err
      if err.code? and err.code is 'ENOENT'
        fs.mkdirSync path
      else
        throw err
    else
      if not stats.isDirectory() then throw new Error "error: otto needs ${path} to be a directory and it is not"


  # check if a socket is openable, check every 10ms until it is (or until we run out of attempts)
  misc.wait_for_socket = (socket, attempts, callback) ->
    testsocket = net.connect socket, ->
      testsocket.destroy()
      callback null
    testsocket.on 'error', (err) ->
      #console.log "waiting for socket #{socket}"
      attempts--
      if attempts > 0
        misc.timeoutSet 10, ->
          misc.wait_for_socket socket, attempts, callback
      else
        callback "gave up waiting for socket #{socket}"


  # sync. read in a pid from a file (or files, it can take a glob pattern) and send that process a kill signal
  misc.kill_from_pid_fileSync = (pid_file_or_glob) ->
    pid_files = glob.sync pid_file_or_glob
    pid_files.forEach (pid_file) ->
      data = fs.readFileSync pid_file
      pid = parseInt(data)
      process.kill(pid)


  # expand "~" in a filename to the user's home directory
  misc.expand_tilde = (path) ->
    homedir = process.env[if process.platform is 'win32' then 'USERPROFILE' else 'HOME']
    #username = process.env['USER']
    return path.replace /^[~]/, homedir


  # from http://code.google.com/p/js-test-driver/source/browse/tags/1.3.2/idea-plugin/src/com/google/jstestdriver/idea/javascript/predefined/qunit/equiv.js?r=937 -jon
  #
  # Tests for equality any JavaScript type and structure without unexpected results.
  # Discussions and reference: http://philrathe.com/articles/equiv
  # Test suites: http://philrathe.com/tests/equiv
  # Author: Philippe Rath <prathe@gmail.com>

  ##
  ## note: i converted this to coffeescript, but it hasn't been tested yet -jon
  ##

  misc.equiv = ->
    callers = [] # stack to decide between skip/abort functions

    # Determine what is o.
    hoozit = (o) ->
        if typeof o is "string"
            return "string"
        else if typeof o is "boolean"
            return "boolean"
        else if typeof o is "number"
            if isNoN(o) then return "nan" else return "number"
        else if typeof o is "undefined"
            return "undefined"

        # consider: typeof null === object
        else if o is null
            return "null"

        # consider: typeof [] === object
        else if o instanceof Array
            return "array"

        # consider: typeof new Date() === object
        else if o instanceof Date
            return "date"

        # consider: /./ instanceof Object;
        #           /./ instanceof RegExp;
        #          typeof /./ === "function"; # => false in IE and Opera,
        #                                          true in FF and Safari
        else if o instanceof RegExp
            return "regexp"

        else if typeof o is "object"
            return "object"

        else if o instanceof Function
            return "function"

    # Call the o related callback with the given arguments.
    bindCallbacks (o, callbacks, args) ->
        prop = hoozit(o)
        if prop
            if hoozit(callbacks[prop]) is "function"
                return callbacks[prop].apply(callbacks, args)
            else
                return callbacks[prop] # or undefined

    callbacks = do ->

        # for string, boolean, number and null
        useStrictEquality = (b, a) ->
            return a is b

        return {
            "string": useStrictEquality
            "boolean": useStrictEquality
            "number": useStrictEquality
            "null": useStrictEquality
            "undefined": useStrictEquality

            "nan": (b) ->
                return isNaN(b)

            "date": (b, a) ->
                return hoozit(b) is "date" && a.valueOf() is b.valueOf()

            "regexp": (b, a) ->
                return hoozit(b) is "regexp" && \
                    a.source is b.source && \ # the regex itself
                    a.global is b.global && \ # and its modifers (gmi) ...
                    a.ignoreCase is b.ignoreCase && \
                    a.multiline is b.multiline

            # - skip when the property is a method of an instance (OOP)
            # - abort otherwise,
            #   initial === would have catch identical references anyway
            "function": ->
                caller = callers[callers.length - 1]
                return caller isnt Object && \
                        typeof caller isnt "undefined"

            "array": (b, a) ->
                # b could be an object literal here
                if ! (hoozit(b) is "array")
                    return false

                len = a.length
                if len isnt b.length # safe and faster
                    return false
                for x, i in a
                    if ! innerEquiv(a[i], b[i])
                        return false
                return true

            "object": (b, a) ->
                eq = true # unless we can prove it
                aProperties = [] # collection of strings
                bProperties = []

                # comparing constructors is more strict than using instanceof
                if a.constructor isnt b.constructor
                    return false

                # stack constructor before traversing properties
                callers.push(a.constructor)

                for i in a # be strict: don't ensures hasOwnProperty and go deep

                    aProperties.push(i) # collect a's properties

                    if ! innerEquiv(a[i], b[i])
                        eq = false

                callers.pop() # unstack, we are done

                for i in b
                    bProperties.push(i) # collect b's properties

                # Ensures identical properties name
                return eq && innerEquiv(aProperties.sort(), bProperties.sort())
        }

    # the real equiv function
    innerEquiv = -> # can take multiple arguments
        args = Array.prototype.slice.apply(arguments)
        if args.length < 2
            return true # end transition

        return ( (a, b) ->
            if a is b
                return true # catch the most you can

            else if typeof a isnt typeof b || a is null || b is null || typeof a is "undefined" || typeof b is "undefined"
                return false # don't lose time with error prone cases

            else
                return bindCallbacks(a, callbacks, [b, a])

        # apply transition with (1..n) arguments
        )(args[0], args[1]) && arguments.callee.apply(this, args.splice(1, args.length -1))
    return innerEquiv


  class misc.Elapsed
    constructor: ->
      @start = Date.now()
      @lap = @start
    seconds: =>
      now = Date.now()
      lap = ((now-@lap)/1000).toFixed(3)
      total = ((now-@start)/1000).toFixed(3)
      @lap = now
      return "#{lap}s (#{total}s total)"
    toString: -> @seconds()


  # determine the user making the request
  # or fall back to ip address if no user can be determined
  misc.authenticate_user = (req, res, next) ->
    client_ip = req.connection.remoteAddress
    if req.headers['x-forwarded-for'] and (client_ip is '127.0.0.1' or client_ip is '::1')
      # might not work in all cases (e.g. locahost on 127.0.0.2)
      # but we can't just blindly accept potentially injected x-forwarded-for headers
      ip_list = req.headers['x-forwarded-for'].split ','
      client_ip = ip_list[ip_list.length-1]
    localhost = false
    for devicename,infolist of os.networkInterfaces()
      for ip in infolist
        if client_ip == ip.address
          localhost = true
          break
      if localhost then break
    otto.sessioniplist[req.sessionID] = { client_ip: client_ip, localhost: localhost }

    next()


  # use the session cookie set by express to connect
  # the session.io session to the express session
  # from http://www.danielbaulig.de/socket-ioexpress/
  # see also https://github.com/mauricemach/zappa/pull/90
  # and this might be of interest:
  # https://www.npmjs.org/package/session.socket.io

  misc.socket_authenticate_user = (handshake, accept) ->
    console.log 'io.set authorization'
    accept(null, true)
    return

    # check if there's a cookie header
    if handshake.headers.cookie
      # if there is, parse the cookies
      #cookieParser = otto.zappa.express.cookieParser()
      cookie_parser handshake, null, (error) ->
        if error
          console.log 'cookie parse error:', error
          accept('cookie parse error', false)
        else
          # note that you will need to use the same secret key to grab the
          # session id as you specified in the Express setup.
          sessionID = handshake.cookies['express.sid'].split(':')[1].split('.')[0]
          console.log 'sessionID', sessionID
          otto.sessionStore.get sessionID, (err, session) ->
            if err || !session
              # if we cannot grab a session, turn down the connection
              console.log 'error: no session found in database during authentication - ', err
              accept('no session found in database', false)
            else
              # save the session data and accept the connection

              # note that if you throw any exceptions in this 'else' section it'll be
              # caught by sessionStore.get and the 'if' section will be called above!

              # first create a real express session object so we can actually change
              # session data inside socketio communications
              # we fake a req object relying on the connection Session constructor only
              # using two fields from it (sessionID and sessionStore)
              # i looked at the code and verified this for connection 2.6.0
              #fake_req = {sessionID: sessionID, sessionStore: otto.sessionStore}
              #handshake.session = new Session(fake_req, session)

              # we don't need this now
              # # oh well, couldn't quite get that working yet
              # #handshake.session = session

              handshake.sessionID = sessionID
              console.log "socket.io thinks the sessionID is #{handshake.sessionID}"
              accept(null, true)
    else
      # if there isn't, turn down the connection with a message
      # and leave the function.
      # hacked to allow app to connection via. socket.io FIXME
      #return accept('no express session ID cookie transmitted', false)
      accept(null, true)


  misc.debug_request = (req, res, next) ->
    was_image = false
    do ->
      # collapse all contiguous /image* urls into one debug message
      if /^[/]image/.test req.url
        if !was_image
          #console.log 'loading /images...'
          was_image = true
      else
        console.log req.url
        was_image = false
      next()


  misc.dBscale = (x) ->
    # logarithmic volume dB scale approximations
    # http://www.dr-lex.be/info-stuff/volumecontrols.html
    # http://www.360doc.com/content/09/1127/20/155970_9889546.shtml
    n = Math.round( Math.pow(4, (x / (100 / 3.322))) )  # x^4
    #n = Math.round( Math.pow(3, (x / (100 / 4.192))) )  # x^3
    #n = Math.round( Math.pow(2, (x / (100 / 6.644))) )  # x^2
    return n

  return misc
