/*
 * dc-lite — a tiny standalone runtime for the Duit OS .dc.html prototype.
 *
 * It understands the subset of the Design Component format the prototype uses:
 *   {{ dotted.path }} holes in text and attributes, <sc-if value>, <sc-for list as>,
 *   JSX-style events (onClick / onChange / onKeyDown), ref callbacks, <helmet> styles,
 *   and a `class Component extends DCLogic` with renderVals() + React-like setState.
 * Every render rebuilds the tree from the template and morphdom patches the live DOM,
 * so focus, caret and scroll positions survive re-renders.
 */
(function () {
  'use strict';

  var HOLE = /\{\{\s*([^}]*?)\s*\}\}/g;
  var WHOLE = /^\{\{\s*([^}]*?)\s*\}\}$/;
  var HTML_NS = 'http://www.w3.org/1999/xhtml';
  var EVENTS = ['click', 'input', 'change', 'keydown', 'keyup', 'focusin', 'focusout', 'submit'];

  var comp = null;
  var tplRoot = null;
  var host = null;
  var handlers = [];
  var queued = false;
  var mounted = false;
  var afterRender = [];

  function DCLogic(props) {
    this.props = props || {};
    this.state = {};
  }
  DCLogic.prototype.setState = function (patch, cb) {
    var next = typeof patch === 'function' ? patch(this.state, this.props) : patch;
    if (next != null) this.state = Object.assign({}, this.state, next);
    if (cb) afterRender.push(cb.bind(this));
    schedule();
  };
  DCLogic.prototype.forceUpdate = function (cb) {
    if (cb) afterRender.push(cb.bind(this));
    schedule();
  };

  function schedule() {
    if (queued || !mounted) return;
    queued = true;
    Promise.resolve().then(flush);
  }

  function flush() {
    if (!queued) return;
    queued = false;
    render();
  }

  // ---------- template evaluation ----------

  function lookup(path, scopes) {
    if (path === 'true') return true;
    if (path === 'false') return false;
    if (path === 'null') return null;
    if (/^-?\d+(\.\d+)?$/.test(path)) return Number(path);
    var parts = path.split('.');
    for (var i = scopes.length - 1; i >= 0; i--) {
      var sc = scopes[i];
      if (sc && Object.prototype.hasOwnProperty.call(sc, parts[0])) {
        var cur = sc[parts[0]];
        for (var j = 1; j < parts.length; j++) {
          if (cur == null) return undefined;
          cur = cur[parts[j]];
        }
        return cur;
      }
    }
    return undefined;
  }

  function interp(str, scopes) {
    return str.replace(HOLE, function (_, p) {
      var v = lookup(p, scopes);
      return v == null || typeof v === 'boolean' || typeof v === 'function' ? '' : String(v);
    });
  }

  function whole(str, scopes) {
    var m = WHOLE.exec(str);
    return m ? lookup(m[1], scopes) : str;
  }

  function eventType(attr, tplEl) {
    var t = attr.slice(2);
    if (t === 'change') {
      var type = (tplEl.getAttribute('type') || '').toLowerCase();
      var isToggle = tplEl.localName === 'select' || type === 'checkbox' || type === 'radio';
      return isToggle ? 'change' : 'input'; // React's onChange fires on every keystroke / slider move
    }
    if (t === 'focus') return 'focusin';
    if (t === 'blur') return 'focusout';
    return t;
  }

  function renderChildren(tpl, out, scopes, ctx) {
    for (var n = tpl.firstChild; n; n = n.nextSibling) renderNode(n, out, scopes, ctx);
  }

  function renderNode(n, out, scopes, ctx) {
    if (n.nodeType === 3) {
      var text = n.nodeValue;
      out.appendChild(document.createTextNode(text.indexOf('{{') < 0 ? text : interp(text, scopes)));
      return;
    }
    if (n.nodeType !== 1) return;

    var tag = n.localName;
    if (tag === 'helmet') return;
    if (tag === 'sc-if') {
      if (whole(n.getAttribute('value') || '', scopes)) renderChildren(n, out, scopes, ctx);
      return;
    }
    if (tag === 'sc-for') {
      var list = whole(n.getAttribute('list') || '', scopes);
      var as = n.getAttribute('as') || 'item';
      if (Array.isArray(list)) {
        for (var i = 0; i < list.length; i++) {
          var sc = { $index: i };
          sc[as] = list[i];
          renderChildren(n, out, scopes.concat([sc]), ctx);
        }
      }
      return;
    }

    var el = n.namespaceURI === HTML_NS ? document.createElement(tag) : document.createElementNS(n.namespaceURI, tag);
    for (var a = 0; a < n.attributes.length; a++) {
      var name = n.attributes[a].name;
      var raw = n.attributes[a].value;
      if (name.indexOf('hint-') === 0) continue;

      if (name === 'ref') {
        var ref = whole(raw, scopes);
        if (typeof ref === 'function') el.setAttribute('data-dc-ref', String(ctx.refs.push(ref) - 1));
        continue;
      }
      if (name.length > 2 && name.indexOf('on') === 0) {
        var fn = whole(raw, scopes);
        if (typeof fn === 'function') el.setAttribute('data-dc-' + eventType(name, n), String(ctx.handlers.push(fn) - 1));
        continue;
      }

      var m = WHOLE.exec(raw);
      if (m) {
        var v = lookup(m[1], scopes);
        var stringy = name.indexOf('aria-') === 0 || name.indexOf('data-') === 0;
        if (v == null || typeof v === 'function' || typeof v === 'object') continue;
        if (typeof v === 'boolean' && !stringy) {
          if (v) el.setAttribute(name, '');
          continue;
        }
        el.setAttribute(name, String(v));
      } else {
        el.setAttribute(name, raw.indexOf('{{') < 0 ? raw : interp(raw, scopes));
      }
    }
    renderChildren(n, el, scopes, ctx);
    out.appendChild(el);
  }

  function render() {
    try {
      var vals = comp.renderVals() || {};
      var ctx = { handlers: [], refs: [] };
      var next = document.createElement('div');
      renderChildren(tplRoot, next, [vals], ctx);
      handlers = ctx.handlers;
      window.morphdom(host, next, { childrenOnly: true });
      var refEls = host.querySelectorAll('[data-dc-ref]');
      for (var i = 0; i < refEls.length; i++) {
        var f = ctx.refs[Number(refEls[i].getAttribute('data-dc-ref'))];
        if (f) f(refEls[i]);
      }
    } catch (err) {
      fail(err);
      return;
    }
    var cbs = afterRender;
    afterRender = [];
    cbs.forEach(function (cb) { cb(); });
  }

  // ---------- events (delegated, React-style bubbling) ----------

  function dispatch(type, ev) {
    var snapshot = handlers;
    var stopped = false;
    var attr = 'data-dc-' + type;
    for (var el = ev.target; el && el !== host.parentNode; el = el.parentNode) {
      if (el.nodeType === 1 && el.hasAttribute(attr)) {
        var fn = snapshot[Number(el.getAttribute(attr))];
        if (fn) {
          fn({
            type: type,
            target: ev.target,
            currentTarget: el,
            key: ev.key,
            nativeEvent: ev,
            preventDefault: function () { ev.preventDefault(); },
            stopPropagation: function () { stopped = true; ev.stopPropagation(); },
          });
        }
        if (stopped) break;
      }
    }
    flush(); // keep controlled inputs in step with the keystroke that changed them
  }

  // ---------- boot ----------

  function readProps(script) {
    var defs = {};
    try { defs = JSON.parse(script.getAttribute('data-props') || '{}'); } catch (e) { defs = {}; }
    var props = {};
    Object.keys(defs).forEach(function (k) {
      if (k.charAt(0) !== '$' && defs[k] && 'default' in defs[k]) props[k] = defs[k].default;
    });
    // ?theme=night&palette=arcade&accent=berry&texture=false override the defaults
    new URLSearchParams(location.search).forEach(function (v, k) {
      if (!(k in props)) return;
      props[k] = typeof props[k] === 'boolean' ? v !== 'false' && v !== '0' : v;
    });
    return props;
  }

  function fail(err) {
    console.error(err);
    var box = document.getElementById('dc-error') || document.body.appendChild(document.createElement('pre'));
    box.id = 'dc-error';
    box.textContent = 'Duit OS crashed:\n' + (err && err.stack ? err.stack : String(err));
  }

  function boot(src, mountEl) {
    var doc = new DOMParser().parseFromString(src, 'text/html');
    var xdc = doc.querySelector('x-dc');
    var script = doc.querySelector('script[data-dc-script]');
    if (!xdc || !script) throw new Error('Not a .dc.html file');

    var helmet = xdc.querySelector('helmet');
    if (helmet) {
      Array.prototype.forEach.call(helmet.children, function (child) {
        document.head.appendChild(document.importNode(child, true));
      });
    }
    Array.prototype.forEach.call(document.querySelectorAll('style[data-dc-after]'), function (st) {
      document.head.appendChild(st);
    });

    var Component = new Function('DCLogic', script.textContent + '\n;return Component;')(DCLogic);
    comp = new Component(readProps(script));
    tplRoot = xdc;
    host = mountEl;
    host.textContent = '';

    EVENTS.forEach(function (type) {
      host.addEventListener(type, function (ev) { dispatch(type, ev); });
    });

    mounted = true;
    render();
    if (typeof comp.componentDidMount === 'function') comp.componentDidMount();
    flush();
  }

  window.dcLite = {
    load: function (url, mountEl) {
      return fetch(url, { cache: 'no-cache' })
        .then(function (r) {
          if (!r.ok) throw new Error('Could not load ' + url + ' (' + r.status + ')');
          return r.text();
        })
        .then(function (src) { boot(src, mountEl); })
        .catch(fail);
    },
  };
})();
