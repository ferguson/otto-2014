_ = require 'underscore'
coffeecup = require 'coffeecup'

otto = global.otto


global.otto.index = do -> # note 'do' calls the function
  index = {}

  index.links = [
      { rel: 'icon', type: 'image/png', href: 'static/images/favicon.png' }
      #{ rel: 'shortcut icon', href: 'static/images/favicon.ico/favicon.ico' }
      #{ rel: 'apple-touch-icon', href: 'static/images/ottoicon1024.png' }
      { rel: 'apple-touch-icon-precomposed', href: 'static/images/ottoicon1024.png' }
    ]

  index.metas = [
      { name: 'apple-mobile-web-app-capable', content: 'yes' }
      #{ name: 'viewport', content: 'width=device-width' }
      #{ name: 'viewport', content: 'width=1470, user-scalable=no' }
      #{ name: 'viewport', content: 'width=1270' }
      { name: 'viewport', content: 'initial-scale=1.0, user-scalable=no' } # no reflective shine
    ]

  index.stylesheets = [
    'static/fonts/icomoon'
    #'static/css/jquery-ui-1.8.17.custom'
    'static/css/jquery-ui-1.10.3.custom'
    #'static/css/reset'
    #'static/css/jquery.terminal'
    #'static/css/miniAlert'
    'static/css/normalize'
    'static/css/ouroboros'
    'static/css/mmenu'
    'static/css/otto'
    ]

  index.scripts = [
    'socket.io/socket.io'
    'zappa/jquery'
    'zappa/zappa'
    #'zappa/sammy'
    #'static/js/jquery-ui-1.8.17.custom.min'
    'static/js/jquery-ui-1.10.3.custom.min'
    'static/js/jquery.scrollstop'
    'static/js/jquery.mousewheel'
    'static/js/jquery.idle-timer'
    'static/js/jquery.lazyload'
    'static/js/jquery-migrate-1.2.1'
    'static/js/jquery.terminal'
    'static/js/jquery.mmenu.min'
    'static/js/prefixfree'
    #'static/js/miniAlert'
    'static/js/showdown'
    'otto.client.templates' # needed by otto.client
    'otto.client.misc' # non-dynamic module
    'otto.client'
    ]

  index.scripts_donotaddjs = [
    # for mobile debugging:
    #'http://jsconsole.com/remote.js?554C497C-216D-4803-8CC5-DD8656C25C8C'
  ]


  # we don't use live.js anymore, so i added prefixfree above
  #if if process.env.NODE_ENV is 'development'
  #  #console.log 'adding live.js for debugging'
  #  #scripts.push 'static/js/live' #for debugging
  #else
  #  console.log 'not adding live.js for debugging, adding prefixfree.js'
  #  scripts.push 'static/js/prefixfree' # off while debugging, it prevents live.js from working


  index.template = coffeecup.compile ->
    doctype 5
    html ->
      head ->
        title @title if @title
        if @links
          for l in @links
            if l.type?
              link rel: l.rel, type: l.type, href: l.href
            else
              link rel: l.rel, href: l.href
        link(rel: @link.rel, href: @link.href) if @link  # non-plural version
        if @metas
          for m in @metas
            meta name: m.name, content: m.content
        meta(name: @meta.name, content: @meta.content) if @meta  # non-plural version
        if @stylesheets
          for s in @stylesheets
            link rel: 'stylesheet', href: s + '.css'
        link(rel: 'stylesheet', href: @stylesheet + '.css') if @stylesheet
        style @style if @style
      body @bodyclasses, ->
        if @body
          text @body
        if @scripts
          for s in @scripts
            script src: s + '.js'
        script(src: @script + '.js') if @script  # non-plural version
        if @scripts_donotaddjs
          for s in @scripts_donotaddjs
            script src: s
        script(src: @script_donotaddjs) if @script_donotaddjs  # non-plural version


  index.render = (moreparams={}) ->
    params = {
      #host: if @req.headers.host? and (@req.headers.host is 'localhost' or @req.headers.host.indexOf('localhost:') is 0) then os.hostname() else @req.headers.host
      #port: otto.port
      title: "otto" + if process.env.NODE_ENV is 'development' then ' (development)' else ''
      metas: index.metas
      links: index.links
      scripts: index.scripts
      scripts_donotaddjs: index.scripts_donotaddjs
      stylesheets: index.stylesheets
    }
    _.extend params, moreparams
    return index.template params


  return index
