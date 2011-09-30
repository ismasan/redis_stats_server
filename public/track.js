(function () {
  var image = new Image()
  
  _tracker = {
    resource: function () {
      return this.escape(document.location.href)
    },
    
    escape: function (a) {
      return (typeof(encodeURIComponent) == 'function') ? encodeURIComponent(a) : escape(a)
    },
    
    referrer: function () {
      var a = '';
      try {
        a = top.document.referrer
      } catch (e1) {
        try {
          a = parent.document.referrer
        } catch (e2) {
          a = ''
        }
      }
      if (a == '') {
        a = document.referrer
      }
      return this.escape(a)
    },
    
    path: function () {
      return location.pathname;
    },
    
    domain: function () {
      return window.location.hostname
    },
    
    title: function () {
      return (document.title && document.title != "") ? this.escape(document.title) : ''
    },
    
    agent: function () {
      return this.escape(navigator.userAgent)
    },
    
    timezoneOffset: function () {
      return Math.round(new Date().getTimezoneOffset() / 60); // -2, 4, etc
    },
    
    /*
    h       host
    r       resource
    ref     referrer
    */
    url: function () {
      var s = document.getElementById('tiny-tracker')
      var account = s.getAttribute('data-account-id');
      var u = s.src.replace('/track.js', '/track.gif');
      u += "?a="    + account;
      u += "&r="    + this.resource();
      u += "&ref="  + this.referrer();
      u += "&tt="   + this.title();
      u += "&h="    + this.domain();
      // u += "&uid="  + this.sessionId();
      // u += "&u="    + this.agent();
      u += "&p="    + this.path();
      u += "&tz="   + this.timezoneOffset()
      return u
    },
    
    setCookie: function (a, b, d) {
      var f, c;
      b = escape(b);
      if (d) {
        f = new Date();
        f.setTime(f.getTime() + (d * 1000));
        c = '; expires=' + f.toGMTString()
      } else {
        c = ''
      }
      document.cookie = a + "=" + b + c + "; path=/"
    },
    
    getCookie: function (a) {
      var b = a + "=",
          d = document.cookie.split(';');
      for (var f = 0; f < d.length; f++) {
        var c = d[f];
        while (c.charAt(0) == ' ') {
          c = c.substring(1, c.length)
        }
        if (c.indexOf(b) == 0) {
          return unescape(c.substring(b.length, c.length))
        }
      }
      return null
    },
    
    sessionId: function () {
      var session_id = this.getCookie('_tracker_sessid')
      if(!session_id) {
        session_id = new Date().getTime() + Math.random() + Math.random()
        this.setCookie('_tracker_sessid', session_id)
      }
      return session_id
    },
    
    track: function () {
      console.log('URL', this.url())
      image.src = this.url()
    }
  }
  
  _tracker.track()
})();