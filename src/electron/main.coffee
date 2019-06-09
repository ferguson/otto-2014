{ ipcMain, app, Menu, Tray, BrowserWindow } = require 'electron'
windowStateKeeper = require 'electron-window-state'

otto_misc = require '../server/misc.coffee'
menus = require './menus.coffee'
tray = require './tray.coffee'

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
    console.log 'app.getName()', app.getName()
    #menus.makeMenus()
    tray.makeTray()

    mainWindowState = windowStateKeeper
      defaultWidth: 1020,
      defaultHeight: 800,

    createBackendWindow()
    createSplashScreen()

    #setTimeout(app.quit, 10000)


cleanup_processes = () =>
  OTTO_VAR = otto_misc.expand_tilde '~/Library/Otto'
  OTTO_VAR_MPD = OTTO_VAR + '/mpd'
  otto.misc.kill_from_pid_fileSync "#{OTTO_VAR_MPD}/[0-9]*pid"
  otto.misc.kill_from_pid_fileSync "#{OTTO_VAR}/mongod.pid"

# cmd-q
app.on 'will-quit', () =>
  console.log 'will-quit'
  cleanup_processes()
  console.log 'cleaned up'

## ctrl-c
#process.on 'SIGINT', () =>
#  console.log 'SIGINT'
#  cleanup_processes()
#  console.log 'cleaned up'

## kill (default)
#process.on 'SIGTERM', () =>
#  console.log 'SIGTERM'
#  cleanup_processes()
#  console.log 'cleaned up'
