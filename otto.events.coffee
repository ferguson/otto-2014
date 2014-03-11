otto = global.otto

##### parent class for adding events to other classes

global.otto.events = do -> # note 'do' calls the function
  events = {}

  events.EventEmitter = class EventEmitter
    constructor: (@validevents) ->
      # very inefficent ^^^ that the static valid events list is stored with each object FIXME
      @eventhandlers = {}


    on: (eventname, callback) ->
      if eventname not in @validevents
        throw new Error "object {@constructor.name} doesn't have an event named #{eventname}"
      if not callback
        throw new Error "on method for {@constructor.name} missing callback"
      if not @eventhandlers[eventname]
        @eventhandlers[eventname] = []
      @eventhandlers[eventname].push callback


    trigger: (eventname, args...) ->
      #console.log "trigger '#{eventname}' for #{@name}" if eventname is not 'time'
      if eventname not in @validevents
        throw new Error "object {@constructor.name} invalid event name #{eventname}"
      for name in [eventname, '*']
        if @eventhandlers[name]
          for handler in @eventhandlers[name]
            handler eventname, @, args...


  return events
