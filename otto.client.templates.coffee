####
#### client side (body of otto.client.templates.coffee served as /otto.templates.js)
####

# binds to otto.templates (on the client side), not otto.client.templates
# for historical reasons (and brevity)

global.otto.client.templates = ->
  $('head').append '<script src="static/js/coffeecup.js">' if not window['coffeecup']?
  window.otto = window.otto || {}
  window.otto.client = window.otto.client || {}
  window.otto.client.templates = true  # for otto.load_module's benefit

  window.otto.templates = do ->
    templates = {}
    t = otto.t = templates
    ccc = coffeecup.compile
    # you can't reference 'templates' or 't' in the compiled functions scope
    # (i'm guessing because they are 'eval'ed), use otto.templates instead
    add = templates: templates, t: t


    t.body_welcome = ccc ->
      div '#welcome', otto.t.welcome @

    t.body = ccc ->
      nav '.channellist-container', ''
      div '#mainpage', ''
      div '.ouroboros-container', ''
      #div '.footer-container', otto.t.footer()
      div '.cursor-hider', ''

    t.body_reset = ->
      $('.channellist-container').empty()
      $('#mainpage').empty()
      $('.ouroboros-container').empty()
      #$('.footer-container').html otto.t.footer()
      $('.cursor-hider').empty()

    t.welcome = ccc ->
      div '.wecome-container', ->
        div '.welcome', ->
          text otto.t.logo()
          div '.greeting', ->
            div '.hi', 'hello!'
            div '.explain', 'I love to play your music for you, but first I need to scan it'
            div '.explain', 'don\'t worry, I won\'t move it or anything like that'
            br()
            br()
            div '.explain', 'I\'ll scan for music in this folder'
            div ->
              div '.folder', ->
                button '.control.medium2.selectfolder', otto.t.icon 'folder'
                input '#selectFolder', type: 'file', style: 'display: none'  #must match UIDelegate in Otto.py
                span '.path', contenteditable: '', @musicroot
            div '.explain.note', ->
              text '(press '
              button '.control.small.selectfolder.', otto.t.icon 'folder'
              text ' to change this)'
            button '.control.large.wide.loadmusic', 'scan'
      div '.footer-container', ''


    t.initialload = ccc ->
      div '.welcome-container', ->
        div '.welcome', ->
          text otto.t.logo()
        div '.initialload-container', otto.t.cubesloader @


    t.cubeswithload = ccc ->
      div '.cubeswithload-container', otto.t.cubesloader @


    t.cubesloader = ccc ->
      div '.loadingstatus', otto.t.loadingstatuses @
      div '.loadingprogress', ''
      div '.loadingcurrent', ''
      div '.loadingcubes-container', ->
        div '.loadingcubes', ''


    t.loadingstatuses = ccc ->
      div '.status.begin', ->
        button '.control.large.wide.loadmusic2', 'scan'
      div '.status.searching', ->
        div '.loadingspinner', ->
          div otto.t.ouroboros size: 'medium', direction: 'cw', speed: 'fast'
          div '.note', 'searching'
      div '.status.loading', ->
        div '.loadingspinner', ->
          div otto.t.ouroboros size: 'medium', direction: 'cw', speed: 'slow'
          div '.note', 'scanning'
      div '.status.finished', ->
        div ->
          text 'all finished! press '
          button '.control.small.begin', otto.t.icon 'play'
          text ' to begin.'
        button '.control.medium2.begin', otto.t.icon 'play'
      div '.status.nonefound', ->
        div ->
          div 'sorry, I was unable to find any music I can play'
          br()
          if @folder
            div 'in folder ' + @folder
          else
            div 'in that folder'
        br()
        br()
        button '.control.large.wide.restartload', 'restart'
      div '.status.error', ->
        div ->
          text 'sorry, I encountered an error while scanning'
        button '.control.large.wide.begin.continue', 'continue'


    t.cubes = ccc ->
        div '.cubes-container', ->
          div '.landscape-right', ''
          div '.landscape-left', ''
          div '.cubes', ->
            div '.scene', ''
        #div '.resort.control.medium2', otto.t.icon 'cubes'

    t.cubelink = ccc ->
      div '.cubelink.'+@rowclass, 'data-id': @id, title: @title, ->
        div '.cube', style: @style

    t.stacklabel = ccc ->
      div '.stacklabel', style: @style, @letter

    t.countprogress = ccc ->
      if @total or @count
        div '.countprogress-binder', ->
          s = @total
          sizePercent = 100
          progressPercent = Math.min((@count / @total * 100), 100)
          div '.progress-maximum', ->
            div '.progress-container', style: "width: #{sizePercent}%;", ->
              div '.progress', ->
                div '.progress-indicator', style: "width: #{progressPercent}%;", ''
            div '.count-container', otto.t.count_widget(@)


    t.logo = ccc ->
      div '.logo-container', ->
        #span '.logo', ''
        a '.logo', href: 'http://ottoaudiojukebox.com/', target: '_blank', ->

    t.mainpage = ccc ->
      if @channel.layout is 'webcast'
          text otto.t.channelbar channel: @channel
          text otto.t.console()
          text otto.t.webcast()
      else if @channel.layout is 'featured'
          text otto.t.channelbar channel: @channel
          text otto.t.console()
          text otto.t.featured()
      #else if @channel.layout is 'holidays'
        # happy holidays
      else
        text otto.t.channelbar channel: @channel
        text otto.t.login()
        text otto.t.playing @
        text otto.t.thealbum()
        div '.ondeckchattoggle-container', ->
          div '.ondeck-container', ''
          div '.chattoggle-container', ->
            button '.control.medium.chattoggle.shy', {title: 'chat'}, otto.t.icon 'chat'
        text otto.t.console()
        text otto.t.browse @
      #div '.footer-backer', ''


    templates.console = coffeecup.compile ->
      div '.console-container', tabindex: -1, ->
        button '.control.medium.chattoggle.shy', otto.t.icon 'close'
        div '.output-container', ->
          div '.output.scrollkiller', ''
        div '.input-container', ->
          div '.inputl', ->
            #pre '#prompt', ''
            div '#prompt', ''
          div '.inputr-container', ->
            div '#inputr', ->  # must be an id, not class
              div '#terminal', ->
                #textarea '.input', spellcheck: 'false'
                #div '.inputcopy', ''


    t.chathelp = ccc ->
      div '.chathelp', ->
        div '/cls - clear screen'
        div '/next - next track'
        div '/pause - pause playing'
        div '/play - resume playing'
        div '/nick &lt;name&gt; - change username'
        div '/part - leave chat'
        div '/help - show commands'


    t.chatunknowncommand = ccc ->
      div '.chatunknowncommand', ->
        'unknown command ' + @prefix + @command


    t.channelbar = ccc ->
      console.log 'channelbar', @
      div '.channelbar-container.reveal', ->
        div '.channelbar', ->

          div '.channelbar-left', ->
            button '.control.medium.channeltoggle.shy', {title: 'channels'}, otto.t.icon 'menu'

          div '.channelbar-center', ->
            div '.channelname-container', ->
              div '.channelname', @channel.fullname
              div '.hostname', ->
                #host = @host
                #if host and host.indexOf(':') > 0
                #  host = host.substr(0, host.indexOf ':') || @host
                #'http://' + host
                r = /^(http:\/\/)?([^\/]*)/.exec(document.URL)
                host = if r and r.length is 3 then r[2] else ''
                host

            text otto.t.logo()

            div '.topcontrols-container', ->
              #input '#fxtoggle', type: 'checkbox', checked: false
              #label '#fx.shy', for: 'fxtoggle', ->
              #  span 'sound cues'
              button '.control.medium2.soundfxtoggle.shy', {title: 'sound cues'}, otto.t.icon 'soundfx'
              if Notification?
                #input '#notificationstoggle', type: 'checkbox', checked: false
                #label '#notifications.shy', for: 'notificationstoggle', ->
                #  span 'notifications'
                button '.control.medium2.notificationstoggle.shy', {title: 'notifications'}, otto.t.icon 'notifications'

          div '.channelbar-right', ->
            #div '.chattoggle-container', ->
            #  button '.control.medium.chattoggle.shy', otto.t.icon 'chat'

          div '.channelbar-lower', ->
            div '.listeners-container', ''


    templates.webcast = coffeecup.compile ->
      div '#webcast-container', ->
        div '#webcast-background', ->
          img src: '/static/images/8013980828_82a933115b_k.jpg', title: '', alt: ''
        div '#webcast-background-attribution', ->
          a '#webcast-background-link', href: 'http://www.flickr.com/photos/joi/8013980828', target: '_blank',
            "DJ Aaron by Joi Ito"
        div '#webcast-overlay', ->
          div '.autosizeX', 'data-autosize-max': 34, 'data-autosize-min': 19, 'data-autosize-right-margin': 56, ->
            otto.autosize_clear_cache()
            div ->
              span '.webcast-title', "Live Webcast"
            #div '#webcast-compatability', ->
            #  "live broadcast currently works in Chrome and Firefox only"
            div '#webcast-chatpointer', ->
              "there is a chat button in the upper right"


    templates.featuredX = coffeecup.compile ->
      div '#archive-container', ->
        div '#archive-background', ->
          img src: '/static/images/webcast.png', title: '', alt: ''
        div '#archive-background-attribution', ->
          a '#archive-background-link', href: 'https://www.facebook.com/photo.php?fbid=10150666518958461&set=o.406990045995364&type=1&theater', ->
            "photo by [AttributionHere]"
        div '#archive-overlay', ->
          div '.autosize', 'data-autosize-max': 34, 'data-autosize-min': 19, 'data-autosize-right-margin': 56, ->
            otto.autosize_clear_cache()
            div ->
              span '.archive-title', "Archives"


    templates.featured = coffeecup.compile ->
      div '#playlist.featured.reveal', ->


    t.play_widget = ccc ->
      button '#play.control.medium2', {title: 'play/pause'}, otto.t.icon 'play'

    t.next_widget = ccc ->
      button '#next.control.medium2.shy', {title: 'next'}, otto.t.icon 'kill'

    # no longer used
    t.lineout_widget = ccc ->
      input '#lineouttoggle', type: 'checkbox', checked: false
      label '#lineout.shy', for: 'lineouttoggle', ->
        span 'server output'
      text otto.t.volumelineout_widget

    t.volume_widget = ccc ->
      div '.volume-container', {title: 'local volume'}, ->
        div '.volume', ''

    t.volumelineout_widget = ccc ->
      div '.volumelineout-container', {title: 'lineout volume'}, ->
        div '.volumelineout', ''

    t.size_widget = ccc ->
      div '.size-widget.shy', ->
        button '#size.smaller.control.small', {title: 'smaller'}, otto.t.icon 'smaller'
        button '#size.bigger.control.small', {title: 'bigger'}, otto.t.icon 'bigger'

    t.currentsong_widget = ccc ->
      div '.currenttrack.autosize', {
          'data-autosize-max': 34,
          'data-autosize-min': 19,
          'data-autosize-right-margin': 56 }, ->
        otto.autosize_clear_cache()
        if @song
          span '.gotothere', 'data-id': @song._id, ->
            @song.song || 'unknown'
          if otto.myusername
            button '.stars.control.teeny.shy.n0', 'data-id': @song._id

    t.currentalbum_widget = ccc ->
      if @song?.album
        div '.album.gotothere', 'data-id': @song.albums[0]._id, ->
          span @song.album

    t.currentyear_widget = ccc ->
      span '.year', @song?.year or ''

    t.currentartist_widget = ccc ->
      if @song?.artist
        artist_id = @song.artists[0]?._id or 0
        div '.artist.gotothere', 'data-id': artist_id, 'data-albumid': @song.albums[0]._id, ->
          # data-albumid is a hack. see artist->fileunder note in gotothere code
          @song.artist

    t.count_widget = ccc ->
      span '#count', ->
        if @total or @count
          totalstr = "#{@total}"
          countstr = "#{@count}"
          if countstr.length < totalstr.length
            less = totalstr.length - countstr.length
            for i in [1..less]
              countstr = '&nbsp;' + countstr
          span '#current-count', countstr
          span '#total-count.sep', totalstr

    t.time_widget = ccc ->
      span '#time', ->
        if @total or @current
          totalstr = otto.t.format_time @total
          currentstr = otto.t.format_time @current, totalstr.length
          span '#current-time', currentstr
          span '#total-time.sep', totalstr

    t.timeprogress_widgets = ccc ->
      if @total or @current
        div '.timeprogress-binder', ->
          s = @total
          if s < 10   then s = 10
          if s > 3600 then s = 3600
          # fun fact: 2397 = 39:57, longest single to reach the UK charts!
          #x = s / 2397 * 0.58
          #x = s / 3600 * 0.58
          x = s / 3600 * 1.718
          scale = Math.sqrt( Math.log( x+1 ) )
          sizePercent = scale * 100
          progressPercent = Math.min((@current / @total * 100), 100)

          div '.progress-maximum', {title: 'seek'}, ->
            div '.progress-container', style: "width: #{sizePercent}%;", ->
              div '.progress', ->
                div '.progress-indicator', style: "width: #{progressPercent}%;", ''

            div '.time-container', otto.t.time_widget(@)

    t.channel_status_errata_widget = ccc ->
      div '.time-container', ->
        div '.time', ->
          if @status.time
            times = @status.time.split ':'
            text otto.t.time_widget current: times[0], total: times[1]
      #div '.audio', @status.audio || ''
      div '.bitrate', if @status.bitrate then @status.bitrate + 'kbps' else ''


    t.owner_widget = ccc ->
      owner = ''
      if @song? and @song.owners? and @song.owners[0]? and @song.owners[0].owner?
        owner = @song.owners[0].owner
      span '.owner', owner

    t.requestor_widget = ccc ->
      classstr = ''
      if @nodecorations
        if @song?.requestor
          span '.requestor', @song.requestor.split('@')[0]
      else
        if @song? and @song.owners? and @song.owners[0]? and @song.owners[0].owner?
          classstr = '.sep'
        if @song?.requestor
          span classstr, 'requested by '
          span '.requestor', @song.requestor


    t.filename_widget = ccc ->
      if @song?.filename
        span '.filename.shy', @song.filename

    t.currentcover_widget = ccc ->
      if @song
        div '.thumb.px300.gotothere', { 'data-id': @song._id }, ->
          if @song.cover
            img
              height: 300
              width: 300
              #src: "/image/300?id=#{@song.cover}"
              src: "/image/orig?id=#{@song.cover}"
              title: @song.album
          else
            div '.noimg.px300', ->
              div @song.album
              div '.noimgspacer', ''
              div @song.artist
      else
        div '.thumb.px300', {}, ->

    t.enqueue_widget = ccc ->
      button '.enqueue.control.teeny.shy', ''

    t.unqueue_widget = ccc ->
      addtoclassstr = @addtoclassstr || ''
      button '.btn.teeny.control.unqueue'+addtoclassstr, ''

    t.currenttrack = ccc ->
      div '.currenttrack-binder', ->
        div '.currentsong-container', otto.t.currentsong_widget(@)
        div '.timeprogress-container', otto.t.timeprogress_widgets(@)
        div '.currentalbum-container', otto.t.currentalbum_widget(@)
        div '.currentyear-container', otto.t.currentyear_widget(@)
        div '.currentartist-container', otto.t.currentartist_widget(@)
        div '.currenterrata-container', ->
          div '.owner-container', otto.t.owner_widget(@)
          div '.requestor-container', otto.t.requestor_widget(@)
      div '.currentcover-container', otto.t.currentcover_widget(@)
      div '.filename-container', ->
        div '.filename-clipper', otto.t.filename_widget(@)

    t.playing = ccc ->
      div '.playing-container.reveal', ->
        if otto.haslineout and otto.localhost
          div '.play-container', otto.t.play_widget
          div '.shy', otto.t.volumelineout_widget
        else
          #button '#connect.control.large.'+@channel.type, otto.t.icon 'disconnected'
          #button '#connect.control.large.'+@channel.type, ->
          div '.connect-container', ->
            button '#connect.control.large', { title: 'connect/disconnect' }, ->
              #img src: 'static/images/disconnected.svg', height: 20, width: 20
              text otto.t.icon 'connect'
          div '.shy', otto.t.volume_widget

        size = @size || 'size1'
        div ".size-container.#{size}", otto.t.size_widget
        div ".next-container.#{size}", otto.t.next_widget
        div ".currenttrack-container.#{size}", otto.t.currenttrack(@)

    t.thealbum = ccc ->
      div '.thealbum-container.reveal', ->
        ''


    templates.browse = coffeecup.compile ->
      div '.browse-container', ->
        div '.browsecontrols-container', ->
          div '.search-container', ->
            form '#searchform.searchform', method:'get', action:'', ->
              input '#searchtext.searchtext', type:'text', name:'search', placeholder: 'search', autocorrect: 'off', autocapitalize: 'off'
              input '.search_button.buttonless', type:'submit', value:'Search'

          div '.letterbar-container', ->
            ul '.letterbar', ->
              #bigwarning = if @largedatabase then '.warn.big' else ''  # bzzz! not passed in FIXME
              bigwarning = ''
              li '.letter.control.shownewest.gap', {title: 'newest'}, otto.t.icon 'newest'
              li '.letter.control.showall.gap'+bigwarning, {title: 'all'}, otto.t.icon 'all'
              if not @largedatabase  # need to make it faster, times out on very large databases FIXME
                li '.letter.control.showusers.gap', {title: 'users'}, otto.t.icon 'users'
              li '.letter.control.showstars.gap', {title: 'starred'}, otto.t.icon 'star'
              li '.letter.control.showcubes.gap'+bigwarning, {title: 'cubes'}, otto.t.icon 'cubes'
              # other fun character considerations: ⁂ ? № ⁕ ⁖ ⁝ ⁞ ⃛ ⋯ +⚂ ⚐ ⚑
              # someday add back: st va
              li '.letter.gap', 'A'
              for letter in 'B C D E F G H I J K L M N O P Q R S T U V W X Y Z # ⋯'.split(' ')
                if letter is '#'
                  li '.letter', {title: 'numbers'}, letter
                else if letter is '⋯'
                  li '.letter', {title: 'other'}, letter
                else
                  li '.letter', letter
              #li '.letter.gap.warn.beta', '/'
              #li '.letter.showlists.gap', '✓'
        div '.browseresults-container', ''


    t.footer = ccc ->
      div '.logo-container.footer-logo-container', ->
        span '.logo.footer-logo', ''


    templates.login = coffeecup.compile ->
      div '.login-container', ->
        div '.login', ->
          form '#loginform.loginform', method:'get', action:'', ->
            span '.loginlabel', 'To browse and select songs '
            # note the homograph unicode cryillic 'a' in 'email' in the placeholder string
            # this is to keep safari from prompting for an auto fill. sigh.
            input '#logintext.logintext', type:'text', placeholder: 'enter your emаil / username here', autocorrect: 'off', autocapitalize: 'off', autocomplete: 'off', autofill: 'off'
            input '.login_button.buttonless', type:'submit', value:'Search'


    templates.listeners = coffeecup.compile ->
      span '.listeners', ->
        count=0
        othercount=0
        for id in @listeners
          if @listeners[id].socketids or @listeners[id].streams
            #console.log @listeners[id].channelname
            if @listeners[id].channelname and @listeners[id].channelname == otto.mychannel
              count++
            else
              othercount++
        if not count
          label = 'no listeners'
        else
          label = count + ' ' + 'listener' + otto.t.plural(count)
        span '.count', label
        if count
          span '.sep', ''

        first = true
        us = null
        for id in @listeners
          if @listeners[id].socketids or @listeners[id].streams
            for sid of @listeners[id].socketids
              if sid is @socketid
                us = id
        if us and @listeners[us]
          text otto.t.format_listener listener: @listeners[us], first: first, me: true
          first = false
        for id in @listeners
          if id is us
            continue
          if @listeners[id].socketids or @listeners[id].streams
            if @listeners[id].channelname and @listeners[id].channelname == otto.mychannel
              text otto.t.format_listener listener: @listeners[id], first: first, me: false
              first = false

        if othercount
          label = othercount + ' ' + 'other listener' + otto.t.plural(othercount)
          span '', ' | '
          span '.count', label

          for id in @listeners
            if id is us
              continue
            if @listeners[id].socketids or @listeners[id].streams
              if @listeners[id].channelname and @listeners[id].channelname != otto.mychannel
                text otto.t.format_listener listener: @listeners[id], first: first, me: false, showchannel: true
                first = false


    templates.format_listener = coffeecup.compile ->
      name = @listener.user || @listener.host || @listener.address
      if @shortname
        name = name.split('@')[0]
      inchat = no
      typing = no
      focus = no
      idle = yes
      for id of @listener.socketids
        socket = @listener.socketids[id]
        if socket
          inchat = yes if socket.inchat? and socket.inchat
          typing = yes if socket.typing? and socket.typing
          focus  = yes if socket.focus? and socket.focus
          if socket.idle?
            idle = no  if not socket.idle
      if idle
        idle = 1
        for id of @listener.socketids
          socket = @listener.socketids[id]
          if socket
            idle = socket.idle if socket.idle > idle
      classes = ''
      classes += '.streaming' if @listener.streams
      classes += '.inchat' if inchat
      classes += '.typing' if typing
      classes += '.idle' if idle or not focus
      classes += '.thisisme' if @me
      classes += '.sep' if not @first
      title = ''
      title += 'Streaming' if @listener.streams
      if @listener.streams > 1
        title += "X#{@listener.streams}"
      if inchat
        title += ', ' if title != ''
        title += 'In chat' if inchat
      if typing
        title += ', ' if title != ''
        title += 'Typing'
      if idle or not focus
        title += ', ' if title != ''
        if idle
          minutes = Math.floor( (Date.now() - parseInt(idle)) / (60 * 1000) )
          if minutes < 120
            title += "Idle for #{minutes} minutes"
          else
            title += 'Idle since ' + Date(idle).toString()
        else
          title += 'Window not focused'
      if @listener.host || @listener.address  # i guess these are not being set? FIXME
        title += ', ' if title != ''
        title += 'Connected from ' + @listener.host || @listener.address
      div '.listener'+classes, title: title, ->
        text name
        if @showchannel
          span '.channel', ' (' + @listener.channelname + ')'
        if @me
          if @listener.user
            span '.thisisme', ->
              span '.you', '(you)'
              button '.control.small.logout', {title: 'logout'}, otto.t.icon 'logout'


    t.format_listeners_for_channel_in_channelbar = ccc ->
      span '.listeners', ->
        first = true
        for id in @listeners
          if @listeners[id].socketids or @listeners[id].streams
            if @listeners[id].channelname and @listeners[id].channelname == @channelname
              text otto.t.format_listener listener: @listeners[id], first: first, me: false, shortname: true
              first = false


    templates.channellist = coffeecup.compile ->
      div '.channellistheader', ->
        button '.control.medium.channeltoggle', otto.t.icon 'close'
      ul ->
        for i in [1..1]
          for channel in @channellist
            classes = '.changechannel'
            classes = classes + '.currentchannel.open' if channel.name is otto.mychannel
            li classes, 'data-channelname': channel.name, ->
              button '.channelsettings.control.small.shy', {title: 'more info'}, otto.t.icon 'info'
              div '.channelselect', ->
                div '.channelname.autosize', {
                    'data-autosize-max': 20,
                    'data-autosize-min': 12,
                    'data-autosize-right-margin': 0 }, ->
                  otto.autosize_clear_cache()
                  channel.fullname

                div '.channellisteners', ->
                  if @listeners
                    # if we reactive the count we should consider omitting if it's 1
                    #span '.listeners.count', count || ''
                    text otto.t.format_listeners_for_channel_in_channelbar listeners: @listeners, channelname: channel.name
              button '.channeloutput.control.small.shy', {title: 'toggle lineout'}, otto.t.icon 'output'
              div '.settings', ->
                #button '.channelsettings.control.small', otto.t.icon 'close'
                button '.channelplay.control.medium2', {title: 'play/pause'}, otto.t.icon 'play'
                text otto.t.volumelineout_widget()
                div '.channelerrata-container', ''
                #button '.channelfork.control.small', {title: 'fork'}, otto.t.icon 'fork'

                button '.crossfade.control.small', {title: 'crossfade'}, 'CF'
                button '.replaygain.control.small', {title: 'replay gain'}, 'RG'


    templates.page_it_out = (items, pagesize, lazychunksize, element, render) ->
      pages = 0
      pagestart = 0
      # someday we should get clever here about not making pages with too few items
      # we could also consider waiting to construct pages until they are scrolled to
      while pagestart < items.length
        pageitems = items.slice(pagestart, pagestart+pagesize)
        chunkstart = 0
        # further break the page into chunks to make it easier for lazyload searching
        element '.page', ->
          while chunkstart < pageitems.length
            element '.lazychunk', ->
              chunk = pageitems.slice(chunkstart, chunkstart+lazychunksize)
              for item in chunk
                # call the supplied render routine on each item
                render item
              chunkstart += lazychunksize
        pagestart += pagesize
        pages += 1


    templates.startswith = coffeecup.compile ->
      empty = true
      otto.t.page_it_out @data, 200, 10, div, (item) ->
        empty = false
        text otto.t.artist item: item

      if empty
        div '.none', 'Nothing filed under ' + @params.value


    templates.allalbums = coffeecup.compile ->
      div '.thumbnails', ->
        empty = true
        otto.t.page_it_out @data, 300, 100, span, (album) ->
          empty = false
          div '.albumall', ->
            div '.thumb.px120.expand', 'data-id': album._id, ->
              if album.cover
                img '.albumimg.lazy', height: 120, width: 120, \
                    #src: 'static/images/gray.gif', \
                    #src: 'data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==', \
                    #src: 'static/images/clear.gif', \
                    src: 'static/images/clear.png', \
                    'data-original': "/image/120?id=#{album.cover}", \
                    title: album.album
              else
                album_div_text = album.album
                if album.fileunder?
                  if album.fileunder[0]?
                    if album.fileunder[0].name?
                      album_div_text += '<br>' + album.fileunder[0].name
                if album.owners?
                  if album.owners[0]?
                    if album.owners[0].owner?
                      album_div_text += '<br>' + album.owners[0].owner
                if album.year?
                  album_div_text += '<br>' + album.year
                div '.noimg.px120', -> album_div_text
#                 div '.noimg.px120', -> album.album + '<br>' + album.fileunder[0].name + '<br>' + album.owners[0].owner + '<br>' + album.year #+ album.genre
            if otto.myusername
              button '.stars.control.teeny.shy.n0', 'data-id': album._id

        if empty
          div '.none', 'No albums loaded'


    templates.artist = coffeecup.compile ->
      div '.artistlist', ->
        if not @nostars
          if otto.myusername
            button '.stars.control.teeny.shy.n0', 'data-id': @item._id
        div '.artistname-container', ->
          span '.artistname.expand', {'data-id': @item._id }, @item.name # was @item.artist before fileunder
          ul '.thumbnails', ->
            if @item.albums?
              albumorder = otto.t.orderalbums @item.albums
              for album in albumorder
                li '.h.thumb.px40.expand', 'data-id': album._id, 'data-container': @item._id, ->
                  if album.cover
                    img '.albumimg.lazy', src: 'static/images/clear.png', height: 40, width: 40, 'data-original': "/image/40?id=#{album.cover}", title: album.album
                  else
                    div '.noimg.px40', -> album.album


    templates.album = coffeecup.compile ->
      expand = if @noexpand then '' else '.expand'
      div '.albumlist', ->
        div '.thumbnails', ->
          div '.thumb.px40'+expand, 'data-id': @item._id, 'data-container': @item._id, ->
            if @item.cover
              if @nolazy
                img '.albumimg', src: "/image/40?id=#{@item.cover}", height: 40, width: 40, title: @item.album
              else
                img '.albumimg.lazy', src: 'static/images/clear.png', height: 40, width: 40, 'data-original': "/image/40?id=#{@item.cover}", title: @item.album
            else
               div '.noimg.px40', -> @item.album
        span '.albumname'+expand, 'data-id': @item._id, ->
          artistinfo = otto.compute_artistinfo @item
          span @item.album
          if artistinfo.single
            span '.artist.sep', artistinfo.single
          if @item.year?
            span '.sep', @item.year
          if otto.myusername and not @nostars
            button '.stars.control.teeny.shy.n0', 'data-id': @item._id


    templates.orderalbums = (albums) ->
      albumorder = []
      variousorder = []
      for album in albums
        if not album.artistinfo?
          album.artistinfo = otto.compute_artistinfo album
        if album.artistinfo.various
          variousorder.push album
        else
          albumorder.push album

      sorter = (a, b) ->
        #if a.songs?[0]?.year? and b.songs?[0].year?
        if a.year? and b.year?
          ayear = Number(a.year)
          byear = Number(b.year)
          if ayear < byear
            return -1
          else if ayear > byear
            return 1
          else
            if a.album? and b.album?
              return a.album.localeCompare b.album, {sensitivity: "base", numeric: true}
            else if a.album?
              return -1
            else if b.album?
              return 1
            else return 0
        else if a.year?
          return -1
        else if b.year?
          return 1
        else
          if a.album? and b.album?
            return a.album.localeCompare b.album, {sensitivity: "base", numeric: true}
          else if a.album?
            return -1
          else if b.album?
            return 1
          else return 0

      albumorder.sort(sorter)
      variousorder.sort(sorter)

      return albumorder.concat(variousorder)


    templates.albums_details = coffeecup.compile ->
      div '.albumlist-container', { 'data-id': @_id }, ->
        button '.close.control.tiny.shy', otto.t.icon 'close'
        #if @data.length > 1
        button '.close.lower.control.tiny.shy', otto.t.icon 'close'
        div '.albumlist', ->
          albumorder = otto.t.orderalbums @data
          had_various = false
          had_nonvarious = false
          for album in albumorder
            if album.artistinfo.various
              if had_nonvarious and not had_various
                div '.varioussep', ''
              had_various = true
            else
              had_nonvarious = true
            text otto.t.album_details album: album, fileunder: @fileunder


    templates.album_details = coffeecup.compile ->
      if not @album.artistinfo?
        @album.artistinfo = otto.compute_artistinfo @album
      div '.albumdetails', ->
        div '.albumcover-container', ->
          if @album.cover
            div '.thumb.px200', ->
              #img src: "/image/300?id=#{@album.cover}", alt: @album.album, title: @album.album
              img src: "/image/orig?id=#{@album.cover}", alt: @album.album, title: @album.album
          else
            div '.noimg.px200', ->
              if @album.artistinfo.various
                span @album.artistinfo.various
              else
                for artist in @album.artistinfo.all
                  span -> artist
              br()
              span @album.album

          div '.stars-container', ->
            if otto.myusername
              button '.stars.control.teeny.shy.n0', 'data-id': @album._id
          div '.year-container', ->
            if @album.years?
              format_years = @album.years[0]
              for year in @album.years[1..]
                format_years += ', '+year
              div '.year', format_years
            else if @album.year?
              div '.year', @album.year

        div '.albuminfo', ->
          div '.album', ->
            span ".id#{@album._id}", 'data-id': @album._id,  ->
              span @album.album
              if otto.myusername
                button '.stars.control.teeny.shy.n0', 'data-id': @album._id
          if @album.artistinfo.various
            div '.artist', @album.artistinfo.various
          else
            for artist in @album.artistinfo.all
              div '.artist', -> artist
          if @album.owners?[0]?.owner
            div '.owner', -> @album.owners[0].owner

          div '.albumsongs.cf', ->
            table ->
              for song in @album.songs
                tr -> td ->
                  text otto.t.enqueue_widget()
                  span ".id#{song._id}", {'data-id': song._id}, song.song
                  if @album.artistinfo.various or song.artist is not @album.artistinfo.primary
                    # this doesn't work when the fileunder name has been transformed in any way FIXME
                    if @album.artistinfo.various and @fileunder and song.artist is @fileunder.name
                      span '.subartist.highlight.sepgray', song.artist
                    else
                      span '.subartist.sep', song.artist
                  if otto.myusername
                    button '.stars.control.teeny.shy.n0', 'data-id': song._id
                    #button '.stars.control.teeny.shy.n0', {'data-id': song._id}, otto.t.icon 'star'
                  span '.time.sep.shy', otto.t.format_time(song.length)

        div '.albumdir.dirpath.shy', ->
           @album.dirpath


    templates.ondeck = coffeecup.compile ->
      table '.ondeck', ->
        # the rest of the queue, on deck
        for song in @songs
          tr ->
            td '.requestor-container', otto.t.requestor_widget( song: song, nodecorations: true )
            td ->
              text otto.t.unqueue_widget( addtoclassstr: '.shy' )
              addtoclassstr = ''
              if song.requestor
                addtoclassstr='.requested'
              span ".song.id#{song._id}#{addtoclassstr}", { 'data-id': song._id, 'data-mpdqueueid': song.mpdqueueid }, song.song
              span '.album.sep', song.album
              span '.artist.sep', song.artist
              span '.sep', otto.t.format_time(song.length)
              span '.shy', ->
                if song.owners
                  owner = song.owners[0].owner
                else
                  owner = ''
                span '.owner.sep', -> owner
                span '.filename.sep', -> song.filename


    templates.featured = coffeecup.compile ->
      ul '.ondeck', ->
        # the rest of the queue, on deck
        for song, n in @songs
          li ->
            if song.requestor
              span '.requestor', ->
                div -> song.requestor
            else
              span '.requestor', -> ''
            if song.nowplaying
              span '.playing.control.teeny', otto.t.icon 'play'
              span '.song.currenttrack', -> song.song
            else
              button '.play.control.teeny.shy', id: song.mpdqueueid, 'data-position': n, ->
                text otto.t.icon 'play'
              span '.song', song.song
            span '.album.sep', song.album
            span '.artist.sep', song.artist
            span '.sep', otto.t.format_time(song.length)
            span '.shy', ->
              if song.owners
                owner = song.owners[0].owner
              else
                owner = ''
              span '.owner.sep', -> owner
              span '.filename.sep', -> song.filename


    templates.alert = coffeecup.compile ->
      div class: 'alert alert-info', ->
        span @message
        br()
        br()
        button '#ok.runself.control.large', 'ok'
        text ' &nbsp; '
        button '#cancel.runself.control.large', 'cancel'


    templates.search = coffeecup.compile ->
      div '.search', ->
        if not @data.fileunders.length and not @data.albums.length and not @data.songs.length
          div class: 'noresults'
        else

          if @data.fileunders.length
            div class: 'section', 'Artists'
            div ->
              for fileunder in @data.fileunders
                #li -> fileunder.name
                div -> otto.t.artist item: fileunder

          if @data.albums.length
            div class: 'section', 'Albums'
            div class: 'albums', ->
              for album in @data.albums
                div -> otto.t.album item: album

          if @data.songcomposers? and @data.songcomposers.length
            div '.section', 'Composers'
            ul class: 'songs', ->
              for song in @data.songcomposers
                filename = song.filename
                li ->
                  button '.enqueue.control.teeny.shy', 'data-oid': song.oid
                  composers = ''
                  if song.tags['©wrt']
                    composers = song.tags['©wrt']
                    composers = composers.replace /^\[u\'/, ''
                    composers = composers.replace /\'\]$/, ''
                  if song.tags['TCOM']
                    if composers
                      composers = composers + ', '
                    composers = song.tags['TCOM']
                  span "[#{composers}] &nbsp;"
                  span id: song.oid, class: 'song', -> song.song
                  span class: 'sep'
                  span class: 'album', -> song.album
                  span class: 'sep'
                  span class: 'artist', -> song.artist
                  if otto.myusername
                    button '.stars.control.teeny.shy.n0', 'data-oid': song.oid
                  span class: 'shy', ->
                    span class: 'sep'
                    span -> otto.t.format_time(song.length)
                    if song.owners
                      owner = song.owners[0].owner
                    else
                      owner = ''
                    span class: 'sep'
                    span class: 'queue owner', -> owner
                    span class: 'sep'
                    span class: 'queue filename', -> filename

          songs_list = {}
          if @data.songs.length
            div class: 'section', 'Songs'
            ul class: 'songs', ->
              for song in @data.songs
                songs_list[song._id] = true
                li ->
                  text otto.t.enqueue_widget()
                  span ".song.id#{song._id}", { 'data-id': song._id }, song.song
                  span '.album.sep', song.album
                  span '.artist.sep', song.artist
                  if otto.myusername
                    button '.stars.control.teeny.shy.n0', 'data-id': song._id
                  span class: 'shy', ->
                    span class: 'sep'
                    span -> otto.t.format_time(song.length)
                    owner = ''
                    if song.owners
                      owner = song.owners[0].owner
                    span '.owner.sep', owner
                    span '.filename.sep', song.filename
          other_cleaned = []
          if @data.other
            for song in @data.other
                if songs_list[song._id]
                    continue
                other_cleaned.push(song)

            if other_cleaned.length
              div 'Other'
              ul class: 'my-new-list', ->
                for song in other_cleaned
                  li ->
                    text otto.t.enqueue_widget()
                    span ".id#{song._id}", { 'data-id': song._id }, song.song
                    span '.sep', song.album
                    span '.sep', song.artist
                    if otto.myusername
                      button '.stars.control.teeny.shy.n0', 'data-id': song._id
                    span '.filename.sep.shy', song.filename


    templates.newest_albums = coffeecup.compile ->
      div '.search', ->
        div '.section', 'Newest Albums'
        empty = true
        lasttimestamp = false
        div '.albums', ->
          owner = ''
          for album in @data
            empty = false

            if lasttimestamp
              interval = lasttimestamp - album.timestamp
            else
              interval = 0
            lasttimestamp = album.timestamp

            if album.owners?
              if owner isnt album.owners[-1..][0].owner
                owner = album.owners[-1..][0].owner
                div '.newestowner', owner + ' &nbsp; ' + otto.t.format_timestamp(album.timestamp)
              else if interval > 3600000
                div '.newestowner', owner + ' &nbsp; ' + otto.t.format_timestamp(album.timestamp)
            else if owner
              owner = ''
              div '.newestowner', '' + otto.t.format_timestamp(album.timestamp)
            else if interval > 3600000
              div '.newestowner', owner + ' &nbsp; ' + otto.t.format_timestamp(album.timestamp)
            div -> otto.t.album item: album


        if empty
          div '.none', 'None'


    otto.event_last_display_time = false
    templates.event = coffeecup.compile ->
      div '.event', ->
        timestamp = new Date(@event.timestamp)
        display_time = otto.t.format_time(timestamp.getHours() * 60 + timestamp.getMinutes(), 5)
        if display_time isnt otto.event_last_display_time
          span '.timestamp', display_time
          otto.event_last_display_time = display_time
        else
          span '.timestamp', ''
        #span class: 'id', -> @event.id
        if @event.user
          short_username = @event.user.split('@')[0]
          span '.user', -> short_username
        #span '.channel', -> @event.channel
        if @event.message?
          if otto.showdown_converter?
            message_markeddown = otto.showdown_converter.makeHtml(@event.message)
          else
            message_markeddown = @event.message
          span '.message', message_markeddown
          #text message_markeddown
        else
          span '.name', -> @event.name


    templates.event_text = (event) ->
      text = ""
      if event.user
        short_username = event.user.split('@')[0]
      else
        short_username = 'unknown'
      text += short_username + '  '
      #text += event.channel
      if event.message?
        #if otto.showdown_converter?
        #  message_markeddown = otto.showdown_converter.makeHtml(@event.message)
        #else
        #  message_markeddown = @event.message
        #text += message_markeddown
        text += event.message
      else
        text += event.name


    templates.loader = coffeecup.compile ->
      div class: 'event loader', ->
        span class: 'message', "scan: #{@event}"


    templates.show_users = coffeecup.compile ->
      div '.userlist', ->
        empty = true
        if @data
          table ->
            for user in @data
              empty = false
              tr '.section', ->
                td '.owner', user.owner
                td if user.songs   then "#{user.songs} song" + otto.t.plural(user.songs)
                td if user.albums  then "#{user.albums} album" + otto.t.plural(user.albums)
                td if user.artists then "#{user.artists} artist" + otto.t.plural(user.artists)
                td "#{user.stars} starred item" + otto.t.plural(user.stars)

        if empty
          div '.none', 'None'


    templates.show_stars = coffeecup.compile ->
      div '.starslist', ->
        nostar = true
        if @data
          for user of @data
            starlist = []
            for staritem in @data[user]
              if staritem.rank > 0
                starlist.push staritem
            if starlist and starlist.length
              nostar = false
              div ' '
              div '.section', ->
                span user
                span '.sep', ->
                  span starlist.length.toString() + ' item' + otto.t.plural(starlist.length)
                  if otto.myusername
                    span class: 'shy', -> button class: 'download btn teeny control', 'data-id': user._id, -> i class: 'download-alt'

            div '.songs', ->  # .songs? that isn't good FIXME
              if starlist and starlist.length
                for item in starlist
                  switch item.otype
                    when 40 then addclass = '.starredartist'
                    when 20 then addclass = '.starredalbum'
                    else addclass = '.starredsong'
                  div '.starreditem'+addclass, ->
                    if otto.myusername and user is otto.myusername
                      button '.stars.control.teeny.shy.n0', 'data-id': item._id
                    else
                      button ".stars.control.teeny.n#{item.rank}.immutable.noupdate", 'data-id': item._id
                    if item.otype == 40
                      text otto.t.artist item: item, nostars: true
                    else if item.otype == 20
                      text otto.t.album item: item, nostars: true
                    else
                      song = item
                      text otto.t.enqueue_widget()
                      span ".song.id#{song._id}", { 'data-id': song._id }, song.song
                      span '.album.sep', song.album
                      span '.artist.sep', song.artist
                      span '.sep.shy', otto.t.format_time(song.length)
                      if song.owners
                        owner = song.owners[0].owner
                        span '.owner.sep.shy', owner
                      span '.filename.sep.shy', song.filename

        if nostar
          div '.nostars', 'Nothing starred yet'


    templates.dirbrowser = coffeecup.compile ->
      div '.dirbrowser', ->
        ul '.path'
        div '.subdirs'
        div '.contents'


    templates.dirbrowser_subdir = coffeecup.compile ->
      ul ->
        for dir in @data.dirs
          li class: 'subdir', id: dir._id, 'data-filename': dir.filename, ->
            dir.filename+'/'


    templates.dirbrowser_item = coffeecup.compile ->
      for dir in @data
        li class: 'path', id: dir._id, -> dir.filename+'/'


    templates.ouroboros = coffeecup.compile ->
      div '.ouroboros', ->
        modifiers = ''
        modifiers += '.' + (@size       || 'medium') # small, medium, large
        modifiers += '.' + (@speed      || 'normal') # slow, normal, fast
        modifiers += '.' + (@direction  || 'cw')     # cw, ccw
        modifiers += '.' + (@color      || 'gray')   # gray, blue
        modifiers += '.' + (@background || 'dark')   # dark, black
        div ".ui-spinner#{modifiers}", ->
          span '.side.left', ->
            span '.fill', ''
          span '.side.right', ->
            span '.fill', ''


    t.format_time = (seconds, minlen=4) ->
      hours = parseInt(seconds / 3600)
      seconds = seconds % 3600
      minutes = parseInt(seconds / 60)
      seconds = parseInt(seconds % 60)
      if seconds < 10
        seconds = '0' + seconds
      else
        seconds = '' + seconds
      if minutes < 10 and (hours > 0 or minlen > 4)
        minutes = '0' + minutes
      else
        minutes = '' + minutes
      formatted = ''
      if hours or minlen > 6
        formatted = "#{hours}:#{minutes}:#{seconds}"
      else
        formatted = "#{minutes}:#{seconds}"


    t.format_timestamp = (timestamp) ->
      if timestamp
        #d = new Date(timestamp * 1000)
        #hours = d.getHours();
        #minutes = d.getMinutes();
        #seconds = d.getSeconds();
        #day = d.getDate()
        #month = d.getMonth()
        #return moment(timestamp).fromNow()  # i like this one
        return moment(timestamp).format('ddd MMM Do YYYY ha')
      else
        return ''


    templates.icon = coffeecup.compile ->
      switch String @
        when 'play'         then span '.icon-play2', ''
        when 'connect'      then span '.icon-play', ''
        when 'pause'        then span '.icon-pause', ''
        #when 'kill'         then span '.icon-remove', ''
        when 'kill'         then span '.icon-minus', ''
        when 'menu'         then span '.icon-menu', ''
        when 'chat'         then span '.icon-bubble2', ''
        when 'bigger'       then span '.icon-zoomin', ''
        when 'smaller'      then span '.icon-zoomout', ''
        when 'newest'       then span '.icon-download', ''
        when 'all'          then span '.icon-grid', ''
        when 'star'         then span '.icon-star', ''
        when 'users'        then span '.icon-users', ''
        when 'cubes'        then span '.icon-stack2', ''
        when 'close'        then span '.icon-close', ''
        when 'enqueue'      then span '.icon-plus', ''
        when 'unqueue'      then span '.icon-minus', ''
        when 'logout'       then span '.icon-cancel-circle', ''
        when 'fork'         then span '.icon-fork', ''
        when 'tag'          then span '.icon-tag', ''
        when 'tags'         then span '.icon-tags', ''
        #when 'output'       then span '.icon-volume-medium', ''
        when 'output'       then span '.icon-volume-mute', ''
        when 'outputmute'   then span '.icon-volume-mute2', ''
        when 'outputsel'    then span '.icon-volume-mute', ''
        when 'notifications' then span '.icon-bubble3', ''
        when 'soundfx'      then span '.icon-lightning', ''
        when 'folder'       then span '.icon-folder-open', ''
        when 'info'         then span '.icon-info', ''
        else                     span '.icon-blocked', ''


    t.plural = (count, single, plural) ->
      return if count is 1 then single || '' else plural || 's'


    console.log 'templates defined'
    return templates
