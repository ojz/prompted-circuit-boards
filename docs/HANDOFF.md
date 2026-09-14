---
status: "maintained checkpoint"
owner: "the agent completing the latest task"
read_when: "starting a session, after reading AGENTS.md and checking the decision inbox"
update_when: "a validated checkpoint, blocker or next action changes; replace superseded prose"
retire_when: "the project ends or another current-state record takes over; Git is the session archive"
---

# Current Handoff

Updated 2026-09-14 by GitHub Copilot (work laptop), after integrating the
2026-09-13 home-laptop checkpoint. This is current state, not an append-only
diary. The roadmap owns priorities, module
specs own circuit requirements, setup owns tool versions and commands,
[MECHANICAL.md](MECHANICAL.md) owns the panel-to-board stack. See
[README.md](README.md).

## Current Position

- Two module designs exist, the passive mult and the dual attenuverter
  (option B precision circuit, simulated against every limit in its error
  budget). Neither has been built or measured.
- **The block library exists** (M4): `Block.Eurorack` (module skeleton:
  panel and board geometry from the HP count, rail holes, the panel
  project), `Block.Power` (2×5 header, series Schottkys, bulk capacitors and
  their nets) and `Block.Precision` (the buffered attenuverter channel). A
  block fixes what its parts are; a design supplies a `Placed` per part and
  merges the rails with `mergeNets`. The attenuverter is built from all
  three, the mult from the skeleton. Tests in `toolkit/test/BlockTests.hs`
  pin each block's identity.
- **M4 paperwork**: datasheet provenance with URLs and revisions is in the
  attenuverter SPEC (three parts marked unverified, see Remaining Limits);
  the mechanical stack and fit review are in [MECHANICAL.md](MECHANICAL.md);
  the first-power-up guide is
  [modules/attenuverter/POWER-UP.md](modules/attenuverter/POWER-UP.md).
- **User decisions of 2026-09-13**, taken on the session's planning page
  and recorded in the roadmap: pitch tracking limit confirmed at ±2 cents
  over 5 octaves, ±5 over 8, 15 to 35 °C; the LED driver block is dropped
  from the roadmap (LED indication is decided per board); Stage A of the
  home lab will be bought as listed (not yet bought); itemised cost and
  stock against JLCPCB was left out of this session's scope.
- Two researched decision files wait in `docs/decisions/` for R1: the
  world-side jack size and the mix semantics.
- M1/M2 complete; M3 has pinned dependencies but no CI; M4 owes cost and
  stock, input over-voltage protection and three datasheet checks by hand.
  Panel development remains deferred.

## Latest Change

Recovered workstation synchronization without rewriting published history:

- The remote already contained Friday's `fe11124` documentation checkpoint.
  Local `main` at `1ea98dc` had no outgoing commits, nine incoming commits,
  and changes in 23 tracked/untracked paths, including an untracked stability
  experiment. The committed branches had not diverged.
- Saved the full tracked and untracked work, including the retired precision
  decision's deletion, in recovery stash
  `5ca11c95875f37967d48d7d17ce067919edcec52`, named
  `recovery: work-laptop before weekend sync 2026-09-14`. A verified standalone
  bundle is retained locally at `.git/recovery-2026-09-14.bundle`. Neither
  backup was dropped or published; both remain on the work laptop.
- Fast-forwarded to `d560786`. The weekend's 100 mm boards, block-library
  refactors, four-pin reference model with noise-reduction filtering, loop-gain
  probes, eight simulation decks and newer documentation remain authoritative.
- Recovered the saved SPICE unknown-library refusal and its regression,
  retaining the newer four-pin reference mapping and output probes. The saved
  channel-2 assertion was adapted to the probe-based output. Recovered the
  PCB emitter's `{slash}` escape for unconnected pin names with a new fixture.
  Both missing behaviors were demonstrated failing before restoring their fixes.
- The saved component-validation change is already identical upstream. The
  adopted option B decision is recorded in the current SPEC; the newer two R1
  decision files remain unanswered and untouched.
- The older 47 pF compensation design, older models, peaking/overshoot deck
  and generated artifacts remain available in the recovery snapshot; they were
  not replayed over the weekend's 10 pF design and direct loop-gain tests.
  This integration does not claim equivalence of every old numerical limit or
  validate the underlying device-model assumptions anew.

## Verification

Work laptop, 2026-09-14, GHC 9.6.7 / cabal 3.14.2.0, KiCad 10.0.3,
ngspice 47, after reconciling the saved changes with `d560786`:

| Check | Result |
|---|---|
| Focused SPICE-emitter and unconnected-pin naming regressions | both fail before the recovered fixes and pass afterwards |
| `cabal test --test-show-details=direct` | 82/82 passed, including the weekend's block tests and both recovered behaviors |
| `toolkit/pipeline.sh attenuverter` | regeneration matches the weekend project/report; module and panel ERC/DRC/parity and renders pass; `check.ok` written |
| `toolkit/sim.sh attenuverter` | 8 decks, 0 failed, using the current block-built netlist |
| `toolkit/test-scripts.sh` | 79 passed, 0 failed; native checks, scratch export/refusals, simulator stubs and report checks |

Not rerun: the mult's native pipeline, the full benchmark, field-solver and
`nodebudget.py` checks. The mult's last native pass is the home-laptop
checkpoint on 2026-09-13. The script suite's fabrication export is a disposable
control, not a manufacturing release. No physical measurement was made.

## Remaining Limits

- Simulated, not measured; the model limits in the attenuverter SPEC stand.
  The mechanical stack is read from drawings and not yet from a built board;
  the pot bodies set a 10 mm panel gap and the jack bushings stop 1 mm short
  of the panel, which the first build must confirm is acceptable.
- Three datasheets could not be fetched as documents from this workstation
  and are marked **unverified** in the SPEC: the JSCJ B5819W (LCSC viewer
  only), Yageo's RT thin-film series (script-rendered site, distributor
  mirror timed out) and Samsung's per-part page. The figures used come from
  LCSC listings; the Yageo tolerance and tempco enter the error budget, so
  check them by hand before an order.
- The power-up guide has never been performed; its expected readings are
  datasheet arithmetic and its supply procedure assumes the Rosfix pair from
  HOMELAB.md.
- Input over-voltage protection is not designed in. CI on a runner with
  KiCad 10 is still owed by M3.
- The router depends on pad order within a net: the weekend's power-block
  refactor changed routing without changing the circuit. Keep that limitation
  in mind when interpreting byte-identity checks across structural refactors.

## Next Action

**P1, the exponential converter**: the matched-pair device model with
thermal coupling in `modules/_models/devices.lib`, a temperature-sweep deck
that reports tracking in cents against the confirmed limit (±2 cents over
5 octaves, ±5 over 8, 15 to 35 °C), the reference-design survey the
proven-circuit rule requires, and the bench calibration procedure. It has
no board yet; its first consumer is R2.

For the user: answer the two R1 decision files in `docs/decisions/`, and
buy Stage A of [HOMELAB.md](HOMELAB.md) when convenient, confirming the
supply's floating output on its product page first.
