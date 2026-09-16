// sketcher.js: the page. All state lives in sketchbook.js and all format
// rules in sketch-core.js; this only draws and forwards input.
(function () {
  'use strict';

  var core = SketchCore.make(SKETCH_CATALOGUE);
  var ed = Sketchbook.edits(core);

  var storage = (function () {
    try { localStorage.setItem('probe', '1'); localStorage.removeItem('probe'); return localStorage; }
    catch (e) { return Sketchbook.memoryStorage(); }
  })();
  var store = Sketchbook.createStore(core, storage);

  var ui = { armed: core.kinds[0].id, sel: null, editingLabel: false, renaming: false, drag: null };

  function $(id) { return document.getElementById(id); }
  function el(tag, attrs, kids) {
    var e = document.createElement(tag);
    if (attrs) Object.keys(attrs).forEach(function (k) {
      if (k === 'class') e.className = attrs[k];
      else if (k === 'text') e.textContent = attrs[k];
      else if (k.indexOf('on') === 0) e.addEventListener(k.slice(2), attrs[k]);
      else e.setAttribute(k, attrs[k]);
    });
    (kids || []).forEach(function (c) { if (c) e.appendChild(typeof c === 'string' ? document.createTextNode(c) : c); });
    return e;
  }
  function say(m) { $('status').textContent = m || ''; }

  // A simple line drawing per kind. Conceptual, like the sketch itself.
  var NS = 'http://www.w3.org/2000/svg';
  function icon(kindId) {
    var s = document.createElementNS(NS, 'svg');
    s.setAttribute('viewBox', '0 0 24 24');
    s.setAttribute('aria-hidden', 'true');
    function add(tag, attrs) {
      var n = document.createElementNS(NS, tag);
      Object.keys(attrs).forEach(function (k) { n.setAttribute(k, attrs[k]); });
      n.setAttribute('fill', attrs.fill || 'none');
      n.setAttribute('stroke', attrs.stroke || 'currentColor');
      n.setAttribute('stroke-width', attrs['stroke-width'] || '1.5');
      n.setAttribute('stroke-linecap', 'round');
      s.appendChild(n);
      return n;
    }
    if (kindId === 'knob') {
      add('circle', { cx: 12, cy: 12, r: 8 });
      add('line', { x1: 12, y1: 12, x2: 12, y2: 5 });
    } else if (kindId === 'jack') {
      add('circle', { cx: 12, cy: 12, r: 8 });
      add('circle', { cx: 12, cy: 12, r: 3 });
    } else if (kindId === 'switch') {
      add('line', { x1: 6, y1: 18, x2: 18, y2: 18 });
      add('line', { x1: 12, y1: 18, x2: 16, y2: 6, 'stroke-width': '2.5' });
    } else if (kindId === 'button') {
      // a square cap, so it does not read as another round hole
      add('rect', { x: 5, y: 5, width: 14, height: 14, rx: 3 });
      add('line', { x1: 9, y1: 12, x2: 15, y2: 12, 'stroke-width': '2.5' });
    } else if (kindId === 'led') {
      add('circle', { cx: 12, cy: 13, r: 4, fill: 'currentColor' });
      add('line', { x1: 12, y1: 5, x2: 12, y2: 2 });
      add('line', { x1: 5, y1: 8, x2: 3, y2: 6 });
      add('line', { x1: 19, y1: 8, x2: 21, y2: 6 });
    }
    return s;
  }

  // Rendering ----------------------------------------------------------------

  function render() {
    var s = store.get();
    renderList();
    if (!s) { $('grid').textContent = ''; return; }
    if (document.activeElement !== $('name')) $('name').value = s.name;
    renderPalette();
    renderGrid(s);
    renderSize(s);
    $('undo').disabled = !store.canUndo();
    $('redo').disabled = !store.canRedo();
    $('handback').classList.toggle('hidden', typeof window.agentDone !== 'function');
  }

  function renderPalette() {
    var p = $('palette');
    p.textContent = '';
    core.kinds.forEach(function (k) {
      var b = el('button', {
        type: 'button', 'aria-pressed': ui.armed === k.id ? 'true' : 'false',
        title: k.note || k.label,
        onclick: function () { ui.armed = k.id; say(k.note || ''); render(); }
      }, [icon(k.id), el('span', { text: k.label })]);
      p.appendChild(b);
    });
  }

  function renderGrid(s) {
    var g = $('grid');
    g.textContent = '';
    g.style.gridTemplateColumns = 'repeat(' + s.columns + ', auto)';
    for (var row = 0; row < s.rows; row++) {
      for (var col = 0; col < s.columns; col++) {
        g.appendChild(cellNode(s, col, row));
      }
    }
  }

  function cellNode(s, col, row) {
    var c = core.at(s, col, row);
    var selected = ui.sel && ui.sel.col === col && ui.sel.row === row;
    var node = el('div', {
      class: 'cell' + (c ? ' filled' : '') + (selected ? ' selected' : ''),
      role: 'gridcell', tabindex: '0',
      'data-col': col, 'data-row': row,
      'aria-label': (c ? (c.label || core.kind(c.kind).label) : 'empty') + ' at column ' + (col + 1) + ', row ' + (row + 1)
    });
    if (c) {
      node.appendChild(icon(c.kind));
      if (selected && ui.editingLabel) {
        var input = el('input', {
          type: 'text', value: c.label, maxlength: '24', 'aria-label': 'Label',
          onclick: function (e) { e.stopPropagation(); },
          onkeydown: function (e) {
            if (e.key === 'Enter') { e.preventDefault(); commitLabel(col, row, this.value); }
            if (e.key === 'Escape') { e.preventDefault(); ui.editingLabel = false; render(); }
          },
          onblur: function () { if (ui.editingLabel) commitLabel(col, row, this.value); }
        });
        node.appendChild(input);
        setTimeout(function () { input.focus(); input.select(); }, 0);
      } else {
        node.appendChild(el('span', { class: 'tag', text: c.label || '' }));
      }
      node.draggable = true;
      node.addEventListener('dragstart', function (e) {
        ui.drag = { col: col, row: row };
        node.classList.add('dragging');
        try { e.dataTransfer.setData('text/plain', col + ',' + row); e.dataTransfer.effectAllowed = 'move'; } catch (err) { /* older browsers */ }
      });
      node.addEventListener('dragend', function () { ui.drag = null; render(); });
    }
    node.addEventListener('dragover', function (e) { if (ui.drag) { e.preventDefault(); node.classList.add('dropzone'); } });
    node.addEventListener('dragleave', function () { node.classList.remove('dropzone'); });
    node.addEventListener('drop', function (e) {
      e.preventDefault();
      node.classList.remove('dropzone');
      var from = ui.drag;
      ui.drag = null;
      if (!from || (from.col === col && from.row === row)) { render(); return; }
      apply(function (sk) { return ed.move(sk, from.col, from.row, col, row); });
      ui.sel = { col: col, row: row };
      render();
    });
    node.addEventListener('click', function () { onCellClick(col, row); });
    node.addEventListener('keydown', function (e) { onCellKey(e, col, row); });
    return node;
  }

  function renderSize(s) {
    $('col-count').textContent = s.columns;
    $('row-count').textContent = s.rows;
    $('col-less').disabled = s.columns <= 1;
    $('col-more').disabled = s.columns >= core.maxColumns;
    $('row-less').disabled = s.rows <= 1;
    $('row-more').disabled = s.rows >= core.maxRows;
    var hp = core.impliedWidth(s);
    var n = s.cells.length;
    $('note').textContent = s.columns + ' x ' + s.rows + ' grid, ' + n + ' component' + (n === 1 ? '' : 's')
      + (hp ? ' — needs a panel of at least ' + hp + ' HP' : '');
    $('limits').textContent = core.why;
  }

  function renderList() {
    var ul = $('list');
    ul.textContent = '';
    store.ids().forEach(function (id) {
      var s = store.get(id);
      var li = el('li', {
        'aria-current': id === store.current() ? 'true' : 'false',
        onclick: function () { store.select(id); ui.sel = null; ui.editingLabel = false; ui.renaming = false; render(); }
      });
      if (ui.renaming && id === store.current()) {
        var input = el('input', {
          type: 'text', value: id, 'aria-label': 'Rename module',
          onclick: function (e) { e.stopPropagation(); },
          onkeydown: function (e) {
            if (e.key === 'Enter') { e.preventDefault(); finishRename(input.value); }
            if (e.key === 'Escape') { e.preventDefault(); ui.renaming = false; render(); }
          },
          onblur: function () { if (ui.renaming) finishRename(input.value); }
        });
        li.appendChild(input);
        setTimeout(function () { input.focus(); input.select(); }, 0);
      } else {
        li.appendChild(el('span', { text: id }));
        li.appendChild(el('span', { class: 'size', text: s.columns + 'x' + s.rows }));
        li.addEventListener('dblclick', function () { ui.renaming = true; render(); });
      }
      ul.appendChild(li);
    });
    $('del').disabled = !store.current();
    $('dup').disabled = !store.current();
  }

  // Editing ------------------------------------------------------------------

  function apply(fn) {
    try { store.edit(fn); say(''); }
    catch (e) { say(e.message); }
  }

  function onCellClick(col, row) {
    var s = store.get();
    var c = core.at(s, col, row);
    if (c && ui.sel && ui.sel.col === col && ui.sel.row === row) {
      ui.editingLabel = true;              // second click on the same cell renames it
    } else if (c) {
      ui.sel = { col: col, row: row };
      ui.editingLabel = false;
    } else {
      apply(function (sk) { return ed.put(sk, col, row, ui.armed, ''); });
      ui.sel = { col: col, row: row };
      ui.editingLabel = true;              // a new component asks for its name
    }
    render();
  }

  function commitLabel(col, row, value) {
    ui.editingLabel = false;
    apply(function (sk) { return ed.setLabel(sk, col, row, value.trim()); });
    render();
    focusCell(col, row);
  }

  function onCellKey(e, col, row) {
    var s = store.get();
    if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); onCellClick(col, row); return; }
    if (e.key === 'Backspace' || e.key === 'Delete') {
      e.preventDefault();
      apply(function (sk) { return ed.clear(sk, col, row); });
      ui.sel = null; render(); focusCell(col, row);
      return;
    }
    var d = { ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1] }[e.key];
    if (!d) return;
    e.preventDefault();
    var nc = col + d[0], nr = row + d[1];
    if (nc < 0 || nc >= s.columns || nr < 0 || nr >= s.rows) return;
    if (e.shiftKey && core.at(s, col, row)) {
      apply(function (sk) { return ed.move(sk, col, row, nc, nr); });
      ui.sel = { col: nc, row: nr };
      render();
    }
    focusCell(nc, nr);
  }

  function focusCell(col, row) {
    var n = $('grid').querySelector('[data-col="' + col + '"][data-row="' + row + '"]');
    if (n) n.focus();
  }

  function resize(dc, dr) {
    var s = store.get();
    if (!s) return;
    apply(function (sk) { return ed.resize(sk, sk.columns + dc, sk.rows + dr); });
    ui.sel = null;
    render();
  }

  $('col-less').onclick = function () { resize(-1, 0); };
  $('col-more').onclick = function () { resize(1, 0); };
  $('row-less').onclick = function () { resize(0, -1); };
  $('row-more').onclick = function () { resize(0, 1); };
  $('name').addEventListener('change', function () {
    var v = this.value;
    apply(function (s) { return ed.setName(s, v); });
  });
  $('undo').onclick = function () { store.undo(); ui.sel = null; render(); };
  $('redo').onclick = function () { store.redo(); ui.sel = null; render(); };

  // Modules --------------------------------------------------------------------

  function freshId(base) {
    var stem = (base || 'module').replace(/[^A-Za-z0-9_-]/g, '-').slice(0, 30) || 'module';
    if (store.ids().indexOf(stem) < 0) return stem;
    for (var n = 2; ; n++) { if (store.ids().indexOf(stem + '-' + n) < 0) return stem + '-' + n; }
  }
  $('new').onclick = function () {
    var id = freshId('module');
    store.add(id, core.emptySketch('', 2, 4));
    ui.sel = null; ui.editingLabel = false;
    say('Started ' + id + '. Double-click its name in the list to rename it.');
    render();
  };
  $('dup').onclick = function () {
    var s = store.get();
    if (!s) return;
    var id = freshId(store.current());
    store.add(id, s);
    say('Copied to ' + id + '.');
    render();
  };
  $('del').onclick = function () {
    var id = store.current();
    if (!id) return;
    var text = core.stringify(store.get(id));
    store.remove(id);
    ui.sel = null;
    $('paste').value = text;
    say('Deleted ' + id + '. Its JSON is in the box below if that was a mistake.');
    render();
  };
  function finishRename(v) {
    var id = store.current();
    ui.renaming = false;
    if (v && v !== id) { try { store.rename(id, v); } catch (e) { say(e.message); } }
    render();
  }

  // JSON ------------------------------------------------------------------------

  $('copy').onclick = function () {
    var s = store.get();
    if (!s) return;
    var text = core.stringify(s);
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(function () { say('Copied.'); }, function () { fallback(text); });
    } else fallback(text);
    function fallback(t) { $('paste').value = t; $('paste').focus(); $('paste').select(); say('Copy it from the box below.'); }
  };
  $('download').onclick = function () {
    var s = store.get();
    if (!s) return;
    var a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([core.stringify(s)], { type: 'application/json' }));
    a.download = store.current() + '.json';
    document.body.appendChild(a); a.click(); document.body.removeChild(a);
    setTimeout(function () { URL.revokeObjectURL(a.href); }, 1000);
    say('Downloaded ' + a.download);
  };
  $('open').addEventListener('change', function () {
    var f = this.files && this.files[0];
    this.value = '';
    if (!f) { say('No file chosen; nothing changed.'); return; }
    var r = new FileReader();
    r.onerror = function () { say('Could not read ' + f.name + '; nothing changed.'); };
    r.onload = function () {
      var id = f.name.replace(/\.json$/i, '').replace(/[^A-Za-z0-9_-]/g, '-').slice(0, 40) || 'imported';
      importText(String(r.result), store.ids().indexOf(id) >= 0 ? id : null, id);
    };
    r.readAsText(f);
  });
  $('import-replace').onclick = function () { importText($('paste').value, store.current(), null); };
  $('import-add').onclick = function () { importText($('paste').value, null, null); };

  function importText(text, replaceId, suggested) {
    var r = core.parse(text);
    if (!r.ok) { say('Not imported. ' + r.errors.join('; ')); return; }
    var id = replaceId || freshId(suggested || 'module');
    try { store.replace(id, r.sketch); } catch (e) { say('Not imported: ' + e.message); return; }
    store.select(id);
    ui.sel = null;
    say((replaceId ? 'Replaced ' : 'Added ') + id + '. Undo restores the previous version.');
    render();
  }

  $('handback').onclick = function () {
    if (typeof window.agentDone !== 'function') return;
    window.agentDone({ format: 'module-sketchbook', version: 2, current: store.current(), sketches: store.exportAll() });
    say('Sent. You can keep editing; everything is saved as you go.');
  };

  // Keyboard and outside changes --------------------------------------------------

  document.addEventListener('keydown', function (e) {
    var t = (e.target && e.target.tagName || '').toLowerCase();
    if (t === 'input' || t === 'textarea') return;
    var mod = e.ctrlKey || e.metaKey;
    if (mod && (e.key === 'z' || e.key === 'Z') && !e.shiftKey) { e.preventDefault(); store.undo(); ui.sel = null; render(); }
    else if (mod && ((e.key === 'y' || e.key === 'Y') || e.shiftKey && (e.key === 'z' || e.key === 'Z'))) { e.preventDefault(); store.redo(); ui.sel = null; render(); }
    else if (e.key === 'Escape') { ui.sel = null; ui.editingLabel = false; render(); }
  });
  store.subscribe(function (ev) {
    if (ev.type === 'external') say('"' + ev.id + '" was changed from outside. Undo restores the previous version.');
    if (ev.type === 'external-invalid') say('An outside change to "' + ev.id + '" was not a valid sketch and was ignored.');
  });
  window.addEventListener('storage', function (e) {
    if (e.key === null) return;
    store.onStorage(e.key, e.newValue);
    render();
  });

  // Start -----------------------------------------------------------------------

  var problems = store.load();
  if (!store.ids().length) {
    store.add('module-1', core.emptySketch('', 2, 4));
    say('Pick a part on the right, then click a cell.');
  } else if (problems.length) {
    say(problems.join(' | '));
  }
  if (store.storageErrors().length) say('This browser is not storing anything; keep a copy of the JSON.');
  render();

  window.sketcher = { core: core, store: store, edits: ed, ui: ui, render: render };
})();
