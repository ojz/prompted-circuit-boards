// smoke.js: run the page itself against a minimal DOM stub, so the code in
// sketcher.js executes outside a browser. `node sketcher/smoke.js`
//
// tests.js covers the format and the sketchbook, neither of which touches the
// DOM. This covers the rest: that the page's ids and the script agree, that
// it renders, and that the first things a user does do not throw. It is not a
// rendering test and says nothing about how the page looks.
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
    this.draggable = false;
    this.style = {};
    this.dataset = {};
    this.listeners = {};
    this.className = '';
    this.files = null;
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
  // `onclick = fn` is how sketcher.js wires most buttons; dispatch honours both.
  dispatch(t, ev) {
    const inline = this['on' + t];
    if (typeof inline === 'function') inline.call(this, ev || {});
    (this.listeners[t] || []).forEach(f => f.call(this, ev || {}));
  }
  focus() { doc.activeElement = this; }
  blur() { doc.activeElement = null; }
  select() { /* a real input selects its text; nothing to do here */ }
  setSelectionRange() {}
  querySelector(sel) {
    const m = /^\[data-col="(\d+)"\]\[data-row="(\d+)"\]$/.exec(sel);
    const walk = (n) => {
      for (const c of n.children) {
        if (m && c.attrs['data-col'] === m[1] && c.attrs['data-row'] === m[2]) return c;
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
function cellNode(col, row) {
  return doc.getElementById('grid').querySelector('[data-col="' + col + '"][data-row="' + row + '"]');
}

check('startup made an empty sketch and drew the grid', () => {
  if (api.store.ids().length !== 1) throw new Error('ids ' + JSON.stringify(api.store.ids()));
  const s = api.store.get();
  if (s.cells.length !== 0) throw new Error('not empty');
  const cells = s.columns * s.rows;
  if (doc.getElementById('grid').children.length !== cells) {
    throw new Error('drew ' + doc.getElementById('grid').children.length + ' of ' + cells + ' cells');
  }
});

check('startup mirrored the sketchbook into storage', () => {
  if (!backing['sketchbook.index']) throw new Error('no index written');
  const ids = JSON.parse(backing['sketchbook.index']).order;
  if (!backing['sketch:' + ids[0]]) throw new Error('no sketch written');
});

check('the palette has one button per kind', () => {
  const n = sandbox.SKETCH_CATALOGUE.kinds.length;
  const got = doc.getElementById('palette').children.length;
  if (got !== n) throw new Error('palette has ' + got + ' of ' + n);
});

check('clicking a cell places the armed kind', () => {
  cellNode(0, 0).dispatch('click');
  const s = api.store.get();
  if (s.cells.length !== 1) throw new Error('cells ' + s.cells.length);
  if (api.core.at(s, 0, 0).kind !== sandbox.SKETCH_CATALOGUE.kinds[0].id) throw new Error('wrong kind');
});

check('choosing another part in the palette changes what gets placed', () => {
  const jack = sandbox.SKETCH_CATALOGUE.kinds.findIndex(k => k.id === 'jack');
  doc.getElementById('palette').children[jack].dispatch('click');
  cellNode(1, 0).dispatch('click');
  if (api.core.at(api.store.get(), 1, 0).kind !== 'jack') throw new Error('kind not switched');
});

check('a second click on a filled cell opens its label field', () => {
  cellNode(1, 0).dispatch('click');   // selects
  cellNode(1, 0).dispatch('click');   // opens the label
  if (!api.ui.editingLabel) throw new Error('label editing did not open');
  const input = cellNode(1, 0).children.find(c => c.tagName === 'INPUT');
  if (!input) throw new Error('no input rendered');
  input.value = 'IN 1';
  input.dispatch('keydown', { key: 'Enter', preventDefault() {} });
  if (api.core.at(api.store.get(), 1, 0).label !== 'IN 1') throw new Error('label not saved');
});

check('a component with no label renders blank, never the word undefined', () => {
  // The JSON leaves an empty label out, so anything that reads a cell and
  // prints it has to cope. This checks the two places a person would see it:
  // the caption under the icon, and the label field when it is open.
  const led = sandbox.SKETCH_CATALOGUE.kinds.findIndex(k => k.id === 'led');
  doc.getElementById('palette').children[led].dispatch('click');
  cellNode(0, 1).dispatch('click');              // places it, opens the label
  const open = cellNode(0, 1);
  const input = open.children.find(c => c.tagName === 'INPUT');
  if (!input) throw new Error('no label field opened');
  const shown = input.getAttribute('value');
  if (shown !== '' && shown !== null) throw new Error('the label field shows ' + JSON.stringify(shown));
  input.dispatch('keydown', { key: 'Escape', preventDefault() {} });   // leave it blank
  const texts = [];
  (function walk(n) { if (n._text) texts.push(n._text); n.children.forEach(walk); })(cellNode(0, 1));
  const bad = texts.filter(t => /undefined/.test(t));
  if (bad.length) throw new Error('the cell renders ' + JSON.stringify(bad));
  const caption = cellNode(0, 1).children.filter(c => c.className === 'tag');
  if (caption.length && caption[0].textContent !== '') {
    throw new Error('the caption is ' + JSON.stringify(caption[0].textContent));
  }
});

check('nothing anywhere on the page renders the word undefined', () => {
  const found = [];
  (function walk(n, where) {
    if (n._text && /undefined/.test(n._text)) found.push(where + ': ' + n._text);
    Object.keys(n.attrs || {}).forEach(k => {
      if (/undefined/.test(String(n.attrs[k]))) found.push(where + ' @' + k + ': ' + n.attrs[k]);
    });
    n.children.forEach((c, i) => walk(c, where + '>' + (c.tagName || '?').toLowerCase() + i));
  })(doc.getElementById('grid'), 'grid');
  ['note', 'status', 'limits', 'list', 'palette'].forEach(id => {
    (function walk(n, where) {
      if (n._text && /undefined/.test(n._text)) found.push(where + ': ' + n._text);
      n.children.forEach((c, i) => walk(c, where + '>' + i));
    })(doc.getElementById(id), id);
  });
  if (found.length) throw new Error(found.join('; '));
});

check('the note reports the grid and the width it implies', () => {
  const t = doc.getElementById('note').textContent;
  if (!/\d+ x \d+ grid/.test(t)) throw new Error('no grid size: ' + t);
  if (!/HP/.test(t)) throw new Error('no implied width: ' + t);
});

check('the steppers grow the grid and stop at the derived maximum', () => {
  const before = api.store.get().columns;
  doc.getElementById('col-more').dispatch('click');
  if (api.store.get().columns !== before + 1) throw new Error('columns did not grow');
  for (let i = 0; i < 10; i++) doc.getElementById('col-more').dispatch('click');
  if (api.store.get().columns !== api.core.maxColumns) throw new Error('columns ' + api.store.get().columns);
  if (!doc.getElementById('col-more').disabled) throw new Error('the + button is still enabled at the maximum');
});

check('shrinking over a component is refused and says which one', () => {
  const s = api.store.get();
  api.store.edit(x => api.edits.put(x, s.columns - 1, 0, 'knob', 'EDGE'));
  api.render();
  const before = JSON.stringify(api.store.get());
  doc.getElementById('col-less').dispatch('click');
  if (JSON.stringify(api.store.get()) !== before) throw new Error('the grid shrank anyway');
  if (!/EDGE/.test(doc.getElementById('status').textContent)) {
    throw new Error('the message does not name it: ' + doc.getElementById('status').textContent);
  }
});

check('backspace on a cell clears it', () => {
  cellNode(0, 0).dispatch('keydown', { key: 'Backspace', preventDefault() {} });
  if (api.core.at(api.store.get(), 0, 0)) throw new Error('still there');
});

check('undo restores it', () => {
  doc.getElementById('undo').dispatch('click');
  if (!api.core.at(api.store.get(), 0, 0)) throw new Error('undo did nothing');
});

check('New adds a second module and Copy a third', () => {
  doc.getElementById('new').dispatch('click');
  if (api.store.ids().length !== 2) throw new Error('ids ' + JSON.stringify(api.store.ids()));
  doc.getElementById('dup').dispatch('click');
  if (api.store.ids().length !== 3) throw new Error('copy did not add one');
});

check('pasting a malformed sketch reports and changes nothing', () => {
  const before = JSON.stringify(api.store.get());
  doc.getElementById('paste').value = '{"format": "module-sketch", "version": 9}';
  doc.getElementById('import-replace').dispatch('click');
  if (JSON.stringify(api.store.get()) !== before) throw new Error('sketch changed');
  if (!/Not imported/.test(doc.getElementById('status').textContent)) {
    throw new Error('no refusal message: ' + doc.getElementById('status').textContent);
  }
});

check('pasting a good sketch replaces the current module', () => {
  doc.getElementById('paste').value = api.core.stringify(api.core.emptySketch('Pasted', 2, 2));
  doc.getElementById('import-replace').dispatch('click');
  if (api.store.get().name !== 'Pasted') throw new Error('name ' + api.store.get().name);
});

console.log('');
console.log((total - failures) + '/' + total + ' smoke checks passed');
process.exit(failures ? 1 : 0);
