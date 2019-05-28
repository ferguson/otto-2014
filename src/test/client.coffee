####
#### client side (body of global.otto.client served by zappa as /otto.client.js)
####

global.otto.client = ->
  window.otto = window.otto || {}
  otto.socketconnected = false
  otto.serverproceed = false
  otto.clientstarted = false
  otto.clientready = false
  otto.salutations = false


  #@on 'connect': ->
  #@io.on 'connect', ->
  @ready ->
    console.log 'ev ready'
    otto.socketconnected = true
    @emit 'connected'
    # now we wait for the server to say 'proceed' or ask us to 'resession'


  @on 'proceed': ->
    console.log 'sio proceed'
    otto.serverproceed = true
    otto.sayhello()
    # now we wait for the server to say 'welcome' and give us data


  @on 'resession': ->
    console.log 'sio resession, sir, yes sir!'
    $.get '/resession', =>
      console.log '/resession, sir, done sir!'
      otto.serverproceed = true
      otto.sayhello()


  @on 'disconnect': ->
    console.log 'sio disconnect'
    $('body').addClass 'disconnected'
    otto.socketconnected = false
    otto.serverproceed = false
    #otto.clientstarted = false
    otto.clientready = false
    otto.salutations = false
    otto.saygoodbye()


  #@on 'error': ->
  @io.on 'error': ->
    console.log 'sio error, reloading'
    window.location.reload()


  # note: connect doesn't work when moved under $ or nextTick!
  # it appears you have to call @connect inside zappa.run's initial call
  # or else the context.socket isn't created inside zappa.run() in
  # time for it to be used internally. i think this also means it's going
  # to be very difficut to rig things so we can call @connect again to connect
  # to a different server. -jon

  # first arg is the url to connect to, undefined connects back to where we were served from
#  @io.connect undefined, 'reconnection limit': 3000, 'max reconnection attempts': Infinity
  # this might be in a race condition with the rest of this file being parsed (move it to end?)
  # i think i fixed ^^ this with the added otto.clientstarted logic


  # using nextTick here so the function, and all the functions it calls, are finished being defined
  #nextTick -> otto.start_client()
  setTimeout ( () -> otto.start_client() ), 0

  otto.start_client = =>
    console.log 'start_client'

    otto.clientstate = {}
    otto.myusername = no
    otto.connect_state = 'disconnected'
    otto.ignore_reload = false

    otto.clientstarted = true
    otto.sayhello()


  otto.sayhello = =>
    console.log 'sayhello?', otto.socketconnected, otto.serverproceed, otto.clientstarted, not otto.salutations
    if otto.socketconnected and otto.serverproceed and otto.clientstarted and not otto.salutations
      otto.salutations = true
      console.log 'well, hello server!'
      @emit 'hello', otto.clientstate # causes the server to welcome us and tell us our state


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

    if otto.emptydatabase
      otto.create_hellopage()
      otto.channel_list = @data.channellist
      otto.myusername = @data.myusername
      otto.mychannel = @data.mychannel
    else
      if $('.mmenu-page').length
        otto.templates.body_reset()
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
