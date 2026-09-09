# Session Handoff

The tracked state the roadmap's "Weekly Session Contract" refers to. Newest
session first. Each entry records what was actually run, what passed, what was
**not** run, and the next action with its prerequisites. Read this after
`ROADMAP.md` and before choosing work.

---

## 2026-09-09, session 2: M1 and M2 closed, M3 partly

Commits: `6ffcdb6` (design model, empty test suite), `7c9e2b5` (the work below).

### What now holds

| Claim | Evidence |
|---|---|
| Invalid designs are rejected before emission | `toolkit/src/Validate.hs`; `cabal test` 40/40; an invalid design exits 1 and leaves every generated file byte-identical (verified by hashing before and after) |
| The four wiring faults ERC accepted now fail | tests name the pin: `U1.8` removed, `U1.88` mistyped, `U1.8` on both rails, `D2.1` dropped |
| No via sits in or against a pad | `Route.Check.viaPadViolations` recomputed on emitted geometry; both boards report 0; generation aborts otherwise |
| A hand-drawn trace cannot fake a finished net | pre-routed copper is one terminal per island; synthetic island test plus per-net connectivity check |
| Export cannot come from stale or failed input | `check.ok` hashes; `toolkit/test-scripts.sh` 42 passed, 0 failed |

### Commands run, with results

```
cabal build                              exit 0
cabal run pcbgen -- all                  exit 0
cabal test                               40/40 tests passed
toolkit/check.sh attenuverter            exit 0   ERC clean, DRC clean (parity included)
toolkit/check.sh attenuverter panel      exit 0   clean
toolkit/check.sh mult                    exit 0   clean
toolkit/check.sh mult panel              exit 0   clean
toolkit/check.sh _tests/route-test       exit 0   clean
toolkit/pipeline.sh mult                 exit 0   all rows PASS (fab SKIPPED, no --fab)
toolkit/pipeline.sh attenuverter --fab   exit 0   all rows PASS, 16 placements
toolkit/test-scripts.sh                  exit 0   42 passed, 0 failed
```

Tool versions: kicad-cli 10.0.6, KiKit 1.8.1, KiCad python 3.11.5, GHC 9.2.8,
cabal 3.6.2.0. Attenuverter routing after the change: 202 segments, 8 vias
(was 6), 690.74 mm total (was 704.98), detour 1.10, 0 via/pad violations, 0
disconnected nets.

### Judgement calls a human may want to overturn

1. **The attenuverter's GND pours no longer bond to pads** (`PadsUnbonded`).
   The stricter via rule changed the routing, which left one pot lug with a
   single thermal spoke where KiCad demands two. Since every net including GND
   is routed as copper, the pours are redundant shielding, so they now stay off
   the pads entirely. DRC still reports 0 unconnected items, and validation now
   rejects an unbonded pour on a net nothing routes. The alternative, lowering
   KiCad's spoke minimum, was tried first and rejected: a `min_resolved_spokes`
   custom rule has no effect because the zone's own setting wins.
2. **The mult keeps thermal relief** because its jack sleeves are connected by
   the pours alone. Unbonding them stranded 11 items; that mistake is what the
   new `unbonded-pour-unrouted-net` check exists to catch.
3. **A via is forbidden in a pad of its own net too.** Ordinary assembly cannot
   have a drill in a solder land, and KiCad's DRC does not object, which is why
   the four historical violations survived.

### Not run, not done, not proven

- The roadmap's claim of four specific via-in-pad violations (`C1.2`, `C4.2`,
  `R3.2`, `R4.1`) was **not** reproduced against the old router. The old board
  had 6 vias and the new checker reports none on the new one; the checker's
  ability to detect real violations is covered by synthetic tests only.
- `toolkit/fab.sh <name> panel` has never been run. No panel gerber bundle exists.
- M3's remaining items are untouched: CI, pinned or reproducibly retrieved
  dependencies, headless SPICE, and removing reliance on globally installed
  agent skills.
- `fabcheck.py`'s warning for "board carries LCSC parts but the CPL is empty"
  is code only; neither fixture reaches it.
- KiKit's own DRC stays off (`--no-drc`): it crashes KiCad 10's bindings.
  `kicad-cli pcb drc` is the authoritative gate.
- No electrical evidence of any kind was added. No datasheet audit, no SPICE
  run, no measurement. M4 has not started.
- `modules/mult/mult.kicad_pro` is untracked and was already there before this
  session; nobody has established what it is.

### Next action

**M2 leftovers, then M3's reproducibility items.** Concretely, the smallest
useful next slice: decide whether the router should aim for fewer vias now that
the via rule is strict (8 vias on a 28 mm board is workable but worth a look),
then add CI that runs `cabal test` and the fixture checks on a clean checkout.
Prerequisite for CI: deciding where it runs, since KiCad 10 and its libraries
must be available to the test suite.

Do not start M4 until someone decides whether the attenuverter is the vehicle
for it, and do not order anything: no purchase has been approved.
