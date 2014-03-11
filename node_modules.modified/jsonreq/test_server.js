var should = require('should');

module.exports = require('http').createServer(function (req, resp) {
    
    // this is super simplistic and not flexible or robust.
    // that's ok -- this is just a simple server for testing.
    
    var body = [];
    
    req.setEncoding('utf8');
    
    req.on('data', function (chunk) {
        body.push(chunk);
    });
    
    req.on('end', function () {
        
        var bodyStr = body.join('');
        
        // if no data posted, just return
        if (!bodyStr) {
            return resp.end();
        }
        
        var data;
        
        try {
            data = JSON.parse(bodyStr);
            data.should.be.an.instanceof(Array);
        } catch (e) {
            resp.writeHead(400, e);
            return resp.end();
        }
        
        data.reverse();
        
        resp.setHeader('Content-Type', 'application/json');
        resp.end(JSON.stringify(data));
        
    });
    
});
