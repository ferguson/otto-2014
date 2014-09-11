Otto Audio Jukebox - beta
=========================

<http://ottoaudiojukebox.com>

### Version 0.3.0 - Mar 11th 2014 - Initial public release

See "History" for previous releases

------------------------------------------------------------

(For Linux, see "Linux Installation" toward the bottom of this file.)


OSX Installation
----------------

- Download and open the disk image (.dmg file) from <http://ottoaudiojukebox.com/downloads/>
- Drag Otto.app to your Applications folder (or your Desktop if you prefer)
- Eject the disk image
- Open the Otto application.

This will start the Otto server. An Otto browser window will appear and an Otto
menu bar icon will appear in your menu bar.

If this is your first time running Otto it will ask to scan your music folder.


OSX Uninstalling
----------------

To uninstall Otto:
  - Drag the Otto application to the trash
  - Drag the Otto folder (inside the Library folder in your home folder) to the trash

If you want to be extra clean when uninstalling (optional):
  - Find the com.ottoaudiojukebox.otto.plist file in the Preferences folder (in
    the Library folder inside your home folder) and drag it to the trash
  - Or type "defaults delete com.ottoaudiojukebox.otto.plist" on the command line


OSX Notes and Known Issues
--------------------------

It's possible that the Otto application will crash in such a way as to leave
music playing in the background. Running Otto again should reconnect it to the
background music player and then you can quit Otto to stop the music.

Otto requires 10.7 or later. It *might* run under 10.6, I just don't know.  I
have no plans to make it work any further back than 10.7 (and I may abandon 10.7
soon).

If you have the OSX firewall enabled you may be prompted to allow incoming
network connections.  Otto opens an incoming network port for it's web
interface, and an additional port for streaming each channel (three channels
currently). The name of the application given by OSX might be "node" or
"mpd". You can manage these settings in the System Preferences Security &
Privacy panel (under the "Firewall" tab).


Scanning Music
--------------

Otto will scan for music files in your music folder. Otto doesn't move or modify your music in any way, it simple builds a database containing information about the music it finds.

The first time you run Otto it will ask which folder to scan for music. The default will be ~/Music (the Music folder in your home folder).

If you add additional music to your music folder you can press the "scan" button located on the "stacked cubes" screen in the browser window. Otto will then look for new files in the last scanned music. If you want to scan a different folder, see "Scanning Music from the Command Line".


Music Owners
------------

Otto associates an owner with the music it scans. Multiple owners can have music loaded in Otto and Otto will pick and play music depending on who is listening and which owners it knows about.

If a music is stored inside a folder that looks like an email address (the folder name has an "@" in it), it will use that email address as the owner of all music found in that folder (and any subfolders).

You can also create a special text file named "otto.json" and place it inside a folder to explicitly set
the owner for everything in that folder without needing to rename the folder to have an "@" in it.

The format for setting the owner in "otto.json" is:

    { "owner": "<email address>" }

Here is an example otto.json file that sets the owner to "jon@ottoaudiojukebox.com":

    { "owner": "jon@ottoaudiojukebox.com" }

If a music file is not in a folder with an "@" in it, and there is no otto.json file, the owner will default to the current user.


Scanning Music from the Command Line
------------------------------------

You can also use a script on the command like to have Otto scan for music. The
script can be used to scan a different folder than was initially scanned when
you started Otto. This can be useful if you want to scan music from multiple
separate folders. Otto remembers the last scanned folder and that is the folder
scanned when you press "scan" from the browser window.

To scan from the command line:

   - Make sure Otto is already running

    On OSX:
    $ cd /Applications/Otto.app/Contents/Resources
    On Linux:
    $ cd /usr/local/otto

    Then:
    $ ./scan.sh

That will scan whatever folder was last scanned (or will default to
~/Music if there has never been a scan). You can give an argument to
scan.sh to tell it to scan a different folder:

    $ ./scan.sh /Volumes/MyMusicDisk   # for example

Future scans will then default to that folder.

Otto remembers all the music it previously saw, so you can run scan.sh several
times with different arguments to build a database that covers several different
distinct folders.

When scanning a folder Otto only looks at new music files it hasn't scanned before. If you make any changes to your music (delete/move/rename files, change meta tags, add/change album art) after Otto has scanned it, the changes won't be seen. Currently the only way to get such changes into Otto, and the only way to remove previously scanned music from Otto, is to delete the database and load it from scratch again (see "Resetting the Database").


Resetting the database
----------------------

If you make any changes to your music (other than adding more music)
and you want Otto to reflect those changes, you'll need to reset the
database and scan your music again. Please note that this means you
will lose the information about any songs, albums, or artists you have
starred in Otto. Your stars list is going to be empty.

To reset the database:

   - Make sure Otto is not running
   - On OSX
     - Find the "Otto" folder in the Library folder in your home folder
     - Throw it in the trash
   - On Linux
     $ rm -rf /usr/local/otto/var

The next time you run Otto it will ask you about scanning for Music
just the the first time you ran it. See "Scanning Music".


------------------------------------------------------------

Linux Installation
------------------

Otto is not yet packaged together as a singular application or installation
package for Linux like it is on OSX. Therefore Linux installation is much more
tricky, especially when it comes to getting a correctly compiled version of MPD
installed (you might want to start with that, see below).

You will also need to install Node.js, Node.js packages, MongoDB and setup a
Python virtual environment with a number of Python modules.

Clone a copy of Otto into /usr/local/otto (requires git):

    $ cd /usr/local
    $ sudo mkdir otto
    $ sudo chown `whoami` otto   # NOTE: those are back ticks, not single quotes
    $ git clone git@github.com:ferguson/otto.git otto
    $ cd otto

Setup a python virtual environment (requires virtualenv):

    $ cd /usr/local   # yes, that is right, don't cd into the otto directory yet
    $ virtualenv otto
    $ cd otto
    $ . activate   # NOTE: there is a space between the "." and "activate"
    $ pip install -r requirements.pip

  - Among other modules, this will install the Pillow module (a PIL replacement)
    which will need libtiff, libjpeg, and perhaps several other
    packages. Inspect the output from 'pip install' above and adjust as needed.

  - You can retry installing Pillow with 'pip uninstall Pillow' followed by
    rerunning the "pip install" line above.

Download and install MongoDB:

  - See <http://www.mongodb.org/downloads>
  - You can install the MongoDB executables in /usr/local/otto/bin, or you can
    install it elsewhere and put a link to just the 'mongod' executable in
    /usr/local/otto/bin.

Download and install Node.js:

  - See <http://nodejs.org/download/>
  - Like MongoDB, you can install it directly in /usr/local/otto, or link to the 'node'
    and 'npm' executables in /usr/local/otto/bin.

  - Once node is installed, install the required npm modules:
    $ cd /usr/local/otto
    $ npm install

Installing MPD:

  - MPD is the hardest part. You might want to try this first because if it doesn't
    work you are sunk
  - You can try installing MPD using a package manager
    for your OS, but most versions of MPD are not compiled with the
    --enable-httpd-server option and Otto requires it
  - Otto is currently battle tested with MPD 0.16.3
  - But I suspect any newer version of MPD would work as well
  - You might need to compile MPD from source. See <http://www.musicpd.org/download.html>
  - MPD has many dependencies which may also be hard to install (e.g. ffmpeg)
  - You might be able to use your OS package manager as a starting point and tweak it's configuration
files to enable a recompile with the --enable-http-server option.
  - You might be able to sift through
    <https://github.com/Homebrew/homebrew/blob/master/Library/Formula/mpd.rb>
    to get some ideas on what libraries to install and options to use
  - Use this wiki page to see what others have done, or to describe what you discover to help future compeers:
    <https://github.com/ferguson/otto/wiki/MPD-Installation-Tips>
  - Once you have a working MPD, put a link to it in /usr/local/otto/bin
  - Good luck


Starting Otto on Linux
----------------------

To start the Otto server on Linux:

    $ /usr/local/otto/go.sh

    - Otto will need permissions to create and write in a /usr/local/otto/var directory

    - You can ignore "Failed to load database" errors from MPD and dire looking
      warnings about the "Apple Bonjour compatibility layer of Avahi".

    - Press ctrl-C to stop the server

Point a web browser on your machine to http://localhost:8778/

Otto should be running at this point, but it's pretty boring since it doesn't yet
know about any music. See "Scanning Music".


------------------------------------------------------------

History
-------