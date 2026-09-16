// tests.js: the sketcher's tests. Runs under node (`node sketcher/tests.js`)
// and in the browser (tests.html), so the same assertions cover the file://
// case the roadmap asks for. The geometry and checks are compared with the
// vectors the Haskell generator wrote (vectors.js); the editing, undo/redo,
// width-change and save/reopen cases exercise sketchbook.js.
(function (root, factory) {
  if (typeof module !== 'undefined' && module.exports) {
    var path = require('path');
    var here = __dirname;
    var deps = {
      catalogue: require(path.join(here, 'catalogue.js')),
      vectors: require(path.join(here, 'vectors.js')),
      SketchCore: require(path.join(here, 'sketch-core.js')),
      Sketchbook: require(path.join(here, 'sketchbook.js'))
    };
    var result = factory(deps);
    result.results.forEach(function (r) {
      console.log((r.ok ? 'PASS  ' : 'FAIL  ') + r.name);
      r.failures.forEach(function (f) { console.log('      ' + f); });
    });
    console.log('');
    console.log(result.passed + '/' + result.results.length + ' tests passed');
    process.exit(result.passed === result.results.length ? 0 : 1);
  } else {
    root.runSketcherTests = function () {
      return factory({ catalogue: root.PCBGEN_CATALOGUE, vectors: root.PCBGEN_VECTORS, SketchCore: root.SketchCore, Sketchbook: root.Sketchbook });
    };
  }
})(typeof globalThis !== 'undefined' ? globalThis : this, function (deps) {
  'use strict';
  var core = deps.SketchCore.make(deps.catalogue);
  var vectors = deps.vectors;
  var Sketchbook = deps.Sketchbook;
  var ed = Sketchbook.edits(core);

  var results = [];
  function test(name, fn) {
    var failures = [];
    try { fn(function (ok, msg) { if (!ok) failures.push(msg); }); }
    catch (e) { failures.push('exception: ' + (e && e.stack || e)); }
    results.push({ name: name, ok: failures.length === 0, failures: failures });
  }
  function near(a, b, tol) { return Math.abs(a - b) <= (tol || 1e-9); }
  function ptNear(a, b) { return near(a.x, b.x) && near(a.y, b.y); }
  function boxNear(a, b) { return near(a.x1, b.x1) && near(a.y1, b.y1) && near(a.x2, b.x2) && near(a.y2, b.y2); }
  function shapeEq(a, b) {
    if (!a && !b) return true;
    if (!a || !b || a.shape !== b.shape) return false;
    return a.shape === 'circle' ? near(a.d, b.d) : (near(a.w, b.w) && near(a.h, b.h));
  }
  function findingKeys(fs) {
    return fs.map(function (f) { return f.kind + '|' + f.severity + '|' + f.controls.slice().sort().join(','); }).sort();
  }
  function clone(v) { return JSON.parse(JSON.stringify(v)); }

  // Vectors ---------------------------------------------------------------------

  vectors.valid.forEach(function (fx) {
    test('vector ' + fx.name + ': text parses to the same sketch and prints the same text', function (expect) {
      var r = core.parse(fx.text);
      expect(r.ok, 'parse failed: ' + (r.errors || []).join('; '));
      if (!r.ok) return;
      expect(JSON.stringify(r.sketch) === JSON.stringify(fx.sketch), 'parsed sketch differs from the exported value');
      expect(core.stringify(r.sketch) === fx.text, 'stringify differs from the Haskell text:\n' + core.stringify(r.sketch) + '\n---\n' + fx.text);
      var again = core.parse(core.stringify(r.sketch));
      expect(again.ok && JSON.stringify(again.sketch) === JSON.stringify(r.sketch), 'second round trip differs');
    });

    test('vector ' + fx.name + ': placements match the Haskell geometry', function (expect) {
      var sk = core.skeleton(fx.sketch.hp);
      expect(near(sk.panelWidth, fx.expected.panelWidth), 'panel width ' + sk.panelWidth);
      expect(ptNear(sk.boardOrigin, fx.expected.boardOrigin), 'board origin');
      var rails = core.railHoles(sk);
      expect(rails.length === fx.expected.railHoles.length && rails.every(function (r, i) { return ptNear(r, fx.expected.railHoles[i]); }), 'rail holes ' + JSON.stringify(rails));
      var ps = core.place(fx.sketch);
      expect(ps.length === fx.expected.controls.length, 'control count ' + ps.length);
      fx.expected.controls.forEach(function (e, i) {
        var p = ps[i];
        if (!p) return;
        expect(p.id === e.id, 'order: ' + p.id + ' vs ' + e.id);
        expect(ptNear(p.centre, e.centre), e.id + ' centre ' + JSON.stringify(p.centre) + ' vs ' + JSON.stringify(e.centre));
        expect(ptNear(p.board, e.board), e.id + ' board ' + JSON.stringify(p.board));
        expect(ptNear(p.footprintOrigin, e.footprintOrigin), e.id + ' footprint origin ' + JSON.stringify(p.footprintOrigin) + ' vs ' + JSON.stringify(e.footprintOrigin));
        expect(p.rotation === e.rotation, e.id + ' rotation');
        expect(boxNear(p.courtyard, e.courtyard), e.id + ' courtyard ' + JSON.stringify(p.courtyard) + ' vs ' + JSON.stringify(e.courtyard));
        expect(shapeEq(p.frontBody, e.frontBody), e.id + ' front body');
        expect(shapeEq(p.frontAccess, e.frontAccess), e.id + ' front access');
      });
    });

    test('vector ' + fx.name + ': findings match the Haskell checks', function (expect) {
      var got = findingKeys(core.check(fx.sketch));
      var want = findingKeys(fx.expected.findings);
      expect(JSON.stringify(got) === JSON.stringify(want), 'findings\n  got    ' + JSON.stringify(got) + '\n  wanted ' + JSON.stringify(want));
      core.check(fx.sketch).forEach(function (f) { expect(typeof f.message === 'string' && f.message.length > 0, 'empty message for ' + f.kind); });
    });
  });

  test('every invalid text is refused', function (expect) {
    vectors.invalid.forEach(function (iv) {
      var r = core.parse(iv.text);
      expect(!r.ok, 'accepted: ' + iv.name);
      if (!r.ok) expect(r.errors.length > 0 && r.errors.every(function (e) { return e.length > 0; }), 'empty diagnostic for ' + iv.name);
    });
  });

  test('the strict parser refuses what JSON.parse would take', function (expect) {
    expect(!core.parse('{"format": "pcbgen-sketch", "version": 1, "hp": 6, "hp": 8, "grid": {"origin": {"x": 1, "y": 1}, "pitch": {"x": 1, "y": 1}}, "controls": []}').ok, 'duplicate key accepted');
    var r = core.parse('{"format": "pcbgen-sketch", "version": 1, "hp": 6, "grid": {"origin": {"x": 1e999, "y": 1}, "pitch": {"x": 1, "y": 1}}, "controls": []}');
    expect(!r.ok && /finite/.test(r.errors[0]), 'infinity accepted: ' + JSON.stringify(r.errors));
    var ok = core.parse('{"format": "pcbgen-sketch", "version": 1, "hp": 6, "grid": {"origin": {"x": 7.5, "y": 20}, "pitch": {"x": 15, "y": 15}}, "controls": [], "name": "\\u00e9\\uD83D\\uDE00"}');
    expect(ok.ok && ok.sketch.name === 'é😀', 'escapes: ' + JSON.stringify(ok));
  });

  test('diagnostics name their path and are all reported', function (expect) {
    var r = core.parse('{"format": "pcbgen-sketch", "version": 1, "hp": 6, "grid": {"origin": {"x": 7.5, "y": 20}, "pitch": {"x": 15, "y": 15}},'
      + ' "controls": [{"id": "a", "hardware": "nope", "cell": {"col": 0, "row": 0}}, {"id": "b", "hardware": "pot-9mm", "cell": {"col": 0, "row": 0}, "rotation": 30}]}');
    expect(!r.ok && r.errors.length === 2, 'expected two diagnostics: ' + JSON.stringify(r.errors));
    if (!r.ok) {
      expect(r.errors.some(function (e) { return e.indexOf('controls[0].hardware') >= 0; }), 'first path');
      expect(r.errors.some(function (e) { return e.indexOf('controls[1].rotation') >= 0; }), 'second path');
    }
  });

  test('default grids agree with the generator for every width and profile', function (expect) {
    vectors.gridDefaults.forEach(function (d) {
      var g = core.defaultGrid(d.hp, d.profile);
      expect(ptNear(g.origin, d.origin), d.hp + 'HP ' + d.profile + ' origin ' + JSON.stringify(g.origin) + ' vs ' + JSON.stringify(d.origin));
      expect(core.columnsFor(d.hp, core.profile(d.profile).pitch.x) === d.columns, d.hp + 'HP ' + d.profile + ' columns');
      expect(core.rowsFor(core.profile(d.profile)) === d.rows, d.profile + ' rows');
    });
  });

  test('the rotation convention is the generator\'s', function (expect) {
    vectors.rotations.forEach(function (r) {
      expect(ptNear(core.rotatePt(r.rotation, r.in), r.out), 'rotation ' + r.rotation + ': ' + JSON.stringify(core.rotatePt(r.rotation, r.in)) + ' vs ' + JSON.stringify(r.out));
    });
  });

  // Editing ---------------------------------------------------------------------

  var sparse = vectors.valid.filter(function (f) { return f.name === 'sparse-mixed'; })[0].sketch;

  function freshStore(storage) {
    var st = Sketchbook.createStore(core, storage || Sketchbook.memoryStorage());
    st.load();
    return st;
  }

  test('a new sketch starts empty with a centred default grid', function (expect) {
    var s = core.newSketch('Test', 8, 'candidate-15');
    expect(s.controls.length === 0, 'not empty');
    expect(s.hp === 8 && near(s.grid.origin.x, 12.65) && s.grid.origin.y === 20, 'grid ' + JSON.stringify(s.grid));
    var fs = core.check(s);
    expect(fs.every(function (f) { return f.severity === 'note'; }), 'a blank panel has findings: ' + JSON.stringify(fs));
  });

  test('sparse placement: adding controls one by one reproduces the fixture, with cells left empty', function (expect) {
    var st = freshStore();
    st.add('m', core.newSketch(sparse.name, 8, 'candidate-15'));
    st.edit(function (s) { return ed.addControl(s, 'pot-9mm', { col: 0, row: 0 }, { id: 'level', rotation: 90, label: 'LEVEL' }); });
    st.edit(function (s) { return ed.addGroup(s, 'ch1', 'Channel 1'); });
    st.edit(function (s) { return ed.updateControl(s, 'level', { group: 'ch1' }); });
    st.edit(function (s) { return ed.addControl(s, 'jack-ts', { col: 0, row: 1 }, { id: 'in', label: 'IN', group: 'ch1' }); });
    st.edit(function (s) { return ed.addControl(s, 'jack-ts', { col: 1, row: 1 }, { id: 'out', label: 'OUT', group: 'ch1' }); });
    st.edit(function (s) { return ed.addControl(s, 'led-3mm', { col: 1, row: 1 }, { id: 'out-led', offset: { x: 6, y: -6 }, group: 'ch1' }); });
    st.edit(function (s) { return ed.addControl(s, 'toggle-spdt', { col: 1, row: 3 }, { id: 'cycle', label: 'CYCLE' }); });
    st.edit(function (s) { return ed.addControl(s, 'pot-9mm', { col: 0, row: 5 }, { id: 'freq', span: { cols: 2, rows: 1 }, label: 'FREQ' }); });
    st.edit(function (s) { return ed.setNotes(s, sparse.notes); });
    var got = st.get('m');
    expect(JSON.stringify(got) === JSON.stringify(sparse), 'built sketch differs:\n' + core.stringify(got) + '\n---\n' + core.stringify(sparse));
    expect(core.check(got).every(function (f) { return f.severity === 'note'; }), 'fixture built by hand has conflicts');
    var occupied = {};
    got.controls.forEach(function (c) { core.cells(c).forEach(function (x) { occupied[x.col + ',' + x.row] = true; }); });
    expect(!occupied['0,2'] && !occupied['1,0'] && !occupied['0,3'], 'empty cells filled');
  });

  test('move, rotate, duplicate, rename, relabel and delete', function (expect) {
    var st = freshStore();
    st.add('m', sparse);
    st.edit(function (s) { return ed.moveControl(s, 'cycle', { col: 0, row: 3 }); });
    expect(ed.get(st.get(), 'cycle').cell.col === 0, 'move');
    st.edit(function (s) { return ed.rotateControl(s, 'cycle', 1); });
    expect(ed.get(st.get(), 'cycle').rotation === 90, 'rotate');
    st.edit(function (s) { return ed.rotateControl(s, 'cycle', -1); });
    expect(ed.get(st.get(), 'cycle').rotation === 0, 'rotate back');
    st.edit(function (s) { return ed.duplicateControl(s, 'in'); });
    var dup = ed.get(st.get(), 'in-2');
    expect(dup && dup.cell.col === 1 && dup.cell.row === 1 && dup.label === 'IN', 'duplicate: ' + JSON.stringify(dup));
    expect(core.check(st.get()).some(function (f) { return f.kind === 'cell-overlap' && f.controls.indexOf('in-2') >= 0; }), 'duplicate onto an occupied cell must be reported, not relocated');
    st.edit(function (s) { return ed.renameControl(s, 'in-2', 'in-b'); });
    expect(ed.get(st.get(), 'in-b') && !ed.get(st.get(), 'in-2'), 'rename');
    var threw = false;
    try { st.edit(function (s) { return ed.renameControl(s, 'in-b', 'in'); }); } catch (e) { threw = true; }
    expect(threw && ed.get(st.get(), 'in-b'), 'renaming onto an existing id must fail and change nothing');
    st.edit(function (s) { return ed.updateControl(s, 'in-b', { label: 'IN B' }); });
    expect(ed.get(st.get(), 'in-b').label === 'IN B', 'relabel');
    st.edit(function (s) { return ed.deleteControl(s, 'in-b'); });
    expect(!ed.get(st.get(), 'in-b') && st.get().controls.length === sparse.controls.length, 'delete');
  });

  test('undo and redo walk the history and stop at its ends', function (expect) {
    var st = freshStore();
    st.add('m', sparse);
    expect(!st.canUndo() && !st.canRedo(), 'fresh sketch has history');
    st.edit(function (s) { return ed.deleteControl(s, 'freq'); });
    st.edit(function (s) { return ed.setHP(s, 10); });
    expect(st.get().hp === 10 && st.get().controls.length === 5, 'edits applied');
    expect(st.undo() && st.get().hp === 8, 'undo hp');
    expect(st.undo() && st.get().controls.length === 6, 'undo delete');
    expect(!st.undo(), 'undo past the start');
    expect(st.redo() && st.get().controls.length === 5, 'redo delete');
    st.edit(function (s) { return ed.setName(s, 'Branch'); });
    expect(!st.canRedo(), 'a new edit must clear the redo stack');
    expect(JSON.stringify(st.get()) !== JSON.stringify(sparse) && st.undo() && st.undo() && JSON.stringify(st.get()) === JSON.stringify(sparse), 'back to the start');
  });

  test('an edit that changes nothing leaves no history entry', function (expect) {
    var st = freshStore();
    st.add('m', sparse);
    st.edit(function (s) { return ed.setHP(s, 8); });
    expect(!st.canUndo(), 'no-op recorded');
  });

  test('narrowing the panel keeps every control and reports the ones outside', function (expect) {
    var st = freshStore();
    st.add('m', sparse);
    st.edit(function (s) { return ed.setHP(s, 4); });
    var s = st.get();
    expect(s.controls.length === sparse.controls.length, 'controls dropped');
    expect(JSON.stringify(s.controls) === JSON.stringify(sparse.controls), 'controls moved');
    var outside = {};
    core.check(s).forEach(function (f) { if (f.kind === 'outside-panel' || f.kind === 'outside-board-zone') f.controls.forEach(function (c) { outside[c] = true; }); });
    expect(outside.out && outside.cycle, 'right-hand column not reported: ' + JSON.stringify(Object.keys(outside)));
    st.undo();
    expect(core.check(st.get()).every(function (f) { return f.severity === 'note'; }), 'undo did not restore a clean sketch');
  });

  test('save and reopen: the sketchbook survives a round trip through storage', function (expect) {
    var storage = Sketchbook.memoryStorage();
    var st = freshStore(storage);
    st.add('alpha', sparse);
    st.add('beta', core.newSketch('Beta', 6, 'candidate-15.24'));
    st.edit(function (s) { return ed.addControl(s, 'jack-ts', { col: 0, row: 0 }); }, 'beta');
    st.select('alpha');
    var exported = st.exportAll();
    var st2 = freshStore(storage);
    expect(JSON.stringify(st2.ids()) === JSON.stringify(['alpha', 'beta']), 'ids ' + JSON.stringify(st2.ids()));
    expect(st2.current() === 'alpha', 'current ' + st2.current());
    expect(JSON.stringify(st2.exportAll()) === JSON.stringify(exported), 'sketches differ after reopen');
    expect(exported.alpha === core.stringify(sparse), 'export text is not the canonical text');
    // and through a file: text -> parse -> replace
    var st3 = freshStore();
    var r = core.parse(exported.alpha);
    expect(r.ok, 'exported text does not parse');
    st3.add('alpha', r.sketch);
    expect(core.stringify(st3.get('alpha')) === exported.alpha, 'file round trip differs');
  });

  test('a malformed stored sketch is reported and the others load', function (expect) {
    var storage = Sketchbook.memoryStorage();
    var st = freshStore(storage);
    st.add('good', sparse);
    st.add('bad', core.newSketch('Bad', 6, 'candidate-15'));
    storage.setItem('sketch:bad', '{"format": "pcbgen-sketch", "version": 1, "hp": 6,');
    storage.setItem('sketch:orphan', core.stringify(core.newSketch('Orphan', 4, 'candidate-15')));
    var st2 = freshStore(storage);
    var problems = st2.load();
    expect(problems.length === 1 && /bad/.test(problems[0]), 'problems ' + JSON.stringify(problems));
    expect(st2.get('good') && !st2.get('bad'), 'good sketch lost or bad sketch loaded');
    expect(st2.get('orphan'), 'an unindexed sketch key was not recovered');
    expect(storage.getItem('sketch:bad') !== null, 'the malformed entry was deleted');
  });

  test('a failed import leaves the current work intact', function (expect) {
    var st = freshStore();
    st.add('m', sparse);
    var before = JSON.stringify(st.get());
    var r = core.parse('{"format": "pcbgen-sketch", "version": 3}');
    expect(!r.ok, 'accepted a bad import');
    var threw = false;
    try { st.replace('m', { format: 'pcbgen-sketch', version: 1 }); } catch (e) { threw = true; }
    expect(threw, 'replace with an invalid sketch did not fail');
    expect(JSON.stringify(st.get()) === before && !st.canUndo(), 'work changed after a failed import');
  });

  test('an external update through storage replaces one sketch and is undoable', function (expect) {
    var storage = Sketchbook.memoryStorage();
    var st = freshStore(storage);
    st.add('m', sparse);
    st.add('other', core.newSketch('Other', 6, 'candidate-15'));
    var events = [];
    st.subscribe(function (e) { events.push(e.type); });
    var incoming = ed.setName(sparse, 'From the agent');
    st.onStorage('sketch:m', core.stringify(incoming));
    expect(st.get('m').name === 'From the agent', 'external update not applied');
    expect(st.get('other').name === 'Other', 'other sketch touched');
    expect(st.canUndo('m') && st.undo('m') && st.get('m').name === sparse.name, 'external update not undoable');
    st.onStorage('sketch:new', core.stringify(core.newSketch('New', 8, 'candidate-15')));
    expect(st.ids().indexOf('new') >= 0, 'new external sketch not added');
    st.onStorage('sketch:m', 'not json');
    expect(st.get('m').name === sparse.name && events.indexOf('external-invalid') >= 0, 'invalid external text changed the sketch or went unreported');
    st.onStorage('sketch:new', null);
    expect(st.ids().indexOf('new') < 0, 'external removal ignored');
  });

  test('storage failures never break editing', function (expect) {
    var broken = { getItem: function () { throw new Error('blocked'); }, setItem: function () { throw new Error('blocked'); }, removeItem: function () { throw new Error('blocked'); } };
    var st = Sketchbook.createStore(core, broken);
    st.load();
    st.add('m', sparse);
    st.edit(function (s) { return ed.setHP(s, 10); });
    expect(st.get().hp === 10, 'edit lost');
    expect(st.storageErrors().length > 0, 'storage errors not recorded');
  });

  test('ids that name Object.prototype members are ordinary ids', function (expect) {
    // "constructor" and "toString" match the identifier pattern, so every map
    // keyed by user text must have a null prototype or these throw or lie.
    expect(core.hardware('constructor') === null, 'hardware lookup returned an inherited member');
    expect(core.profile('toString') === null, 'profile lookup returned an inherited member');
    var bad = core.parse('{"format": "pcbgen-sketch", "version": 1, "hp": 6, "grid": {"origin": {"x": 7.5, "y": 20}, "pitch": {"x": 15, "y": 15}},'
      + ' "controls": [{"id": "constructor", "hardware": "constructor", "cell": {"col": 0, "row": 0}}]}');
    expect(!bad.ok, 'a control with hardware "constructor" was accepted');
    if (!bad.ok) expect(bad.errors.some(function (e) { return e.indexOf('unknown hardware') >= 0; }), 'wrong diagnostic: ' + JSON.stringify(bad.errors));

    var ok = core.parse('{"format": "pcbgen-sketch", "version": 1, "hp": 6, "grid": {"origin": {"x": 7.5, "y": 20}, "pitch": {"x": 15, "y": 15}},'
      + ' "controls": [{"id": "constructor", "hardware": "jack-ts", "cell": {"col": 0, "row": 0}},'
      + ' {"id": "toString", "hardware": "jack-ts", "cell": {"col": 0, "row": 2}}]}');
    expect(ok.ok, 'controls named after prototype members were refused: ' + JSON.stringify(ok.errors || []));
    if (ok.ok) {
      expect(core.check(ok.sketch).every(function (f) { return f.severity === 'note'; }), 'false conflict for prototype-named controls');
      var st = freshStore();
      st.add('constructor', ok.sketch);
      expect(st.get('constructor') !== null && st.ids().length === 1, 'a sketch named "constructor" did not round trip');
      expect(st.get('toString') === null, 'an absent sketch resolved to an inherited member');
      st.edit(function (x) { return ed.deleteControl(x, 'toString'); }, 'constructor');
      expect(st.get('constructor').controls.length === 1, 'delete by a prototype-member id failed');
    }
  });

  test('sketch ids and control ids are identifiers', function (expect) {
    var st = freshStore();
    var threw = false;
    try { st.add('my module', sparse); } catch (e) { threw = true; }
    expect(threw && st.ids().length === 0, 'a sketch id with a space was accepted');
    st.add('m', sparse);
    expect(ed.uniqueId(st.get(), 'jack') === 'jack' && ed.uniqueId(st.get(), 'in') === 'in-2', 'unique ids');
  });

  var passed = results.filter(function (r) { return r.ok; }).length;
  return { results: results, passed: passed };
});
