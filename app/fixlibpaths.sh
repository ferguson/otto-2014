#!/bin/sh

LIB=$1
if [ "$LIB" == "" ]; then
  LIB="dist/Otto.app/Contents/Resources/lib"
fi

TAB="	"   # verbatium tab character
BADPATH="/usr/local/lib/"
REGEXP="^${TAB}$BADPATH"  
#REGEXP="^ +name $BADPATH"  # at some point osx > 10.7 changes the output to include "name" (w/o tabs)

echo "removing $BADPATH from $LIB/*.dylib"


fixes=0
for f in $LIB/*.dylib; do
    if [ -h "$f" ]; then
	continue
    fi
    if otool -L $f | egrep -q "$REGEXP"; then
	echo ":::" $f ":::"
	for x in `otool -L $f | egrep "$REGEXP" | awk '{print $1}'` ; do
	#for x in `otool -L $f | egrep "$REGEXP" | awk '{print $2}'` ; do   # if you use the "name" REGEXP above, then this needs to change too
	    minusbadpath="`echo $x | sed \"s%$BADPATH%%\"`"
	    fix="@executable_path/../lib/$minusbadpath"   # fails if lib has % in it's name
	    install_name_tool -change "$x" "$fix" "$f"
	    fixes=$((fixes+1))
	done
    fi
done


errors=0
#for f in $LIB/*.dylib; do
#    if otool -L $f | egrep -q "$REGEXP"; then
#	echo "$0 error: $f didn't get fixed"
#	errors=$((errors+1))
#    fi
#done
# it seems we can't check that way as the first entry (for the lib itself) never seems to get changed (we could skip that one)


if [ $fixes -lt 1 -o $errors -gt 0 ]; then
    if [ $fixes -lt 1 ]; then
	echo "$0 error: no fixes done to library paths!"
    fi
    exit 1
fi

exit
