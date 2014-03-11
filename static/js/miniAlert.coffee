#
# miniAlert, an alert plugin for jQuery
# Instructions: http://minijs.com/plugins/10/alert
# By: Matthieu Aussaguel, http://www.mynameismatthieu.com, @mattaussaguel
# Version: v1.0 stable
# More info: http://minijs.com/
#

jQuery ->
  $.miniAlert = (element, options) ->
    # default plugin settings
    @defaults = 
      text:     'x'       # close button text content
      cssClass: 'close'   # close button css class
      position: 'before'  # close button position: 'before' or 'after'
      effect:   'basic'   # closing effect: 'basic' or fade' or 'slide'
      duration: 100       # hide animation duration in milliseconds
      onLoad:   ->        # callback called when the close button has been added
      onHide:   ->        # callback called when close button is clicked
      onHidden: ->        # callback called when alert message is hidden

    @state = ''

    @settings = {}

    @$element = $ element

    setState = (@state) ->

    @getState = -> state

    @getSetting = (settingKey) -> @settings[settingKey]

    @callSettingFunction = (functionName, args = [@$element, @$button]) ->
      @settings[functionName].apply(this, args)

    removeElement = =>
      @$element.remove()

      setState 'hidden'
      @callSettingFunction 'onHidden', []

    addButton = =>
      options = { class: @settings.cssClass, text: @settings.text }
      @$button   = $('<button />', options)

      if @settings.position is 'after'
        @$button.appendTo @$element
      else
        @$button.prependTo @$element

    bindButtonEvent = =>
      @$button.bind 'click', (e) =>
        e.preventDefault()

        setState 'hiding'
        @callSettingFunction 'onHide'

        if @settings.effect is 'fade'
          @$element.fadeOut @settings.duration, removeElement
        else if @settings.effect is 'slide'
          @$element.slideUp @settings.duration, removeElement
        else
          removeElement()

    init = =>   
      setState 'loading'

      @settings = $.extend({}, @defaults, options)

      addButton()
      bindButtonEvent()

      setState 'loaded'
      @callSettingFunction 'onLoad'

    init()

    this

  $.fn.miniAlert = (options) ->
    this.each ->
      if undefined == ($ this).data('miniAlert')
        plugin = new $.miniAlert this, options
        ($ this).data 'miniAlert', plugin