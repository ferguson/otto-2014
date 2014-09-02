import logging
logging.basicConfig(level=logging.DEBUG)
from socketIO_client import SocketIO, BaseNamespace

import time

def emit(name):
    if sio:
        print 'sending', name
        sio.emit(name)


def sio_event(self, events, *args):
    print 'sio event!'


class Object(object):
    pass

self = Object()
self.ticks_since_last_heartbeat = 0


class Namespace(BaseNamespace):
    def on_proceed_message(self, *args):
        print 'on_proceed'


def processSocketIO():
    global self
    print 'tick'
    global sio
    if sio:
        # process pending socket.io events
        #sio.wait(0.0001)
        print 'A'
        #sio._process_events()  # won't auto reconnect like wait() does, but runs smoother
        print 'B'
        # it also means we need to directly manage the socketIO heartbeats
        self.ticks_since_last_heartbeat += 1
        #if self.ticks_since_last_heartbeat > 300:  # every 30 seconds hopefully
        print 'socketIO tick'
        if self.ticks_since_last_heartbeat > 30:  # huh? FIXME
            print 'sending socketIO heartbeat'
            sio._transport.send_heartbeat()
            self.ticks_since_last_heartbeat = 0


sio = False

def openSocketIO():
    global sio
    sio = SocketIO('localhost', 8778, Namespace)
    sio.on_event = sio_event


if __name__ == '__main__':
    openSocketIO()
    while True:
        processSocketIO()
        time.sleep(0.001)
