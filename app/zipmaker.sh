#!/bin/sh

timestamp=`date "+%Y%m%d%H%M"`
zipfile="Otto-${timestamp}.zip"

if [ -e dist/$zipfile ]; then
  echo "dist/$zipfile already exists! just wait a minute."
  exit 1
fi

echo "zipping Otto.app..."
(cd dist; zip -y -r -q $zipfile Otto.app)

# from http://hintsforums.macworld.com/showthread.php?t=70769
#Rez -append ../static/images/dmgicon1.rsrc -o "dist/$zipfile"

# from http://stackoverflow.com/questions/8371790/how-to-set-icon-on-file-or-directory-using-cli-on-os-x
rm -f build/zipicon.icns
cp -p ../static/images/ottoicon.icns build/zipicon.icns
# Add icon to image file, meaning use itself as the icon
sips -i build/zipicon.icns
# Take that icon and put it into a rsrc file
DeRez -only icns build/zipicon.icns > build/zipicon.rsrc
Rez -append build/zipicon.rsrc -o "dist/$zipfile"
SetFile -a C "dist/$zipfile"
# don't know why that isn't working. or is it?

ls -l "dist/$zipfile"
echo "size:" `du -sh dist/$zipfile`

exit
