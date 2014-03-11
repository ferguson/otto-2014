##### live dev module. only loaded in 'development' mode

fs = require 'fs'
glob = require 'glob'

otto = global.otto


module.exports = global.otto.livedev = do ->  # note the 'do' causes the function to be called
  livedev = {}

  #otto.development = true


  reload_module = (name) ->
    # remove from require cache
    for own path of require.cache
      if otto.misc.endsWith path, '/' + name
        console.log "removing #{path} from require.cache"
        delete require.cache[path]
        break
    console.log "reloading module #{name}"
    require './' + name


  fs.watchFile 'otto.client.coffee', interval: 200, =>  # 200ms drains batteries
    filename = 'otto.client.coffee'
    #code = fs.readFileSync filename, 'utf8'
    #CoffeeScript.run(code.toString(), {filename: file})
    # save names of loaded client modules so we can reload them too
    client_modules = []
    for own modulename of otto.client
      client_modules.push modulename
    console.log "#{filename} changed..."
    reload_module filename
    # since we wiped otto.client, we also need to reload
    # all the other client modules since they bind to it
    for modulename in client_modules
      reload_module "otto.client.#{modulename}.coffee"
    otto.zappa.io.sockets.emit 'reloadself', filename


  glob 'otto.client.*.coffee', (err, filenames) =>
    for filename in filenames
      do (filename) =>  # to each his own
        console.log "watching #{filename}"
        fs.watchFile filename, interval: 200, =>  # 200ms drains batteries
          console.log "#{filename} changed..."
          reload_module filename
          otto.zappa.io.sockets.emit 'reloadmodule', filename


  glob 'static/css/*.css', (err, filenames) =>
    for filename in filenames
      do (filename) =>  # to each his own
        console.log "watching #{filename}"
        fs.watchFile filename, interval: 200, =>  # 200ms drains batteries
          console.log "#{filename} changed..."
          css = fs.readFileSync filename, 'utf8'
          sheetname = filename.match(/([^\/]*.css)$/)[1]
          otto.zappa.io.sockets.emit 'restyle', filename: filename, sheetname: sheetname, css: css


  return livedev
