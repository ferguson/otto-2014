otto = global.otto

otto.main = ->
  #console.log = ->
  #  for arg in arguments
  #    process.stdout.write String(arg)+' '
  #  process.stdout.write '\n'

  console.log 'node version ' + process.version
  if process.versions['node-webkit']
    console.log 'node-webkit version ' + process.versions['node-webkit']

  #if process.versions['node-webkit']
  process.mainModule.exports.call_me_when_ready = (callback) ->
    if otto.listening
      callback 'http://localhost:8778'
    else
      otto.on_listening_hook = ->
        callback 'http://localhost:8778'

  process.mainModule.exports.node_webkit_context_hook = (gui, window, start_win) ->
    otto.gui = gui
    otto.window = window
    otto.start_win = start_win
    process.mainModule.exports.otto = otto   #!# just for debugging, remove me
    console.log '#'
    console.log otto.gui
    console.log '#'

    console.log process.versions
    console.log process.versions['node-webkit']
    #if process.versions['node-webkit']
    #  otto.window.console.log 'running under node-webkit, creating menubar menu'
    #  otto.menu.startup()
    otto.menu.startup()


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
    #cleanup_processes() # don't cleanup processes on a SIGTERM
    #this let's mpd (and mongo) keep running when node debugging
    #module supervsior reloads us do to a file change
    #(we prefer supervisor to nodemon these days)
    #this has the unfortunate side effect of not shutting
    #everything down if someone kills otto from the command line
    #we could patch supervisor to send a different signal
    #wait! i have an idea:
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

  # speaking of which, we might want to have an option to change to a plain user if we are
  # launched as root or, we could just recommend people use supervisord (the python one, not
  # to be confused with node-supervisor)

  # git for auto updates, rsync

  otto.db.init ->
    otto.channels.init ->
      otto.server()





#    if process.env['USER'] is 'root'
#      try
#        safeuser = 'jon'
#        safeuserpw = posix.getpwnam(safeuser)
#        console.log "switching to user '#{safeuser}'"
#        process.setgid safeuserpw.gid
#        process.setuid safeuserpw.uid
#        console.log "new uid: #{process.getuid()}"
#      catch err
#        console.log 'failed to drop root privileges: ' + err
