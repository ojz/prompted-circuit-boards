---
status: "maintained checkpoint"
owner: "the agent completing the latest task"
read_when: "starting a session, after reading AGENTS.md and checking the decision inbox"
update_when: "a validated checkpoint, blocker or next action changes; replace superseded prose"
retire_when: "the project ends or another current-state record takes over; Git is the session archive"
---

# Current Handoff

Updated 2026-09-14 by GitHub Copilot (work laptop), after integrating the user's
R1 answers and aligning the next work with R1 design and home-lab procurement.
Use [README.md](README.md) as the document register and short code map. This
handoff holds current evidence and next actions, not a session history.

## Current Position

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
- M1/M2 complete; M3 has pinned dependencies but no CI. Panel development and
  the final case remain deferred. P1's converter/gain blocks serve R2/R3 and
  do not block starting R1.
- **Panel hardware standard drafted 2026-09-14** (home laptop, three parallel
  research agents; findings in [MECHANICAL.md](MECHANICAL.md)): one part per
  role with stack fit, footprint and source. Two facts changed: the Alpha
  pot's "15 mm" shaft is measured from the mounting surface, so about 13 mm
  stands above the panel (was recorded as 18), and Thonk ships jacks without
  nuts or washers. **Blocking finding for R1:** no switched TRS 3.5 mm jack
  fits the stack, so the approved normalling cannot come from the world-side
  jack; the choice is in
  [decisions/2026-09-14-panel-hardware.md](decisions/2026-09-14-panel-hardware.md)
  together with 18 preference questions (knob, nuts, LEDs, toggle, USB-C
  front or back). Two repository footprints are owed before R1's layout:
  the stereo Thonkiconn and the sub-mini toggle.

## Latest Change

- The user's exact 2026-09-14 conversation answers are preserved in R1's spec
  and checkpointed in `845ac0f`. They were not invented from the blank inbox
  forms. The two answered forms are now retired; no pending question remains.
- The single document register is [README.md](README.md), with the two working
  documents first and a short explanation of the code. One spec replaces two
  questions: 21 tracked Markdown files, no parallel notes folder or new task plan.
- The lab guide now separates historical candidates from purchase-ready items,
  removes unsupported current-limit/accuracy/grounding assurances and makes
  6.35 mm cabling conditional on a chosen instrument. No fresh supplier/manual
  verification, price refresh, purchase or circuit change was performed.
- The roadmap and readiness report now point to the adopted specification.
  Answering the behavior questions does not close the engineering or order gates.

## Recovery Retained

Friday's documentation was already pushed. The work-laptop changes were saved
before fast-forwarding the nine weekend commits, then distinct SPICE refusal and
unconnected-pin escaping fixes were recovered and published as `6f1d417`.

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
| Current documentation checks | lifecycle fields, local links, approved R1 choices, retired inbox files, register coverage and whitespace checked; no code/CAD change requiring regeneration |

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

1. **R1 design:** first the user answers section 1 of the panel-hardware
  decision file (how normalling survives an unswitched stereo jack), then
  establish the complete connection diagram and verified reference
  circuits, then derive connector-level and power budgets from the approved spec.
  Propose how phone/laptop stereo playback occupies the four mono channels before
  fixing jack allocation. Preserve DC CV paths and protected consumer audio;
  do not promise phone recording through an ordinary headphone socket. Draw
  the two owed footprints (stereo Thonkiconn, sub-mini toggle) into
  `lib/footprints/` with their dimensions confirmed on a drawing or sample.
2. **Lab procurement:** finalize a linked, itemized assembly basket and verify the
  exact supply/manual, precision measurement method and R1 probing requirements
  in [HOMELAB.md](HOMELAB.md). Identify owned equipment before pricing adapters.
  The agent handles research; the user approves spending and reports delivery.

Close relevant [order-readiness findings](ORDER-READINESS.md) as the design uses
those blocks and implement CI before an order. No new questionnaire, P1 research,
router optimization or final panel work is needed to start these two tracks.
