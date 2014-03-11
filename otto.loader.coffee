_ = require 'underscore'
fs = require 'fs'
net = require 'net'
#posix = require 'posix'
posix = require 'fs'
jsonstream = require 'JSONStream'
child_process = require 'child_process'

require './otto.misc'  # attaches to global.otto.misc
otto = global.otto


global.otto.loader = do ->  # note the 'do' causes the function to be called
  loader = {}

  loading = false

  loader.load = (req, res, zappa) ->
    if loading
      return "currently loading"
    else
      loading = true

      opts =
        #detached: true
        #env :
        #  DYLD_FALLBACK_LIBRARY_PATH: otto.OTTO_LIB
        #  LD_LIBRARY_PATH: otto.OTTO_LIB
      #if process.env['USER'] is 'root'
      #  opts.uid = posix.getpwnam('jon').uid  # mpd can't use file:/// as root, also: not Windows

      # we should pass in the musicroot we found instead of letting loader.py find it itself?
      # we might also want to pass in a flag to change the output format to be more compatable to being parsed
      child = child_process.spawn otto.OTTO_BIN + '/python', ['-u', otto.OTTO_ROOT + '/loader.py', '-j'], opts

      #child.unref()
      console.log child.pid
      console.log 'loader started'
      parser = jsonstream.parse([true])  # we'll take anything
      res.send '<pre>'
      zappa.io.sockets.emit 'loader', 'started'
      loader_says = (data) ->
        console.log 'loader: ' + data
        res.send String(data)
        zappa.io.sockets.emit 'loader', String(data)
      child.stdout.pipe(parser)
      child.stderr.on 'data', loader_says
      parser.on 'data', (data) ->
        #if data.stdout
        #  loader_says(data.stdout)
        console.log 'loader: ', data
        zappa.io.sockets.emit 'loader', data

      child.on 'exit', (code, signal) ->
        return if otto.exiting
        loading = false
        console.log "loader exited with code #{code}"
        if signal then console.log "...and signal #{signal}"
        res.end()
        zappa.io.sockets.emit 'loader', 'finished'


  return loader
