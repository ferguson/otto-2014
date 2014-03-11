###############
### client side (otto.client.soundfx.coffee served as /otto.soundfx.js)
###############

global.otto.client.soundfx = ->
  window.otto.client.soundfx = do ->  # note the 'do' causes the function to be called

    $('head').append '<script src="static/js/buzz.js">'

    soundfx = {}

    event_sound_map =
      'chat':           'randomize4.wav'
      'joinedchannel':  'joined.wav'
      'leftchannel':    'startedorstopped.wav'
      'removed':        'left.wav'
      'killed':         'downish.wav'
      'enqueue':        'subtle.wav'
      'joinedchat':     'skweek.wav'
      'leftchat':       'delete.wav'
      'startstreaming': no
      'stopstreaming':  no
      'finished':       no
      'fxenabled':      'subtle.wav'

    fx_attenuation = 0.70 # we want the sound effects to only be 70% of the music vol

    sounds = {}

    $ ->
      for eventname, soundfile of event_sound_map
        if soundfile
          sounds[eventname] = new buzz.sound '/static/sounds/'+soundfile
          sounds[eventname].load()
        else
          sounds[eventname] = no


    soundfx.play = (eventname) ->
      if sounds[eventname]
        if otto.chat_state or eventname not in ['chat', 'joinedchat', 'leftchat']
          fx = sounds[eventname]
          vol = parseInt( otto.current_volume * fx_attenuation )
          fx.setVolume(vol).play()


    return soundfx
