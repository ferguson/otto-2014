#!/bin/sh

cd /usr/local/otto
watchfiles=`ls -1 *.coffee | egrep -v '[.]client[.]'`
watchlist=`echo $watchfiles | sed 's/ /,/g'`
echo $watchlist

NODE_ENV='development' supervisor -w $watchlist otto.coffee