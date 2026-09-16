// sketcher.js: the editor's DOM and SVG. All geometry and checks come from
// sketch-core.js, all state from sketchbook.js; this file only draws and
// forwards input. It runs from file:// and, bundled, inside fast-ui, where
// localStorage is the server-backed shim and window.agentDone exists.
(function () {
  'use strict';

  var core = SketchCore.make(PCBGEN_CATALOGUE);
  var ed = Sketchbook.edits(core);

  var storage = (function () {
    try { localStorage.setItem('sketchbook.probe', '1'); localStorage.removeItem('sketchbook.probe'); return localStorage; }
    catch (e) { return Sketchbook.memoryStorage(); }
  })();
  var store = Sketchbook.createStore(core, storage);

  var ui = {
    selected: null, armed: null, rear: false, cells: true, courtyards: true, access: true, labels: true,
    drag: null, hotCell: null, confirmDelete: false, renaming: false, message: ''
  };

  function $(id) { return document.getElementById(id); }
  function el(tag, attrs, children) {
    var e = document.createElement(tag);
    if (attrs) Object.keys(attrs).forEach(function (k) {
      if (k === 'class') e.className = attrs[k];
      else if (k === 'text') e.textContent = attrs[k];
      else if (k.indexOf('on') === 0) e.addEventListener(k.slice(2), attrs[k]);
      else e.setAttribute(k, attrs[k]);
    });
    (children || []).forEach(function (c) { if (c) e.appendChild(typeof c === 'string' ? document.createTextNode(c) : c); });
    return e;
  }
  var SVG_NS = 'http://www.w3.org/2000/svg';
  function svg(tag, attrs, children) {
    var e = document.createElementNS(SVG_NS, tag);
    if (attrs) Object.keys(attrs).forEach(function (k) {
      if (k === 'class') e.setAttribute('class', attrs[k]);
      else if (k === 'text') e.textContent = attrs[k];
      else if (k.indexOf('on') === 0) e.addEventListener(k.slice(2), attrs[k]);
      else e.setAttribute(k, attrs[k]);
    });
    (children || []).forEach(function (c) { if (c) e.appendChild(c); });
    return e;
  }
  function fmt(n) { return Math.round(n * 100) / 100; }
  function say(msg) { ui.message = msg; renderTopbar(); }

  // Store wiring --------------------------------------------------------------

  function edit(fn, label) {
    try {
      store.edit(fn);
      if (label) say(label);
    } catch (e) { say('Not applied: ' + e.message); }
    render();
  }
  function current() { return store.get(); }

  store.subscribe(function (ev) {
    if (ev.type === 'external') say('Sketch "' + ev.id + '" was updated from outside (undo restores the previous version).');
    if (ev.type === 'external-invalid') say('An outside update to "' + ev.id + '" was not a valid sketch and was ignored: ' + ev.errors[0]);
    if (ev.type === 'remove' && ui.selected) ui.selected = null;
  });
  window.addEventListener('storage', function (e) {
    if (e.key === null) return;
    store.onStorage(e.key, e.newValue);
    render();
  });

  // Rendering -----------------------------------------------------------------

  function render() {
    var s = current();
    if (s && ui.selected && !ed.get(s, ui.selected)) ui.selected = null;
    renderSketchList();
    renderModuleForm(s);
    renderGridForm(s);
    renderPalette();
    renderCanvas(s);
    renderControlForm(s);
    renderGroups(s);
    renderFindings(s);
    renderTopbar();
  }

  function renderTopbar() {
    $('undo').disabled = !current() || !store.canUndo();
    $('redo').disabled = !current() || !store.canRedo();
    var errs = store.storageErrors();
    $('status').textContent = (ui.message || '') + (errs.length ? '  (browser storage unavailable: work is kept in memory only)' : '');
    $('handback').classList.toggle('hidden', typeof window.agentDone !== 'function');
  }

  function renderSketchList() {
    var ul = $('sketch-list');
    ul.textContent = '';
    store.ids().forEach(function (id) {
      var s = store.get(id);
      var conflicts = core.check(s).filter(function (f) { return f.severity === 'conflict'; }).length;
      var li = el('li', { class: id === store.current() ? 'current' : '', role: 'button', tabindex: '0',
                          onclick: function () { store.select(id); ui.selected = null; ui.confirmDelete = false; ui.renaming = false; render(); },
                          onkeydown: function (e) { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); this.click(); } } });
      if (ui.renaming && id === store.current()) {
        var input = el('input', { type: 'text', value: id, pattern: '[A-Za-z0-9_-]{1,40}', 'aria-label': 'New sketch id' });
        input.addEventListener('click', function (e) { e.stopPropagation(); });
        input.addEventListener('keydown', function (e) {
          if (e.key === 'Enter') { e.preventDefault(); finishRename(input.value); }
          if (e.key === 'Escape') { e.preventDefault(); ui.renaming = false; render(); }
        });
        input.addEventListener('blur', function () { if (ui.renaming) finishRename(input.value); });
        li.appendChild(input);
        setTimeout(function () { input.focus(); input.select(); }, 0);
      } else {
        li.appendChild(el('span', { text: id }));
        if (conflicts) li.appendChild(el('span', { class: 'badge', text: String(conflicts), title: conflicts + ' conflicts' }));
        li.appendChild(el('span', { class: 'meta', text: s.hp + 'HP · ' + s.controls.length }));
      }
      ul.appendChild(li);
    });
    if (!store.ids().length) ul.appendChild(el('li', { class: 'hint', text: 'No sketches yet. New module starts one.' }));
    $('rename-sketch').disabled = !store.current();
    $('delete-sketch').disabled = !store.current();
    $('delete-sketch').textContent = ui.confirmDelete ? 'Really delete "' + store.current() + '"' : 'Delete';
  }
  function finishRename(newId) {
    var id = store.current();
    ui.renaming = false;
    if (newId && newId !== id) {
      try { store.rename(id, newId); say('Renamed to ' + newId); } catch (e) { say('Not renamed: ' + e.message); }
    }
    render();
  }

  function fillSelect(sel, options, value) {
    sel.textContent = '';
    options.forEach(function (o) { sel.appendChild(el('option', { value: o.value, text: o.text })); });
    sel.value = value;
  }

  function renderModuleForm(s) {
    var disabled = !s;
    ['sketch-name', 'sketch-hp', 'sketch-status', 'sketch-notes'].forEach(function (id) { $(id).disabled = disabled; });
    if (!s) return;
    if (document.activeElement !== $('sketch-name')) $('sketch-name').value = s.name;
    var form = core.form;
    fillSelect($('sketch-hp'), PCBGEN_CATALOGUE.skeletons.map(function (sk) {
      var inPolicy = sk.hp >= form.policyHP.min && sk.hp <= form.policyHP.max;
      return { value: String(sk.hp), text: sk.hp + ' HP  (' + sk.panelWidth + ' mm)' + (inPolicy ? '' : '  outside policy') };
    }), String(s.hp));
    $('sketch-status').value = s.status;
    if (document.activeElement !== $('sketch-notes')) $('sketch-notes').value = (s.notes || []).join('\n');
  }

  function renderGridForm(s) {
    var disabled = !s;
    ['grid-profile', 'grid-ox', 'grid-oy', 'grid-px', 'grid-py'].forEach(function (id) { $(id).disabled = disabled; });
    if (!s) return;
    var opts = PCBGEN_CATALOGUE.profiles.map(function (p) { return { value: p.id, text: p.id + ' (' + p.pitch.x + ' × ' + p.pitch.y + ' mm, ' + p.status + ')' }; });
    opts.push({ value: '', text: 'custom (no profile)' });
    fillSelect($('grid-profile'), opts, s.grid.profile || '');
    var prof = s.grid.profile ? core.profile(s.grid.profile) : null;
    $('grid-status').textContent = prof ? prof.status : 'custom';
    [['grid-ox', s.grid.origin.x], ['grid-oy', s.grid.origin.y], ['grid-px', s.grid.pitch.x], ['grid-py', s.grid.pitch.y]].forEach(function (kv) {
      if (document.activeElement !== $(kv[0])) $(kv[0]).value = kv[1];
    });
    var ext = core.gridExtent(s);
    $('grid-hint').textContent = ext.cols + ' columns × ' + ext.rows + ' rows have their centres on this panel. ' + (prof ? prof.note : 'A custom grid records no profile; re-laying it later is by hand.');
  }

  function glyph(hw) {
    var g = svg('svg', { viewBox: '-10 -10 20 20', 'aria-hidden': 'true' });
    var body = hw.frontBody.shape === 'circle' ? svg('circle', { r: hw.frontBody.d / 2 * 1.4, class: 'body' }) : svg('rect', { x: -hw.frontBody.w / 2, y: -hw.frontBody.h / 2, width: hw.frontBody.w, height: hw.frontBody.h, class: 'body' });
    body.setAttribute('fill', 'none'); body.setAttribute('stroke', 'currentColor'); body.setAttribute('stroke-width', '1');
    g.appendChild(body);
    var mark;
    if (hw.role === 'pot') mark = svg('line', { x1: 0, y1: 0, x2: 0, y2: -7, stroke: 'currentColor', 'stroke-width': '1.5' });
    else if (hw.role === 'switch') mark = svg('line', { x1: 0, y1: 0, x2: 0, y2: -8, stroke: 'currentColor', 'stroke-width': '2.5', 'stroke-linecap': 'round' });
    else if (hw.role === 'led') mark = svg('circle', { r: 2.2, fill: 'currentColor' });
    else mark = svg('circle', { r: 2.5, fill: 'none', stroke: 'currentColor', 'stroke-width': '1' });
    g.appendChild(mark);
    return g;
  }

  function renderPalette() {
    var pal = $('palette');
    pal.textContent = '';
    PCBGEN_CATALOGUE.hardware.forEach(function (hw) {
      var b = el('button', { type: 'button', class: ui.armed === hw.id ? 'armed' : '', title: hw.name + '\n' + hw.notes,
                              'aria-pressed': ui.armed === hw.id ? 'true' : 'false',
                              onclick: function () { ui.armed = ui.armed === hw.id ? null : hw.id; say(ui.armed ? 'Click a cell to place ' + hw.id + '. Esc cancels.' : ''); render(); } });
      b.appendChild(glyph(hw));
      b.appendChild(el('span', { text: hw.id }));
      pal.appendChild(b);
    });
  }

  // The panel. Front view is panel coordinates directly; rear view mirrors x
  // about the panel's centre line, so what is on the left of the face is on
  // the right when you look at the back.
  function renderCanvas(s) {
    var c = $('canvas');
    c.textContent = '';
    if (!s) { c.removeAttribute('viewBox'); return; }
    var sk = core.skeleton(s.hp);
    var W = sk.panelWidth, H = core.form.panelHeight, m = 8;
    c.setAttribute('viewBox', (-m) + ' ' + (-m) + ' ' + (W + 2 * m) + ' ' + (H + 2 * m));
    var root = svg('g', { transform: ui.rear ? 'translate(' + W + ',0) scale(-1,1)' : '' });
    c.appendChild(root);

    // background click clears the selection or places an armed part
    root.appendChild(svg('rect', { x: -m, y: -m, width: W + 2 * m, height: H + 2 * m, fill: 'transparent',
                                   onpointerdown: function () { if (!ui.armed) { ui.selected = null; render(); } } }));
    root.appendChild(svg('rect', { class: 'panel-face', x: 0, y: 0, width: W, height: H, rx: 1, ry: 1 }));
    var zone = core.boardZone(sk);
    root.appendChild(svg('rect', { class: 'pcb-zone', x: zone.x1, y: zone.y1, width: zone.x2 - zone.x1, height: zone.y2 - zone.y1 }));
    core.railHoles(sk).forEach(function (h) {
      root.appendChild(svg('circle', { class: 'rail-keepout', cx: h.x, cy: h.y, r: core.form.railKeepoutRadius }));
      root.appendChild(svg('circle', { class: 'rail-hole', cx: h.x, cy: h.y, r: core.form.railHoleDiameter / 2 }));
    });

    // cells
    var g = s.grid, ext = core.gridExtent(s);
    if (ui.cells || ui.armed) {
      for (var col = 0; col < ext.cols; col++) for (var row = 0; row < ext.rows; row++) {
        (function (col, row) {
          var cx = g.origin.x + col * g.pitch.x, cy = g.origin.y + row * g.pitch.y;
          var hot = ui.hotCell && ui.hotCell.col === col && ui.hotCell.row === row;
          root.appendChild(svg('rect', { class: 'cell' + (hot ? ' hot' : ''), x: cx - g.pitch.x / 2, y: cy - g.pitch.y / 2, width: g.pitch.x, height: g.pitch.y,
                                         'data-col': col, 'data-row': row,
                                         onpointerdown: function (e) { if (ui.armed) { e.stopPropagation(); placeAt(col, row); } else { ui.selected = null; render(); } } }));
        })(col, row);
      }
    }

    // controls
    var findings = core.check(s);
    var severity = {};
    findings.forEach(function (f) { f.controls.forEach(function (id) { if (f.severity === 'conflict') severity[id] = 'conflict'; else if (f.severity === 'warning' && severity[id] !== 'conflict') severity[id] = 'warning'; }); });
    core.place(s).forEach(function (p) {
      var hw = p.hardware, cx = p.centre.x, cy = p.centre.y;
      var cls = 'ctl' + (ui.selected === p.id ? ' selected' : '') + (severity[p.id] ? ' ' + severity[p.id] : '');
      var grp = svg('g', { class: cls, 'data-id': p.id, tabindex: '0', role: 'button',
                           'aria-label': p.id + ' (' + hw.id + ')' + (p.control.label ? ': ' + p.control.label : '') });
      if (ui.courtyards) root.appendChild(svg('rect', { class: 'court', x: p.courtyard.x1, y: p.courtyard.y1, width: p.courtyard.x2 - p.courtyard.x1, height: p.courtyard.y2 - p.courtyard.y1, 'pointer-events': 'none' }));
      if (ui.access && p.frontAccess) grp.appendChild(shapeEl(p.frontAccess, cx, cy, 'access'));
      grp.appendChild(shapeEl(p.frontBody, cx, cy, 'body'));
      grp.appendChild(svg('circle', { class: 'hole', cx: cx, cy: cy, r: hw.hole / 2 }));
      var rot = p.rotation;
      if (hw.role === 'pot') grp.appendChild(svg('line', { class: 'pointer', x1: cx, y1: cy, x2: cx, y2: cy - hw.frontBody.d / 2 + 0.8 }));
      if (hw.role === 'switch') {
        var dir = core.rotatePt(rot, { x: 0, y: -1 });
        grp.appendChild(svg('line', { class: 'bat', x1: cx, y1: cy, x2: cx + dir.x * 4.5, y2: cy + dir.y * 4.5 }));
      }
      if (hw.role === 'led') grp.appendChild(svg('circle', { class: 'led', cx: cx, cy: cy, r: 1.2 }));
      if (hw.role === 'jack') grp.appendChild(svg('circle', { class: 'hole', cx: cx, cy: cy, r: 1.8, fill: 'none' }));
      if (ui.labels) {
        var below = cy + extentBelow(p) + 2.6;
        if (p.control.label) grp.appendChild(textEl(p.control.label, cx, below, 'label'));
        grp.appendChild(textEl(p.id, cx, below + (p.control.label ? 2.2 : 0), 'idtext'));
      }
      grp.addEventListener('pointerdown', function (e) { startDrag(e, p); });
      grp.addEventListener('keydown', function (e) { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); ui.selected = p.id; render(); focusControl(p.id); } });
      grp.addEventListener('focus', function () { if (ui.selected !== p.id) { ui.selected = p.id; render(); focusControl(p.id); } });
      root.appendChild(grp);
    });

    // scale and view tag (mirrored back so they read normally in rear view)
    var tag = textEl(ui.rear ? 'REAR VIEW (behind the panel)' : 'FRONT VIEW', W / 2, -3.5, 'view-tag');
    root.appendChild(tag);
    var sc = svg('g', { class: 'scale' });
    sc.appendChild(svg('line', { x1: 0, y1: H + 4, x2: 10, y2: H + 4 }));
    sc.appendChild(svg('line', { x1: 0, y1: H + 3, x2: 0, y2: H + 5 }));
    sc.appendChild(svg('line', { x1: 10, y1: H + 3, x2: 10, y2: H + 5 }));
    sc.appendChild(textEl('10 mm', 5, H + 7, ''));
    sc.appendChild(textEl(W + ' × ' + H + ' mm, ' + s.hp + ' HP', W / 2, H + 7, ''));
    root.appendChild(sc);
  }
  function extentBelow(p) {
    var b = p.frontBody;
    return b.shape === 'circle' ? b.d / 2 : b.h / 2;
  }
  function shapeEl(sh, cx, cy, cls) {
    if (sh.shape === 'circle') return svg('circle', { class: cls, cx: cx, cy: cy, r: sh.d / 2 });
    return svg('rect', { class: cls, x: cx - sh.w / 2, y: cy - sh.h / 2, width: sh.w, height: sh.h });
  }
  function textEl(txt, x, y, cls) {
    var t = svg('text', { class: cls, x: x, y: y, text: txt, 'text-anchor': 'middle' });
    if (ui.rear) t.setAttribute('transform', 'translate(' + (2 * x) + ',0) scale(-1,1)');
    return t;
  }
  function focusControl(id) {
    var node = $('canvas').querySelector('[data-id="' + id + '"]');
    if (node && document.activeElement !== node) node.focus({ preventScroll: true });
  }

  function svgPoint(e) {
    var c = $('canvas');
    var pt = c.createSVGPoint(); pt.x = e.clientX; pt.y = e.clientY;
    var m = c.getScreenCTM();
    if (!m) return { x: 0, y: 0 };
    var p = pt.matrixTransform(m.inverse());
    if (ui.rear) p.x = core.skeleton(current().hp).panelWidth - p.x;
    return { x: p.x, y: p.y };
  }
  function placeAt(col, row) {
    var hw = core.hardware(ui.armed);
    var newId = null;
    edit(function (s) {
      var t = ed.addControl(s, hw.id, { col: col, row: row }, { rotation: hw.defaultRotation || 0 });
      newId = t.controls[t.controls.length - 1].id;
      return t;
    }, 'Placed ' + hw.id + ' at (' + col + ', ' + row + ')');
    ui.armed = null;
    ui.selected = newId;
    render();
  }

  // Dragging: pointer capture, cell snapping on release, nothing committed
  // until the pointer is up. Touch and mouse both arrive as pointer events.
  function startDrag(e, p) {
    if (ui.armed) return;
    e.stopPropagation();
    e.preventDefault();
    ui.selected = p.id;
    var start = svgPoint(e);
    var s = current();
    ui.drag = { id: p.id, start: start, cell: { col: p.control.cell.col, row: p.control.cell.row }, moved: false, node: null, dcol: 0, drow: 0 };
    // Selecting redraws the panel, which replaces every node, so the capture
    // and the listeners have to go on the node that survives that redraw.
    // Capturing the old one lost the drag as soon as the pointer left it.
    render();
    var node = $('canvas').querySelector('[data-id="' + p.id + '"]');
    if (!node) { ui.drag = null; return; }
    ui.drag.node = node;
    node.classList.add('dragging');
    try { node.setPointerCapture(e.pointerId); } catch (err) { /* capture is an optimisation, not a requirement */ }
    var onMove = function (ev) {
      var q = svgPoint(ev);
      var dcol = Math.round((q.x - start.x) / s.grid.pitch.x), drow = Math.round((q.y - start.y) / s.grid.pitch.y);
      if (dcol !== 0 || drow !== 0) ui.drag.moved = true;
      ui.drag.dcol = dcol; ui.drag.drow = drow;
      node.setAttribute('transform', 'translate(' + (dcol * s.grid.pitch.x) + ',' + (drow * s.grid.pitch.y) + ')');
    };
    var onUp = function () {
      node.removeEventListener('pointermove', onMove);
      node.removeEventListener('pointerup', onUp);
      node.removeEventListener('pointercancel', onUp);
      var d = ui.drag; ui.drag = null;
      if (d && d.moved) {
        edit(function (sk) { return ed.moveControl(sk, d.id, { col: d.cell.col + d.dcol, row: d.cell.row + d.drow }); }, 'Moved ' + d.id);
      } else render();
      focusControl(p.id);
    };
    node.addEventListener('pointermove', onMove);
    node.addEventListener('pointerup', onUp);
    node.addEventListener('pointercancel', onUp);
  }

  function renderControlForm(s) {
    var c = s && ui.selected ? ed.get(s, ui.selected) : null;
    $('control-none').classList.toggle('hidden', !!c);
    $('control-form').classList.toggle('hidden', !c);
    if (!c) return;
    var hw = core.hardware(c.hardware);
    var active = document.activeElement;
    function set(id, v) { if (active !== $(id)) $(id).value = v; }
    set('ctl-id', c.id); set('ctl-label', c.label); set('ctl-group', c.group || '');
    fillSelect($('ctl-hardware'), PCBGEN_CATALOGUE.hardware.map(function (h) { return { value: h.id, text: h.id }; }), c.hardware);
    set('ctl-col', c.cell.col); set('ctl-row', c.cell.row); set('ctl-cols', c.span.cols); set('ctl-rows', c.span.rows);
    set('ctl-dx', c.offset.x); set('ctl-dy', c.offset.y);
    fillSelect($('ctl-rot'), hw.rotations.map(function (r) { return { value: String(r), text: r + '°' }; }), String(c.rotation));
    var dl = $('group-list'); dl.textContent = '';
    (s.groups || []).forEach(function (g) { dl.appendChild(el('option', { value: g.id })); });
    var p = core.placeControl(core.skeleton(s.hp), s.grid, c);
    $('ctl-geometry').textContent = 'Centre on panel (' + fmt(p.centre.x) + ', ' + fmt(p.centre.y) + ') mm; on the board (' + fmt(p.board.x) + ', ' + fmt(p.board.y) + '); footprint origin (' + fmt(p.footprintOrigin.x) + ', ' + fmt(p.footprintOrigin.y) + ') at ' + p.rotation + '°. Hole Ø' + hw.hole + ' mm.';
    $('ctl-hardware-note').textContent = hw.name + '. Status: ' + hw.status + '; front envelope ' + hw.frontEvidence + '. ' + hw.notes;
  }

  function renderGroups(s) {
    var ul = $('group-ul');
    ul.textContent = '';
    if (!s) return;
    (s.groups || []).forEach(function (g) {
      var n = s.controls.filter(function (c) { return c.group === g.id; }).length;
      ul.appendChild(el('li', {}, [
        el('span', { text: g.id + (g.label ? ' — ' + g.label : '') + ' (' + n + ')' }),
        el('button', { type: 'button', text: 'remove', title: 'Remove the group; its controls stay', onclick: function () { edit(function (sk) { return ed.removeGroup(sk, g.id); }, 'Removed group ' + g.id); } })
      ]));
    });
    if (!(s.groups || []).length) ul.appendChild(el('li', { class: 'hint', text: 'No functional groups yet.' }));
  }

  function renderFindings(s) {
    var ul = $('findings');
    ul.textContent = '';
    if (!s) { $('findings-summary').textContent = ''; return; }
    var fs = core.check(s);
    var nC = fs.filter(function (f) { return f.severity === 'conflict'; }).length;
    var nW = fs.filter(function (f) { return f.severity === 'warning'; }).length;
    $('findings-summary').textContent = nC + ' conflicts, ' + nW + ' warnings';
    $('findings-summary').style.color = nC ? 'var(--conflict)' : (nW ? 'var(--warning)' : '');
    fs.forEach(function (f) {
      var li = el('li', { class: f.severity, onclick: function () { if (f.controls.length) { ui.selected = f.controls[0]; render(); focusControl(f.controls[0]); } } }, [
        el('span', { class: 'kind', text: f.kind }), document.createTextNode(f.message)
      ]);
      ul.appendChild(li);
    });
    ul.appendChild(el('li', { class: 'note', text: 'A sketch is a panel idea. It approves no circuit, no part order and no cutting file.' }));
  }

  // Forms -> edits ----------------------------------------------------------------

  function num(id) { var v = parseFloat($(id).value); return isFinite(v) ? v : null; }
  function intOf(id) { var v = parseInt($(id).value, 10); return isFinite(v) ? v : null; }

  $('sketch-name').addEventListener('change', function () { var v = this.value; edit(function (s) { return ed.setName(s, v); }); });
  $('sketch-hp').addEventListener('change', function () { var hp = parseInt(this.value, 10); edit(function (s) { return ed.setHP(s, hp); }, 'Width ' + hp + ' HP. Controls stay where they are; anything outside is listed under findings.'); });
  $('sketch-status').addEventListener('change', function () { var v = this.value; edit(function (s) { return ed.setStatus(s, v); }); });
  $('sketch-notes').addEventListener('change', function () { var lines = this.value.split('\n').map(function (l) { return l.trim(); }).filter(Boolean); edit(function (s) { return ed.setNotes(s, lines); }); });
  $('grid-profile').addEventListener('change', function () {
    var id = this.value;
    if (id) edit(function (s) { return ed.applyProfile(s, id); }, 'Grid re-derived for ' + id + '. Controls keep their cells.');
    else edit(function (s) { var g = JSON.parse(JSON.stringify(s.grid)); delete g.profile; return ed.setGrid(s, g); }, 'Custom grid.');
  });
  ['grid-ox', 'grid-oy', 'grid-px', 'grid-py'].forEach(function (id) {
    $(id).addEventListener('change', function () {
      var ox = num('grid-ox'), oy = num('grid-oy'), px = num('grid-px'), py = num('grid-py');
      if (ox === null || oy === null || px === null || py === null || px <= 0 || py <= 0) { say('Grid numbers must be finite and pitches positive.'); render(); return; }
      edit(function (s) { var g = { origin: { x: ox, y: oy }, pitch: { x: px, y: py } }; return ed.setGrid(s, g); }, 'Custom grid (no profile recorded).');
    });
  });

  $('ctl-id').addEventListener('change', function () {
    var from = ui.selected, to = this.value.trim();
    edit(function (s) { var t = ed.renameControl(s, from, to); ui.selected = to; return t; }, 'Renamed ' + from + ' to ' + to);
  });
  $('ctl-hardware').addEventListener('change', function () {
    var hwId = this.value, id = ui.selected, hw = core.hardware(hwId);
    edit(function (s) { var c = ed.get(s, id); var rot = hw.rotations.indexOf(c.rotation) >= 0 ? c.rotation : (hw.defaultRotation || 0); return ed.updateControl(s, id, { hardware: hwId, rotation: rot }); }, id + ' is now a ' + hwId);
  });
  $('ctl-label').addEventListener('change', function () { var id = ui.selected, v = this.value; edit(function (s) { return ed.updateControl(s, id, { label: v }); }); });
  $('ctl-group').addEventListener('change', function () {
    var id = ui.selected, v = this.value.trim();
    edit(function (s) {
      var t = s;
      if (v && !(s.groups || []).some(function (g) { return g.id === v; })) t = ed.addGroup(t, v, '');
      return ed.updateControl(t, id, { group: v || null });
    }, v ? id + ' grouped under ' + v : id + ' ungrouped');
  });
  ['ctl-col', 'ctl-row', 'ctl-cols', 'ctl-rows'].forEach(function (fid) {
    $(fid).addEventListener('change', function () {
      var id = ui.selected, col = intOf('ctl-col'), row = intOf('ctl-row'), cols = intOf('ctl-cols'), rows = intOf('ctl-rows');
      if (col === null || row === null || cols === null || rows === null || cols < 1 || rows < 1) { say('Cells are integers; spans are at least 1.'); render(); return; }
      edit(function (s) { return ed.updateControl(s, id, { cell: { col: col, row: row }, span: { cols: cols, rows: rows } }); });
    });
  });
  ['ctl-dx', 'ctl-dy'].forEach(function (fid) {
    $(fid).addEventListener('change', function () {
      var id = ui.selected, dx = num('ctl-dx'), dy = num('ctl-dy');
      if (dx === null || dy === null) { say('Offsets must be finite numbers.'); render(); return; }
      edit(function (s) { return ed.updateControl(s, id, { offset: { x: dx, y: dy } }); });
    });
  });
  $('ctl-rot').addEventListener('change', function () { var id = ui.selected, r = parseInt(this.value, 10); edit(function (s) { return ed.updateControl(s, id, { rotation: r }); }); });
  $('ctl-rotate').addEventListener('click', function () { rotateSelected(1); });
  $('ctl-duplicate').addEventListener('click', duplicateSelected);
  $('ctl-delete').addEventListener('click', deleteSelected);

  $('group-add').addEventListener('click', function () {
    var id = $('group-new-id').value.trim(), label = $('group-new-label').value.trim();
    if (!core.validIdentifier(id)) { say('A group id uses letters, digits, - and _.'); return; }
    edit(function (s) { return ed.addGroup(s, id, label); }, 'Added group ' + id);
    $('group-new-id').value = ''; $('group-new-label').value = '';
  });

  function rotateSelected(steps) { var id = ui.selected; if (!id) return; edit(function (s) { return ed.rotateControl(s, id, steps); }, 'Turned ' + id); focusControl(id); }
  function duplicateSelected() {
    var id = ui.selected; if (!id) return;
    var newId = null;
    edit(function (s) { var t = ed.duplicateControl(s, id); newId = t.controls[t.controls.length - 1].id; return t; }, 'Duplicated ' + id + '. Move the copy; overlaps are listed, not resolved.');
    ui.selected = newId; render(); focusControl(newId);
  }
  function deleteSelected() { var id = ui.selected; if (!id) return; ui.selected = null; edit(function (s) { return ed.deleteControl(s, id); }, 'Deleted ' + id); }
  function nudgeSelected(dc, dr) { var id = ui.selected; if (!id) return; edit(function (s) { return ed.nudgeControl(s, id, dc, dr); }); focusControl(id); }

  // Sketchbook buttons -----------------------------------------------------------

  $('new-sketch').addEventListener('click', function () {
    var n = 1; while (store.ids().indexOf('module-' + n) >= 0) n++;
    var id = 'module-' + n;
    store.add(id, core.newSketch('Untitled module', 8, PCBGEN_CATALOGUE.profiles[0].id));
    ui.selected = null; ui.armed = null; ui.confirmDelete = false;
    say('Started ' + id + ': 8 HP, empty. Rename it to what the module does.');
    render();
  });
  $('rename-sketch').addEventListener('click', function () { ui.renaming = true; render(); });
  $('delete-sketch').addEventListener('click', function () {
    if (!ui.confirmDelete) { ui.confirmDelete = true; render(); setTimeout(function () { if (ui.confirmDelete) { ui.confirmDelete = false; render(); } }, 4000); return; }
    var id = store.current(); ui.confirmDelete = false;
    var text = core.stringify(store.get(id));
    store.remove(id);
    ui.selected = null;
    say('Deleted ' + id + '. Its JSON is in the paste box in case that was a mistake.');
    $('paste-json').value = text; $('paste-details').open = true;
    render();
  });
  $('undo').addEventListener('click', function () { store.undo(); say('Undone'); render(); });
  $('redo').addEventListener('click', function () { store.redo(); say('Redone'); render(); });

  ['view-rear', 'view-cells', 'view-courtyards', 'view-access', 'view-labels'].forEach(function (id) {
    $(id).addEventListener('change', function () {
      ui.rear = $('view-rear').checked; ui.cells = $('view-cells').checked; ui.courtyards = $('view-courtyards').checked; ui.access = $('view-access').checked; ui.labels = $('view-labels').checked;
      renderCanvas(current());
    });
  });

  // Exchange -----------------------------------------------------------------------

  $('copy-json').addEventListener('click', function () {
    var s = current(); if (!s) return;
    var text = core.stringify(s);
    var done = function () { say('Copied ' + store.current() + '.json to the clipboard.'); };
    if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(text).then(done, function () { fallbackCopy(text); done(); });
    else { fallbackCopy(text); done(); }
  });
  function fallbackCopy(text) { var ta = $('paste-json'); ta.value = text; $('paste-details').open = true; ta.focus(); ta.select(); try { document.execCommand('copy'); } catch (e) { /* the text is selected for a manual copy */ } }
  $('download-json').addEventListener('click', function () {
    var s = current(); if (!s) return;
    var blob = new Blob([core.stringify(s)], { type: 'application/json' });
    var a = document.createElement('a');
    a.href = URL.createObjectURL(blob); a.download = store.current() + '.json';
    document.body.appendChild(a); a.click(); document.body.removeChild(a);
    setTimeout(function () { URL.revokeObjectURL(a.href); }, 1000);
    say('Downloaded ' + a.download);
  });
  $('open-json').addEventListener('change', function () {
    var file = this.files && this.files[0];
    this.value = '';
    if (!file) { say('No file chosen; nothing changed.'); return; }
    var reader = new FileReader();
    reader.onerror = function () { say('Could not read ' + file.name + '; nothing changed.'); };
    reader.onload = function () {
      var id = file.name.replace(/\.json$/i, '').replace(/[^A-Za-z0-9_-]/g, '-').slice(0, 40) || 'imported';
      importText(String(reader.result), store.ids().indexOf(id) >= 0 ? id : null, id);
    };
    reader.readAsText(file);
  });
  $('import-replace').addEventListener('click', function () { importText($('paste-json').value, store.current(), null); });
  $('import-add').addEventListener('click', function () { importText($('paste-json').value, null, null); });
  function importText(text, replaceId, suggestedId) {
    var r = core.parse(text);
    if (!r.ok) {
      $('import-result').textContent = 'Not imported. ' + r.errors.length + ' problem' + (r.errors.length === 1 ? '' : 's') + ': ' + r.errors.join('; ');
      say('Import refused; the current work is unchanged.');
      return;
    }
    var id = replaceId;
    if (!id) { id = suggestedId || 'module-1'; var n = 1; var base = id; while (store.ids().indexOf(id) >= 0) { n++; id = base + '-' + n; } }
    try { store.replace(id, r.sketch); } catch (e) { $('import-result').textContent = 'Not imported: ' + e.message; return; }
    store.select(id);
    ui.selected = null;
    $('import-result').textContent = (replaceId ? 'Replaced ' : 'Added ') + id + ' (' + r.sketch.controls.length + ' controls). Undo restores the previous version.';
    say('Imported into ' + id + '.');
    render();
  }
  $('handback').addEventListener('click', function () {
    if (typeof window.agentDone !== 'function') return;
    var payload = { format: 'pcbgen-sketchbook', version: 1, current: store.current(), sketches: store.exportAll() };
    window.agentDone(payload);
    say('Handed ' + store.ids().length + ' sketch' + (store.ids().length === 1 ? '' : 'es') + ' back to the agent. You can keep editing; every change is stored.');
  });

  // Keyboard -------------------------------------------------------------------------

  document.addEventListener('keydown', function (e) {
    var tag = (e.target && e.target.tagName || '').toLowerCase();
    var typing = tag === 'input' || tag === 'textarea' || tag === 'select';
    if (e.key === 'Escape') {
      if (ui.armed) { ui.armed = null; say('Placement cancelled.'); render(); return; }
      if (!typing && ui.selected) { ui.selected = null; render(); return; }
      if (typing) e.target.blur();
      return;
    }
    if (typing) return;
    var mod = e.ctrlKey || e.metaKey;
    if (mod && (e.key === 'z' || e.key === 'Z') && !e.shiftKey) { e.preventDefault(); if (store.undo()) say('Undone'); render(); return; }
    if ((mod && (e.key === 'y' || e.key === 'Y')) || (mod && e.shiftKey && (e.key === 'z' || e.key === 'Z'))) { e.preventDefault(); if (store.redo()) say('Redone'); render(); return; }
    if (mod && (e.key === 'd' || e.key === 'D')) { e.preventDefault(); duplicateSelected(); return; }
    if (!ui.selected) return;
    var mirror = ui.rear ? -1 : 1;
    if (e.key === 'ArrowLeft') { e.preventDefault(); nudgeSelected(-1 * mirror, 0); }
    else if (e.key === 'ArrowRight') { e.preventDefault(); nudgeSelected(1 * mirror, 0); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); nudgeSelected(0, -1); }
    else if (e.key === 'ArrowDown') { e.preventDefault(); nudgeSelected(0, 1); }
    else if (e.key === 'r' || e.key === 'R') { e.preventDefault(); rotateSelected(e.shiftKey ? -1 : 1); }
    else if (e.key === 'Delete' || e.key === 'Backspace') { e.preventDefault(); deleteSelected(); }
  });

  // Start ----------------------------------------------------------------------------

  var problems = store.load();
  if (!store.ids().length) {
    store.add('module-1', core.newSketch('Untitled module', 8, PCBGEN_CATALOGUE.profiles[0].id));
    say('Empty sketchbook: started module-1 at 8 HP. Pick a part from the palette and click a cell.');
  } else {
    say('Recovered ' + store.ids().length + ' sketch' + (store.ids().length === 1 ? '' : 'es') + ' from this browser.' + (problems.length ? ' Problems: ' + problems.join(' | ') : ''));
  }
  render();

  // For the browser tests and the console.
  window.sketcher = { core: core, store: store, edits: ed, ui: ui, render: render };
})();
