###############
### client side (otto.client.templates.coffee served as /otto.templates.js)
###############

# binds to otto.templates on the client side, not otto.client.templates
# for historical reasons (and brevity)

global.otto.client.templates = ->
  if not window['coffeecup']
    $('head').append '<script src="static/js/coffeecup.js">'
  window.otto = window.otto || {}
  window.otto.client = window.otto.client || {}
  window.otto.client.templates = true  # for otto.load_module's benefit
  window.otto.templates = do ->
    templates = {}
    # you can't reference 'templates' in the compiled functions scope
    # (i'm guessing because they are 'eval'ed), use otto.templates instead


    templates.body = coffeecup.compile ->
      nav '#channellist', ''
      div '#mainpage', ''


    templates.mainpage = coffeecup.compile ->
      if @channel.layout is 'webcast'
          div '.channelbarconsole-container', ->
            text otto.templates.channelbar channel: @channel
            text otto.templates.console()
          text otto.templates.webcast()
      else if @channel.layout is 'featured'
          div '.channelbarconsole-container', ->
            text otto.templates.channelbar channel: @channel
            text otto.templates.console()
          text otto.templates.featured()
      #else if @channel.layout is 'holidays'  # happy holidays
      else
        div '.channelbarconsole-container', ->
          text otto.templates.channelbar channel: @channel
          text otto.templates.console()
        text otto.templates.playlist()
        if otto.myusername
          text otto.templates.browsebar()
        else
          text otto.templates.login()
        div '#results', ''
        div '#footer', ''


    templates.console = coffeecup.compile ->
      div '#console', tabindex: -1, ->
        div '#outputdiv', ->
          div '#output.scrollkiller', ''
        div '#inputdiv', ->
          div '#inputl', ->
            pre '#prompt', ''
          div '.inputrdiv', ->
            div '#inputr', ->
              div '#terminal', ->
                #textarea '#input', spellcheck: 'false'
                #div '#inputcopy', ''


    templates.channelbar = coffeecup.compile ->
      console.log 'channelbar', @
      div '.channelbar-container.reveal', ->
        div '.channelbar', ->

          div '.channelbar-left', ->
            button '.control.medium.channeltoggle.shy', ->
              span 'data-icon': '&#xe005;', 'aria-hidden': 'true'  # menu

          div '.channelbar-center', ->
            div '.channelname-container', ->
              div '#channelname', @channel.fullname
              div '#hostname', ->
                #host = @host
                #if host and host.indexOf(':') > 0
                #  host = host.substr(0, host.indexOf ':') || @host
                #'http://' + host
                r = /^(http:\/\/)?([^\/]*)/.exec(document.URL)
                host = if r and r.length is 3 then r[2] else ''
                host
            div '.maincontrols-container', ->
              div '.maincontrols', ->
                div '.maincontrols-left', ->
                  div '.volumebar-container', ->
                    div '#volumebar.shy', ''
                div '.maincontrols-center', ->
                  #button '#connect.control.large.'+@channel.type, otto.templates.icon 'disconnected'
                  button '#connect.control.large.'+@channel.type, ->
                    img src: 'static/images/disconnected.svg', height: 20, width: 20
                div '.maincontrols-right', ->
                  input '#fxtoggle', type: 'checkbox', checked: false
                  label '#fx.shy', for: 'fxtoggle', ->
                    span 'sound cues'
                  if Notification?
                    input '#notificationstoggle', type: 'checkbox', checked: false
                    label '#notifications.shy', for: 'notificationstoggle', ->
                      span 'notifications'
            div '.logo-container', ->
              span '.logo', ''

          div '.channelbar-right', ->
            div '.chattoggle-container', ->
              button '.control.medium.chattoggle.shy', ->
                span 'data-icon': '&#xe008;', 'aria-hidden': 'true'  # console
            div '.ouroboros-container', ''
            #div '.settingstoggle-container', ->
            #  button '.control.medium.settingstoggle.shy', ->
            #    span 'data-icon': '&#xe017;', 'aria-hidden': 'true'  # console

          div '.channelbar-lower', ->
            div '.listeners-container', ->
              div '.listeners-clipper', ->
                div '#listeners', ''


    templates.webcast = coffeecup.compile ->
      div '#webcast-container', ->
        div '#webcast-background', ->
          img src: '/static/images/8013980828_82a933115b_k.jpg', title: '', alt: ''
        div '#webcast-background-attribution', ->
          a '#webcast-background-link', href: 'http://www.flickr.com/photos/joi/8013980828', target: '_blank',
            "DJ Aaron by Joi Ito"
        div '#webcast-overlay', ->
          div '.autosizeX', ->
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
          div '.autosize', ->
            div ->
              span '.archive-title', "Archives"


    templates.featured = coffeecup.compile ->
      div '#playlist.featured.reveal', ->
        table '.nowplayingcontainer.queue', ->
          tr ->
            td '.nowplayingcover-container', ''
            td '.nowplaying', ->
              div '#currenttrack-container', ''
              div '#currenttrack-errata', ''

        div '#ondeck.ondeck-container.scrollkiller.featured', ''


    templates.nowplaying_controls = coffeecup.compile ->
      #button '#play.control.large', otto.templates.icon 'play'
      #button '#next.control.large', otto.templates.icon 'next'
      button '#play.control.medium2', otto.templates.icon 'play'
      button '#next.control.medium2.shy', otto.templates.icon 'kill'
      if otto.haslineout
        input '#lineouttoggle', type: 'checkbox', checked: false
        label '#lineout.shy', for: 'lineouttoggle', ->
          span 'line out'
        div '.volumebar-lineout-container', ->
          div '#volumebar-lineout.shy', ''


    templates.playlist = coffeecup.compile ->
      classes = ''
      #if otto.current_channel.layout is 'featured'
      #  classes += '.featured'
      div '#playlist.reveal'+classes, ->
        table '.nowplayingcontainer.queue', ->
          tr ->
            td '.nowplayingcover-container', ''
            td '.nowplaying', ->
              div '.nowplaying-controls', otto.templates.nowplaying_controls()
              div '#currenttrack-container', ''
              #br()
              div '#currenttrack-errata', ''

        div '#ondeck.ondeck-container.scrollkiller', ''


    templates.browsebar = coffeecup.compile ->
      div '#browsebar', ->
        div '.browsebar-container', ->
          div '.search-container', ->
            form '#searchform.searchform', method:'get', action:'', ->
              input '#searchtext.searchtext', type:'text', name:'search', placeholder: 'search', autocorrect: 'off', autocapitalize: 'off'
              input '.search_button.buttonless', type:'submit', value:'Search'

          div '.letterbar-container', ->
            ul '.letterbar', ->
              li '.letter.control.shownewest.gap', '&nbsp;&nbsp;'
              if @large_database
                li '.letter.control.showall.warn.big.gap', '&nbsp;&nbsp;'
              else
                li '.letter.control.showall.gap', '&nbsp;&nbsp;'
              # other fun character considerations: ⁂ ? № ⁕ ⁖ ⁝ ⁞ ⃛ ⋯ +
              # someday add back: st va
              li '.letter.gap', 'A'
              for letter in 'B C D E F G H I J K L M N O P Q R S T U V W X Y Z # ⋯'.split(' ')
                li '.letter', letter
              li '.letter.control.showstars.gap', ''
              li '.letter.control.showowners.gap', '&nbsp;&nbsp;'
              if @large_database
                li '.letter.control.showcubes.warn.gap.big', '&nbsp;&nbsp;'
              else
                li '.letter.control.showcubes.gap', '&nbsp;&nbsp;'
              #li '.letter.gap.warn.beta', '/'
              #li '.letter.showlists.gap', '✓'


    templates.login = coffeecup.compile ->
      div '#login', ->
        div '.login-container', ->
          form '#loginform.loginform', method:'get', action:'', ->
            span '.loginlabel', 'To browse and select songs '
            input '#logintext.logintext', type:'text', name:'login', placeholder: 'enter your name here', autocorrect: 'off', autocapitalize: 'off'
            input '.login_button.buttonless', type:'submit', value:'Search'


    templates.listeners = coffeecup.compile ->
      span '.listeners', ->
        count=0
        for id in @listeners
          if @listeners[id].socketids.length > 0 or @listeners[id].streams
            count++
        if not count
          label = 'no listeners'
        else if count == 1
          label = count + ' ' + 'listener'
        else
          label = count + ' ' + 'listeners'
        span class: 'count', label
        if count
          span class: 'sep'

        first = true
        us = null
        for id in @listeners
          if @listeners[id].socketids.length > 0 or @listeners[id].streams
            for sid in @listeners[id].socketids
              if sid is @socketid
                us = id
        if us and @listeners[us]
          text otto.templates.format_listener listener: @listeners[us], first: first, me: true
          first = false
        for id in @listeners
          if id is us
            continue
          if @listeners[id].socketids.length > 0 or @listeners[id].streams
            text otto.templates.format_listener listener: @listeners[id], first: first, me: false
            first = false


    templates.format_listener = coffeecup.compile ->
      console.log @listener
      name = @listener.user
      if not name
        name = @listener.host
      if not name
        name = @listener.address
      inchat = no
      typing = no
      focus = no
      idle = yes
      for id in @listener.socketids
        socket = @listener.socketids[id]
        if socket
          inchat = yes if socket.inchat? and socket.inchat
          typing = yes if socket.typing? and socket.typing
          focus  = yes if socket.focus? and socket.focus
          if socket.idle?
            idle = no  if not socket.idle
      if idle
        idle = 1
        for id in @listener.socketids
          socket = @listener.socketids[id]
          if socket
            idle = socket.idle if socket.idle > idle
      classes = 'listener'
      classes += ' streaming' if @listener.streams
      classes += ' inchat' if inchat
      classes += ' typing' if typing
      classes += ' idle' if idle or not focus
      classes += ' thisisme' if @me
      classes += ' sep' if not @first
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
          title += 'Idle since ' + Date(idle).toString()
        else
          title += 'Window not focused'
      span class: classes, title: title, ->
        text name
        if @me
          if @listener.user
            span '.thisisme', ->
              span '.you', '(you)'
              button '.control.small.logout', title: 'logout', ->
                span 'data-icon': '&#xe085;', 'aria-hidden': 'true'  # menu


    templates.channellist = coffeecup.compile ->
      div '#channellistheader', ->
        button '.control.medium.channeltoggle', ->
          span 'data-icon': '&#xe005;', 'aria-hidden': 'true'  # menu
      ul ->
        for i in [1..1]
          for channel in @channellist
            classes = '.changechannel'
            classes = classes + '.currentchannel' if channel.name is otto.mychannelname
            li classes, 'data-channelname': channel.name, ->
              span '.channelselect', channel.fullname
              button '.channelsettings.control.small.shy', ->
                span 'data-icon': '&#xe06f;', 'aria-hidden': 'true'  # menu
              button '.channelfork.control.small.shy', ->
                span 'data-icon': '&#xe02d;', 'aria-hidden': 'true'  # menu


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
      otto.templates.page_it_out @data, 200, 10, div, (item) ->
        text otto.templates.artist item: item


    templates.allalbums = coffeecup.compile ->
      div '.thumbnails', ->
        otto.templates.page_it_out @data, 300, 100, span, (album) ->
          div '.albumall', ->
            div '.thumb.px120.expand', 'data-oid': album._id, ->
              if album.cover
                img '.albumimg.lazy', height: 120, width: 120, \
                    src: 'static/images/gray.gif', \
                    'data-original': "/image/120?id=#{album.cover}", \
                    title: album.album
              else
                 div '.noimg.px120', -> album.album + '<br>' + album.fileunder[0].name + '<br>' + album.owners[0].owner + '<br>' + album.year #+ album.genre
            if otto.myusername
              button '.stars.control.teeny.shy.n0', 'data-oid': album._id


    templates.artist = coffeecup.compile ->
      div '.artistlist', ->
        if otto.myusername
          button '.stars.control.teeny.shy.n0', 'data-oid': @item._id
        span '.artistname.expand', {'data-oid': @item._id }, @item.name # was @item.artist before fileunder
        ul '.thumbnails', ->
          if @item.albums?
            albumorder = otto.templates.orderalbums @item.albums
            for album in albumorder
              li '.h.thumb.px40.expand', 'data-oid': album._id, 'data-container': @item._id, ->
                if album.cover
                  img '.albumimg.lazy', src: 'static/images/gray.gif', height: 40, width: 40, 'data-original': "/image/40?id=#{album.cover}", title: album.album
                else
                  div '.noimg.px40', -> album.album
        div id: @item._id  # we don't really need this, do we?


    templates.album = coffeecup.compile ->
      div '.albumlist', ->
        div '.thumbnails', ->
          div '.thumb.px40.expand', 'data-oid': @item._id, 'data-container': @item._id, ->
            if @item.cover
              img '.albumimg.lazy', src: 'static/images/gray.gif', height: 40, width: 40, 'data-original': "/image/40?id=#{@item.cover}", title: @item.album
            else
               div '.noimg.px40', -> @item.album
        span '.albumname.expand', 'data-oid': @item._id, ->
          artistinfo = otto.compute_artistinfo @item
          span '&nbsp;&nbsp;'
          span @item.album
          if artistinfo.single
            span '.artist.sep', artistinfo.single
          if @item.year?
            span '.sep', @item.year
          if otto.myusername
            button '.stars.control.teeny.shy.n0', 'data-oid': @item._id
        div id: @item._id


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
      div '.albumlist-container', { 'data-oid': @oid }, ->
        button '.close.control.tiny.shy', ''
        #if @data.length > 1
        button '.close.lower.control.tiny.shy', ''
        div '.albumlist', ->
          albumorder = otto.templates.orderalbums @data
          had_various = false
          had_nonvarious = false
          for album in albumorder
            if album.artistinfo.various
              if had_nonvarious and not had_various
                div '.varioussep', ''
              had_various = true
            else
              had_nonvarious = true
            text otto.templates.album_details album: album, fileunder: @fileunder


    templates.album_details = coffeecup.compile ->
      if not @album.artistinfo?
        @album.artistinfo = otto.compute_artistinfo @album
      div '.albumdetails', ->
        div '.albumcover', ->
          if @album.cover
            img src: "/image/120?id=#{@album.cover}", alt: @album.album, title: @album.album
          else
            p ->
              if @album.artistinfo.various
                span @album.artistinfo.various
              else
                for artist in @album.artistinfo.all
                  span -> artist
              br()
              span @album.album
          div '.stars-container', ->
            if otto.myusername
              button '.stars.control.teeny.shy.n0', 'data-oid': @album._id
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
            span id: @album.oid, ->
              span @album.album
              if otto.myusername
                button '.stars.control.teeny.shy.n0', 'data-oid': @album.oid
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
                  button '.enqueue.control.teeny.shy', 'data-oid': song.oid
                  span id: song.oid, -> '&nbsp;' + song.song
                  if @album.artistinfo.various or song.artist is not @album.artistinfo.primary
                    # this doesn't work when the fileunder name has been transformed in any way FIXME
                    if @album.artistinfo.various and @fileunder and song.artist is @fileunder.name
                      span '.subartist.highlight.sepgray', song.artist
                    else
                      span '.subartist.sep', song.artist
                  if otto.myusername
                    button '.stars.control.teeny.shy.n0', 'data-oid': song.oid
                    #button '.stars.control.teeny.shy.n0', {'data-oid': song.oid}, otto.templates.icon 'stars'
                  span '.time.sep.shy', otto.format_time(song.length)


    templates.nowplaying_cover = coffeecup.compile ->
      div '.nowplayingcover.thumb.px300.gotothere', { 'data-oid': @song._id }, ->
        if @song.cover
          img
            height: 300
            width: 300
            src: "/image/300?id=#{@song.cover}"
            title: @song.album
        else
          div '.noimg.px300', ->
            div @song.album
            div '.noimgspacer', ''
            div @song.artist

    templates.nowplaying_currenttrack = coffeecup.compile ->
      div '.currenttrack.autosize', ->
        span '.gotothere', 'data-oid': @song.oid, ->
          @song.song || 'unknown'
        if otto.myusername
          button '.stars.control.teeny.shy.n0', 'data-oid': @song._id

      div '#progress-container', ->
        div '#progress.progress', ->
          div '#progress-bar.bar', ''
        span '#time', ->
          span '#current-time', '0:00'
          span '#total-time.sep', '0:00'

      if @song.album
        div '.album.gotothere', 'data-oid': @song.albums[0].oid, ->
          span @song.album
          if @song.year
            span '.year', @song.year

      if @song.artist
        artistoid = 0
        if @song.artists[0] and @song.artists[0].oid?
          artistoid = @song.artists[0].oid
        div '.artist.gotothere', 'data-oid': artistoid, 'data-albumoid': @song.albums[0].oid, ->
          # data-albumoid is a hack. see artist->fileunder note in gotothere code
          @song.artist


    templates.nowplaying_errata = coffeecup.compile ->
      if @song.requestor
        span class: 'errata requestor', -> @song.requestor
        span class: 'errata', ' requested this'
        span class: 'sep'
      if @song.owners? and @song.owners[0]? and @song.owners[0].owner?
        owner = @song.owners[0].owner
      else
        owner = ''
      span '.errata.owner', ->
        span owner
        span class: 'shy', ->
          span class: 'sep'
          #filename = musicroot.relative(@song.filename)
          filename = @song.filename
          span class: 'errata queue filename', filename


    templates.nowplaying_ondeck = coffeecup.compile ->
      ul '.unstyled.queue.ondeck.scrollbox', ->
        # the rest of the queue, on deck
        for song in @songs
          classes = if song.requestor then '' else '.shy'
          li classes, ->
            if song.requestor
              span '.requestor', ->
                div -> song.requestor
            else
              span '.requestor', -> ''
            button '.remove.control.teeny.shy2', id: song.mpdqueueid
            if song.requestor
              span '.song.requested', -> song.song
            else
              span '.song', song.song
            span '.album.sep', song.album
            span '.artist.sep', song.artist
            span '.sep', otto.format_time(song.length)
            span '.shy2', ->
              if song.owners
                owner = song.owners[0].owner
              else
                owner = ''
              span '.queue.owner.sep', -> owner
              #filename = musicroot.relative(song.filename)
              filename = song.filename
              span '.queue.filename.sep', -> filename


    templates.nowplaying_featured = coffeecup.compile ->
      ul '.unstyled.queue.ondeck.scrollbox', ->
        # the rest of the queue, on deck
        for song, n in @songs
          li ->
            if song.requestor
              span '.requestor', ->
                div -> song.requestor
            else
              span '.requestor', -> ''
            #button '.remove.control.teeny.shy', id: song.mpdqueueid
            if song.nowplaying
              span '.playing.control.teeny', otto.templates.icon 'play'
              span '.song.currenttrack', -> song.song
            else
              button '.play.control.teeny.shy', id: song.mpdqueueid, 'data-position': n, ->
                text otto.templates.icon 'play'
              span '.song', song.song
            span '.album.sep', song.album
            span '.artist.sep', song.artist
            span '.sep', otto.format_time(song.length)
            span '.shy', ->
              if song.owners
                owner = song.owners[0].owner
              else
                owner = ''
              span '.queue.owner.sep', -> owner
              #filename = musicroot.relative(song.filename)
              filename = song.filename
              span '.queue.filename.sep', -> filename


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
                div -> otto.templates.artist item: fileunder
          if @data.albums.length
            div class: 'section', 'Albums'
            div class: 'albums', ->
              for album in @data.albums
                div -> otto.templates.album item: album
          songs_list = {}
          if @data.songs.length
            div class: 'section', 'Songs'
            ul class: 'songs unstyled queue', ->
              for song in @data.songs
                songs_list[song.oid] = true
                #filename = musicroot.relative(song.filename)
                filename = song.filename
                li ->
                  button '.enqueue.control.teeny.shy', 'data-oid': song.oid
                  span id: song.oid, class: 'song', -> song.song
                  span class: 'sep'
                  span class: 'album', -> song.album
                  span class: 'sep'
                  span class: 'artist', -> song.artist
                  if otto.myusername
                    button '.stars.control.teeny.shy.n0', 'data-oid': song.oid
                  span class: 'shy', ->
                    span class: 'sep'
                    span -> otto.format_time(song.length)
                    if song.owners
                      owner = song.owners[0].owner
                    else
                      owner = ''
                    span class: 'sep'
                    span class: 'queue owner', -> owner
                    span class: 'sep'
                    span class: 'queue filename', -> filename
          other_cleaned = []
          if @data.other
            for song in @data.other
                if songs_list[song.oid]
                    continue
                other_cleaned.push(song)

            if other_cleaned.length
              p 'Other'
              ul class: 'my-new-list', ->
                for song in other_cleaned
                  li ->
                    button '.enqueue.control.teeny.shy', 'data-oid': song.oid # should be id?
                    span song.song
                    span class: 'sep'
                    span song.album
                    span class: 'sep'
                    span song.artist
                    if otto.myusername
                      button '.stars.control.teeny.shy.n0', 'data-oid': song.oid
                    span class: 'shy', ->
                      span class: 'sep'
                      span class: 'filename', -> song.filename


    templates.newest_albums = coffeecup.compile ->
      div '.search', ->
        div '.section', '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Newest Albums'
        div '.albums', ->
          owner = ''
          for album in @data
            if album.owners?
              if owner isnt album.owners[-1..][0].owner
                owner = album.owners[-1..][0].owner
                br()
                br()
                div '.newestowner', '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;' + owner
            else if owner
              owner = ''
              div '.newestowner', ''
            div -> otto.templates.album item: album


    templates.event = coffeecup.compile ->
      div class: 'event', ->
        timestamp = new Date(@event.timestamp)
        display_time = otto.format_time(timestamp.getHours() * 60 + timestamp.getMinutes(), 5)
        span class: 'timestamp', display_time
        #span class: 'oid', -> @event.oid
        if @event.user
          short_username = @event.user.split('@')[0]
        else
          short_username = 'unknown'
        span class: 'user sep', -> short_username + '&nbsp;&nbsp;' # FIXME use css
        #span class: 'channel', -> @event.channel
        if @event.message?
          if otto.showdown_converter?
            message_markeddown = otto.showdown_converter.makeHtml(@event.message)
          else
            message_markeddown = @event.message
          span class: 'message', message_markeddown
        else
          span class: 'name', -> @event.name


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
        span class: 'message', "loader: #{@event}"


    templates.show_owners = coffeecup.compile ->
      div '.ownerslist', ->
        if @data
          table ->
            for user in @data
              tr '.section', ->
                td "<font size='+1'>&nbsp;&nbsp;&nbsp;&nbsp;#{user.owner}</font>"
                td "&nbsp;&nbsp;&nbsp;&nbsp; #{user.albums} albums"
                td "&nbsp;&nbsp;&nbsp;&nbsp; #{user.songs} songs"
                td "&nbsp;&nbsp;&nbsp;&nbsp; #{user.artists} artists"
                td "&nbsp;&nbsp;&nbsp;&nbsp; #{user.stars} starred items"


    templates.show_stars = coffeecup.compile ->
      div '.starslist', ->
        if @data
          for user of @data
            starlist = []
            for staritem in @data[user]
              if staritem.rank > 0
                starlist.push staritem
            if starlist and starlist.length
              div ' '
              div '.section', ->
                span user
                span '.sep', ->
                  if starlist.length != 1
                    plural = ' items'
                  else
                    plural = ' item'
                  span starlist.length.toString() + plural
                  if otto.myusername
                    span class: 'shy', -> button class: 'download btn teeny control', 'data-oid': user.oid, -> i class: 'download-alt'

            #ul '.songs.unstyled.queue', ->
            div '.songs.unstyled.queue', ->
              if starlist and starlist.length
                for item in starlist
                  if item.otype == 40
                    text otto.templates.artist item: item
                  else if item.otype == 20
                    album = item
                    console.log 'stars album', album
                    div ->
                      otto.templates.album item: album
                  else
                    song = item
                    #filename = musicroot.relative(song.filename)
                    filename = song.filename
                    div ->
                      button '.enqueue.control.teeny.shy', 'data-oid': song.oid
                      span '.song', { id: song.oid, }, song.song
                      span '.album.sep', song.album
                      span '.artist.sep', song.artist
                      if otto.myusername
                        button '.stars.control.teeny.shy.n0', 'data-oid': song.oid
                      span '.sep.shy', otto.format_time(song.length)
                      if song.owners
                        owner = song.owners[0].owner
                        span '.queue.owner.sep.shy', owner
                      span '.queue.filename.sep.shy', filename


    templates.dirbrowser = coffeecup.compile ->
      div id: 'dirbrowser', ->
        ul id: 'path'
        div id: 'subdirs'
        div id: 'contents'


    templates.dirbrowser_subdir = coffeecup.compile ->
      ul ->
        for dir in @data.dirs
          li class: 'subdir', id: dir.oid, 'data-filename': dir.filename, ->
            dir.filename+'/'


    templates.dirbrowser_item = coffeecup.compile ->
      for dir in @data
        li class: 'path', id: dir.oid, -> dir.filename+'/'


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


    templates.icon = coffeecup.compile ->
      switch String @
        when 'play'
          #span 'data-icon': '&#xe000;', 'aria-hidden': 'true'
          #span 'data-icon': '&#xe01b;', 'aria-hidden': 'true'
          #span 'data-icon': '&#xe024;', 'aria-hidden': 'true'
          span 'data-icon': '&#xe089;', 'aria-hidden': 'true'
        when 'attach'
          #span 'data-icon': '&#xe089;', 'aria-hidden': 'true'
          span 'data-icon': '&#xe024;', 'aria-hidden': 'true'
        when 'connected'
          span 'data-icon': '&#xe075;', 'aria-hidden': 'true'
        when 'disconnected'
          span 'data-icon': '&#xe040;', 'aria-hidden': 'true'
        when 'pause'
          #span 'data-icon': '&#xe019;', 'aria-hidden': 'true'
          #span 'data-icon': '&#xe01c;', 'aria-hidden': 'true'
          span 'data-icon': '&#xe08a;', 'aria-hidden': 'true'
        when 'detach'
          span 'data-icon': '&#xe01a;', 'aria-hidden': 'true'
        when 'next'
          #!#span 'data-icon': '&#xe004;', 'aria-hidden': 'true'
          span 'data-icon': '&#xe01e;', 'aria-hidden': 'true'
        when 'kill'
          span 'data-icon': '&#xe01e;', 'aria-hidden': 'true'
        when 'stars'
          span 'data-icon': '&#xe07c;', 'aria-hidden': 'true'


    console.log 'templates defined'
    return templates
