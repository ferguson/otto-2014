####
#### client side (otto.client served by zappa as /otto.client.js)
####

global.otto.client = ->
  window.otto = window.otto || {}

  otto.socketconnected = false
  otto.salutations = false
  otto.clientstate = {}
  otto.myusername = no
  otto.mychannel = no
  otto.current_track_qid = no
  otto.channel_list = []
  otto.current_channel = no
  otto.play_state = 'unknown'
  otto.connect_state = 'disconnected'
  otto.ignore_reload = false
  otto.cache = { queue: [], list: [], stars: [] }
  otto.current_volume = 80
  otto.soundfx = no
  otto.notifications = no

  ## should only do this in dev mode, but we need to tell the client we are in dev mode somehow FIXME
  #window.console.log = ->
  #  @emit 'console.log', Array().slice.call(arguments)
  #window.console.dir = ->
  #  @emit 'console.dir', Array().slice.call(arguments)

  #alternately:
  #$('body').append $ '<script src="http://jsconsole.com/remote.js?656D8845-91E3-4879-AD29-E7C807640B61">'


  @on 'error': ->
    console.log 'socket.io connection error'
    #alert 'reloading'
    window.location.reload()


  @on 'connect': ->
    console.log 'socket.io connected'
    otto.socketconnected = true
    # now we wait for the server to say 'proceed' or ask us to 'resession'


  @on 'resession': ->
    console.log 'sir, yes sir!'
    $.get '/resession', =>
      console.log 'sir, done sir!'
      otto.sayhello()


  @on 'proceed': ->
    otto.sayhello()
    # now we wait for the server to say 'welcome' and give us data


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


  # use nextTick so the function, and the functions it calls, are all defined
  nextTick ->
    otto.start_client()

  otto.start_client = =>
    console.log 'start_client'

    otto.touch_init()

    otto.showdown_converter = new Showdown.converter()

    $(window).on 'scrollstop', otto.results_lazyload_handler
    $(window).smartresize otto.results_lazyload_handler
    $(window).smartresize otto.autosize_adjust
    $(window).on 'focus blur', otto.window_focus_handler
    otto.ouroboros_init()
    otto.window_idle_handler_init()

    $(document.body).html otto.templates.body_startup()

    $('body').on 'click', otto.button_click_handler
    $('body').on 'click', otto.letterbar_click_handler
    $('body').on 'change', otto.checkbox_click_handler
    $('body').on 'submit', otto.form_submit_handler

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

    #otto.sayhello()  # is this needed? doesn't having it in @on 'connect' suffice? FIXME
    # if it is needed we might be in trouble with out new 'proceed' and 'resession' setup


  otto.sayhello = =>
    if otto.socketconnected and not otto.salutations
      otto.salutations = true
      console.log 'well, hello server!'
      @emit 'hello', otto.clientstate # causes the server to welcome us and tells us our state


  otto.saygoodbye = =>
    console.log 'ok lady, goodbye!'
    otto.salutations = false
    otto.myusername = false
    otto.mychannel = false
    otto.current_track_qid = false


  @on 'welcome': ->
    console.log 'welcome data', @data
    $('body').removeClass 'disconnected'
    otto.localhost = @data.localhost
    otto.emptydatabase = @data.emptydatabase
    otto.largedatabase = @data.largedatabase
    otto.haslineout = @data.haslineout
    otto.musicroot = @data.musicroot
    console.log 'musicroot', otto.musicroot

    #otto.emptydatabase = true  #!# temp. while developing

    if otto.emptydatabase
      otto.create_hellopage()
      otto.channel_list = @data.channellist
      otto.myusername = @data.myusername
      otto.mychannel = @data.mychannel
    else
      $(document.body).html otto.templates.body()
      $('.channellist-container').on 'click', otto.channellist_click_handler
      otto.process_channellist @data.channellist, true  #process_mychannel will do the final html
      otto.process_myusername.call @, @data.myusername
      otto.process_mychannel.call @, @data.mychannel


  @on 'begun': ->
    otto.emptydatabase = false
    $(document.body).html otto.templates.body()
    $('.channellist-container').on 'click', otto.channellist_click_handler
    otto.process_channellist otto.channel_list, true  #process_mychannel will do the final html
    otto.process_myusername.call @, otto.myusername
    otto.process_mychannel.call @, otto.mychannel
    $('.output').append navigator.userAgent
    $('.output').append otto.app

    @emit 'updateme'


  otto.create_mainpage = ->
    #$(document).attr 'title', otto.current_channel.fullname + ' ▪ ' + otto.myurl + ' ▪ otto' #FIXME
 #!#   $(document).attr 'title', otto.current_channel.fullname + ' ▪ otto' #FIXME
    $('#mainpage').html otto.templates.mainpage channel: otto.current_channel

    $('.playing-container').on 'click', otto.results_click_handler
    $('.browseresults-container').on 'click', otto.results_click_handler
    $('.console-container').on 'click', otto.console_click_handler
    $('.volume').slider value: otto.current_volume, range: 'min', slide: otto.adjust_volume_handler
    $('.volumelineout').slider value: otto.current_volume, range: 'min', slide: otto.adjust_volumelineout_handler
    $('.scrollkiller').on 'mousewheel', otto.scroll_bubble_stop_handler
    $('.console-container').resizable handles: 's', alsoResize: $('.output'), minHeight: 45, autoHide: true
    $('.channellist-container').mmenu(  { slidingSubmenus: false } )
    #$('.cursor-hider').hover (e) -> e.stopPropagation() # don't suppress the mouseleave event FIXME
    $('.cursor-hider').on 'mouseenter', (e) -> e.stopPropagation()
    otto.chat_init()
    # preserve chat window state
    if otto.clientstate.inchat
      otto.clientstate.inchat = false  # to convince enable_chat to act
      otto.enable_chat true


  otto.create_hellopage = ->
    otto.load_module 'cubes'  # all the welcome css is in otto.cubes.css
    $(document.body).html otto.templates.body_welcome musicroot: otto.musicroot
    $('.folder .path').keydown (e) ->
      if e.keyCode is 13
        e.preventDefault()
        $('.folder .path').blur()


  @on 'queue': ->
    console.log 'queue', @data
    if @data.length
      n = 0
      console.log @data
      for song, i in @data
        if song.nowplaying
          n = i
          break
      if not otto.current_track_qid == false || otto.current_track_qid != @data[n].mpdqueueid
        len = Math.ceil(@data[n].length)  # we want to round up so it matches what mpd does
        # take 'len' if you don't want an initial progress bar
        time = otto.current_song_time || { current: 0, total: len || 0 }
        active = $('.currentcover-container .thumb').is '.active'
        $('.currenttrack-container').html otto.templates.currenttrack song: @data[n], current: time.current, total: time.total
        otto.autosize_adjust()
        if active
          top = $(window).scrollTop()
          $('.currentcover-container .thumb').click()
          $(window).scrollTop(top)
          # that isn't cutting it, still scrolls if track changes
          # and a minimum we should check if the album changed and only repaint if so

      otto.current_track_qid = @data[n].mpdqueueid

      $target = if otto.noscroll_click_event then $(otto.noscroll_click_event.target) else false
      otto.noscroll_click_event = false
      otto.render_without_scrolling $target, =>
        if otto.current_channel.layout is 'featured'
          $('.ondeck-container').html otto.templates.featured songs: @data[0..@data.length]
        else
          $('.ondeck-container').html otto.templates.ondeck songs: @data[1..@data.length]

      if otto.notifications  # add notification for enter/leaving chat room #FIXME <- might be ok
        song = @data[n]
        if song._id isnt otto.lastnotificationid
          otto.lastnotificationid = song._id
          album = song.album || ''
          #album += ' • ' + song.year if song.year
          album += '    ' + song.year if song.year
          artist = song.artist || ''
          body = "#{album}\n#{artist}"
          body += "\n#{song.owners[0].owner}" if song.owners?[0].owner?
          otto.lastnotification.close() if otto.lastnotification  # we should (also?) close on 'finished' event
          otto.lastnotification = new Notification song.song, body: body, icon: "/image/120?id=#{song.cover}"
          #n.onshow = ->
          #  timeoutSet 10000, -> n.close()
    else
      $('.currenttrack-container').html otto.templates.currenttrack {}
    otto.cache.queue = @data

    otto.mark_allthethings()


  @on 'state': ->
    console.log 'state', @data
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
      otto.current_song_time = { current: current, total: total }

      $('.timeprogress-container').html otto.templates.timeprogress_widgets total: total, current: current


  @on 'loader': ->
    #console.log 'loader says:', @data
    otto.client.cubes.loader_event @data
    if @data is 'started'
      if otto.emptydatabase
        $(document.body).html otto.templates.initialload folder: $('.folder .path').text()
        $('.loadingstatus').addClass('searching');
        $('.loadingcubes').html otto.client.cubes.show()
    else if @data.stdout and @data.stdout isnt 'new' and @data.stdout isnt ' ' and @data.stdout isnt ''
      $output = $('.output')
      if $output.length
        amountscrolledup =  $output.prop('scrollHeight') - $output.height() - $output.scrollTop()
        $output.append otto.templates.loader event: @data.stdout
        if amountscrolledup < 500  # was 80, but i think we need a different detection mech. for autoscroll
          $output.scrollToBottom()


  @on 'myusername': ->
    console.log 'myusername'
    otto.process_myusername.call @, @data

  otto.process_myusername = (username) ->
    otto.myusername = username
    if username
      $('body').addClass 'loggedin'
      $('body').removeClass 'loggedout'
    else
      otto.enable_chat false
      $('.browseresults-container').empty()
      $('body').addClass 'loggedout'
      $('body').removeClass 'loggedin'


  @on 'myurl': ->
    console.log 'myurl'
    otto.myurl = @data.name
    $('#channelname').text @data.fullname


  @on 'mychannel': ->
    console.log 'changing channel to', @data.name
    otto.process_mychannel.call @, @data.name

  otto.process_mychannel = (name) ->
    otto.mychannel = name
    otto.current_track_qid = false

    otto.current_channel = false
    for channel in otto.channel_list
      if channel.name is otto.mychannel
        otto.current_channel = channel
    if not otto.current_channel then otto.current_channel = otto.channel_list[0]

    if not otto.emptydatabase
      otto.create_mainpage()

      $('.channellist-container').html otto.templates.channellist channellist: otto.channel_list

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
    if otto.clientstate.inchat
      if window.location.hash isnt ''
        window.location.hash += '&chat=1'
      else
        window.location.hash += '#chat=1'
    window.location.reload()


  @on 'chat': ->
    console.log @data.name
    return if @data.name is 'finished'
    otto.play_soundfx @data.name
    otto.play_notification @data
    $output = $('.output')
    amountscrolledup = $output.prop('scrollHeight') - $output.height() - $output.scrollTop()
    $output.append otto.templates.event event: @data
    if amountscrolledup < 80
      $output.scrollToBottom()


  @on 'lists': ->
    console.log 'lists'
    if @data
      otto.process_lists @data

  otto.process_lists = (lists) ->
    if lists
      for user in lists
        if user == otto.myusername
          otto.cache.list = user.list
          otto.mark_listed_items()
          $('.browsersults-container').trigger('scrollstop')


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
        $('.browseresults-container').trigger('scrollstop')


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
        console.error 'failed to disable style sheet'
    #$new_sheet = $('<style id="#'+@data.sheetname+'css">').html @data.css
    $new_sheet = $('<style>').html @data.css
    #$new_sheet[0].data = sheetname
    $('head').append $new_sheet
    document.styleSheets[document.styleSheets.length-1].data = sheetname


  @on 'listeners': ->
    #console.log 'listeners', @data
    socketid = @socket?.socket?.sessionid
    $('.listeners-container').html otto.templates.listeners(listeners: @data, socketid: socketid)

    #$('.channellist-container').html otto.templates.channellist channellist: otto.channel_list, listeners: @data, socketid: socketid
    # let's try to insert the listeners without rebuilding the entire channel list
    # so that open channel setting don't go away every time a listener changes state
    for channel in otto.channel_list
      html = otto.templates.format_listeners_for_channel_in_channelbar listeners: @data, channelname: channel.name
      $('.channellist-container [data-channelname="'+channel.name+'"] .channellisteners').html html


  @on 'channellist': ->
    console.log 'channellist'
    otto.process_channellist @data


  @on 'outputs': ->

  @on 'lineout': ->
    if @data
      for channelname,lineout of @data
        $el = $('.channellist-container .changechannel[data-channelname="'+channelname+'"]')
        if $el
          if lineout == '1'
            $el.addClass 'lineout'
          else
            $el.removeClass 'lineout'


  @on 'status': ->
    if @data
      for channelname,status of @data
        $el = $('.channellist-container .changechannel[data-channelname="'+channelname+'"]')
        if $el
          if status.state == 'play'
            $el.addClass 'playing'
          else
            $el.removeClass 'playing'
        if channelname == otto.mychannel
          # should prob. do this here too: if parseInt($vol.slider('value')) != parseInt(status.volume)
          $('#mainpage .volumelineout').slider 'option', 'value', status.volume
        $el.find('.volumelineout').each ->
          $vol = $(@)
          # when i do a log based volume formula, i'll need to reverse it here
          if parseInt($vol.slider('value')) != parseInt(status.volume)
            #console.log '$vol.value', $vol.slider('value'), 'status.volume', status.volume
            $vol.slider 'option', 'value', status.volume
          $el.find('.channelerrata-container').html otto.templates.channel_status_errata_widget status: status


  otto.process_channellist = (channellist, skiphtml) =>
    otto.channel_list = channellist
    unless skiphtml
      $('.channellist-container').html otto.templates.channellist channellist: otto.channel_list
      $('.volumelineout').slider value: otto.current_volume, range: 'min', slide: otto.adjust_volumelineout_handler


  ####
  #### handlers
  ####

  otto.checkbox_click_handler = (e) =>
    $checkbox = $(e.target)
    if not $checkbox.is 'input[type="checkbox"]'
      return
    e.stopPropagation()

    # no longer used
    if $checkbox.is '#fxtoggle'
      otto.soundfx = $checkbox.is ':checked'
      if otto.soundfx
        otto.play_soundfx 'fxenabled'

    # not used anymore
    if $checkbox.is '#lineouttoggle'
      otto.lineout = $checkbox.is ':checked'
      if otto.lineout
        $('.volumelineout').show()
      else
        $('.volumelineout').hide()
      for channel in otto.channel_list
        if channel.name is otto.mychannel
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
    e.stopPropagation()

    find_id = ($el, ancestorlimit=2) ->
      id = $el.data('id')
      if id then return id
      for oneclass in $el[0].className.split /\s/
        found = oneclass.match /^id(.{24})$/
        if found then return found[1]
      $el.find("*").each ->
        id = find_id $(this), 0
        if id then return false  # stops .each
      if id then return id
      if ancestorlimit > 0
        return find_id $el.parent(), ancestorlimit - 1
      return 0

    find_qid = ($el, ancestorlimit=2) ->
      qid = $el.data('mpdqueueid')
      if qid then return qid
      $el.find("*").each ->
        qid = find_qid $(this), 0
        if qid then return false  # stop .each
      if qid then return qid
      if ancestorlimit > 0
        return find_qid $el.parent(), ancestorlimit - 1
      return 0

    # check for unqueue class before enqueue since the button will be .enqueue.unqueue
    if $button.is '.unqueue'
      qid = find_qid $button
      console.log 'deleteid', qid
      otto.noscroll_click_event = e
      @emit 'deleteid', qid

    else if $button.is '.enqueue'
      id = find_id $button
      console.log 'enqueue', id
      otto.noscroll_click_event = e
      @emit 'enqueue', id

    else if $button.is '.stars'
      console.log '.stars', e
      console.log $button
      console.log 'e.pageX', e.pageX
      console.log '$button.offset().left', $button.offset().left
      if $('html').is '.doubler'
        clickpoint = e.pageX - ($button.offset().left * 2) - 8
        clickpoint = clickpoint / 2
      else
        clickpoint = e.pageX - $button.offset().left - 4
      console.log 'clickpoint', clickpoint
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
      id = find_id $button
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
      toggle_play.call @

    else if $button.is '#next'
      next_track.call @

    else if $button.is '.smaller'
      console.log 'yup'
      #if $('html').is '.doubler'
      #  console.log 'undoubler'
      #  $('html').removeClass('doubler')
      #else
      #  $('.currenttrack-container').addClass('size1').removeClass('size2')
      #  $('.next-container').addClass('size1').removeClass('size2')
      $('.currenttrack-container').addClass('size1').removeClass('size2')
      $('.next-container').addClass('size1').removeClass('size2')
      otto.autosize_adjust()
    else if $button.is '.bigger'
      #window.resizeTo(1920, 1080)  # just for debugging tv mode
      #if $('.currenttrack-container').is '.size2'
      #  $('html').addClass('doubler')
      #else
      #  $('.currenttrack-container').addClass('size2').removeClass('size1')
      #  $('.next-container').addClass('size2').removeClass('size1')
      $('.currenttrack-container').addClass('size2').removeClass('size1')
      $('.next-container').addClass('size2').removeClass('size1')
      otto.autosize_adjust()

    else if $button.is '.close'
      container_top = $button.parent().parent().parent().offset().top
      $button.parent().remove()
      if $('.browseresults-container').parent().scrollTop() > container_top
        $('.browseresults-container').parent().scrollTop(container_top)

    else if $button.is '.runself'
      run = $button.data('run')
      run()

    else if $button.is '.download'
      id = $button.data('id')
      $iframe = $("<iframe class='download' id='#{id}' style='display:none'>")
      $(document.body).append $iframe
      $iframe.attr 'src', "/download/#{id}"
      $iframe.load ->
        console.log "iframe #{id} loaded"
        #$iframe.remove() # this seems to cut off the download FIXME

    else if $button.is '.chattoggle'
      #$('.console-container').toggle(200)
      if not otto.clientstate.inchat
        otto.enable_chat true
      else
        otto.enable_chat false

    else if $button.is '.channeltoggle'
      toggle_channellist $button

    else if $button.is '.logout'
      @emit 'logout'

    else if $button.is '.play'
      @emit 'play', $button.data('position')

    else if $button.is '.notificationstoggle'
      if otto.notifications
        otto.notifications = false
        $button.removeClass 'enabled'
        otto.lastnotification.close() if otto.lastnotification
      else if Notification?
        Notification.requestPermission (status) ->
          console.log 'notifications permission', status  # looking for "granted"
          if status isnt "granted"
            otto.notifications = false
            $button.removeClass 'enabled'
          else
            otto.notifications = true
            $button.addClass 'enabled'
            n = new Notification "Notifications Enabled", {body: ""} # this also shows the notification
            n.onshow = ->
              timeoutSet 4000, -> n.close()
            otto.lastnotification = n

    else if $button.is '.soundfxtoggle'
      if otto.soundfx
        otto.soundfx = false
        $button.removeClass 'enabled'
      else
        otto.soundfx = true
        $button.addClass 'enabled'
        otto.play_soundfx 'fxenabled'

    else if $button.is '.selectfolder'
      if otto.localhost and /Otto$/.test navigator.userAgent
        #@emit('selectfolder')  # uneven message processing in Otto.py make this unusable
        # instead i use a UIDelegate on the webview to override the file selection input
        # so the rest of this if should never be run
        $('#selectFolder').click()
        $('#selectFolder').change ->
          alert 'sorry, you can\'t use the folder selection dialog from a web browser'
          #$('.folder .path').text $('#selectFolder').val()
          return false
      else
        $path = $('.folder .path')
        $path.focus()
        #$path.text $path.text()  # move cursor to end? nope.
        #len = $path.val().length
        #$path[0].setSelectionRange(len, len)  # nope (setSelectionRange not defined)

    else if $button.is '.loadmusic'
      @emit 'loadmusic', $('.folder .path').text()

    else if $button.is '.loadmusic2'
      @emit 'loadmusic'  # loader.py defaults to last directory loaded from

    else if $button.is '.begin'
      console.log 'begin!'
      @emit 'begin'

    else if $button.is '.restartload'
      console.log 'restartload'
      otto.create_hellopage()

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
      id = $expand.data('id')
      containerid = $expand.data('container') || id
      #$container = $(".id#{containerid}")
      $parent = $expand.parent()
      $container = $parent
      if $parent.is '.thumbnails'
        $container = $parent.parent()

      $expanded = $('.expanded')
      if $expanded.length and $expanded.data('id') == id
        # same item, close it instead of redisplaying it (i.e. do nothing)
        otto.render_without_scrolling $(e.target), ->
          $expanded.remove()
          $('.active').removeClass('active')
      else
        $.getJSON '/album_details', {'id': id}, (data) ->
          if data.albums
            data=data.albums
          $.getJSON '/load_object', {'id': containerid}, (fileunder) ->
            otto.render_without_scrolling $(e.target), ->
              $expanded.remove()
              $('.active').removeClass('active')
              $element = $ "<div class='expanded cf' data-id=#{id}>"
              $element.html otto.templates.albums_details data: [].concat(data), fileunder: fileunder, id: id
              if $parent.is '.albumall'
                # search forward to find where the line breaks and put it there
                $eol = false
                $last = $parent
                while not $eol
                  $next = $last.next()
                  if $next.length is 0
                    $eol = $last
                  else if $next.offset().top > $last.offset().top
                    $eol = $last
                  else
                    $last = $next
                $eol.after $element
              else
                $container.append $element
              $expand.addClass('active')
              otto.mark_allthethings()

    else if $gotothere
      id = $gotothere.data('id')
      if $gotothere.is '.active'
        $('.browseresults-container').empty()
        $gotothere.removeClass('active')
        console.log 'removing active'
      else
        $('.active').removeClass('active')
        $gotothere.addClass('active')
        console.log 'adding active'
        if not $('.browseresults-container').children().first().is '.albumdetailscontainer'
          $('.browseresults-container').empty()
        $.getJSON '/load_object', {id: id, load_parents: 20}, (object) ->
          if object.otype is 10
            id = object.albums[0]._id
          else if object.otype in [20, 30]
            id = object._id
          if object.otype in [10, 20]
            $.getJSON '/album_details', {'id': id}, (data) ->
              displayed_id = $('.browseresults-container').children().first().data('id')
              if not displayed_id or displayed_id != id
                if data.albums
                  data=data.albums
                $('.browseresults-container').html otto.templates.albums_details data: [].concat(data), id: id
                otto.mark_allthethings()
          else if object.otype in [30]
            # database is broken. artist->fileunder isn't recorded in collections! FIXME
            # hack around this
            id = $gotothere.data('albumid')
            $.getJSON '/load_fileunder', {'artistid': id}, (fileunder) ->
              id = 0
              for fu in fileunder
                if fu.key != 'various'
                  id = fu._id
              if id
                $.getJSON '/album_details', {'id': id}, (data) ->
                  displayed_id = $('.browseresults-container').children().first().data('id')
                  if not displayed_id or displayed_id != id
                    if data.albums
                      data=data.albums
                    $('.browseresults-container').html otto.templates.albums_details data: [].concat(data), id: id
                    otto.mark_allthethings()

    else if $target.is('.progress') or $target.is('.progress-indicator')
      if $target.is('.progress-indicator')
        width = $target.parent().innerWidth()
        adjust = 0
      else
        width = $target.innerWidth()
        adjust = -2
      seconds = Math.round( (e.offsetX+adjust) / (width-1) * otto.current_song_time.total)
      @emit 'seek', seconds
      if otto.connect_state isnt 'disconnected'
        otto.reconnect_player() # make it stop playing instantly (flush buffer)
    else if $target.is '.loadmusic' # i don't understand why this is needed here, why button_click_handler doesn't see it
      #@emit 'loadmusic', $('.folder .path').text()
      console.log 'this one'
      @emit 'loadmusic', '/Users/jon/Music'
    else
      console.log 'do not know what to do with clicks on this element:'
      console.dir $target
      console.dir e


  toggle_play = ->
    if otto.play_state is 'play'
      @emit 'pause'
    else
      @emit 'play'


  next_track = ->
    qid = otto.current_track_qid
    console.log 'deleteid', qid
    @emit 'deleteid', qid
    otto.current_song_time = false
    if otto.connect_state isnt 'disconnected'
      otto.reconnect_player() # make it stop playing instantly (flush buffer)


  toggle_channellist = ($button) ->
    $channellist = $('.channellist-container')
    if $channellist.is '.mmenu-opened'
      $channellist.trigger('close')
    else
      $channellist.trigger('open')
      $button.trigger 'mousemove'
      # webkit bug leaves the div hovered when it is moved from under cursor
      #$('.channelbar').trigger 'mouseleave' # doesn't work


  otto.channellist_click_handler = (e) =>
    $target = $(e.target)
    $button = $(e.target)
    if $target.is 'button'
      $button = $target
    else
      $button = $target.parents('button').first()
    if $button.is 'button'
      e.stopPropagation()
    else
      $button = false

    find_channelname = ($el, ancestorlimit=4) ->
      channelname = $el.data('channelname')
      if channelname then return channelname
      if ancestorlimit > 0
        return find_channelname $el.parent(), ancestorlimit - 1
      return false

    if $button
      if $button.is '.channeltoggle'
        toggle_channellist $button
      else if $button.is '.channeloutput'
        channelname = find_channelname($target)
        alt = e.altKey
        @emit 'togglelineout', channelname: channelname, alt: e.altKey
      else if $button.is '.channelplay'
        channelname = find_channelname($target)
        @emit 'toggleplay', channelname
      else if $button.is '.channelsettings'
        if $button.parent().is '.open'
          console.log 'closing'
          $button.parent().parent().parent().find('.open').removeClass 'open'
        else
          console.log 'opening'
          $button.parent().parent().parent().find('.open').removeClass 'open'
          $button.parent().addClass 'open'
    else if $target.is '.channelselect, .channelname, .channellisteners, .listener'
      newchannelname = find_channelname($target)
      console.log 'change channel to', newchannelname
      @emit 'changechannel', newchannelname
      $('.channellist-container').trigger('close')

    else
      console.log 'do not know what to do about a click on this here element:'
      console.dir $target


  otto.console_click_handler = (e) ->
    $target = $(e.target)

    if $target.is '.console-container'
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
      otto.clientstate.focus = 1
    else if e.type is 'blur'
      otto.clientstate.focus = 0
    @emit 'focus', otto.clientstate.focus


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
    e.stopPropagation()

    if $letter.is '.active'
      $letter.removeClass 'active'
      $('.browseresults-container').empty()
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
        $('.browseresults-container').empty()
        $letter.clone().removeClass('warn active').on('click', otto.letter_click_handler).click()
      $alert.find("#cancel").data 'run', ->
        $letter.parent().find("li").removeClass 'active'
        $('.browseresults-container').html '<div>canceled</div>'
        $('.browseresults-container').children().fadeOut 1500, ->
          $('.browseresults-container').empty()
      $('.browseresults-container').html $alert
      return

    if $letter.is '.shownewest'
      return otto.render_json_call_to_results '/load_newest_albums', {}, 'newest_albums'
    if $letter.is '.showusers'
      return otto.render_json_call_to_results '/load_users', {}, 'show_users'
    if $letter.is '.showall'
      return otto.render_json_call_to_results '/all_albums_by_year', {}, 'allalbums'
    if $letter.is '.showcubes'
      otto.load_module 'cubes', ->
        $('.browseresults-container').html otto.templates.cubeswithload
        $('.loadingstatus').addClass('begin')
        $('.loadingcubes').html otto.call_module 'cubes', 'show'
      return
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
    $(".browseresults-container").children().each ->
      $this = $ this
      # skip this container if it's marked nolazy
      if $this.is '.nolazy'
        return
      s = {threshold: 2000, container: window}
      # check if this container is visible, skip it if it's not
      if $.belowthefold(this, s) || $.rightoffold(this, s) || $.abovethetop(this, s) || $.leftofbegin(this, s)
        return
      # now dive in to the top level items on a page
      $(".browseresults-container").children().each ->
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
        $('#logintext').val('')


  otto.adjust_volume_handler = (e, ui) ->
    console.log 'adjust_volume'
    otto.current_volume = ui.value
    otto.call_module_ifloaded 'player', 'setvolume', otto.current_volume


  otto.adjust_volumelineout_handler = (e, ui) =>
    console.log 'adjust_volumelineout', ui.value

    find_channelname = ($el, ancestorlimit=4) ->
      channelname = $el.data('channelname')
      if channelname then return channelname
      if ancestorlimit > 0
        return find_channelname $el.parent(), ancestorlimit - 1
      return false

    channelname = find_channelname( $(e.target) ) || otto.mychannel
    @emit 'setvol', channelname: channelname, volume: ui.value


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


  ####
  #### other stuff
  ####

  otto.render_json_call_to_results = (url, params, template, message, callback) ->
    $results = $('.browseresults-container')
    if message
      $results.html message
    else
      $results.empty()
    $.getJSON url, params, (data) ->
      # we could put the rendering under nextTick so the waiting spinner goes away
      # and is not at risk of staying there if the rendering throws an exception
      # *but* the rendering is often what takes the most time so we still
      # want a spinner.
      #nextTick ->
      # we could also consider changing the spinnder to be the slower one once
      # the rendering starts
      # let's try catching any exceptions during rendering so we can exit
      # cleanly and jquery can call out code to dismiss the spinner
      try
        $results.append otto.templates[template] data: data, params: params
        #document.body.scrollTop=0
        otto.mark_allthethings()
        $results.trigger 'scrollstop'
        if callback
          callback(data)
      catch error
        console.error "render_json_call_to_results caught error #{error}"


  otto.render_without_scrolling = ($target, render) ->
    if not $target
      render()
    else
      console.log 'before', $target.offset()
      top_before = $target.offset().top
      render()
      top_after = $target.offset().top
      if top_after isnt 0  # sometimes the element is removed (e.g. removing songs from ondeck panel)
        console.log 'after', $target.offset()
        amount_moved = top_after - top_before
        console.log 'moved', amount_moved, $(window).scrollTop(), $(window).scrollTop() + amount_moved
        $(window).scrollTop( $(window).scrollTop() + amount_moved )


  otto.dirbrowser = ->
    dirbrowser_html = $ otto.templates.dirbrowser()
    dirbrowser_click_handler = (e) ->
      item = $(e.target)
      id = item.attr('id')
      if item.is '.path'
        $.getJSON '/load_dir', {'id': id}, (data) ->
          $('#subdirs').html otto.templates.dirbrowser_subdir data: data
      else if item.is '.subdir'
        $('#path').append(
            $('<li class="path">').html(
              item.attr('data-filename')+'/'
            )
        )
        $.getJSON '/load_dir', {'id': id}, (data) ->
          $('#subdirs').html otto.templates.dirbrowser_subdir data: data
    dirbrowser_html.click dirbrowser_click_handler
    $('.browseresults-container').html dirbrowser_html

    $.getJSON '/music_root_dirs', (data) ->
      $('#path').html otto.templates.dirbrowser_item data: data


  otto.mark_allthethings = ->
    otto.mark_queued_songs()
    otto.mark_listed_items()
    otto.mark_starred_items()

  otto.mark_queued_songs = () ->
    $('.inqueue').removeClass('inqueue')
    $('.first').removeClass('first')
    $('.enqueue.unqueue').removeClass('unqueue')
    first = true
    for song in otto.cache.queue
      #if not song.requestor then continue  # if we only want to mark non auto picked songs
      $items = $('.id'+song._id)
      classstr = 'inqueue'
      if first
        classstr += ' first'
      $items.addClass(classstr)
      $items.parent().find('.enqueue').addClass('unqueue')
      if first
        $items.parent().find('.enqueue').addClass('first')
      $items.data('mpdqueueid', song.mpdqueueid)
      first = false

  otto.mark_listed_items = () ->

  otto.mark_starred_items = () ->
    $('.stars.n1, .stars.n2, .stars.n3, .stars.n4, .stars.n5, .stars.n6').removeClass('n1 n2 n3 n4 n5 n6').addClass('n0')
    if otto.cache.stars
      for item in otto.cache.stars
        $('[data-id='+item.child.toString()+'].stars').addClass('n'+item.rank)


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
    else if album.artist
      all.push(album.artist)

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
    otto.call_module 'player', 'connect', otto.mychannel

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


  otto.touch_init = ->
    #disable shy controls on touch devices
    #touch_device = 'ontouchstart' in document.documentElement
    #touch_device = ('ontouchstart' in window) or window.DocumentTouch and document instanceof DocumentTouch
    #touch_device = 'ontouchstart' in window or 'onmsgesturechange' in window # 2nd test for ie10

    #touch_device = true  #detection not working for some reason wtf? FIXME
    $('head').append '<script src="static/js/modernizr.custom.66957.js">'
    touch_device = Modernizr.touch  # prob doesn't work for ie10
    #http://stackoverflow.com/questions/4817029/whats-the-best-way-to-detect-a-touch-screen-device-using-javascript
    if touch_device
      otto.touchdevice = true
      console.log 'touch device detected, disabling shy controls'
      $('body').addClass 'noshy'
      $('head').append '<script src="static/js/fastclick.js">'
      FastClick.attach(document.body)

      addToHomescreen skipFirstVisit: true, maxDisplayCount: 1
      # http://blog.flinto.com/how-to-get-black-status-bars.html
      if window.navigator.standalone
        $("meta[name='apple-mobile-web-app-status-bar-style']'").remove()



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
    chatinput = (str) =>
      $('.output').scrollToBottom()
      str = $.trim(str)  # should strip tabs too FIXME
      if str != ''
        parts = str.match(/^([/.])([^ ]*)[ ]*(.*)$/)  # spaces *and* tabs FIXME
        if parts
          prefix  = parts[1]
          command = parts[2]
          therest = parts[3]
          args = therest.split('/[ \\t]/')
          switch command
            when 'cls' then $('.output').empty()
            when 'reload' then @emit 'reloadme'
            when 'reloadall' then @emit 'reloadall'
            when 'nick' then @emit 'login', therest
            when 'exit' then otto.enable_chat false
            when 'leave' then otto.enable_chat false
            when 'part' then otto.enable_chat false
            when 'pause' then if otto.play_state is 'play' then toggle_play.call @
            when 'play' then if otto.play_state is 'pause' then toggle_play.call @
            when 'next' then next_track.call @
            when 'help' then $('.output').append otto.templates.chathelp()
            else $('.output').append otto.templates.chatunknowncommand prefix: prefix, command: command
          $('.output').scrollToBottom()
        else
          @emit 'chat', str

    $('#inputr').first().cmd
      prompt: ->  # empty function supresses the addition of a prompt
      width: '100%'
      elementtobind: $('.console-container')
      commands: chatinput
      onCommandChange: otto.command_change_handler

  otto.enable_chat = (state) =>
    if state and not otto.clientstate.inchat and otto.myusername
      $('.console-container').slideDown(200)
      $('.console-container').focus()
      otto.clientstate.inchat = 1
      @emit 'inchat', 1
      $('body').addClass 'inchat'
    else if not state and otto.clientstate.inchat
      $('.console-container').slideUp(200)
      $('.channelbar-container').focus()
      otto.clientstate.inchat = 0
      @emit 'inchat', 0
      $('body').removeClass 'inchat'
