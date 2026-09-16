// sketchbook.js: the editor's state, without a DOM. A sketchbook holds
// several module sketches; every edit is a pure function from a sketch to a
// sketch, each sketch has its own undo stack, and each is mirrored into
// storage under its own key.
//
// Storage (localStorage, or fast-ui's server-backed shim of it):
//   sketchbook.index  -> {"version": 2, "order": [id, ...], "current": id}
//   sketch:<id>       -> the sketch's JSON text, as it would be saved
(function (root, factory) {
  if (typeof module !== 'undefined' && module.exports) { module.exports = factory(); }
  else { root.Sketchbook = factory(); }
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  var INDEX_KEY = 'sketchbook.index';
  var SKETCH_PREFIX = 'sketch:';
  var HISTORY_LIMIT = 200;
  var ID_RE = /^[A-Za-z0-9_-]{1,40}$/;

  function clone(v) { return JSON.parse(JSON.stringify(v)); }

  // Edits. Shrinking the grid is refused while a component sits outside the
  // new size, so nothing disappears behind the user's back.
  function edits(core) {
    function withCells(s, cells) {
      var t = clone(s); t.cells = cells; return core.canonical(t);
    }
    return {
      setName: function (s, name) { var t = clone(s); t.name = name; return core.canonical(t); },
      resize: function (s, columns, rows) {
        if (columns < 1 || columns > core.maxColumns) throw new Error('columns must be 1 to ' + core.maxColumns);
        if (rows < 1 || rows > core.maxRows) throw new Error('rows must be 1 to ' + core.maxRows);
        var stranded = s.cells.filter(function (c) { return c.col >= columns || c.row >= rows; });
        if (stranded.length) {
          throw new Error('clear ' + stranded.map(function (c) {
            return (c.label || c.kind) + ' at ' + (c.col + 1) + ',' + (c.row + 1);
          }).join(' and ') + ' first');
        }
        var t = clone(s); t.columns = columns; t.rows = rows; return core.canonical(t);
      },
      put: function (s, col, row, kindId, label) {
        if (!core.kind(kindId)) throw new Error('unknown kind ' + kindId);
        var rest = s.cells.filter(function (c) { return !(c.col === col && c.row === row); });
        return withCells(s, rest.concat([{ col: col, row: row, kind: kindId, label: label || '' }]));
      },
      clear: function (s, col, row) {
        return withCells(s, s.cells.filter(function (c) { return !(c.col === col && c.row === row); }));
      },
      setLabel: function (s, col, row, label) {
        var c = core.at(s, col, row);
        return c ? this.put(s, col, row, c.kind, label) : s;
      },
      setKind: function (s, col, row, kindId) {
        var c = core.at(s, col, row);
        return c ? this.put(s, col, row, kindId, c.label) : s;
      },
      // Move a component to another cell, swapping with whatever is there.
      move: function (s, fromCol, fromRow, toCol, toRow) {
        var a = core.at(s, fromCol, fromRow);
        if (!a) return s;
        if (toCol < 0 || toCol >= s.columns || toRow < 0 || toRow >= s.rows) return s;
        var b = core.at(s, toCol, toRow);
        var rest = s.cells.filter(function (c) {
          return !(c.col === fromCol && c.row === fromRow) && !(c.col === toCol && c.row === toRow);
        });
        var moved = [{ col: toCol, row: toRow, kind: a.kind, label: a.label }];
        if (b) moved.push({ col: fromCol, row: fromRow, kind: b.kind, label: b.label });
        return withCells(s, rest.concat(moved));
      }
    };
  }

  function createStore(core, storage) {
    var listeners = [];
    var order = [];
    var sketches = Object.create(null);
    var history = Object.create(null);
    var current = null;
    var storageErrors = [];

    function safeGet(k) { try { return storage ? storage.getItem(k) : null; } catch (e) { storageErrors.push(String(e)); return null; } }
    function safeSet(k, v) { try { if (storage) storage.setItem(k, v); } catch (e) { storageErrors.push(String(e)); } }
    function safeRemove(k) { try { if (storage) storage.removeItem(k); } catch (e) { storageErrors.push(String(e)); } }

    function emit(what) { listeners.forEach(function (l) { l(what); }); }
    function hist(id) { return history[id] || (history[id] = { undo: [], redo: [] }); }
    function writeIndex() { safeSet(INDEX_KEY, JSON.stringify({ version: 2, order: order.slice(), current: current })); }
    function writeSketch(id) { safeSet(SKETCH_PREFIX + id, core.stringify(sketches[id])); }

    // Malformed entries are reported, never deleted: a hand-edited file is
    // the user's to fix.
    function load() {
      var problems = [];
      var idx = safeGet(INDEX_KEY), parsed = null;
      if (idx) { try { parsed = JSON.parse(idx); } catch (e) { problems.push('sketchbook index is not JSON: ' + e.message); } }
      var ids = (parsed && Array.isArray(parsed.order)) ? parsed.order.filter(function (x) { return typeof x === 'string'; }) : [];
      if (storage && typeof storage.length === 'number' && typeof storage.key === 'function') {
        try {
          for (var i = 0; i < storage.length; i++) {
            var k = storage.key(i);
            if (k && k.indexOf(SKETCH_PREFIX) === 0 && ids.indexOf(k.slice(SKETCH_PREFIX.length)) < 0) {
              ids.push(k.slice(SKETCH_PREFIX.length));
            }
          }
        } catch (e) { storageErrors.push(String(e)); }
      }
      order = []; sketches = Object.create(null); history = Object.create(null);
      ids.forEach(function (id) {
        var txt = safeGet(SKETCH_PREFIX + id);
        if (txt === null) { problems.push('sketch ' + id + ' is listed but missing'); return; }
        var r = core.parse(txt);
        if (!r.ok) { problems.push('sketch ' + id + ' is not valid: ' + r.errors.join('; ')); return; }
        order.push(id); sketches[id] = r.sketch;
      });
      current = (parsed && typeof parsed.current === 'string' && sketches[parsed.current]) ? parsed.current : (order[0] || null);
      emit({ type: 'load', problems: problems });
      return problems;
    }

    function add(id, sketch) {
      if (!ID_RE.test(id)) throw new Error('a sketch id uses letters, digits, - and _');
      if (sketches[id]) throw new Error('a sketch named ' + id + ' already exists');
      sketches[id] = core.canonical(sketch);
      order.push(id);
      current = id;
      writeSketch(id); writeIndex();
      emit({ type: 'add', id: id });
      return id;
    }
    function remove(id) {
      if (!sketches[id]) return;
      delete sketches[id]; delete history[id];
      order = order.filter(function (x) { return x !== id; });
      if (current === id) current = order[0] || null;
      safeRemove(SKETCH_PREFIX + id); writeIndex();
      emit({ type: 'remove', id: id });
    }
    function rename(id, newId) {
      if (!sketches[id] || id === newId) return;
      if (!ID_RE.test(newId)) throw new Error('a sketch id uses letters, digits, - and _');
      if (sketches[newId]) throw new Error('a sketch named ' + newId + ' already exists');
      sketches[newId] = sketches[id]; delete sketches[id];
      history[newId] = history[id]; delete history[id];
      order = order.map(function (x) { return x === id ? newId : x; });
      if (current === id) current = newId;
      safeRemove(SKETCH_PREFIX + id); writeSketch(newId); writeIndex();
      emit({ type: 'rename', id: id, newId: newId });
    }
    function select(id) {
      if (!sketches[id]) return;
      current = id; writeIndex();
      emit({ type: 'select', id: id });
    }
    function get(id) { return sketches[id || current] || null; }

    // An exception inside fn leaves everything as it was.
    function edit(fn, id) {
      var target = id || current;
      if (!sketches[target]) return null;
      var before = sketches[target];
      var after = fn(before);
      if (!after) return before;
      var check = core.validate(after);
      if (!check.ok) throw new Error('edit produced an invalid sketch: ' + check.errors.join('; '));
      after = check.sketch;
      if (JSON.stringify(after) === JSON.stringify(before)) return before;
      var h = hist(target);
      h.undo.push(before);
      if (h.undo.length > HISTORY_LIMIT) h.undo.shift();
      h.redo = [];
      sketches[target] = after;
      writeSketch(target);
      emit({ type: 'edit', id: target });
      return after;
    }
    function undo(id) {
      var t = id || current, h = hist(t);
      if (!h.undo.length) return false;
      h.redo.push(sketches[t]);
      sketches[t] = h.undo.pop();
      writeSketch(t);
      emit({ type: 'undo', id: t });
      return true;
    }
    function redo(id) {
      var t = id || current, h = hist(t);
      if (!h.redo.length) return false;
      h.undo.push(sketches[t]);
      sketches[t] = h.redo.pop();
      writeSketch(t);
      emit({ type: 'redo', id: t });
      return true;
    }
    function canUndo(id) { return hist(id || current).undo.length > 0; }
    function canRedo(id) { return hist(id || current).redo.length > 0; }

    // Replace from outside (a file, or the agent). The previous version goes
    // on the undo stack, so an import is never a loss.
    function replace(id, sketch) {
      var r = core.validate(sketch);
      if (!r.ok) throw new Error('not a valid sketch: ' + r.errors.join('; '));
      if (!sketches[id]) return add(id, r.sketch);
      if (JSON.stringify(r.sketch) === JSON.stringify(sketches[id])) return id;
      hist(id).undo.push(sketches[id]); hist(id).redo = [];
      sketches[id] = r.sketch;
      writeSketch(id);
      emit({ type: 'replace', id: id });
      return id;
    }

    function onStorage(key, newValue) {
      if (key === INDEX_KEY) {
        var idx; try { idx = JSON.parse(newValue); } catch (e) { return; }
        if (!idx || !Array.isArray(idx.order)) return;
        var known = idx.order.filter(function (x) { return sketches[x]; });
        order.forEach(function (x) { if (known.indexOf(x) < 0) known.push(x); });
        order = known;
        emit({ type: 'index' });
        return;
      }
      if (key && key.indexOf(SKETCH_PREFIX) === 0) {
        var id = key.slice(SKETCH_PREFIX.length);
        if (newValue === null) { if (sketches[id]) remove(id); return; }
        var r = core.parse(newValue);
        if (!r.ok) { emit({ type: 'external-invalid', id: id, errors: r.errors }); return; }
        if (sketches[id] && JSON.stringify(r.sketch) === JSON.stringify(sketches[id])) return;
        if (sketches[id]) { hist(id).undo.push(sketches[id]); hist(id).redo = []; sketches[id] = r.sketch; }
        else { sketches[id] = r.sketch; order.push(id); if (!current) current = id; }
        emit({ type: 'external', id: id });
      }
    }

    function exportAll() {
      var out = {};
      order.forEach(function (id) { out[id] = core.stringify(sketches[id]); });
      return out;
    }

    return {
      load: load, add: add, remove: remove, rename: rename, select: select, get: get, edit: edit,
      undo: undo, redo: redo, canUndo: canUndo, canRedo: canRedo, replace: replace,
      onStorage: onStorage, exportAll: exportAll,
      ids: function () { return order.slice(); },
      current: function () { return current; },
      subscribe: function (l) { listeners.push(l); return function () { listeners = listeners.filter(function (x) { return x !== l; }); }; },
      storageErrors: function () { return storageErrors.slice(); },
      INDEX_KEY: INDEX_KEY, SKETCH_PREFIX: SKETCH_PREFIX
    };
  }

  function memoryStorage() {
    var m = {};
    return {
      getItem: function (k) { return Object.prototype.hasOwnProperty.call(m, k) ? m[k] : null; },
      setItem: function (k, v) { m[k] = String(v); },
      removeItem: function (k) { delete m[k]; },
      key: function (i) { return Object.keys(m)[i] || null; },
      get length() { return Object.keys(m).length; }
    };
  }

  return { edits: edits, createStore: createStore, memoryStorage: memoryStorage, INDEX_KEY: INDEX_KEY, SKETCH_PREFIX: SKETCH_PREFIX };
});
