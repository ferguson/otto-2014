require './otto.misc'
require './otto.events'
otto = global.otto


otto.listeners = do ->  # note the 'do' causes the function to be called
  listeners = {}

  # we could just use [] for our arrays, but then
  # the object type would be Array instead of Object
  # and JSON would only stringify the Array items
  # and would miss our awful abuse of the poor object
  # (we are adding attributes like [key].attribute)

  listeners.SocketList = class SocketList extends Array

  listeners.ListenerList = class ListenerList extends Array
    constructor: ->  # is this necessary? (oddly, it seems it is)

    add: (id, user='', address='', channelname='') ->
      if id not in @
        @push id
        @[id] =
          socketids: new SocketList()
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

    remove: (id) ->
      if id in @
        return removefromarray(@, id)
      return no

    empty: (id) ->
      if @[id].socketids.length == 0 and @[id].streams == 0
        return yes
      return no

    addSocket: (id, socketid) ->
      @add(id)
      @[id].socketids.push socketid
      @[id].socketids[socketid] =
        inchat: 0
        typing: 0
        focus: 1
        idle: 0

    removeSocket: (id, socketid) ->
      removefromarray(@[id].socketids, socketid)
      if @empty(id)
        return @remove(id)
      return no

    addStream: (id) ->
      @[id].streams++

    removeStream: (id) ->
      if @[id].streams > 0
        @[id].streams--

    set: (id, socketid, k, v) ->
      oldv = @[id].socketids[socketid][k]
      console.log 'k', k, 'oldv', oldv, 'v', v
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


    set_user: (session, sessionID) ->
      if @list.setUser sessionID, session.user, session.address
        @hysteresis 'join', sessionID, =>
          if not @list.empty(sessionID)
            @trigger 'userjoin', @list[sessionID]


    change_user: (session, sessionID) ->
      if @list.changeUser sessionID, session.user, session.address
        @hysteresis 'join', sessionID, =>
          if not @list.empty(sessionID)
            @trigger 'userjoin', @list[sessionID]
      else
        @trigger 'userchange', @list[sessionID]


    add_socket: (socketid, session, sessionID, channelname) ->
      console.log 'add_socket sessionID', sessionID
      @list.setUser sessionID, session.user, session.address, channelname
      @list.addSocket sessionID, socketid
      @update()


    remove_socket: (socketid, sessionID) ->
      console.log 'remove_socket sessionID', sessionID
      left = @list.removeSocket sessionID, socketid
      if left
        @hysteresis 'join', sessionID, =>
          if @list.empty(sessionID)
            @trigger 'userleft', left
      @update()


    add_stream: (session, sessionID) ->
      console.log 'add_stream sessionID', sessionID
      @list.setUser sessionID, session.user, session.address
      @list.addStream sessionID
      @update()
      if @list[sessionID].streams == 1
        @hysteresis 'stream', sessionID, =>
          if @list[sessionID].streams > 0
            @trigger 'streamingstart', @list[sessionID]


    remove_stream: (sessionID) ->
      console.log 'remove_stream sessionID', sessionID
      @list.removeStream sessionID
      @update()
      if @list[sessionID].streams == 0
        @hysteresis 'stream', sessionID, =>
          if @list[sessionID].streams == 0
            @trigger 'streamingstop', @list[sessionID]


    set_state: (sessionID, socketid, state, value) ->
      console.log 'set_state', sessionID, socketid, state, value
      if @list.set sessionID, socketid, state, value
        @update()


    list_socketids: (sessionID) ->
      return @list[sessionID].socketids

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

