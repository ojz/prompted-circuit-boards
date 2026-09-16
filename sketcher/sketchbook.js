// sketchbook.js: the editor's state, without a DOM. A sketchbook is a set of
// module sketches (docs/ROADMAP.md S2, extended 2026-09-16 to hold several
// modules so the agent and the user can work on more than one idea). Every
// edit is a pure function from a sketch to a sketch; the store keeps an undo
// and redo stack per sketch and mirrors each sketch into storage under its
// own key, so the fast-ui page and a plain file:// page share the code.
//
// Storage layout (localStorage, or fast-ui's server-backed shim of it):
//   sketchbook.index  -> JSON {"version": 1, "order": [id, ...], "current": id}
//   sketch:<id>       -> the sketch's JSON text, exactly as it would be saved
// The index is the only key that says which sketches exist; a sketch key
// without an index entry is recovered on load rather than lost.
(function (root, factory) {
  if (typeof module !== 'undefined' && module.exports) { module.exports = factory(); }
  else { root.Sketchbook = factory(); }
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  var INDEX_KEY = 'sketchbook.index';
  var SKETCH_PREFIX = 'sketch:';
  var HISTORY_LIMIT = 200;

  function clone(v) { return JSON.parse(JSON.stringify(v)); }

  // Sketch edits ----------------------------------------------------------------
  // Each takes a canonical sketch (core.canonical) and returns a new one.
  // They never move or drop other controls: a narrower panel leaves controls
  // where they are and the checks report them outside.
  function edits(core) {
    function withControls(s, controls) {
      var t = clone(s); t.controls = controls; return core.canonical(t);
    }
    function findIndex(s, id) {
      for (var i = 0; i < s.controls.length; i++) if (s.controls[i].id === id) return i;
      return -1;
    }
    function uniqueId(s, base) {
      var ids = Object.create(null);
      s.controls.forEach(function (c) { ids[c.id] = true; });
      var stem = (base || 'ctl').replace(/[^A-Za-z0-9_-]/g, '-').slice(0, 30) || 'ctl';
      if (!ids[stem]) return stem;
      for (var n = 2; ; n++) { var cand = stem + '-' + n; if (!ids[cand]) return cand; }
    }
    return {
      uniqueId: uniqueId,
      findIndex: findIndex,
      get: function (s, id) { var i = findIndex(s, id); return i < 0 ? null : core.expand(s.controls[i]); },
      setHP: function (s, hp) { var t = clone(s); t.hp = hp; return core.canonical(t); },
      setName: function (s, name) { var t = clone(s); t.name = name; return core.canonical(t); },
      setStatus: function (s, status) { var t = clone(s); t.status = status; return core.canonical(t); },
      setNotes: function (s, notes) { var t = clone(s); t.notes = notes; return core.canonical(t); },
      setGrid: function (s, grid) { var t = clone(s); t.grid = clone(grid); return core.canonical(t); },
      // Re-derive the default origin for the current width and a profile.
      applyProfile: function (s, profileId) { var t = clone(s); t.grid = core.defaultGrid(s.hp, profileId); return core.canonical(t); },
      addControl: function (s, hardwareId, cell, props) {
        var hw = core.hardware(hardwareId);
        if (!hw) throw new Error('unknown hardware ' + hardwareId);
        var c = { id: uniqueId(s, (props && props.id) || hw.role), hardware: hardwareId, cell: { col: cell.col, row: cell.row },
                  span: { cols: 1, rows: 1 }, offset: { x: 0, y: 0 }, rotation: 0, label: '', group: null };
        if (props) Object.keys(props).forEach(function (k) { if (k !== 'id') c[k] = clone(props[k]); });
        return withControls(s, s.controls.concat([c]));
      },
      updateControl: function (s, id, changes) {
        var i = findIndex(s, id);
        if (i < 0) return s;
        var c = core.expand(s.controls[i]);
        Object.keys(changes).forEach(function (k) { c[k] = clone(changes[k]); });
        var controls = s.controls.slice(); controls[i] = c;
        return withControls(s, controls);
      },
      renameControl: function (s, id, newId) {
        if (!core.validIdentifier(newId)) throw new Error('not an identifier: ' + newId);
        if (newId !== id && findIndex(s, newId) >= 0) throw new Error('id already used: ' + newId);
        return this.updateControl(s, id, { id: newId });
      },
      moveControl: function (s, id, cell) { return this.updateControl(s, id, { cell: { col: cell.col, row: cell.row } }); },
      nudgeControl: function (s, id, dcol, drow) {
        var c = this.get(s, id); if (!c) return s;
        return this.moveControl(s, id, { col: c.cell.col + dcol, row: c.cell.row + drow });
      },
      rotateControl: function (s, id, steps) {
        var c = this.get(s, id); if (!c) return s;
        var hw = core.hardware(c.hardware);
        var i = hw.rotations.indexOf(c.rotation);
        var next = hw.rotations[(((i < 0 ? 0 : i) + steps) % hw.rotations.length + hw.rotations.length) % hw.rotations.length];
        return this.updateControl(s, id, { rotation: next });
      },
      duplicateControl: function (s, id) {
        var c = this.get(s, id); if (!c) return s;
        var d = clone(c);
        d.id = uniqueId(s, c.id);
        d.cell = { col: c.cell.col + c.span.cols, row: c.cell.row };
        return withControls(s, s.controls.concat([d]));
      },
      deleteControl: function (s, id) {
        return withControls(s, s.controls.filter(function (c) { return c.id !== id; }));
      },
      setGroups: function (s, groups) {
        var t = clone(s);
        t.groups = groups;
        var keep = Object.create(null);
        groups.forEach(function (g) { keep[g.id] = true; });
        t.controls = t.controls.map(function (c) { if (c.group && !keep[c.group]) { var d = clone(c); delete d.group; return d; } return c; });
        return core.canonical(t);
      },
      addGroup: function (s, id, label) {
        if (!core.validIdentifier(id)) throw new Error('not an identifier: ' + id);
        var groups = (s.groups || []).slice();
        if (groups.some(function (g) { return g.id === id; })) return s;
        groups.push({ id: id, label: label || '' });
        return this.setGroups(s, groups);
      },
      removeGroup: function (s, id) {
        return this.setGroups(s, (s.groups || []).filter(function (g) { return g.id !== id; }));
      }
    };
  }

  // Store ---------------------------------------------------------------------------
  // Holds the sketchbook, per-sketch history, and the storage mirror. `storage`
  // has getItem/setItem/removeItem; pass null to keep everything in memory.
  function createStore(core, storage, options) {
    var opts = options || {};
    var listeners = [];
    var order = [];        // sketch ids in display order
    // Null prototypes: sketch ids come from the user, and a plain object
    // would answer get("constructor") with an inherited function.
    var sketches = Object.create(null);     // id -> canonical sketch
    var history = Object.create(null);      // id -> {undo: [sketch], redo: [sketch]}
    var current = null;
    var storageErrors = [];

    function safeGet(k) { try { return storage ? storage.getItem(k) : null; } catch (e) { storageErrors.push(String(e)); return null; } }
    function safeSet(k, v) { try { if (storage) storage.setItem(k, v); } catch (e) { storageErrors.push(String(e)); } }
    function safeRemove(k) { try { if (storage) storage.removeItem(k); } catch (e) { storageErrors.push(String(e)); } }

    function emit(what) { listeners.forEach(function (l) { l(what); }); }

    function hist(id) { return history[id] || (history[id] = { undo: [], redo: [] }); }

    function writeIndex() {
      safeSet(INDEX_KEY, JSON.stringify({ version: 1, order: order.slice(), current: current }));
    }
    function writeSketch(id) { safeSet(SKETCH_PREFIX + id, core.stringify(sketches[id])); }

    // Load from storage. Malformed entries are reported, never deleted: the
    // user may want to fix a hand-edited file. Returns the list of problems.
    function load() {
      var problems = [];
      var idx = safeGet(INDEX_KEY);
      var parsedIndex = null;
      if (idx) {
        try { parsedIndex = JSON.parse(idx); } catch (e) { problems.push('sketchbook index is not JSON: ' + e.message); }
      }
      var ids = [];
      if (parsedIndex && Array.isArray(parsedIndex.order)) ids = parsedIndex.order.filter(function (x) { return typeof x === 'string'; });
      // recover sketch keys the index does not list
      if (storage && typeof storage.length === 'number' && typeof storage.key === 'function') {
        try {
          for (var i = 0; i < storage.length; i++) {
            var k = storage.key(i);
            if (k && k.indexOf(SKETCH_PREFIX) === 0 && ids.indexOf(k.slice(SKETCH_PREFIX.length)) < 0) ids.push(k.slice(SKETCH_PREFIX.length));
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
      current = (parsedIndex && typeof parsedIndex.current === 'string' && sketches[parsedIndex.current]) ? parsedIndex.current : (order[0] || null);
      emit({ type: 'load', problems: problems });
      return problems;
    }

    function validId(id) { return core.validIdentifier(id); }

    function add(id, sketch) {
      if (!validId(id)) throw new Error('sketch id must be an identifier: ' + id);
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
      if (!validId(newId)) throw new Error('sketch id must be an identifier: ' + newId);
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

    // Apply an edit to the current sketch, recording history. `fn` gets the
    // sketch and returns the new one; an exception leaves everything intact.
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
      var target = id || current, h = hist(target);
      if (!h.undo.length) return false;
      h.redo.push(sketches[target]);
      sketches[target] = h.undo.pop();
      writeSketch(target);
      emit({ type: 'undo', id: target });
      return true;
    }
    function redo(id) {
      var target = id || current, h = hist(target);
      if (!h.redo.length) return false;
      h.undo.push(sketches[target]);
      sketches[target] = h.redo.pop();
      writeSketch(target);
      emit({ type: 'redo', id: target });
      return true;
    }
    function canUndo(id) { return hist(id || current).undo.length > 0; }
    function canRedo(id) { return hist(id || current).redo.length > 0; }

    // Replace a sketch from outside (a file, or the agent through storage).
    // The previous version goes on the undo stack so nothing is lost.
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

    // A storage event from another tab or from the agent's set_state. Only the
    // key named is touched; nothing else in the editor changes.
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
      undo: undo, redo: redo, canUndo: canUndo, canRedo: canRedo, replace: replace, onStorage: onStorage,
      exportAll: exportAll,
      ids: function () { return order.slice(); },
      current: function () { return current; },
      subscribe: function (l) { listeners.push(l); return function () { listeners = listeners.filter(function (x) { return x !== l; }); }; },
      storageErrors: function () { return storageErrors.slice(); },
      INDEX_KEY: INDEX_KEY, SKETCH_PREFIX: SKETCH_PREFIX,
      options: opts
    };
  }

  // A minimal in-memory storage with the localStorage interface, for tests
  // and for a browser that blocks storage.
  function memoryStorage() {
    var m = {};
    return {
      getItem: function (k) { return Object.prototype.hasOwnProperty.call(m, k) ? m[k] : null; },
      setItem: function (k, v) { m[k] = String(v); },
      removeItem: function (k) { delete m[k]; },
      key: function (i) { return Object.keys(m)[i] || null; },
      get length() { return Object.keys(m).length; },
      dump: function () { return JSON.parse(JSON.stringify(m)); }
    };
  }

  return { edits: edits, createStore: createStore, memoryStorage: memoryStorage, INDEX_KEY: INDEX_KEY, SKETCH_PREFIX: SKETCH_PREFIX };
});
