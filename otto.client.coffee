###############
### client side (otto.client served by zappa as /otto.client.js)
###############

global.otto.client = ->

  window.otto = window.otto || {}

  otto.socketconnected = false
  otto.greeted = false
  otto.clientstate = {}
  otto.myusername = no
  otto.mychannelname = no
  otto.current_track_qid = no
  otto.channel_list = []
  otto.current_channel = no
  otto.play_state = 'unknown'
  otto.connect_state = 'disconnected'
  otto.chat_state = no
  otto.ignore_reload = false
  otto.cache = { queue: [], list: [], stars: [] }
  otto.current_volume = 80
  otto.soundfx = no
  otto.notifications = no


  #disable shy controls on touch devices
  #touch_device = 'ontouchstart' in document.documentElement
  #touch_device = ('ontouchstart' in window) or window.DocumentTouch and document instanceof DocumentTouch
  #touch_device = 'ontouchstart' in window or 'onmsgesturechange' in window # 2nd test for ie10

  #touch_device = true  #detection not working for some reason wtf? FIXME
  $('head').append '<script src="static/js/modernizr.custom.66957.js">'
  touch_device = Modernizr.touch  # prob doesn't work for ie10
  #http://stackoverflow.com/questions/4817029/whats-the-best-way-to-detect-a-touch-screen-device-using-javascript
  if touch_device
    console.log 'touch device detected, disabling shy controls'
    $('body').addClass 'noshy'
    $('head').append '<script src="static/js/fastclick.js">'
    FastClick.attach(document.body)


  @on 'error': ->
    console.log 'socket.io connection error'
    #alert 'reloading'
    window.location.reload()


  @on 'connect': ->
    console.log 'socket.io connected'
    otto.socketconnected = true
    $('body').removeClass 'disconnected'
    otto.sayhello()


  @on 'disconnect': ->
    console.log 'socket.io disconnection'
    $('body').addClass 'disconnected'
    otto.socketconnected = false
    otto.saygoodbye()


  # note: doesn't work when moved under $ or nextTick!
  # it appears you have to call @connect inside zappa.run's initial call
  # or else the context.socket isn't created inside zappa.run() in
  # time for it to be used internally. i think this also means it's going
  # to be very difficut it rig things so we can call @connect again to connect
  # to a different server. -jon
  # first arg is the url to connect to, undefined connects to where we were served from
  @connect undefined, 'reconnection limit': 5000, 'max reconnection attempts': Infinity


  # use nextTick so the function, and the function it calls, are all defined
  nextTick ->
    otto.start_client()

  otto.start_client = =>
    console.log 'start_client()'

    #otto.call_module 'webkit', 'init'

    otto.showdown_converter = new Showdown.converter()

    $(window).on 'scrollstop', otto.results_lazyload_handler
    #$(window).on 'resize', otto.results_lazyload_handler
    $(window).smartresize otto.results_lazyload_handler
    #$(window).on 'resize', otto.adjust_autosize
    $(window).smartresize otto.adjust_autosize  # can this take a second function?
    $(window).on 'focus blur', otto.window_focus_handler
    otto.ouroboros_init()
    otto.window_idle_handler_init()

    $(document.body).html otto.templates.body large_database: otto.large_database
    $('body').on 'click', otto.button_click_handler
    $('body').on 'click', otto.letterbar_click_handler
    $('body').on 'change', otto.checkbox_click_handler
    $('body').on 'submit', otto.form_submit_handler
    $('#channellist').on 'click', otto.channellist_click_handler

    $(window).on 'unload', ->
      otto.lastnotification.close() if otto.lastnotification
    $(window).on 'beforeunload', ->
      otto.lastnotification.close() if otto.lastnotification
    # hmmm, was hoping beforeunload would help with refresh, but alas

    if /^#/.test location.hash
      params = location.hash.slice(1).split('&')
      $.each params, ->
        if @ != ''
          kv = @.split '='
          k = kv[0]
          v = kv[1]
          switch k
            when 'connect' then if v == '1' then otto.connect_player()
            when 'chat' then if v == '1' then $('.chattoggle').click()
            when 'ignorereload' then if v = '1' then otto.ignore_reload = true

    otto.sayhello()


  otto.sayhello = =>
    if otto.socketconnected and not otto.greeted
      otto.greeted = true
      console.log 'well, hello server!'
      @emit 'hello'  # causes the server to welcome us with all kinds of state data


  otto.saygoodbye = =>
    console.log 'ok lady, goodbye!'
    otto.greeted = false
    otto.mychannelname = false


  @on 'welcome': ->
    console.log 'welcome data', @data
    otto.process_myusername @data.myusername
    otto.process_channellist @data.channellist
    otto.process_lists @data.lists
    if @data.stars
      otto.process_stars @data.stars


  otto.create_mainpage = ->
    #$(document).attr 'title', otto.current_channel.fullname + ' ▪ ' + otto.myurl + ' ▪ otto' #FIXME
 #!#   $(document).attr 'title', otto.current_channel.fullname + ' ▪ otto' #FIXME
    $('#mainpage').html otto.templates.mainpage channel: otto.current_channel

    $('#playlist').on 'click', otto.results_click_handler
    $('#results').on 'click', otto.results_click_handler
    $('#console').on 'click', otto.console_click_handler
    $('#volumebar').slider value: otto.current_volume, range: 'min', slide: otto.adjust_volume_handler
    $('#volumebar-lineout').slider value: otto.current_volume, range: 'min', slide: otto.adjust_volume_lineout_handler
    $('.scrollkiller').on 'mousewheel', otto.scroll_bubble_stop_handler
    $('#console').resizable handles: 's', alsoResize: $('#output'), minHeight: 45, autoHide: true
    $('.playlist-container').resizable handles: 's', alsoResize: $('#ondeck'), minHeight: 146, autoHide: true
    otto.chat_init()


  @on 'playlistinfo': ->
    active = $('.nowplayingcover').is '.active'
    if @data.length
      n = 0
      console.log @data
      for song, i in @data
        if song.nowplaying
          n = i
          break
      otto.current_track_qid = @data[n].mpdqueueid
      $('.nowplayingcover-container').html otto.templates.nowplaying_cover song: @data[n]
      $('#currenttrack-container').html otto.templates.nowplaying_currenttrack song: @data[n]
      $('#currenttrack-errata').html otto.templates.nowplaying_errata song: @data[n]
      if otto.current_channel.layout is 'featured'
        $('#ondeck').html otto.templates.nowplaying_featured songs: @data[0..@data.length]
      else
        $('#ondeck').html otto.templates.nowplaying_ondeck songs: @data[1..@data.length]
      otto.adjust_autosize() # problem with getting the playlistinfo event before page is built on the client side?
      if otto.notifications
        song = @data[n]
        if song._id isnt otto.lastnotificationid
          otto.lastnotificationid = song._id
          album = song.album || ''
          #album += ' • ' + song.year if song.year
          album += '    ' + song.year if song.year
          artist = song.artist || ''
          body = "#{album}\n#{artist}"
          body += "\n#{song.owners[0].owner}" if song.owners?[0].owner?
          otto.lastnotification.close() if otto.lastnotification
          otto.lastnotification = new Notification song.song, body: body, icon: "/image/120?id=#{song.cover}"
          #n.onshow = ->
          #  timeoutSet 10000, -> n.close()
    else
      $('.nowplayingcover-container').empty()
      $('#currenttrack-container').empty()
      $('#currenttrack-errata').empty()
    otto.cache.queue = @data
    if active
      $('.nowplayingcover').removeClass('active')
      $('.nowplayingcover').click()

    otto.mark_allthethings()


  @on 'state': ->
    otto.play_state = @data
    if @data is 'play'
      $play = $('#play')
      $play.html otto.templates.icon 'pause'
      $play.addClass 'shy'
    else
      $play = $('#play')
      $play.html otto.templates.icon 'play'
      $play.removeClass 'shy'


  @on 'time': ->
    if @data
      parts = @data.split(':')
      [current, total] = parts[0..1]
      otto.current_song_total = total
      percent = (current / total * 100)
      width = 90 * ( total / 2397 )
      # 2397 = 39:57, length of the longest single to ever reach the UK charts!
      width = 75 if width > 75
      width = 5 if width < 5

      $('#progress-container').each (index, element) ->  # why each?
        $progress_container = $ element
        space = $(window).width() - $progress_container.offset().left
        widthpx = width / 100 * space
        $('#progress').css 'width', "#{widthpx}px"
        $('#progress-bar').css 'width', "#{percent}%"
        totalstr = otto.format_time total
        currentstr = otto.format_time current, totalstr.length
        $('#total-time').text totalstr
        $('#current-time').text currentstr
        $('#progress-container').css 'visibility', 'visible'


  @on 'loader': ->
    if @data.stdout
      amountscrolledup =  $('#output').prop('scrollHeight') - $('#output').height() - $('#output').scrollTop()
      $('#output').append otto.templates.loader event: @data.stdout
      if amountscrolledup < 80
        $('#output').scrollToBottom()
    else if @data.count and @data.total
      $('#loader_progress').text "#{@data.count} / #{@data.total}"
    else if @data.album
      $('#loader_current').text "#{@data.album} ▪ #{@data.fileunder[0].name}"
      console.log @data
      if otto.place_one_cube
        html = otto.place_one_cube(@data.fileunder[0].key, @data.fileunder[0].name, @data.album)
        $('.scene').append html
        maxheight = otto.otto.cubes.maxheight
        # position the cubes so the top fits on the landscape
        $('#cubes').css('top', (-maxheight + 20) + "px")
        # adjust the landscape grid to cover everything
        $('#landscape').height(-maxheight + 300)


  @on 'myusername': ->
    otto.process_myusername @data

  otto.process_myusername = (username) ->
    otto.myusername = username
    if username
      $('#login').replaceWith otto.templates.browsebar()
    else
      $('#browsebar').replaceWith otto.templates.login()
      $('#results').empty()


  @on 'loggedout': ->
    console.log 'loggedout'
    otto.process_myusername null


  @on 'myurl': ->
    otto.myurl = @data.name
    $('#channelname').text @data.fullname


  @on 'changechannel': ->
    console.log 'changing channel to', @data.name
    otto.mychannelname = @data.name
    html = otto.templates.channellist channellist: otto.channel_list
    $('#channellist').html( html ).mmenu(  { slidingSubmenus: false } )
    otto.current_channel = false
    for channel in otto.channel_list
      if channel.name is otto.mychannelname
        otto.current_channel = channel
    if not otto.current_channel then otto.current_channel = otto.channel_list[0]
    otto.create_mainpage()
    if otto.connect_state isnt 'disconnected'
      otto.connect_player()
    @emit 'updateme'


  @on 'reload': ->
    if otto.ignore_reload
      console.log 'ignoring reload event'
      return
    if otto.connect_state isnt 'disconnected'
      window.location.hash = '#connect=1'
    else
      window.location.hash = '' # hash still appears, rumour is you can't get rid of it
    if otto.chat_state
      if window.location.hash isnt ''
        window.location.hash += '&chat=1'
      else
        window.location.hash += '#chat=1'
    window.location.reload()


  @on 'chat': ->
    console.log @data.name
    otto.play_soundfx @data.name
    otto.play_notification @data
    $output = $('#output')
    amountscrolledup = $output.prop('scrollHeight') - $output.height() - $output.scrollTop()
    $output.append otto.templates.event event: @data
    if amountscrolledup < 80
      $output.scrollToBottom()


  @on 'lists': ->
    if @data
      otto.process_lists @data

  otto.process_lists = (lists) ->
    if lists
      for user in lists
        if user == otto.myusername
          otto.cache.list = user.list
          otto.mark_listed_items()
          $('#results').trigger('scrollstop')


  @on 'stars': ->
    console.log 'on stars', @data
    if @data
      otto.process_stars

  otto.process_stars = (stars) ->
    for own username of stars
      console.log 'username', username
      console.log 'myusername', otto.myusername
      if username == otto.myusername
        console.log 'matched'
        otto.cache.stars = stars[username]
        otto.mark_starred_items()
        $('#results').trigger('scrollstop')


  @on 'reloadmodule': ->
    modulename = @data.match(/otto[.]client[.](.*)[.]coffee/)[1]
    console.log 'reloading module ' + modulename
    if modulename is 'templates'  # templates module exception
      delete otto.templates
      $('head').append '<script src="/otto.client.templates.js">'
    else
      if modulename of otto.client
        delete otto.client[modulename]
        otto.load_module modulename
    @emit 'updateme'


  @on 'restyle': ->
    sheetname = @data.sheetname
    console.log "restyle time! (#{sheetname})"
    original_sheet = undefined
    for sheet in document.styleSheets
      continue if sheet.disabled
      try
        if (sheet.ownerNode?.dataset?.href?.indexOf '/'+sheetname) > -1  # is this Chrome specific?
          console.log 'disabling old style sheet'
          sheet.disabled = true
        else if sheet.data is sheetname
          console.log 'disabling old reloaded style sheet'
          sheet.disabled = true
      catch err
        console.log 'failed to disable style sheet'
    #$new_sheet = $('<style id="#'+@data.sheetname+'css">').html @data.css
    $new_sheet = $('<style>').html @data.css
    #$new_sheet[0].data = sheetname
    $('head').append $new_sheet
    document.styleSheets[document.styleSheets.length-1].data = sheetname


  @on 'listeners': ->
    socketid = @socket?.socket?.sessionid
    otto.ll = @data
    $('#listeners').html otto.templates.listeners(listeners: @data, socketid: socketid)


  @on 'channellist': ->
    otto.process_channellist @data

  otto.process_channellist = (channellist) =>
    otto.channel_list = channellist
    html = otto.templates.channellist channellist: otto.channel_list
    $('#channellist').html( html ).mmenu(  { slidingSubmenus: false } )
    if not otto.mychannelname
      channelname = 'main'
      @emit 'changechannel', channelname


  ##########
  ########## handlers
  ##########

  otto.checkbox_click_handler = (e) =>
    $checkbox = $(e.target)
    if not $checkbox.is 'input[type="checkbox"]'
      return
    e.stopPropagation();
    if $checkbox.is '#fxtoggle'
      otto.soundfx = $checkbox.is ':checked'
      if otto.soundfx
        otto.play_soundfx 'fxenabled'

    if $checkbox.is '#notificationstoggle'
      if $checkbox.is ':checked'
        if Notification?
          Notification.requestPermission (status) ->
            console.log 'notifications permission', status  # looking for "granted"
            if status isnt "granted"
              otto.notifications = false
              $checkbox.attr 'checked', false
            else
              otto.notifications = true
              n = new Notification "Notifications Enabled", {body: ""} # this also shows the notification
              n.onshow = ->
                timeoutSet 4000, -> n.close()


    if $checkbox.is '#lineouttoggle'
      otto.lineout = $checkbox.is ':checked'
      if otto.lineout
        $('#volumebar-lineout').show()
      else
        $('#volumebar-lineout').hide()
      for channel in otto.channel_list
        if channel.name is otto.mychannelname
          @emit 'lineout', otto.lineout
          break


  otto.button_click_handler = (e) =>
    $button = $(e.target)
    if not $button.is 'button'
      $button = $(e.target).parents('button').first()
      if not $button.is 'button'
        #console.log 'this did not look like a button to me'
        #console.log $button
        return
    e.stopPropagation();

    id = $button.data('oid') || $button.attr('id')
    id = id || $button.parent().data('oid') || $button.parent().attr('id')
    id = id || $button.parent().parent().data('oid')
    id = id || $button.parent().parent().attr('id')

    if $button.is '.enqueue'
      console.log('enqueue ' + id)
      @emit 'enqueue', id

    else if $button.is '.stars'
      console.log '.stars', e
      console.log $button
      clickpoint = e.pageX - $button.offset().left - 4
      console.log clickpoint
      if clickpoint < 2
        halfstars = 0
      else if clickpoint < 11
        halfstars = 1
      else if clickpoint < 19
        halfstars = 2
      else if clickpoint < 26
        halfstars = 3
      else if clickpoint < 35
        halfstars = 4
      else if clickpoint < 42
        halfstars = 5
      else
        halfstars = 6
      console.log halfstars
      console.log "stars #{halfstars} " + id
      $button.removeClass('n0 n1 n2 n3 n4 n5 n6').addClass('n' + halfstars)
      @emit 'stars', id: id, rank: halfstars

    else if $button.is '#connect'
      console.log otto.connect_state
      if otto.connect_state is 'disconnected'
        otto.connect_player()
      else
        otto.disconnect_player()

    else if $button.is '#play'
      if otto.play_state is 'play'
        @emit 'pause'
      else
        @emit 'play'

    else if $button.is '#next'
      qid = otto.current_track_qid
      console.log 'deleteid', qid
      @emit 'deleteid', qid
      if otto.connect_state isnt 'disconnected'
        otto.reconnect_player() # make it stop playing instantly (flush buffer)

    else if $button.is '.remove'
      console.log 'deleteid', id
      @emit 'deleteid', id

    else if $button.is '.close'
      container_top = $button.parent().parent().parent().offset().top
      $button.parent().remove()
      if $('#results').parent().scrollTop() > container_top
        $('#results').parent().scrollTop(container_top)

    else if $button.is '.runself'
      run = $button.data('run')
      run()

    else if $button.is '.download'
      oid = $button.data('oid')
      $iframe = $("<iframe class='download' id='#{oid}' style='display:none'>")
      $(document.body).append $iframe
      $iframe.attr 'src', "/download/#{oid}"
      $iframe.load ->
        console.log "iframe #{oid} loaded"
        #$iframe.remove() # this seems to cut off the download FIXME

    else if $button.is '.chattoggle'
      $('#console').toggle()
      if $('#console').is(':visible')
        $('#console').focus()
        @emit 'inchat', 1
        otto.chat_state = yes
      else
        $('#channelbar').focus()
        @emit 'inchat', 0
        otto.chat_state = no

    else if $button.is '.channeltoggle'
      $channellist = $('#channellist')
      if $channellist.is '.mmenu-opened'
        $channellist.trigger('close')
      else
        $channellist.trigger('open')
        $button.trigger 'mousemove'
        # webkit bug leaves the div hovered when moved from under cursor
        #$('.channelbar').trigger 'mouseleave' # doesn't work

    else if $button.is '.logout'
      @emit 'logout'
      #$.getJSON '/logout'

    else if $button.is '.play'
      @emit 'play', $button.data('position')

    else
      console.log 'did not know what action to do with button'
      console.log $button
      return

    e.cancelBubble = true
    if e.stopPropagation
      e.stopPropagation()


  otto.results_click_handler = (e) =>
    $target = $(e.target)

    if $target.is '.expand'
      $expand = $target
    else if $target.parent().is '.expand'
      $expand = $target.parent()

    if $target.is '.gotothere'
      $gotothere = $target
    else if $target.parent().is '.gotothere'
      $gotothere = $target.parent()
    else if $target.parent().parent().is '.gotothere'
      $gotothere = $target.parent().parent()

    if $expand
      oid = $expand.attr('data-oid')
      container = $expand.attr('data-container')
      console.log 'container', container
      console.log 'oid', oid
      if not container
        container = oid
      $element = $("##{container}")
      console.log '$element', $element

      $child = $element.children().filter(":first")
      if $child and $child.data('oid') == oid # parseInt(oid) <- not anymore!
        # same item, toggle it closed instead of redisplaying it
        $element.empty().hide()
        $expand.removeClass('active')
      else
        #$expand.parent().find('.active').removeClass 'active'
        $.getJSON '/album_details', {'oid': oid}, (data) ->
          if data.albums
            data=data.albums
          $.getJSON '/load_object', {'oid': container}, (fileunder) ->
            if $element.length is 0
              $element = $ "<div id='#{container}' class='expander cf'>"
              $eol = false
              $last = $expand.parent()
              while not $eol
                $next = $last.next()
                console.log 'next', $next
                if $next.length is 0
                  $eol = $last
                else if $next.offset().top > $last.offset().top
                  $eol = $last
                else
                  $last = $next
              console.log '$eol', $eol
              $eol.after $element
            $('.expander').hide();
            $('.active').removeClass 'active'
            $expand.addClass('active')
            $element.show()
            $element.html otto.templates.albums_details data: [].concat(data), fileunder: fileunder, oid: oid
            otto.mark_allthethings()

    else if $gotothere
      oid = $gotothere.data('oid')
      if $gotothere.is '.active'
        $('#results').empty()
        $gotothere.removeClass('active')
        console.log 'removing active'
      else
        $('.active').removeClass('active')
        $gotothere.addClass('active')
        console.log 'adding active'
        if not $('#results').children().first().is '.albumdetailscontainer'
          $('#results').empty()
        $.getJSON '/load_object', {oid: oid, load_parents: 20}, (object) ->
          if object.otype is 10
            oid = object.albums[0].oid
          else if object.otype in [20, 30]
            oid = object.oid
          if object.otype in [10, 20]
            $.getJSON '/album_details', {'oid': oid}, (data) ->
              displayed_oid = $('#results').children().first().data('oid')
              if not displayed_oid or displayed_oid != oid
                if data.albums
                  data=data.albums
                $('#results').empty()
                $('#results').html otto.templates.albums_details data: [].concat(data), oid: oid
                otto.mark_allthethings()
          else if object.otype in [30]
            # database is broken. artist->fileunder isn't recorded in collections! FIXME
            # hack around this
            oid = $gotothere.data('albumoid')
            $.getJSON '/load_fileunder', {'artistoid': oid}, (fileunder) ->
              oid = 0
              for fu in fileunder
                if fu.key != 'various'
                  oid = fu.oid
              if oid
                $.getJSON '/album_details', {'oid': oid}, (data) ->
                  displayed_oid = $('#results').children().first().data('oid')
                  if not displayed_oid or displayed_oid != oid
                    if data.albums
                      data=data.albums
                    $('#results').empty()
                    $('#results').html otto.templates.albums_details data: [].concat(data), oid: oid
                    otto.mark_allthethings()

    else if $target.is('.progress') or $target.is('#progress-bar')
      if $target.is('#progress-bar')
        width = $target.parent().innerWidth()
        adjust = -2
      else
        width = $target.innerWidth()
        adjust = -4
      seconds = Math.round( (e.offsetX+adjust) / (width-1) * otto.current_song_total)
      @emit 'seek', seconds
    else
      console.log 'do not know what to do with clicks on this element:'
      console.dir $target
      console.dir e


  otto.channellist_click_handler = (e) =>
    $target = $(e.target)

    if ($target.is '.changechannel') or ($target.parent().is '.changechannel')
      newchannelname = $target.data('channelname') || $target.parent().data('channelname')
      console.log 'change channel to', newchannelname
      @emit 'changechannel', newchannelname
      $('#channellist').trigger('close')

    else
      console.log 'do not know what to do about a click on this here element:'
      console.dir $target


  otto.console_click_handler = (e) ->
    $target = $(e.target)

    if $target.is '#console'
      $target.focus()
      return true

    else
      console.log 'do not know what to do with a click on this element:'
      console.dir $target


  otto.command_change_handler = (command) =>
    if command and command != '' and command.indexOf('.') != 0
      if not otto.clientstate.typing
        @emit 'typing', 1
      otto.clientstate.typing = 1
    else
      if otto.clientstate.typing
        @emit 'typing', 0
      otto.clientstate.typing = 0


  otto.window_focus_handler = (e) =>
    if e.type is 'focus'
      @emit 'focus', 1
    else if e.type is 'blur'
      @emit 'focus', 0


  otto.window_idle_handler_init = =>
    $.idleTimer(5 * 60 * 1000)
    $(document).on 'idle.idleTimer', =>
      if not otto.clientstate.idle
        @emit 'idle', 1
      otto.clientstate.idle = 1
    $(document).on 'active.idleTimer', =>
      if otto.clientstate.idle
        @emit 'idle', 0
      otto.clientstate.idle = 0


  otto.letterbar_click_handler = (e) =>
    $letter = $(e.target)
    if not $letter.is '.letter'
      $letter = $(e.target).parents('.letter').first()
      if not $letter.is '.letter'
        #console.log 'this did not look like a letter to me'
        #console.log $letter
        return
    e.stopPropagation();

    if $letter.is '.active'
      $letter.removeClass 'active'
      $('#results').empty()
      return

    $('.active').removeClass 'active'
    $letter.addClass 'active'

    if $letter.is '.warn'
      if $letter.is '.big'
        $alert = $ otto.templates.alert
          #message: '''
          #  Warning: This shows everything, which is quite a lot.
          #  It takes a while, give it at least a minute or two.
          #  It can be very hard on your browser (Chrome probably handles it best).
          #'''
          message: '''
            Warning: This is suppose to show everything, but it
            is not currently working.
          '''
      if $letter.is '.beta'
        $alert = $ otto.templates.alert
          message: 'Warning: this feature is not really working yet'


      $alert.find('#ok').data 'run', ->
        $('#results').empty()
        $letter.clone().removeClass('warn active').on('click', otto.letter_click_handler).click()
      $alert.find("#cancel").data 'run', ->
        $letter.parent().find("li").removeClass 'active'
        $('#results').html '<div>canceled</div>'
        $('#results').children().fadeOut 1500, ->
          $('#results').empty()
      $('#results').html $alert
      return

    if $letter.is '.shownewest'
      return otto.render_json_call_to_results '/load_newest_albums', {}, 'newest_albums'
    if $letter.is '.showowners'
      return otto.render_json_call_to_results '/load_owners', {}, 'show_owners'
    if $letter.is '.showall'
      return otto.render_json_call_to_results '/all_albums', {}, 'allalbums'
    if $letter.is '.showcubes'
      return otto.call_module 'cubes', 'show'
    if $letter.is '.showlists'
      return otto.render_json_call_to_results '/load_lists', { objects: 1 }, 'show_lists'
    if $letter.is '.showstars'
      return otto.render_json_call_to_results '/load_stars', { objects: 1 }, 'show_stars'

    val = $letter.text()

    if val is '/'
      return otto.dirbrowser()

    if val is '#'
      val = 'num'
    if val is '⋯'
      val = 'other'
    otto.render_json_call_to_results '/starts_with', \
        { value: val, otype: 40, attribute: 'key' }, 'startswith'


  otto.results_lazyload_handler = (e) ->
    $("#results").children().each ->
      $this = $ this
      # skip this container if it's marked nolazy
      if $this.is '.nolazy'
        return
      s = {threshold: 2000, container: window}
      # check if this container is visible, skip it if it's not
      if $.belowthefold(this, s) || $.rightoffold(this, s) || $.abovethetop(this, s) || $.leftofbegin(this, s)
        return
      # now dive in to the top level items on a page
      $("#results").children().each ->
        $this = $(this)
        # skip this container if it's marked nolazy
        if $this.is '.nolazy'
          return
        s = {threshold: 2000, container: window}
        # check if this container is visible, skip it if it's not
        if $.belowthefold(this, s) || $.rightoffold(this, s) || $.abovethetop(this, s) || $.leftofbegin(this, s)
          return
        $this.find("img.lazy").each ->
          $this = $(this)
          if not ($.belowthefold(this, s) || $.rightoffold(this, s) || $.abovethetop(this, s) || $.leftofbegin(this, s))
            $lazy = $this
            $real = $("<img />").on 'load', ->
              $lazy.attr('src', $lazy.data('original'))
            $real.attr("src", $lazy.data('original'))
            $lazy.removeClass('lazy')


  otto.form_submit_handler = (e) =>
    $form = $(e.target)
    return if not $form.is 'form'
    e.preventDefault()

    if $form.is '.searchform'
      $searchtext = $('#searchtext')
      search_word = $searchtext.val()
      $searchtext.select()
      if not (search_word=='')
        otto.render_json_call_to_results '/search', {value: search_word}, 'search', \
            "&nbsp;&nbsp;&nbsp;&nbsp;Searching <span class='highlight'>#{search_word}</span>"

    else if $form.is '.loginform'
      name = $('#logintext').val()
      if not (name=='')
        @emit 'login', name
        #$.getJSON '/login', { user: name }, (data) ->


  otto.adjust_volume_handler = (e, ui) ->
    console.log 'adjust_volume'
    otto.current_volume = ui.value
    otto.call_module_ifloaded 'player', 'setvolume', otto.current_volume


  otto.adjust_volume_lineout_handler = (e, ui) =>
    console.log 'adjust_volume_lineout'
    otto.current_volume_lineout = ui.value
    @emit 'setvol', ui.value


  # prevent mouse wheel events from bubbling up to the parent
  otto.scroll_bubble_stop_handler = (e, delta) ->
    # requires the jquery.mousewheel plugin which adds the delta param
    $this = $(this)
    height = $this.height()
    scroll_height = $this.prop 'scrollHeight'
    if scroll_height > height # only kill scrolling on elements with scroll bars
      if delta > 0  # scroll up
        if $this.scrollTop() == 0
          e.preventDefault()
      else if delta < 0  # scroll down
        scroll_bottom = $this.scrollTop() + height
        if scroll_bottom == scroll_height
          e.preventDefault()


  ##########
  ########## non-handlers
  ##########

  otto.render_json_call_to_results = (url, params, template, message, callback) ->
    $results = $('#results')
    if message
      $results.html message
    else
      $results.empty()
    $.getJSON url, params, (data) ->
      $results.append otto.templates[template] data: data
      #document.body.scrollTop=0
      otto.mark_allthethings()
      $results.trigger 'scrollstop'
      if callback
        callback(data)


  otto.dirbrowser = ->
    dirbrowser_html = $ otto.templates.dirbrowser()
    dirbrowser_click_handler = (e) ->
      item = $(e.target)
      id = item.attr('id')
      if item.is '.path'
        $.getJSON '/load_dir', {'oid': id}, (data) ->
          $('#subdirs').html otto.templates.dirbrowser_subdir data: data
      else if item.is '.subdir'
        $('#path').append(
            $('<li class="path">').html(
              item.attr('data-filename')+'/'
            )
        )
        $.getJSON '/load_dir', {'oid': id}, (data) ->
          $('#subdirs').html otto.templates.dirbrowser_subdir data: data
    dirbrowser_html.click dirbrowser_click_handler
    $('#results').empty()
    $('#results').append dirbrowser_html

    $.getJSON '/music_root_dirs', (data) ->
      $('#path').html otto.templates.dirbrowser_item data: data


  otto.mark_allthethings = ->
    otto.mark_queued_songs()
    otto.mark_listed_items()
    otto.mark_starred_items()

  otto.mark_queued_songs = () ->
    $('.inqueue').removeClass('inqueue')
    $('.first').removeClass('first')
    $('.tempremove').remove()
    $('.temphidden').show()
    first = true
    for song in otto.cache.queue
      #if song.requestor  # if we only want to mark non auto picked songs
      $items = $('#'+song.oid.toString())
      $items.addClass('inqueue')
      if first
        $items.addClass('first')
        first = false
      $items.parent().find('.enqueue').addClass('temphidden').hide()
      $items.parent().prepend("<button id='#{song.mpdqueueid}' class='tempremove btn teeny control remove'><i class='remove'>")


  otto.mark_listed_items = () ->


  otto.mark_starred_items = () ->
    $('.stars.n1, .stars.n2, .stars.n3, .stars.n4, .stars.n5, .stars.n6').removeClass('n1 n2 n3 n4 n5 n6').addClass('n0')
    if otto.cache.stars
      for item in otto.cache.stars
        $('[data-oid='+item.child.toString()+'].stars').addClass('n'+item.rank)


  otto.compute_artistinfo = (album) ->
    # FIXME doubled artists? (filter out 5,6?)
    all = []
    various = soundtrack = false
    single = primary = secondary = ''
    if album.artists
      for artist in album.artists
        if artist.artist is 'Soundtrack'
          soundtrack = 'Soundtrack'
        # FIXME we shouldn't have to remove these
        # (but we do until i track down why everything is soundtrack and various bug)
        continue if artist.artist is 'Soundtrack'
        continue if artist.artist is 'Various'
        all.push(artist.artist)

    if all.length > 2
      various = 'Various'
      single = 'Various'
    if not various
      if all.length
        primary = all[0]
      if all.length is 2
        secondary = all[1]
      single = primary
      if secondary
        single += ', ' + secondary
    if soundtrack
      if not single
        single = 'Soundtrack'
    #console.log all
    return { various: various, soundtrack: soundtrack, single: single, primary: primary, secondary: secondary, all: all }


  otto.connect_player = ->
    if not otto.ismoduleloaded 'player'
      # give some immediate feedback while the module loads
      $('#connect').html otto.templates.ouroboros size: 'small', direction: 'cw', speed: 'slow'
    otto.connect_state = 'connected'
    otto.call_module 'player', 'connect', otto.mychannelname

  otto.disconnect_player = ->
    otto.connect_state = 'disconnected'
    otto.call_module 'player', 'disconnect'

  otto.reconnect_player = ->
    otto.disconnect_player()
    otto.connect_player()

  otto.play_soundfx = (name) ->
    if otto.soundfx
      otto.call_module 'soundfx', 'play', name


  otto.play_notification = (event) ->
    if otto.notifications
      return if event.name is 'finished'
      text = otto.templates.event_text event
      n = new Notification event.name, body: text
      n.onshow = ->
        timeoutSet 10000, -> n.close()


  otto.ouroboros_init = ->
    # css animations seem to stop when the client is working (e.g. when rending the template
    # after receiving the data from the ajax call). i wonder if animated gifs do.
    # i hear making it it's own layer on the GPU will allow animations to continue (ref AEA '13 notes)
    $(document).ajaxStart ->
      $('.ouroboros-container').html otto.templates.ouroboros()
    $(document).ajaxStop ->
      $('.ouroboros-container').empty()
    $(document).ajaxError (e, xhr, settings, exception) ->
      # or maybe use ajaxComplete (no)? look at the jQuery docs
      # (see http://stackoverflow.com/questions/4419241/jqueryajaxstop-versus-jqueryajaxcomplete)
      # it seems if you throw and error while processing in your success callback this (or ajaxStop)
      # doesn't get called? if true then this is fragile. perhaps use the ajaxSend/ajaxComplete hooks?
      # those should run before any of our error-prone code, yes? we'd need to keep an outstanding call count
      $('.ouroboros-container').empty()
      console.log 'ajax error in: ' + settings.url + ' \n'+'error:\n' + exception
      throw exception


  otto.chat_init = =>
    chatinput = (command) =>
      if command != ''
        $('#output').scrollToBottom()
        if /^[.]/.test command
          switch command
            when '.cls' then $('#output').empty()
            when '.reload' then @emit 'reloadme'
            when '.reloadall' then @emit 'reloadall'

        else
          @emit 'chat', command

    $('#inputr').cmd
      prompt: ->  # empty function supresses the addition of a prompt
      width: '100%'
      elementtobind: $('#console')
      commands: chatinput
      onCommandChange: otto.command_change_handler
