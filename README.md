Otto Jukebox - beta
===================

Home page <http://ottojukebox.com>

> Version 2014.11.19.1 - bundle id back to com.ottojukebox.otto

(See "History" for previous releases)

NOTE: On the Mac if you are running OSX 10.9.5 (or 10.10 I presume)
you will get a dialog with message "the identity of the developer
cannot be confirmed." and it won't let you run Otto. To get past this,
control-click on the Otto.app and select "Open" from the pop-up
menu. This will get you a dialog with the option to open the app
anyway.

This page shows how to use the workaround (but for Firefox instead of
Otto):

<https://support.mozilla.org/en-US/kb/firefox-cant-be-opened-after-you-install-it-on-mac>

------------------------------------------------------------
Otto is an open source music jukebox application that disguises itself as an
iTunes replacement without all the extra baggage.

It is also a web-first fully streaming cloudless social music server that
is always playing music and allows multiple people to listen to the same stream
of music at the same time (and act as DJs for each other). This is enabled
via. it's full featured web-interface running on port 8778.

It gracefully organizes very large music collections.

Otto utilizes and integrates a large number of other open source projects and
would not be possible without them, especially the excellent Music Player
Daemon (MPD) <http://www.musicpd.org/> which is what gives Otto its voice.

See the demo at <http://demo.ottojukebox.com:8778/>.


OSX Installation
================

(For Linux, see "Linux Installation")

 - Download and open the disk image (.dmg file) from
   <http://ottojukebox.com/downloads/>
 - Drag Otto.app to your Applications folder (or your Desktop if you prefer)
 - Eject the disk image
 - Open the Otto application.

This will start the Otto server. An Otto browser window will appear and a menu
bar icon will appear in your menu bar.

If this is your first time running Otto it will ask to scan your music folder.


OSX Uninstalling
----------------

To uninstall Otto:
 - Drag the Otto application to the trash
 - Drag the Otto folder (found inside the Library folder in your home
   folder) to the trash

If you want to be extra clean when uninstalling (optional):
 - Find the `com.ottojukebox.otto.plist` file in the Preferences folder
   (in the Library folder in your home folder) and drag it to the trash
 - Or type `defaults delete com.ottojukebox.otto.plist` on the command
   line


OSX Notes + Known Issues
------------------------

Otto requires 10.7 or later. It *might* run under 10.6, I just don't know.  I
have no plans to make it work any further back than 10.7 (and I may abandon
10.7 soon).

If you have multiple user accounts on your Mac and you want Otto to scan the
Music folders of those other accounts, you have to change the permissions on
the `Music` folders so Otto can scan them.

    $ sudo chmod a+rx /Users/other/Music  # do this from an admin account

Then you can add a soft link in the Music folder of the account under which
Otto runs so that Otto will find the others account's music. You should name
the soft link with an email address for the other person so that Otto will
automatically know that it's a different person's music (See "Music Owners").

    $ ln -s /Users/other/Music ~/Music/roommate@mindspring.com


Otto tries to do the right thing with the media keys (next track, play/pause)
on keyboards that have them. However, it can't do the right thing with the
'play/pause' key because iTunes will wake up and interfere, even if it's not
running. You can work around this by quitting iTunes and launching the
QuickTime Player. Keep the Quicktime Player running, but close all of its
media windows. This should keep iTunes from reacting to play/pause.

If you don't have media keys on your keyboard but still want a key you can
press anytime to skip the currently playing track, you can use the "Get Info"
panel on the Otto.app and check the "Open in 32-bit mode" box (and relaunch
Otto if it was running). Then F8 should skip the current track even if Otto
isn't the currently active application.

Notifications don't work in the OSX Otto application browser window (and the
button for them is hidden). If you want notifications, point a notifications
capable browser at <http://localhost:8778/> and toggle the "notifications"
control in the top banner (next to the lightning bolt "sound cues" control).

The folder selection dialog box can be slow to come up on OSX when you click
the folder icon during the initial scan. This might be especially slow if your
music is on a network drive.

If you manage to paste a folder path into the initial load screen you may get
some funky formatting

If you have the OSX firewall enabled you may be prompted to allow incoming
network connections.  Otto opens an incoming network port for its web
interface, and an additional port for streaming each channel (three channels
currently). The name of the application given by OSX might be "node" or "mpd"
or "mpd-0.16.3-working". You can deny these connections but the "node" one is
required to connect to Otto with other devices. You can manage these settings
in the System Preferences Security & Privacy panel (under the "Firewall" tab).

It's possible that the Otto application may crash in such a way as to leave
music playing in the background. Running Otto again should reconnect it to the
background music player daemon(s) and then you can quit Otto to stop the music.

The initial OSX application window is too big for some laptop screens.

Otto prints out a lot of debugging log messages. On OSX you can type `syslog
-C` on the command line to see recent messages.


If Otto isn't starting, type `syslog -C` and if you are getting messages that look like this:

    ERROR: listen(): bind() failed errno:22 Invalid argument for
    socket: /Users/jon/Library/Otto/var/mongod.sock

You might have a OSX Access Control List permissions problem.

Here's how I fixed this on my machine (Change `/Users/jon` to your actual home
directory):

    $ ls -aled /Users/jon  # to check for the problematic ACL
    group:everyone deny delete  # there is it

    $ chmod -N /Users/jon  # -N removes ACLs from a file
    $ chmod -N /Users/jon/Library
    $ chmod -RN /Users/jon/Library/Otto

You can ignore: `Failed to clear ACL on file mongod.sock: Invalid argument` or
similar errors on the last command.


(See "Known Issues" below for more)

Operation
=========

Web Interface
-------------

When running Otto you (and other people) can listen to and control it
with any modern web browser or mobile device. Otto runs a web server
on port 8778 and the web interface is the same interface as in the
desktop application.

If you are running it on the same machine as your browser you can
access it at the URL <http://localhost:8778/>. The port number `8778`
is suppose to memorable by looking like the word 'otto' (with 8's
being mutant 'o's and 7's being 't's).

To access it from other machines you'll need to figure out the IP
address or hostname of the machine running Otto and replace
`localhost` with the IP address or hostname.

If you are on the same local network as your Otto server, and your
Otto server computer has a name configured (see the Sharing system
preferences panel in OSX for example), then you might be able to
access the machine by using `http://<computername>.local:8778/`.


Scanning Music
--------------

Otto will scan for music files in your music folder. Otto doesn't move or
modify your music in any way, it simple builds a database containing
information about the music it finds.

The first time you run Otto it will ask which folder to scan for music. The
default will be ~/Music (the Music folder in your home folder).

If you add additional music to your music folder you can press the "scan"
button located on the "stacked cubes" screen in the browser window. Otto will
then look for new files in the last scanned music folder. If you want to scan a
different folder, see "Scanning Music from the Command Line".


Music Owners
------------

Otto associates an owner with the music it scans. Multiple owners can have
music scanned into Otto and Otto will pick and play music depending on who is
listening and which owners it knows about.

If music is stored inside a folder that looks like an email address (the
folder name has an "@" in it), it will use that email address as the owner of
all music found in that folder, and any subfolders.

You can also create a special text file named "otto.json" and place it inside a
folder to explicitly set the owner for everything in that folder without
needing to rename the folder to have an "@" in it.

The format for setting the owner in "otto.json" is:

    { "owner": "<email address>" }

Here is an example otto.json file that sets the owner to
"roommate@mindspring.com":

    { "owner": "roommate@mindspring.com" }

If a music file is not in a folder with an "@" in it, and there is no otto.json
file, the owner will default to the current user running the application.


Scanning Music from the Command Line
------------------------------------

You can also use a script on the command like to have Otto scan for music. The
script can be used to scan a different folder than was initially scanned when
you started Otto. This can be useful if you want to scan music from multiple
separate folders. Otto remembers the last scanned folder and that is the folder
that gets scanned when you press "scan" from the browser window.

To scan from the command line:

 - Make sure Otto is already running, and then:

   - On OSX:

            $ cd /Applications/Otto.app/Contents/Resources

   - On Linux:

            $ cd /usr/local/otto

 - Then run the scan script:

        $ ./scan

That will scan whatever folder was last scanned (or will default to
`~/Music` if there has never been a scan). You can give an argument to
scan to tell it to scan a different folder:

    $ ./scan /Volumes/MyMusicDisk   # for example

Future scans will then default to that folder.

Otto remembers all the music it previously scanned, so you can run scan
multiple times with different arguments to build a database that covers any
number of different distinct folders.

When scanning a folder Otto only looks at new music files it hasn't scanned
before. If you make any changes to your music (delete/move/rename files, change
meta tags, add/change album art) after Otto has scanned it, the changes won't
be seen. The only way to get such changes into Otto, and the only way to remove
previously scanned music from Otto, is to delete the database and scan it from
scratch again (see "Resetting the Database").


Resetting the database
----------------------

If you make any changes to your music (other than adding more music) and you
want Otto to reflect those changes, you'll need to reset the database and scan
your music again. Please note this means you will lose the information about
any songs, albums, or artists you have starred in Otto. Your stars list is
going to be empty.

To reset the database:

 - Make sure Otto is not running

 - On OSX
   - Find the "Otto" folder in the Library folder in your home folder
   - Throw it in the trash

 - On Linux

        $ rm -rf /usr/local/otto/var

The next time you run Otto it will ask you about scanning for Music
just like the first time you ran it. See "Scanning Music".


Known Issues
============

Interface is not currently usable on phones. Tablets are not much better.

During the initial first-time scan, the cubes can be stacked under the wrong
names. The "stacked cubes" display will be correct inside the application after
the inital scan.

Otto has some issues scanning multiple albums from the same directory, stuff
may get filed wrong, especially for Various and unknown artists.

If there is no "currently playing" track information displayed, try reloading
the browser (use a right-click and pick 'reload' from the pop-up menu in the
OSX application).

An empty queue can sometimes be fixed by adding a song. Also try shutting down
and restarting Otto.

Otto will sometimes fail to finish its initial scan and transition cleanly to
the normal playing interface. Try some of the above tricks (reload browser,
restart Otto).

The channel listeners list at the top is a little buggy, esp. when logging out
and in.

Logging in the first time might require a browser reload before the current
track info is displayed properly.

If Otto is completely stuck and not playing anything and you can't add tracks,
MPD might be stuck on a track that it doesn't like. You can try clearing the
bad song from the MPD queue:

 - Shutdown Otto
 - Kill any errant background Otto processes (mpd, node, mongod)
 - There is a script to kill background Otto processes:

    - On Osx:

            $ /Applications/Otto.app/Content/Resources/reset

    - On Linux:

            $ /usr/local/otto/reset

    - Be aware that reset will try to kill off all mpd, mongod, and node
      processes, so you might not want to use it if you are using MongoDB
      or NodeJS on you machine for other purposes.

 - Clear out MPDs state files

    - On Osx:

            $ rm ~/Library/Otto/var/mpd/??state

    - On Linux:

            $ rm /usr/local/otto/var/mpd/??state

 - Restart Otto and see how it goes

------------------------------------------------------------

Linux Installation
==================

Otto is not yet packaged together as a singular application or installation
package for Linux like it is on OSX. Therefore Linux installation is fraught
with peril, especially when it comes to getting a correctly compiled version
of MPD installed.

You will also need to install git, MongoDB, Node.js + NPM packages,
Avahi DNS lib (and development headers), virtualenv and setup a Python
virtual environment with a number of Python modules.

Installing MPD
--------------

 - MPD is the hardest part. I put this first because if it doesn't
   work you are sunk

 - You can try installing MPD using a package manager
   for your OS, but most versions of MPD are not compiled with the
   `--enable-httpd-server` option and Otto requires it

 - Someone tried installing Otto on a Fedora machine for me (thanks
   Matt!), and he said "Luckily it looks like Fedora + rpmfusion
   packaged all the deps necessary, including mpd with httpd support."
   See "Fedora Tips" below.

 - You can check if mpd was compiled with `--enable-httpd-server` by
   typing

        $ mpd --version

   Look for `httpd` in the list of supported outputs

 - Otto is currently battle tested with MPD version 0.16.3

 - But I suspect any newer version of MPD would work as well

 - You might need to compile MPD from source.
   See <http://www.musicpd.org/download.html>

 - MPD has many dependencies which may also be hard to install (e.g. ffmpeg)

 - You might be able to use your OS package manager as a starting point and
   tweak its configuration files to enable a recompile with
   the `--enable-http-server` option

 - You might be able to sift through
   <https://github.com/Homebrew/homebrew/blob/master/Library/Formula/mpd.rb>
   to get some ideas on what libraries to install and what options to use
   (but don't forget to add `--enable-http-server`)

 - Use this wiki page to see what others have done, or to describe what you
   discover to help future compeers:
   <https://github.com/ferguson/otto/wiki/MPD-Installation-Tips>

 - Once you have a working mpd executable, put a link to it
   in `/usr/local/otto/bin`

 - Good luck

Fedora Tips
-----------

Someone (thanks again Matt!) was able to install Otto on Fedora using
system packages for mpd (which thankfully was compiled with httpd
support) and MongoDB.

    $ yum install python-virtualenv mpd avahi-compat-libdns_sd-devel

Don't use the Fedora packages for node/npm/coffee-script, they are too
new for Otto. Otto needs node v8 and they install node v10. Instead
use the 'devsetup' script included in the otto repo to install node
(see below). Don't worry if you already have them installed, the
devsetup script will only install them in the otto directory, they
won't conflict with a system-wide node install.

You could also use yum install mongo and mongo-server, but it's so
easy to install MongoDB directly into the otto directory, just do that
instead (see below).

Don't forget to put a link to the system installed mpd into otto/bin:

    $ ln -s /usr/bin/mpd /usr/local/otto/bin


Debian Tips
-----------

The mpd 0.16.7 system package on Debian 7.6 seems to be compiled with
httpd enabled, so that's good!  Installing the mpd package configures
it to automatically start up. The resulting mpd running in the
background shouldn't conflict with Otto, but you might want disable it
just to be sure.

    $ sudo aptitude install git python-virtualenv python-dev curl libavahi-compat-libdnssd-dev libtiff-dev libjpeg-dev

Don't forget to put a link to the system installed mpd into otto/bin:

    $ ln -s /usr/bin/mpd /usr/local/otto/bin


Install the Otto repo from github
---------------------------------

Clone a copy of Otto into `/usr/local/otto` (requires git):

    $ cd /usr/local
    $ sudo mkdir otto
    $ sudo chown `whoami` otto   # NOTE: those are back ticks, not quotes
    $ git clone https://github.com/ferguson/otto.git otto


Setup the python virtual environment and required modules
---------------------------------------------------------

This requires virtualenv be installed.

    $ cd /usr/local   # NOTE: don't cd into the otto directory yet
    $ virtualenv otto
    $ cd otto
    $ . activate   # NOTE: there is a space between the "." and "activate"
    $ pip install -r requirements.pip

 - Among other modules, this will install the Pillow module (a PIL
   replacement) which will need libtiff, libjpeg, and perhaps several other
   packages. Inspect the output from 'pip install' above and adjust as needed.

 - You can retry installing Pillow with `pip uninstall Pillow` followed by
   `pip install -r requirements.pip`


Install MongoDB
---------------

Download and install MongoDB <http://www.mongodb.org/downloads>.

You don't need to do anything complicated here like making sure
MongoDB starts when your system boots. As long as Otto can find a
MongoDB executable in Otto's bin directory, it will take care of
everything else it needs.

The easiest thing to do is to download the correct tarball for your
system from the above link, unpack it, and just copy everything in the
resulting bin directory into `/usr/local/otto/bin`.

 - The latest version (or anything close to it) should work just fine
 - Version 2.4.9 is what is currently used in the Otto OSX application
 - You can install the MongoDB executables in /usr/local/otto/bin, or you can
   install it elsewhere and put a link to just the 'mongod' executable in
   /usr/local/otto/bin.
 - You don't need to configure MongoDB to start/stop on boot


Install Node.js using 'devsetup'
--------------------------------

The 'devsetup' script in the Otto repo will download 'n' (a utility by
the inimitable TJ Holowaychuk) and uses that to download and install
the correct version of node locally in the Otto directory.

    $ cd /usr/local/otto
    $ ./devsetup

Just for reference, Otto has only been tested with Node.js version
0.8.17 (but I'm sure any newer version of 0.8 will work).


Install NPM modules
-------------------

    $ cd /usr/local/otto
    $ . activate   # won't hurt to do it twice if you previously activated above
    $ npm install
    $ ./nogfix  # links `coffee` into otto/bin


Starting Otto on Linux
----------------------

To start the Otto server on Linux:

    $ /usr/local/otto/go

  - Otto will need permissions to create and write in `/usr/local/otto/var`
    It will try to create it if it doesn't already exist.

  - You can ignore "Failed to load database" errors from MPD and dire looking
    warnings about the "Apple Bonjour compatibility layer of Avahi".

  - To stop Otto, press `Ctrl-C`

Point a web browser on your machine to <http://localhost:8778/>

Otto should be running at this point, but it's pretty boring since it doesn't
yet know about any music. See "Scanning Music".


------------------------------------------------------------

History
=======

> Version 2014.11.15.0 - put bundle id back to com.ottoaudiojukebox.otto until issue with signing is resolved
> changed kill track symbol to a plain minus as the circle-minus symbol made people think they were deleting the track
> using localStorage to remember now playing size
> forgot to remove a /var under OSX in ottodb.py

> Version 2014.11.13.0 - general source code cleanups
> better connection logic to fix empty now playing loading bug
> handle no license file / third party notices exceptions
> changed 'load music' to 'scan music' in app menus
> scan music app menu item brings forth the cubes view
> makeapp runs a pip install and npm install
> fixed mmenu channel slider bug on reconnects
> fixed error about uninited slider
> added debug npm module (but not using it yet)
> fixed right-click refresh bug in app
> tried and failed to tweak bottom margin on bottom logo
> discovered that some versions of coffee seem to need .coffee
> fixed an errant exception catch in offeescript that though it was python
> remove .sh from scrips
> rename ottoaudijukebox.com to ottojukebox.com
> updated README to talk about web interface and expand on Linux installation instructions
> added devsetup script which installs node (and may do other things someday)
> added nogfix script which links npm modules execuables into bin
> added N_PREFIX to activate script

> Version 2014.09.24.0 - added home page link to logo, bottom logo jumps back to top,
> one logo at a time on screen, added tooltips to most controls, fixed hover color
> for notifications and sound cues controls, cleaned up channel list appearance,
> current channel now open, changed icon for expanding channel info, current channel
> expanded by default, added toggle for crossfade and replay gain, consolidated
> zoom in and zoom out controls into one control, fixed setting owner with otto.json,
> app is now less than half it's previous size, tweaked README

> Version 2014.09.18.0 - Fix for broken scan.py (unicode char in creating
> composer index), orange logo

> Version 2014.09.17.0 - Fix libtiff path fix, search on composer,
> orange color for active, some layout fixes, scan button tweaks

> Version 0.3.0 - Mar 11th 2014 - Initial public release
