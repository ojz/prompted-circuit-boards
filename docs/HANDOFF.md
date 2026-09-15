---
status: "maintained checkpoint"
owner: "the agent completing the latest task"
read_when: "starting a session, after reading AGENTS.md and checking the decision inbox"
update_when: "a validated checkpoint, blocker or next action changes; replace superseded prose"
retire_when: "the project ends or another current-state record takes over; Git is the session archive"
---

# Current Handoff

Updated 2026-09-15 by GitHub Copilot (work laptop), after recording the panel
language, direct-control policy and queued browser-only sketcher milestones.
Use [README.md](README.md) as the document register and short code map. This
handoff holds current evidence and next actions, not a session history.

## Current Position

- **Next coding task: S1, then S2 at its gate.** The user requested programming
  work for the next token window, the evening of 2026-09-16. The shared panel
  model, local HTML sketcher and later generator bridge are queued in
  [ROADMAP.md](ROADMAP.md#s1-shared-panel-model-and-checks-queued), not implemented
  or scheduled to run automatically. The editor requires no backend.
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

- The standing rules in [AGENTS.md](../AGENTS.md#rules) now record the user's
  no-menu, visible persistent-control requirement and distinguish current
  sketching work from deferred final panels. The CYCLE-switch example is an
  interface constraint, not a dynamic-state retention project.
- S1-S3 have prerequisites, deliverables and test gates, including intentional
  blank cells and portable save/reopen. There is no new HTML, layout format,
  generator input or export implementation, and no existing board was moved.
- The active hardware inbox is registered in [README.md](README.md). Its
  stale blank-answer-as-approval and finished-fit claims are corrected; all
  remaining answers are preserved. No new questionnaire, supplier research,
  parts order or hardware-release approval was introduced.

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
3. **Lab procurement:** finalize a linked, itemized assembly basket and verify the
  exact supply/manual, precision measurement method and R1 probing requirements
  in [HOMELAB.md](HOMELAB.md). Identify owned equipment before pricing adapters.
  The agent handles research; the user approves spending and reports delivery.

Close relevant [order-readiness findings](ORDER-READINESS.md) as the design uses
those blocks and implement CI before an order. S1/S2 are independent of hardware
delivery and do not authorize S3 to bypass the mechanical or native-check gates.
There is no automatic work between sessions.
