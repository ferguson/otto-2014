###############
### client side (otto.client.player.coffee served as /otto.player.js)
###############

global.otto.client.player = ->
  window.otto.client.player = do ->  # note the 'do' causes the function to be called

    $('head').append '<script src="static/js/jquery.jplayer.min.js">'
    #$('head').append '<script src="static/js/jquery.jplayer.inspector.js">'


    player = {}


    $(window).on 'unload', ->
      player.destroy_jplayer()


    player.connect = (channelname) ->
      player.channelname = channelname
      console.log 'creating jplayer for channel', player.channelname
      player.state 'connecting'
      player.create_jplayer()
      #$('#results').jPlayerInspector({jPlayer:$("#jplayer")})
      #$('#jplayer_inspector_toggle_0').click()


    player.disconnect = ->
      player.state 'disconnected'
      player.destroy_jplayer()


    player.destroy_jplayer = ->
      player.$jplayer.remove() if player.$jplayer


    player.create_jplayer = ->
      player.destroy_jplayer()
      player.$jplayer = $ '<div id="jplayer">'
      $(document.body).prepend player.$jplayer
      player.$jplayer.jPlayer
        swfPath:    '/static/js'
        supplied:   'mp3,oga'  # historical note: live streaming from traktor uses oga
        #supplied:   'wav'
        wmode:      'window'
        errorAlerts: false
        warningAlerts: false
        volume:     otto.current_volume / 100
        solution:   'flash, html'   # as opposed to 'html, flash'
        preload:    'none'
        timeupdate: player.jplayer_event_handler
        progress:   player.jplayer_event_handler
        ended:      player.jplayer_event_handler
        error:      player.jplayer_event_handler
        ready:      player.jplayer_event_handler
        #play:       player.jplayer_event_handler
        #pause:      player.jplayer_event_handler


    player.jplayer_event_handler = (e) ->
      if e.type not in ['jPlayer_timeupdate', 'jPlayer_progress']
        console.log "jplayer event #{e.type} state #{player.state()}"

      switch e.type
        when 'jPlayer_ready'
          player.$jplayer.jPlayer 'setMedia',
            title: "Otto"
            mp3: "/stream/#{player.channelname}/mp3"
            ogg: "/stream/#{player.channelname}/ogg"
            #wav: "/stream/#{player.channelname}/wav"
          player.$jplayer.jPlayer 'play'
          player.state 'buffering'

        when 'jPlayer_ended'
          if player.state() isnt 'disconnected'
            player.state 'reconnecting'
            nextTick ->
              player.create_jplayer()

        when 'jPlayer_error'
          if e.jPlayer.error.type in [$.jPlayer.error.URL, $.jPlayer.error.FLASH]
            timeoutSet 1000, ->
              if player.state() isnt 'disconnected'
                player.state 'reconnecting'
                player.create_jplayer()
          else
            console.log "jplayer error #{e.jPlayer.error.type}"

        when 'jPlayer_timeupdate'
          if e.jPlayer.status.currentTime and player.state() not in ['connected', 'disconnected']
            player.state 'connected'
          player.timeupdate e.jPlayer.status.currentTime, e.jPlayer.status.duration

        when 'jPlayer_progress'
          return #!#
          #if player.state() in ['buffering', 'underrun']
            #if e.jPlayer.status.duration != progress_last
              #$('#connect').html otto.templates.ouroboros size: 'small', direction: 'cw', speed: 'normal'
              #progress_last = e.jPlayer.status.duration
            #if not player.buffering_state
            #  player.buffering_state = true
            #  #$('#connect').html otto.templates.ouroboros size: 'small', direction: 'cw', speed: 'normal'
            #  $('#connect .ouroboros .ui-spinner').addClass('cw').removeClass('ccw')


    player.timeupdate = do ->
      lasttime = 0
      cycles = 4  # slows it down this many timeupdate events
      cycle = cycles  # setup so first one causes a change
      (currenttime, duration) ->
        #console.log "timeupdate! #{currenttime} #{duration} #{lasttime} #{cycles} #{cycle}"
        if currenttime != lasttime
          lasttime = currenttime
          if cycle < cycles # slow it down
            cycle += 1
          else
            cycle = 0
            # this is where the old streaming in progress indicator was, do we want a new one? FIXME
            #console.log 'pulse'
        else
          if player.state() is 'connected'
            if e.jPlayer.status.currentTime + 1 > duration
              console.log 'setting state to underrun'
              player.state 'underrun'
            else
              player.state 'skipping'  # a very odd state jplayer gets into
              console.log 'jplayer skipping detected, restarting jplayer'
              player.create_jplayer()


    player.state = (newstate) ->
      return otto.connect_state if not newstate
      console.log 'player state', newstate
      otto.connect_state = newstate

      switch newstate
        when 'disconnected'
          #$('#connect').html otto.templates.icon 'disconnected'  # put correct play icon back FIXME
          $('#connect').html '<img src="static/images/disconnected.svg" height="20" width="20">'
        when 'connecting'
          # the ouroboros might already be there from when the module was being loaded
          if not $('#connect>:first-child').is '.ouroboros'
            $('#connect').html otto.templates.ouroboros size: 'small', direction: 'cw', speed: 'slow'
        when 'connected'
          #$('#connect').html otto.templates.icon 'connected'
          $('#connect').html '<img src="static/images/connected.svg" height="20" width="20">'
        when 'reconnecting'
          $('#connect').html otto.templates.ouroboros size: 'small', direction: 'cw', speed: 'slow'
        when 'skipping'
          $('#connect').html otto.templates.ouroboros size: 'small', direction: 'cw', speed: 'slow'
        #when 'buffering'
        #when 'underrun'


    player.setvolume = (volume) ->
      otto.current_volume = volume
      if player.$jplayer
        player.$jplayer.jPlayer 'option', 'volume', otto.current_volume / 100


    return player
