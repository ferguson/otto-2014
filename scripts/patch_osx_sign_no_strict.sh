#!/bin/sh

FILE=node_modules/electron-osx-sign/sign.js
EXPR="opts\\['strict-verify'\\] !== false &&\$"

if [ -e $FILE ]; then
    echo "patching electron-osx-sign to not supply the --strict argument to codesign..."
    if egrep -q "$EXPR" $FILE; then
        sed -i~ -e "s/$EXPR/& false \\&\\&/" $FILE  # add a "&& false" clause to make it always skip
        if [ "$?" == "0" ]; then
            echo "done"
        else
            echo "$0 - error: failed to patch $FILE, sed failed"
            exit 1
        fi
    else
        echo "$0 - error: failed to patch $FILE, perhaps it has already been patched?"
        exit 1
    fi
else
    echo "$0 - error: $FILE not found" >&2
    echo "$0 - error: run this script once after doing 'yarn install' in the root of the otto code repository" >&2
    exit 1
fi

exit

