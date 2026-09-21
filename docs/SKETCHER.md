---
status: "maintained; the grid editor and the v2 sketch format are implemented and tested"
owner: "the agent maintains the format, the limits and the editor; the user owns the module ideas the sketches hold"
read_when: "sketching a module, exchanging a sketch with the agent or the other workstation, or changing the format, the kinds or the grid limits"
update_when: "the format version changes, a kind is added, the derived limits move because a part or the form factor changed, or the generator bridge lands"
retire_when: "the sketcher is replaced or folded into another tool"
---

# Module sketcher

Put components on a grid. Open `sketcher/index.html` in a browser: no server,
no build step, no network. Pick a knob, a jack, a switch, a button or an LED,
click a cell, name it. Change how many columns and rows you want. That is the
tool.

It is conceptual on purpose. A sketch says "a knob here, an input there"; it
does not say which pot, on what panel, wired to what. Choosing the part and
laying out the board happen later, from the design in Haskell.

## The grid, and why it is the size it is

You asked for the measurements rather than a size picker, so the editor has
no panel and no HP field. It offers **1 to 6 columns and 1 to 6 rows**, and
those two numbers are derived, not chosen:

- **Six rows.** A 100 mm board leaves 80.6 mm of vertical travel for control
  centres once the tallest thing above a centre and the deepest thing below
  one are allowed for. Six rows space them 16.1 mm apart. **Seven would space
  them 13.4 mm, and two 3.5 mm jacks cannot stack closer than 13.6 mm**, so
  seven is not possible with these parts. Eight, which was the first guess,
  would need 11.5 mm.
- **Six columns.** At 15 mm spacing, six columns already need the full 20 HP,
  which is the widest module the project allows.

The deepest part is the jack: its body hangs 12.98 mm below the barrel. That
single number is what caps the rows. The editor prints the whole derivation
under the size controls, so it can be checked rather than believed, and
[Sketch/Catalogue.hs](../toolkit/src/Sketch/Catalogue.hs) computes it from
the footprints the boards already use.

A sketch's column count implies a minimum panel width, and the editor shows
it as a note under the grid. That is the only place HP is mentioned.

| Columns | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| Needs at least | 4 HP | 8 HP | 10 HP | 14 HP | 16 HP | 20 HP |

**None of this approves anything.** The 15 mm spacing is a candidate awaiting
the mockup in [the grid and fit gate](MECHANICAL.md#grid-and-fit-gate), and a
sketch is a module idea, not a circuit, a part list or a cutting file.

## Using it

- **Place**: click a part on the right, then click a cell. A new component
  asks for its name straight away; press Enter, or Escape to leave it blank.
- **Rename**: click a filled cell once to select it, again to edit its name.
- **Move**: drag a cell onto another. If something is already there the two
  swap, so nothing is ever lost. Shift with an arrow key does the same from
  the keyboard.
- **Clear**: select a cell and press Backspace.
- **Resize**: the plus and minus buttons. Growing is always allowed. Shrinking
  is refused while a component sits outside the new size, and the message
  names it, so nothing disappears behind your back.
- **Undo and redo**: Ctrl+Z and Ctrl+Y, per module.
- **Several modules**: the list on the right. Double-click a name to rename it.

Everything is saved to the browser as you go, but that is a recovery copy.
The JSON is the copy that counts.

## Exchanging a sketch

The text the browser writes and the text the generator writes are the same
bytes for the same sketch, so a file moves between the two workstations and
between you and the agent without churn.

- **File**: Download, or Open. A cancelled or unreadable open changes nothing.
- **Clipboard**: Copy, or paste into the box and press Replace or Add.
- **The agent**: `cabal run pcbgen -- sketch <file.json> ...` validates a
  sketch and prints what it holds, exiting 1 if a file is not a sketch.
  `node sketcher/preview.js <file.json>` draws it as text, which is how a
  sketch gets looked at without opening a browser:

  ```
  +-----------+-----------+-----------+
  |    (o)    |    (=)    |           |
  |    CH1    |   IN 1    |           |
  +-----------+-----------+-----------+
  |    [/]    |    (=)    |     *     |
  |   AC/DC   |    OUT    |   CLIP    |
  +-----------+-----------+-----------+
  ```
- **fast-ui**: `build/sketcher/index.html` is the whole editor in one file
  with the shared-storage hook in front, so the agent can put it on screen
  and read every sketch back. A **Send to agent** button appears only there.

The loop this is for: you say what the module should do, the agent writes the
JSON, you open it and move things around, you send it back.

## The format

`module-sketch` version 2.

```json
{
  "format": "module-sketch",
  "version": 2,
  "name": "Mixer",
  "columns": 3,
  "rows": 6,
  "cells": [
    { "col": 0, "row": 0, "kind": "knob", "label": "CH1" },
    { "col": 1, "row": 0, "kind": "jack", "label": "IN 1" },
    { "col": 2, "row": 5, "kind": "led",  "label": "CLIP" }
  ]
}
```

Columns and rows count from zero, left to right and top to bottom. A cell
holds one component or nothing, so two components cannot overlap: the format
cannot express it. A label is optional and at most 24 characters. Cells are
written in reading order, so the same panel drawn in a different order is the
same file.

The kinds, with the note the palette shows for each:

| Kind | For |
|---|---|
| `knob` | A rotary control. Its position is the setting. |
| `jack` | A patch point, in or out. |
| `switch` | A maintained switch, for a setting that stays put. Anything that must survive a power cycle. |
| `button` | A momentary press: a manual trigger, a tap. Not for a mode that has to stay set. |
| `led` | An indicator. |

The switch and button notes carry [the instrument's visible-control
rule](../AGENTS.md#rules) to the place where the choice is actually made.

Reading is strict. Unknown fields, a wrong version, a grid past the limits, a
cell off the grid, two components in one cell, an unknown kind, a fractional
or non-finite number: all refused, every problem reported at once, each
naming its path. A reader that cannot read a file whole reads none of it.

Two reference sketches live in `sketches/_fixtures/` and are generated. Your
own sketches belong beside them in `sketches/`.

## Where the code is

| File | What it owns |
|---|---|
| [Sketch/Catalogue.hs](../toolkit/src/Sketch/Catalogue.hs) | the kinds, the part envelopes behind them, and the derivation of the grid limits |
| [Sketch/Model.hs](../toolkit/src/Sketch/Model.hs) | the format: strict decoding, deterministic encoding |
| [Sketch/Export.hs](../toolkit/src/Sketch/Export.hs) | what the browser is told, and the single-file bundle |
| [Sketch/Json.hs](../toolkit/src/Sketch/Json.hs) | a strict JSON reader and printer, so the toolkit gains no dependency |
| [sketch-core.js](../sketcher/sketch-core.js) | the same format in the browser |
| [sketchbook.js](../sketcher/sketchbook.js) | the modules, their undo stacks and the storage mirror |
| [sketcher.js](../sketcher/sketcher.js) | the page, and nothing else |
| [preview.js](../sketcher/preview.js) | prints a sketch as text, for a terminal or for the agent |

`cabal run pcbgen -- sketcher` regenerates `sketcher/catalogue.js`,
`sketcher/vectors.js`, the fixtures and the bundle. Those files are generated;
do not hand-edit them. Run it after any change under `toolkit/src/Sketch/`.

Three runs, all expected clean before a commit:

```
cabal test                 the Haskell: format, limits, export
node sketcher/tests.js     the browser format and sketchbook, against the vectors
node sketcher/smoke.js     the page itself, against a minimal DOM stub
```

`sketcher/tests.html` runs the second in a real browser. The smoke run exists
because the other two never touch the DOM; it checks that the page's ids and
the script agree and that nothing throws, and says nothing about how the page
looks.

## Known limits

- **The 15 mm spacing is a candidate**, so the column and row maxima move if
  the mockup settles on something else. The format stores counts, not
  millimetres, so a sketch survives that change.
- **Five kinds, and one of them has no part yet.** No trimmer, and no
  multi-cell component: something that needs two cells cannot be drawn. Say so
  and it gets added.
- **No momentary part is chosen.** `button` exists in the sketch and in the
  palette, but [MECHANICAL.md](MECHANICAL.md#panel-hardware-standard) has no
  push button in its hardware standard. The grid reckons its size with the
  sub-mini toggle's body as a stand-in, which is smaller than the knob and the
  jack in every direction, so the real part cannot change the six-by-six limit
  whatever it turns out to be. A test holds that.
- **No generator bridge.** Nothing here writes a KiCad file, a circuit or a
  cutting file, and the browser never touches a generated project. That is
  [S3](ROADMAP.md#s3-generator-bridge-and-panel-exports-deferred) and it is not
  started.
- **No rendered screenshot has been inspected.** The tests cover the logic and
  the code paths; how the page looks has not been checked on a desktop or a
  phone.
