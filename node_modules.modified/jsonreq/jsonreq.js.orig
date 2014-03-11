var http = require('http');
var url_parse = require('url').parse;

function req(method, url, data, callback) {
    
    url = url_parse(url);
    
    var opts = {
        host: url.hostname,
        port: url.port || 80,
        path: url.pathname + (url.search || ''),
        method: method,
        headers: {
            'Accept': 'application/json',
        },
    };
    
    var req = http.request(opts, function (resp) {
        
        if (resp.statusCode >= 400) {
            return callback(new Error(resp.statusCode));
        }
        
        // TODO should we auto-redirect? should that be an option?
        //if (resp.statusCode >= 300) {
        //    get(resp.headers['location'], callback);
        //    return;
        //}
        
        var body = [];
        
        // TEMP TODO should this really be hardcoded?
        resp.setEncoding('utf8');
        
        resp.on('data', function (chunk) {
            body.push(chunk);
        });
        
        resp.on('end', function () {
            var data, err, bodyStr = body.join('');
            
            try {
                data = bodyStr ? JSON.parse(bodyStr) : null;
            } catch (e) {
                err = e;
            }
            
            callback(err, data);
        });
        
    });
    
    req.on('error', function (err) {
        callback(err);
    });
    
    if (data) {
        req.setHeader('Content-Type', 'application/json');
        req.write(JSON.stringify(data));
    }
    
    req.end();
    
};

exports.get = function get(url, callback) {
    req('GET', url, null, callback);
};

exports.post = function post(url, data, callback) {
    req('POST', url, data, callback);
};