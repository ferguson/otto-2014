jsonreq for Node.js
===================

JSON requests made easy. No more dealing with low-level HTTP events, chunked requests or responses,
buffering, etc. Just get and post to send and receive.


Installation
------------

    npm install jsonreq


Usage
-----

    var json = require('jsonreq');
    
    json.get('http://api.example.com/foo.json', function (err, data) {
        // ...
    });
    
    // TODO not implemented yet
    json.post('http://api.example.com/foo.json', data, function (err, data) {
        // ...
    });


Development
-----------

    npm link


Testing
-------

    npm test

