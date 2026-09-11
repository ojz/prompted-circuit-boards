# Session Handoff

The tracked state the roadmap's "Weekly Session Contract" refers to. Newest
session first. Each entry records what was actually run, what passed, what was
**not** run, and the next action with its prerequisites. Read this after
`ROADMAP.md` and before choosing work.

---

## 2026-09-11, session 9: work-laptop validation (GitHub Copilot)

Pulled Fable's work with `git pull --ff-only`: 12 commits from `1ede48e` to
`b9b5a2b`, a clean fast-forward with no local commits waiting to push. Read
`HANDOUT.md` and reproduced the existing validation on the work laptop.
The user's priority remains validation while payment cards and hardware are
unavailable. No circuit, routing objective, part choice or panel design changed.

### Software and reproducibility

Installed ngspice 47's console build at
`%LOCALAPPDATA%/ngspice/Spice64`, matching the home-laptop archive's SHA-256:
`59225971bd68cdd1199443649aa4615a9e6d684933f205ab49006a3942518f5a`.
SourceForge returned HTML with HTTP success to ordinary downloads; curl with
the `Wget/1.21.4` user agent retrieved the correct archive. The rejected
downloads were never extracted or executed. `SETUP.md` records the working
download command and the requirement to check its hash.

Existing tools needed no upgrades: KiCad CLI 10.0.3, GHC 9.6.7, cabal
3.14.2.0, KiKit 1.8.1, KiCad Python 3.11.5 and NumPy 2.4.2. Despite the
different KiCad patch and GHC versions at home, both module pipelines
regenerated exactly the committed content after Git's line-ending
normalization, including their existing panels.

### A false simulation pass, reproduced and fixed

`NGSPICE=/usr/bin/false toolkit/sim.sh attenuverter` reported **six decks,
zero failures**, despite the substituted simulator exiting 1 without running
anything. The runner scanned error text but ignored process status, and also
accepted successful processes that printed no assertions.

`toolkit/sim.sh` now requires a successful process, no recognized error
diagnostics, assertion output from every executed deck, and at least one
experiment deck. `toolkit/test-scripts.sh` adds isolated stub tests for a
nonzero exit even after printing PASS, empty output, an error with exit 0,
an explicit FAIL, a valid PASS, and no experiment decks. These add 12 checks
to the existing 42. Real ngspice still passes all six attenuverter decks.

### Commands run, with results

| Command | Result |
|---|---|
| `cabal build all` | exit 0; compiler warnings remain |
| `cabal test --test-show-details=direct` | 65/65 passed |
| `toolkit/pipeline.sh attenuverter` | regeneration matches; board and panel ERC/DRC/parity clean; renders pass; export skipped |
| `toolkit/pipeline.sh mult` | regeneration matches; board and panel ERC/DRC/parity clean; renders pass; export skipped |
| `toolkit/check.sh _tests/route-test` | ERC/DRC/parity clean; renders pass |
| `toolkit/test-scripts.sh` | 54 passed, 0 failed after the fix; includes a successful scratch export and all refusal cases |
| `toolkit/sim.sh attenuverter` | 6 decks, 13 assertions, 0 failed after the fix |
| `python toolkit/nodebudget.py verify` | closed form vs ngspice: worst difference 0.2% |
| `python toolkit/xsection.py verify --pitch 0.025` | exit 0; worst difference 7.4%, 5.9% at 0.3 mm trace width |

Shell scripts were run with Git Bash, not the WSL `bash` on this machine's
PATH. Both Python commands used KiCad's bundled interpreter. Native reports,
renders and `check.ok` manifests are in each project's ignored `build/`
directory, with panel results under `build/panel/`. The Cabal test log is in
`dist-newstyle/build/x86_64-windows/ghc-9.6.7/pcbgen-0.1.0.0/t/pcbgen-test/test/`.

SHA-256 of this run's artifacts (filled boards are KiCad-version-specific):

| Artifact | SHA-256 |
|---|---|
| `modules/attenuverter/build/attenuverter.kicad_pcb` | `a0d681edb2584c6cadb99a9388eb325b04898df8e1b1b622f197036b77b42b10` |
| `modules/mult/build/mult.kicad_pcb` | `0838974db2ab529ac17e138bbf1fb7afb91d5f44c26b490bc8c6ea7dce1e29fe` |
| `modules/attenuverter/sim/attenuverter.cir` | `220bcae4dfc813f2198f468c12f1de0c9afd5370940a1739a94998b97916824d` |

### Not run, not done, not proven

- No manufacturer-datasheet audit, new EMC/thermal review, mechanical-fit
  review, sourcing/stock check, purchase, assembly or physical measurement.
- The roughly 0.35 V headroom is a nominal model result, not a guaranteed
  supply/load/temperature envelope. The existing supply-corner assertion uses
  a 5 V signal; it does not prove +/-10 V headroom at the low-supply corner.
  Load current, overload/protection and temperature remain model limitations.
- The full-resolution `xsection.py verify` run was stopped after more than
  12 CPU-minutes without completing its first width. The 0.025 mm check above
  passed; a full refinement/convergence study was not repeated.
- Freerouting parity benchmarks were not rerun. The new standalone default
  jar location and `FREEROUTING_JAR` are not configured on this laptop; the
  previously installed KiCad plugin is not part of these checks.
- No retained manufacturing bundle was produced. The fault suite's successful
  export was a disposable control; its scratch files were removed on exit.
- M3 still owes CI and dependency/library pinning. The mult still has no
  simulation decks. The user subsequently gave standing authorization to
  commit and push validated checkpoints routinely; that rule is recorded in
  `AGENTS.md` and `ROADMAP.md`.

### Follow-up: language choice and voltage explanation

The user asked whether the Python helpers meant Haskell was the wrong
foundation. Recommendation: retain Haskell for the circuit source of truth,
validation, generation and routing; use Python for concrete integration or
scientific-library needs such as pcbnew and NumPy. No language migration was
requested or performed. Python's ecosystem is useful, but a rewrite would
not establish electrical correctness or address the current evidence gaps.

The attenuverter spec now distinguishes nominal output headroom from gain,
explains the shared-reference shift as about +4.67 V to +4.71 V in the untouched
channel, and qualifies the low-supply result as a 5 V test. It also corrects
"measured" to "simulated". A 41.8 mV shift corresponds to about 50 cents at
1 V/octave, so the deck's 50 mV acceptance budget is not automatically adequate
for precision pitch use. No component or acceptance threshold was changed.

### Next action

Build the attenuverter's exact-part and datasheet evidence record: identities,
source URLs/document versions, pin-to-package mapping, ratings and the
supply/load conditions behind the headroom assumption. Prerequisites are the
existing design and access to manufacturer documents, not a payment card.
Then choose meaningful corner checks and a short mult simulation pass. Any
circuit change to widen headroom remains the user's decision. Keep panel art
and purchases deferred, and close CI/pinning before calling M3 complete.

---

## 2026-09-11, session 8: the first electrical evidence

The roadmap's timebox on routing research had run out and module work had
stalled: two modules, none new, four sessions of toolkit. M4's circuit
evidence is the next gate and the ngspice work made one of its bullets cheap,
so this session took it. The attenuverter now has simulated evidence where it
previously had arithmetic in a spec file and nothing else.

### The netlist is generated, the experiment is not

`Emit/Spice.hs` writes a SPICE netlist from the same `Module` the board comes
from. That is the whole point: a hand-written deck can quietly describe a
different circuit than the one being fabricated, and then every result is
about a circuit nobody is building. Topology comes from `modNets`, values
from `partValue`, and the generator refuses rather than guesses -- on a part
it cannot model, on a value it cannot read, and on two nets that would become
the same SPICE node.

What is hand-written is the experiment: decks in `modules/<name>/sim/` that
`.include` the netlist and echo PASS or FAIL. `toolkit/sim.sh <name>`
regenerates the netlist, runs every deck and fails closed; tightening a
tolerance until a deck fails was checked to produce exit 1.

Device models are in `modules/_models/devices.lib`, hand-built from datasheet
figures rather than taken from vendor files. That was a choice: every
parameter can be traced to a published number, which is what M4 asks for, and
there is no redistribution question. The cost is that the models capture only
what they were built to capture, and that list is written at the top of the
file.

### What the simulation says about the attenuverter

Six decks, thirteen assertions, all passing:

| Question | Answer |
|---|---|
| Does `Vout = (2k-1)*Vin` hold? | within 6 mV across the rotation |
| Does +/-10 V full scale fit? | yes, just: clipping at +10.34 and -10.37 V |
| What is the offset reference? | **4.67 V, not the 4.8 V in the spec** |
| Do the channels interact? | **yes, 41.8 mV when one is patched** |
| What does a load cost? | 0.99% into 100k, 1.96% into 50k, 9.1% into 10k |
| Will the knob null at centre? | -44 to +55 mV on 5 V in, with 1% resistors |
| Does matching affect the gain? | not at k=1, where it cancels exactly |
| Does a 10% low supply matter? | not to the signal; the reference drops to 4.22 V |
| Does it keep up at 20 kHz? | amplitude error 0.05% |

The 6 mV is not slop. It is the op-amp's 3 mV input offset at a noise gain of
2, which is exactly what the circuit should do, and seeing the expected number
come out is the reason to trust the rest.

**The offset reference is wrong in SPEC.md.** The spec said 4.8 V, from
12 V through a 1.5k/1k divider. The circuit produces 4.67 V, because the
series Schottky drops the rail to 11.84 V and the two channels' pots and
input resistors load the divider. Nothing depends on the exact value -- it is
an offset knob -- but a spec should carry the number the circuit produces.
Corrected, with the reason.

**Patching one channel moves the other by 41.8 mV.** SPEC.md already flagged
the shared supply-derived offset as a risk; this measures it. Inserting a
plug lifts that channel's loading off the divider, the reference rises, and
the other channel's idle output follows at full gain. Under the 50 mV budget
written into the deck, but not by much, and it is the only cross-channel
interaction this circuit has.

**Headroom is 0.35 V.** Full-scale Eurorack is +/-10 V and clipping starts at
about +/-10.35 V. It passes, with less margin than one might assume.

### Five bugs, all found by disbelieving a result

Two in the generator, both producing netlists that read perfectly well:

- `+12V` and `-12V` both scrubbed to `_12V`, so **the supply rails were one
  node** and the op-amp had V+ and V- shorted together. Found by reading the
  emitted file. Signs now survive scrubbing, and `nodeCollisions` refuses any
  design where two nets would still land on one node.
- Diodes came out reversed. KiCad numbers a diode's **cathode 1 and anode 2**
  -- checked in `Device.kicad_sym` rather than assumed -- and SPICE wants the
  anode first. Both protection diodes were backwards and the netlist
  simulated happily.

Two in the decks, both of which produced a confident FAIL that was not real:

- `reset` starts a new ngspice plot, so vectors captured before it are gone.
  The "idle" baseline was reading as zero and the interaction test failed by
  4.7 V. Values now go into shell variables, which survive.
- The patch-cable source was wired to the jack tip unconditionally, so with
  the normalling switch closed it drove the shared reference to 5 V through a
  milliohm. A plug does two things at once and the deck has to do both: open
  the switch *and* connect the source.

The second pair is the more interesting one. A failing test that agrees with
a suspicion is the easiest thing in the world to believe.

A fifth bug, and the most instructive, was in what a test measured rather
than in how it ran. The transient deck first compared the output against the
input instant by instant and failed at 137 mV. That number is real and it is
almost entirely **phase lag**: 3 MHz of gain-bandwidth in a noise-gain-of-2
loop puts the closed-loop pole near 1.5 MHz, which is 0.8 degrees at 20 kHz,
and 0.8 degrees on a 10 V sine is 130 mV of instantaneous difference while
the amplitude is untouched. Asserting on it would have been demanding that a
utility module be phase-linear to a fraction of a degree. The deck now
measures amplitude, which is what "keeps up with audio" means, and reports
the phase figure beside it.

### Not run, not done, not proven

- **Nothing has been measured.** No board built, nothing probed. Every number
  above is a model.
- The op-amp model draws quiescent supply current but does **not** draw load
  current from the rails, so nothing here is evidence about power consumption
  under load -- one of M4's explicit bullets.
- Output overload is a clamp, not an output stage. Where clipping starts is
  meaningful; what happens past it, including JFET-input phase inversion, is
  not modelled at all.
- The mult has no simulation. It is passive, so there is less to learn, but
  "less" is not "nothing": its jack normalling and the pours are worth a look.
- M4's non-simulation bullets are untouched: datasheet provenance with source
  URLs, the mechanical stack, itemised cost and stock, the assembly views and
  the first-power-up guide.
- M3's CI and dependency pinning are still owed.

### Next action

**M4's remaining bullets, which are paperwork rather than engineering.** The
simulation side is done for the attenuverter: transfer, headroom, loading,
corners, interaction and transient all have decks and all pass. What is left
before anything can be ordered is the part that has to be right and does not
need the cards to have arrived:

- Datasheet provenance for every part, with source URLs and versions. The
  models in `modules/_models/` cite figures; the parts themselves do not yet
  have recorded sources.
- The mechanical stack: XY alignment, jack body and bushing heights,
  PCB-to-panel spacing, knobs, nuts, rails and their tolerances.
- Itemised cost and stock against JLCPCB, and the hand-parts list.

The mult deserves a short simulation pass too -- it is passive, so there is
less to learn, but its jack normalling is worth confirming.

One thing to weigh rather than assume: the 0.35 V of headroom over full
scale. It passes, and it is thinner than a utility module usually wants. If
anyone wants margin there it is a circuit change, not a layout one, and it
should be decided before the board is ordered rather than after.

---

## 2026-09-11, session 7: the router routes against the circuit

The measurement from session 6 is now an objective the router optimises. On
the fixture built for it, declared crosstalk goes from 85 mV to 0.55 mV
against a 10 mV budget, for 2.8% more copper and no vias.

### How it works

`autoroute` charges a quiet net for copper near a noisy one, at a price in
cell steps per picofarad, so crosstalk, copper and vias are all weighed on one
scale. The price is not a constant anybody chose: it starts at zero, and while
the emitted board misses the declared limit it is raised through 200, 800,
3200 and 12800 and the board rerouted. That is Lagrangian relaxation, and it
is the same shape as the congestion multiplier the negotiation has always
used -- the price of a thing rises until people stop doing it.

Boards that already meet their limit pay one comparison and nothing else.

### Three ways it silently did nothing, all caught by the independent check

Each of these passed the router's own opinion and failed the benchmark's
measurement of the emitted copper. This is the whole argument for scoring a
router with a checker it does not own.

1. **String-pulling undid it.** The search moved the quiet net away, and the
   post-process then straightened it right back alongside the aggressor,
   because a straight run was legal geometry. The router reported success at
   every price while the board sat at 85 mV against a 10 mV limit. The
   pulling predicate now takes the stretch a shortcut would replace, not just
   its endpoints, and a quiet net refuses a shortcut that couples worse than
   what it replaces.

2. **The descent rejected every fix.** The post-convergence descent accepts a
   reroute only when it is cheaper, and "cheaper" meant copper and vias. A
   coupling detour is longer by construction, so the descent threw away
   exactly the moves the penalty had just bought. It now compares the same
   total the search minimises, coupling included.

3. **Victims were routed before aggressors.** A quiet net cannot be charged
   for running near a noisy net that has not been placed yet, and on a board
   that converges in one iteration it never gets a second chance. With a
   coupling price on, aggressors now go first and victims last whatever the
   ordering heuristic says.

### The fixture had to be fixed twice, and that was informative

`modules/_bench/crosstalk` was first written 6 mm tall, expecting the router
to escape to the back layer for two vias. It could not: the via keepout around
the four 0805 pads covered every cell on the board, so no via could be placed
anywhere. The fixture was offering an escape that did not exist and the router
was being blamed for not taking it. It is now 18 mm tall and the escape is a
bow into the empty half of the board, which is what a person would do anyway.

Its limit was also first set at 1 mV, which no routing can reach: the quiet
net's pads sit 2 mm from the aggressor whatever happens, and those stubs alone
inject about 5.6 mV. A fixture nobody can pass measures nothing. It is 10 mV
now, missed by 8x on the direct route and met with room to spare.

### The coupling table was wrong past 2 mm

It stopped at 2 mm and held its last value, which overstated 3 mm by a factor
of two and 5 mm by nine. Worse than the error: it left the density *flat* from
2 mm out to the cutoff, so a router trying to move away found no gradient to
follow until it fell off a cliff. Solved three more gaps (3, 5 and 8 mm) and
widened the cutoff to 4 mm. That alone took the fixture from 3.36 mV to
0.55 mV, because the router could finally tell 2.5 mm from 3.5 mm.

### Coupling inside one signal path is not crosstalk

The check had no notion of a channel, so it reported every quiet/noisy pair on
the board. On the attenuverter that meant the only non-zero numbers in the
report were `WIPER1` against `OA1` and `WIPER2` against `OA2` -- each op-amp
against its own output, which is its feedback network and not crosstalk at
all. The four pairs that do mean crosstalk were all zero and sat underneath
them.

Worse than a confusing report: a tighter limit would have set the router
spending copper prising each op-amp away from its own feedback.

`anSameCircuit` now declares which nets are one signal path. The checker skips
those pairs, and the router is given them as `csIgnore` so it never pays to
separate them. The attenuverter declares its two channels, and its report is
now four cross-channel rows, all zero, which is the fact worth knowing.

### What the benchmark now says

The crosstalk column is measured by the harness on the emitted copper, with
the design's own intent, for every router:

  attenuverter  ours 0.00 mV   freerouting 2.22 mV   limit 2.20 mV
  crosstalk     ours 0.55 mV   freerouting 85.00 mV  limit 10.00 mV

Freerouting misses the attenuverter's declared crosstalk spec, marginally, and
the fixture's by 8x. Its 2.22 mV survives the same-circuit exclusion, so it is
genuine channel-to-channel coupling and not an op-amp against its own
feedback. It is not a criticism of Freerouting: nothing told it
there was a spec. That is the point of the whole exercise -- it is the first
column in this benchmark where our router is doing something a mature one
does not, rather than catching up.

`cabal run pcbgen -- log <board>` was added to print the router's own trace,
escalation included, because all three bugs above were invisible in the score
and obvious in the log.

### Verification

`cabal test` 59 of 59; attenuverter, mult and both panels clean under ERC and
DRC with schematic parity; `test-scripts.sh` 42 of 42. The real modules
regenerate unchanged in behaviour: the attenuverter meets its limit at
lambda 0, so the escalation costs it one comparison.

### Not run, not done, not proven

- No board has been measured on a bench. Every crosstalk number here is a
  prediction from a 2D field solve and a single-pole circuit model, checked
  against ngspice but never against an oscilloscope. The model is
  conservative for short or skewed neighbours and ignores the far layer
  entirely, both stated in `Route.Coupling`.
- The escalation gives up after four prices. A board that cannot meet its
  limit is reported as missing it, not refused: crosstalk is intent, not
  manufacturability, and `check.sh` is still the gate on whether a board can
  be built.
- Building the coupling map is quadratic in the cutoff radius per noisy cell.
  It only happens when a board is over budget, so no current board pays it,
  but a dense board with many aggressors would.
- `cabal test` takes about 15 minutes, because every routing test runs six
  negotiations and one now runs the escalation as well. Sparking the six
  orderings with `par` was tried and removed: the RTS converted none of them
  ("6 sparks, 0 converted, 6 GC'd"), because `pick` evaluates each result in
  the main thread before the scheduler can hand it out, and the timing did
  not move. Real parallelism needs explicit concurrency and an IO-shaped
  `autoroute`.
- M3's CI and dependency pinning are still owed. M4 has not started.

### Next action

**Bench-measure one prediction.** The chain from field solve to millivolts is
now long, self-consistent and entirely unvalidated against reality. The
cheapest honest check is a two-trace coupon: two 0.3 mm traces at a known gap
and length over a ground plane, drive one, measure the other with a known
load, and compare against `nodebudget.py`. Until then every number in the
crosstalk column is a claim about a model.

Failing that, the other open thread is the via-cost objective: the sweep
still shows no undominated value, and now that a via can be weighed against
millivolts there may finally be something to price it against.

---

## 2026-09-10, session 6: net order dominates, and what analog layout actually binds

Two threads. The router's remaining instability turned out to be net ordering,
and the analog objective turned out to be a different quantity than the one
everybody quotes.

### Router: ordering beats every other setting

- The via-cost spread left over from session 5 was path dependence, not noise.
  The negotiation only reroutes nets that are in conflict, so a net that took a
  wasteful path in round one and was never contested again keeps it, and final
  quality follows the order conflicts happened to appear in.
- Two changes, both in `Route/Router.hs`. A **post-convergence descent**
  (`rcImproveRounds`, 12) offers every net one more route against the others'
  finished copper and keeps it only when it is cheaper by the measure the A*
  itself minimises; total cost strictly decreases, so it terminates. And
  **multi-start** (`rcStarts`, 6): the negotiation runs once per net ordering
  and the best result is kept, lexicographically on faults, then contested
  cells, then cost. Never a weighted sum.
- The orderings are four named heuristics (most terminals first, fewest first,
  longest span first, shortest first) and then deterministic shuffles. The
  heuristics come first so a small `rcStarts` still gets the sensible ones.
  Hardest-first against easiest-first is a real disagreement in the
  literature and neither wins on every board, which is the argument for
  running both instead of picking one.
- Measured at the default via cost over the three congested boards:

  | starts | reversal | route-test | attenuverter |
  |---|---|---|---|
  | 1 | **illegal, 202 vias** | 30 vias | 9 vias |
  | 2 | **illegal** | 17 vias | 7 vias |
  | 4 | 23 vias | 9 vias | 5 vias |
  | 6 | 14 vias | 9 vias | 5 vias |
  | 8 | identical to 6 | identical | identical |

  A single ordering leaves the crossing fixture illegal with 202 vias. Six
  orderings get it to 14. Nothing else in the router buys a factor of
  fourteen, and the curve is flat past six.
- The descent, separately, is worth one or two vias. It also needed its
  conflict test fixed: contest is symmetric, and checking only "my new copper
  in someone else's halo" accepted reroutes that swallowed a settled
  neighbour's trace and left boards illegal.
- The via cost stays at 40, again. The sweep still shows no value undominated
  everywhere, and nothing yet prices a via against a millimetre.

### Analog: length does not bind, coupling does

Installed ngspice 47 (console build, `%LOCALAPPDATA%/ngspice/Spice64`) and
wrote two tools, so that the numbers in a design are derived rather than
asserted:

- `toolkit/xsection.py` solves the cross-section of the stackup we order: 2D
  finite volume on div(eps grad phi) = 0, capacitance from field energy, three
  solves for a pair. Validated two ways, against the Hammerstad closed form
  and by refining the grid (`converge`) to show the difference is
  discretisation. It reads about 6% high at 0.025 mm cells and falls with the
  grid; pushing the outer boundary out or setting copper thickness to zero
  each move it about 1%, so the grid is the error and the operator underneath
  is right.
- `toolkit/nodebudget.py` turns capacitance into budgets with ngspice.
  `nodebudget.py verify` checks the closed form the Haskell now uses against
  ngspice in the capacitive-divider limit, the slope-limited limit and the
  crossover between them: agreement to 0.2%.

What they say, and it redirected the work:

- **Trace length never binds on a board this size.** A 100k node may carry
  1741 mm of copper before losing 3 dB at 20 kHz; a 1M node, 174 mm. The
  longest trace a 6HP board can hold is about 110 mm. A length budget in the
  objective would optimise a quantity that is 9 to 871 times slack, which is
  the same mistake as optimising copper length because it feels like it ought
  to cost something.
- **Coupling binds hard, and spacing is a weak lever against it.** A 5 V gate
  edge running 20 mm beside a 1M node injects 700 mV at 0.2 mm and still
  111 mV at 2 mm. The solve says why: at 0.2 mm two traces are coupled to each
  other (0.0316 pF/mm) as strongly as either is to the ground plane (0.0310),
  so adjacent copper is a half-and-half divider. What controls injection is
  how far the two run alongside each other, and that is what a router chooses.
- So a design declares an electrical limit in millivolts and the checker
  predicts injection from the copper, instead of declaring a spacing nobody
  can justify. `Design.Analog` carries roles (`Quiet` with its node
  impedance, `Noisy` with its volts and rise time), length budgets, matched
  groups, the injection limit and the node's stray capacitance.
  `Route/Analog.hs` integrates the solved coupling along each quiet net and
  applies the verified closed form.

### The attenuverter declares its intent, and the check found something

Channel-to-channel crosstalk is the real spec for a dual utility module, and
this circuit has exactly one mechanism for it: each channel's op-amp output
swings 22 V at audio rate near the other channel's pot wiper, the only
high-impedance node in the signal path (25k worst case, at centre detent).

- Cross-channel coupling measures **exactly zero** on today's routing, because
  the channels are physically apart. The margin against the declared 2.2 mV
  (-80 dB on a 22 V swing) is total. A test routes the board and asserts it,
  so a future layout that runs one channel's output past the other's wiper
  fails in `cabal test` rather than in someone's headphones.
- The matched-length check did find two real things: `IN1` is 67.63 mm against
  `IN2`'s 39.35, and `OUT1` is 58.03 mm against `OUT2`'s 11.76, five times
  longer. Nothing electrical turns on that at audio and the report says so,
  but one channel is being routed the long way round and that was invisible
  before.

### The fixture the next step needs

`modules/_bench/crosstalk` is a 40 mm board whose pads put a `Quiet` 1M net
2 mm from a `Noisy` 5 V gate net, so the shortest routing runs them alongside
for 32 mm: about 0.13 pF, tens of millivolts, three orders of magnitude past
any crosstalk figure worth quoting. There is a way out and it is the move a
person would make -- put one of the two on the back layer, where 1.6 mm of
substrate makes the coupling irrelevant -- and it costs two vias.

The benchmark routes it today with **zero vias and a detour of 1.00**: both
nets straight across, side by side. That is the correct answer to the question
the router was asked, and the wrong board. It is the measurement the objective
work has to move.

### Verification

`cabal test` 58 of 58; the attenuverter, the mult and both panels clean under
ERC and DRC with schematic parity; `test-scripts.sh` 42 of 42. On the one
benchmark board where both routers are legal and unconfounded, `route-test`,
ours is now at 9 vias and 689.45 mm against Freerouting's 6 and 690.79 -- less
copper for three more vias, where two sessions ago it was 27 vias and 717 mm.

### Not run, not done, not proven

- **The router does not act on any of this yet.** The intent is measured and
  reported; nothing feeds it into the objective. That is the next step, and it
  needs a bench fixture where a quiet and a noisy net must compete for one
  corridor, because on the real boards the coupling is already zero and a
  change would be unmeasurable.
- Same-channel pairs (an output against its own wiper, 0.16 mV) are reported
  next to the cross-channel ones. That is feedback rather than crosstalk and
  nothing asserts on it, but the check has no notion of "same channel" and
  would raise it as a finding if it ever exceeded the limit.
- The coupling integral is same-layer only and treats coupling as a local
  function of separation. Both are stated in the code; neither is validated
  against a 3D solve.
- The victim's self-capacitance uses the isolated-trace figure (0.0457 pF/mm)
  while the solve says an adjacent pair sees 0.0310. That makes predicted
  injection slightly optimistic where two nets do run together, by up to 1.5x
  over that stretch. Not corrected.
- `cabal test` got substantially slower, because every routing test now runs
  six negotiations. Tests that check legality rather than quality should pin
  `rcStarts` to 1; they do not.
- M3's CI and dependency pinning are still owed. No electrical measurement of
  any real board has been made, and M4 has not started.

### Next action

**Put the coupling term in the router's objective.** Add a bench fixture where
a `Quiet` net and a `Noisy` net must share a corridor, so the term has
something to bite on and the benchmark can show it working. The mechanism is
already in place: the A* takes a per-cell penalty array, so routing noisy nets
first and charging a quiet net for cells near noisy copper is the same shape
as the congestion penalty it already uses. Then add predicted injection as a
benchmark column, so a routing change that buys copper at the cost of
crosstalk is visible rather than silent.

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
- `modules/mult/mult.kicad_pro` was untracked and nobody had established what
  it was. Resolved 2026-09-11: it was tracked until commit 150aa0a moved every
  module into its own `kicad/` directory, and the copy on disk was larger than
  the deleted one and carried settings keys a newer KiCad writes, so the GUI
  had recreated it after the move. Stale, unreferenced, superseded by
  `modules/mult/kicad/mult.kicad_pro`, and in git history if it is ever
  wanted. Deleted.

### Next action

**M2 leftovers, then M3's reproducibility items.** Concretely, the smallest
useful next slice: decide whether the router should aim for fewer vias now that
the via rule is strict (8 vias on a 28 mm board is workable but worth a look),
then add CI that runs `cabal test` and the fixture checks on a clean checkout.
Prerequisite for CI: deciding where it runs, since KiCad 10 and its libraries
must be available to the test suite.

Do not start M4 until someone decides whether the attenuverter is the vehicle
for it, and do not order anything: no purchase has been approved.
