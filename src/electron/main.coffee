{ ipcMain, app, Menu, BrowserWindow } = require 'electron'
windowStateKeeper = require 'electron-window-state'

mainWindowState = null
splashScreen = null

# Create a hidden background window for the backend
createBackendWindow = () =>
  result = new BrowserWindow
    show: false
    partition: 'persist:otto'
    webPreferences: { nodeIntegration: true }
  result.loadFile 'src/electron/backend.html'
  result.webContents.openDevTools()
  result.on 'ready-to-show', () =>
    result.webContents.openDevTools()
  result.on 'closed', () =>
    console.log 'backend window closed'
  return result

createSplashScreen = () =>
  splashScreen = new BrowserWindow
    show: false
    width: 240
    height: 420
    frame: false
    transparent: true
    #backgroundColor: '#FF77FFFF'
  splashScreen.loadFile 'static/images/ottosplash.png'
  splashScreen.once 'ready-to-show', () =>
    splashScreen.show();

createBrowserWindow = () =>
  # Create the main browser window.
  win = new BrowserWindow
    show: false
    x: mainWindowState.x
    y: mainWindowState.y
    width: mainWindowState.width
    height: mainWindowState.height
    partition: 'persist:otto'
    webPreferences: { nodeIntegration: true }

  mainWindowState.manage win

  # load the main window
  win.loadURL 'http://localhost:8778'
  win.once 'ready-to-show', () =>
    win.openDevTools()
    win.show()

serverReady = () =>
  createBrowserWindow();
  splashScreen.close();

ipcMain.on 'server-ready', serverReady

app.on 'ready', () =>
    console.log 'ready event'
    #makeMenus()
    mainWindowState = windowStateKeeper
      defaultWidth: 1020,
      defaultHeight: 800,

    createBackendWindow()
    createSplashScreen()


makeMenus = () =>
  console.log 'app.getName()', app.getName()
  template = [
    # { role: 'appMenu' }
    [{
      label: app.getName(),
      submenu: [
        { role: 'about' },
        { type: 'separator' },
        { role: 'services' },
        { type: 'separator' },
        { role: 'hide' },
        { role: 'hideothers' },
        { role: 'unhide' },
        { type: 'separator' },
        { role: 'quit' }
      ]
    }],
    # { role: 'fileMenu' }
    {
      label: 'File',
      submenu: [
        { role: 'close' }
      ]
    },
    # { role: 'editMenu' }
    {
      label: 'Edit',
      submenu: [
        { role: 'undo' },
        { role: 'redo' },
        { type: 'separator' },
        { role: 'cut' },
        { role: 'copy' },
        { role: 'paste' },
        { role: 'pasteAndMatchStyle' },
        { role: 'delete' },
        { role: 'selectAll' },
        { type: 'separator' },
        {
          label: 'Speech',
          submenu: [
            { role: 'startspeaking' },
            { role: 'stopspeaking' }
          ]
        }
      ]
    },
    # { role: 'viewMenu' }
    {
      label: 'View',
      submenu: [
        { role: 'reload' },
        { role: 'forcereload' },
        { role: 'toggledevtools' },
        { type: 'separator' },
        { role: 'resetzoom' },
        { role: 'zoomin' },
        { role: 'zoomout' },
        { type: 'separator' },
        { role: 'togglefullscreen' }
      ]
    },
    {
      label: 'Channels',
      submenu: [
        { label: 'One', role: 'channelone' },
      ]
    },
    # { role: 'windowMenu' }
    {
      label: 'Window',
      submenu: [
        { role: 'minimize' },
        { role: 'zoom' },
        { type: 'separator' },
        { role: 'front' },
        { type: 'separator' },
        { role: 'window' }
      ]
    },
    {
      role: 'help',
      submenu: [
        {
          label: 'Learn More'
        }
      ]
    }
  ]

  menu = Menu.buildFromTemplate(template)
  Menu.setApplicationMenu(menu)
