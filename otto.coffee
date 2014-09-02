fs = require 'fs'
path = require 'path'
#posix = require 'posix'
posix = require 'fs'
#require('epipebomb')()


global.otto = otto = {}    # our namespace
require './otto.misc'      # attaches to global.otto.misc

otto.MUSICROOT_SEARCHLIST =
[
  { dir: '/otto/u', strip: no }       # linux, multiuser
  { dir: '~/Music', strip: 'Music' }  # osx, others, singleuser
]

otto.SECRET = 'FiiY3Xeiwie3deeGahBiu9ja'  # need to randomly generate this for each install FIXME

otto.OTTO_ROOT = path.dirname(fs.realpathSync(__filename))

otto.OTTO_BIN            = otto.OTTO_ROOT    + '/bin'
otto.OTTO_LIB            = otto.OTTO_ROOT    + '/lib'

if process.platform is 'darwin'
  otto.OTTO_LIBRARY = otto.misc.expand_tilde '~/Library/Otto'
  otto.misc.assert_is_dir_or_create_itSync otto.OTTO_LIBRARY
  otto.OTTO_VAR =  otto.OTTO_LIBRARY + '/var'
else
  otto.OTTO_VAR          = otto.OTTO_ROOT    + '/var'
otto.misc.assert_is_dir_or_create_itSync otto.OTTO_VAR

otto.OTTO_VAR_MPD        = otto.OTTO_VAR     + '/mpd'
otto.OTTO_VAR_MPD_MUSIC  = otto.OTTO_VAR_MPD + '/music'
otto.MPD_EXECUTABLE      = otto.OTTO_BIN     + '/mpd'
otto.misc.assert_is_dir_or_create_itSync otto.OTTO_VAR_MPD
otto.misc.assert_is_dir_or_create_itSync otto.OTTO_VAR_MPD_MUSIC

otto.OTTO_VAR_MONGODB    = otto.OTTO_VAR  + '/mongodb'
otto.MONGOD_EXECUTABLE   = otto.OTTO_BIN  + '/mongod'
otto.misc.assert_is_dir_or_create_itSync otto.OTTO_VAR_MONGODB
# we should probably also test for the BINs

if process.env['USER'] is 'root'
  # safer to not run as root
  # and as root, mpd can't use file:///
  # also: mpd can not use file:/// under Windows at all (not related to root)
  otto.OTTO_SPAWN_AS_UID = posix.getpwnam('jon').uid  # oh boy. FIXME


if process.platform is 'darwin'
  try
    posix.setrlimit('nofile', { soft: 10000, hard: 10000 })
  catch error
    #console.log '###'
    #console.log '### setting file limit failed: ' + error
    #console.log '###'


otto.channelinfolist = [
  {name: 'main',   fullname: 'Main Channel',   type: 'standard', layout: 'standard'},
  {name: 'second', fullname: 'Second Channel', type: 'standard', layout: 'standard'}
  {name: 'third',  fullname: 'Third Channel',  type: 'standard', layout: 'standard'}
]


require './otto.misc'      # attaches to global.otto.misc
require './otto.events'    # attaches to global.otto.events
require './otto.db'        # etc...
require './otto.mpd'
require './otto.listeners'
require './otto.channels'
require './otto.loader'
require './otto.index'
require './otto.zeroconf'
#require './otto.menu'
require './otto.main'

# client side
require './otto.client'  # must be first
require './otto.client.templates'
require './otto.client.misc'
require './otto.client.player'
require './otto.client.soundfx'
require './otto.client.cubes'

require './otto.server'

otto.exiting = false
otto.main()

