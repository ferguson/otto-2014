#!/bin/sh

ROOT=/usr/local/otto

if [ "$OTTO_ACTIVATE" != "$ROOT" ]; then
    echo "you need to . activate"
    exit 1
fi

cd $ROOT/app || exit

rm -rf $ROOT/app/dist/Simple.app

python simple_setup.py py2app $*

RES=dist/Simple.app/Contents/Resources
cp -p ../static/images/ottosplash.png $RES/

exit
