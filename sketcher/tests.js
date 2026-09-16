// tests.js: the format and the sketchbook, in node (`node sketcher/tests.js`)
// or in a browser (tests.html). Results come from vectors.js, which the
// generator wrote, so the browser cannot drift from the Haskell.
(function (root, factory) {
  if (typeof module !== 'undefined' && module.exports) {
    var path = require('path');
    var here = __dirname;
    var r = factory({
      catalogue: require(path.join(here, 'catalogue.js')),
      vectors: require(path.join(here, 'vectors.js')),
      SketchCore: require(path.join(here, 'sketch-core.js')),
      Sketchbook: require(path.join(here, 'sketchbook.js'))
    });
    r.results.forEach(function (t) {
      console.log((t.ok ? 'PASS  ' : 'FAIL  ') + t.name);
      t.failures.forEach(function (f) { console.log('      ' + f); });
    });
    console.log('');
    console.log(r.passed + '/' + r.results.length + ' tests passed');
    process.exit(r.passed === r.results.length ? 0 : 1);
  } else {
    root.runSketcherTests = function () {
      return factory({ catalogue: root.SKETCH_CATALOGUE, vectors: root.SKETCH_VECTORS, SketchCore: root.SketchCore, Sketchbook: root.Sketchbook });
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
  function fresh() { var s = Sketchbook.createStore(core, Sketchbook.memoryStorage()); s.load(); return s; }

  // Against the generator ------------------------------------------------------

  vectors.valid.forEach(function (fx) {
    test('vector ' + fx.name + ': parses, matches and prints the generator\'s bytes', function (expect) {
      var r = core.parse(fx.text);
      expect(r.ok, 'parse failed: ' + (r.errors || []).join('; '));
      if (!r.ok) return;
      expect(JSON.stringify(r.sketch) === JSON.stringify(fx.sketch), 'parsed sketch differs from the exported value');
      expect(core.stringify(r.sketch) === fx.text, 'stringify differs:\n' + core.stringify(r.sketch) + '\n---\n' + fx.text);
      var again = core.parse(core.stringify(r.sketch));
      expect(again.ok && JSON.stringify(again.sketch) === JSON.stringify(r.sketch), 'second round trip differs');
      expect(core.impliedWidth(r.sketch) === fx.hp, 'implied width ' + core.impliedWidth(r.sketch) + ' vs ' + fx.hp);
    });
  });

  test('every invalid text is refused with a diagnostic', function (expect) {
    vectors.invalid.forEach(function (iv) {
      var r = core.parse(iv.text);
      expect(!r.ok, 'accepted: ' + iv.name);
      if (!r.ok) expect(r.errors.length > 0 && r.errors.every(function (e) { return e.length > 0; }), 'empty diagnostic for ' + iv.name);
    });
  });

  test('the grid limits are the generator\'s', function (expect) {
    expect(core.maxColumns === deps.catalogue.maxColumns, 'columns');
    expect(core.maxRows === deps.catalogue.maxRows, 'rows');
    expect(typeof core.why === 'string' && core.why.length > 40, 'the explanation is missing');
    expect(!core.validate({ format: 'module-sketch', version: 2, columns: core.maxColumns + 1, rows: 1, cells: [] }).ok, 'a grid past the limit was accepted');
    expect(core.validate({ format: 'module-sketch', version: 2, columns: core.maxColumns, rows: core.maxRows, cells: [] }).ok, 'the largest legal grid was refused');
  });

  test('the strict parser refuses what JSON.parse would take', function (expect) {
    expect(!core.parse('{"format":"module-sketch","version":2,"columns":2,"columns":3,"rows":2,"cells":[]}').ok, 'duplicate key accepted');
    var r = core.parse('{"format":"module-sketch","version":2,"columns":1e999,"rows":2,"cells":[]}');
    expect(!r.ok && /finite/.test(r.errors[0]), 'infinity accepted: ' + JSON.stringify(r.errors));
  });

  test('diagnostics name their path and are all reported', function (expect) {
    var r = core.parse('{"format":"module-sketch","version":2,"columns":2,"rows":2,"cells":['
      + '{"col":0,"row":0,"kind":"banana"},{"col":9,"row":0,"kind":"knob"}]}');
    expect(!r.ok && r.errors.length === 2, 'expected two diagnostics: ' + JSON.stringify(r.errors));
    if (!r.ok) {
      expect(r.errors.some(function (e) { return e.indexOf('cells[0].kind') >= 0; }), 'first path');
      expect(r.errors.some(function (e) { return e.indexOf('cells[1].col') >= 0; }), 'second path');
    }
  });

  // Editing ---------------------------------------------------------------------

  var mixer = vectors.valid.filter(function (f) { return f.name === 'mixer'; })[0].sketch;

  test('placing components one by one reproduces the mixer fixture', function (expect) {
    var st = fresh();
    st.add('m', core.emptySketch('Mixer', 3, 6));
    var put = [
      [0, 0, 'knob', 'CH1'], [1, 0, 'jack', 'IN 1'],
      [0, 1, 'knob', 'CH2'], [1, 1, 'jack', 'IN 2'],
      [0, 2, 'knob', 'CH3'], [1, 2, 'jack', 'IN 3'],
      [0, 3, 'knob', 'CH4'], [1, 3, 'jack', 'IN 4'],
      [0, 5, 'switch', 'AC/DC'], [1, 5, 'jack', 'OUT'], [2, 5, 'led', 'CLIP']
    ];
    put.forEach(function (p) {
      st.edit(function (s) { return ed.put(s, p[0], p[1], p[2], p[3]); });
    });
    var got = st.get('m');
    expect(JSON.stringify(got) === JSON.stringify(mixer), 'differs:\n' + core.stringify(got) + '\n---\n' + core.stringify(mixer));
    expect(core.at(got, 2, 0) === null && core.at(got, 0, 4) === null, 'empty cells are not empty');
  });

  test('a cell holds one component: placing on it replaces', function (expect) {
    var st = fresh();
    st.add('m', core.emptySketch('', 2, 2));
    st.edit(function (s) { return ed.put(s, 0, 0, 'knob', 'A'); });
    st.edit(function (s) { return ed.put(s, 0, 0, 'jack', 'B'); });
    expect(st.get().cells.length === 1, 'cells ' + st.get().cells.length);
    expect(core.at(st.get(), 0, 0).kind === 'jack', 'kind not replaced');
  });

  test('clear, relabel, change kind', function (expect) {
    var st = fresh();
    st.add('m', core.emptySketch('', 2, 2));
    st.edit(function (s) { return ed.put(s, 1, 1, 'knob', 'GAIN'); });
    st.edit(function (s) { return ed.setLabel(s, 1, 1, 'LEVEL'); });
    expect(core.at(st.get(), 1, 1).label === 'LEVEL', 'relabel');
    st.edit(function (s) { return ed.setKind(s, 1, 1, 'switch'); });
    expect(core.at(st.get(), 1, 1).kind === 'switch' && core.at(st.get(), 1, 1).label === 'LEVEL', 'kind change kept the label');
    st.edit(function (s) { return ed.clear(s, 1, 1); });
    expect(st.get().cells.length === 0, 'clear');
  });

  test('moving swaps with whatever is in the way and never duplicates', function (expect) {
    var st = fresh();
    st.add('m', core.emptySketch('', 2, 2));
    st.edit(function (s) { return ed.put(s, 0, 0, 'knob', 'A'); });
    st.edit(function (s) { return ed.put(s, 1, 0, 'jack', 'B'); });
    st.edit(function (s) { return ed.move(s, 0, 0, 1, 0); });
    expect(st.get().cells.length === 2, 'count ' + st.get().cells.length);
    expect(core.at(st.get(), 1, 0).label === 'A' && core.at(st.get(), 0, 0).label === 'B', 'not swapped');
    st.edit(function (s) { return ed.move(s, 1, 0, 1, 1); });
    expect(core.at(st.get(), 1, 1).label === 'A' && core.at(st.get(), 1, 0) === null, 'move into an empty cell');
  });

  test('a move off the grid does nothing', function (expect) {
    var st = fresh();
    st.add('m', core.emptySketch('', 2, 2));
    st.edit(function (s) { return ed.put(s, 0, 0, 'knob', 'A'); });
    var before = JSON.stringify(st.get());
    st.edit(function (s) { return ed.move(s, 0, 0, 5, 0); });
    expect(JSON.stringify(st.get()) === before, 'sketch changed');
  });

  test('growing the grid is free; shrinking over a component is refused', function (expect) {
    var st = fresh();
    st.add('m', core.emptySketch('', 2, 2));
    st.edit(function (s) { return ed.put(s, 1, 1, 'knob', 'EDGE'); });
    st.edit(function (s) { return ed.resize(s, 4, 4); });
    expect(st.get().columns === 4 && st.get().rows === 4, 'grew');
    expect(core.at(st.get(), 1, 1).label === 'EDGE', 'component moved when the grid grew');
    var before = JSON.stringify(st.get());
    var threw = false;
    try { st.edit(function (s) { return ed.resize(s, 1, 4); }); } catch (e) { threw = /EDGE/.test(e.message); }
    expect(threw, 'shrinking over a component was allowed, or the message did not name it');
    expect(JSON.stringify(st.get()) === before, 'the refused resize still changed the sketch');
    st.edit(function (s) { return ed.clear(s, 1, 1); });
    st.edit(function (s) { return ed.resize(s, 1, 4); });
    expect(st.get().columns === 1, 'shrinking after clearing');
  });

  test('the grid cannot exceed the derived limits', function (expect) {
    var st = fresh();
    st.add('m', core.emptySketch('', core.maxColumns, core.maxRows));
    var threw = false;
    try { st.edit(function (s) { return ed.resize(s, core.maxColumns + 1, core.maxRows); }); } catch (e) { threw = true; }
    expect(threw, 'went past the column limit');
    threw = false;
    try { st.edit(function (s) { return ed.resize(s, core.maxColumns, core.maxRows + 1); }); } catch (e) { threw = true; }
    expect(threw, 'went past the row limit');
  });

  test('undo and redo walk the history and stop at its ends', function (expect) {
    var st = fresh();
    st.add('m', core.emptySketch('', 2, 2));
    expect(!st.canUndo(), 'fresh sketch has history');
    st.edit(function (s) { return ed.put(s, 0, 0, 'knob', 'A'); });
    st.edit(function (s) { return ed.put(s, 1, 1, 'jack', 'B'); });
    expect(st.undo() && st.get().cells.length === 1, 'undo');
    expect(st.undo() && st.get().cells.length === 0, 'undo again');
    expect(!st.undo(), 'undo past the start');
    expect(st.redo() && st.get().cells.length === 1, 'redo');
    st.edit(function (s) { return ed.setName(s, 'Branch'); });
    expect(!st.canRedo(), 'a new edit must clear the redo stack');
  });

  test('an edit that changes nothing leaves no history entry', function (expect) {
    var st = fresh();
    st.add('m', core.emptySketch('', 2, 2));
    st.edit(function (s) { return ed.clear(s, 0, 0); });
    expect(!st.canUndo(), 'no-op recorded');
  });

  test('save and reopen: the sketchbook survives a round trip through storage', function (expect) {
    var storage = Sketchbook.memoryStorage();
    var st = Sketchbook.createStore(core, storage); st.load();
    st.add('alpha', mixer);
    st.add('beta', core.emptySketch('Beta', 2, 3));
    st.select('alpha');
    var exported = st.exportAll();
    var st2 = Sketchbook.createStore(core, storage); st2.load();
    expect(JSON.stringify(st2.ids()) === JSON.stringify(['alpha', 'beta']), 'ids ' + JSON.stringify(st2.ids()));
    expect(st2.current() === 'alpha', 'current ' + st2.current());
    expect(JSON.stringify(st2.exportAll()) === JSON.stringify(exported), 'sketches differ after reopen');
    expect(exported.alpha === core.stringify(mixer), 'export is not the canonical text');
  });

  test('a malformed stored sketch is reported and the others load', function (expect) {
    var storage = Sketchbook.memoryStorage();
    var st = Sketchbook.createStore(core, storage); st.load();
    st.add('good', mixer);
    st.add('bad', core.emptySketch('', 2, 2));
    storage.setItem('sketch:bad', '{"format":"module-sketch","version":2,');
    storage.setItem('sketch:orphan', core.stringify(core.emptySketch('Orphan', 1, 1)));
    var st2 = Sketchbook.createStore(core, storage);
    var problems = st2.load();
    expect(problems.length === 1 && /bad/.test(problems[0]), 'problems ' + JSON.stringify(problems));
    expect(st2.get('good') && !st2.get('bad'), 'good lost or bad loaded');
    expect(st2.get('orphan'), 'an unindexed sketch key was not recovered');
    expect(storage.getItem('sketch:bad') !== null, 'the malformed entry was deleted');
  });

  test('a failed import leaves the current work intact', function (expect) {
    var st = fresh();
    st.add('m', mixer);
    var before = JSON.stringify(st.get());
    expect(!core.parse('{"format":"module-sketch","version":9}').ok, 'accepted a bad import');
    var threw = false;
    try { st.replace('m', { format: 'module-sketch', version: 2 }); } catch (e) { threw = true; }
    expect(threw, 'replace with an invalid sketch did not fail');
    expect(JSON.stringify(st.get()) === before && !st.canUndo(), 'work changed after a failed import');
  });

  test('an external update replaces one sketch and is undoable', function (expect) {
    var st = fresh();
    st.add('m', mixer);
    st.add('other', core.emptySketch('Other', 1, 1));
    var events = [];
    st.subscribe(function (e) { events.push(e.type); });
    st.onStorage('sketch:m', core.stringify(ed.setName(mixer, 'From the agent')));
    expect(st.get('m').name === 'From the agent', 'external update not applied');
    expect(st.get('other').name === 'Other', 'other sketch touched');
    expect(st.undo('m') && st.get('m').name === mixer.name, 'not undoable');
    st.onStorage('sketch:m', 'not json');
    expect(st.get('m').name === mixer.name && events.indexOf('external-invalid') >= 0, 'invalid external text was applied or unreported');
  });

  test('storage failures never break editing', function (expect) {
    var broken = { getItem: function () { throw new Error('blocked'); }, setItem: function () { throw new Error('blocked'); }, removeItem: function () { throw new Error('blocked'); } };
    var st = Sketchbook.createStore(core, broken);
    st.load();
    st.add('m', core.emptySketch('', 2, 2));
    st.edit(function (s) { return ed.put(s, 0, 0, 'knob', 'A'); });
    expect(st.get().cells.length === 1, 'edit lost');
    expect(st.storageErrors().length > 0, 'storage errors not recorded');
  });

  test('ids that name Object.prototype members are ordinary ids', function (expect) {
    expect(core.kind('constructor') === null, 'kind lookup returned an inherited member');
    var st = fresh();
    st.add('constructor', core.emptySketch('', 2, 2));
    expect(st.get('constructor') !== null && st.ids().length === 1, 'a sketch named "constructor" did not round trip');
    expect(st.get('toString') === null, 'an absent sketch resolved to an inherited member');
  });

  var passed = results.filter(function (r) { return r.ok; }).length;
  return { results: results, passed: passed };
});
