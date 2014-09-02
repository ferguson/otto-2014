#!/bin/sh

# initially from http://stackoverflow.com/questions/96882/how-do-i-create-a-nice-looking-dmg-for-mac-os-x-using-command-line-tools
# with some help from http://el-tramo.be/guides/fancy-dmg/
# and http://digital-sushi.org/entry/how-to-create-a-disk-image-installer-for-apple-mac-os-x/

if [ ! -e dist/Otto.app ]; then
  echo "you need to build Otto.app first"
  exit 1
fi

if [ ! -e build ]; then
  mkdir build
fi

for f in InstallOtto Empty Pack; do
  if [ -e build/$f ]; then
    hdiutil detach build/$f
    sleep 2
  fi

  if [ -e build/$f ]; then
    echo "error: build/$f still exists"
    exit 1
  fi

  if [ -e "build/$f 1" ]; then
    echo "that thing is happening"
    exit 1
  fi
done

if [ ! -e build/empty.dmg ]; then
  echo "build/empty.dmg missing, rebuilding it"

  # this sometimes seems to make a vol which mounts as Otto *and* Otto 1
  #rm -f build/empty.dmg
  rm -rf build/emptydir
  mkdir build/emptydir
  hdiutil create -size 1M -srcfolder "build/emptydir" -volname "InstallOtto" -fs HFS+ \
      -fsargs "-c c=64,a=16,e=16" -format UDRW build/empty.dmg
  rm -rf build/emptydir
  # let's try again. nope! this still does it. but the above doesn't fail copying soft links
  #  hdiutil create -srcfolder "dist" -volname "InstallOtto" -fs HFS+ \
  #      -fsargs "-c c=64,a=16,e=16" -format UDRW -size 600m build/pack.dmg

  hdiutil attach -readwrite -noverify -noautoopen "build/empty.dmg" -mountpoint "build/Empty"
  sleep 2

  #rm -rf build/Empty/{*,.??*}

  mkdir build/Empty/.background
  cp -p ../static/images/dmg-background.png build/Empty/.background/background.png
  #cp -p ../static/images/ottoicon.icns build/Empty/.VolumeIcon.icns
  cp -p ../static/images/dmgicon.icns build/Empty/.VolumeIcon.icns
  # change the creator to icnC
  SetFile -c icnC build/Empty/.VolumeIcon.icns
  # set custom icon attribute
  SetFile -a C build/Empty

  mkdir build/Empty/Otto.app
  touch build/Empty/README.txt
  ln -s /Applications build/Empty/Applications

  echo '
     tell application "Finder"
       tell disk "Empty"
             open
             set current view of container window to icon view
             set toolbar visible of container window to false
             set statusbar visible of container window to false
             set the bounds of container window to {200, 100, 700, 500}
             set theViewOptions to the icon view options of container window
             set arrangement of theViewOptions to not arranged
             set icon size of theViewOptions to 96
             set text size of theViewOptions to 16
             set background picture of theViewOptions to file ".background:background.png"
             #make new alias file at container window to POSIX file "/Applications" with properties {name:"Applications"}
             set position of item "Otto.app" of container window to {95, 245}
             set position of item "Applications" of container window to {395, 245}
             set position of item "README.txt" of container window to {250, 80}
             update without registering applications
             close
             delay 0.5
             open
             #eject
       end tell
     end tell
  ' | osascript

  #echo "check/adjust the icon(s) and hit return: "
  #read wait
  
  hdiutil detach build/Empty
  sleep 1
fi

if [ -e dist/pack.dmg ]; then
  echo "removing old pack.dmg"
  rm -f dist/pack.dmg
fi

timestamp=`date "+%Y%m%d%H%M"`
dmgfile="Otto-${timestamp}.dmg"

if [ -e dist/$dmgfile ]; then
  echo "dist/$dmgfile already exists! just wait a minute."
  exit 1
fi

# we don't want to keep 600m disk images hanging around so we need to expand it
echo "building pack.dmg from empty.dmg"
cp -p build/empty.dmg build/pack.dmg
hdiutil resize -size 600M "build/pack.dmg"
hdiutil attach -readwrite -noverify -noautoopen "build/pack.dmg" -mountpoint build/InstallOtto
sleep 1

echo "copying Otto.app..."
#rsync -av dist/Otto.app build/InstallOtto
rsync -a dist/Otto.app build/InstallOtto

echo "copying README.md..."
cp -p ../README.md build/InstallOtto/README.txt

chmod -Rf go-w build/InstallOtto
hdiutil detach build/InstallOtto
sleep 1

hdiutil convert "build/pack.dmg" -format UDZO -imagekey zlib-level=9 -o "dist/$dmgfile"
rm -f build/pack.dmg

# from http://hintsforums.macworld.com/showthread.php?t=70769
#Rez -append ../static/images/dmgicon.rsrc -o "dist/$dmgfile"

# from http://stackoverflow.com/questions/8371790/how-to-set-icon-on-file-or-directory-using-cli-on-os-x
rm -f build/dmgicon.icns
cp -p ../static/images/dmgicon.icns build/dmgicon.icns
# Add icon to image file, meaning use itself as the icon
sips -i build/dmgicon.icns
# Take that icon and put it into a rsrc file
DeRez -only icns build/dmgicon.icns > build/dmgicon.rsrc
Rez -append build/dmgicon.rsrc -o "dist/$dmgfile"
SetFile -a C "dist/$dmgfile"

ls -l "dist/$dmgfile"
echo "size:" `du -sh dist/$dmgfile`

echo "done"

exit

