# Session Handoff

The tracked state the roadmap's "Weekly Session Contract" refers to. Newest
session first. Each entry records what was actually run, what passed, what was
**not** run, and the next action with its prerequisites. Read this after
`ROADMAP.md` and before choosing work.

---

## 2026-09-10, session 5: the negotiation had no memory

Parity measurement paid for itself: chasing the via-count gap Freerouting
exposed found a real defect in our implementation of negotiated congestion.

### What was run

- `pcbgen sweep-via`, a new subcommand: the grid router priced from 10 to 320
  cells per via, every benchmark board, printed and not committed (a sweep
  answers a question once; the answer belongs in the default). `--costs` sets
  the ladder and `--iters` the negotiation budget, because a cost that leaves
  contested cells has either steered the search into a bad basin or merely run
  out of rounds, and only moving the budget separates the two.
- The first sweep showed legality flipping on and off as the via cost moved:
  the `reversal` fixture was legal at 25 and 40, illegal at 15, 30 and 320.
  `--iters 2000`, ten times the budget, did not fix either failing cost. That
  is a stall, not slow convergence.
- Cause, in `Route/Router.hs`: present congestion grows as `1.4^round` while
  history congestion accumulated a flat `+1` per round, so by round 200 the
  present term was about 10^29 and history at most 200. History was
  arithmetically irrelevant, the negotiation had no memory, and two nets
  simply traded places forever. McMurchie & Ebeling's convergence argument
  needs a cell that has been fought over to stay expensive after it falls
  free. History is now charged in the same currency as present congestion
  (`+pres` per round), and the exponent is capped at 500 because `1.4^2100`
  overflows a Double to infinity and would poison every cost in the array.

### Results

- The sweep went from 11 of 17 legal to **24 of 24**: every via cost from 10
  to 320 now converges on every board.
- On `route-test`, at the unchanged default via cost, **27 vias and 717.67 mm
  became 7 vias and 698.69 mm**. Freerouting scores 6 vias and 690.79 mm on
  the same board, so the via gap closed from 4.5x to 1.17x and the copper gap
  from 3.9% to 1.1%. The gap was never a mistuned via cost; it was thrashing,
  and thrashing spends vias.
- The remaining `reversal` failure at cost 18 now responds to budget (600
  rounds settle it), which is the behaviour the algorithm promises and did not
  previously have. The default budget is raised from 200 to 600; the loop
  exits as soon as nothing is contested, so boards that settle early (every
  real module, in 1 to 25 rounds) pay nothing for it.
- `attenuverter` and `route-test` were regenerated and both pass ERC and DRC
  with schematic parity, as do both panel projects. `mult`'s copper is
  byte-identical. `cabal test` is 47 of 47, including a new regression test
  that `reversal` converges at the two via costs that used to stall.

### Decided not to do, with the reason

- **The via cost stays at 40.** After the fix no value is undominated
  everywhere: 40 gives the fewest vias on `route-test` and is beaten on both
  axes by 25 and 30 on the attenuverter and on `reversal`, while 20 wins
  `route-test` and then spends 51 vias on `reversal` where 25 spends 9. That
  spread is too wide to tune against five boards without fitting noise, and
  nothing yet prices a via against a millimetre of copper. It waits for the
  objective, not for a better guess.

### Not run, not done, not proven

- ngspice is still not installed. KiCad ships only `ngspice.dll` for its
  internal simulator, there is no batch executable, and it is not in winget,
  so it needs a download from the ngspice site.
- The via-count spread at fixed cost on `reversal` (51 at cost 20, 9 at cost
  25) is large enough to suggest the search is still unstable even with the
  negotiation fixed. Not investigated.
- Whether Freerouting can be made to respect an unbonded pour is still open,
  so the attenuverter comparison is still void: it leans on the ground plane
  and leaves GND in two islands.
- Nothing in this session touched the objective, the analog intent, or M4.
  M3's CI and dependency pinning are still owed.

### Next action

**The objective.** Install ngspice, then declare per-net analog intent in the
design (a length budget on high-impedance nodes, control-voltage and audio
separation, channel symmetry) and add those terms to the score. Search quality
is now close enough to a mature router that further search work is catch-up;
an analog-aware cost function is the part nobody else is doing, and it is also
what would let the via cost be chosen rather than guessed.

---

## 2026-09-10, session 4: parity against Freerouting

Installed, outside the repo: Freerouting 2.4.1 as a plain jar in
`%LOCALAPPDATA%/freerouting` (sha256 251101c3eeac22d7e7dfcf6796603279e5d1000283eb82d8f093780f7afc6aa9),
driven by the Temurin 25 JRE already on PATH. Its telemetry and contact flags
were **turned off** in `%APPDATA%/freerouting/freerouting.json` before it was
ever run, since it defaults to on and this is the user's board data; the
original is kept as `freerouting.json.bak-before-claude`.

`toolkit/freeroute.py` does the Specctra round trip through KiCad's own
`ExportSpecctraDSN` / `ImportSpecctraSES`, so nothing here parses DSN or SES.
`Bench.freeroutingRouter` writes the design out with the autorouter switched
off, hands the board over, and reads the copper back. Nothing in `modules/` is
ever produced this way.

`Bench.Strategy` changed shape: a design in, copper out, so an in-process
router and a subprocess both fit. The harness now verifies whatever copper
comes back with our own checks, which is how every finding below was caught.

### The parity picture

| Board | Our router | Freerouting | Reading |
|---|---|---|---|
| route-test, 21 nets | legal, 27 vias, 717.67 mm | legal, **6 vias, 690.79 mm** | The fair comparison, and Freerouting wins it clearly: 4.5x fewer vias |
| mult, 2 nets | legal, 159.62 mm | legal, 162.42 mm | Ours marginally shorter |
| reversal, 20 crossing nets | legal, 18 vias | **left /X1 unrouted** | Ours complete, theirs shorter on what it did route |
| attenuverter, 16 nets | legal | **GND not one island** | Not comparable: it leaned on the ground plane, which this design deliberately does not bond to pads. Its 0.86 detour is missing copper, not a win |
| pinch-wide, 0.25 mm corridor | **legal** | produced nothing | Ours finds a tight but ordinary corridor; Freerouting does not |
| pinch, 0.04 mm corridor | produced nothing | produced nothing | Neither. Completeness is a property no router here provides |

Summary: Freerouting is markedly better at via economy on an ordinary
congested board. Ours is more complete, and more honest about failing. Neither
is dominant, and the pour behaviour means any future comparison has to control
for what the plane is allowed to do.

### Other changes

- The project file's default net class now advertises the width copper is
  actually laid at (0.3 mm) instead of the DRC minimum (0.2 mm). They differed,
  and an external router reads that number, so the first comparison was unfair
  in our favour. Only `.kicad_pro` files changed.
- `pinch-wide` added as the practically-sized half of the completeness pair.
  `pinch` is now documented as a theoretical probe: no fab holds 0.04 mm, so a
  board needing that corridor could not be built anyway.
- `Route.Extract.copperOfBoard` reads tracks and vias back out of a board file.
  Arcs are reported as their chord; nothing we drive emits them today.

### Not run, not done

- ngspice is still **not installed**. KiCad ships `ngspice.dll` for its own
  simulator but no batch executable, and it is not in winget, so it needs a
  download from the ngspice site. Nothing analog has been measured.
- The objective still scores only length, vias and detour.
- Freerouting ran at 10 passes and one thread, its defaults untuned. A tuned
  run might do better still; nobody has tried.
- Whether Freerouting can be made to respect an unbonded pour is unknown, and
  that is the blocker for a fair attenuverter comparison.
- Still owed from M3: CI, dependency pinning.

### Next action

**The objective.** Install ngspice, then declare per-net analog intent in the
design (length budget on high-impedance nodes, control-voltage separation,
channel symmetry) and add those terms to the score. The via-economy gap
Freerouting just demonstrated is the other obvious thread: 27 vias against 6
on the same board suggests our via cost of 40 cells is badly tuned, and that is
a one-line experiment the harness can now settle.

## 2026-09-10, session 3: routing benchmark (rung 0) and the research direction

### Direction agreed with the user

Chase: topological routing, an analog-aware objective, joint placement and
routing, and evolving the heuristic as programs. Maybe: an exact optimum,
Lean proofs. Parked: learned models. Start with the benchmark. Most of a
weekly session for a few weeks, timeboxed. Pair mode: explain the algorithm,
decide together, then the agent writes it.

Two hard constraints came out of it and are now in memory:

- **No model in the generation loop.** The generator's input is the netlist
  plus declared constraints. A model may search for heuristics offline; none
  ever chooses where a component goes.
- **Front panels are deferred.** The modules bench-test without them and the
  panel art is a separate project. Existing panel projects stay and keep
  passing checks; nobody invests in them.

The user also corrected my framing on the exact solver, correctly: JLCPCB does
not charge by trace length, so an optimum measured in millimetres optimises a
quantity nobody pays for. The ruler survives for two other questions, namely
whether a legal board was findable at all and later optimality against an
objective that has analog terms in it. It moves behind the objective work.

Their own decomposition (represent the objective, split it, solve pieces,
score, merge, mutate, with ant colony / annealing / genetic search over the
top) maps onto global-versus-detailed routing, which is the standard two-level
split in this field and something our flat router does not do at all. Merging
independently-legal pieces at region boundaries is the known crux.

### What was built

`toolkit/src/Bench.hs`: a router is a `Strategy` (record of functions, `IO`
so an external tool can be one), a score is a vector of eleven measurements
and never a weighted total, and the report prints all of it without declaring
a winner. `cabal run pcbgen -- bench` writes `BENCH.md`, committed so quality
changes show in a diff. `modules/_bench/BenchFixtures.hs` holds two synthetic
fixtures, never emitted as projects.

### Two findings from the first run

| Finding | Evidence |
|---|---|
| The negotiation budget was too low, and it was a real bug | The 20-net `reversal` fixture left 7 contested cells at the old 40-round cap and settles cleanly at 200, with fewer vias (18 vs 20) and slightly less copper. Default raised to 200; the loop still exits as soon as nothing is contested, so every real board pays nothing. Generated files byte-identical after the change. |
| The 0.2 mm grid costs completeness, now quantified | The `pinch` fixture has one legal path about 0.04 mm wide. The grid cannot see it at any budget, partly because no cell centre lands in the band and partly because the grid refuses cells within 0.8 mm of a board edge. It is expected to fail and a test asserts that; a router that routes it is an improvement and the test should then be flipped. |

### Commands run, with results

```
cabal build                      exit 0
cabal run pcbgen -- bench        exit 0   5 boards, 4 legal, 1 expected fault
cabal run pcbgen -- all          exit 0   0 tracked files changed (deterministic)
cabal test                       45/45 tests passed
toolkit/check.sh attenuverter    exit 0
toolkit/check.sh mult            exit 0
toolkit/check.sh _tests/route-test  exit 0
```

### Not run, not done

- No new fixture beyond the two. A dense repetitive board (a fixed filterbank
  was the user's suggestion, and it is the best of them for this) would stress
  density and symmetry together, and belongs with the objective work.
- Freerouting is not wired in as a strategy yet, though the user approved it
  and the `Strategy` slot exists for it.
- The objective still scores only length, vias and detour. Nothing analog.
- Everything M3 still owed is still owed: CI, dependency pinning, headless
  SPICE. The user has approved installing SPICE and Python and wants a
  Dockerfile eventually, but not yet.
- An adaptive stopping rule would beat a fixed 200-round cap; not attempted.

### Next action

**Rung 2, the objective.** Declare per-net analog intent in the design
(length budget on high-impedance nodes, separation between control voltage and
audio, symmetry between channels) and add those terms to the score, then
install ngspice and check the routed board against extracted parasitics.
Expect the current router to score worse at first; that is the objective
becoming honest. Prerequisite: none, the harness is in place.

## 2026-09-09, session 2: M1 and M2 closed, M3 partly

Commits: `6ffcdb6` design model and empty test suite, `7c9e2b5` the work below,
`4f2ea64` this file and the roadmap status, `fea9a34` the pre-fix confirmation.

### What now holds

| Claim | Evidence |
|---|---|
| Invalid designs are rejected before emission | `toolkit/src/Validate.hs`; `cabal test` 40/40; an invalid design exits 1 and leaves every generated file byte-identical (verified by hashing before and after) |
| The four wiring faults ERC accepted now fail | tests name the pin: `U1.8` removed, `U1.88` mistyped, `U1.8` on both rails, `D2.1` dropped |
| No via sits in or against a pad | `Route.Check.viaPadViolations` recomputed on emitted geometry; both boards report 0; generation aborts otherwise |
| The roadmap's four via-in-pad locations were real | The checker run against the pre-fix board (commit `1ede48e`) reports exactly 4 violations, at `R4.1`, `R3.2`, `C4.2` and `C1.2`, overlapping by 0.30 to 0.45 mm. All four were same-net vias, which is why neither the router nor KiCad objected |
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

- The checker's ability to catch real violations is otherwise covered by
  synthetic tests only; the pre-fix board is not committed as a fixture.
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
