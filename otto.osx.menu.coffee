nodeobjc = require 'NodObjC'
nodobjc.import 'Cocoa'

pool = nodobjc.NSAutoreleasePool('alloc')('init')
app  = nodobjc.NSApplication 'sharedApplication'

# set up the app delegate
AppDelegate = nodobjc.NSObject.extend 'AppDelegate'
AppDelegate.addMethod 'applicationDidFinishLaunching:', 'v@:@', (self, _cmd, notif) ->
  systemStatusBar = nodobjc.NSStatusBar 'systemStatusBar'
  statusMenu = systemStatusBar 'statusItemWithLength', nodobjc.NSVariableStatusItemLength
  statusMenu 'retain'
  title = nodobjc.NSString 'stringWithUTF8String', 'otto'
  statusMenu 'setTitle', title

AppDelegate.register()

delegate = AppDelegate('alloc')('init')
app 'setDelegate', delegate

app 'activateIgnoringOtherApps', true
app 'run'

pool 'release'
