fs = require 'fs'
path = require 'path'


global.otto = otto = {}    # our namespace
require './misc'      # attaches to global.otto.misc

otto.SECRET = 'FiiY3Xeiwie3deeGahBiu9ja'  # need to randomly generate this for each install FIXME

otto.OTTO_ROOT = path.dirname(fs.realpathSync(__filename))

if process.platform is 'darwin'
  library = otto.misc.expand_tilde '~/Library/Otto'
  if otto.misc.is_dirSync(library + '/var')  # for backwards compatability
    otto.OTTO_VAR =  library + '/var'
  else
    otto.OTTO_VAR =  library
else
  otto.OTTO_VAR          = otto.OTTO_ROOT    + '/var'
otto.misc.assert_is_dir_or_create_itSync otto.OTTO_VAR

otto.OTTO_VAR_MONGODB    = otto.OTTO_VAR  + '/mongodb'


require './main'

# client side
require './client'  # must be first

require '../server/index'
require './server'

otto.exiting = false
otto.main()
