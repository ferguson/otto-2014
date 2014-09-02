import objc
#from Foundation import *
#from AppKit import *
# we want the splash screen to come up fast, so only import the bare minimum
# we'll import much more after the splash screen is up
from Foundation import NSMakeRect
from AppKit import NSObject, NSApplication, NSApp, NSTimer, NSWindow, NSColor, NSBackingStoreBuffered, NSColor, NSImage, NSImageView, NSScaleToFit


class MyApp(NSApplication):

    def applicationWillFinishLaunching_(self, notification):
        print 'will finish launching'

    def finishLaunching(self):
        super(MyApp, self).finishLaunching()
        print 'finish launching'


class OttoDelegate(NSObject):

    def applicationDidFinishLaunching_(self, notification):
        makeMainMenu()
        closeSplash()
        NSApp.activateIgnoringOtherApps_(True)

    def applicationShouldTerminate_(self, notification):
        print 'quitting!'
        shutItDown()
        return True

    def about_(self, notification):
        openAbout()


splash = False

def openSplash():
    global splash
    splash = NSWindow.alloc()
    rect = NSMakeRect(0,0,240,420)
    styleMask = 0
    splash.initWithContentRect_styleMask_backing_defer_(rect, styleMask, NSBackingStoreBuffered, False)

    # http://stackoverflow.com/questions/19437580/splash-screen-in-osx-cocoa-app

    splashImage = NSImageView.alloc().initWithFrame_(rect)
    splashImage.setImageScaling_(NSScaleToFit)
    splashImage.setImage_(NSImage.imageNamed_('ottosplash.png'))
    #[customView addSubview:splashImage];

    #splash.setContentView_(webview)
    splash.setContentView_(splashImage)
    splash.setHasShadow_(True)
    splash.setOpaque_(False)
    splash.setBackgroundColor_(NSColor.clearColor())

    # xPos = NSWidth([[splashWindow screen] frame])/2 - NSWidth([splashWindow frame])/2;
    #CGFloat yPos = NSHeight([[splashWindow screen] frame])/2 - NSHeight([splashWindow frame])/2;
    #[splashWindow setFrame:NSMakeRect(xPos, yPos, NSWidth([splashWindow frame]), NSHeight([splashWindow frame])) display:YES];
    splash.center()
    splash.orderFrontRegardless()
    #splash.display()



def closeSplash():
    global splash
    splash.close()


about = False
aboutpolicy = False

class AboutPolicyDelegate(NSObject):
    def webView_decidePolicyForNavigationAction_request_frame_decisionListener_(self, webView, actionInformation, request, frame, listener):
        print 'link clicked:', request.URL()
        listener.ignore()
        if str(request.URL()).endswith('/license'):
            openLicense()
        elif str(request.URL()).endswith('/notices'):
            openNotices()
        else:
            #NSWorkspace.sharedWorkspace().openURL_(request.URL())  # this crashes for some reason
            subprocess.call(['open', str(request.URL())])

def openAbout():
    global about
    global aboutpolicy
    if not about:
        about = NSWindow.alloc()
        rect = Foundation.NSMakeRect(0,0,300,370)
        styleMask = NSTitledWindowMask | NSClosableWindowMask | \
            NSResizableWindowMask | NSMiniaturizableWindowMask
        about.initWithContentRect_styleMask_backing_defer_(rect, styleMask, NSBackingStoreBuffered, False)
        about.setTitle_('About Otto')
        #about.setBackgroundColor_(NSColor.blueColor()) # not working (try it on the webview instead)

        webview = WebKit.WebView.alloc()
        webview.initWithFrame_(rect)
        webview.setFrameLoadDelegate_(NSApp.delegate())

        respath = os.environ['RESOURCEPATH']
        print 'respath =', respath
        pageurl = Foundation.NSURL.URLWithString_('file://'+respath+'/static/html/about.html')
        aboutreq = Foundation.NSURLRequest.requestWithURL_(pageurl)
        webview.mainFrame().loadRequest_(aboutreq)

        aboutpolicy = AboutPolicyDelegate.alloc().init()
        webview.setPolicyDelegate_(aboutpolicy)

        about.setReleasedWhenClosed_(False)
        about.setContentView_(webview)

    if not about.isVisible():
      about.center()
      #about.display()
    about.orderFrontRegardless()
    about.makeKeyAndOrderFront_(None)


def makeMainMenu():
    # http://www.cocoawithlove.com/2010/09/minimalist-cocoa-programming.html
    # http://www.cocoabuilder.com/archive/cocoa/192181-initializing-the-menubar-without-interface-builder.html
    # By Robert Nikander via. https://github.com/albertz/music-player/blob/master/guiCocoa.py

    appName = NSProcessInfo.processInfo().processName()

    mainMenu = NSMenu.alloc().initWithTitle_('MainMenu')
    appleMenuItem = mainMenu.addItemWithTitle_action_keyEquivalent_('Apple', None, '')
    appleMenu = NSMenu.alloc().initWithTitle_('Apple')

    # strange hack (their comment, not mine -jon)
    NSApp.setAppleMenu_(appleMenu)
    mainMenu.setSubmenu_forItem_(appleMenu, appleMenuItem)

    NSApp.setMainMenu_(mainMenu)

    # Otto menu
    appleMenu.addItemWithTitle_action_keyEquivalent_('About '+appName, 'about:', '')
    appleMenu.addItem_(NSMenuItem.separatorItem())
    #appleMenu.addItemWithTitle_action_keyEquivalent_('Preferences...', 'preferences:', ',')
    #appleMenu.addItem_(NSMenuItem.separatorItem())
    appleMenu.addItemWithTitle_action_keyEquivalent_('Quit '+appName, 'terminate:', 'q')
    

def shutItDown():
    AppHelper.stopEventLoop()


def signalHandler(signum, frame):
    print 'Signal handler called with signal', signum
    shutItDown()
    #pool.release()


if __name__ == '__main__':
    #app = NSApplication.sharedApplication()
    app = MyApp.sharedApplication()
    #NSApp.setActivationPolicy_(NSApplicationActivationPolicyRegular)
    #NSMenu.setMenuBarVisible_(True)

    openSplash()

    # Bring app to top
    NSApp.activateIgnoringOtherApps_(True)

    delegate = OttoDelegate.alloc().init()
    app.setDelegate_(delegate)
    from Foundation import *

    from AppKit import *
    import WebKit
    #from Quartz import CGEventTapCreate, CGEventMaskBit, kCGSessionEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault
    import Quartz
    from PyObjCTools import NibClassBuilder, AppHelper

    app.setPresentationOptions_(NSFullScreenWindowMask)

    import os
    import signal

    #signal.signal(signal.SIGCHLD, signalHandler)
    signal.signal(signal.SIGINT, signalHandler)

    #app.run()  # can't use AppHelper.stopEventLoop() to exit if we do this
    AppHelper.runEventLoop()

    #pool.release()
