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

# https://stackoverflow.com/questions/31709087/failure-digitally-signing-a-mac-app-outside-xcode

install_name_tool \
    -change /Users/jon/otto/lib/libfaad.2.dylib ../lib/libfaad.2.dylib \
    -change /Users/jon/otto/lib/libzzip-0.13.dylib ../lib/libzzip-0.13.dylib \
    -change /Users/jon/otto/lib/libmms.0.dylib ../lib/libmms.0.dylib \
    -change /Users/jon/otto/lib/libglib-2.0.0.dylib ../lib/libglib-2.0.0.dylib \
    -change /Users/jon/otto/lib/libintl.8.dylib ../lib/libintl.8.dylib \
    -change /Users/jon/otto/lib/libid3tag.0.dylib ../lib/libid3tag.0.dylib \
    -change /Users/jon/otto/lib/libvorbisfile.3.dylib ../lib/libvorbisfile.3.dylib \
    -change /Users/jon/otto/lib/libvorbis.0.dylib ../lib/libvorbis.0.dylib \
    -change /Users/jon/otto/lib/libogg.0.dylib ../lib/libogg.0.dylib \
    -change /Users/jon/otto/lib/libFLAC.8.dylib ../lib/libFLAC.8.dylib \
    -change /Users/jon/otto/lib/libsndfile.1.dylib ../lib/libsndfile.1.dylib \
    -change /Users/jon/otto/lib/libaudiofile.0.dylib ../lib/libaudiofile.0.dylib \
    -change /Users/jon/otto/lib/libwavpack.1.dylib ../lib/libwavpack.1.dylib \
    -change /Users/jon/otto/lib/libiconv.2.dylib ../lib/libiconv.2.dylib \
    -change /Users/jon/otto/lib/libmad.0.dylib ../lib/libmad.0.dylib \
    -change /Users/jon/otto/lib/libcue.1.dylib ../lib/libcue.1.dylib \
    -change /Users/jon/otto/lib/libmp3lame.0.dylib ../lib/libmp3lame.0.dylib \
    -change /Users/jon/otto/lib/libtwolame.0.dylib ../lib/libtwolame.0.dylib \
    -change /Users/jon/otto/lib/libvorbisenc.2.dylib ../lib/libvorbisenc.2.dylib \
    -change /Users/jon/otto/lib/libshout.3.dylib ../lib/libshout.3.dylib \
    -change /Users/jon/otto/lib/libsamplerate.0.dylib ../lib/libsamplerate.0.dylib \
    -change /Users/jon/otto/lib/libgthread-2.0.0.dylib ../lib/libgthread-2.0.0.dylib \
    build/bin/mpd

cp -a dist/mpd/lib build/

for f in `find build/lib -type f -name "*.dylib"`; do
    for g in `otool -L $f | egrep "/Users/jon/otto/lib" | cut -d' ' -f1`; do
	newpath="`echo $g | sed -e 's%/Users/jon/otto/lib/%../lib/%'`"
	install_name_tool -change $g $newpath $f
    done
done

echo "building electron..."
bin/electron-builder .

echo ""
echo "done."
echo ""

exit
