// preview.js: print a sketch as text. `node sketcher/preview.js <file.json>`
//
// So a sketch can be looked at without opening a browser: useful in a
// terminal, and it is how the agent shows you what it drew before you open
// it. It reads the same format the editor does, through sketch-core.js.
'use strict';
const fs = require('fs');
const path = require('path');

const core = require(path.join(__dirname, 'sketch-core.js'))
  .make(require(path.join(__dirname, 'catalogue.js')));

const file = process.argv[2];
if (!file) {
  console.error('usage: node sketcher/preview.js <file.json>');
  process.exit(2);
}

let text;
try { text = fs.readFileSync(file, 'utf8'); }
catch (e) { console.error(file + ': cannot be read (' + e.message + ')'); process.exit(1); }

const r = core.parse(text);
if (!r.ok) {
  console.error(file + ': not a valid sketch (' + r.errors.length + ' problems)');
  r.errors.forEach(function (e) { console.error('  ' + e); });
  process.exit(1);
}

const s = r.sketch;
const glyph = { knob: '(o)', jack: '(=)', switch: '[/]', button: '[o]', led: ' * ' };
const W = 11;

function pad(t) {
  t = String(t).slice(0, W);
  const left = Math.floor((W - t.length) / 2);
  return ' '.repeat(left) + t + ' '.repeat(W - t.length - left);
}
const rule = '+' + Array.from({ length: s.columns }, () => '-'.repeat(W)).join('+') + '+';

const hp = core.impliedWidth(s);
console.log(s.name || '(untitled)');
console.log(s.columns + ' x ' + s.rows + ' grid, ' + s.cells.length + ' component'
  + (s.cells.length === 1 ? '' : 's') + (hp ? ', needs at least ' + hp + ' HP' : ''));
console.log('');
console.log(rule);
for (let row = 0; row < s.rows; row++) {
  let top = '|', bottom = '|';
  for (let col = 0; col < s.columns; col++) {
    const c = core.at(s, col, row);
    top += pad(c ? (glyph[c.kind] || '?') : '') + '|';
    bottom += pad(c ? (c.label || '') : '') + '|';
  }
  console.log(top);
  console.log(bottom);
  console.log(rule);
}
console.log('');
console.log('(o) knob   (=) jack   [/] switch   [o] button    *  led');
