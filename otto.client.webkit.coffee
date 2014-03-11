###############
### client side (otto.client.webkit.coffee served as /otto.webkit.js)
###############

global.otto.client.webkit = ->
  window.otto.client.webkit = do ->  # note the 'do' causes the function to be called

    webkit = {}


    webkit.init = ->
      console.log window.process.versions['node-webkit']

      #if process.versions['node-webkit']
      #  gui = require 'nw.gui'
      #  win = gui.Window.get()
      #  # Save size on close.
      #  win.on 'close', ->
      #    localStorage.x      = win.x
      #    localStorage.y      = win.y
      #    localStorage.width  = win.width
      #    localStorage.height = win.height
      #    console.log 'closing!'
      #    this.close(true)

      console.log 'node-webkit?'
      # hmmm... very strange, we don't seem to have the node-webkit stuff
      try
        gui = require 'nw.gui'
        console.log 'trying to show node-webkit window'
        win = gui.Window.get()
        win.show()
        win.focus()
        console.log 'done showing'
      catch err
        console.log 'not running under node-webkit'

      console.log 'window.show:'
      try
        console.log window.show
        console.log window.focus
      catch err
        console.log 'err'


    return webkit
