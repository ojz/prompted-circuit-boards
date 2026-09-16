// smoke.js: run the editor itself against a minimal DOM stub, so the code in
// sketcher.js executes outside a browser. `node sketcher/smoke.js`
//
// tests.js covers the format, the geometry and the sketchbook, none of which
// touch the DOM. This covers the rest: that the page's ids and the script
// agree, that startup renders, and that the first things a user does do not
// throw. It is not a rendering test and says nothing about how the page looks;
// the browser test page (tests.html) and a human eye are still what confirm
// that. It exists because a browser is not always available to the agent.
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const SKETCHER = __dirname;

function parseIds(html) {
  const ids = [];
  const re = /\bid="([^"]+)"/g;
  let m;
  while ((m = re.exec(html))) ids.push(m[1]);
  return ids;
}

// The smallest element that the editor's DOM and SVG calls can run against.
class El {
  constructor(tag, ns) {
    this.tagName = (tag || 'div').toUpperCase();
    this.ns = ns || null;
    this.children = [];
    this.attrs = {};
    this._text = '';
    this.value = '';
    this.checked = false;
    this.disabled = false;
    this.style = {};
    this.dataset = {};
    this.listeners = {};
    this.className = '';
    this.files = null;
    this.open = false;
    const self = this;
    this.classList = {
      add(c) { if (!self.className.split(' ').includes(c)) self.className = (self.className + ' ' + c).trim(); },
      remove(c) { self.className = self.className.split(' ').filter(x => x && x !== c).join(' '); },
      toggle(c, on) { on ? this.add(c) : this.remove(c); },
      contains(c) { return self.className.split(' ').includes(c); }
    };
  }
  get textContent() { return this._text; }
  set textContent(v) { this._text = String(v); this.children = []; }
  setAttribute(k, v) { this.attrs[k] = String(v); if (k === 'class') this.className = String(v); }
  getAttribute(k) { return k in this.attrs ? this.attrs[k] : null; }
  removeAttribute(k) { delete this.attrs[k]; }
  appendChild(c) { this.children.push(c); c.parentNode = this; return c; }
  removeChild(c) { this.children = this.children.filter(x => x !== c); return c; }
  addEventListener(t, f) { (this.listeners[t] = this.listeners[t] || []).push(f); }
  removeEventListener(t, f) { if (this.listeners[t]) this.listeners[t] = this.listeners[t].filter(x => x !== f); }
  dispatch(t, ev) { (this.listeners[t] || []).forEach(f => f.call(this, ev || {})); }
  focus() { doc.activeElement = this; }
  blur() { doc.activeElement = null; }
  setPointerCapture() {}
  createSVGPoint() { return { x: 0, y: 0, matrixTransform() { return { x: 0, y: 0 }; } }; }
  getScreenCTM() { return { inverse() { return {}; } }; }
  querySelector(sel) {
    const m = /^\[data-id="(.*)"\]$/.exec(sel);
    const want = m ? m[1] : null;
    const walk = (n) => {
      for (const c of n.children) {
        if (want !== null && c.attrs['data-id'] === want) return c;
        const r = walk(c);
        if (r) return r;
      }
      return null;
    };
    return walk(this);
  }
  querySelectorAll() { return []; }
}

const doc = {
  activeElement: null,
  byId: Object.create(null),
  getElementById(id) { return this.byId[id] || null; },
  createElement(t) { return new El(t); },
  createElementNS(ns, t) { return new El(t, ns); },
  createTextNode(t) { const e = new El('#text'); e._text = t; return e; },
  addEventListener() {},
  body: new El('body')
};

// Every id the page declares exists, and nothing else does: a lookup the page
// does not provide comes back null here exactly as it would in a browser.
const html = fs.readFileSync(path.join(SKETCHER, 'index.html'), 'utf8');
for (const id of parseIds(html)) {
  const e = new El('div');
  e.attrs.id = id;
  doc.byId[id] = e;
}

const backing = Object.create(null);
const localStorage = {
  getItem(k) { return k in backing ? backing[k] : null; },
  setItem(k, v) { backing[k] = String(v); },
  removeItem(k) { delete backing[k]; },
  key(i) { return Object.keys(backing)[i] || null; },
  get length() { return Object.keys(backing).length; }
};

const sandbox = {
  document: doc, localStorage, console,
  navigator: {}, location: { protocol: 'file:' },
  window: null, globalThis: null,
  addEventListener() {},
  setTimeout: (f) => { f(); },
  Blob: function () {},
  URL: { createObjectURL: () => 'blob:stub', revokeObjectURL() {} },
  FileReader: function () {},
  JSON, Math, Object, Array, String, Number, Boolean, Error, RegExp,
  isFinite, isNaN, parseInt, parseFloat, Date
};
sandbox.window = sandbox;
sandbox.globalThis = sandbox;
vm.createContext(sandbox);

for (const f of ['catalogue.js', 'sketch-core.js', 'sketchbook.js', 'sketcher.js']) {
  vm.runInContext(fs.readFileSync(path.join(SKETCHER, f), 'utf8'), sandbox, { filename: f });
}

const api = sandbox.window.sketcher;
if (!api) {
  console.log('FAIL  sketcher.js did not publish its api');
  process.exit(1);
}

let total = 0, failures = 0;
function check(name, fn) {
  total++;
  try { fn(); console.log('PASS  ' + name); }
  catch (e) { failures++; console.log('FAIL  ' + name + '\n      ' + (e && e.stack || e)); }
}

check('startup created a sketch and rendered without throwing', () => {
  if (api.store.ids().length !== 1) throw new Error('ids ' + JSON.stringify(api.store.ids()));
  if (!api.store.get()) throw new Error('no current sketch');
});

check('startup mirrored the sketchbook into storage', () => {
  if (!backing['sketchbook.index']) throw new Error('no index written');
  const ids = JSON.parse(backing['sketchbook.index']).order;
  if (!backing['sketch:' + ids[0]]) throw new Error('no sketch written');
});

check('the palette rendered one button per catalogue part', () => {
  const pal = doc.getElementById('palette');
  const n = sandbox.PCBGEN_CATALOGUE.hardware.length;
  if (pal.children.length !== n) throw new Error('palette has ' + pal.children.length + ' of ' + n);
});

check('the canvas drew the panel', () => {
  const c = doc.getElementById('canvas');
  if (!c.getAttribute('viewBox')) throw new Error('no viewBox');
  if (c.children.length === 0) throw new Error('nothing drawn');
});

check('arming a palette part and clicking a cell places a control', () => {
  doc.getElementById('palette').children[0].dispatch('click');
  const root = doc.getElementById('canvas').children[0];
  const cell = root.children.find(x => x.className && x.className.includes('cell'));
  if (!cell) throw new Error('no cell drawn to click');
  cell.dispatch('pointerdown', { stopPropagation() {}, preventDefault() {} });
  if (api.store.get().controls.length !== 1) throw new Error('controls ' + api.store.get().controls.length);
});

check('the findings list rendered for the placed control', () => {
  if (doc.getElementById('findings').children.length === 0) throw new Error('no findings rendered');
  if (!doc.getElementById('findings-summary').textContent.includes('conflicts')) throw new Error('no summary');
});

check('changing the width keeps the control and is undoable', () => {
  const sel = doc.getElementById('sketch-hp');
  sel.value = '4';
  sel.dispatch('change');
  if (api.store.get().hp !== 4) throw new Error('hp ' + api.store.get().hp);
  if (api.store.get().controls.length !== 1) throw new Error('control lost');
  doc.getElementById('undo').dispatch('click');
  if (api.store.get().hp === 4) throw new Error('undo did nothing');
});

check('new module adds a second sketch and selects it', () => {
  doc.getElementById('new-sketch').dispatch('click');
  if (api.store.ids().length !== 2) throw new Error('ids ' + JSON.stringify(api.store.ids()));
});

check('pasting a malformed sketch reports and changes nothing', () => {
  const before = JSON.stringify(api.store.get());
  doc.getElementById('paste-json').value = '{"format": "pcbgen-sketch", "version": 9}';
  doc.getElementById('import-replace').dispatch('click');
  if (JSON.stringify(api.store.get()) !== before) throw new Error('sketch changed');
  if (!doc.getElementById('import-result').textContent.startsWith('Not imported')) {
    throw new Error('no refusal message: ' + doc.getElementById('import-result').textContent);
  }
});

check('pasting a good sketch replaces the current module', () => {
  doc.getElementById('paste-json').value = api.core.stringify(api.core.newSketch('Pasted', 6, 'candidate-15'));
  doc.getElementById('import-replace').dispatch('click');
  if (api.store.get().name !== 'Pasted') throw new Error('name ' + api.store.get().name);
});

check('the rear view redraws mirrored', () => {
  const v = doc.getElementById('view-rear');
  v.checked = true;
  v.dispatch('change');
  const root = doc.getElementById('canvas').children[0];
  if (!/scale\(-1,1\)/.test(root.getAttribute('transform') || '')) throw new Error('not mirrored');
});

console.log('');
console.log((total - failures) + '/' + total + ' smoke checks passed');
process.exit(failures ? 1 : 0);
