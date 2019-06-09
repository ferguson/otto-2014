otto = global.otto

if process.versions.hasOwnProperty('electron')
  electron = require 'electron'

require './livedev' if process.env.NODE_ENV is 'development'

otto.cleanup_processes = ->
  console.log 'killing mpds'
  otto.mpd.kill_all_mpdsSync()
  console.log 'killing mongod'
  otto.mongod.kill_mongodSync()

otto.main = (cb) ->
  console.log 'node version ' + process.version
  console.log 'electron version ' + process.versions['electron'] if process.versions['electron']


  crash_handler = (err) ->
    console.log 'exception: ' + err
    console.log err.stack
    process.removeListener 'on', crash_handler
    # we should capture the exception to a file for debugging
    otto.exiting = true
    otto.cleanup_processes()
    #throw new Error err
    #console.trace()
    process.exit(1)

#see NOTES
#  # ctrl-c
#  process.on 'SIGINT', ->
#    otto.cleanup_processes()
#    process.exit()

#  # kill (default)
#  process.on 'SIGTERM', ->
#    # don't cleanup processes when in development mode
#    # this let's mpd (and mongo) keep running when the
#    # supervisor node module reloads us do to a file change
#    # (we prefer supervisor to nodemon these days)
#    if process.env.NODE_ENV isnt 'development'
#      otto.cleanup_processes()
#    process.exit()

  # nodemon detected a file change
  process.once 'SIGUSR2', ->
    otto.cleanup_processes()
    process.kill(process.pid, 'SIGUSR2')

  # crashes
  #!#process.on 'uncaughtException', crash_handler

  # we still need to catch and deal with ENOACCESS and other problems opening the http port
  # (though ENOACCESS is less important now that we decided to not run on port 80)

  otto.mongod.init (url_escaped) ->
    console.log 'mongod.inited'
    otto.db.init 'otto', url_escaped, ->
      console.log 'db.inited'
      otto.channels.init ->
        console.log 'channels.inited'
        otto.server ->
          console.log 'server inited'
          cb() if cb
