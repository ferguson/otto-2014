#!/bin/bash

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# lookup the full pathname before we cd $ROOT and lose any relative paths
DIR=""
if [ "$1" != "" ]; then
    if [ -d "$1" ]; then
	DIR="$(cd $1; pwd)"
    else
	echo "$0 error: $1 is not a directory"
	exit 1
    fi
fi

cd $ROOT
. activate

python scan.py $DIR

exit

