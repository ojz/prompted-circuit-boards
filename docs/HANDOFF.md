---
status: "maintained checkpoint"
owner: "the agent completing the latest task"
read_when: "starting a session, after reading AGENTS.md and checking the decision inbox"
update_when: "a validated checkpoint, blocker or next action changes; replace superseded prose"
retire_when: "the project ends or another current-state record takes over; Git is the session archive"
---

# Current Handoff

Updated 2026-09-16 by Claude Code (home laptop), after implementing the shared
panel model and the browser module sketcher (roadmap S1 and S2).
Use [README.md](README.md) as the document register and short code map. This
handoff holds current evidence and next actions, not a session history.

## Current Position

- **The module sketcher exists and is tested.** Roadmap S1 and S2 landed on
  2026-09-16 and were cut back the same day on the user's direction: the first
  version modelled millimetres, grid profiles and clearance conflicts, and the
  user judged it far too much. `sketcher/index.html` is now a grid of cells
  and a palette of four kinds, with no panel drawing, no size picker and no
  millimetre in the interface. [SKETCHER.md](SKETCHER.md) is the guide.
  **The grid limits are derived rather than chosen: at most six columns by six
  rows.** Seven rows would space centres 13.44 mm apart and two Thonkiconns
  need 13.6 mm, so the jack body caps the grid; six columns already needs the
  full 20 HP. That answers the user's "8 rows seems fine" with a measurement:
  eight is not possible with these parts.
  Evidence: `cabal test`, `node sketcher/tests.js` (23) against vectors the
  generator writes, and `node sketcher/smoke.js` (14) which runs the page
  against a DOM stub because the other two never touch the DOM.
  **Open:** no rendered screenshot has been inspected; the browser extension
  in that session could not open a local page or a localhost server.
  **What it does not do:** no KiCad file, circuit, netlist or cutting file.
  The generator bridge is S3 and is not started. The 15 mm spacing the limits
  are reckoned at is still a candidate, so the maxima move if it does; the
  format stores counts, not millimetres, so sketches survive that.
- **R5 Boolean + Clock has a draft plan.** The user's 2026-09-15 inbox note
  is integrated into [modules/boolean-clock/SPEC.md](modules/boolean-clock/SPEC.md):
  `A AND NOT B` defined and provided in both orders, a proposed behavior table
  awaiting confirmation, the budget items to derive, and a six-step plan. The
  one genuine choice, how the multi-input digital part and fixed-pattern trigger
  sequencer are realised, is in
  [decisions/2026-09-15-logic-module-architecture.md](decisions/2026-09-15-logic-module-architecture.md)
  with hardwired CMOS plus a diode matrix recommended. No circuit or part chosen.
- **First module: R1 IO + Mixer.** Its [behavior specification](modules/io-mixer/SPEC.md)
  now records the approved connector and mixer choices. Circuit, parts, models,
  Haskell implementation and board are not implemented. The attenuverter remains
  a method rehearsal, not a silently substituted first order.
- **Home lab:** prepare the exact staged basket in [HOMELAB.md](HOMELAB.md).
  Purchase intent is recorded, but no equipment is confirmed bought. Supplies,
  precision measurement, PD accessories and scope capability need verification;
  do not buy the historical list unchanged.
- The passive mult and option B attenuverter exist as generated, checked designs.
  No board has been built or measured. **Ordering remains on hold** under the
  specific findings and release gates in [ORDER-READINESS.md](ORDER-READINESS.md).
- `Block.Eurorack`, `Block.Power` and `Block.Precision` exist and are used by
  those designs. They are reusable definitions, not bench-proven circuits or a
  PD converter. Relevant review findings must be closed before reuse in R1.
- M1/M2 complete; M3 has pinned dependencies but no CI. Final panel artwork,
  fabrication and case work remain deferred. Panel standards, ergonomic
  mockups and sketcher programming are authorized now. P1's converter/gain
  blocks serve R2/R3 and do not block R1.
- **Panel language adopted; hardware catalogue still provisional.**
  [MECHANICAL.md](MECHANICAL.md) owns the sparse grid, marking conventions and
  fit gate. Exact pitch, material/thickness, remaining hardware variants and
  sample fits are not approved by this discussion. **R1 remains blocked on
  its jack tradeoff:** the proposed WQP419GR has no switch contact; no checked
  switched TRS candidate fits the proposed stack. The unresolved choice is in
  [decisions/2026-09-14-panel-hardware.md](decisions/2026-09-14-panel-hardware.md)
  with the remaining hardware preferences. The general persistent-switch
  question is integrated, not the R1 option or the blank variant answers.
  The stereo Thonkiconn and sub-mini toggle still need verified repository
  footprints before a layout uses them.

## Latest Change

- **Built the module sketcher (roadmap S1 and S2), then simplified it.** New:
  `toolkit/src/Sketch/` (the `module-sketch` v2 format with a strict JSON
  reader written rather than added as a dependency, the component kinds, and
  the derivation of the grid limits), `toolkit/test/SketchTests.hs`, the
  editor under `sketcher/`, generated fixtures under `sketches/_fixtures/`,
  and [SKETCHER.md](SKETCHER.md). Two commands: `pcbgen sketcher` regenerates
  what the browser reads, `pcbgen sketch <file>` validates and fails closed.
- **The first version was too much and was cut back the same session.** It
  drew a Eurorack panel, offered an HP selector, grid profiles, rear views,
  courtyard overlays and a findings list of clearance conflicts. The user
  asked for something conceptual: components on coordinates, an adjustable
  column count, and the measurements done for them rather than shown to them.
  What was deleted is the whole geometry layer (`Sketch/Check.hs` is gone) and
  most of the format: a cell now holds one component or nothing, so overlaps
  cannot be expressed and the checks that looked for them are unnecessary.
- **The measurement the user asked for.** Six rows, six columns, derived in
  `Sketch/Catalogue.hs` from the footprint courtyards and the 100 mm board.
  Recorded in [MECHANICAL.md](MECHANICAL.md#grid-and-fit-gate) as a first
  result from the candidate 15 mm spacing, not as an approved pitch.
- Two defects found and fixed while checking the first version, both in the
  exchange rather than the drawing: the generator wrote CRLF on Windows while
  the browser writes LF, so one sketch was two files on disk, and
  `pcbgen sketch` crashed on a missing file instead of reporting it. Doepfer's
  width table, which had been copied into three places, now has one home in
  `Design.eurorackPanelWidths`.
- The fast-ui exchange was tested end to end before the rewrite: a page wrote
  a sketch into its storage, the agent read it back through `get_state`, and
  the recovered text was byte for byte the generator's file.

## Recovery Retained

Distinct SPICE refusal and unconnected-pin escaping fixes were recovered and
published as `6f1d417` after synchronizing the two workstations on 2026-09-14.

The full tracked/untracked backup remains in stash
`5ca11c95875f37967d48d7d17ce067919edcec52`
(`recovery: work-laptop before weekend sync 2026-09-14`) and the verified local
bundle `.git/recovery-2026-09-14.bundle`. Do not drop or blindly pop them. The older
47 pF design/model/peaking experiment is recovery-only; it did not overwrite the
weekend's 100 mm boards, 10 pF design, NR model and direct loop-gain tests. The old
and new experiments are not claimed to impose equivalent numerical limits.

## Verification

Work laptop, 2026-09-14, GHC 9.6.7 / cabal 3.14.2.0, KiCad 10.0.3,
ngspice 47. Circuit/software evidence is from recovery checkpoint `6f1d417`
and its same-day readiness review, not a new run after documentation edits:

| Check | Result |
|---|---|
| Focused SPICE-emitter and unconnected-pin naming regressions | both fail before the recovered fixes and pass afterwards |
| `cabal test --test-show-details=direct` | 82/82 passed, including the weekend's block tests and both recovered behaviors |
| `toolkit/pipeline.sh attenuverter` | regeneration matches the weekend project/report; module and panel ERC/DRC/parity and renders pass; `check.ok` written |
| `toolkit/sim.sh attenuverter` | 8 decks, 0 failed, using the current block-built netlist |
| `toolkit/test-scripts.sh` | 79 passed, 0 failed; native checks, scratch export/refusals, simulator stubs and report checks |
| Mult native check during readiness review | board ERC/DRC/parity and renders passed |
| 2026-09-15 documentation checks | YAML lifecycle fields, local links/anchors, register coverage, retained pending answers and whitespace checked; no code/CAD change requiring regeneration |

Home laptop, 2026-09-16, GHC 9.6.7 / cabal 3.18.1.0, for the sketcher work,
against the simplified version that is committed:

| Check | Result |
|---|---|
| `cabal test --test-show-details=direct` | 102/102 passed; the sketch suite covers the format, the derived limits and the export |
| `node sketcher/tests.js` | 23/23 passed: the format against generator-written vectors, placing, clearing, moving, resizing, undo/redo, save/reopen, malformed input and storage failure |
| `node sketcher/smoke.js` | 14/14 passed; runs the page against a DOM stub, placing from the palette, renaming in the cell, the steppers stopping at the derived maximum, a refused shrink, backspace, undo and a refused paste |
| `sketcher/tests.html` in a browser | not run; the browser extension in this session could not open a local page or a localhost server, so the rendered screenshots are still owed |
| `pcbgen sketch` on the two fixtures | both report their grid, component count and implied width; a malformed file and a missing file each exit 1 with a diagnostic |
| Board designs, simulation, pipeline and benchmark | not rerun; no design, model, deck or router code was touched |

The full mult pipeline/panel, benchmark, field-solver and node-budget checks were
not rerun for the readiness review. Its analyzers, PDF evidence, skipped thermal
assessment and coverage limits are recorded in [ORDER-READINESS.md](ORDER-READINESS.md).
Review JSON/PDFs in local ignored build folders are not a manufacturing release.
The script suite's fabrication export is a disposable control. No physical
measurement was made; software/hardware tests were not rerun for this docs-only task.

## Remaining Limits

- REF5050 effective capacitance, powered-off input protection and connector-level
  loaded precision remain unresolved; current passing decks do not model all
  those behaviors. Downloaded datasheets are not complete part verification.
- The drawing-derived stack in [MECHANICAL.md](MECHANICAL.md) has not been
  physically fitted. No assembly stock reservation, release bundle or quote exists.
- The [attenuverter power-up guide](modules/attenuverter/POWER-UP.md) has never
  been performed and still needs correction under OR-04. Do not follow it unchanged;
  revising the lab guide did not validate the candidate supplies or that procedure.
- CI on a runner with KiCad 10 is still owed by M3 before the first order.
- The router depends on pad order within a net: the weekend's power-block
  refactor changed routing without changing the circuit. Keep that limitation
  in mind when interpreting byte-identity checks across structural refactors.

## Next Action

1. **Next coding session: S1.** Start with one sparse mixed-control fixture,
  the versioned sketch format and geometry checks against `Block.Eurorack`.
  Once that gate passes, proceed to S2's local HTML placement/save/reopen
  workflow. Keep unknown hardware dimensions and candidate pitches explicitly
  provisional; do not let pending physical fit or R1's jack choice prevent
  a usable sketcher. Detailed scope and gates live in the roadmap.
2. **R1 design:** section 1 of the existing hardware inbox still needs the
  user's normalling choice before final jack allocation. The agent establishes
  the full connection diagram, proven reference circuits and connector-level
  and power budgets, including how consumer stereo playback occupies the four
  mono channels. Preserve DC CV paths and protected consumer audio; no promise
  of phone recording through an ordinary headphone socket. Verify the two
  proposed custom footprints before using them.
3. **R5 decision:** when the user answers the architecture file, record the
  answer in the R5 plan, confirm or edit its behavior table with them, and
  only then start reference-circuit provenance. No R5 code before that.
4. **Lab procurement:** finalize a linked, itemized assembly basket and verify the
  exact supply/manual, precision measurement method and R1 probing requirements
  in [HOMELAB.md](HOMELAB.md). Identify owned equipment before pricing adapters.
  The agent handles research; the user approves spending and reports delivery.

Close relevant [order-readiness findings](ORDER-READINESS.md) as the design uses
those blocks and implement CI before an order. S1/S2 are independent of hardware
delivery and do not authorize S3 to bypass the mechanical or native-check gates.
There is no automatic work between sessions.
