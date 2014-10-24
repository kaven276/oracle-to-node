/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 14-10-20
 * Time: 下午4:58
 */

var sessionStore = {}

function Session(){
  this.store = {};
  this.LAT = Date.now();
}
Session.prototype.set = function(name, value){
  this.store[name] = value;
  // todo: write to log;
};
function createSession(app, bsid){
  try {
    return sessionStore[app][bsid] = new Session();
  } catch (e) {
    sessionStore[app] = {};
    return sessionStore[app][bsid] = new Session();
  }
}

function destroySession(app, bsid){
  try {
    delete sessionStore[app][bsid];
  } catch (e) {
    ;
  }
}

exports.create = createSession;
exports.destroy = destroySession;

// for sending app session data to oracle
exports.gets = function(app, bsid){
  try {
    return sessionStore[app][bsid];
  } catch (e1) {
    return false;
    try {
      // new bsid
      return sessionStore[app][bsid] = new Session();
    } catch (e2) {
      // new app
      sessionStore[app] = {};
      return sessionStore[app][bsid] = new Session();
    }
  }
};

function clearTimeout(){
  var now = Date.now();
  for (app in sessionStore) {
    var appSess = sessionStore[app];
    for (bsid in appSess) {
      var session = appSess[bsid]
      if ((now - session.LAT) > 20 * 60 * 1000) {
        delete appSess[bsid];
      }
    }
  }
}

setInterval(clearTimeout, 3 * 60 * 1000);