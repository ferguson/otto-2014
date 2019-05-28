_ = require 'underscore'
teacup = require 'teacup'
{doctype, html, head, body, title, meta, style, script, link, raw, div, span} = teacup

otto = global.otto


global.otto.index = do -> # note 'do' calls the function
  index = {}

  index.links = [
      { rel: 'icon', type: 'image/png', href: 'static/images/favicon.png' }
      #{ rel: 'shortcut icon', href: 'static/images/favicon.ico/favicon.ico' }
      #{ rel: 'apple-touch-icon', href: 'static/images/ottoicon1024.png' }
      { rel: 'apple-touch-icon-precomposed', href: 'static/images/ottoicon1024.png' }  # no reflective shine
      { rel: 'apple-touch-startup-image', href: 'static/images/ottoiphonesplash.png' }
  ]

  index.metas = [
      { name: 'apple-mobile-web-app-capable', content: 'yes' }
      { name: 'mobile-web-app-capable', content: 'yes' }  # android?
      #{ name: 'viewport', content: 'width=device-width' }
      #{ name: 'viewport', content: 'width=1470, user-scalable=no' }
      #{ name: 'viewport', content: 'width=1270' }
      { name: 'viewport', content: 'initial-scale=1.0, user-scalable=no, minimal-ui' }
      #{ name: 'apple-mobile-web-app-status-bar-style', content: 'black' }
      #{ name: 'apple-mobile-web-app-status-bar-style', content: 'translucent' }
      { name: 'apple-mobile-web-app-status-bar-style', content: 'black-translucent' }
      { name: 'apple-mobile-web-app-title', content: 'Otto Client' }
      { name: 'format-detection', content: 'telephone=no' }
    ]

  index.stylesheets = [
    #'static/css/jquery-ui-1.8.17.custom.css'
    'static/css/jquery-ui-1.10.3.custom.css'
    #'static/css/reset.css'
    #'static/css/jquery.terminal.css'
    #'static/css/miniAlert.css'
    'static/css/addtohomescreen.css'
    'static/css/normalize.css'
    'static/css/ouroboros.css'
    'static/css/mmenu.css'
    'static/fonts/icomoon.css'  # mmenu.css messes up the icons!
    'static/css/otto.css'
    ]

  index.scripts = [
    #'socket.io/socket.io.js'
    #'zappa/jquery.js'
    #'zappa/zappa.js'
    #'zappa/sammy.js'
    'static/js/zappa-client-2.6.0.browser.js'
    'static/js/jquery-1.8.3.min.js'
    #'static/js/jquery-ui-1.8.17.custom.min.js'
    'static/js/jquery-ui-1.10.3.custom.min.js'
    'static/js/jquery.scrollstop.js'
    'static/js/jquery.mousewheel.js'
    'static/js/jquery.idle-timer.js'
    'static/js/jquery.lazyload.js'
    'static/js/jquery-migrate-1.2.1.js'
    'static/js/jquery.terminal.js'
    'static/js/jquery.mmenu.min.js'
    'static/js/restive.min.js'
    'static/js/moment.min.js'
    'static/js/addtohomescreen.min.js'
    'static/js/toe.js'
    'static/js/prefixfree.js'
    'static/js/modernizr.custom.04062.js'
    #'static/js/miniAlert.js'
    'static/js/showdown.js'
    'otto.client.templates.js'
    'otto.client.misc.js' # non-dynamic module
    #'http://jsconsole.com/remote.js?554C497C-216D-4803-8CC5-DD8656C25C8C'  # for mobile debugging
    'otto.client.js'
    ]


  # we don't use live.js anymore, so i added prefixfree above
  #if if process.env.NODE_ENV is 'development'
  #  #console.log 'adding live.js for debugging'
  #  #scripts.push 'static/js/live' #for debugging
  #else
  #  console.log 'not adding live.js for debugging, adding prefixfree.js'
  #  scripts.push 'static/js/prefixfree' # off while debugging, it prevents live.js from working


  index.template = teacup.renderable (p)->
    doctype 5
    html '.nofouc', ->  # .nofouc not really used currently
      head ->
        title p.title if p.title
        if p.links
          for l in p.links
            if l.type?
              link rel: l.rel, type: l.type, href: l.href
            else
              link rel: l.rel, href: l.href
        link(rel: p.link.rel, href: p.link.href) if p.link  # non-plural version
        if p.metas
          for m in p.metas
            meta name: m.name, content: m.content
        meta(name: p.meta.name, content: p.meta.content) if p.meta  # non-plural version
        if p.stylesheets
          for s in p.stylesheets
            link rel: 'stylesheet', href: s
        link(rel: 'stylesheet', href: p.stylesheet) if p.stylesheet
        style p.style if p.style
        script 'document.documentElement.className=""'  # http://www.paulirish.com/2009/avoiding-the-fouc-v3/
      body p.bodyclasses, ->
        if p.body
          raw p.body
        if p.scripts
          for s in p.scripts
            script src: s
        script(src: p.script) if p.script  # non-plural version


  index.body_startup = teacup.renderable (p)->
    div '.startup-container', ->
      div '.startup', ->
        #raw otto.templates.ouroboros size: 'large', direction: 'cw', speed: 'slow'
        div '.ouroboros', ->
          div '.ui-spinner.large.slow.cw.gray.dark', ->
            span '.side.left', ->
              span '.fill', ''
            span '.side.right', ->
              span '.fill', ''


  index.render = (moreparams={}) ->
    params = {
      #host: if @req.headers.host? and (@req.headers.host is 'localhost' or @req.headers.host.indexOf('localhost:') is 0) then os.hostname() else @req.headers.host
      #port: otto.port
      title: "otto" + if process.env.NODE_ENV is 'development' then ' (development)' else ''
      body: index.body_startup()
      metas: index.metas
      links: index.links
      scripts: index.scripts
      stylesheets: index.stylesheets
    }
    _.extend params, moreparams
    return index.template params


  return index
