###############
### client side (body of otto.client.misc.coffee served as /otto.misc.js)
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
        if callback
          callback()
    else
      if callback
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


  otto.autosize_clear_cache = -> otto.$autosize_elements_cache = false
  otto.autosize_clear_cache()

  otto.autosize_adjust = ->
    console.log 'autosize_adjust'
    if !otto.$autosize_elements_cache
      otto.$autosize_elements_cache = $('.autosize')
    otto.$autosize_elements_cache.each (index, element) ->
      $element = $ element
      maxFontSize = $element.data('autosize-max') || $element.height()-4
      minFontSize = $element.data('autosize-min') || Math.round($element.height/2)-4
      rightMargin = $element.data('autosize-right-margin') || 0

      fontSize = maxFontSize

      #while size > minFontSize and element.scrollWidth > element.offsetWidth
      #  $element.css 'font-size': "#{fontSize}px"

      desiredWidth = $element.parent().width()

      $resizer = $element.clone()
      $resizer.css
        'display': 'inline'
        'white-space': 'nowrap'
        'width': 'auto'
        'font-size': "#{fontSize}px"
      $resizer.insertAfter($element)

      while fontSize > minFontSize and $resizer.width() > desiredWidth
        fontSize = fontSize - 1
        $resizer.css 'font-size': "#{fontSize}px"

      # adjust the top so the text stays centered in the div
      heightAdjust = 0
      if fontSize > minFontSize
        heightAdjust = (maxFontSize - fontSize) / 2

      $resizer.remove()

      $element.css
        'font-size': "#{fontSize}px"
        'top': "#{heightAdjust}px"


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
        timeout = setTimeout(delayed, threshold || 50)
      return debounced
    # smartresize
    $.fn[sr] = (fn) ->
      return if fn then this.bind('resize', debounce(fn)) else this.trigger(sr)
