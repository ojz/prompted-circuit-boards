---
status: "maintained checkpoint"
owner: "the agent completing the latest task"
read_when: "starting a session, after reading AGENTS.md and checking the decision inbox"
update_when: "a validated checkpoint, blocker or next action changes; replace superseded prose"
retire_when: "the project ends or another current-state record takes over; Git is the session archive"
---

# Current Handoff

Updated 2026-09-13 (evening) by Claude Fable 5.1 (home laptop). This is
current state, not an append-only diary. The roadmap owns priorities, module
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

Four checkpoints on 2026-09-13, one per item:

1. **Skeleton.** Both designs and both panels carried their own panel
   arithmetic; `Block.Eurorack` owns it now. Regenerating all five projects
   changed no generated file.
2. **Power entry.** `Block.Power` plus `Design.Placed` and `Design.mergeNets`.
   The schematic was identical up to the order of five symbols. The board
   re-routed to an equivalent solution because the pad order within the
   rail nets changed and the router's tie-breaks with it (745 mm of copper
   against 752, 23 vias against 22, no contested cells, no findings). Worth
   knowing: **the grid router's result depends on pad order within a net**,
   so a reorder of parts can move copper without changing the circuit. Not a
   defect, but it weakens byte-identity as a regression check; a canonical
   pad order in the router would restore it.
3. **Precision channel.** `Block.Precision`. Board identical to the previous
   checkpoint up to line order; schematic differs only in the sheet note,
   which had still said 100k where the design has been 10k since the
   option B decks.
4. **Paperwork**: provenance, mechanical stack, power-up guide, roadmap and
   this handoff, two R1 decision files.

## Verification

Home laptop, 2026-09-13, GHC 9.6.7 / cabal 3.18.1.0, KiCad 10:

| Check | Result |
|---|---|
| `cabal run -v0 pcbgen -- all` after the skeleton | all five projects regenerated, no file changed |
| `cabal test` | 80/80 passed (65 before this session; 15 block tests added) |
| `toolkit/pipeline.sh attenuverter` | module and panel: ERC clean, DRC clean with schematic parity, renders, `check.ok` written; not exported |
| `toolkit/pipeline.sh mult` | module and panel clean; not exported |
| `toolkit/sim.sh attenuverter` | 8 decks, 0 failed, on the netlist generated from the block-built design |
| Sorted-line comparison of the generated files against the previous commit | skeleton: identical; power: schematic identical, board re-routed; precision: board identical, schematic note corrected |

Not rerun: `toolkit/test-scripts.sh`, the benchmark, the field-solver and
`nodebudget.py` checks (inputs unchanged). No manufacturing release or
physical measurement was made.

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
