#!/bin/sh

# initially from http://stackoverflow.com/questions/96882/how-do-i-create-a-nice-looking-dmg-for-mac-os-x-using-command-line-tools

if [ ! -e dist/Otto.app ]; then
  echo "you need to build Otto.app first"
  exit 1
fi

if [ -e /Volumes/Otto ]; then
  hdiutil detach /Volumes/Otto
  sleep 2
fi

if [ -e /Volumes/Otto ]; then
  echo "error: /Volumes/Otto still exists"
  exit 1
fi

if [ -e "/Volumes/Otto 1" ]; then
  echo "that thing is happening"
  exit 1
fi

if [ -e dist/Otto.dmg ]; then
  rm -f dist/Otto.dmg
fi

#if [ -e pack.temp.dmg ]; then
#  echo removing old pack.tmp.dmg
#  rm -f pack.temp.dmg
#fi

if [ ! -e build/pack.temp.dmg ]; then
# this seems to make a vol which mounts as Otto *and* Otto 1
  rm -rf build/emptydir
  mkdir build/emptydir
  hdiutil create -srcfolder "build/emptydir" -volname "Otto" -fs HFS+ \
      -fsargs "-c c=64,a=16,e=16" -format UDRW -size 600m build/pack.temp.dmg
  rm -rf build/emptydir
# let's try again. nope! this still does it. but the above doesn't fail copying soft links
#  hdiutil create -srcfolder "dist" -volname "Otto" -fs HFS+ \
#      -fsargs "-c c=64,a=16,e=16" -format UDRW -size 600m build/pack.temp.dmg
fi

# don't need to save the device name, as of 10.4 you can give hdiutil detach the mount point
#device=$(hdiutil attach -readwrite -noverify -noautoopen "build/pack.temp.dmg" | \
#         egrep '^/dev/' | sed 1q | awk '{print $1}')
#echo $device

hdiutil attach -readwrite -noverify -noautoopen "build/pack.temp.dmg"
sleep 2

rm -rf /Volumes/Otto/{*,.??*}

rsync -a --progress dist/Otto.app /Volumes/Otto/

cp -p ../README.md /Volumes/Otto/README.txt

mkdir /Volumes/Otto/.background
cp -p ../static/images/dmg-background.png /Volumes/Otto/.background/background.png

echo '
   tell application "Finder"
     tell disk "'Otto'"
           open
           set current view of container window to icon view
           set toolbar visible of container window to false
           set statusbar visible of container window to false
           set the bounds of container window to {400, 100, 800, 400}
           set theViewOptions to the icon view options of container window
           set arrangement of theViewOptions to not arranged
           set icon size of theViewOptions to 72
           set background picture of theViewOptions to file ".background:'background.png'"
           make new alias file at container window to POSIX file "/Applications" with properties {name:"Applications"}
           set position of item "'Otto.app'" of container window to {100, 125}
           set position of item "Applications" of container window to {300, 125}
           update without registering applications
           #delay 5
           delay 2
           #eject
     end tell
   end tell
' | osascript

# this worked once, but then stopped?
cp ../static/images/ottoicon.icns /Volumes/Otto/.VolumeIcon.icns
# change the creator to icnC
SetFile -c icnC /Volumes/Otto/.VolumeIcon.icns
# set custom icon attribute
SetFile -a C /Volumes/Otto

#hdiutil attach -readwrite -noverify "build/pack.temp.dmg"
echo "adjust the icon(s) and hit return: "
read wait

chmod -Rf go-w /Volumes/Otto
sync  # i strongly suspect this is unnecessary
hdiutil detach /Volumes/Otto
sleep 2
hdiutil convert "build/pack.temp.dmg" -format UDZO -imagekey zlib-level=9 -o "dist/Otto.dmg"

#rm -f build/pack.temp.dmg 

