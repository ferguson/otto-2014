mdns = require 'mdns'

global.otto = otto = global.otto || {}

module.exports = global.otto.menu = do ->  # note the 'do' causes the function to be called
  menu = {}

  menu.startup = ->
    #otto.start_win.hide()

    # this loses the node-webkit context (fixed in 0.3.7? <-no)

    #otto.win = otto.gui.Window.open.call otto.window, 'http://localhost:8778'
    #  width: 1200
    #  height: 1000
    #  show: true
    #  toolbar: true
    #  frame: true

    #otto.win = otto.gui.Window.get(
    #  otto.window.open('http://localhost:8778/phase', '_blank', 'width=1200,height=1000')
    #)

    #if global.listening
    #  callback 'http://jon.local:8778'
    #else
    #  global.on_listening = ->
    #    callback 'http://jon.local:8778'

    # Create a tray icon
    console.log '##'
    console.log otto.gui
    console.log '##'

    otto.tray = new otto.gui.Tray icon: 'static/images/osxmenubaricon.png'

    # Give it a menu
    otto.menu = new otto.gui.Menu()
    otto.menuitems = []
    otto.tray.menu = otto.menu;

    # Remove the tray
    #otto.tray.remove()
    #otto.menuitem = null
    #otto.menu = null
    #otto.tray = null

    browser = mdns.createBrowser mdns.tcp('otto')

    console.log 'registering serviceUp handler'
    browser.on 'serviceUp', (service) ->
      console.log 'service up: ', service.name, service.addresses[0], service.port
      newitem = new otto.gui.MenuItem type: 'normal', label: service.name, click: ->
        # going to need to wrap this in a closure to get the item context
        console.log 'menu item selected'
      otto.menuitems.push newitem
      otto.menu.append newitem

    console.log 'registering serviceDown handler'
    browser.on 'serviceDown', (service) ->
      console.log 'service down: ', service.name
      for menuitem,i in otto.menuitems
        if menuitem.label is service.name
          otto.menu.remove(menuitem)
          otto.menuitems[i] = null
          otto.menuitems.splice(i, 1)
          break

    console.log 'starting up mdns browser'
    browser.start()

    otto.mdns_browser = browser


  return menu