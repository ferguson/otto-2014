# these are here just to force py2app to include them as they are used by scan.py
import json
import getpass
import hashlib

import sys
print >>sys.stderr, sys.argv[0], 'python', sys.executable, 'version', sys.version

import objc
#from Foundation import *
#from AppKit import *
# we want the splash screen to come up fast, so only import the bare minimum
# we'll import much more after the splash screen is up
from Foundation import NSMakeRect
from AppKit import NSObject, NSApplication, NSApp, NSTimer, NSWindow, NSColor, NSBackingStoreBuffered, NSColor, NSImage, NSImageView, NSScaleToFit
from socketIO_client import SocketIO, BaseNamespace

FLT_MAX = 3.40282347e+38

# remember that long output strings kills things on 10.9

# this looks promising for a global hot key:
# https://pythonhosted.org/pyobjc/examples/Cocoa/AppKit/HotKeyPython/index.html
# requires 32 bit mode which you can force in your Info.plist:(this wasn't working for me)
#   <key>LSArchitecturePriority</key>
#   <array>
#     <string>i386</string>
#   </array>

kEventHotKeyPressedSubtype = 6
kEventHotKeyReleasedSubtype = 9

class HotKeyApp(NSApplication):

    # from http://fredandrandall.com/blog/2011/07/30/how-to-launch-your-macios-app-with-a-custom-url/
    # see also http://lethain.com/how-to-use-selectors-in-pyobjc/
    # not working
    def applicationWillFinishLaunching_(self, notification):
        print 'installing url handler'
        appleeventmanager = NSAppleEventManager.sharedAppleEventManager()
        appleeventmanager.setEventManager_andSelector_forEventClass_andEventID_(
            self, objc.selector(self.handleGetURLEvent_, 'v@:@:'), kInternetEventClass, kAEGetURL
        )

    def handleGetURLEvent_withReplyEvent_(self, event, replyevent):
        print 'handling url'
        urlstr = event.paramDescriptorForKeyword_(keyDirectObject).stringValue()
        print 'urlstring =', urlstr
        #url = NSURL.URLWithString_(urlstr)

    def finishLaunching(self):
        super(HotKeyApp, self).finishLaunching()
        print hotkeys
        #print hasattr(Carbon.CarbonEvt, 'RegisterEventHotKey')
        if hotkeys:
            print 'registering hot keys!'
            # register cmd-control-J
            #self.hotKeyRef = RegisterEventHotKey(38, cmdKey | controlKey, (0, 0),
            # key ref http://snipplr.com/view/42797/
            # F7=0x62 F8=0x64 F9=0x65
            #self.hotKeyRef1 = RegisterEventHotKey(0x62, 0, (0, 0),
            #                                     GetApplicationEventTarget(), 0)
            self.hotKeyRef2 = RegisterEventHotKey(0x64, 0, (0, 0),
                                                 GetApplicationEventTarget(), 0)
            #self.hotKeyRef3 = RegisterEventHotKey(0x65, 0, (0, 0),
            #                                     GetApplicationEventTarget(), 0)
        else:
            print 'could not register hot keys! not running in 32 bit mode?'


    def sendEvent_(self, event):

        # Catch media key events
        # http://stackoverflow.com/questions/3885302/make-my-cocoa-app-respond-to-the-keyboard-play-pause-key
        # http://weblog.rogueamoeba.com/2007/09/29/
        # this works lovely except it launches iTunes. :(
        # perhaps this could be instructive: https://github.com/nevyn/SPMediaKeyTap
        # http://stackoverflow.com/questions/2969110/cgeventtapcreate-breaks-down-mysteriously-with-key-down-events
        # http://overooped.com/post/2593597587/mediakeys
        # https://github.com/nevyn/SPMediaKeyTap  # this is the real way to do it
        if event.type() == NSSystemDefined and event.subtype() == 8:
            keyCode = (event.data1() & 0xFFFF0000) >> 16
            keyFlags = event.data1() & 0x0000FFFF
            keyState = ((keyFlags & 0xFF00) >> 8) == 0xA

            # Process the media key event and return
            # w/o passing on the event (prevents iTunes from launching?)
            if mediaKeyEvent(keyCode, keyState):
                return None

        if event.type() == NSSystemDefined and \
               event.subtype() == kEventHotKeyPressedSubtype:
            print 'hotkeyevent'
            print event

            # i can't figure out how to tell which hot key was pressed

            # http://www.cocoabuilder.com/archive/cocoa/310086-how-to-get-key-code-from-sysdefined-carbon-event.html
            # https://code.google.com/r/evilphillip-cocoa-ctypes/source/browse/pyglet/window/carbon/__init__.py?name=holkner_1
            #    carbonEvent,
            #    kEventParamDirectObject,
            #    typeEventHotKeyID,
            #    NULL,
            #    sizeof(EventHotKeyID),
            #    NULL,
            #    &hotKeyID) ;

            """
            hotKeyID = '        '
            GetEventParameter(event, Carbon.kEventParamDirectObject,
                              Carbon.typeEventHotKeyID, None, 8, None, hotKeyID)
            print hotKeyID
            #self.activateIgnoringOtherApps_(True)
            #NSRunAlertPanel(u'Hot Key Pressed', u'Hot Key Pressed',
            #    None, None, None)
            """
            #emit('next')
            emit('delete')
            
        super(HotKeyApp, self).sendEvent_(event)


    def webView_didFinishLoadForFrame_(self, webview, notification):
        print 'frame loaded'

    def webView_didStartProvisionalLoadForFrame_(self, webview, notification):
        print 'frame load started'

    def webView_didReceiveTitle_forFrame_(self, webview, title, frame):
        print 'frame title ' + title


def mediaKeyEvent(key, state):
    if key == 19:    # >>
        if state:
            #emit('next')
            emit('delete')
    elif key == 16:  # >"
        if state:
            emit('toggleplay')
    elif key == 20:  # <<
        if state:
            openMainWindow()
    else:
        return False
    return True


# perhaps a more modern way to do hot keys:
# http://stackoverflow.com/questions/8201338/how-to-implement-shortcut-key-input-in-mac-cocoa-app
# (not ideal, requires acessibility to be enabled, see NSEvent docs)
#def hotKeyHandler(event):
#  print 'hotKeyHandler!'
#eventMonitor = NSEvent.addGlobalMonitorForEventsMatchingMask_handler_( NSKeyDownMask, hotKeyHandler)

# let's try an event tap

eventTap = False

def createEventTap():
    global eventTap
    print 'about to create event tap'
    # i change the event tap to listen only as we we've been unable to block media key events
    # more importantly it was causing all kinds of ui response problems, like ignoring first click
    eventTap = CGEventTapCreate(kCGSessionEventTap,
                                     kCGHeadInsertEventTap,  # kCGTailAppendEventTap,
                                     kCGEventTapOptionListenOnly,  # kCGEventTapOptionDefault,
                                     CGEventMaskBit(14),  # 14 = NX_SYSDEFINED
                                     tapEventCallback,
                                     None)  # <- refcon
    print 'eventTap =', eventTap
  
def tapEventCallback(proxy, type, event, refcon):
      print 'woo!'
      pool = NSAutoreleasePool.new()
      ret = tapEventCallback2(proxy, type, event, refcon)
      pool.drain()
      return ret

def tapEventCallback2(proxy, type, event, refcon):
      #SPMediaKeyTap *self = refcon;
      if (type == kCGEventTapDisabledByTimeout):
          print 'Media key event tap was disabled by timeout'
          #CGEventTapEnable(self->_eventPort, TRUE);
          return event
      elif (type == kCGEventTapDisabledByUserInput):
          # Was disabled manually by -[pauseTapOnTapThread]
          return event

      #NSEvent *nsEvent = nil;
      try:
          nsEvent = NSEvent.eventWithCGEvent_(event)
      except:
          print 'Strange CGEventType'  #: %d: %@", type, e);
          return event
  
      print 'type =', type, 'NSSystemDefined', NSSystemDefined
      #if (type != NX_SYSDEFINED or nsEvent.subtype() != SPSystemDefinedEventMediaKeys):
      if (type != 14 or nsEvent.subtype() != SPSystemDefinedEventMediaKeys):
          return event
  
      keyCode = (event.data1() & 0xFFFF0000) >> 16
      keyFlags = event.data1() & 0x0000FFFF
      keyState = ((keyFlags & 0xFF00) >> 8) == 0xA

      #if (keyCode != NX_KEYTYPE_PLAY && keyCode != NX_KEYTYPE_FAST && keyCode != NX_KEYTYPE_REWIND && keyCode != NX_KEYTYPE_PREVIOUS && keyCode != NX_KEYTYPE_NEXT)
      #return event;
  
      #if (![self shouldInterceptMediaKeyEvents])
      #return event;
  
      print 'omg, i blocked it!'
      #nsEvent retain]; // matched in handleAndReleaseMediaKeyEvent:
      #    [self performSelectorOnMainThread:@selector(handleAndReleaseMediaKeyEvent:) withObject:nsEvent waitUntilDone:NO];
  
      return None
  
  
class OttoDelegate(NSObject):

    def applicationDidFinishLaunching_(self, notification):
        makeMainMenu()
        makeStatusBarMenu()
        makeDockMenu()
        startItUp()
        startWatchdog()

    def applicationShouldTerminate_(self, notification):
        print 'quitting!'
        shutItDown()
        return True

    def play_(self, notification):
        emit('play')

    def pause_(self, notification):
        emit('pause')

    def pauseifnot_(self, notification):
        print 'pauseifnot'
        emit('pauseifnot')

    def togglePlay_(self, notification):
        emit('toggleplay')

    def next_(self, notification):
        #emit('next')
        emit('delete')

    def mainWindow_(self, notification):
        openMainWindow()

    def browser_(self, notification):
        openWebBrowser()

    def loadMusic_(self, notification):
        #loader_process = subprocess.Popen(['python', 'loader.py'])
        emit('loadmusic')
        pass

    def serverReady(self):
        print 'OttoDelegate#serverReady'
        closeSplash()
        #openWebBrowser()

        cookies = getSessionCookie()
        openSocketIO(cookies)
        NSApp.activateIgnoringOtherApps_(True)
        openMainWindow()  # uses cookies directy from the shared cookie storage, Safari does too
        return
        

    def about_(self, notification):
        openAbout()


    def webView_didFinishLoadForFrame_(self, webview, notification):
        print 'frame 2 loaded'

    def webView_didStartProvisionalLoadForFrame_(self, webview, notification):
        print 'frame 2 load started'

    def webView_didReceiveTitle_forFrame_(self, webview, title, frame):
        print 'frame 2 title ' + title


def emit(name, *args):
    if sio:
        print 'sending', name
        if args:
          sio.emit(name, args)
        else:
          sio.emit(name)


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
    #del splash
    #splash = False
    #splash.close()


linkpolicy = False

class LinkPolicyDelegate(NSObject):

    def webView_decidePolicyForNavigationAction_request_frame_decisionListener_(self, webView, action, request, frame, listener):
        print 'link clicked:', request.URL()
        #print 'action:', action
        #print 'action type:', action['WebActionNavigationTypeKey']
        #print 'reload type', WebKit.WebNavigationTypeReload
        if action['WebActionNavigationTypeKey'] == WebKit.WebNavigationTypeReload:
            listener.use()
        else:
            listener.ignore()
            if str(request.URL()).endswith('/license'):
                openLicense()
            elif str(request.URL()).endswith('/notices'):
                openNotices()
            else:
                #NSWorkspace.sharedWorkspace().openURL_(request.URL())  # this crashes for some reason
                subprocess.call(['open', str(request.URL())])

    # this one is for links with a 'target' attribute
    def webView_decidePolicyForNewWindowAction_request_newFrameName_decisionListener_(self, webView, actionInformation, request, newFrameName, listener):
        # punt to the regular link handeler above
        self.webView_decidePolicyForNavigationAction_request_frame_decisionListener_(webView, actionInformation, request, None, listener)
        


about = False

def openAbout():
    global about
    global linkpolicy
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
        pageurl = Foundation.NSURL.URLWithString_('file://'+respath+'/static/html/about.html')
        aboutreq = Foundation.NSURLRequest.requestWithURL_(pageurl)
        webview.mainFrame().loadRequest_(aboutreq)

        if not linkpolicy:
            linkpolicy = LinkPolicyDelegate.alloc().init()
        webview.setPolicyDelegate_(linkpolicy)

        about.setReleasedWhenClosed_(False)
        about.setContentView_(webview)

    if not about.isVisible():
      about.center()
      #about.display()
    about.orderFrontRegardless()
    about.makeKeyAndOrderFront_(None)


license = False

def openLicense():
    global license
    if not license:
        license = NSWindow.alloc()
        rect = Foundation.NSMakeRect(100,100,570,440)
        #styleMask = NSTitledWindowMask | NSClosableWindowMask | \
        #    NSResizableWindowMask | NSMiniaturizableWindowMask
        styleMask = NSTitledWindowMask | NSClosableWindowMask | \
            NSMiniaturizableWindowMask
        license.initWithContentRect_styleMask_backing_defer_(rect, styleMask, NSBackingStoreBuffered, False)
        license.setTitle_('Otto License')
        #license.setBackgroundColor_(NSColor.blueColor()) # not working
        #license.setFrameAutosaveName_('licenseWindow')
        license.setFrameTopLeftPoint_( NSPoint(200, NSHeight(license.screen().frame()) - 100) )

        textview = NSTextView.alloc()
        textview.initWithFrame_(rect)
        textview.setEditable_(False)
        textview.setSelectable_(True)

        respath = os.environ['RESOURCEPATH']
        try:
            with codecs.open( os.path.join(respath, 'LICENSE'), 'r', 'utf-8') as f:
                licensetext = f.read()
        except IOError:
            licensetext = 'Could not read LICENSE file.'
        storage = textview.textStorage()
        nsstring = NSAttributedString.alloc().initWithString_(licensetext)
        storage.insertAttributedString_atIndex_(nsstring, 0)

        license.setReleasedWhenClosed_(False)
        license.setContentView_(textview)

    #if not license.isVisible():
    #  license.center()
    #  #license.display()
    license.orderFrontRegardless()
    license.makeKeyAndOrderFront_(None)


notices = False

def openNotices():
    global notices
    if not notices:
        notices = NSWindow.alloc()
        rect = Foundation.NSMakeRect(100,100,570,800)
        styleMask = NSTitledWindowMask | NSClosableWindowMask | \
            NSResizableWindowMask | NSMiniaturizableWindowMask
        notices.initWithContentRect_styleMask_backing_defer_(rect, styleMask, NSBackingStoreBuffered, False)
        notices.setFrameTopLeftPoint_( NSPoint(300, NSHeight(notices.screen().frame()) - 200) )
        notices.setTitle_('Otto Notices')
        #notices.setFrameAutosaveName_('noticesWindow')

        scrollview = NSScrollView.alloc().initWithFrame_(notices.contentView().frame())
        contentSize = scrollview.contentSize()
 
        scrollview.setBorderType_(NSNoBorder)
        scrollview.setHasVerticalScroller_(True)
        scrollview.setHasHorizontalScroller_(False)
        scrollview.setAutoresizingMask_(NSViewWidthSizable | NSViewHeightSizable)

        textview = NSTextView.alloc()
        textview.initWithFrame_( NSMakeRect(0, 0, contentSize.width, contentSize.height) )
        textview.setMaxSize_(NSMakeSize(FLT_MAX, FLT_MAX))
        textview.setVerticallyResizable_(True)
        textview.setHorizontallyResizable_(False)
        textview.setAutoresizingMask_(NSViewWidthSizable)
        textview.textContainer().setContainerSize_(NSMakeSize(contentSize.width, FLT_MAX))
        textview.textContainer().setWidthTracksTextView_(True)
        textview.setEditable_(False)
        textview.setSelectable_(True)
        #textview.setBackgroundColor_(NSColor.blueColor())

        scrollview.setDocumentView_(textview)

        respath = os.environ['RESOURCEPATH']
        try:
            with codecs.open( os.path.join(respath, 'THIRD-PARTY-NOTICES'), 'r', 'utf-8') as f:
                noticestext = f.read()
        except IOError:
            noticestext = 'Could not read THIRD-PARTY-NOTICES file.'
        storage = textview.textStorage()
        nsstring = NSAttributedString.alloc().initWithString_(noticestext)
        storage.insertAttributedString_atIndex_(nsstring, 0)

        notices.setReleasedWhenClosed_(False)
        notices.setContentView_(scrollview)

    #if not notices.isVisible():
    #  notices.center()
    #  #notices.display()
    notices.orderFrontRegardless()
    notices.makeKeyAndOrderFront_(None)


class SelectFolderDelegate(NSObject):
    def webView_runOpenPanelForFileButtonWithResultListener_(self, webView, resultListener):
        print 'runOpenPanelForFileButtonWithResultListener delegate'
        openpanel = NSOpenPanel.openPanel()
        openpanel.setCanChooseFiles_(False)
        openpanel.setCanChooseDirectories_(True)
        openpanel.setCanCreateDirectories_(False)
        openpanel.setPrompt_('Select')
        #button = openpanel.runModalForDirectory_file_('/Users', False)
        button = openpanel.runModal()
        if button is NSOKButton:
            files = openpanel.filenames()
            if files:
                print 'selected folder', files[0]
                resultListener.chooseFilename_(files[0])  # don't think this does anything useful for us
                #emit('selectedfolder', files[0])  # this would have to be relayed by server
                print 'attempting to inject selected folder'
                #print '!!!', webView.stringByEvaluatingJavaScriptFromString_('$(".folder .path").text('+files[0]+')')  # what a hack!
                js = 'document.querySelectorAll(".path")[0].innerHTML = "'+files[0]+'"'
                print '!!!!', webView.stringByEvaluatingJavaScriptFromString_(js)  # what a hack!
                # i'm a little worried about things needing to be escaped for that


win = False;
selectfolderdelegate = False;

def openMainWindow():
    global win
    global linkpolicy
    global selectfolderdelegate

    if win:
        #win.orderFrontRegardless()
        win.makeKeyAndOrderFront_(None)
        return

    #if win:
    #    del win

    # http://stackoverflow.com/questions/7221699/how-to-load-user-css-in-a-webkit-webview-using-pyobjc

    rect = Foundation.NSMakeRect(0,0,1020,800)
    win = NSWindow.alloc()
    styleMask = NSTitledWindowMask | NSClosableWindowMask | \
        NSResizableWindowMask | NSMiniaturizableWindowMask
    win.initWithContentRect_styleMask_backing_defer_(rect, styleMask, NSBackingStoreBuffered, False)
    win.setTitle_('Otto Audio Jukebox')
    win.center()
    win.setFrameAutosaveName_('mainWindow')
    win.setCollectionBehavior_(NSWindowCollectionBehaviorFullScreenPrimary)
    #win.setBackgroundColor_(NSColor.blackColor().set())  # doesn't seem to do anything

    webview = WebKit.WebView.alloc()
    webview.initWithFrame_(rect)

    #webview.preferences().setUserStyleSheetEnabled_(objc.YES)
    #print webview.preferences().userStyleSheetEnabled()
    #cssurl = Foundation.NSURL.URLWithString_('static/css/webview.css')
    #webview.preferences().setUserStyleSheetLocation_(cssurl)
    #print webview.preferences().userStyleSheetLocation()

    #webview.setCustomUserAgent_('Otto')
    webview.setApplicationNameForUserAgent_('Otto_OSX')  # client uses this to tell if they are running in our webview
    #anfua = webview.applicationNameForUserAgent()
    #print '%%%%%%%%%%%%%%%% appnameforUA', anfua
    #cua = webview.customUserAgent()
    #print '%%%%%%%%%%%%%%%% customUA', cua

    selectfolderdelegate = SelectFolderDelegate.alloc().init()
    webview.setUIDelegate_(selectfolderdelegate)

    pageurl = Foundation.NSURL.URLWithString_('http://localhost:8778/')
    req = Foundation.NSURLRequest.requestWithURL_(pageurl)
    webview.mainFrame().loadRequest_(req)
    #print '$$$$$$$$$$$$$$$$$$$$', webview.stringByEvaluatingJavaScriptFromString_('window.otto = window.otto || {}; otto.app = true;')

    if not linkpolicy:
        linkpolicy = LinkPolicyDelegate.alloc().init()
    webview.setPolicyDelegate_(linkpolicy)

    win.setReleasedWhenClosed_(False)
    win.setContentView_(webview)
    #win.display()
    win.orderFrontRegardless()
    win.makeKeyAndOrderFront_(None)


def openWebBrowser():
    # also check out 'import webbrowser' esp. re reusing window
    name = NSHost.currentHost().name()
    # people don't like when you pick their browser for them
    #if subprocess.call(['open', '-a', 'Google Chrome', 'http://'+name+':8778/']):
    #    print 'no chrome, falling back to Safari (or whatever the default browser is)'
    #    subprocess.call(['open', 'http://'+name+':8778/'])

    #subprocess.call(['open', 'http://'+name+':8778/'])  # there is something wrong with x.local FIXME
    subprocess.call(['open', 'http://localhost:8778/'])



def getSessionCookie():
    cookieJar = NSHTTPCookieStorage.sharedHTTPCookieStorage()
    cookies = {}
    for cookie in cookieJar.cookies():
        if cookie.domain() == 'localhost' and cookie.name() == 'express.sid':  # hmm... what about otto.local? FIXME
            cookies[cookie.name()] = cookie.value()
    r = requests.get('http://localhost:8778/resession', cookies=cookies)
    if 'express.sid' in r.cookies:
      # the server sent a new session cookie
      props = {}
      props[NSHTTPCookieVersion] = '1'
      props[NSHTTPCookiePath] = '/'
      props[NSHTTPCookieName] = 'express.sid'
      props[NSHTTPCookieDomain] = 'localhost'
      props[NSHTTPCookieValue] = r.cookies['express.sid']
      props[NSHTTPCookieMaximumAge] = 365 * 24 * 60 * 60 * 1000
      nscookie = NSHTTPCookie.cookieWithProperties_( props )
      cookieJar.setCookie_(nscookie)
      cookies['express.sid'] = r.cookies['express.sid']
    return cookies


class SocketIOEventTimer(NSTimer):
    ticks_since_last_heartbeat = 0
    def tick_(self, notification):
        #print 'tick'
        global sio
        if sio:
            # process pending socket.io events
            sio.wait(0.00000000001)
            #sio._process_events()  # won't auto reconnect like wait() does, but runs smoother
            # it also means we need to directly manage the socketIO heartbeats
            self.ticks_since_last_heartbeat += 1
            #if self.ticks_since_last_heartbeat > 300:  # every 30 seconds hopefully
            #print 'socketIO tick'
            if self.ticks_since_last_heartbeat > 30:  # huh? FIXME
                #print 'sending socketIO heartbeat'
                sio._transport.send_heartbeat()
                self.ticks_since_last_heartbeat = 0


sio = False

class Namespace(BaseNamespace):
    def on_connect(self):
        print 'Otto.py socketIO connected'

    def on_disconnect(self):
        print 'Otto.py socketIO disconnected'

    # i don't know what message is (vs. event)
    def on_message(self, *args):
        #print 'Otto.py sio message!'
        pass

    def on_event(self, event, *args):
        #print 'Otto.py sio event!', event
        if event == 'resession':
            r = requests.get('http://localhost:8778/resession')
            emit('hello')
        elif event == 'proceed':
            emit('hello')
        elif event == 'welcome':
            print 'i\'m welcome!'
            #too late to do this here (in terms of the main window)
            #if 'username' not in args or not args['username']:
            #    username = os.getlogin()  # probably not useful in Windows
            #    if username:
            #        emit('login', username)
        elif event == 'selectfolder':
          # this works, but is useless since incoming messages are unreliable
          print '^^^^^^^^^^^^^^^ selectfolder!'
          openpanel = NSOpenPanel.openPanel()
          openpanel.setCanChooseFiles_(False)
          openpanel.setCanChooseDirectories_(True)
          openpanel.setCanCreateDirectories_(False)
          openpanel.setPrompt_('Select')
          #button = openpanel.runModalForDirectory_file_('/Users', False)
          button = openpanel.runModal()
          if button is NSOKButton:
              files = openpanel.filenames()
              if files:
                  print 'selected folder', files[0]


def openSocketIO(cookies):
    print 'opening SocketIO'
    global sio
    sio = SocketIO('localhost', 8778, Namespace=Namespace, cookies=cookies)
    # horrible hack to get around a pesky 3 second stutter
    # as websocket.py times out on receiving some combination of bytes
    # this doesn't hurt us now, but it might in the future if it is causing
    # messages to be dropped
    sio._transport._connection.settimeout(0.00001)
    sioeventstimer = SocketIOEventTimer.alloc().init()
    start_time = NSDate.date()
    interval = 0.05
    timer = NSTimer.alloc().initWithFireDate_interval_target_selector_userInfo_repeats_(
        start_time, interval, sioeventstimer, 'tick:', None, True)
    NSRunLoop.currentRunLoop().addTimer_forMode_(timer, NSDefaultRunLoopMode)
    timer.fire()


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
    
    # File menu
    fileMenu = NSMenu.alloc().initWithTitle_('File')
    fileMenuItem = mainMenu.addItemWithTitle_action_keyEquivalent_('File', None, '')
    mainMenu.setSubmenu_forItem_(fileMenu, fileMenuItem)

    fileMenu.addItemWithTitle_action_keyEquivalent_('Main Window', 'mainWindow:', '1')
    fileMenu.addItemWithTitle_action_keyEquivalent_('Browser Window', 'browser:', 'n')
    fileMenu.addItem_(NSMenuItem.separatorItem())
    fileMenu.addItemWithTitle_action_keyEquivalent_('Play', 'play:', 'p')
    fileMenu.addItemWithTitle_action_keyEquivalent_('Stop', 'pauseifnot:', '.')  # does 'stop:' have a special meaning?
    fileMenu.addItemWithTitle_action_keyEquivalent_('Next', 'next:', NSRightArrowFunctionKey)
    fileMenu.addItem_(NSMenuItem.separatorItem())
    fileMenu.addItemWithTitle_action_keyEquivalent_('Scan Music', 'loadMusic:', '')

    # # Edit menu
    # editMenu = NSMenu.alloc().initWithTitle_('Edit')
    # editMenuItem = mainMenu.addItemWithTitle_action_keyEquivalent_('Edit', None, '')
    # mainMenu.setSubmenu_forItem_(editMenu, editMenuItem)

    # editMenu.addItemWithTitle_action_keyEquivalent_('Cut', 'cut:', 'x')
    # editMenu.addItemWithTitle_action_keyEquivalent_('Copy', 'copy:', 'c')
    # editMenu.addItemWithTitle_action_keyEquivalent_('Paste', 'paste:', 'v')
    # editMenu.addItemWithTitle_action_keyEquivalent_('Select all', 'selectText:', 'a')

    # View menu
    viewMenu = NSMenu.alloc().initWithTitle_('View')
    viewMenuItem = mainMenu.addItemWithTitle_action_keyEquivalent_('View', None, '')
    mainMenu.setSubmenu_forItem_(viewMenu, viewMenuItem)

    viewMenu.addItemWithTitle_action_keyEquivalent_('Full Screen', 'toggleFullScreen:', 'F')



statusImages = {'idle': 'static/images/osxmenubaricon.png'}
images = {}
statusbar = None
state = 'idle'
statusItem = False  # must be global or else menu disappears when function exits

def makeStatusBarMenu():
    global statusImages
    global images
    global statusbar
    global state
    global statusItem

    for i in statusImages.keys():  # Load all images
        images[i] = NSImage.alloc().initByReferencingFile_(statusImages[i])

    statusBar = NSStatusBar.systemStatusBar()
    statusItem = statusBar.statusItemWithLength_(NSVariableStatusItemLength)
    statusItem.setImage_(images[state])  # Set initial image
    statusItem.setHighlightMode_(1)  # Let it highlight upon clicking
    statusItem.setToolTip_('Otto')

    statusMenu = NSMenu.alloc().init()
    statusItem.setMenu_(statusMenu)

    # status bar menu
    (F7, F8, F9) = ('', '', '')
    if hotkeys:
        #(F7, F8, F9) = (NSF7FunctionKey, NSF8FunctionKey, NSF9FunctionKey)
        # sadly i can't currently distunguish between multiple hot keys
        (F7, F8, F9) = ('', '', NSF8FunctionKey)  # note that F9 actually equals F8
    togglePlay = statusMenu.addItemWithTitle_action_keyEquivalent_('Play/Pause', 'togglePlay:', F8)
    nextItem = statusMenu.addItemWithTitle_action_keyEquivalent_('Next', 'next:', F9)
    mainWindowItem = statusMenu.addItemWithTitle_action_keyEquivalent_('Main Window', 'mainWindow:', F7)
    togglePlay.setKeyEquivalentModifierMask_(0)
    nextItem.setKeyEquivalentModifierMask_(0)
    mainWindowItem.setKeyEquivalentModifierMask_(0)
    statusMenu.addItem_(NSMenuItem.separatorItem())
    statusMenu.addItemWithTitle_action_keyEquivalent_('Scan Music', 'loadMusic:', '')
    statusMenu.addItem_(NSMenuItem.separatorItem())
    statusMenu.addItemWithTitle_action_keyEquivalent_('Quit Otto', 'terminate:', '')


def makeDockMenu():
    dockMenu = NSMenu.alloc().initWithTitle_('DockMenu')
    dockMenu.addItemWithTitle_action_keyEquivalent_('Play', 'play:', '')
    dockMenu.addItemWithTitle_action_keyEquivalent_('Stop', 'pauseifnot:', '')
    dockMenu.addItemWithTitle_action_keyEquivalent_('Next', 'next:', '')
    
    #NSApp.delegate().setDockMenu_(dockMenu)  # why were they doing this? (albertz/music-player)
    NSApp.setDockMenu_(dockMenu)


class WatchdogTimer(NSTimer):
    server_ready = False
    def tick_(self, notification):
        global server_process
        #print 'watchdog tick'
        if server_process and server_process.poll():
            print 'server exited.'
            shutItDown()
        elif not self.server_ready:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            result = sock.connect_ex(('127.0.0.1',8778))
            sock.close()
            if result == 0:
                self.server_ready = True
                # perhaps we should schedule a message to be sent here
                NSApp.delegate().serverReady()


def startWatchdog():
    watchdog = WatchdogTimer.alloc().init()
    interval = 0.5
    timer = NSTimer.timerWithTimeInterval_target_selector_userInfo_repeats_(
        interval, watchdog, 'tick:', None, True)
    NSRunLoop.currentRunLoop().addTimer_forMode_(timer, NSDefaultRunLoopMode)
    #NSRunLoop.currentRunLoop().addTimer_forMode_(timer, NSEventTrackingRunLoopMode)
    #timer.fire()


server_process = False    

def startItUp():
    global server_process
    #RESOURCES_DIR=os.path.dirname(os.path.realpath(__file__))  # fails in py2app -A mode
    #RESOURCES_DIR=os.getcwd()  # or we could just use RESOURCEPATH env variable
    # http://stackoverflow.com/questions/16434632/how-to-directly-access-a-resource-in-a-py2app-or-py2exe-program/17084259#17084259
    RESOURCES_DIR=os.environ['RESOURCEPATH']


    os.environ['DYLD_FALLBACK_LIBRARY_PATH'] = RESOURCES_DIR+'/lib'
    os.environ['LD_LIBRARY_PATH'] = RESOURCES_DIR+'/lib'
    os.environ['PATH'] = RESOURCES_DIR+'/bin' + ':'+os.environ['PATH']
    #print os.environ['PATH']
    server_process = subprocess.Popen(['Otto', 'otto.coffee'], executable='coffee')
    # the above doesn't work to make the process name Otto as coffee ends up spawning node
    # we'd really like to make the process name Otto so when people are prompted by their firewall
    # they know what's going on. perhaps we need to hack up our own version of coffee to set the name
    print server_process
    print 'pid = ', server_process.pid
    print 'otto server started'


def shutItDown():
    global server_process
    if server_process:
        #os.killpg(server_process.pid, signal.SIGTERM)
        print server_process
        print 'pid = ', server_process.pid
        #os.killpg(server_process.pid, signal.SIGINT)
        try:
            server_process.send_signal(signal.SIGINT)
            server_process.wait()
        except:
            print 'sending signal failed'
        #terminate_(notification)
    server_process = False
    AppHelper.stopEventLoop()


def signalHandler(signum, frame):
    print 'Signal handler called with signal', signum
    shutItDown()
    #pool.release()


if __name__ == '__main__':
    #NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    #pool = NSAutoreleasePool.alloc().init()

    #app = NSApplication.sharedApplication()
    app = HotKeyApp.sharedApplication()
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
    from Quartz import CGEventTapCreate, CGEventMaskBit, kCGSessionEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, kCGEventTapOptionListenOnly
    from PyObjCTools import NibClassBuilder, AppHelper

    app.setPresentationOptions_(NSFullScreenWindowMask)

    try:
        from Carbon.CarbonEvt import RegisterEventHotKey, GetApplicationEventTarget  #, GetEventParameter #bzzzt. import err
        from Carbon.Events import cmdKey, controlKey
        import struct  # i don't know why this is here
        hotkeys = True
    except ImportError:
        hotkeys = False
        pass

    import logging  # socketIO_client uses this to log
    #logging.basicConfig(level=logging.DEBUG)
    logging.basicConfig()
    #from socketIO_client import SocketIO, BaseNamespace

    import os
    import re
    import signal
    import socket
    import codecs
    import requests
    import subprocess

    #signal.signal(signal.SIGCHLD, signalHandler)
    signal.signal(signal.SIGINT, signalHandler)

    from gestalt import gestalt
    osxver = gestalt('sysv')
    print 'OSX version =', hex(osxver)
    if osxver > 0x1080:
        print 'creating event tap to catch media keys'
        createEventTap()
    else:
        print 'OSX < 10.8, skipping event tap'

    #app.run()  # can't use AppHelper.stopEventLoop() to exit if we do this
    AppHelper.runEventLoop()

    #pool.release()
