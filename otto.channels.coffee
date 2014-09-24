require './otto.events'
otto = global.otto


global.otto.channels = do -> # note 'do' calls the function
  channels = {}

  channels.channel_list = {}
  root = null


  channels.Channel = class Channel extends otto.events.EventEmitter
    constructor: (@name, @info) ->
      # valid events:
      super ['*', 'time', 'queue', 'state', 'status', 'lineout', 'outputs', 'started', 'finished', 'addtoqueue', 'killed', 'removed']
      if channels.channel_list[@name]
        throw new Error "channel name #{@name} already exists!"
      channels.channel_list[@name] = @
      @type = @info.type || 'standard'
      @queue = []
      @outputs = []
      @lineout = 0
      switch @type
        when 'webcast', 'archive'
          @autofill = false
        else
          @autofill = true
          @autofill_min = 4
      @autofill_pending = false
      @mpd = null


    attach_mpd: (callback) ->
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

      @mpd.connect callback
      #@mpd.refresh() # this shouldn't be needed, just debugging something


    mpd_event_handler: (eventname, mpd, args...) ->
      switch eventname
        when 'time'
          @time = args[0]
          @trigger 'time'

        when 'playlist'
          @playlist_changed args[0], =>
            @trigger 'queue'

        when 'state'
          @state = args[0]
          @trigger 'state'
          if @type is 'webcast' and @state isnt 'play'
            otto.misc.timeoutSet 1000, =>
              mpd.playifnot ->

        when 'status'
          @status = args[0]
          @trigger 'status'

        when 'outputs'
          @outputs = args[0]
          for output in @outputs
            if output.outputname is 'Otto Line Out'
              if @lineout != output.outputenabled
                @lineout = output.outputenabled
                alllineout = {}
                for name,channel of channels.channel_list
                  alllineout[name] = channel.lineout
                @trigger 'lineout', alllineout
              break
          alloutputs = {}
          for name,channel of channels.channel_list
            alloutputs[name] = channel.outputs
          @trigger 'outputs', alloutputs

        when 'died'
          @autofill_pending = false
          @mpdids_invalid = true


    refresh: ->
      @mpd.refresh()


    playlist_changed: (newplaylist, callback=no) ->
      console.log "Channel#playlist_changed for #{@name}"
      filename_list = []
      for mpdsong in newplaylist
        ottofilename = channels.mpd_filename_to_otto(mpdsong.file)
        filename_list.push(ottofilename)

      # correlate the mpd queue ids to the otto song list
      otto.db.load_songs_by_filenames filename_list, (ottosongs) =>
        for ottosong in ottosongs
          for mpdsong in newplaylist
            if ottosong.filename is channels.mpd_filename_to_otto(mpdsong.file)  # not sure this works with "s
              ottosong.mpdqueueid = mpdsong.Id

        if @queue.length
          # transfer the (currently) ephemeral requestor values to the new song list
          if not @mpdids_invalid
            for ottosong in ottosongs
              if ottosong.mpdqueueid
                for oldsong in @queue
                  if oldsong.mpdqueueid and ottosong.mpdqueueid is oldsong.mpdqueueid
                    if oldsong.requestor?
                      ottosong.requestor = oldsong.requestor
                    break
          else
            # old ids invalid, match by filename instead of mpdids
            for ottosong in ottosongs
              for oldsong in @queue
                if ottosong.filename is oldsong.filename
                  if oldsong.requestor?
                      ottosong.requestor = oldsong.requestor
                    break
            @mpdids_invalid = false

          # see if the playing song has changed
          previously_playing = @queue[0]
          if previously_playing
            if ottosongs.length is 0 or previously_playing.mpdqueueid != ottosongs[0].mpdqueueid
              # check the killed flag to determine if it finished naturally
              if not previously_playing.killed
                @trigger 'finished', previously_playing

        if newplaylist.songpos and ottosongs and newplaylist.songpos < ottosongs.length
          ottosongs[newplaylist.songpos].nowplaying = true
          previously_playing = false
          for oldsong in @queue
            if oldsong.nowplaying
              previously_playing = oldsong
          if not previously_playing or not previously_playing._id.equals( ottosongs[newplaylist.songpos]._id )
            @trigger 'started', ottosongs[newplaylist.songpos]
            # that might not work with featured playlists
            # but probably neither does the @queue[0] bit about a dozen lines above

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
      console.log 'autofill_queue'
      if otto.db.emptydatabase
        console.log 'empty database, skipping autofill_queue'
        callback()
        return
      if @type is 'webcast'
        console.log 'autofill ignored for webcast'
        callback()
        return
      if @autofill_min > @queue.length and not @autofill_pending
        howmany = @autofill_min - @queue.length
        console.log 'howmany', howmany
        @autofill_pending = true
        console.log 'autofill_pending', @autofill_pending
        switch @type
          when 'standard'
            otto.db.get_random_songs 300, (randomsongs) =>  # was 100
              console.log 'auto filling queue with random songs'
              vettedsongs = []
              for song in randomsongs
                genre = false
                if song.genre?
                  genre = song.genre.toLowerCase()
                if genre
                  if /book/.test(genre) then continue
                  if /audio/.test(genre) then continue
                  if /speech/.test(genre) then continue
                  if /spoken/.test(genre) then continue
                  if /podcast/.test(genre) then continue
                  if /academic/.test(genre) then continue
                  #if /comedy/.test(genre) then continue  # also '57'
                  if genre in ['183', '184', '186', '101'] then continue
                vettedsongs.push song
              channels.pick_a_lucky_listener (luckylistener) =>
                mpdfilenames = []
                if luckylistener
                  for randomsong in vettedsongs
                    if randomsong.owners[0].owner is luckylistener
                      mpdfilenames.push channels.otto_filename_to_mpd(randomsong.filename)
                    if mpdfilenames.length >= howmany
                      break
                if mpdfilenames.length < howmany
                  console.log "not enough songs for #{luckylistener}, backfilling"
                  for randomsong in vettedsongs
                    if channels.otto_filename_to_mpd(randomsong.filename) not in mpdfilenames
                      mpdfilenames.push channels.otto_filename_to_mpd(randomsong.filename)
                    if mpdfilenames.length >= howmany
                      break
                console.log mpdfilenames
                console.log 'before addsongs'
                @mpd.addsongs mpdfilenames, =>
                  console.log 'after addsongs'
                  @autofill_pending = false
                  console.log 'autofill_pending', @autofill_pending
                  callback()
          when 'limited'
            otto.db.get_random_starred_songs howmany, 'jon', (newsongs) =>
              console.log 'auto filling queue with limited songs'
              mpdfilenames = []
              if newsongs
                for newsong in newsongs
                  mpdfilenames.push channels.otto_filename_to_mpd(newsong.filename)
                #console.log mpdfilenames
                @mpd.addsongs mpdfilenames, =>
                  @autofill_pending = false
                  callback()
              else
                callback()
      else
        console.log 'queue has enough songs, autofillpending =', @autofill_pending
        callback()


    add_to_queue: (id, user, callback) ->
      console.log 'Channel#add_to_queue', id
      if !id
        if callback then callback() else return
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
          #console.log 'mpdresponse', mpdresponse
          #console.log 'queue', @queue
          @mpd.playlist (playlist) =>
            @playlist_changed playlist, =>
              if @queue.length
                # set the requestor of the new song
                found = false
                for queuesong in @queue
                  if queuesong.mpdqueueid is mpdresponse[0].Id
                    queuesong.requestor = user
                    found = true
                if not found
                  console.log 'error: unable to mark the requestor in the queue'
              @trigger 'queue'
              @trigger 'addtoqueue', song, user
              if callback
                callback()


    remove_from_queue: (id, user) ->
    # this appears to be messed up re: return values and async callbacks
      if @queue
        first = true
        if id is '' and @queue[0]
          id = @queue[0].mpdqueueid
        for song in @queue
          if Number(song.mpdqueueid) == Number(id)
            song.killed = true
            @mpd.deleteid id, =>
              if first
                @trigger 'killed', song, user
              else
                @trigger 'removed', song, user
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

    pauseifnot: (callback) ->
      if @state is 'play'
        @mpd.pause callback
      else
        callback()

    # next is not currently used
    next: (callback) ->
      @mpd.next callback

    # new calls added to support 'featured' channels
    seek: (seconds, callback) ->
      @mpd.seekcur seconds, callback
    play: (position, callback) ->
      @mpd.play position, callback

    toggleplay: (callback) ->
      if @state is 'play'
        @mpd.pause callback
      else
        @mpd.play undefined, callback

    #output state and manipulation
    get_outputs: (callback) ->
      @mpd.outputs callback
    #lineout is just a specific input
    set_lineout: (enable, callback) ->
      @mpd.outputs (r) =>
        for output in r
          if output.outputname is 'Otto Line Out'
            if enable
              @mpd.enableoutput output.outputid, ->
            else
              @mpd.disableoutput output.outputid, ->
            break
    toggle_lineout: (enable, callback) ->
      @mpd.outputs (r) =>
        for output in r
          if output.outputname is 'Otto Line Out'
            if @lineout == '1'
              @mpd.disableoutput output.outputid, ->
            else
              @mpd.enableoutput output.outputid, ->
            break

    #server side vol for line out (doesn't affect the streams thankfully)
    setvol: (vol, callback) ->
      @mpd.setvol Math.max( Math.min(vol, 100), 0), callback


  channels.pick_a_lucky_listener = (callback) ->
    # get a list of owners (people who have loaded music, or starred something)
    otto.db.load_owner_list (owners) =>
      ownerusernames = owners.map (owner) -> return owner.owner
      # we still need to lookup the stars to include them in the lucky listeners picks FIXME
      listeners = []
      if otto.ourlisteners
        list = otto.ourlisteners.get_list()
        for id in list
          listener = list[id]
          # filter out old stale listeners junk from the listener list
          if listener.socketids or listener.streams
            # each listener only get one slot, even if they have multiple connections
            if listener.user not in listeners
              # this prevents non owner users from making things more random,
              # but maybe we want a little bit of that?
              if listener.user in ownerusernames
                listeners.push listener.user
      console.log 'eligible listeners', listeners
      luckylistener = undefined
      if listeners.length
        luckylistener = listeners[Math.floor Math.random() * listeners.length]
        # 15% of the time the lucky listener is actually unlucky
        if luckylistener and Math.random() > 0.15
          console.log 'lucky listener', luckylistener
        else
          console.log 'unluckly listener', luckylistener
          notlucky = ownerusernames.filter (username) -> username isnt luckylistener
          luckylistener = notlucky[Math.floor Math.random() * notlucky.length]
          console.log 'lucky owner', luckylistener
      if not luckylistener
        # no listeners match owners/starred, randomly pick luckylistener
        # a lucky owner from the owners list (this method should help balance out
        # lopsided collections)
        luckylistener = ownerusernames[Math.floor Math.random() * ownerusernames.length]
        console.log 'lucky owner', luckylistener
      callback luckylistener


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
    #if not root
    #  console.log 'error: could not find the music root directory. exiting.'
    #  process.exit(1)
    console.log 'using ' + root.dir + ' as the music root directory.'

    callcount = otto.channelinfolist.length
    for channelinfo in otto.channelinfolist
      console.log "creating channel #{channelinfo.name}"
      channel = new otto.channels.Channel(channelinfo.name, channelinfo)
      if channels.global_event_handler
        channel.on '*', global_event_handler
      channel.attach_mpd ->
        if callcount-- == 1 and callback
          callback()
      #channel.refresh()  # this didn't do what i expected


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
