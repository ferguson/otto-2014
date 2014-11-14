otto = global.otto

require './otto.livedev' if process.env.NODE_ENV is 'development'

otto.main = ->
  console.log 'node version ' + process.version
  if process.versions['node-webkit']
    console.log 'node-webkit version ' + process.versions['node-webkit']

  cleanup_processes = ->
    console.log 'killing mpds'
    otto.mpd.kill_all_mpdsSync()
    console.log 'killing mongod'
    otto.db.kill_mongodSync()

  crash_handler = (err) ->
    console.log 'exception: ' + err
    console.log err.stack
    process.removeListener 'on', crash_handler
    # we should capture the exception to a file for debugging
    otto.exiting = true
    cleanup_processes()
    #throw new Error err
    #console.trace()
    process.exit(1)

  # ctrl-c
  process.on 'SIGINT', ->
    cleanup_processes()
    process.exit()

  # kill (default)
  process.on 'SIGTERM', ->
    # don't cleanup processes when in development mode
    # this let's mpd (and mongo) keep running when the
    # supervisor node module reloads us do to a file change
    # (we prefer supervisor to nodemon these days)
    if process.env.NODE_ENV isnt 'development'
      cleanup_processes()
    process.exit()

  # nodemon detected a file change
  process.once 'SIGUSR2', ->
    cleanup_processes()
    process.kill(process.pid, 'SIGUSR2')

  # crashes
  #!#process.on 'uncaughtException', crash_handler

  # we still need to catch and deal with ENOACCESS and other problems opening the http port
  # (though ENOACCESS is less important now that we decided to not run on port 80)

  otto.db.init ->
    otto.channels.init ->
      otto.server()
