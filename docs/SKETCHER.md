---
status: "maintained; sketch format v1 and the browser editor are implemented and tested; the grid pitch and most hardware envelopes they draw remain provisional"
owner: "the agent maintains the format, catalogue and editor; the user owns the panel ideas the sketches hold"
read_when: "sketching a module's panel, exchanging a sketch with the agent or the other workstation, or changing the sketch format, hardware catalogue or editor"
update_when: "the format version changes, a hardware record or grid profile is added or corrected, the editor gains or loses a capability, or the generator bridge lands"
retire_when: "the sketcher is replaced or folded into another tool, or the generator bridge makes this a section of that tool's document"
---

# Module sketcher

A local HTML editor for panel ideas. Choose a width, drop knobs, jacks,
switches and LEDs on a grid of control centres, and see what collides before
anyone draws a circuit. It is a laptop design tool, not firmware and not part
of the instrument; it runs from a file with no backend, no login and no
network.

The panel language it draws is in [MECHANICAL.md](MECHANICAL.md); the
programming milestones it satisfies are S1 and S2 in
[ROADMAP.md](ROADMAP.md#s1-shared-panel-model-and-checks-done-2026-09-16). The bridge
that would turn a reviewed sketch into a generated board is S3 and does not
exist yet.

## What a sketch is, and is not

A sketch is inert data about the front of a module: a width in HP, a grid, and
controls that occupy cells and carry a hardware identity, a label and a
functional group. It names no net, no part number and no circuit.

**A sketch approves nothing.** Its `status` is `provisional` or `reviewed`,
never manufacturing-ready. The grid pitches on offer are candidates awaiting
the mockup in [the grid and fit gate](MECHANICAL.md#grid-and-fit-gate); most
of the front-of-panel envelopes it checks against are estimates, and two of
the parts it offers have no footprint drawn yet. The editor says so in its
findings list rather than letting a clean-looking panel imply a fit result.

## Opening it

Open `sketcher/index.html` in a browser. That is the whole procedure: no
server, no build step, no development mode. `sketcher/tests.html` runs the
same tests the command line does, in whatever browser you opened it with.

Two of its files are generated and must not be hand-edited:

```
cabal run pcbgen -- sketcher
```

writes `sketcher/catalogue.js` (the hardware records, grid profiles and
form-factor numbers, taken from the Haskell that generates boards),
`sketcher/vectors.js` (fixtures with their expected geometry and findings),
the reference fixtures under `sketches/_fixtures/`, and a single-file bundle
at `build/sketcher/index.html` for the fast-ui exchange below. Run it after
any change to `toolkit/src/Sketch/` or to the form factor.

## Using it

The left column holds the sketchbook, the module's width and status, the grid,
the palette and the view switches. The middle is the panel. The right column
holds the selected control, the groups, the findings and the exchange buttons.

- **Place** by clicking a palette part and then a cell. Esc cancels.
- **Move** by dragging, by the arrow keys, or by typing a cell in the form.
  Everything snaps to the grid; an offset within half a cell is what puts an
  indicator LED diagonally beside its jack.
- **Turn** with R, **duplicate** with Ctrl+D, **delete** with Del, and undo or
  redo with Ctrl+Z and Ctrl+Y. Pointer, keyboard and touch all reach every
  control; Tab cycles them and Enter selects.
- **Rear view** mirrors the panel so you can see what the board side looks
  like. Courtyard, finger-room and cell overlays switch on and off.
- **Several modules at once.** The sketchbook holds as many sketches as you
  want; each has its own undo history and its own storage key.

Changing the width never moves or drops a control. Anything that no longer
fits is reported, and the report is the whole point.

## What it checks

Conflicts mean the panel cannot be built as drawn: a hole off the panel, a
body outside the PCB zone, a control on a rail screw, two controls sharing a
cell, colliding nuts or knobs in front, overlapping footprint courtyards
behind, or an offset that leaves its cell. Warnings are comfort and policy:
finger, cable or bat room overlapping, and a width outside the 4 to 20 HP
module policy or off Doepfer's table. Notes record what the sketch cannot
claim: the provisional pitch, unverified envelopes and missing footprints.

The geometry is the generator's own. Panel size, the PCB zone, the rail holes
and the footprint-origin transform come through `Block.Eurorack`'s `skeleton`,
`toBoard` and `originFor`, the same calls the attenuverter's design makes, and
a test places a pot through the sketch model and compares it with where that
design actually put `RV1`. The browser reimplements that arithmetic in
JavaScript and is held to the Haskell numbers by the generated vectors, so
there is one set of panel dimensions in the project rather than two.

## Exchanging a sketch

Round trips are byte-for-byte: the text the browser writes and the text the
generator writes are the same file for the same sketch.

- **File.** Download or open a `.json`. A failed or cancelled open leaves the
  current work untouched.
- **Clipboard.** Copy the current sketch, or paste one in and replace the
  current module or add it as a new one.
- **The agent.** `cabal run pcbgen -- sketch <file.json> ...` validates
  sketches and prints their findings; it exits 1 if a file is not a sketch and
  2 if a sketch has conflicts, so it fails closed in a script.
- **fast-ui.** The bundle at `build/sketcher/index.html` is the whole editor
  in one file with the shared-storage hook in front of it, so the agent can
  show it, read every sketch back out of the page's storage, and write the
  result into the repository. A **Hand back to agent** button appears only
  when the page is running there.

The browser's own storage is a recovery copy, never the only one. Sketches
live under `sketch:<id>` with an index at `sketchbook.index`; if storage is
blocked the editor keeps working in memory and says so.

## The format

`pcbgen-sketch` version 1. Unknown fields, unknown hardware, duplicate ids,
non-finite numbers, bad rotations, zero spans and a dangling group are all
refused, each with the path it concerns, and every problem is reported at
once rather than the first. A reader that cannot read a file whole reads none
of it.

```json
{
  "format": "pcbgen-sketch",
  "version": 1,
  "name": "Sparse mixed fixture",
  "status": "provisional",
  "hp": 8,
  "grid": {
    "origin": { "x": 12.65, "y": 20 },
    "pitch": { "x": 15, "y": 15 },
    "profile": "candidate-15"
  },
  "controls": [
    { "id": "level", "hardware": "pot-9mm", "cell": { "col": 0, "row": 0 },
      "rotation": 90, "label": "LEVEL", "group": "ch1" },
    { "id": "out", "hardware": "jack-ts", "cell": { "col": 1, "row": 1 },
      "label": "OUT", "group": "ch1" },
    { "id": "out-led", "hardware": "led-3mm", "cell": { "col": 1, "row": 1 },
      "offset": { "x": 6, "y": -6 }, "group": "ch1" },
    { "id": "freq", "hardware": "pot-9mm", "cell": { "col": 0, "row": 5 },
      "span": { "cols": 2, "rows": 1 }, "label": "FREQ" }
  ],
  "groups": [ { "id": "ch1", "label": "Channel 1" } ],
  "notes": [ "Row 2 is empty on purpose." ]
}
```

Coordinates are millimetres from the panel's top-left corner, viewed from the
front, y downward. `cell` is the top-left cell of the block a control
reserves and `span` how many it takes; `offset` moves the centre within that
block and may not leave it. `rotation` is counter-clockwise on screen, the
sense KiCad displays, and must be one the part allows. `span`, `offset`,
`rotation`, `label`, `group`, `groups` and `notes` are omitted at their
defaults. An empty cell is space, not a missing component, and creates no
hole.

The three reference sketches in `sketches/_fixtures/` are generated: a sparse
mixed-control panel that checks clean, one that triggers every conflict kind,
and an empty 4HP panel. Your own sketches belong beside them in `sketches/`,
not in that directory.

## Where the code is

| File | What it owns |
|---|---|
| [Sketch/Model.hs](../toolkit/src/Sketch/Model.hs) | the format: decoding with diagnostics, deterministic encoding |
| [Sketch/Catalogue.hs](../toolkit/src/Sketch/Catalogue.hs) | hardware records with their evidence status, grid profiles, derived defaults |
| [Sketch/Check.hs](../toolkit/src/Sketch/Check.hs) | placement through `Block.Eurorack` and the findings |
| [Sketch/Export.hs](../toolkit/src/Sketch/Export.hs) | what the browser gets, and the single-file bundle |
| [Sketch/Json.hs](../toolkit/src/Sketch/Json.hs) | a strict JSON reader and printer, so the toolkit gains no dependency |
| [sketch-core.js](../sketcher/sketch-core.js) | the same format, geometry and checks in the browser |
| [sketchbook.js](../sketcher/sketchbook.js) | the sketchbook, per-sketch undo/redo and the storage mirror |
| [sketcher.js](../sketcher/sketcher.js) | the editor's DOM and SVG, and nothing else |
| [tests.js](../sketcher/tests.js) | the browser tests, run by node or by `tests.html` |
| [smoke.js](../sketcher/smoke.js) | a DOM stub that runs the editor itself when no browser is available |

Three test runs, all expected clean before a commit:

```
cabal test                 the Haskell: format, catalogue, geometry, export
node sketcher/tests.js     the browser core, against the generated vectors
node sketcher/smoke.js     the editor itself, against a minimal DOM stub
```

`sketcher/tests.html` runs the second of those in a real browser. The smoke run
exists because the first two never touch the DOM: it starts the editor, places
a control, changes the width, undoes, refuses a bad paste and switches to the
rear view, so that code executes even when no browser is available. It checks
that nothing throws and that the page's ids and the script agree. It says
nothing about how the page looks.

## Known limits

- **The pitch is not chosen.** Every profile is a candidate. A sketch records
  which one it used so the same idea can be re-laid once the mockup settles
  the question; nothing here snaps an existing board to a candidate grid.
- **Front-of-panel envelopes are estimates.** The nut, knob and cable-barrel
  circles and the toggle's bat rectangle are reasoned from drawings, not
  measured. They are marked unverified and produce warnings, never fit claims.
  Courtyards and footprint anchors, by contrast, are read from the KiCad
  footprints the boards already use.
- **`jack-trs` and the toggles have no footprint.** A design cannot place them
  until `lib/footprints/` gains one, and the editor notes that on every sketch
  that uses them.
- **No generator bridge.** Nothing here writes a KiCad file, a circuit or a
  cutting file, and the browser never touches a generated project.
- **The browser-rendered screenshots in S2's gate are not taken.** The logic is
  covered by the three runs above; the editor's own code is exercised by the
  smoke run against a stub. What none of that establishes is how the page
  actually looks: no rendered screenshot has been inspected, on a desktop or a
  phone. Open `sketcher/index.html` and look before trusting the layout.
