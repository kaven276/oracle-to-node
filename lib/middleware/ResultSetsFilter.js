/**
 * Created by cuccpkfs on 14-12-15.
 */

var EE = require('events').EventEmitter
  , parse = require('./../RSParser.js').rsParse
  , mimeType = 'text/resultsets;'
  , mimeLen = mimeType.length
  ;

module.exports = function ResultSetsFilter(oraRes, ohdr, flags){
  if (ohdr._convert === 'JSON' && ohdr['Content-Type'] && ohdr['Content-Type'].substr(0, mimeLen) === mimeType) ; else {
    return oraRes;
  }
  var chunks = []
    , count = 0
    , ee = new EE()
    ;
  oraRes.on('data', function(data){
    if (!data) return true;
    chunks.push(data);
    count += data.length;
  });
  oraRes.on('end', function(){
    var buf = new Buffer(count)
      , offset = 0
      ;
    chunks.forEach(function(chunk){
      chunk.copy(buf, offset);
      offset += chunk.length;
    });
    var rss = parse(buf.toString('utf8'))
      , rJson = JSON.stringify(rss)
      , bJson = new Buffer(rJson)
      ;
    delete ohdr['Transfer-Encoding'];
    ohdr['Content-Type'] = 'application/json';
    ohdr['Content-Length'] = (bJson.length).toString();
    ee.emit('end', [bJson]);
  });
  flags.headFixed = false;
  return ee;
};
