/// JavaScript-side host API injected into every plugin context.
///
/// Design: plugins get a `fetch`/`axios`-like client whose transport is a
/// Dart message channel. That means no XHR in JS, so Dart controls every
/// request (headers, cookies, redirects, logging, SSRF blocking).
///
/// A minimal cheerio-compatible subset is provided because most scrapers only
/// use `load`, `find`, `attr`, `text`, `html` and `each`. Anything unsupported
/// throws a clear error that shows up in the plugin health panel instead of
/// silently returning wrong data.
class HostApiShim {
  const HostApiShim._();

  /// Core bridge: `__aeroSend(channel, payloadJson)` returns a Promise of String.
  static const String bridge = r'''
(function (global) {
  if (global.__aeroReady) return;
  global.__aeroReady = true;

  var pending = {};
  var nextId = 1;

  global.__aeroResolve = function (id, ok, payload) {
    var p = pending[id];
    if (!p) return;
    delete pending[id];
    if (ok) { p.resolve(payload); } else { p.reject(new Error(payload)); }
  };

  global.__aeroSend = function (channel, payload) {
    return new Promise(function (resolve, reject) {
      var id = nextId++;
      pending[id] = { resolve: resolve, reject: reject };
      try {
        sendMessage('aero:' + channel, JSON.stringify({ id: id, payload: payload || {} }));
      } catch (e) {
        delete pending[id];
        reject(e);
      }
    });
  };

  // ---------------- console ----------------
  global.console = {
    log: function () { global.__aeroSend('log', { level: 'log', args: Array.prototype.map.call(arguments, String) }); },
    info: function () { global.__aeroSend('log', { level: 'info', args: Array.prototype.map.call(arguments, String) }); },
    warn: function () { global.__aeroSend('log', { level: 'warn', args: Array.prototype.map.call(arguments, String) }); },
    error: function () { global.__aeroSend('log', { level: 'error', args: Array.prototype.map.call(arguments, String) }); },
    debug: function () { global.__aeroSend('log', { level: 'debug', args: Array.prototype.map.call(arguments, String) }); }
  };

  // ---------------- base64 / text ----------------
  var B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  global.btoa = function (s) {
    s = String(s); var out = '', i = 0;
    while (i < s.length) {
      var c1 = s.charCodeAt(i++) & 0xff;
      var c2 = i < s.length ? s.charCodeAt(i++) & 0xff : NaN;
      var c3 = i < s.length ? s.charCodeAt(i++) & 0xff : NaN;
      var e1 = c1 >> 2, e2 = ((c1 & 3) << 4) | (c2 >> 4);
      var e3 = isNaN(c2) ? 64 : (((c2 & 15) << 2) | (c3 >> 6));
      var e4 = isNaN(c3) ? 64 : (c3 & 63);
      out += B64.charAt(e1) + B64.charAt(e2) +
             (e3 === 64 ? '=' : B64.charAt(e3)) +
             (e4 === 64 ? '=' : B64.charAt(e4));
    }
    return out;
  };
  global.atob = function (s) {
    s = String(s).replace(/[^A-Za-z0-9+/=]/g, '');
    var out = '', i = 0;
    while (i < s.length) {
      var e1 = B64.indexOf(s.charAt(i++)), e2 = B64.indexOf(s.charAt(i++));
      var e3 = B64.indexOf(s.charAt(i++)), e4 = B64.indexOf(s.charAt(i++));
      var c1 = (e1 << 2) | (e2 >> 4);
      var c2 = ((e2 & 15) << 4) | (e3 >> 2);
      var c3 = ((e3 & 3) << 6) | e4;
      out += String.fromCharCode(c1);
      if (e3 !== 64 && e3 !== -1) out += String.fromCharCode(c2);
      if (e4 !== 64 && e4 !== -1) out += String.fromCharCode(c3);
    }
    return out;
  };
  global.TextEncoder = function () {};
  global.TextEncoder.prototype.encode = function (s) {
    var arr = []; s = String(s);
    for (var i = 0; i < s.length; i++) arr.push(s.charCodeAt(i) & 0xff);
    return new Uint8Array(arr);
  };
  global.TextDecoder = function () {};
  global.TextDecoder.prototype.decode = function (buf) {
    var out = '';
    for (var i = 0; i < buf.length; i++) out += String.fromCharCode(buf[i]);
    return out;
  };

  // ---------------- crypto helpers (delegated to Dart) ----------------
  global.__aeroCrypto = {
    md5: function (s) { return global.__aeroSend('crypto', { op: 'md5', data: String(s) }); },
    sha1: function (s) { return global.__aeroSend('crypto', { op: 'sha1', data: String(s) }); },
    sha256: function (s) { return global.__aeroSend('crypto', { op: 'sha256', data: String(s) }); },
    hmacSha256: function (s, k) { return global.__aeroSend('crypto', { op: 'hmac', data: String(s), key: String(k) }); },
    randomBytes: function (n) { return global.__aeroSend('crypto', { op: 'random', length: n | 0 }); }
  };

  // ---------------- HTTP ----------------
  function buildUrl(url, params) {
    if (!params) return url;
    var qs = Object.keys(params).map(function (k) {
      return encodeURIComponent(k) + '=' + encodeURIComponent(params[k]);
    }).join('&');
    if (!qs) return url;
    return url + (url.indexOf('?') >= 0 ? '&' : '?') + qs;
  }

  function doRequest(method, url, opts) {
    opts = opts || {};
    var target = buildUrl(url, opts.params);
    return global.__aeroSend('http', {
      method: method,
      url: target,
      headers: opts.headers || {},
      body: opts.body == null ? null : (typeof opts.body === 'string' ? opts.body : JSON.stringify(opts.body)),
      timeoutMs: opts.timeout || 0,
      followRedirects: opts.followRedirects !== false
    }).then(function (raw) {
      var res = JSON.parse(raw);
      return {
        ok: res.status >= 200 && res.status < 300,
        status: res.status,
        statusText: res.statusText || '',
        url: res.url || target,
        headers: res.headers || {},
        data: res.body,
        text: function () { return Promise.resolve(res.body); },
        json: function () {
          try { return Promise.resolve(JSON.parse(res.body)); }
          catch (e) { return Promise.reject(e); }
        }
      };
    });
  }

  global.fetch = function (url, opts) { return doRequest((opts && opts.method) || 'GET', url, opts); };

  function axiosInstance(defaults) {
    function request(config) {
      config = config || {};
      var merged = {
        method: config.method || 'GET',
        headers: Object.assign({}, defaults.headers || {}, config.headers || {}),
        params: config.params,
        body: config.data,
        timeout: config.timeout || defaults.timeout
      };
      var url = config.url || '';
      if (defaults.baseURL && !/^https?:\/\//i.test(url)) {
        url = defaults.baseURL.replace(/\/$/, '') + '/' + url.replace(/^\//, '');
      }
      return doRequest(merged.method.toUpperCase(), url, merged);
    }
    ['get', 'delete', 'head', 'options'].forEach(function (m) {
      request[m] = function (url, config) {
        return request(Object.assign({}, config || {}, { url: url, method: m }));
      };
    });
    ['post', 'put', 'patch'].forEach(function (m) {
      request[m] = function (url, data, config) {
        return request(Object.assign({}, config || {}, { url: url, method: m, data: data }));
      };
    });
    request.create = function (cfg) { return axiosInstance(Object.assign({}, defaults, cfg || {})); };
    request.defaults = defaults;
    return request;
  }
  global.axios = axiosInstance({});

  // ---------------- timers ----------------
  var timers = {}; var timerId = 1;
  global.setTimeout = function (fn, ms) {
    var id = timerId++;
    timers[id] = fn;
    global.__aeroSend('timer', { id: id, ms: ms | 0 });
    return id;
  };
  global.clearTimeout = function (id) { delete timers[id]; };
  global.__aeroFireTimer = function (id) {
    var fn = timers[id];
    if (fn) { delete timers[id]; try { fn(); } catch (e) { console.error(e); } }
  };
  global.setInterval = function () { throw new Error('setInterval is not available in the Aero sandbox'); };
  global.clearInterval = function () {};

  // ---------------- storage (per-plugin, in-memory) ----------------
  var store = {};
  global.localStorage = {
    getItem: function (k) { return Object.prototype.hasOwnProperty.call(store, k) ? store[k] : null; },
    setItem: function (k, v) { store[k] = String(v); },
    removeItem: function (k) { delete store[k]; },
    clear: function () { store = {}; }
  };

  // Explicitly deny dangerous globals.
  global.XMLHttpRequest = undefined;
  global.WebSocket = undefined;
  global.eval = undefined;
  global.Function = undefined;
})(this);
''';

  /// Minimal cheerio-compatible HTML reader backed by Dart's parser bridge.
  ///
  /// Rather than shipping cheerio's ~500 KB bundle into every context, we
  /// proxy selector queries to Dart. Scrapers use a narrow API surface, and
  /// unsupported selectors raise a descriptive error.
  static const String cheerio = r'''
(function (global) {
  if (global.cheerio) return;

  function Cheerio(docId, selector) {
    this._doc = docId;
    this._sel = selector || null;
    this.length = 0;
  }

  Cheerio.prototype._query = function (op, args) {
    return global.__aeroSend('html', {
      op: op, doc: this._doc, selector: this._sel, args: args || {}
    }).then(function (raw) { return JSON.parse(raw); });
  };

  Cheerio.prototype.ready = function () {
    var self = this;
    return this._query('count').then(function (r) { self.length = r.count || 0; return self; });
  };
  Cheerio.prototype.find = function (sel) {
    var next = new Cheerio(this._doc, this._sel ? this._sel + ' ' + sel : sel);
    return next;
  };
  Cheerio.prototype.eq = function (i) {
    return new Cheerio(this._doc, (this._sel || '') + ':nth-of-type(' + (i + 1) + ')');
  };
  Cheerio.prototype.first = function () { return this.eq(0); };
  Cheerio.prototype.attr = function (name) { return this._query('attr', { name: name }).then(function (r) { return r.value; }); };
  Cheerio.prototype.text = function () { return this._query('text').then(function (r) { return r.value; }); };
  Cheerio.prototype.html = function () { return this._query('html').then(function (r) { return r.value; }); };
  Cheerio.prototype.toArray = function () {
    return this._query('list').then(function (r) {
      return (r.selectors || []).map(function (s) { return new Cheerio(this._doc, s); }.bind(this));
    });
  };
  Cheerio.prototype.each = function (fn) {
    var self = this;
    return this.toArray().then(function (nodes) {
      return Promise.all(nodes.map(function (n, i) { return fn.call(n, i, n); }));
    });
  };
  Cheerio.prototype.map = function (fn) {
    return this.each(fn);
  };

  global.cheerio = {
    load: function (html) {
      var docId = null;
      // Register the document synchronously-ish, then return a callable.
      var ready = global.__aeroSend('html', { op: 'load', html: String(html) })
        .then(function (raw) { docId = JSON.parse(raw).doc; });
      function root(selector) {
        var c = new Cheerio(docId, selector);
        return c;
      }
      root.ready = ready;
      root.html = function () { return global.__aeroSend('html', { op: 'raw', doc: docId }).then(function (r) { return JSON.parse(r).value; }); };
      root.root = function () { return new Cheerio(docId, null); };
      return root;
    }
  };
  global.load = global.cheerio.load;
})(this);
''';

  static String full({bool includeHtmlParser = true}) =>
      includeHtmlParser ? '$bridge\n$cheerio' : bridge;
}
