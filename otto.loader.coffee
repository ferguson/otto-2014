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
  child = false


  loader.load = (zappa, path) ->
    console.log 'loader.load'
    console.log 'path', path
    #shell_cmd_debug('pwd')
    #shell_cmd_debug('env')
    if loading
      zappa.io.sockets.emit 'loader', 'started'  # just for dev? perhaps not!
      return 'currently loading'
    else
      loading = true

      opts =
        #detached: true
        #env :
        #  DYLD_FALLBACK_LIBRARY_PATH: otto.OTTO_LIB
        #  LD_LIBRARY_PATH: otto.OTTO_LIB

      console.log 'spawning scan.py'
      args = ['-u', otto.OTTO_ROOT + '/scan.py', '-j']
      if path then args.push path
      child = child_process.spawn otto.OTTO_BIN + '/python', args, opts
      #console.log 'child', child

      #child.unref()
      console.log child.pid
      console.log 'loader started'
      parser = jsonstream.parse([true])  # we'll take anything
      #res.send '<pre>'
      zappa.io.sockets.emit 'loader', 'started'

      loader_says = (data) ->
        console.log 'loader: ' + data
        #res.send String(data)
        zappa.io.sockets.emit 'loader', String(data)

      child.stdout.pipe(parser)
      child.stderr.on 'data', loader_says

      starter = []
      parser.on 'data', (data) ->
        #if data.stdout
        #  loader_says(data.stdout)
        #console.log 'loader: ', data
        zappa.io.sockets.emit 'loader', data
        if data.album
          console.log 'loader says album:', data
          if data.songs
            for song in data.songs
              if song.song and hash_code2(song.song) in [-647063660, -1208355988]
                starter.push song
                console.log 'spotted one!', song.song

      child.on 'exit', (code, signal) ->
        child = false
        loading = false
        return if otto.exiting
        console.log "loader exited with code #{code}"
        if signal then console.log "...and signal #{signal}"
        #res.end()
        wasempty = otto.db.emptydatabase
        otto.db.emptydatabase = false
        firstchannel = false
        for own channelname of otto.channels.channel_list
          channel = otto.channels.channel_list[channelname]
          if not firstchannel then firstchannel = channelname
          do (channelname) ->
            if channelname is firstchannel
              if wasempty and starter.length
                id = starter[Math.floor Math.random() * starter.length]._id
                channel.add_to_queue id, 'otto', ->
                  console.log 'starter', id
                  status = if code or signal then 'error' else 'finished'
                  zappa.io.sockets.emit 'loader', status
              else
                channel.autofill_queue ->
                  console.log 'initial autofill done, channelname ', channelname
                  zappa.io.sockets.emit 'loader', if code or signal then 'error' else 'finished'
            else
              channel.autofill_queue ->
                console.log 'initial autofill done, channelname ', channelname


  loader.cancel = (zappa) ->
    if loading and child
      child.kill()


  hash_code = (str) ->
    hash = 0
    for char in str
      hash = ((hash<<5)-hash)+char.charCodeAt(0)
      hash = hash & hash # Convert to 32bit integer
    return hash


  hash_code2 = (str) ->
    hashstr = ''
    for c in str.toLowerCase()
      if /[abdf-prstv-z]/.test(c)
        hashstr = hashstr + c
        if hashstr.length > 9
          break
    return hash_code(hashstr)


  shell_cmd_debug = (cmd, args, callback) ->
    child = child_process.spawn(cmd, args)
    buffer = ''
    child.stdout.on 'data', (output) -> buffer += output
    child.stdout.on 'end', -> if callback then callback buffer else console.log 'shell_cmd_debug', cmd, ':\n', buffer


  return loader
