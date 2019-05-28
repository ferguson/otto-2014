require './misc'
require './events'
otto = global.otto


otto.listeners = do ->  # note the 'do' causes the function to be called
  listeners = {}

  # we could just use [] for our arrays, but then
  # the object type would be Array instead of Object
  # and JSON would only stringify the Array items
  # and would miss our awful abuse of the poor object
  # (we are adding attributes like [key].attribute)

  listeners.ListenerList = class ListenerList extends Array
    constructor: ->  # is this necessary? (oddly, it seems it is)
      super()

    add: (id, user='', address='', channelname='') ->
      if id not in @
        @push id
        @[id] =
          socketids: {}
          user: user
          address: address
          channelname: channelname
          streams: 0

    setUser: (id, user, address='', channelname='') ->
      if id not in @
        @add(id, user, address, channelname)
        return yes
      return no

    changeUser: (id, user, address='', channelname='') ->
      if id not in @
        return @setUser(id, user, address, channelname)
      @[id].user = user
      @[id].address = address
      @[id].channelname = channelname
      return no

    changeChannel: (id, channelname) ->
      @[id].channelname = channelname

    remove: (id) ->
      if id in @
        return removefromarray(@, id)
      return no

    empty: (id) ->
      if Object.keys(@[id].socketids).length == 0 and @[id].streams == 0
        return yes
      return no

    addSocket: (id, socketid) ->
      @add(id)
      @[id].socketids[socketid] =
        inchat: 0
        typing: 0
        focus: 1
        idle: 0

    getSockets: (id) ->
      return @[id].socketids

    removeSocket: (id, socketid) ->
      #removefromarray(@[id].socketids, socketid)
      delete @[id].socketids[socketid]
      if @empty(id)
        return @remove(id)
      return no

    addStream: (id) ->
      @[id].streams++

    removeStream: (id) ->
      if @[id].streams > 0
        @[id].streams--

    set: (id, socketid, k, v) ->
      return no if not @[id].socketids[socketid]
      oldv = @[id].socketids[socketid][k]
      #console.log 'k', k, 'oldv', oldv, 'v', v
      if not (v is oldv)
        @[id].socketids[socketid][k] = v
        return yes
      return no

  ##### end of class ListenersList


  listeners.Listeners = class Listeners extends otto.events.EventEmitter
    constructor: ->
      # valid events:
      super [ '*'
              'update'
              'userjoin'
              'userchange'
              'userleft'
              'streamingstart'
              'streamingstop'
            ]
      @list = new ListenerList
      # hey! i just introduced a race condition! cool! FIXME
      # (not sure what this ^^^ means anymore)
      @timeouts = {}
      otto.ll = @list  # ugh.


    # on the 'update' event, we should consider making a copy of ourselves while
    #  skipping any incomplete connections and send that instead
    update: ->
      @trigger 'update', @list


    hysteresis: (type, sessionID, callback) ->
      @timeouts[sessionID] = {} if not @timeouts[sessionID]?
      if not @timeouts[sessionID][type]
        @timeouts[sessionID][type] = otto.misc.timeoutSet 5000, =>
          @timeouts[sessionID][type] = false
          callback()


    set_user: (session) ->
      if @list.setUser session.sessionID, session.user, session.address
        @hysteresis 'join', session.sessionID, =>
          if not @list.empty(session.sessionID)
            @trigger 'userjoin', @list[session.sessionID]


    change_user: (session) ->
      if @list.changeUser session.sessionID, session.user, session.address
        @hysteresis 'join', session.sessionID, =>
          if not @list.empty(session.sessionID)
            @trigger 'userjoin', @list[session.sessionID]
      else
        @trigger 'userchange', @list[session.sessionID]

    change_channel: (session) ->
      console.log 'listeners.change_channel', session.channelname
      @list.changeChannel session.sessionID, session.channelname

    add_socket: (session, socket) ->
      console.log 'add_socket sessionID', session.sessionID
      @list.setUser session.sessionID, session.user, session.address, session.channelname
      @list.addSocket session.sessionID, socket.id
      @update()


    get_sockets: (session) ->
      @list.getSockets session.sessionID


    remove_socket: (session, socket) ->
      console.log 'remove_socket sessionID', session.sessionID, 'socket.id', socket.id
      left = @list.removeSocket session.sessionID, socket.id
      if left
        @hysteresis 'join', session.sessionID, =>
          if @list.empty(session.sessionID)
            @trigger 'userleft', left
      @update()


    add_stream: (session) ->
      console.log 'add_stream for sessionID', session.sessionID
      @list.setUser session.sessionID, session.user, session.address
      @list.addStream session.sessionID
      @update()
      if @list[session.sessionID].streams == 1
        @hysteresis 'stream', session.sessionID, =>
          if @list[session.sessionID].streams > 0
            @trigger 'streamingstart', @list[session.sessionID]


    remove_stream: (session) ->
      console.log 'remove_stream for sessionID', session.sessionID
      @list.removeStream session.sessionID
      @update()
      if @list[session.sessionID].streams == 0
        @hysteresis 'stream', session.sessionID, =>
          if @list[session.sessionID].streams == 0
            @trigger 'streamingstop', @list[session.sessionID]


    set_state: (sessionID, socketid, state, value) ->
      #console.log 'set_state', sessionID, socketid, state, value
      if @list.set sessionID, socketid, state, value
        @update()


    list_socketids: (sessionID) ->
      return @list[sessionID].socketids

    get_list: ->
      return @list

  ##### end of class Listeners


  removefromarray = (array, item) ->
    for victim, i in array
      if item == victim
        return array.splice(i, 1)
    return null


  return listeners





  # a previous attempt, after which i said "let's dial that back a bit"
  ## ref http://www.bennadel.com/blog/2292-\
  #        Extending-JavaScript-Arrays-While-Keeping-Native-Bracket-Notation-Functionality.htm
  #ListenersX = (->
  #  # the construction function
  #  Listeners = ->
  #    listeners = Object.create( Array:: )
  #    listeners = (Array.apply( listeners, arguments ) || listeners)
  #    Listeners.injectClassMethods( listeners )
  #    return listeners
  #
  #  Listeners.injectClassMethods = (listeners) ->
  #    for method of Listeners::
  #      # Make sure this is a local method
  #      #if Listeners::hasOwnProperty(method)
  #      listeners[method] = Listeners::[method];
  #    return listeners
  #
  #  Listeners:: =
  #    add: (id) ->
  #
  #  return Listeners
  #).call( {} )  # magic
