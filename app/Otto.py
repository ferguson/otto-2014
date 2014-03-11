import objc, re, os
from Foundation import *
from AppKit import *
from PyObjCTools import NibClassBuilder, AppHelper
import subprocess
import signal
import socket

# something in this next section kills it on 10.9
#import sys
#print sys.path
#try:
#  print os.environ['PYTHONPATH']
#except KeyError:
#  print 'no PYTHONPATH'


app = False

#status_images = {'idle':'/usr/local/otto/static/images/osxmenubaricon.png'}
status_images = {'idle':'static/images/osxmenubaricon.png'}

start_time = NSDate.date()

#class Timer(NSObject):
#class Timer(NSWindowController):
class Timer(NSViewController):
  images = {}
  statusbar = None
  state = 'idle'
  browser_launched = False

  def applicationDidFinishLaunching_(self, notification):
    statusbar = NSStatusBar.systemStatusBar()
    # Create the statusbar item
    self.statusitem = statusbar.statusItemWithLength_(NSVariableStatusItemLength)
    # Load all images
    for i in status_images.keys():
      self.images[i] = NSImage.alloc().initByReferencingFile_(status_images[i])
    # Set initial image
    self.statusitem.setImage_(self.images['idle'])
    # Let it highlight upon clicking
    self.statusitem.setHighlightMode_(1)
    # Set a tooltip
    self.statusitem.setToolTip_('Play')

    # Build a very simple menu
    self.barmenu = NSMenu.alloc().init()
    # Play event is bound to play_ method
    #menuitem = NSMenuItem.alloc().initWithTitle_action_keyEquivalent_('Play...', 'play:', '')
    #self.barmenu.addItem_(menuitem)
    menuitem = NSMenuItem.alloc().initWithTitle_action_keyEquivalent_('Browser', 'browser:', '')
    self.barmenu.addItem_(menuitem)
    menuitem = NSMenuItem.alloc().initWithTitle_action_keyEquivalent_('Load', 'load:', '')
    self.barmenu.addItem_(menuitem)
    # Default event
    #menuitem = NSMenuItem.alloc().initWithTitle_action_keyEquivalent_('Quit', 'terminate:', '')
    menuitem = NSMenuItem.alloc().initWithTitle_action_keyEquivalent_('Quit', 'quit:', '')
    self.barmenu.addItem_(menuitem)
    # Bind it to the status item
    self.statusitem.setMenu_(self.barmenu)

    if False:
        #mainMenu = NSApplication.mainMenu()
        self.menu = NSMenu.alloc().init()
        #self.menu = app.mainMenu_()
        print self.menu
        menuitem = NSMenuItem.alloc().initWithTitle_action_keyEquivalent_('Quit', 'quit:', 'Q')
        print menuitem
        self.menu.addItem_(menuitem)
        app.setMainMenu_(self.menu)
        #NSApplication.setMainMenu_(self.menu)

    #os.chdir('/usr/local/otto')
    
    #RESOURCES_DIR=os.path.dirname(os.path.realpath(__file__))  # fails in py2app -A mode
    RESOURCES_DIR=os.getcwd()
    os.environ['DYLD_FALLBACK_LIBRARY_PATH'] = RESOURCES_DIR+'/lib'
    os.environ['LD_LIBRARY_PATH'] = RESOURCES_DIR+'/lib'
    os.environ['PATH'] = RESOURCES_DIR+'/bin' + ':'+os.environ['PATH']
    print os.environ['PATH']
    print "before"
    self.server_process = subprocess.Popen(['coffee', 'otto.coffee'])
    print "after"
    print self.server_process
    print "pid = ", self.server_process.pid
    
    # Get the timer going
    #self.timer = NSTimer.alloc().initWithFireDate_interval_target_selector_userInfo_repeats_(start_time, 5.0, self, 'tick:', None, True)
    self.timer = NSTimer.alloc().initWithFireDate_interval_target_selector_userInfo_repeats_(start_time, 0.5, self, 'tick:', None, True)
    NSRunLoop.currentRunLoop().addTimer_forMode_(self.timer, NSDefaultRunLoopMode)
    self.timer.fire()
    print "done"


  @objc.IBAction
  def play_(self, notification):
    print "play"

  @objc.IBAction
  def browser_(self, notification):
    if subprocess.call(['open', '-a', 'Google Chrome', 'http://localhost:8778/']):
      subprocess.call(['open', 'http://localhost:8778/'])
    
  @objc.IBAction
  def load_(self, notification):
    self.loader_process = subprocess.Popen(['python', 'loader.py'])


  def tick_(self, notification):
    #print self.state
    #print self.server_process.poll()
    #print "tick"
    if self.server_process.poll():
      print "server exited."
      AppHelper.stopEventLoop()
    elif not self.browser_launched:
      sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
      result = sock.connect_ex(('127.0.0.1',8778))
      sock.close()
      if result == 0:
        self.browser_launched = True
        if subprocess.call(['open', '-a', 'Google Chrome', 'http://localhost:8778/']):
          print "no chrome, falling back to Safari (or whatever the default browser is)"
          subprocess.call(['open', 'http://localhost:8778/'])
      

  @objc.IBAction
  def quit_(self, notification):
    print "quitting!"
    shutitdown()


def shutitdown():
  try:
    #os.killpg(server_process.pid, signal.SIGTERM)
    print delegate.server_process
    print "pid = ", delegate.server_process.pid
    #os.killpg(delegate.server_process.pid, signal.SIGINT)
    try:
      delegate.server_process.send_signal(signal.SIGINT)
      delegate.server_process.wait()
    except:
      pass
    #delegate.terminate_(notification)
  except AttributeError:
    pass
  AppHelper.stopEventLoop()

def handler(signum, frame):
  print 'Signal handler called with signal', signum
  shutitdown()

if __name__ == "__main__":
  #print __file__
  #print os.path.dirname(os.path.realpath(__file__))
  #print os.getcwd()

  #signal.signal(signal.SIGINT, handler)
  #signal.signal(signal.SIGCHLD, handler)
  signal.signal(signal.SIGINT, handler)

  app = NSApplication.sharedApplication()

  #NibClassBuilder.extractClasses('Otto')

  #delegate = Timer.alloc().init()
  #delegate = Timer.alloc().initWithWindowNibName_("Otto")
  #delegate = Timer.alloc().initWithNibName_("Otto")
  #delegate = Timer.alloc().initWithNibName("Otto")
  delegate = Timer.alloc().init()
  app.setDelegate_(delegate)

  ## Initiate the controller with a XIB (NIB?)
  #viewController = Simple.alloc().initWithWindowNibName_("Otto")

  # Show the window
  #viewController.showWindow_(viewController)
  #delegate.showWindow_(delegate)

  # Bring app to top
  NSApp.activateIgnoringOtherApps_(True)

  AppHelper.runEventLoop()
