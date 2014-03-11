_ = require 'underscore'

require './otto.events'
otto = global.otto


global.otto.channels = do -> # note 'do' calls the function
  channels = {}

  channels.channel_list = {}
  root = null


  channels.Channel = class Channel extends otto.events.EventEmitter
    constructor: (@name, @info) ->
      # valid events:
      super ['*', 'time', 'update', 'state', 'finished', 'addtoqueue', 'killed', 'removed']
      if channels.channel_list[@name]
        throw new Error "channel name #{@name} already exists!"
      channels.channel_list[@name] = @
      @type = @info.type || 'standard'
      @queue = []
      switch @type
        when 'webcast', 'archive'
          @autofill = false
        else
          @autofill = true
          @autofill_min = 4
      @autofill_pending = false
      @mpd = null


    attach_mpd: ->
      @mpd = new otto.mpd.MPD(@name)
      if @name is 'main' and process.platform isnt 'darwin'
        @mpd.setautopause no

      # otto.mpd has async events, establish event handlers before calling connect()
      @mpd.on 'start', (eventname, mpd) =>
        # webcast and archive clear their queues and then load them. to prevent interrupting
        # webcasts and losing place on the archive during restarts we should check the queues
        # to see if they really need to be reloaded before we stomp all over them FIXME
        switch @type
          when 'webcast'
            if @info.urls?
              urls = @info.urls
            else
              urls = @info.url
            @mpd.play_url urls, =>
          when 'archive'
            @mpd.clear =>
              otto.db.get_album @info.archivename, (album) =>
                console.log 'filling archive queue'
                mpdfilenames = []
                if album and album.songs?
                  for song in album.songs
                    mpdfilenames.push channels.otto_filename_to_mpd(song.filename)
                console.log mpdfilenames
                if mpdfilenames
                  @mpd.play_archive mpdfilenames, =>

      @mpd.on '*', (eventname, mpd, args...) =>
        @mpd_event_handler eventname, mpd, args...

      @mpd.connect()
      #@mpd.refresh() # this shouldn't be needed, just debugging something


    mpd_event_handler: (eventname, mpd, args...) ->
      switch eventname
        when 'time'
          @time = args[0]
          @trigger 'time'

        when 'playlist'
          @playlist_changed args[0], =>
            @trigger 'update'

        when 'state'
          @state = args[0]
          @trigger 'state'
          if @type is 'webcast' and @state isnt 'play'
            otto.misc.timeoutSet 1000, =>
              mpd.playifnot ->


    refresh: ->
      @mpd.refresh()


    playlist_changed: (newplaylistinfo, callback=no) ->
      console.log "Channel#playlist_changed for #{@name}"
      filename_list = []
      for mpdsong in newplaylistinfo
        ottofilename = channels.mpd_filename_to_otto(mpdsong.file)
        filename_list.push(ottofilename)

      # correlate the mpd queue ids to the otto song list
      otto.db.load_songs_by_filenames filename_list, (ottosongs) =>
        for ottosong in ottosongs
          for mpdsong, n in newplaylistinfo
            if ottosong.filename is channels.mpd_filename_to_otto(mpdsong.file)
              ottosong.mpdqueueid = mpdsong.Id

        if newplaylistinfo.song and ottosongs and newplaylistinfo.song < ottosongs.length
          ottosongs[newplaylistinfo.song].nowplaying = true

        if @queue.length
          # transfer the (currently) ephemeral requestor values to the new song list
          for ottosong in ottosongs
            if ottosong.mpdqueueid
              for oldsong in @queue
                if oldsong.mpdqueueid and ottosong.mpdqueueid is oldsong.mpdqueueid
                  if oldsong.requestor?
                    ottosong.requestor = oldsong.requestor
                  break
          # see if the playing song has changed
          previously_playing = @queue[0]
          if previously_playing
            if ottosongs.length is 0 or previously_playing.mpdqueueid != ottosongs[0].mpdqueueid
              # check the killed flag to determine if it finished naturally
              if not previously_playing.killed
                @trigger 'finished', previously_playing

        # this is broken now
        #if requested_filename
        #  for song in ottosongs[1..ottosongs.length]
        #    if not song.requestor? and song.filename = requested_filename
        #      song.requestor = requestor
        #      break

        @queue = ottosongs
        callback()
        if @autofill
          @autofill_queue ->


    # adds random songs to the queue if it's below the autofill_min
    autofill_queue: (callback) ->
      if @type is 'webcast'
        console.log 'autofill ignored for webcast'
        callback()
        return
      if @autofill_min > @queue.length and not @autofill_pending
        @autofill_pending = true
        howmany = @autofill_min - @queue.length
        console.log 'howmany', howmany
        switch @type
          when 'standard'
            otto.db.get_random_songs 100, (randomsongs) =>
              console.log 'auto filling queue with random songs'
              # get a list of owners (people who have loaded music, or starred something)
              otto.db.load_owner_list (owners) =>
                ownerusernames = owners.map (owner) -> return owner.owner
                # we still need to lookup the stars to include them in the lucky listeners picks FIXME
                listeners = []
                if otto.ll?
                  for id in otto.ll
                    listener = otto.ll[id]
                    # filter out old stale listeners junk from the listener list
                    if listener.socketids.length > 0 or listener.streams
                      # each listener only get one slot, even if they have multiple connections
                      if listener.user not in listeners
                        # this prevents non owner users from making things more random,
                        # but maybe we want a little bit of that?
                        if listener.user in ownerusernames
                          listeners.push listener.user
                console.log 'listeners', listeners
                mpdfilenames = []
                luckylistener = undefined
                if listeners.length and (Math.floor Math.random() * 100) > 0
                  luckylistener = listeners[Math.floor Math.random() * listeners.length]
                  console.log 'luckylistener', luckylistener
                # 15% of the time the lucky listener is actually unlucky
                if luckylistener and Math.random() < 0.15
                  notlucky = ownerusernames.filter (username) -> username isnt luckylistener
                  luckylistener = notlucky[Math.floor Math.random() * notlucky.length]
                  console.log 'make that unlucky'
                  console.log 'new lucky owner', luckylistener
                if not luckylistener
                  # no listeners match owners/starred, randomly pick luckylistener
                  # a lucky owner from the owners list (this method should help balance out
                  # lopsided collections)
                  luckylistener = ownerusernames[Math.floor Math.random() * ownerusernames.length]
                  console.log 'luckowner', luckylistener
                if luckylistener
                  for randomsong in randomsongs
                    if randomsong.owners[0].owner is luckylistener
                      mpdfilenames.push channels.otto_filename_to_mpd(randomsong.filename)
                    if mpdfilenames.length >= howmany
                      break
                if mpdfilenames.length < howmany
                  console.log "not enough songs for #{luckylistener}, backfilling"
                  for randomsong in randomsongs
                    if channels.otto_filename_to_mpd(randomsong.filename) not in mpdfilenames
                      mpdfilenames.push channels.otto_filename_to_mpd(randomsong.filename)
                    if mpdfilenames.length >= howmany
                      break
                console.log mpdfilenames
                @mpd.addsongs mpdfilenames, =>
                  @autofill_pending = false
                  callback()
          when 'limited'
            otto.db.get_random_starred_songs howmany, 'jon', (newsongs) =>
              console.log 'auto filling queue with limited songs'
              mpdfilenames = []
              if newsongs
                for newsong in newsongs
                  mpdfilenames.push channels.otto_filename_to_mpd(newsong.filename)
                console.log mpdfilenames
                @mpd.addsongs mpdfilenames, =>
                  @autofill_pending = false
                  callback()
              else
                callback()
      else
        console.log 'queue has enough songs'
        callback()


    add_to_queue: (id, user) ->
      console.log 'Channel#add_to_queue', id
      otto.db.load_object id, no, (song) =>
        mpdfilename = channels.otto_filename_to_mpd(song.filename)
        if @queue and @queue.length
          for queuesong, pos in @queue[1..]  # skip the 'now playing' song
            if not queuesong.requestor? # skip past any requests
              break
          pos+=1  # because we skipped the first one, ya see
        else
          pos=0 # queue is empty, insert song at the beginning
        @mpd.addid mpdfilename, pos, (mpdresponse) =>
          console.log 'mpdresponse', mpdresponse
          console.log 'queue', @queue
          @mpd.playlist_watchdog =>  # the callback supresses the 'playlist' event
            @playlist_changed @mpd.cache.playlistinfo, =>
              if @queue.length
                # set the requestor of the new song
                found = false
                for queuesong in @queue
                  if queuesong.mpdqueueid is mpdresponse[0].Id
                    queuesong.requestor = user
                    found = true
                if not found
                  console.log 'error: unable to mark the requestor in the queue'
              @trigger 'update'
              @trigger 'addtoqueue', song, user


    remove_from_queue: (id, user) ->
    # this appears to be messed up re: return values and async callbacks
      if @queue
        first = true
        for song in @queue
          if Number(song.mpdqueueid) == Number(id)
            song.killed = true
            @mpd.deleteid id, =>
              if first
                @trigger 'killed', song, user
              else
                @trigger 'removed', song, user
              #@mpd.playlistinfo() # perhaps mpd.deleteid should trigger this (now it does)
              return true
            break
          first = false


    clear_queue: (id, user, callback) ->
      if @queue
        @mpd.clear callback


    proxy_stream: (args...) ->
      @mpd.proxy_stream args...


    pause: (callback) ->
      @mpd.pause callback
    # next is not currently used
    next: (callback) ->
      @mpd.next callback

    # new calls added to support 'featured' channels
    seek: (seconds, callback) ->
      @mpd.seekcur seconds, callback
    play: (position, callback) ->
      @mpd.play position, callback

    #output state and manipulation
    outputs: (callback) ->
      @mpd.outputs callback
    lineout: (enable, callback) ->
      @mpd.outputs (r) =>
        for output in r
          if output.outputname is 'Otto Line Out'
            if enable
              @mpd.enableoutput output.outputid, ->
            else
              @mpd.disableoutput output.outputid, ->
            break

    #server side vol for line out (doesn't affect the streams thankfully)
    setvol: (vol, callback) ->
      @mpd.setvol vol, callback


  channels.set_global_event_handler = (handler) ->
    console.log 'set_global_event_handler'
    channels.global_events_handler = handler
    for own channelname, channel of otto.channels.channel_list
      channel.on '*', handler


  channels.init = (callback) ->
    # figure out where the music directory lives so we know how to convert
    # between otto's absolute filenames and mpd's relative file names
    # maybe we should compute this from the database?
    for testroot in otto.MUSICROOT_SEARCHLIST
      testroot.dir = otto.misc.expand_tilde testroot.dir
      if otto.misc.is_dirSync(testroot.dir)
        root = testroot
        break
    if not root
      console.log 'error: could not find the music root directory. exiting.'
      process.exit(1)
    console.log 'using ' + root.dir + ' as the music root directory.'

    for channelinfo in otto.channelinfolist
      console.log "creating channel #{channelinfo.name}"
      channel = new otto.channels.Channel(channelinfo.name, channelinfo)
      if channels.global_event_handler
        channel.on '*', global_event_handler
      channel.attach_mpd()

    callback()


  #channels.mpd_filename_to_otto = (filename) ->
  #  if filename?
  #    return root.dir+'/' + filename.replace('^'+root.strip+'/', '')

  #channels.otto_filename_to_mpd = (filename) ->
  #  # files with " in them don't work, mpd can't handle 'em
  #  return filename.replace(root.dir+'/', '').replace('"', '\\"')

  channels.mpd_filename_to_otto = (filename) ->
    return filename

  channels.otto_filename_to_mpd = (filename) ->
    # files with " in them don't work, mpd can't handle 'em
    return 'file://'+filename.replace('"', '\\"')

  channels.otto_filename_to_relative = (filename) ->
    return filename.replace(root.dir+'/', '')


  return channels




# saving this post_with_body snippet
#filename_params = querystring.stringify(filename: filename_list)
#jsonreq.post_with_body 'http://localhost:8778/load_songs', filename_params, (err, ottosongs) =>
