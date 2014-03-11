Otto Audio Jukebox - beta
=========================

[Otto Home Page](http://ottoaudiojukebox.com)

### Version 0.3.0 - Mar 11th 2014 - Initial public release

------------------------------------------------------------

OSX Installation
----------------

Download and open the .dmg disk image.
Drag Otto.app to your Applications folder (or your Desktop if you prefer).
Double-click Otto.app in it's new location.

Otto will start and an Otto menubar menu will appear in your menubar.
Google Chrome will launch (or if you don't have Chrome, your default browser
will be used) pointing to Otto's web interface via. http://localhost:8778/.

At this point Otto doesn't have any music loaded, so it's pretty boring.

OSX Loading Music
-----------------

Loading music is currently the least user friendly part of Otto.app, but let's
walk through it step by step:

Open a command line window in the Terminal.app (It's found in /Application/Utilities).
At the shell prompt in a Terminal window type:

    $ cd /Applications   # or change /Applications to wherever you installed Otto
    $ cd Otto.app/Contents/Resources
    $ . activate   # NOTE: there is a space between the "." and "activate"
    $ python loader.py

Otto will then look in your Music directory and load all the music files it can find there.
Otto doesn't move or modify your music in any way, it simple builds a database containing information about the music it finds. Note that Otto.app must be running before you run loader.py or else it can't use the database.

You can re-run the steps above any time you want Otto to load more music. You can also give an argument to loader.py to tell it to look for music somewhere else:

    $ python loader.py /Volumes/MyMusicDisk   # for example

Otto remembers all the music it previously saw, so you can run loader.py several times with different arguments to build a database that covers several different folders. If you want to remove music from Otto, currently the only was is to delete the database and load it from scratch again. Otto keeps the database in ~/Library/Otto. If you remove that directory Otto will start from scratch the next time you do the four shell commands listed above (with Otto running).

Otto associates an owner name with the files it loads. Owner names are determined by directory names that are named like an email address (has an "@" in it). If a given music file has a parent directory that looks like an email address, it will use that email address as the owner of all music found in that directory. You can also create a special otto.json file in a directory to set the owner for everything in that directory. Here is an example otto.json file that sets the owner:

    { "owner": "jon@ottoaudiojukebox.com" }

If no directory has an @ in it and there is no otto.json file, Otto will default to using the username of the user currently running the loader.py script.


OSX Uninstalling
----------------

To uninstall Otto, simply drag Otto.app to the trash. If you also want to remove Otto's database, also drag ~/Library/Otto to the Trash and Otto will be completely uninstalled.

OSX Known Issues
----------------
- The menubar menu "load" item currently doesn't do anything.
- There is no regular application menu, the only way to quit is using the menubar menu.
- The application isn't currently signed, so you will prbably get warnings about running an unsigned app. You can make an exception for Otto in the Securty tab in System Preferences. I've also heard that you can hold the shift key down while launching Otto to allow it to run.
- The system might ask you if you want to all Otto to open several network ports. Otto open a port for it's web interface, and an additinal port for streaming each channel (two channels is the current default).
- Otto requires 10.7 or later. It *might* run under 10.6, but I just don't know and have no plans to make it work any further back than 10.7.

------------------------------------------------------------

Linux Installing
----------------

Linux installation is less automated and more tricky, especially in getting a correctly compiled version of MPD installed. You also need to install Node.js, MongoDB and do some python virtualenv setup.

    $ cd /usr/local
    $ sudo mkdir otto
    $ sudo chown `whoami` otto   # NOTE: those are back ticks, not single quotes
    $ git clone git@github.com:ferguson/otto.git otto
    $ cd otto

    # setup python
    $ cd /usr/local
    $ virtualenv otto
    $ cd otto
    $ . activate   # NOTE: there is a space between the "." and "activate"
    $ python setup.py install


Download and install MongoDB. You can install it directly in /usr/local/otto, or you can put a link to the mongod executable in /usr/local/otto/bin.

Download and install Node.js. Like MongoDB, you can install it directly in /usr/local/otto or link to node and npm in /usr/local/otto/bin.

    $ cd /usr/local/otto
    $ npm install

MPD is the hardest part. You can try installing MPD using a package manager for your OS, but some versions of MPD are not compiled with the httpd server enabled and Otto requires it. You might need to compile MPD from source. Or you might be able to use the package manager as a starting point and tweak it's configuration files to enable a recompile with the --enable-http-server option.

Once you have a working MPD, put a link to it in /usr/local/otto/bin.

To start Otto:

    $ cd /usr/local/otto
    $ ./start.sh  # no space (unlike . activate below)

You can ignore mpd "Failed to load database" errors and dire looking warnings about the "Apple Bonjour compatibility layer of Avahi"

NOTE: To stop Otto press ctrl-c on start.sh

Then point a browser on your machine to http://localhost:8778/

Otto should be running at this point, but it's pretty boring since it doesn't know about any music.

Linux Loading Music
-------------------

Let Otto continue to run and open another terminal. Then:

    $ cd /usr/local/otto
    $ . activate
    $ python loader.py

Otto will then look in your Music directory and load all the music files it can find there.
Otto doesn't move or modify your music in any way, it simple builds a database containing information about the music it finds. Note that Otto must be running before you run loader.py or else it can't use the database.

You can re-run the steps above any time you want Otto to load more music. You can also give an argument to loader.py to tell it to look for music somewhere else:

    $ python loader.py /Volumes/MyMusicDisk   # for example

Otto remembers all the music it previously saw, so you can run loader.py several times with different arguments to build a database that covers several different folders. If you want to remove music from Otto, currently the only was is to delete the database and load it from scratch again. Otto keeps the database in /usr/local/otto/var. If you remove that directory Otto will start from scratch the next time you do the three shell commands listed above (with Otto running).

Otto associates an owner name with the files it loads. Owner names are determined by directory names that are named like an email address (has an "@" in it). If a given music file has a perent directory that looks like an email address, it will use that email address as the owner of all music found in that directory. You can also create a special otto.json file in a directory to set the owner for everything in that directory. Here is an example otto.json file that sets the owner:

    { "owner": "jon@ottoaudiojukebox.com" }

If no directory has an @ in it and there is no otto.json file, Otto will default to using the username of the user currently running the loader.py script.


