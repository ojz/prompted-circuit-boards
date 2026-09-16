// sketch-core.js: the sketch format in the browser, matching
// toolkit/src/Sketch/{Json,Model}.hs and held to it by vectors.js.
// No DOM here: the same file runs under node for the tests and in the page.
//
// A sketch is a grid and the components in its cells. There are no
// millimetres in it.
(function (root, factory) {
  if (typeof module !== 'undefined' && module.exports) { module.exports = factory(); }
  else { root.SketchCore = factory(); }
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  var FORMAT = 'module-sketch';
  var VERSION = 2;

  // Strict JSON. JSON.parse takes duplicate keys silently and turns 1e999
  // into Infinity; a sketch file must fail on both.
  function parseStrict(text) {
    var i = 0, n = text.length;
    function err(msg) { throw new Error('JSON error at offset ' + i + ': ' + msg); }
    function ws() { while (i < n && ' \t\r\n'.indexOf(text[i]) >= 0) i++; }
    function value() {
      ws();
      if (i >= n) err('unexpected end of text');
      var c = text[i];
      if (c === '{') return object();
      if (c === '[') return array();
      if (c === '"') return string();
      if (c === 't') return literal('true', true);
      if (c === 'f') return literal('false', false);
      if (c === 'n') return literal('null', null);
      if (c === '-' || (c >= '0' && c <= '9')) return number();
      err('unexpected character ' + JSON.stringify(c));
    }
    function literal(word, v) {
      if (text.substr(i, word.length) !== word) err('expected ' + word);
      i += word.length; return v;
    }
    function object() {
      i++; ws();
      var out = Object.create(null), seen = Object.create(null), count = 0;
      if (text[i] === '}') { i++; return out; }
      for (;;) {
        ws();
        if (text[i] !== '"') err(count ? 'expected a string key after \',\'' : 'expected a string key');
        var k = string();
        if (seen[k]) err('duplicate key ' + JSON.stringify(k));
        seen[k] = true;
        ws();
        if (text[i] !== ':') err('expected \':\' after object key');
        i++;
        out[k] = value();
        count++;
        ws();
        if (text[i] === ',') { i++; ws(); if (text[i] === '}') err('trailing comma in object'); continue; }
        if (text[i] === '}') { i++; return out; }
        if (i >= n) err('unterminated object');
        err('expected \',\' or \'}\' in object');
      }
    }
    function array() {
      i++; ws();
      var out = [];
      if (text[i] === ']') { i++; return out; }
      for (;;) {
        out.push(value());
        ws();
        if (text[i] === ',') { i++; ws(); if (text[i] === ']') err('trailing comma in array'); continue; }
        if (text[i] === ']') { i++; return out; }
        if (i >= n) err('unterminated array');
        err('expected \',\' or \']\' in array');
      }
    }
    function string() {
      i++;
      var out = '';
      for (;;) {
        if (i >= n) err('unterminated string');
        var c = text[i];
        if (c === '"') { i++; return out; }
        if (c === '\\') {
          i++;
          var e = text[i];
          if (e === '"' || e === '\\' || e === '/') { out += e; i++; }
          else if (e === 'b') { out += '\b'; i++; }
          else if (e === 'f') { out += '\f'; i++; }
          else if (e === 'n') { out += '\n'; i++; }
          else if (e === 'r') { out += '\r'; i++; }
          else if (e === 't') { out += '\t'; i++; }
          else if (e === 'u') {
            var hi = hex4(i + 1); i += 5;
            if (hi >= 0xD800 && hi <= 0xDBFF) {
              if (text[i] !== '\\' || text[i + 1] !== 'u') err('unpaired high surrogate');
              var lo = hex4(i + 2);
              if (lo < 0xDC00 || lo > 0xDFFF) err('invalid low surrogate');
              i += 6;
              out += String.fromCharCode(hi, lo);
            } else if (hi >= 0xDC00 && hi <= 0xDFFF) { err('unpaired low surrogate'); }
            else { out += String.fromCharCode(hi); }
          }
          else err('invalid escape \\' + e);
        } else if (c.charCodeAt(0) < 0x20) { err('control character in string'); }
        else { out += c; i++; }
      }
    }
    function hex4(at) {
      var h = text.substr(at, 4);
      if (!/^[0-9a-fA-F]{4}$/.test(h)) { i = at; err('invalid \\u escape'); }
      return parseInt(h, 16);
    }
    function number() {
      var start = i;
      if (text[i] === '-') i++;
      if (text[i] === '0') { i++; }
      else if (text[i] >= '1' && text[i] <= '9') { while (text[i] >= '0' && text[i] <= '9') i++; }
      else err('expected a digit');
      if (text[i] === '.') {
        i++;
        if (!(text[i] >= '0' && text[i] <= '9')) err('expected a digit after \'.\'');
        while (text[i] >= '0' && text[i] <= '9') i++;
      }
      if (text[i] === 'e' || text[i] === 'E') {
        i++;
        if (text[i] === '+' || text[i] === '-') i++;
        if (!(text[i] >= '0' && text[i] <= '9')) err('expected a digit in exponent');
        while (text[i] >= '0' && text[i] <= '9') i++;
      }
      var v = Number(text.slice(start, i));
      if (!isFinite(v)) { i = start; err('number is not a finite double'); }
      return v;
    }
    var v = value();
    ws();
    if (i < n) err('unexpected text after the JSON value');
    return v;
  }

  function isObj(v) { return v !== null && typeof v === 'object' && !Array.isArray(v); }
  function isWhole(v) { return typeof v === 'number' && isFinite(v) && v === Math.round(v); }

  function make(catalogue) {
    var kindById = Object.create(null);
    catalogue.kinds.forEach(function (k) { kindById[k.id] = k; });
    var hpFor = Object.create(null);
    catalogue.widthForColumns.forEach(function (w) { hpFor[w.columns] = w.hp; });

    function kind(id) { return kindById[id] || null; }
    function impliedWidth(s) { return hpFor[s.columns] != null ? hpFor[s.columns] : null; }

    // Returns {ok: true, sketch} or {ok: false, errors}; every problem at once.
    function validate(v) {
      var errors = [];
      if (!isObj(v)) return { ok: false, errors: ['the sketch must be a JSON object'] };
      var known = ['format', 'version', 'name', 'columns', 'rows', 'cells'];
      Object.keys(v).forEach(function (k) { if (known.indexOf(k) < 0) errors.push('unknown field ' + k); });
      if (!('format' in v)) errors.push('missing field format');
      else if (typeof v.format !== 'string') errors.push('format: expected a string');
      else if (v.format !== FORMAT) errors.push('format: expected ' + JSON.stringify(FORMAT) + ', got ' + JSON.stringify(v.format));
      if (!('version' in v)) errors.push('missing field version');
      else if (typeof v.version !== 'number') errors.push('version: expected a number');
      else if (v.version !== VERSION) errors.push('version: only version ' + VERSION + ' is understood, got ' + v.version);
      if (errors.length) return { ok: false, errors: errors };

      var name = '';
      if ('name' in v) { if (typeof v.name === 'string') name = v.name; else errors.push('name: expected a string'); }
      var cols = dimension('columns', v, catalogue.maxColumns, errors);
      var rows = dimension('rows', v, catalogue.maxRows, errors);

      var raw = null;
      if (!('cells' in v)) errors.push('missing field cells');
      else if (!Array.isArray(v.cells)) errors.push('cells: expected an array');
      else raw = v.cells;
      if (errors.length) return { ok: false, errors: errors };

      var cells = [];
      raw.forEach(function (c, i) {
        var r = validateCell(c, 'cells[' + i + ']', cols, rows, errors);
        if (r) cells.push(r);
      });
      if (errors.length) return { ok: false, errors: errors };

      var seen = Object.create(null);
      cells.forEach(function (c) {
        var key = c.col + ',' + c.row;
        if (seen[key]) errors.push('cells: ' + key + ' holds more than one component');
        seen[key] = true;
      });
      if (errors.length) return { ok: false, errors: errors };

      return { ok: true, sketch: canonical({ name: name, columns: cols, rows: rows, cells: cells }) };
    }

    function dimension(field, v, limit, errors) {
      if (!(field in v)) { errors.push('missing field ' + field); return null; }
      var x = v[field];
      if (typeof x !== 'number' || !isFinite(x)) { errors.push(field + ': expected a number'); return null; }
      if (!isWhole(x)) { errors.push(field + ': expected a whole number, got ' + x); return null; }
      if (x < 1) { errors.push(field + ': must be at least 1'); return null; }
      if (x > limit) { errors.push(field + ': at most ' + limit + ' fit a Eurorack module, asked for ' + x); return null; }
      return x;
    }

    function validateCell(c, path, cols, rows, errors) {
      if (!isObj(c)) { errors.push(path + ': expected an object'); return null; }
      var unknown = Object.keys(c).filter(function (k) { return ['col', 'row', 'kind', 'label'].indexOf(k) < 0; });
      if (unknown.length) { errors.push(path + ': unknown field ' + unknown[0]); return null; }
      var col = coord(c, 'col', path + '.col', cols, errors);
      var row = coord(c, 'row', path + '.row', rows, errors);
      if (col === null || row === null) return null;
      if (!('kind' in c)) { errors.push(path + ': missing field kind'); return null; }
      if (typeof c.kind !== 'string') { errors.push(path + '.kind: expected a string'); return null; }
      if (!kind(c.kind)) {
        errors.push(path + '.kind: unknown kind ' + JSON.stringify(c.kind) + '; expected one of '
          + catalogue.kinds.map(function (k) { return k.id; }).join(', '));
        return null;
      }
      var label = '';
      if ('label' in c) {
        if (typeof c.label !== 'string') { errors.push(path + '.label: expected a string'); return null; }
        if (c.label.length > 24) { errors.push(path + '.label: at most 24 characters'); return null; }
        label = c.label;
      }
      return { col: col, row: row, kind: c.kind, label: label };
    }

    function coord(c, field, path, limit, errors) {
      if (!(field in c)) { errors.push(path + ': missing'); return null; }
      var x = c[field];
      if (typeof x !== 'number' || !isFinite(x)) { errors.push(path + ': expected a number'); return null; }
      if (!isWhole(x)) { errors.push(path + ': expected a whole number, got ' + x); return null; }
      if (x < 0 || x >= limit) { errors.push(path + ': ' + x + ' is off a grid of ' + limit); return null; }
      return x;
    }

    // Key order and cell order of Sketch.Model.encodeSketch, so
    // stringify produces the generator's bytes.
    function canonical(s) {
      var cells = (s.cells || []).slice().sort(function (a, b) {
        return (a.row - b.row) || (a.col - b.col);
      }).map(function (c) {
        var o = { col: c.col, row: c.row, kind: c.kind };
        if (c.label) o.label = c.label;
        return o;
      });
      return { format: FORMAT, version: VERSION, name: s.name || '', columns: s.columns, rows: s.rows, cells: cells };
    }
    function stringify(s) { return JSON.stringify(canonical(s), null, 2) + '\n'; }
    function parse(text) {
      var v;
      try { v = parseStrict(text); } catch (e) { return { ok: false, errors: [e.message] }; }
      return validate(v);
    }

    function at(s, col, row) {
      for (var i = 0; i < s.cells.length; i++) {
        if (s.cells[i].col === col && s.cells[i].row === row) return s.cells[i];
      }
      return null;
    }
    function emptySketch(name, columns, rows) {
      return canonical({ name: name || '', columns: columns, rows: rows, cells: [] });
    }

    return {
      FORMAT: FORMAT, VERSION: VERSION, catalogue: catalogue,
      kinds: catalogue.kinds, kind: kind,
      maxColumns: catalogue.maxColumns, maxRows: catalogue.maxRows,
      impliedWidth: impliedWidth, why: catalogue.why,
      parseStrict: parseStrict, parse: parse, validate: validate,
      canonical: canonical, stringify: stringify,
      at: at, emptySketch: emptySketch
    };
  }

  return { make: make, parseStrict: parseStrict, FORMAT: FORMAT, VERSION: VERSION };
});
