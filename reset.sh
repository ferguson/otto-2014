#!/bin/sh

killall mpd     2>/dev/null
killall mongod  2>/dev/null
killall node    2>/dev/null

sleep 1

killall -9 mpd     2>/dev/null
killall -9 mongod  2>/dev/null
killall -9 node    2>/dev/null

rm /usr/local/otto/var/mpd/??state  2>/dev/null

ps auxwww | egrep "[m]pd|[m]ongod|[n]ode|[o]tto"

exit

