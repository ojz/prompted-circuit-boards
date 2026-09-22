---
status: "maintained checkpoint"
owner: "the agent completing the latest task"
read_when: "starting a session, after reading AGENTS.md and checking the decision inbox"
update_when: "a validated checkpoint, blocker or next action changes; replace superseded prose"
retire_when: "the project ends or another current-state record takes over; Git is the session archive"
---

# Current Handoff

Updated 2026-09-22: three Rack modules now exist -- Quad Amp, Drive Filter and
Break -- and patch together. No circuit, part, layout or manufacturing output
was produced, and **no playtesting has happened yet.**
Use [README.md](README.md) as the document register and short code map. This
handoff holds current evidence and next actions, not a session history.

## Current Position

- **Current work is V0: play before building.** Build digital versions of the
  candidate modules in VCV Rack, then test the balance of VCAs, LFOs, envelopes,
  voices and utilities through real patches and user playtesting. The earlier
  five-board composition is the starting hypothesis, not a fixed resource count.
  [ROADMAP.md](ROADMAP.md#v0-playable-digital-modules-and-function-balance-current)
  owns the sequence and musical acceptance gate.
- **The first prototype is [Quad Amp](modules/quad-amp/SPEC.md):** four
  amplifier channels on a normalled mix bus, from the user's 2026-09-21
  description and revised the same evening. Each channel is SIG IN, BIAS, MOD,
  DEPTH, OUT: an initial gain plus an attenuverted modulation, replacing a
  coarse/fine level pair that could never sit half open under a patched CV.
  Five columns by five rows, 16 HP, the fifth column holding SUM and four cells
  reserved for I/O. Built as a Rack plugin in `rack/`, installed and confirmed
  loading; **not yet played.**
- **The second prototype is [Drive Filter](modules/drive-filter/SPEC.md):**
  distortion into resonant high-pass filter and resonant low-pass filter in
  a normalled series chain, from the user's 2026-09-22 description. Three
  columns by five rows, 10 HP. Output of distortion is normalled to HPF input;
  output of HPF is normalled to LPF input; patching either filter input breaks
  that normal. Built and verified with 44 headless transfer tests, installed
  into Rack with C-runtime parity checked.
- **Drive Filter came from the work laptop** on 2026-09-22: distortion into a
  resonant high-pass and low-pass in series, chained by normals, 10 HP.
  Reviewed here and corrected -- see Latest Change.
- **Break is a bench tool, not a candidate module**
  ([spec](modules/break/SPEC.md)). It feeds the other two with a drum loop and
  must not be counted in V0's function balance. It loads a WAV from disk rather
  than shipping one: the Amen recording is under copyright, and the licensed
  pack the user supplied forbids redistributing individual files.
- **Five rows is now a standing rule** ([AGENTS.md](../AGENTS.md#rules)). The
  derivation still owns the maximum (six rows, six columns); the rule fixes the
  project's choice inside it. Row pitch remains a candidate, not a verified fit.
- **New hardware work and further procurement are deferred.** The existing
  [R1 behavior](modules/io-mixer/SPEC.md) and [R5 draft](modules/boolean-clock/SPEC.md)
  inform digital prototypes without selecting physical parts or firmware.
  Musical acceptance does not replace precision, electrical, mechanical,
  physical-measurement or purchase gates.
- **Inventory and payment readiness are updated in [HOMELAB.md](HOMELAB.md).**
  Use confirmed purchases, not the old empty-bench basket. Tool suitability,
  a complete measurement setup and further spending remain unapproved.
- **Retained baseline:** the passive mult and option B attenuverter are generated,
  checked designs, not built or measured hardware. Their three reusable blocks
  are not bench-proven or a PD converter. [ORDER-READINESS.md](ORDER-READINESS.md)
  remains HOLD. M1/M2 are complete; M3 still lacks CI.
- **The sketcher remains available for control ideas.** S1/S2 are implemented;
  [SKETCHER.md](SKETCHER.md) is the guide. It produces no audio, circuit or cutting
  file. Rendered screenshot inspection remains open; S3 is deferred.
- **The two hardware inbox files are retained, unanswered and deferred:**
  [panel hardware](decisions/2026-09-14-panel-hardware.md) and
  [R5 architecture](decisions/2026-09-15-logic-module-architecture.md).
  They do not block V0. Revisit when hardware resumes or the user supplies
  answers; a recommendation, blank field or desktop implementation is not approval.

## Latest Change

- Reviewed the incoming Drive Filter and fixed three findings.
  **It could not self-oscillate**, while a code comment, a test name and its
  specification all said it could: the damping floor left it stable, so a full
  resonance impulse decayed to nothing in 80 ms, and the test only checked that
  the output stayed finite -- which a filter decaying to zero also does. The
  damping now travels past zero, bounded by the saturated feedback, with the
  constant chosen from a measured sweep. ROADMAP.md wants the filter usable as
  an oscillator, so this was a gap against stated intent, not a tidy-up.
- Removed two duplications that had appeared with the second module: the
  saturation curve (now `rack/src/Saturate.hpp`) and the whole panel grid (now
  `rack/src/PanelGrid.hpp`, with tests that all three modules place their rows
  identically). The grid mattered most: the row pitch is still a candidate, and
  it had been copied into each module with nothing to catch a divergence.
- Corrected cutoff comments that were an octave out in three places.
- Added Break, with a WAV reader written here because the SDK has none. It is
  bounds-checked against malformed input and tested against truncated, corrupt
  and overlong-chunk files, since it parses files the user chose.

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

Home laptop, 2026-09-22. Rack Free 2.6.6 Windows x64, Fundamental 2.6.4,
Rack SDK 2.6.6, MSYS2 MINGW64 g++ 16.2.0:

| Check | Result |
|---|---|
| `rack/build.sh` panel SVG parse, three panels | all parse at their expected page sizes |
| `rack/build.sh` transfer-function tests | **77 checked, 0 failed**: Quad Amp's four patch states and saturation, Drive Filter's distortion, normalled chain, normalled breaks, filter responses and resonance, the shared panel grid, the WAV reader including malformed input, and the Break engine |
| Resonance, measured rather than asserted | sustains at 1.139 V at full; decays to 0.000 V at half and just below the onset |
| C runtime parity, plugin against Rack.exe | `Rack=msvcrt plugin=msvcrt` |
| Three modules in one patch, cabled together | all three modules and widgets created, **0 fatal signals** |
| WAV reader against the user's licensed pack | four files read: 44.1 kHz, correct durations; the 174 BPM cut is 1.379 s, exactly one bar |

**No playtesting was done, and no sound was heard.** Nothing is known about how
any of these feel, whether four channels is enough, whether the self-oscillation
is loud or findable enough, or whether any of it is musically right. No
rendered panel has been inspected: the geometry is verified numerically, not
visually.

No hardware, circuit, layout, simulation or fabrication work was performed, and
no board, netlist or benchmark was regenerated. Earlier documentation checks
this day covered sequencing, inventory, payment boundaries, entry points,
preserved R1 requirements, unchanged OR-01 through OR-05 findings and verbatim
pending answer sections, plus YAML lifecycle metadata, local links and heading
anchors, document-index coverage and whitespace across the tracked Markdown.

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

**Play them.** All three load and patch together and nothing about how they feel
is known. A reasonable first patch is Break's MIX into Drive Filter's DIST IN,
Drive Filter's LPF OUT into a Quad Amp channel, and Break's ENV into that
channel's MOD -- which exercises every normalled break in one go. Load the
licensed Amen cut into Break at 174 BPM for real material.

The questions each module was built to answer are at the end of its
specification. The ones most likely to change a design:

- Is Quad Amp's `SUM` a panel jack or an inter-module bus? Still open question 1.
- Is Drive Filter's self-oscillation sliver findable, and is 1.14 V loud enough?
- Does Quad Amp's scale-and-shift mode get reached for, or forgotten?

Then save and reopen a patch with its dependencies, as
[SETUP.md](SETUP.md#vcv-rack) item 3 requires -- Break stores a sample path, so
that is worth checking deliberately. Do not resume R1 circuitry, S3 exports or
lab shopping as the default next task. Preserve the hardware review and CI
obligations for that later stage. There is no automatic work between sessions.
