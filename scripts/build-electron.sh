#!/bin/bash

rm -rf build
mkdir build

echo "packaging up scan..."
scripts/makescan.sh

echo "staging build..."
cp -p assets/ottoicon.icns build/icon.icns
cp -p assets/dmg-background.png build/background.png
cp -p assets/dmgicon.icns build/

mkdir build/bin
cp -p bin/{mongod,mpd,scan} build/bin/

cp -a dist/mpd/lib build/

echo "building electron..."
bin/electron-builder .

echo ""
echo "done."
echo ""

exit
