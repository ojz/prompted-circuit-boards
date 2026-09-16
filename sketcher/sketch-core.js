// sketch-core.js: the sketch format, its geometry and its checks, in the
// browser. A re-implementation of toolkit/src/Sketch/{Json,Model,Check}.hs
// held to the Haskell results by vectors.js (run tests.js). No DOM in here:
// the same file runs under node for the tests and in the page for the editor.
//
// Coordinates are panel millimetres from the top-left corner viewed from the
// front, y downward (docs/MECHANICAL.md). Rotation is counter-clockwise on
// screen with y down, as KiCad displays it: rotatePt(90, [x, y]) = [y, -x].
(function (root, factory) {
  if (typeof module !== 'undefined' && module.exports) { module.exports = factory(); }
  else { root.SketchCore = factory(); }
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  var FORMAT = 'pcbgen-sketch';
  var VERSION = 1;
  var EPS = 1e-6;

  // Strict JSON --------------------------------------------------------------
  // JSON.parse accepts duplicate keys silently and turns 1e999 into Infinity;
  // a sketch file must fail on both, so the reader is our own.
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

  // Format -------------------------------------------------------------------

  var ID_RE = /^[A-Za-z0-9_-]{1,40}$/;
  function validIdentifier(s) { return typeof s === 'string' && ID_RE.test(s); }

  function isObj(v) { return v !== null && typeof v === 'object' && !Array.isArray(v); }
  function isInt(v) { return typeof v === 'number' && isFinite(v) && v === Math.round(v) && Math.abs(v) < 1e9; }

  function make(catalogue) {
    // Null prototypes throughout: these are keyed by text out of a sketch
    // file, and "constructor" or "toString" are legal identifiers that a
    // plain object would resolve to an inherited function.
    var hardwareById = Object.create(null);
    catalogue.hardware.forEach(function (h) { hardwareById[h.id] = h; });
    var profileById = Object.create(null);
    catalogue.profiles.forEach(function (p) { profileById[p.id] = p; });
    var skeletonByHp = Object.create(null);
    catalogue.skeletons.forEach(function (s) { skeletonByHp[s.hp] = s; });
    var form = catalogue.form;

    function hardware(id) { return hardwareById[id] || null; }
    function profile(id) { return profileById[id] || null; }
    function skeleton(hp) { return skeletonByHp[hp] || null; }

    // Decoding: every problem, each naming its path. Returns {ok, sketch} or
    // {ok, errors}. The result is a fresh, canonical object.
    function validate(v) {
      var errors = [];
      if (!isObj(v)) return { ok: false, errors: ['the sketch must be a JSON object'] };
      var known = ['format', 'version', 'name', 'status', 'hp', 'grid', 'controls', 'groups', 'notes'];
      Object.keys(v).forEach(function (k) { if (known.indexOf(k) < 0) errors.push('unknown field ' + k); });
      if (!('format' in v)) errors.push('missing field format');
      else if (typeof v.format !== 'string') errors.push('format: expected a string');
      else if (v.format !== FORMAT) errors.push('format: expected ' + JSON.stringify(FORMAT) + ', got ' + JSON.stringify(v.format));
      if (!('version' in v)) errors.push('missing field version');
      else if (typeof v.version !== 'number') errors.push('version: expected a number');
      else if (v.version !== VERSION) errors.push('version: only version ' + VERSION + ' is understood, got ' + v.version);
      if (errors.length) return { ok: false, errors: errors };

      var out = { format: FORMAT, version: VERSION, name: '', status: 'provisional', hp: 0, grid: null, controls: [] };
      if ('name' in v) { if (typeof v.name === 'string') out.name = v.name; else errors.push('name: expected a string'); }
      if ('status' in v) {
        if (typeof v.status !== 'string') errors.push('status: expected a string');
        else if (v.status !== 'provisional' && v.status !== 'reviewed') errors.push('status: expected provisional or reviewed, got ' + JSON.stringify(v.status));
        else out.status = v.status;
      }
      if (!('hp' in v)) errors.push('missing field hp');
      else if (!isInt(v.hp)) errors.push('hp: expected an integer');
      else if (v.hp < 1 || v.hp > 84) errors.push('hp: ' + v.hp + ' is not a panel width (1 to 84)');
      else out.hp = v.hp;
      if (!('grid' in v)) errors.push('missing field grid');
      else {
        var g = validateGrid(v.grid, errors);
        if (g) out.grid = g;
      }
      var controlsV = null;
      if (!('controls' in v)) errors.push('missing field controls');
      else if (!Array.isArray(v.controls)) errors.push('controls: expected an array');
      else controlsV = v.controls;
      var groupsV = [];
      if ('groups' in v) { if (Array.isArray(v.groups)) groupsV = v.groups; else errors.push('groups: expected an array'); }
      if ('notes' in v) {
        if (!Array.isArray(v.notes) || !v.notes.every(function (x) { return typeof x === 'string'; })) errors.push('notes: expected an array of strings');
        else if (v.notes.length) out.notes = v.notes.slice();
      }
      var controls = [];
      if (controlsV) controlsV.forEach(function (c, i) { var r = validateControl(c, 'controls[' + i + ']', errors); if (r) controls.push(r); });
      var groups = [];
      groupsV.forEach(function (gr, i) { var r = validateGroup(gr, 'groups[' + i + ']', errors); if (r) groups.push(r); });
      if (errors.length) return { ok: false, errors: errors };

      var seen = Object.create(null);
      controls.forEach(function (c) { if (seen[c.id]) { if (seen[c.id] === 1) errors.push('controls: duplicate id ' + JSON.stringify(c.id)); seen[c.id]++; } else seen[c.id] = 1; });
      var gseen = Object.create(null);
      groups.forEach(function (g) { if (gseen[g.id]) { if (gseen[g.id] === 1) errors.push('groups: duplicate id ' + JSON.stringify(g.id)); gseen[g.id]++; } else gseen[g.id] = 1; });
      var dangling = Object.create(null);
      controls.forEach(function (c) { if (c.group && !gseen[c.group] && !dangling[c.group]) { dangling[c.group] = true; errors.push('controls: group ' + JSON.stringify(c.group) + ' is not declared in groups'); } });
      if (errors.length) return { ok: false, errors: errors };
      out.controls = controls;
      if (groups.length) out.groups = groups;
      return { ok: true, sketch: canonical(out) };
    }

    function validatePoint(p, path, errors) {
      if (!isObj(p)) { errors.push(path + ': expected an object with x and y'); return null; }
      var ks = Object.keys(p).sort();
      if (ks.join(',') !== 'x,y') { errors.push(path + ': expected exactly the fields x and y'); return null; }
      if (typeof p.x !== 'number' || !isFinite(p.x)) { errors.push(path + '.x: expected a number'); return null; }
      if (typeof p.y !== 'number' || !isFinite(p.y)) { errors.push(path + '.y: expected a number'); return null; }
      return { x: p.x, y: p.y };
    }
    function validatePair(p, path, a, b, errors) {
      if (!isObj(p)) { errors.push(path + ': expected an object with ' + a + ' and ' + b); return null; }
      var ks = Object.keys(p).sort();
      if (ks.join(',') !== [a, b].sort().join(',')) { errors.push(path + ': expected exactly the fields ' + a + ' and ' + b); return null; }
      if (!isInt(p[a])) { errors.push(path + '.' + a + ': expected an integer'); return null; }
      if (!isInt(p[b])) { errors.push(path + '.' + b + ': expected an integer'); return null; }
      var r = {}; r[a] = p[a]; r[b] = p[b]; return r;
    }
    function validateGrid(g, errors) {
      if (!isObj(g)) { errors.push('grid: expected an object'); return null; }
      var bad = false;
      Object.keys(g).forEach(function (k) { if (['origin', 'pitch', 'profile'].indexOf(k) < 0) { errors.push('grid: unknown field ' + k); bad = true; } });
      if (bad) return null;
      var origin = ('origin' in g) ? validatePoint(g.origin, 'grid.origin', errors) : (errors.push('missing field origin'), null);
      var pitch = ('pitch' in g) ? validatePoint(g.pitch, 'grid.pitch', errors) : (errors.push('missing field pitch'), null);
      if (pitch && (pitch.x <= 0 || pitch.y <= 0)) { errors.push('grid.pitch: both pitches must be positive'); pitch = null; }
      var prof = '';
      if ('profile' in g) {
        if (typeof g.profile !== 'string') { errors.push('profile: expected a string'); return null; }
        if (g.profile !== '' && !profile(g.profile)) { errors.push('grid.profile: unknown profile ' + JSON.stringify(g.profile)); return null; }
        prof = g.profile;
      }
      if (!origin || !pitch) return null;
      var out = { origin: origin, pitch: pitch };
      if (prof) out.profile = prof;
      return out;
    }
    function validateControl(c, path, errors) {
      if (!isObj(c)) { errors.push(path + ': expected an object'); return null; }
      var known = ['id', 'hardware', 'cell', 'span', 'offset', 'rotation', 'label', 'group'];
      var unknown = Object.keys(c).filter(function (k) { return known.indexOf(k) < 0; });
      if (unknown.length) { errors.push(path + ': unknown field ' + unknown[0]); return null; }
      if (!('id' in c)) { errors.push(path + ': missing field id'); return null; }
      if (typeof c.id !== 'string') { errors.push(path + '.id: expected a string'); return null; }
      if (!validIdentifier(c.id)) { errors.push(path + '.id: ' + JSON.stringify(c.id) + ' is not an identifier (letters, digits, - and _; at most 40)'); return null; }
      if (!('hardware' in c)) { errors.push(path + ': missing field hardware'); return null; }
      if (typeof c.hardware !== 'string') { errors.push(path + '.hardware: expected a string'); return null; }
      var hw = hardware(c.hardware);
      if (!hw) { errors.push(path + '.hardware: unknown hardware ' + JSON.stringify(c.hardware)); return null; }
      if (!('cell' in c)) { errors.push(path + ': missing field cell'); return null; }
      var cell = validatePair(c.cell, path + '.cell', 'col', 'row', errors);
      if (!cell) return null;
      var span = { cols: 1, rows: 1 };
      if ('span' in c) {
        span = validatePair(c.span, path + '.span', 'cols', 'rows', errors);
        if (!span) return null;
        if (span.cols < 1 || span.rows < 1) { errors.push(path + '.span: cols and rows must be at least 1'); return null; }
      }
      var offset = { x: 0, y: 0 };
      if ('offset' in c) { offset = validatePoint(c.offset, path + '.offset', errors); if (!offset) return null; }
      var rotation = 0;
      if ('rotation' in c) {
        if (!isInt(c.rotation)) { errors.push(path + '.rotation: expected an integer'); return null; }
        if (hw.rotations.indexOf(c.rotation) < 0) { errors.push(path + '.rotation: ' + c.rotation + ' is not one of ' + hw.rotations.join(', ') + ' for ' + hw.id); return null; }
        rotation = c.rotation;
      }
      var label = '';
      if ('label' in c) { if (typeof c.label !== 'string') { errors.push('label: expected a string'); return null; } label = c.label; }
      var group = null;
      if ('group' in c && c.group !== null) {
        if (typeof c.group !== 'string') { errors.push(path + '.group: expected a string'); return null; }
        if (!validIdentifier(c.group)) { errors.push(path + '.group: not an identifier'); return null; }
        group = c.group;
      }
      return { id: c.id, hardware: c.hardware, cell: cell, span: span, offset: offset, rotation: rotation, label: label, group: group };
    }
    function validateGroup(g, path, errors) {
      if (!isObj(g)) { errors.push(path + ': expected an object'); return null; }
      var unknown = Object.keys(g).filter(function (k) { return k !== 'id' && k !== 'label'; });
      if (unknown.length) { errors.push(path + ': unknown field ' + unknown[0]); return null; }
      if (!('id' in g)) { errors.push(path + ': missing field id'); return null; }
      if (typeof g.id !== 'string') { errors.push(path + '.id: expected a string'); return null; }
      if (!validIdentifier(g.id)) { errors.push(path + '.id: not an identifier'); return null; }
      var label = '';
      if ('label' in g) { if (typeof g.label !== 'string') { errors.push('label: expected a string'); return null; } label = g.label; }
      return { id: g.id, label: label };
    }

    // The canonical object: the key order and default omission of
    // Sketch.Model.encodeSketch, so JSON.stringify(canonical, null, 2) is
    // byte for byte what the generator writes.
    function canonical(s) {
      var out = { format: FORMAT, version: VERSION, name: s.name || '', status: s.status || 'provisional', hp: s.hp };
      var g = { origin: { x: s.grid.origin.x, y: s.grid.origin.y }, pitch: { x: s.grid.pitch.x, y: s.grid.pitch.y } };
      if (s.grid.profile) g.profile = s.grid.profile;
      out.grid = g;
      out.controls = (s.controls || []).map(function (c) {
        var o = { id: c.id, hardware: c.hardware, cell: { col: c.cell.col, row: c.cell.row } };
        var span = c.span || { cols: 1, rows: 1 };
        if (span.cols !== 1 || span.rows !== 1) o.span = { cols: span.cols, rows: span.rows };
        var off = c.offset || { x: 0, y: 0 };
        if (off.x !== 0 || off.y !== 0) o.offset = { x: off.x, y: off.y };
        if (c.rotation) o.rotation = c.rotation;
        if (c.label) o.label = c.label;
        if (c.group) o.group = c.group;
        return o;
      });
      if (s.groups && s.groups.length) out.groups = s.groups.map(function (g) { return { id: g.id, label: g.label || '' }; });
      if (s.notes && s.notes.length) out.notes = s.notes.slice();
      return out;
    }
    function stringify(s) { return JSON.stringify(canonical(s), null, 2) + '\n'; }
    function parse(text) {
      var v;
      try { v = parseStrict(text); } catch (e) { return { ok: false, errors: [e.message] }; }
      return validate(v);
    }
    // Every control with its defaults filled in, for editing code.
    function expand(c) {
      return { id: c.id, hardware: c.hardware, cell: { col: c.cell.col, row: c.cell.row },
               span: c.span ? { cols: c.span.cols, rows: c.span.rows } : { cols: 1, rows: 1 },
               offset: c.offset ? { x: c.offset.x, y: c.offset.y } : { x: 0, y: 0 },
               rotation: c.rotation || 0, label: c.label || '', group: c.group || null };
    }

    // Geometry -----------------------------------------------------------------

    function rotatePt(rot, p) {
      var r = ((rot % 360) + 360) % 360;
      if (r === 90) return { x: p.y, y: -p.x };
      if (r === 180) return { x: -p.x, y: -p.y };
      if (r === 270) return { x: -p.y, y: p.x };
      return { x: p.x, y: p.y };
    }
    function boxRotate(rot, b) {
      var r = ((rot % 360) + 360) % 360;
      if (r === 90) return { x1: b.y1, y1: -b.x2, x2: b.y2, y2: -b.x1 };
      if (r === 180) return { x1: -b.x2, y1: -b.y2, x2: -b.x1, y2: -b.y1 };
      if (r === 270) return { x1: -b.y2, y1: b.x1, x2: -b.y1, y2: b.x2 };
      return { x1: b.x1, y1: b.y1, x2: b.x2, y2: b.y2 };
    }
    function boxTranslate(d, b) { return { x1: b.x1 + d.x, y1: b.y1 + d.y, x2: b.x2 + d.x, y2: b.y2 + d.y }; }
    function shapeRotate(rot, s) {
      if (!s || s.shape === 'circle') return s ? { shape: 'circle', d: s.d } : null;
      var odd = (Math.round(rot / 90) % 2) !== 0;
      return odd ? { shape: 'rect', w: s.h, h: s.w } : { shape: 'rect', w: s.w, h: s.h };
    }
    function cells(c) {
      var out = [];
      var span = c.span || { cols: 1, rows: 1 };
      for (var i = 0; i < span.cols; i++) for (var j = 0; j < span.rows; j++) out.push({ col: c.cell.col + i, row: c.cell.row + j });
      return out;
    }
    function controlCentre(grid, c) {
      var span = c.span || { cols: 1, rows: 1 };
      var off = c.offset || { x: 0, y: 0 };
      return { x: grid.origin.x + (c.cell.col + (span.cols - 1) / 2) * grid.pitch.x + off.x,
               y: grid.origin.y + (c.cell.row + (span.rows - 1) / 2) * grid.pitch.y + off.y };
    }
    function toBoard(sk, p) { return { x: p.x - sk.boardOrigin.x, y: p.y - sk.boardOrigin.y }; }
    // Block.Eurorack.originFor for the Front side: rotate the local anchor and
    // subtract it from the wanted board position.
    function originFor(rot, local, board) {
      var d = rotatePt(rot, local);
      return { x: board.x - d.x, y: board.y - d.y };
    }
    function placeControl(sk, grid, c) {
      var hw = hardware(c.hardware);
      var centre = controlCentre(grid, c);
      var bc = toBoard(sk, centre);
      var rot = c.rotation || 0;
      return { id: c.id, control: c, hardware: hw, centre: centre, board: bc,
               footprintOrigin: originFor(rot, hw.anchor, bc), rotation: rot,
               courtyard: boxTranslate(centre, boxRotate(rot, hw.courtyard)),
               frontBody: shapeRotate(rot, hw.frontBody),
               frontAccess: shapeRotate(rot, hw.frontAccess) };
    }
    function place(s) {
      var sk = skeleton(s.hp);
      return s.controls.map(function (c) { return placeControl(sk, s.grid, c); });
    }
    function boardZone(sk) {
      return { x1: sk.boardOrigin.x, y1: sk.boardOrigin.y, x2: sk.boardOrigin.x + sk.boardWidth, y2: sk.boardOrigin.y + sk.boardHeight };
    }
    function railHoles(sk) {
      var out = [];
      sk.railHolesX.forEach(function (x) { sk.railHolesY.forEach(function (y) { out.push({ x: x, y: y }); }); });
      return out;
    }

    function boxesOverlap(a, b) {
      return a.x1 < b.x2 - EPS && b.x1 < a.x2 - EPS && a.y1 < b.y2 - EPS && b.y1 < a.y2 - EPS;
    }
    function circleRect(d, c, r, rc) {
      var nx = Math.max(rc.x - r.w / 2, Math.min(c.x, rc.x + r.w / 2));
      var ny = Math.max(rc.y - r.h / 2, Math.min(c.y, rc.y + r.h / 2));
      return Math.hypot(c.x - nx, c.y - ny) < d / 2 - EPS;
    }
    function shapesOverlap(s1, c1, s2, c2) {
      if (!s1 || !s2) return false;
      if (s1.shape === 'circle' && s2.shape === 'circle') return Math.hypot(c1.x - c2.x, c1.y - c2.y) < (s1.d + s2.d) / 2 - EPS;
      if (s1.shape === 'rect' && s2.shape === 'rect') {
        return boxesOverlap({ x1: c1.x - s1.w / 2, y1: c1.y - s1.h / 2, x2: c1.x + s1.w / 2, y2: c1.y + s1.h / 2 },
                            { x1: c2.x - s2.w / 2, y1: c2.y - s2.h / 2, x2: c2.x + s2.w / 2, y2: c2.y + s2.h / 2 });
      }
      if (s1.shape === 'circle') return circleRect(s1.d, c1, s2, c2);
      return circleRect(s2.d, c2, s1, c1);
    }

    // Checks -------------------------------------------------------------------

    function mm(d) { var r = Math.round(d * 100) / 100; return r + ' mm'; }
    var SEV_ORDER = { conflict: 0, warning: 1, note: 2 };

    function check(s) {
      var sk = skeleton(s.hp);
      var out = [];
      if (!sk) return [{ kind: 'unknown-width', severity: 'conflict', controls: [], message: 'no skeleton for ' + s.hp + ' HP' }];
      var ps = place(s);
      var w = sk.panelWidth, h = form.panelHeight;
      var zone = boardZone(sk);
      var rails = railHoles(sk);
      var f = function (kind, severity, controls, message) { out.push({ kind: kind, severity: severity, controls: controls, message: message }); };

      ps.forEach(function (p) {
        var cid = p.id, cx = p.centre.x, cy = p.centre.y, r = p.hardware.hole / 2, b = p.courtyard;
        var off = p.control.offset || { x: 0, y: 0 };
        if (cx - r < 0 || cx + r > w || cy - r < 0 || cy + r > h)
          f('outside-panel', 'conflict', [cid], cid + ': its ' + mm(2 * r) + ' hole leaves the ' + mm(w) + ' x ' + mm(h) + ' panel');
        if (b.x1 < zone.x1 - EPS || b.x2 > zone.x2 + EPS || b.y1 < zone.y1 - EPS || b.y2 > zone.y2 + EPS)
          f('outside-board-zone', 'conflict', [cid], cid + ': its body behind the panel leaves the PCB zone (panel x ' + mm(zone.x1) + ' to ' + mm(zone.x2) + ', y ' + mm(zone.y1) + ' to ' + mm(zone.y2) + ')');
        rails.forEach(function (rh) {
          if (shapesOverlap(p.frontBody, p.centre, { shape: 'circle', d: 2 * form.railKeepoutRadius }, rh))
            f('rail-keepout', 'conflict', [cid], cid + ': stands within ' + mm(form.railKeepoutRadius) + ' of the rail screw at (' + mm(rh.x) + ', ' + mm(rh.y) + ')');
        });
        if (Math.abs(off.x) > s.grid.pitch.x / 2 + EPS || Math.abs(off.y) > s.grid.pitch.y / 2 + EPS)
          f('offset-too-large', 'conflict', [cid], cid + ': offset (' + mm(off.x) + ', ' + mm(off.y) + ') leaves its cell; keep it within half a pitch');
      });

      for (var i = 0; i < ps.length; i++) for (var j = i + 1; j < ps.length; j++) {
        var p = ps[i], q = ps[j], a = p.id, bId = q.id;
        if (p.hardware.reservesCell && q.hardware.reservesCell) {
          var cp = cells(p.control), cq = cells(q.control), shared = null;
          cp.forEach(function (c1) { if (!shared) cq.forEach(function (c2) { if (!shared && c1.col === c2.col && c1.row === c2.row) shared = c1; }); });
          if (shared) f('cell-overlap', 'conflict', [a, bId], a + ' and ' + bId + ' reserve the same cell (' + shared.col + ', ' + shared.row + ')');
        }
        var front = shapesOverlap(p.frontBody, p.centre, q.frontBody, q.centre);
        if (front) f('front-overlap', 'conflict', [a, bId], a + ' and ' + bId + ' collide in front of the panel (nut, knob or bushing)');
        if (boxesOverlap(p.courtyard, q.courtyard)) f('back-overlap', 'conflict', [a, bId], a + ' and ' + bId + ' have overlapping footprint courtyards behind the panel');
        if (!front) {
          var access = shapesOverlap(p.frontAccess, p.centre, q.frontBody, q.centre)
                    || shapesOverlap(q.frontAccess, q.centre, p.frontBody, p.centre)
                    || shapesOverlap(p.frontAccess, p.centre, q.frontAccess, q.centre);
          if (access) f('access-overlap', 'warning', [a, bId], a + ' and ' + bId + ': finger, cable or bat room overlaps; check on the mockup');
        }
      }

      if (s.hp < form.policyHP.min || s.hp > form.policyHP.max)
        f('hp-policy', 'warning', [], 'width ' + s.hp + ' HP is outside the ' + form.policyHP.min + ' to ' + form.policyHP.max + ' HP module policy');
      if (form.doepferTable.indexOf(s.hp) < 0)
        f('hp-formula', 'warning', [], 'width ' + s.hp + ' HP is not in Doepfer\'s table; the panel width is the formula HP x 5.08 - 0.3');

      var prof = s.grid.profile ? profile(s.grid.profile) : null;
      if (!prof || prof.status === 'candidate')
        f('provisional-grid', 'note', [], 'grid profile ' + JSON.stringify(s.grid.profile || '') + ' is a candidate pitch, not an approved one; this sketch is provisional');
      catalogue.hardware.forEach(function (hw) {
        var ids = ps.filter(function (p) { return p.hardware.id === hw.id; }).map(function (p) { return p.id; });
        if (!ids.length) return;
        if (hw.frontEvidence === 'unverified')
          f('unverified-front', 'note', ids, hw.id + ': nut, knob or cable envelope is an estimate awaiting the mockup (' + ids.length + ' control' + (ids.length === 1 ? '' : 's') + ')');
        if (hw.footprint === null)
          f('no-footprint', 'note', ids, hw.id + ': no footprint exists yet, so a design cannot place it until lib/footprints gains one');
        if (hw.status === 'proposed')
          f('proposed-hardware', 'note', ids, hw.id + ': proposed in the hardware standard, not yet designed in or measured');
      });
      // stable sort by severity, keeping discovery order within a severity
      return out.map(function (x, k) { return [x, k]; })
        .sort(function (u, v) { return (SEV_ORDER[u[0].severity] - SEV_ORDER[v[0].severity]) || (u[1] - v[1]); })
        .map(function (u) { return u[0]; });
    }

    // Default grids, as Sketch.Catalogue derives them.
    function columnsFor(hp, pitch) {
      var sk = skeleton(hp);
      return Math.max(1, Math.floor((sk.panelWidth - 2 * form.minCentreEdgeDistance) / pitch + 1e-9) + 1);
    }
    var deepestBelow = Math.max.apply(null, catalogue.hardware.map(function (h) { return h.courtyard.y2; }));
    function rowsFor(prof) {
      var last = form.pcbTop + form.pcbHeight - deepestBelow;
      return Math.max(1, Math.floor((last - prof.firstRow) / prof.pitch.y + 1e-9) + 1);
    }
    // Rounded to a nanometre, as Sketch.Catalogue.roundMm does, so a derived
    // origin reads as 12.65 rather than 12.649999999999999 and the two
    // implementations agree exactly. Math.round is what the Haskell mirrors.
    function roundMm(x) { return Math.round(x * 1e6) / 1e6; }
    function defaultGrid(hp, profileId) {
      var prof = profile(profileId) || catalogue.profiles[0];
      var n = columnsFor(hp, prof.pitch.x);
      var w = skeleton(hp).panelWidth;
      return { origin: { x: roundMm((w - (n - 1) * prof.pitch.x) / 2), y: roundMm(prof.firstRow) }, pitch: { x: prof.pitch.x, y: prof.pitch.y }, profile: prof.id };
    }
    // How many columns and rows a grid shows on a panel: every cell whose
    // centre lies inside the panel. The grid is unbounded; the panel bounds it.
    function gridExtent(s) {
      var sk = skeleton(s.hp), g = s.grid;
      var cols = Math.max(0, Math.floor((sk.panelWidth - g.origin.x) / g.pitch.x + 1e-9) + 1);
      var rows = Math.max(0, Math.floor((form.panelHeight - g.origin.y) / g.pitch.y + 1e-9) + 1);
      return { cols: cols, rows: rows };
    }
    function newSketch(name, hp, profileId) {
      return canonical({ name: name, status: 'provisional', hp: hp, grid: defaultGrid(hp, profileId), controls: [] });
    }

    return {
      FORMAT: FORMAT, VERSION: VERSION, catalogue: catalogue, form: form,
      hardware: hardware, profile: profile, skeleton: skeleton,
      parseStrict: parseStrict, parse: parse, validate: validate, canonical: canonical, stringify: stringify, expand: expand,
      validIdentifier: validIdentifier,
      rotatePt: rotatePt, boxRotate: boxRotate, shapeRotate: shapeRotate, cells: cells, controlCentre: controlCentre,
      toBoard: toBoard, originFor: originFor, placeControl: placeControl, place: place, boardZone: boardZone, railHoles: railHoles,
      boxesOverlap: boxesOverlap, shapesOverlap: shapesOverlap,
      check: check, columnsFor: columnsFor, rowsFor: rowsFor, roundMm: roundMm, defaultGrid: defaultGrid, gridExtent: gridExtent, newSketch: newSketch
    };
  }

  return { make: make, parseStrict: parseStrict, validIdentifier: validIdentifier, FORMAT: FORMAT, VERSION: VERSION };
});
