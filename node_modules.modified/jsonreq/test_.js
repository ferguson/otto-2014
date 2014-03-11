var json = require('./');
var should = require('should');
var streamline = require('streamline');
var flows = streamline.flows;

var SERVER = require('./test_server');
var SERVER_PORT = 9999;
var SERVER_ADDRESS = 'http://localhost:' + SERVER_PORT;

var TEST_CASES = {
    
    'Non-existent': {
        url: 'http://i.certainly.dont.exist.example.com',
        err: /ENOTFOUND/,
    },
    
    'Non-200': {
        url: 'http://json.org/404',
        err: /404/,
    },
    
    'Non-JSON': {
        url: 'http://google.com/',
        err: /SyntaxError/,
    },
    
    'Empty JSON': {
        url: SERVER_ADDRESS,
        exp: null,
    },
    
    // via http://dev.twitter.com/doc/get/statuses/show/:id
    'Twitter': {
        url: 'https://api.twitter.com/1/statuses/show/20.json',
        // too much here (and may change) to test deep equality; assume it's valid
    },
    
    // via http://zoom.it/pages/api/reference/v1/content/get-by-id
    'Zoom.it': {
        url: 'http://api.zoom.it/v1/content/h',
        exp: {
            id: 'h',
            url: 'http://upload.wikimedia.org/wikipedia/commons/3/36/SeattleI5Skyline.jpg',
            ready: true,
            failed: false,
            progress: 1,
            shareUrl: 'http://zoom.it/h',
            embedHtml: '<script src="http://zoom.it/h.js?width=auto&height=400px"></script>',
            dzi: {
                url: 'http://cache.zoom.it/content/h.dzi',
                width: 4013,
                height: 2405,
                tileSize: 254,
                tileOverlap: 1,
                tileFormat: 'jpg',
            },
        },
    },
    
    // our test server reverses data passed to it
    'Post JSON': {
        url: SERVER_ADDRESS,
        post: [ 'alpha', 'beta', 'gamma', {
            'delta': 'epsilon',
        }],
        exp: [{
            'delta': 'epsilon',
        }, 'gamma', 'beta', 'alpha'],
    },
    
};

var started = 0,
    finished = 0;

process.on('exit', function () {
    var remaining = started - finished;
    remaining.should.equal(0, remaining + ' callbacks never fired!');
});

function test(name, data, _) {
    var act, err;
    
    started++;
    
    try {
        if (data.post) {
            act = json.post(data.url, data.post, _);
        } else {
            act = json.get(data.url, _);
        }
    } catch (e) {
        err = e;
    }
    
    finished++;
    
    if (data.err) {
        should.exist(err, 'expected error, received result: ' + act);
        err.should.match(data.err, 'error doesn\'t match expected: ' + err + ' vs. ' + data.err);
        should.not.exist(act, 'received error *and* result: ' + act);
        return;
    }
    
    should.not.exist(err);
    should.be.defined(act, 'received neither error not result');
        // note how act can be null, but cannot be undefined
    
    // TEMP act and data.exp can be null, so we can't be totally expressive here. see comments:
    
    // equivalent to "act should be of type object"
    // note that {...}, [...] and null are all type 'object'
    (typeof act === 'object').should.be.truthy(name + ' returned content is not an object or array: ' + act);
    
    if ('exp' in data) {    // i.e. it's specified (but can be null)
        // equivalent to "act should match data.exp", but need to account for null
        should.deepEqual(act, data.exp, name + ' content doesn\'t match expected: ' + act + ' vs. ' + data.exp);
    }
}

function tryTest(name, data, _) {
    try {
        test(name, data, _);
        console.log('\t✓ ' + name);
    } catch (e) {
        console.log('\tx ' + name);
        console.error('\t  ' + e.message);
        // don't propagate!
    }
}

console.log();
SERVER.listen(SERVER_PORT, _);      // wait for it to start

var testFutures = [];

for (var name in TEST_CASES) {
    testFutures.push(
        tryTest(name, TEST_CASES[name])
    );
}

flows.spray(testFutures).collectAll(_);

SERVER.close();
console.log();
