fs = require 'fs'
net = require 'net'
querystring = require 'querystring'
child_process = require 'child_process'

otto = global.otto

module.exports = global.otto.mongod = do ->  # note the 'do' causes the function to be called
  mongod = {}


  mongod.init = (callback) ->
    mongod.assemble_conf()
    mongod.spawn ->
      callback mongod.conf.url_escaped


  mongod.assemble_conf = (db_name) ->
    mongod.conf =
      db: "#{db_name}"
      host: otto.OTTO_VAR + '/mongod.sock'
      domainSocket: true
      url: "mongodb://#{otto.OTTO_VAR + '/mongod.sock'}"
      url_escaped: "mongodb://#{querystring.escape(otto.OTTO_VAR + '/mongod.sock')}"
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

    mongod.conf.text = """
      # auto generated (and regenerated) by otto, don't edit

      dbpath = #{mongod.conf.db_directory}
      pidfilepath = #{mongod.conf.pid_file}
      bind_ip = #{mongod.conf.socket_file}
      #bind_ip = #{mongod.conf.bind_ip}
      port = #{mongod.conf.port} # not really used, socket file on previous line is used instead
      nounixsocket = true  # suppresses creation of a second socket in /tmp
      #nohttpinterface = true
      journal = on
      noprealloc = true
      noauth = true
      #verbose = true
      quiet = true
      profile = 0  # don't report slow queries
      slowms = 2000  # it still prints them to stdout though, this'll cut that down

      """  # blank line at the end is so conf file has a closing CR (but not a blank line)

    return mongod.conf


  mongod.spawn = (callback) ->
    # see if there is an existing mongod by testing a connection to the socket
    testsocket = net.connect mongod.conf.socket_file, ->
      # mongod process already exists, don't spawn another one
      console.log "using existing mongod on #{mongod.conf.socket_file}"
      testsocket.destroy()

      callback()

    testsocket.on 'error', (err) ->
      #console.log 'error', err
      testsocket.destroy()
      console.log "no existing mongod found, spawning a new one on #{mongod.conf.socket_file}"
      console.log "...using executable #{mongod.conf.mongod_executable}"
      # we wait until now to write the conf file so we don't step on existing conf files for an existing mongod
      fs.writeFile mongod.conf.file, mongod.conf.text, (err) ->
        if err then throw err
        opts =
          #stdio: [ 'ignore', 'ignore', 'ignore' ]
          detached: true
          #env :
          #  DYLD_FALLBACK_LIBRARY_PATH: otto.OTTO_LIB
          #  LD_LIBRARY_PATH: otto.OTTO_LIB
        if otto.OTTO_SPAWN_AS_UID
          opts.uid = otto.OTTO_SPAWN_AS_UID
        child = child_process.spawn mongod.conf.mongod_executable, ['-f', mongod.conf.file], opts
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

        otto.misc.wait_for_socket mongod.conf.socket_file, 1500, (err) ->  # needed to be > 500 for linux
          if err then throw new Error err
          callback()


  mongod.kill_mongodSync = ->
    # needs to be Sync so we finish before event loop exits
    otto.misc.kill_from_pid_fileSync otto.OTTO_VAR + '/mongod.pid'


  return mongod