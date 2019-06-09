{ Tray, Menu } = require 'electron'

tray = {}

ourTray = null

tray.makeTray = () =>
  template =
  [
    { label: 'Play/Pause', role: 'togglePlay' },
    { label: 'Next', role: 'next' },
    { label: 'Main Window', role: 'mainWindow' },
    { type: 'separator' },
    { label: 'Scan Music', role: 'loadMusic' },
    { type: 'separator' },
    { label: 'Quit Otto', role: 'quit' },
  ]

  trayMenu = Menu.buildFromTemplate(template)

  ourTray = new Tray 'assets/osxmenubaricon.png'  # 'static/images/osxmenubaricon.png'  # FIXME
  ourTray.setToolTip 'Otto'
  ourTray.setContextMenu(trayMenu)


module.exports = tray