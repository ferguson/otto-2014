###############
### client side (otto.client.misc.coffee served as /otto.misc.js)
###############


global.otto.client.misc = ->

  window.otto = window.otto || {}

  # on demand client side modules
  otto.client = otto.client || {}

  otto.load_module = (modulename, callback) ->
    if not otto.client[modulename]
      console.log "loading module #{modulename}"
      $.getScript "/otto.client.#{modulename}.js", ->
        console.log "module #{modulename} loaded"
        callback()
    else
      callback()

  otto.call_module = (modulename, methodname, args...) ->
    otto.load_module modulename, ->
      console.log "calling otto.client.#{modulename}.#{methodname}(args...)"
      otto.client[modulename][methodname](args...)

  otto.call_module_ifloaded = (modulename, methodname, args...) ->
    # only call the module if it is already loaded, otherwise do nothing
    if otto.client[modulename]  # don't trigger a automatic module load
      otto.call_module modulename, methodname, args...
    else
      console.log "ignoring call to unloaded module otto.client.#{modulename}.#{methodname}(args...)"

  otto.ismoduleloaded = (modulename) ->
    return otto.client[modulename]?


  # client side version of node's nextTick
  window.nextTick = (func) -> setTimeout(func, 0)


  # coffeescript friendly version of setTimeout and setInterval
  window.timeoutSet  = (ms, func) -> setTimeout(func, ms)
  window.intervalSet = (ms, func) -> setInterval(func, ms)


  $.fn.scrollToBottom = ->
    this.animate scrollTop: this.prop('scrollHeight') - this.height(), 100


  otto.adjust_autosize = ->
    #console.log 'adjust_autosize'
    #$element = $( $('.autosize').filter(':first') )
    $('.autosize').each (index, element) ->
      $element = $ element
      size = 34
      #console.log $element
      #desired_width = $element.width()
      desired_width = $(window).width() - $element.parent().offset().left
      desired_width -= 10  # give a little bit of margin

      $resizer = $element.clone(true, true)
      $resizer.css
        #'max-width': desired_width
        'display': 'inline'
        'white-space': 'nowrap'
        'width': 'auto'
        'font-size': "#{size}px"
      $resizer.insertAfter("#playlist")

      #console.log "desired_width #{desired_width}, width #{$resizer.width()}, size #{size}"
      gaveup = false;
      while $resizer.width() > desired_width
        size = size - 1
        if size <= 19
          gaveup = true
          break
        #console.log "desired_width #{desired_width}, width #{$resizer.width()}, size #{size}"
        $resizer.css
          'font-size':  "#{size}px"

      # adjust the padding so the text stays at the botton of the div as it shrinks
      if gaveup
        height_adjust = 0
      else
        height_adjust = $element.height() - $resizer.height()
      #console.log 'height_adjust', height_adjust
      $resizer.remove()

      $element.css
        'font-size': "#{size}px"
      $element.css
        'padding-top': "#{height_adjust}px"
      $element.width(desired_width)
      #$('currenttrack-container').css 'max-width': "300px"


  otto.format_time = (seconds, minlen=4) ->
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


  # from http://stackoverflow.com/questions/6658517/window-resize-in-jquery-firing-multiple-times
  # debouncing function from John Hann
  # http://unscriptable.com/index.php/2009/03/20/debouncing-javascript-methods/
  # usage:
  # $(window).smartresize ->
  #   code that takes it easy...
  do ($ = jQuery, sr = 'smartresize') ->
    debounce = (func, threshold, execAsap) ->
      timeout = null
      debounced = ->
        obj = this
        args = arguments
        delayed = ->
          if not execAsap
            func.apply(obj, args)
          timeout = null
        if timeout
          clearTimeout timeout
        else if execAsap
          func.apply(obj, args)
        timeout = setTimeout(delayed, threshold || 100)
      return debounced
    # smartresize
    $.fn[sr] = (fn) ->
      return if fn then this.bind('resize', debounce(fn)) else this.trigger(sr)
