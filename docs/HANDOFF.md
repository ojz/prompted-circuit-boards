---
status: "maintained checkpoint"
owner: "the agent completing the latest task"
read_when: "starting a session, after reading AGENTS.md and checking the decision inbox"
update_when: "a validated checkpoint, blocker or next action changes; replace superseded prose"
retire_when: "the project ends or another current-state record takes over; Git is the session archive"
---

# Current Handoff

Updated 2026-09-21: VCV Rack-first direction and inventory update; documentation
only, with no new digital module, circuit, layout or manufacturing output.
Use [README.md](README.md) as the document register and short code map. This
handoff holds current evidence and next actions, not a session history.

## Current Position

- **Current work is V0: play before building.** Build digital versions of the
  candidate modules in VCV Rack, then test the balance of VCAs, LFOs, envelopes,
  voices and utilities through real patches and user playtesting. The earlier
  five-board composition is the starting hypothesis, not a fixed resource count.
  [ROADMAP.md](ROADMAP.md#v0-playable-digital-modules-and-function-balance-current)
  owns the sequence and musical acceptance gate.
- **Rack installation is user-reported; prototype verification is still ahead.**
  [SETUP.md](SETUP.md#vcv-rack) records what needs checking at the first prototype
  session. No project-specific Rack prototype was built or tested in this update.
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

- Recorded the user's 2026-09-21 direction in the standing rules and roadmap,
  and aligned the entry points, setup, module specifications and order path.
- Recorded confirmed equipment purchases and available payment in the existing
  inventory without inventing models, capabilities, costs or purchase approval.
- Preserved pending answer sections and existing approved R1 behavior; marked
  physical decisions as deferred. No new questionnaire or empty project scaffold.

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

2026-09-21: focused documentation checks passed for sequencing, inventory,
payment boundaries, entry points, preserved R1 requirements, unchanged OR-01
through OR-05 findings and verbatim pending answer sections. Parsed YAML
lifecycle metadata, local links and heading anchors, complete document-index
coverage and whitespace checks passed across the tracked Markdown documents.
Only documentation changed. No VCV Rack playback, plugin build, hardware test
or regeneration was performed for this update.

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

**Build the first playable VCV Rack prototype.** Establish the installed
version and available plugins, map the candidate behaviors to digital modules
or documented stand-ins, and save/reopen a voice patch with a VCA, envelope,
independent LFO and mix/output path. Count actual concurrent function use and
let the user play it before expanding into V0's representative instrument tests.

Use observations to agree the behavior and composition that should become
hardware. Do not resume R1 circuitry, S3 exports or lab shopping as the default
next task. Preserve the hardware review and CI obligations for that later stage.
There is no automatic work between sessions.
