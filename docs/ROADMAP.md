---
status: "maintained"
owner: "the agent is responsible for keeping this roadmap current; the user sets direction and decides"
read_when: "selecting work, defining acceptance limits, or evaluating a scope/cost tradeoff"
update_when: "a direction, gate, round or priority changes, or a round completes; the agent updates it in the same checkpoint, not later"
retire_when: "the project direction is replaced; merge lasting decisions and remove obsolete plans rather than archiving copies"
---

# Roadmap: From A Musical Idea To A Playable Row

Updated: 2026-09-14. Status: M1-M2 complete; M3 lacks CI; M4 is the method
rehearsal on the attenuverter (option B implemented, characterized in simulation
and factored into three library blocks). The order-readiness review found open
reference-capacitor, input-protection, loaded-accuracy and bring-up/measurement
issues; documents being written does not close those gates. See
[ORDER-READINESS.md](ORDER-READINESS.md). No board has been built or measured.
The plan below replaces the earlier per-module milestones (DUSG, SSG)
with a five-board system designed around the five-board fabrication minimum.

## Goal And Constraints

Make it practical for a non-technical musician to describe a Eurorack module,
have an agent maintain its design and generate manufacturing files, then
assemble and test it using detailed instructions. Success is a working
instrument and a repeatable process, not a more elaborate CAD framework.

| Decision | Direction |
|---|---|
| First priority | A reliable agent-driven design, verification, and export workflow |
| The instrument | A five-board system that is roughly one 84 HP row: IO + Mixer (power and world interface), Slope + VCA, Resonant Filter + VCA, Stepped/Smooth Generator + Noise, Boolean + Clock. Serge-style: the slope and the filter are the oscillators |
| Fidelity | Musical behavior matters more than historical circuitry; modern components are acceptable |
| Circuit approach | Reuse established circuit topologies and documented reference designs; improve precision and validation rather than inventing circuitry for novelty |
| Precision | Precision-first, confirmed 2026-09-11: accuracy, stability and channel independence are default requirements, including pitch CV; invest extra agent effort before fabrication |
| Human role | Describe features, choose between explained alternatives, approve purchases, install larger parts, and perform guided measurements and calibration |
| Agent role | Own design code, tooling, sourcing research, calculations, checks, documentation, measurement scripts, and troubleshooting |
| Assembly | Prefer factory-installed SMD; hand-install jacks, pots, headers, trimmers and other suitable large parts |
| Work cadence | Approximately one session per week, using a variable remaining token budget; progress must survive gaps and model changes |
| Prototype budget | EUR 150-300 per round, including boards, assembly, parts, VAT, shipping, and applicable fees; each round requires approval |
| Home lab | Start from an empty bench, cheapest tool that does each job: about EUR 300 to assemble and power up, about EUR 500 for everything including an optional scope ([HOMELAB.md](HOMELAB.md)), inside the EUR 500-1000 envelope. Bought in stages from bol.com with the user's debit card. No fume extractor. Fabrication orders still wait on the user |
| System power | The IO board supplies the system from USB-C Power Delivery; a current-limited bench supply is still required to test that board itself and for every first power-up |
| Front panels | Deferred 2026-09-10; boards can be bench-tested lying flat, and the art is a separate project |
| Eurorack case | Deferred and budgeted separately; needed when the row is assembled as an instrument |
| Release intent | Personal instrument; a public repository is acceptable, but commercial readiness is not a current goal |
| Stack policy | Code-first and headless; retain working pieces and replace weak ones on evidence |

The user should not need to learn Haskell, manually repair KiCad files, resolve
Python installations, interpret a DRC report unaided, or invent a test plan.
The agent must explain choices in terms of musical behavior, cost, risk, and
work required from the user. It must not invent measurements or treat its own
confidence as evidence that a circuit works.

### Precision-First Design

The user explicitly prefers more design and validation effort over accepting
avoidable inaccuracy. Do not present precision as an optional upgrade whose
only cost is more tokens. The agent must derive justified numerical limits,
express pitch-CV errors in cents as well as volts, and check gain, offset,
loading, channel interaction, noise, drift and headroom across a stated
operating envelope. A nominal simulation pass is not a worst-case guarantee.

For the attenuverter, the first circuit's 41.8 mV simulated channel-patching
shift was treated as a defect, not an accepted compromise: the error budget
was derived, the design changed (option B) and the decks now assert 0.1 mV,
with 1.3 µV simulated. Limits are never weakened to accommodate an existing
circuit. Physical verification of these predictions is tracked explicitly as
the M5 gate.

Precision is relative to intended behavior: controlled distortion or drift
can be a requested musical feature, but unintended detuning and channel
interaction are not. Additional analysis is authorized; material cost,
architecture and scope changes still need explained decisions, and purchases
still need approval. Use measurable acceptance gates, not an unbounded quest
for more simulated decimal places.

**Pitch tracking is a system requirement**, because the slope and the
filter are the oscillators. **Limit, confirmed by the user on 2026-09-13**
(answered on the session's planning page, not in a decision file): within
±2 cents over 5 octaves and ±5 cents over 8 octaves, from 15 to 35 °C. It is
met by one exponential-converter block (matched transistor pair, temperature
compensating resistor, scale and high-frequency trimmers) designed once and
calibrated per board on the bench; the temperature-sweep deck of P1 asserts
it in cents.

### Cost Is Not An Optimisation Target

Stated by the user on 2026-09-11, when choosing the more expensive of two
attenuverter options: *"we are not optimizing for price"*. A few dollars per
board is not a reason to accept a worse circuit, and effort spent finding a
cheaper build of an already-good circuit is effort misspent.

There is exactly one cost constraint, and it is about the market rather than
the bill of materials: **if a module built this way costs more than buying an
equivalent commercial module** — Doepfer, Behringer and similar — **that is a
project-level failure**, and the user would rather buy the commercial one.
Fixed per-order fees and the panel dominate that comparison at prototype
quantities; layout does not move it.

This has a direct consequence for the generator. Via count and trace length
cost nothing at the fab — see [JLCPCB.md](JLCPCB.md), which records the actual
thresholds and shows our boards sitting at 8% of the free drill allowance. Any
routing objective justified on cost grounds is justified on a false premise.
Keep such objectives only where they serve a real electrical or search purpose,
and say which one. The objective that is genuinely missing is ground-plane
integrity, not a better via price.

### Module Form Factor And Composition

Stated by the user on 2026-09-11. These are decisions, not proposals.

**Width: no module narrower than 4 HP, none wider than 20 HP.** The intent is
to stay inside JLCPCB's standard tier, which is 100 x 100 mm. The upper bound
does exactly that: 20 HP is a 101.3 mm panel and a 99.3 mm PCB, the widest
Eurorack size that fits; 22 HP (109.4 mm PCB) does not. The lower bound does
not do what it was meant to. JLCPCB treats any board with a dimension of
30 mm or less as a small board and applies handling charges; a 4 HP PCB is
18.0 mm wide and a 6 HP PCB is 28.0 mm, so both attract them, and **8 HP
(38.3 mm PCB) is the first width that clears the threshold**. The 4 HP floor
stands as stated; in practice every board in the planned system is 12 HP or
wider, so the question is moot until a small module is proposed.

**Height: the PCB is 100 mm** (`eurorackPcbHeight`, changed from 108 mm on
2026-09-13 with the option B rework), or the 100 x 100 tier is missed
regardless of width. The panel controls did not move; the attenuverter's SMD
strips were re-laid into the pad-free zones between them, and the mult
regenerated unchanged in placement. Required of every module.

**No doubling up.** The five-copy planning assumption means a dual VCA would
yield ten VCAs if all five PCBs were populated.
Instead, one board combines *different* functions: a slope generator with a
VCA, a filter with a drive VCA, a random generator with its own noise source,
a power supply with a world interface and a mixer -- small analog computers.
Five identical filters is acceptable because five filters are useful; ten
attenuverters are not.

**Quantity clarification, 2026-09-14:** PCB fabrication quantity and assembly
quantity are not necessarily identical. JLCPCB currently advertises assembly
starting at two units; the selected service and live quote must establish the
actual quantities (source in [ORDER-READINESS.md](ORDER-READINESS.md)). This
does not change the agreed combined-function boards or authorize an order.

**Chaining is done with dedicated jacks, not CV thrus.** Clock out, reset out,
end-of-rise and end-of-fall triggers, and a divider's /16 output let board n
drive board n+1. Buffered CV thru/mult jacks were considered and dropped for
now (2026-09-11) to keep the panels manageable; revisit if patching proves it
necessary. A sequencer designed so five boards chain into one is parked, not
rejected.

**The filter is a drive stage into a resonant state-variable filter**, with the
Sherman Filterbank's input overdrive and first filter as the *behavioural*
reference. No Sherman schematic is published or licensed, so nothing is
copied; the SVF-plus-drive topology is generic and gives LP, BP, HP and notch
simultaneously. What can be shown by a deck is the drive stage's transfer
curve, the filter's response and resonance range, the oscillation frequency
against V/Oct, and the feedback path's stability; that it *sounds like* a
Sherman cannot be, and is not claimed. The earlier Ripples direction is
withdrawn.

### Proven Circuit Reuse

Start from established attenuverter, buffer, reference, protection, integrator,
exponential-converter and sample/hold approaches where they meet the required
behavior. Reuse is not evidence by itself: verify the exact implementation,
parts, operating conditions, stability and error budget. Track manufacturer
documents and source/licensing restrictions before reusing published drawings
or models; a commercial product with no published schematic is a behavioural
reference only.

Only propose a new circuit topology when a concrete requirement cannot be
met adequately by a proven approach. This is distinct from topological
routing, which describes how copper paths are represented in software.
Precision remains the goal for either existing or adapted circuitry.

## Stack Decision

Keep the current foundation provisionally. A language rewrite would not, by
itself, fix the missing electrical and manufacturing guarantees.

| Layer | Decision | Evidence required to retain it |
|---|---|---|
| Conversation and intent | User-facing plain-language specifications and acceptance examples | A new session can identify what is wanted, what is approved, and what remains unknown without replaying old chats |
| Haskell / pcbgen | Keep as an agent-maintained source of truth; add validation and reusable circuit blocks | Invalid designs are rejected, useful diagnostics are produced, and changes remain small and testable |
| KiCad 10 libraries and CLI | Keep as the CAD target and independent native checker; no GUI dependency | Supported versions and library inputs are recorded; clean-checkout generation and checks reproduce |
| Custom grid router | Keep on probation for simple routing, not as an analog design authority | No silent incomplete routing, accidental SMD via-in-pad, or disconnected pre-route assumptions; critical analog constraints are respected |
| KiKit | Keep for fabrication and assembly exports behind an enforced release gate | Generated layers, drills, BOM, placement coordinates, sides, and part rotations survive end-to-end checks |
| SPICE | Pinned, headless ngspice with hand-built, datasheet-sourced device models | Executable, model provenance, complete test circuits, assertions, and useful failure reports work on both workstations |
| Datasheets and sourcing | Add structured part records and a local evidence cache; use distributor helpers as replaceable adapters | Exact part identity, package, pin mapping, ratings, tolerances, and assembly availability can be checked without relying on a chat assertion |
| Automated checks | Add real regression tests and CI; retain native ERC/DRC as separate checks | Fault-injection tests fail for the right reason; positive fixture projects still pass |
| Measurement scripts | Add laptop-driven instrument control for calibration and verification, alongside the guided procedures | A measurement script reports what it read, with instrument identity and settings; it never fills in an unmeasured value |
| Human review and bench | Required, with agent-authored illustrated procedures | Actual observations and measurements meet stated limits; unreadable or ambiguous results remain unresolved |

Do not reintroduce GUI/MCP automation just to avoid fixing local generator
bugs. Do not build a new simulator, distributor backend, or general autorouter
when an existing tool meets the requirement. Windows setup must be reproducible
and should not depend on an undocumented user-specific Python path.

If a retained component repeatedly blocks a milestone, use one bounded work
item to test one credible replacement on the same fixture and acceptance
checks. Freerouting is a candidate for routing, not a presumed solution to
analog layout. Compare correctness, unattended operation, reproducibility,
installation burden, and agent maintenance cost. Ask before a migration;
preserve the working path until the replacement passes.

## Current Baseline

Use [HANDOFF.md](HANDOFF.md) for the current tested checkpoint, commands,
results and gaps. Native rule checks, software regression tests and simulation
results are different evidence; none alone is fabrication approval. Module
requirements live in [modules/attenuverter/SPEC.md](modules/attenuverter/SPEC.md)
and [modules/mult/SPEC.md](modules/mult/SPEC.md), not a second status table here.

M1/M2's wiring, via/pad, disconnected-pre-route and assembly faults are retained
as regression cases in [../toolkit/test/ValidateTests.hs](../toolkit/test/ValidateTests.hs)
and [../toolkit/test/RouteTests.hs](../toolkit/test/RouteTests.hs). Export and
simulator false-pass cases live in [../toolkit/test-scripts.sh](../toolkit/test-scripts.sh).

## Delivery Sequence

```text
M0 Direction recorded [DONE]
  -> M1 Explicit design intent and rejection tests [DONE 2026-09-09]
  -> M2 Routing and assembly correctness [DONE 2026-09-09]
  -> M3 Reproducible, fail-closed pipeline [PART DONE; dependencies pinned 2026-09-11; CI open]
  -> R0 Routing benchmark [DONE 2026-09-10]
  -> M4 Method rehearsal: option B characterization and first three blocks exist; order-readiness findings [OPEN; see ORDER-READINESS.md]
  -> P1 Shared blocks: exponential converter, gain element
  -> P2 Five rounds, one board each, in dependency order:
       R1 IO + Mixer -> R2 Slope + VCA -> R3 Filter + VCA -> R4 SSG + Noise -> R5 Boolean + Clock
       every round: models -> error budget -> decks -> board -> checks -> approval -> order
                    -> build -> first power-up -> calibrate -> MEASURE against predictions (M5 gate)
  -> P4 One row: case, panels, the calibration and first-power-up guide
  -> P5 Compounding: block library, first one-shot candidate, then the digital control plane

L1 Home lab (HOMELAB.md) must exist before R1's boards arrive; purchasable now.
CI (M3) proceeds in parallel and is owed before the first order.
```

Milestones and rounds are acceptance gates, not weekly deadlines. Split each
into work items that fit the available session budget. A later stage must not
assume that an earlier stage's artifacts, equipment, or approvals exist. Rounds
overlap in practice: the next board is designed while the previous one is at
the fab. At roughly one session a week, with two to three sessions per board
plus fabrication lead time, P2 is on the order of six to nine months. That is
a shape, not a promise.

### M1: Make Invalid Designs Fail [DONE]

Gate met 2026-09-09: the four wiring faults are rejected with useful
diagnostics, intentional NC cases succeed, and all native-check fixtures pass.
Retained as regression tests; see Current Baseline.

### M2: Make Routing And Assembly Intent Explicit [DONE]

Gate met 2026-09-09: positive and negative routing/assembly fixtures pass;
current boards pass native DRC/parity; no SMD pad drills remain. Assembly
intent is per part (`Factory`, `Hand`, `DNP`, `Mechanical`).

### M3: One Reproducible Pipeline [PART DONE]

`toolkit/pipeline.sh` is the entry point; `check.ok` and the hash-gated
`fab.sh` make it fail closed; `toolkit/test-scripts.sh` proves the refusals
fire; `cabal.project.freeze` pins the Haskell dependencies (both workstations
on GHC 9.6.7 since 2026-09-11).

Open: **CI on a runner with KiCad 10 and its libraries.** This is owed before
the first order, because an order is the first time a stale local pass would
cost money. Local test passes do not close this gate.

### M4: Method Rehearsal On The Attenuverter [IN FLIGHT]

The attenuverter is no longer a module the system would order five of; it is
the **end-to-end rehearsal of the method** every later board repeats, and its
circuit becomes a library block (it reappears as every CV attenuverter on the
five boards). Option B was decided on 2026-09-11 and implemented on
2026-09-13; the decision and its reasoning are recorded in
[modules/attenuverter/SPEC.md](modules/attenuverter/SPEC.md).

- [DONE 2026-09-13] OPA2197 and REF5050 models from datasheet maxima, with
  input capacitance, a second pole and temperature terms; option B with
  10 kΩ gain resistors (chosen on deck evidence, not the assumed 100 kΩ);
  PCB at 100 mm; eight decks covering the adopted characterization checks in
  [modules/attenuverter/ERROR-BUDGET.md](modules/attenuverter/ERROR-BUDGET.md),
  including a loop-gain phase-margin measurement through a probe the
  netlist generator now emits in every op-amp output; pipeline passed;
  decision file retired.
- [DONE 2026-09-13] The block library begins: `Block.Eurorack` (the module
  skeleton: panel and board geometry, rail holes, the panel project),
  `Block.Power` (header, series Schottkys, bulk capacitors and their nets)
  and `Block.Precision` (the buffered attenuverter channel). The
  attenuverter and the mult are built from them; regeneration proved the
  skeleton byte-identical and the power and channel blocks identical up to
  part order, with the router then finding an equivalent solution. **No LED
  driver block**: the user decided on 2026-09-13 to drop it from the roadmap
  and decide LED indication per board, since no board has an LED yet and a
  block without a consumer cannot be proven.
- [DONE 2026-09-13] Datasheet provenance with URLs and revisions
  (attenuverter SPEC, with three parts marked unverified for hand checking),
  the mechanical stack and fit review ([MECHANICAL.md](MECHANICAL.md)), the
  first-power-up guide
  ([modules/attenuverter/POWER-UP.md](modules/attenuverter/POWER-UP.md)).
- Remaining: itemised cost and stock against JLCPCB (deferred by the user on
  2026-09-13); input over-voltage protection; complete part evidence and the
  findings in [ORDER-READINESS.md](ORDER-READINESS.md). In particular, demonstrate
  effective reference output capacitance over tolerance/bias/temperature,
  allocate source and receiver loading in the relevant pitch path, and correct
  the first-power and DC-measurement procedure. Some previously inaccessible
  PDFs were obtained on 2026-09-14; acquisition is not complete verification.

Gate: every consequential electrical, mechanical, sourcing, and assembly
assumption has evidence or an explicit bounded experiment; the human receives
a plain-language preview and an all-in quote. A reviewed prototype candidate
is allowed to be unbuilt; it must not be labeled bench-tested.

### P1: The Two Blocks The System Stands On

Prerequisites: M4's method and skeleton, met on 2026-09-13 (`Block.Eurorack`,
`Block.Power`, `Block.Precision`; models, error budget, decks, provenance,
mechanical stack, power-up guide as the pattern each block repeats).

1. **The exponential converter.** Matched transistor pair, temperature
   compensating resistor, scale and high-frequency trimmers; coarse and fine
   tune inputs. Deliverables: the device model for the matched pair with
   thermal coupling, a temperature-sweep deck reporting tracking in cents, the
   proposed limit confirmed or changed by the user, and the bench calibration
   procedure the user will perform five times per round. Used by R2 and R3.
2. **The gain element.** Choose the OTA or VCA part once (the slope's VCA, the
   filter's drive VCA and the SVF's two integrators all use it), model it from
   its datasheet, and record its limits. Choose it before R2 is drawn.

Gate: both blocks have models, decks with stated limits, and a written
calibration or characterisation step; neither has yet been on a board.

### P2: Five Rounds

Each round is the same sequence and the same gate. **The gate is a
measurement**, not a passing deck: the board is built, powered through a
current-limited supply, calibrated, and measured against the numbers its decks
predicted. Discrepancies are explained and the cheapest informative next
measurement is chosen; a respin gets its own reason, cost and approval.

| Round | Board | What it proves | Why this position |
|---|---|---|---|
| R1 | **IO + Mixer** — USB-C PD power supply, ±12 V / +5 V distribution, line-level inputs summed to a mix, independent line-level outputs | The supply is quiet enough for precision boards; the modelled crosstalk chain against a **two-trace coupon** placed on this board's spare area | The user owns no case or supply, so nothing else can be powered or heard. Fully testable alone with a charger, a laptop and a DAW |
| R2 | **Slope + VCA** — half a DUSG cycling as a tracking triangle VCO, EOR/EOF triggers, VCA normalled to the slope | The exponential-converter block on the simpler circuit; the shared gain element; the first voice | Audible through R1. Proves P1 on the circuit that is easier to reason about |
| R3 | **Resonant Filter + VCA** — drive stage into a 2-pole SVF, LP/BP/HP/notch, feedback path, tracking at self-oscillation | The same expo block reused, not re-proven; drive and feedback behaviour; the second oscillator | The voice gets its character |
| R4 | **SSG + Noise** — smooth/stepped generator, S&H and T&H, analog white noise, comparator | Hold-stage droop and feedthrough; noise level range and spectrum; comparator behaviour | Modulation and randomness; depends on nothing new but the analog switch |
| R5 | **Boolean + Clock** — shared-threshold logic, edge triggers, /2 to /16 divider with reset | Logic thresholds and timing; a divider chain five boards deep | Utilities last; nothing depends on them |

The detailed panel lists for these boards are being edited by the user and
move into `docs/modules/<name>/SPEC.md` when a round is promoted; a round is
not started until its SPEC exists and its open questions (tracking limit,
world-side jack size, IO mix semantics, hold stages, filter pole count) are
answered.

Per-round gate: the board's stated behaviours pass both their simulation
assertions and their physical measurements within the chosen cost and space;
calibration is documented and repeatable; evidence is recorded against the
board revision and installed parts. Budget and approve each round separately.

### L1: Build The Home Lab In Stages

Prerequisites: the agreed budget and an empty bench. Purchasable now with the
user's debit card; **must exist before R1's boards arrive.** The shopping list
with staged purchases, prices and reasons is [HOMELAB.md](HOMELAB.md), owned by
the agent and confirmed by the user as items are bought. The user rejected the
first list (EUR 1,680) as far too expensive on 2026-09-13; the current list
buys the cheapest tool that does each job: **Stage A about EUR 300, Stage B
about EUR 30-100, everything including an optional handheld scope about
EUR 500**, inside the EUR 500-1000 envelope. Scriptability is a bonus, not a
requirement; the scope is deferred until a measurement asks for it; **no fume
extractor, ever** (open window and a fan). Purchase order is Stage A (what the
first boards need), then the audio interface (which runs the tracking,
response, noise and crosstalk measurements from Python), then a scope only if
needed. The stages below use HOMELAB.md's letters.

| Stage | Equipment and guidance | Acceptance |
|---|---|---|
| A (part 1): assembly and basic measurements | Temperature-controlled soldering station, tips/stand, solder/flux, cleaning, cutters/tweezers, heat-resistant surface, ventilation (window and fan), eye protection, ESD basics, a fused-input multimeter with leads | Guided practice and continuity/resistance checks completed before working on the first module |
| A (part 2): safe first power | Current-limited bench supply capable of bipolar ±12 V (series-capable channels), a USB-C PD charger and PD tester for R1, identified cables, connectors and protection | Exact wiring, polarity, grounding, current-limit settings and shutdown criteria documented and checked without a board attached |
| B: dynamic measurements and scripting | A USB audio interface as spectrum analyser and stimulus, driven from Python; attenuation for Eurorack levels; a cheap scope only when a measurement (R1's switching converter) asks for one | Guided probe compensation and a known-signal exercise; a first measurement script reads an instrument and reports what it read |
| C: later expansion | Eurorack case/power, additional instruments, rework tools | Buy only when a named task requires them; case/power have a separate budget |

Prefer instruments the laptop can drive, so that calibration becomes a script
the user and the agent run together rather than a list of readings the user
transcribes. The script reports; it never invents.

No DIY mains wiring, PSU internals, mains probing, or defeated protective earth.
Use commercially enclosed mains-powered equipment and follow its documentation.
Ordinary oscilloscope probe grounds are common and usually earth-referenced;
the guide must identify the correct circuit reference and must not assume a
channel or supply can float. In-circuit tests use a low-voltage, current-limited
setup; unexplained current, heating, polarity, or ground ambiguity stops testing.

### M5: Guided Physical Proof (the gate every round passes through)

Prerequisites: an approved round package, delivered hardware, and the L1
equipment and training for each step. Until delivery, status is "waiting for
hardware," not "testing in progress."

- The agent provides numbered steps with annotated diagrams, instrument
  settings, expected ranges and stop conditions, and where possible a
  measurement script. The user reports observations; neither party fills in an
  unmeasured result.
- Inspect and assemble, perform unpowered checks, then follow the reviewed
  current-limited first-power sequence. Check rails and current before signal
  tests. Calibrate with the written procedure.
- Measure the round's stated limits: rails and offsets, tracking in cents,
  responses, interaction, loading, overload behaviour, mechanical fit. Identify
  the board revision, installed parts, instruments and conditions.

Gate: a physical board passes its stated tests and the user can complete the
procedure without writing code or inventing electrical tests. Only then are its
blocks promoted to bench-tested. A hobby prototype pass is not certification.

### P4: One Row

After R5: five boards, about 70 HP, powered by their own IO board. Calibrate
all five; write the calibration and first-power-up guide as the durable
deliverable; then the deferred items in order — case, then panels. The parked
sequencer is reconsidered here, by which time the control plane may be its
better home.

### P5: Compounding

The measure of this phase is whether **the sixth board costs almost nothing**.
Assets by then: a block library (power entry, exponential converter, gain
cell, precision buffer, output stage, PD supply), a device-model library, deck
and error-budget templates, calibration procedures and scripts.

- **First one-shot candidate:** a new combined board built from existing
  blocks with no new device model — specification in, verified project out.
- **Digital control plane:** years away by the user's statement; the analog
  boards carry nothing for it now.

### Toolkit Obligations Along The Way

- **Ground-plane integrity** as a routing objective and check. The missing
  objective identified in [JLCPCB.md](JLCPCB.md); it becomes concrete on R1,
  where switching converters sit beside precision rails.
- **CI** (M3), before the first order.
- **Board variants** (same SMD, different hand-population) only if a round
  needs them; not speculatively.

### Routing Research Wishlist

- **Joint placement and routing: planned, not implemented.** Agreed in the
  2026-09-10 research direction and reaffirmed 2026-09-11. Search over
  eligible component positions/orientations together with copper routes,
  rather than optimise routing around a single fixed placement.
- Keep panel-mounted parts and other declared mechanical anchors fixed;
  declare allowed moves for other parts, assembly side, body clearances and
  circuit-local constraints. Generation remains deterministic and code-first,
  with no learned model choosing positions or copper in the generation loop.
- Prerequisites: explicit movement constraints and a trustworthy benchmark
  with independent native DRC and equivalent rules for each strategy. Show
  an improvement in completion or electrical margins on held-out boards
  against fixed placement within a stated compute budget; shorter copper
  alone does not establish a better analog design.

Known limits to address before stronger routing claims:

- The benchmark's selected connectivity/via checks are not a full independent
  native DRC for every strategy. External routing uses a limited configuration;
  the attenuverter's unbonded ground-pour assumptions confound that comparison.
  Freerouting's rows are not deterministic run to run; only grid-astar rows are
  the diff.
- The reported minimum spanning tree is a reference length, not a proven lower
  bound for branched copper. Do not infer a missing connection from a detour
  below 1 alone.
- The coupling model ignores the opposite layer and full ground-return behavior,
  has a cutoff, and approximates nearby geometry. Predicted zero is not physical
  zero. R1's coupon is the first test of the whole chain against a measurement.
- Grid pitch, via cost and multi-start count are heuristics tested on a small
  fixture set; via cost in particular is a congestion heuristic, not a price.

The recorded scores belong in [BENCH.md](BENCH.md); the current algorithm and
model details are in [../toolkit/src/Route/Router.hs](../toolkit/src/Route/Router.hs)
and [../toolkit/src/Route/Coupling.hs](../toolkit/src/Route/Coupling.hs). Do not
retune them merely because this wishlist exists.

### Parked And Dissolved Ideas

- **4-step chainable sequencer:** parked 2026-09-11. Five boards chaining into
  20 steps is the purest example of the five-board rule as a feature; it brings
  the first digital-logic modelling step and depends on the pot-linearity
  question. Reconsider at P4.
- **OUT-01 (output stage) and POW-01 (power):** dissolved into R1, the IO board.
- Parked: an SMT remake of Gijs Gieskes' 3TrinsRGB+1c video synthesizer.
  Confirm permissions and scope before using or publishing derivative material.

Remove an idea when explicitly rejected or superseded; when promoted, give it
an owned module specification and acceptance gate rather than a parallel list.

## What Can Stop It

- **Money:** fabrication orders wait on the user; the lab has its own budget
  and can start now.
- **Decisions outstanding:** the IO board's world-side jack size and its mix
  semantics (both now in `docs/decisions/` as researched questions), one or
  two hold stages on the SSG, the filter's pole count. The tracking limit is
  confirmed. Option B is implemented and factored into blocks; what M4 still
  owes is cost and stock, input protection and three datasheet checks by
  hand.
- **The three hard problems:** pitch tracking over temperature (the hardest
  analog work in the plan), switching-supply noise beside precision audio on
  R1, and a modelled chain that has never met an oscilloscope — R1 is the
  moment that stops being true.
- **Ritual cost:** trimmers mean every board of every round is calibrated by
  the user, guided. The measurement scripts exist to make that a shared job
  rather than transcription.

## Weekly Session Contract

The agent may choose and execute a bounded task within this roadmap. It asks
at material design decisions, budget changes, purchases, uncertain safety
steps, or stack migrations. It does not require approval for every routine
code edit or test. The user gave standing authorization on 2026-09-11 to commit
and push completed, validated checkpoints without asking each time. Follow
the two-workstation rule in `AGENTS.md`; this does not authorize purchases,
force-pushes, or committing unrelated work or secrets.

1. Read [../AGENTS.md](../AGENTS.md), the current [HANDOFF.md](HANDOFF.md), and edited questions in `docs/decisions/`. Use this roadmap for the affected gate; check actual inputs and worktree state before choosing work.
2. Select one main outcome: a named failing behavior, an evidence gap, or a guide with a concrete acceptance check. Announce the scope and what would disprove the proposed solution.
3. Implement in small steps and run the narrow relevant checks. Escalate only on evidence; do not use remaining tokens as a reason to add unrelated features or endlessly compare tools.
4. Before stopping, leave a tested checkpoint or explicitly mark partial work as blocked/non-releasable. Preserve existing user changes and record which edits belong to this task.
5. Update the compact handoff with the exact result, artifact paths/hashes, commands and tool versions, remaining risks and one next action. If user input is genuinely needed, create a researched question using [decisions/README.md](decisions/README.md), integrate edited answers, and retire processed files. Remove superseded status prose instead of appending an unbounded session diary. Say what has not been run.
6. **Keep this roadmap current in the same checkpoint** that changes a
   direction, gate, round or priority. A stale roadmap is the agent's fault.

There is no promise of background work between sessions. Every new agent must
be able to resume from tracked documents, not private memory or ignored scratch
files. Avoid recreating already answered questions or repeatedly running broad
analysis when the relevant inputs have not changed.

## Durable Deliverables

Create these when their milestone supplies real content, not as empty process
scaffolding.

| Artifact | Purpose / owner |
|---|---|
| This roadmap | Agreed priorities, constraints, rounds and gates; the agent updates it at every material change |
| [HANDOFF.md](HANDOFF.md) | Agent-maintained compact current/blocked/next state and evidence; Git retains past checkpoints |
| [HOMELAB.md](HOMELAB.md) | Staged lab shopping list with prices, reasons and laptop connectivity; agent-maintained, user-confirmed |
| Stack decision and toolchain record | Agent-maintained versions, installation checks, tested library inputs, and reasons for any migration; build on [SETUP.md](SETUP.md) |
| Per-module specification and tests | `docs/modules/<name>/SPEC.md` owns intent and limits; executable simulations and tests stay with the design/code |
| Block library | Reusable circuit blocks in the generator with their models, decks and limits; the asset P5 is measured by |
| `docs/decisions/` inbox | Concrete researched user choices; answers are integrated into their authoritative documents, then inbox files are deleted |
| Part evidence and manufacturing recipe | Exact identities/ratings, sourcing checks, assembly intent, approved process options, and complete order list |
| Lab, assembly, calibration and test guides, with scripts | Instructions and scripts sufficient for a beginner to buy, set up, measure, calibrate and stop safely |
| Prototype record | Human observations plus agent analysis and script output, tied to board revision and actual installed parts |

Commit source designs, tests, guides, scripts, status, and suitable summaries.
Generated KiCad projects remain tracked; fabrication output and binaries remain
outside git as required by the repository. Retain purchased-revision bundles
and bench evidence in a durable user-controlled archive with hashes/locations
recorded in tracked state, not only ephemeral CI artifacts. Keep secrets,
addresses, order credentials, and personal history out of public files. Respect
datasheet and model redistribution terms.

## Next Work Item

**Before any order:** close the findings and release gates in
[ORDER-READINESS.md](ORDER-READINESS.md). R1 remains the planned first order and
has no specification or PCB yet. An earlier small rehearsal order would need
its own reviewed candidate and explicit scope/quote approval. Card availability
does not substitute for either review.

1. **P1**: the exponential-converter block, beginning with the matched-pair
   model with thermal coupling and the temperature-sweep deck reporting
   tracking in cents against the confirmed limit. See [HANDOFF.md](HANDOFF.md)
   for the exact next action.
2. **L1**: the user buys Stage A of [HOMELAB.md](HOMELAB.md) as listed
   (stated intent 2026-09-13; not yet bought); the lab must exist before
   R1's boards arrive.
3. **Answer the two R1 decision files** in `docs/decisions/` (jack size, mix
   semantics) so the R1 SPEC can be written.
4. **M4 leftovers**, before any order: cost and stock against JLCPCB, input
   over-voltage protection, hand verification of the three datasheets the
   attenuverter SPEC marks unverified.

CI remains a parallel M3 obligation owed before the first order.
