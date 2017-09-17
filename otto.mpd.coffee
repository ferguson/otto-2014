_ = require 'underscore'
fs = require 'fs'
net = require 'net'
child_process = require 'child_process'

mpdsocket = require 'mpdsocket'
require './otto.misc'  # attaches to global.otto.misc
require './otto.events'
otto = global.otto


global.otto.mpd = do ->  # note 'do' calls the function
  mpd = {}

  mpd_list = {}
  mpd_slots = []


  mpd.kill_all_mpdsSync = ->
    otto.misc.kill_from_pid_fileSync "#{otto.OTTO_VAR_MPD}/[0-9]*pid"


  mpd.MPD = class MPD extends otto.events.EventEmitter
    constructor: (@name, @slot=0) ->
      super ['*', 'start', 'time', 'state', 'status', 'playlist', 'outputs', 'replaygain', 'died'] # valid events
      if mpd_list[@name]
        throw new Error "already an mpd with name #{@name}"
      mpd_list[@name] = @
      # slots start at 1
      if not @slot
        for mpd_slot, i in mpd_slots
          if !mpd_slot
            @slot = i+1
            break
        if !@slot
          @slot = mpd_slots.length+1
      #if @slot < 1 or @slot > 99   # perhaps we don't need to limit this to 99 (ha!)
      #  throw new Error "error: bad mpd slot number #{@slot}, can only be from 1 to 99"
      mpd_slots[@slot-1] = @
      @slotstr = "#{@slot}"
      if @slotstr.length < 2 then @slotstr = '0'+@slotstr  # convert 1..9 to 01..09

      @cache = {}
      @streamcount = 0
      @autopause = yes

      @conf_file       = "#{otto.OTTO_VAR_MPD}/#{@slotstr}-mpd.conf"
      # the '-' in the filename above is to make it appear first in a
      # directory listing for a given slot's related files
      @music_dir       = "#{otto.OTTO_VAR_MPD_MUSIC}"
      @db_file         = "#{otto.OTTO_VAR_MPD}/#{@slotstr}database"
      @log_file        = "#{otto.OTTO_VAR_MPD}/#{@slotstr}log"
      @pid_file        = "#{otto.OTTO_VAR_MPD}/#{@slotstr}pid"
      @state_file      = "#{otto.OTTO_VAR_MPD}/#{@slotstr}state"
      @control_port    = (@slot-1)+6600  # not currently used
      @control_socket  = "#{otto.OTTO_VAR_MPD}/#{@slotstr}socket"
      # for relability we should probably check if ports are free first
      # and assign them more dynamically, but this would lose the easy
      # mapping between slot numbers and their streaming port numbers
      # which would make reusing existing mpd processes more difficult
      # (we'd need to dig in to the on-disk conf file to find the correct
      # streaming port numbers), so for now:
      @stream_ports =
        'mp3': (@slot-1)*3+8101,  # 8101 for slot 1, 8104 for slot 2
        'ogg': (@slot-1)*3+8102,  # 8102 for slot 1, 8105 for slot 2
        'wav': (@slot-1)*3+8103,  # 8103 for slot 1, 8106 for slot 2
      @stream_sockets =  # not currently used
        'mp3': "#{otto.OTTO_VAR_MPD}/#{@slotstr}socket_mp3"
        'ogg': "#{otto.OTTO_VAR_MPD}/#{@slotstr}socket_ogg"
        'wav': "#{otto.OTTO_VAR_MPD}/#{@slotstr}socket_wav"
      @mpd_executable  = "#{otto.MPD_EXECUTABLE}"


    connect: (callback) ->
      if @mpdsocket
        throw new Error "mpd already connected for #{@name}"
      @spawn =>
        #@mpdsocket = new mpdsocket 'localhost', @control_port, false
        @mpdsocket = new mpdsocket @control_socket, '', false
        @mpdsocket.on 'connect', =>
          #console.log "mpd connected on port #{@control_port}"
          console.log "mpd connected for #{@name} on socket #{@control_socket}"
          @setup callback


    disconnect:
      delete @mpdsocket


    setup: (callback) ->
      console.log 'mpd setup'
      @mpdsocket.send 'repeat 0', =>
        @mpdsocket.send 'random 0', =>
          @mpdsocket.send 'single 0', =>
            @mpdsocket.send 'consume 1', =>
              #@mpdsocket.send 'crossfade 10', =>
              @mpdsocket.send 'crossfade 5', =>
                @mpdsocket.send 'replay_gain_mode track', =>
                  @start callback
                  if @name is 'main'
                    #@mpdsocket.send 'play 0', =>
                    #@mpdsocket.send 'pause 0', =>
                    #@playifnot ->
                    console.log ''


    start: (callback) ->
      #console.log "mpd starting for #{@name}"
      # prime the pump
      @refresh callback
      # then setup the intervals
      @status_interval = otto.misc.intervalSet 100, => @status_watchdog()
      @playlist_interval = otto.misc.intervalSet 200, => @playlist_watchdog()
      @outputs_interval = otto.misc.intervalSet 1000, => @outputs_watchdog()
      @replaygain_interval = otto.misc.intervalSet 1000, => @replaygain_watchdog()
      @trigger 'start'
      if callback
        callback()


    stop: (callback) ->
      clearInterval @status_interval
      clearInterval @playlist_interval
      clearInterval @outputs_interval
      clearInterval @replaygain_interval
      if callback
        callback()


    send: (req, callback) ->
      try
        @mpdsocket.send req, callback
      catch mpdsocketNotOpenExeption
        if not @revive_pending
          @revive_pending = true
          # mpd seems to have died
          console.log "********\n******** mpd #{@slot} died! trying to revive it\n********"
          @reset =>
            @trigger 'died'
            @revive =>
              @revive_pending = false
              ## try sending the failed command again (not sure this is a good idea)
              #@send req, callback
              # we're just going to abandon all callbacks and let the upper layer reset itself
              # with the 'died' event above
        else
          #callback()  # not gonna work (won't have the right arguments, like r for example)


    reset: (callback) ->
      # stop everything, clear out the state file
      # and delete the mpdsocket
      @stop()
      try
        fs.unlinkSync @state_file
      catch ENOENT
      delete @mpdsocket
      if callback
        callback()


    restoreoutputs: (cache, callback) ->
      if cache.metavolume?
        @setvol cache.metavolume, ->
      console.log 'restoring outputs'
      if cache.outputs
        for output in cache.outputs
          if output.outputenabled is '1'
            @send "enableoutput #{output.outputid}", ->
          else
            @send "disableoutput #{output.outputid}", ->
      callback()


    restorereplaygain: (cache, callback) ->
      if cache.metavolume?
        @setvol cache.metavolume, ->
      console.log 'restoring replaygain'
      if cache.replaygain
        @send "replay_gain_mode #{cache.replaygain}", ->
          callback()


    revive: (callback) ->
      # try to revive a dead mpd by clearing out it's state file
      # to remove the potentially bad track and then restore it's state
      # we don't currently restore the rest of the playlist FIXME
      wasplaying = @cache.state is 'play'
      oldcache = @cache
      @connect =>
        @restoreoutputs oldcache, =>
          @restorereplaygain oldcache, =>
            # restore the playlist (minus the suspect song)
            if oldcache.playlist
              console.log 'restoring playlist'
              newplaylist = []
              for song in oldcache.playlist
                newplaylist.push 'file://'+song.file
              if oldcache.status?.song?
                newplaylist.splice(oldcache.status.song, 1)
              else
                newplaylist.splice(0, 1)  # gotta remove something :)
              for file in newplaylist
                @addid file, null, ->
              console.log 'done restoring playlist'
            if wasplaying
              # hack: give it some time to get the queue filled
              # (currently fails because picking songs is so damn slow)
              # (bumped it up from 500ms to 3000ms)
              # (wouldn't be an issue if we restored the playlist) FIXME
              #otto.misc.timeoutSet 3000, =>
              #  @play 0, ->
              @play 0, ->
            callback()


    #####
    ##### simple direct mpd protocol commands
    #####

    status: (callback) ->
      @send 'status', callback

    playlistinfo: (callback) ->
      @send 'playlistinfo', callback

    outputs: (callback) ->
      @send 'outputs', callback

    replaygainstatus: (callback) ->
      @send 'replay_gain_status', (r) ->
        callback r[0].replay_gain_mode

    replaygainmode: (mode, callback) ->
      @send "replay_gain_mode #{mode}", callback
      @replaygain_watchdog()

    pause: (callback) ->
      @send 'pause', callback
      @status_watchdog()

    seekcur: (seconds, callback) ->
      # newer mpds have a seekcur command, let's fake it
      @status (r) =>
        songpos = r[0].song
        console.log 'songpos', songpos
        console.log 'seek', songpos, seconds
        @send "seek #{Number(songpos)} #{Number(seconds)}", callback
        @status_watchdog()

    next: (callback) ->
      @send 'next', callback
      @playlist_watchdog()

    enableoutput: (id, callback) ->
      @status (r) =>
        # help hide mpd's '-1' volume when no output is enabled
        if r[0].volume == '-1'
          @send "enableoutput #{id}", =>
            @setvol @cache.metavolume, callback
          @outputs_watchdog()
        else
          @send "enableoutput #{id}", callback
          @outputs_watchdog()

    disableoutput: (id, callback) ->
      @send "disableoutput #{id}", callback
      @outputs_watchdog()

    setvol: (vol, callback) ->
      @send "setvol #{vol}", callback
      # help hide mpd's '-1' volume when no output enabled
      @cache.metavolume = vol
      @status_watchdog()

    togglecrossfade: ->
      if @cache.status.xfade is '0'
        @send 'crossfade 5', ->
      else
        @send 'crossfade 0', ->
      @status_watchdog()

    togglereplaygain: ->
      if @cache.replaygain is 'off'
        @send 'replay_gain_mode track', ->
      else
        @send 'replay_gain_mode off', ->
      @replaygain_watchdog()


    # attempt to get mpd to load new files it might not have in it's database yet
    update: (filename, callback) ->
      filename = '"'+filename+'"'
      @send "update #{filename}", callback

    addid: (filename, pos=undefined, callback) ->
      filename = '"'+filename+'"'
      pos = if pos? then ' '+pos else ''
      @send "addid #{filename}#{pos}", callback
      #@playlist_watchdog()

    deleteid: (id, callback) ->
      @send "deleteid #{id}", callback
      @playlist_watchdog()

    repeat: (flag, callback) ->
      @send "repeat #{flag}", callback
      @status_watchdog()

    single: (flag, callback) ->
      @send "single #{flag}", callback
      @status_watchdog()

    consume: (flag, callback) ->
      @send "consume #{flag}", callback
      @status_watchdog()

    clear: (callback) ->
      @send 'clear', callback
      @status_watchdog()
      @playlist_watchdog()

    play: (pos=undefined, callback) ->
      #console.log "play! for #{@name} pos #{pos}"
      pos = if pos? then ' '+pos else ''
      @send 'play'+pos, callback
      @status_watchdog()


    ######
    ###### more complex commands
    ######


    play_url: (urls, callback) ->
      @autopause = no
      # set repeat 1? single 1? consume 0?
      @repeat 1, =>
        @single 1, =>
          @consume 0, =>
            @clear =>
              urllist = [].concat(urls)
              addurls = =>
                if urllist.length
                  oneurl = urllist.shift()
                  #console.log 'adding url', oneurl
                  #console.log 'urllist', urllist
                  #console.log 'urls', urls
                  @addid oneurl, 0, (mpdresponse) => addurls()
                else
                  @play 0, callback
              addurls()


    play_archive: (filenames, callback) ->
      @autopause = no
      # set repeat 1 single 0? consume 0
      @repeat 1, =>
        @single 0, =>
          @consume 0, =>
            @clear =>
              filenamelist = [].concat(filenames)
              @addsongs filenamelist, =>
                @play undefined, callback


    playifnot: (callback) ->
      @status (r) =>
        #console.log r[0].state, '<<<<'
        if r[0].state is 'play'
          callback()
        else if r[0].state is 'stop'
          @play undefined, callback
        else if r[0].state is 'pause'
          @pause callback # pause doesn't need a delay, stream sockets exist while paused


    addsongs: (mpdfilenames, callback) ->
      addonesong = (filename, singlecallback) =>
        # first we execute a mpd db update command on the single file
        # to make sure it's in it's perhaps incomplete database
        #@update filename, =>
        # EXCEPT this isn't needed when using unix domain sockets and
        # when using the full filename in addid (not file:/// apparently?)
        @addid filename, null, singlecallback
      i = 0
      console.log 'addsongs', mpdfilenames.length
      recurse = ->
        addonesong mpdfilenames[i], ->
          if ++i < mpdfilenames.length
            console.log 'recurse', i
            recurse()
          else
            console.log 'callback', i
            callback()
      recurse()


    #####
    ##### state change watchdogs
    #####


    refresh: (callback) ->
      @cache = {}
      callcount = 4
      @status_watchdog   ->
        if callcount-- == 1 and callback
          callback()
      @playlist_watchdog =>
        if callcount-- == 1 and callback
          callback()
          @trigger 'playlist', @cache.playlist  # triggers autofill
      @outputs_watchdog  ->
        if callcount-- == 1 and callback
          callback()
      @replaygain_watchdog  ->
        if callcount-- == 1 and callback
          callback()


    status_watchdog: (callback) ->
      @status (r) =>
        newtime = r[0].time
        if not _.isEqual newtime, @cache.time
          @cache.time = newtime
          @trigger 'time', @cache.time
        newstate = r[0].state
        if not _.isEqual newstate, @cache.state
          @cache.state = newstate
          @trigger 'state', @cache.state
        newstatus = _.omit r[0], ['elapsed']
        # also consider omitting bitrate, time, playlist{,length}, nextsong{,id}

        # work around a feature of mpd that messes up our ui
        # if output isn't enabled the volume status is reported as -1
        # let's hide that
        # one side effect of this is that when the server is restarted
        # channels that don't have an output enabled have their volume
        # bar set wrong until the output is enabled. to FIXME we'll need
        # to store the metavolume in the database
        # or maybe it's the "cannot call methods on slider prior to initialization"
        # error i'm getting in the console
        if newstatus.volume == '-1'
          newstatus.volume = @cache.metavolume
        else
          @cache.metavolume = newstatus.volume
        if not _.isEqual newstatus, @cache.status
          @cache.status = newstatus
          @trigger 'status', @cache.status
        if callback
          callback


    playlist: (callback) ->
      @status (r1) =>
        songpos = r1[0].song
        @playlistinfo (r2) =>
          r2.songpos = songpos
          callback r2

    playlist_watchdog: (callback) ->
      @playlist (r) =>
        if not _.isEqual(r, @cache.playlist)
          @cache.playlist = r
          @trigger 'playlist', @cache.playlist
        if callback
          callback


    outputs_watchdog: (callback) ->
      @outputs (r) =>
        newtime = r[0].time
        if not _.isEqual r, @cache.outputs
          @cache.outputs = r
          @trigger 'outputs', @cache.outputs
        if callback
          callback


    replaygain_watchdog: (callback) ->
      @replaygainstatus (r) =>
        newtime = r[0].time
        if not _.isEqual r, @cache.replaygain
          @cache.replaygain = r
          @trigger 'replaygain', @cache.replaygain
        if callback
          callback


   #####
   ##### other stuff
   #####


    setautopause: (flag=yes) ->
      @autopause = flag   # why didn't = flag? work?


    spawn: (callback) ->
      # see if there is an existing mpd by testing a connection to the socket
      testsocket = net.connect @control_socket, =>
        testsocket.destroy()
        # mpd process already exists, don't spawn and just use the existing socket
        console.log "using existing mpd for slot #{@slot} on #{@control_socket}"
        callback()

      # error means we need to spawn an mpd process
      testsocket.on 'error', (err) =>
        testsocket.destroy()
        console.log "no existing mpd found for slot #{@slot}, spawning a new one on #{@control_socket}"
        console.log "...using executable #{@mpd_executable}"
        # generate and write the conf file
        @generate_conf_file_text()
        fs.writeFile @conf_file, @conf_file_text, (err) =>
          if err then throw err
          opts =
            detached: true
            env :
              DYLD_FALLBACK_LIBRARY_PATH: otto.OTTO_LIB
              LD_LIBRARY_PATH: otto.OTTO_LIB
          if otto.OTTO_SPAWN_AS_UID
            opts.uid = otto.OTTO_SPAWN_AS_UID

          child = child_process.spawn @mpd_executable, ['--no-daemon', @conf_file], opts
          child.unref()
          mpd_says = (data) =>
            console.log "mpd#{@slotstr}: " + data  # i could make this a different color. fun!
          child.stdout.on 'data', mpd_says
          child.stderr.on 'data', mpd_says
          child.on 'exit', (code, signal) ->
            return if otto.exiting
            console.log "mpd #{@slot} exited with code #{code}"
            if signal then console.log "...and signal #{signal}"
            # when mpd crashes, we should consider blowing away the state file
            # and removing the currently playing song from the queue and then
            # firing things up again (and perhaps recording a problem with that file)
            # (we have since added code on 'send' to detect a dead mpd and try
            #  to revive it there. perhaps it would be better done here)

          otto.misc.wait_for_socket @control_socket, 500, (err) ->
            if err then throw new Error err

            callback()


    generate_conf_file_text: ->
      @conf_file_text = """
        # auto generated (and regenerated) by otto, don't edit
        # for channel #{@name}

        music_directory   "#{@music_dir}"
        db_file           "#{@db_file}"
        log_file          "#{@log_file}"
        pid_file          "#{@pid_file}"
        state_file        "#{@state_file}"
        bind_to_address   "#{@control_socket}"
        #port              "#{@control_port}"
        #bind_to_address   "localhost"
        #zeroconf_enabled  "no"
        #zeroconf_name     "Otto Music Player #{@name}"
        volume_normalization "yes"
        input {
          plugin "curl"
        }
        audio_output {
          type            "httpd"
          name            "Otto HTTP MP3 Stream #{@name}"
          encoder         "lame"
          #bind_to_address "#{@stream_sockets['mp3']}"
          port            "#{@stream_ports['mp3']}"
          bind_to_address "any"
          #quality         "5.0"     # do not define if bitrate is defined
          bitrate         "128"     # do not define if quality is defined
          format          "44100:16:1"
          #max_clients     "0"
        }
        audio_output {
          type            "httpd"
          name            "Otto HTTP OGG Stream #{@name}"
          encoder         "vorbis"
          #bind_to_address "#{@stream_sockets['ogg']}"
          port            "#{@stream_ports['ogg']}"
          bind_to_address "any"
          #quality         "5.0"     # do not define if bitrate is defined
          bitrate         "128"     # do not define if quality is defined
          format          "44100:16:1"
          #max_clients     "0"
        }
        audio_output {
          type            "httpd"
          name            "Otto HTTP WAV Stream #{@name}"
          encoder         "wave"
          #bind_to_address "#{@stream_sockets['wav']}"
          port            "#{@stream_ports['wav']}"
          bind_to_address "any"
          format          "44100:16:1"
          #max_clients     "0"
        }
        # having the null output seems to avoid a bug in mpd when no listeners are connected
        audio_output {
          type            "null"
          name            "Otto Null Output"
          mixer_type      "none"
        }

      """  #" #" fixes emacs coffee mode brain damage (caused by "'s or #'s in above block)
      #if @name is 'main'
      if process.platform is 'darwin'
        enabled = if @name is 'main' then 'yes' else 'no'
        @conf_file_text += """
          audio_output {
            type            "osx"
            name            "Otto Line Out"
            mixer_type      "software"
            enabled         "#{enabled}"
          }
        """  #"


    proxy_stream: (req, res, add_stream_callback=no, remove_stream_callback=no, format='mp3') ->
      #if typeof onempd is 'string'
      #  onempd = mpd_list[onempd]
      console.log 'MPD#proxy_stream format', format
      headers = assemble_headers(req.headers)
      outsocket = res.socket
      @playifnot =>  # this has to go first so the streams are created
        console.log 'playing...'
        open_callback = =>
          @streamcount++
          if add_stream_callback
            add_stream_callback(req, @, format)
        close_callback = =>
          #if --@streamcount is 0 and @autopause
          #  @pause =>
          #    console.log 'no listeners left, mpd paused'
          if remove_stream_callback
            remove_stream_callback(req, @, format)

        port = @stream_ports[format]
        host = 'localhost'
        otto.misc.wait_for_socket {port: port, host: host}, 200, (err) ->
          if err
            console.log "warning: we never saw the socket on #{host}:#{port} open up!"
            res.send('stream not found!', 503)
          else
            console.log 'about to proxy_raw_icy_stream'
            proxy_raw_icy_stream outsocket, headers, open_callback, close_callback, port, host


  ##### end of class MPD


  assemble_headers = (headers) ->
    CRLF = '\r\n';
    messageHeader = 'GET / HTTP/1.1' + CRLF
    store = (field, value) ->
      messageHeader += "#{field}: #{value}" + CRLF
    if headers
      keys = Object.keys(headers)
      isArray = (Array.isArray(headers))
      for key in keys
        if isArray
          field = headers[key][0]
          value = headers[key][1]
        else
          field = key
          value = headers[key]

        if Array.isArray(value)
          store(field, val) for val in value
        else
          store(field, value)
    return messageHeader + CRLF;


  # note: the ICY response codes break the node+connect http parsing code
  # so we just jam the sockets together and keep our nose out of it
  proxy_raw_icy_stream = (outsocket, headers, open_callback, close_callback, port=8101, host='localhost') ->
    console.log 'proxy_raw_icy_stream'
    insocket = net.connect port, host, ->
      console.log 'net connected'
      insocket.write headers
      console.log 'headers written'

      #insocket.addListener 'data', (data) ->
      #  console.log(data.length)

      open_callback()

      # close when the client disconnects or else we are just
      # going to buffer up the stream until we run out of memory!
      outsocket.on 'close', ->
        insocket.end()
        close_callback()

      # this is dirty. and ugly. we write directly to the socket and keep
      # http.js from writing out it's standard implicit headers
      # we rely on the headers being sent from mpd instead.
      # we just wanna give the client exactly what mpd sends

      # we also attempt to inject this one extra header to make jplayer think it can play faster
      # https://groups.google.com/forum/#!msg/jplayer/nSM2UmnSKKA/bC-l3k0pCPMJ
      #outsocket.write 'Accept-Ranges:bytes\r\n' # doesn't work, appears before the HTTP result code line, of course

      insocket.pipe(outsocket)


  ##### end of class otto.mpd.MPD


  return mpd







# this was my first attempt to proxy the mp3 stream
# hoo boy! this worked nice until mpd tried to respond
# with an ICY response code which broke the node http parser.
# it's a very nice way to proxy non-ICY web requests
#   proxy = http.createClient 8101, 'localhost'
#   proxy_request = proxy.request request.request.method, request.request.url, request.request.headers
#   proxy_request.addListener 'response', (proxy_response) ->
#     proxy_response.addListener 'data', (chunk) ->
#       request.response.write chunk, 'binary'
#     proxy_response.addListener 'end', ->
#       request.response.end()
#     request.response.writeHead proxy_response.statusCode, proxy_response.headers
#   request.request.addListener 'data', (chunk) ->
#     proxy_request.write chunk, 'binary'
#   request.request.addListener 'end', ->
#     proxy_request.end()


#stashing this more typical proxy code here just to keep it around
#nothing to do with mpd or streaming, was used to call our python api
#proxy_api_request = (request) ->
#  console.log 'proxy_api_request', request.request.url
#  proxy = http.createClient 8778, 'localhost'
#  proxy_request = proxy.request request.request.method, request.request.url, request.request.headers
#
#  #request.request.pipe(proxy_request)
#
#  proxy_request.addListener 'response', (proxy_response) ->
#    proxy_response.addListener 'data', (chunk) ->
#      request.response.write chunk, 'binary'
#    proxy_response.addListener 'end', ->
#      request.response.end()
#    request.response.writeHead proxy_response.statusCode, proxy_response.headers
#    #proxy_request.pipe(request.response)
#
#  request.request.addListener 'data', (chunk) ->
#    proxy_request.write chunk, 'binary'
#  request.request.addListener 'end', ->
#    proxy_request.end()
#
#  proxy_request.on 'error', ->
#    console.log 'proxy_request error!'



# i don't remember what this was, perhaps useful to reference when i want to fork mpd processes
#child = new (forever.Monitor)(forever.fork)
#fork = require 'fork'
#forever = require 'forever'
#if child
#  forever.startServer child
#  child.on 'exit', ->
#    console.log 'child exited'
#  child.start()
#  forever.list false, (err, data) ->
#    if err
#      console.log 'Error running `forever.list()`'
#      console.dir err
#    console.log 'Data returned from `forever.list()`'
#    console.dir data
#  return ''

