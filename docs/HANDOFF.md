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
  2026-09-16. `sketcher/index.html` opens in a browser with no backend and
  edits a sketchbook of module panels; the `pcbgen-sketch` v1 format, hardware
  catalogue and geometry checks live in `toolkit/src/Sketch/`.
  [SKETCHER.md](SKETCHER.md) is the guide. Evidence: `cabal test` covers the
  Haskell, and 26 browser tests pass under node and in `sketcher/tests.html`,
  checked against vectors the generator writes, so the JavaScript geometry is
  held to the Haskell numbers rather than a second hand-kept copy of the panel
  dimensions. A placement test compares a sketched pot with where
  `Attenuverter.hs` actually put `RV1`.
  **Open:** the rendered desktop and mobile screenshots in S2's gate were not
  captured, because the browser extension in that session could not open a
  local page or a localhost server.
  **What it does not do:** no KiCad file, circuit, netlist or cutting file.
  The generator bridge is S3 and is not started. The grid pitches it offers
  are candidates, and most front-of-panel envelopes it checks are estimates;
  the editor reports both as notes on every sketch.
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

- **Built the shared panel model and the module sketcher (roadmap S1 and S2).**
  New: `toolkit/src/Sketch/` (the `pcbgen-sketch` v1 format with a strict JSON
  reader written rather than added as a dependency, the hardware and grid
  catalogue, the geometry checks, the fixtures and the browser export),
  `toolkit/test/SketchTests.hs`, the editor under `sketcher/`, generated
  fixtures under `sketches/_fixtures/`, and [SKETCHER.md](SKETCHER.md).
  Two new commands: `pcbgen sketcher` regenerates what the browser reads, and
  `pcbgen sketch <file>` validates sketches and fails closed.
- On the user's 2026-09-16 direction the editor holds a **sketchbook of
  several modules** rather than one, so a session can move between ideas, and
  the generator emits a single-file bundle for the fast-ui channel. That
  exchange was tested end to end: a page wrote a sketch into its storage, the
  agent read it back through `get_state`, and the recovered text is byte for
  byte the file the generator writes.
- Two defects found and fixed while checking, both about the exchange rather
  than the drawing. The generator wrote CRLF on Windows while the browser
  writes LF, so the same sketch was two different files on disk; `pcbgen`
  now writes these outputs through an explicit LF handle and a test refuses a
  carriage return in encoded text. And `pcbgen sketch` crashed on a missing
  file instead of reporting it and moving to the next one.
- Documentation reconciled in the same task: the roadmap's S1/S2 sections and
  next work item, [MECHANICAL.md](MECHANICAL.md#panel-layout-language) (the
  diagonal LED offset can now be checked but is still not a chosen number, and
  the sketcher does not close the fit gate), [README.md](README.md), the root
  README and the toolchain section of [AGENTS.md](../AGENTS.md).
- The earlier 2026-09-15 work-laptop checkpoint recorded the no-menu,
  visible persistent-control rule and the S1-S3 gates in
  [AGENTS.md](../AGENTS.md#rules) and the roadmap; the hardware inbox's stale
  claims were corrected with all answers preserved.

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

Home laptop, 2026-09-16, GHC 9.6.7 / cabal 3.18.1.0, for the sketcher work:

| Check | Result |
|---|---|
| `cabal test --test-show-details=direct` | 103/103 passed; the sketch suite adds format, geometry, catalogue and export cases to the existing 102 |
| `node sketcher/tests.js` | 27/27 passed, covering the format, the geometry against generator-written vectors, sparse placement, editing, undo/redo, width-change conflicts, save/reopen, malformed input and storage failure |
| `node sketcher/smoke.js` | 11/11 passed; starts the editor against a DOM stub and places a control, changes the width, undoes, refuses a bad paste and switches to the rear view, so the editor's own 35 kB of code runs at least once |
| `sketcher/tests.html` in a browser | not run; the browser extension in this session could not open a local page or a localhost server, so the page-rendered run and S2's screenshots are still owed |
| `pcbgen sketch` on the three fixtures | clean fixture exits 0 with notes only, the conflict fixture exits 2 with nine conflicts, a malformed file and a missing file each exit 1 with a diagnostic |
| fast-ui exchange | a page's stored sketch returned through `get_state` is byte-identical to the generator's file |
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
