#!/bin/sh

self="$0"

# prepend current working dir if we were not given a full path
case "$self" in
   [^/]*) self="`pwd`/$self" ;;
esac

# remember our path might have spaces in it
MacOS="`dirname \"$self\"`"
Contents="`dirname \"$MacOS\"`"
Resources="$Contents/Resources"
App="`dirname \"$Contents\"`"

#echo $0
#echo $Resources
#/bin/env

cd "$Resources"
. activate

#exec "$Resources/bin/coffee" otto.app.coffee $*
# NodObjC not quite ready for prime time yet
exec "$Resources/bin/python" Otto.py $*
