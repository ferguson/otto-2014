#{ipcRenderer} = require 'electron'
electron = require 'electron'
ipcRenderer = electron.ipcRenderer

require '../otto'

# Send logs as messages to the main thread to show on the console
log = (value) =>
  console.log value
  ipcRenderer.send 'to-main', process.pid + ': ' + value

# let the main thread know this thread is ready to process something
ready = () =>
  console.log 'ready'
  ipcRenderer.send 'ready'

# if message is received, pass it back to the renderer via the main thread
ipcRenderer.on 'message', (event, arg) =>
  log 'received ' + arg
  ipcRenderer.send 'for-renderer', process.pid + ': reply to ' + arg
  ready()

global.otto.main () =>
  console.log 'server ready'
  ipcRenderer.send 'server-ready'
  #not reliable enough (see NOTES)
  #window.addEventListener 'unload', () =>
  #  console.log 'cleaning up processes'
  #  global.otto.cleanup_processes()
