---
status: "maintained"
owner: "the agent is responsible for keeping this roadmap current; the user sets direction and decides"
read_when: "selecting work, defining acceptance limits, or evaluating a scope/cost tradeoff"
update_when: "a direction, gate, round or priority changes, or a round completes; the agent updates it in the same checkpoint, not later"
retire_when: "the project direction is replaced; merge lasting decisions and remove obsolete plans rather than archiving copies"
---

# Roadmap: From A Musical Idea To A Playable Row

Updated: 2026-09-21. **Current phase: VCV Rack prototypes before hardware.**
The user wants to play digital versions of the proposed modules before taking
the risk of designing and building an unfamiliar instrument. Establish the
musical behavior and balance of VCAs, LFOs, envelopes and other functions through
patching first. The five-board composition below is the starting point to test,
not a finished allocation that the virtual instrument must vindicate.

Existing hardware work is retained, not abandoned: M1-M2 complete; M3 lacks CI;
M4's option B attenuverter is implemented, characterized in simulation and
factored into three library blocks. Its open electrical and bring-up findings
remain in [ORDER-READINESS.md](ORDER-READINESS.md). No board has been built or
measured. New circuit/layout work, hardware procurement preparation and
fabrication are deferred while V0 is the priority. Virtual success will not
close physical verification or purchase gates.

## Goal And Constraints

Make it practical for a non-technical musician to describe a Eurorack module,
play a digital version in VCV Rack, and refine an instrument's function balance
before committing to hardware. Once the musical design is accepted, have an
agent maintain its circuit design and generate manufacturing files, then
assemble and test it using detailed instructions. Success is a useful, playable
instrument and a repeatable process, not a more elaborate CAD framework.

| Decision | Direction |
|---|---|
| First priority | Playable digital module prototypes in VCV Rack; learn through patching and establish a useful balance of functions before hardware design resumes |
| The instrument | Starting hypothesis: roughly one 84 HP row with IO + Mixer, Slope + VCA, Resonant Filter + VCA, Stepped/Smooth Generator + Noise, Boolean + Clock. Serge-style: the slope and filter can be oscillators. V0 tests the grouping and counts, including the functions lost when a shared resource takes one of those roles. |
| Fidelity | Musical behavior matters more than historical circuitry; modern components are acceptable |
| Circuit approach | Reuse established circuit topologies and documented reference designs; improve precision and validation rather than inventing circuitry for novelty |
| Precision | Precision-first, confirmed 2026-09-11: accuracy, stability and channel independence are default requirements, including pitch CV; invest extra agent effort before fabrication |
| Human role | Play the prototypes and report what is useful or missing; describe features, choose between explained alternatives, approve purchases, and later assemble and perform guided measurements and calibration |
| Agent role | Own digital prototypes, reproducible patches, behavior checks and resource accounting; later own circuit design code, tooling, sourcing research, calculations, checks, documentation and guided measurement |
| Assembly | Prefer factory-installed SMD; hand-install jacks, pots, headers, trimmers and other suitable large parts |
| Work cadence | Approximately one session per week, using a variable remaining token budget; progress must survive gaps and model changes |
| Prototype budget | EUR 150-300 per round, including boards, assembly, parts, VAT, shipping, and applicable fees; each round requires approval |
| Home lab | Retain the agreed EUR 500-1000 envelope and existing purchases; [HOMELAB.md](HOMELAB.md) owns inventory, payment readiness and remaining capability gaps. Further lab procurement is deferred, not a prerequisite for VCV Rack. No extractor purchase is added. Equipment spending and fabrication orders still require approval. |
| System power | The IO board supplies the system from USB-C Power Delivery; a current-limited bench supply is still required to test that board itself and for every first power-up |
| Instrument interaction | Follow the visible, persistent control rules in [AGENTS.md](../AGENTS.md#rules): the panel and cables describe the musical setup. No separate power-loss state-saving project. |
| Panel standard | Paperface-inspired sparse grid and original printed/laser-cut faceplates; adopted principles and provisional dimensions live in [MECHANICAL.md](MECHANICAL.md#panel-layout-language). |
| Front panels | Final artwork and fabrication remain deferred; the shared layout model, ergonomic mockups and browser-only sketcher are authorized now (2026-09-15). |
| Eurorack case | Deferred and budgeted separately; needed when the row is assembled as an instrument |
| Release intent | Personal instrument; a public repository is acceptable, but commercial readiness is not a current goal |
| Stack policy | VCV Rack for interactive musical prototypes; keep the code-first, headless hardware workflow for eventual circuits and fabrication. Retain working pieces and replace weak ones on evidence. |

The user should not need to learn DSP programming or Haskell, manually repair
KiCad files, resolve Python installations, interpret a DRC report unaided, or
invent a test plan.
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
to be met by a planned exponential-converter block (matched transistor pair, temperature
compensating resistor, scale and high-frequency trimmers) designed once and
calibrated per board on the bench; P1 must supply a temperature-sweep deck that
asserts it in cents. A digital oscillator's tracking does not prove that block.

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

The physical constraints below were set on 2026-09-11 and remain requirements
for eventual hardware. The earlier grouping and quantity assumptions are now
inputs to V0's musical evaluation; do not select a replacement hardware
architecture without the user's agreement.

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

**Combined-function baseline.** The earlier "no doubling up" decision assumed
five populated copies, so a dual VCA would yield ten VCAs. The starting plan
therefore combines *different* functions on one board: a slope generator with a
VCA, a filter with a drive VCA, a random generator with its own noise source,
a power supply with a world interface and a mixer -- small analog computers.
V0 must test whether this actually supplies enough independently usable
functions. Do not forbid an extra virtual VCA or LFO to preserve the old count;
record why it was needed and use that evidence in the composition decision.

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

Add the playable VCV Rack phase while retaining the existing hardware
foundation. This is not a pcbgen language rewrite, a commitment to firmware in
the physical modules, or the later embedded digital control plane. Those
choices would not, by themselves, fix electrical and manufacturing guarantees.

| Layer | Decision | Evidence required to retain it |
|---|---|---|
| Conversation and intent | User-facing plain-language specifications and acceptance examples | A new session can identify what is wanted, what is approved, and what remains unknown without replaying old chats |
| VCV Rack | Current musical prototyping environment; installed per user report, with exact setup still to record in [SETUP.md](SETUP.md) | Saved patches reopen with recorded Rack/plugin versions; digital behaviors and approximations are explicit; the user can play and evaluate the proposed instrument |
| Haskell / pcbgen | Keep as the hardware design source of truth; digital prototypes do not replace circuit validation | Invalid designs are rejected, useful diagnostics are produced, and changes remain small and testable |
| Module sketcher | Existing local HTML/CSS/JavaScript for panel ideas, not an audio simulator; the generator bridge remains deferred | Opens locally without a server or network; portable sketch files round-trip; the eventual bridge shares layout data rather than copying coordinates |
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
requirements live in [modules/io-mixer/SPEC.md](modules/io-mixer/SPEC.md),
[modules/attenuverter/SPEC.md](modules/attenuverter/SPEC.md)
and [modules/mult/SPEC.md](modules/mult/SPEC.md), not a second status table here.

M1/M2's wiring, via/pad, disconnected-pre-route and assembly faults are retained
as regression cases in [../toolkit/test/ValidateTests.hs](../toolkit/test/ValidateTests.hs)
and [../toolkit/test/RouteTests.hs](../toolkit/test/RouteTests.hs). Export and
simulator false-pass cases live in [../toolkit/test-scripts.sh](../toolkit/test-scripts.sh).

## Delivery Sequence

```text
Current work:
V0 Play before building [CURRENT; prototypes not yet built]
  -> Digital versions of the candidate modules in VCV Rack
  -> Representative patches; record concurrent VCA/LFO/envelope/utility use
  -> User playtesting and revision of behavior, grouping and counts
  -> User accepts the musical composition before hardware work resumes

Retained hardware path [DEFERRED behind V0]:
M0/M1/M2/R0 complete; M3 partially complete (CI open)
  -> M4 Close method-rehearsal and order-readiness gaps
  -> P2 Hardware rounds, rechecked against the accepted virtual instrument:
       R1 IO + Mixer -> R2 Slope + VCA -> R3 Filter + VCA -> R4 SSG + Noise -> R5 Boolean + Clock
       every round: models -> error budget -> decks -> board -> checks -> approval -> order
                    -> build -> first power-up -> calibrate -> MEASURE against predictions (M5 gate)
  -> P4 One row: case, panels, the calibration and first-power-up guide
  -> P5 Compounding: block library, first one-shot candidate, then the embedded digital control plane

P1 Shared blocks and L1 further lab procurement are deferred with hardware.
Equipment and reviewed procedures must exist before physical tests, not virtual patching.
CI (M3) remains owed before the first order, not before V0.

Retained panel software:
S1 Shared panel model [DONE 2026-09-16]
  -> S2 Browser module sketcher [DONE 2026-09-16, one gate item open]
  -> S3 Generator bridge and panel exports [DEFERRED]
Sketches may support virtual control planning; physical fit still gates layouts and cutting.
```

Milestones and rounds are acceptance gates, not weekly deadlines. Split each
into work items that fit the available session budget. A later stage must not
assume that an earlier stage's artifacts, equipment, or approvals exist. There
is no hardware schedule while the musical composition is under evaluation;
the earlier six-to-nine-month estimate is not a current delivery plan.

### V0: Playable Digital Modules And Function Balance [CURRENT]

The user has installed VCV Rack to learn by playing before committing to
physical modules. Installation is not evidence that project prototypes exist
or that their musical behavior has been accepted.

1. **Build digital versions of the intended modules.** Start with one playable
   voice and its modulation, gain control and mix/output path, then cover the
   remaining candidate functions. Map each prototype to the intended controls,
   ports, normalled routes and operating modes. Reuse suitable Rack modules or
   patches where they represent the behavior; implement custom Rack DSP when
   a specific behavioral gap needs it. Record substitutions and approximations,
   and respect source and licensing constraints. A convenient stand-in is not
   automatically a validated digital version of the proposed module.
2. **Play an instrument, not isolated demonstrations.** Save representative
   patches for a voice, independently modulated voices and clocked/random
   modulation. Start within the candidate function counts, then record what
   must be added or reassigned to make the patches musically useful. Count
   VCAs for both audio and CV, LFOs, envelopes, mixers/attenuverters, clocks,
   logic and distribution utilities. A slope used as an oscillator cannot
   simultaneously count as an independent LFO, envelope and master clock;
   apply the same rule to a filter used as an oscillator.
3. **Revise from playing evidence.** The user plays the patches and reports
   missing functions, awkward controls, useful combinations and unused
   capacity. Preserve patch files, exact plugin dependencies and observations;
   update the owning specifications and this roadmap when a resulting change
   is agreed. Do not silently add unlimited duplicates, polyphonic channels
   or hidden plugin functions and claim the original hardware row is balanced.

Gate: the prototypes and representative patches reopen and run with recorded
versions; intended behaviors and known differences are documented; concurrent
resource use is accounted for; the user has played them and accepts a revised
or retained composition as the basis for hardware. Until then, no new hardware
round becomes the default next task. Hardware-only inbox choices can wait.

Keep the instrument's visible, persistent controls policy in the digital
design. Rack's host menus and patch saving are software conveniences, not
permission to depend on hidden modes in the eventual module. Virtual audio and
I/O can stand in for the world interface; do not simulate a USB-C power supply
just to make the row playable. A successful patch establishes musical utility,
not analog accuracy, loading, noise, protection, mechanical fit or safety.
SPICE, ERC/DRC, review, physical measurement and purchase approval remain
separate later gates.

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

### S1: Shared Panel Model [DONE 2026-09-16]

Gate met, then simplified the same day on the user's direction. The first
version modelled millimetres, grid profiles and clearance conflicts; the user
judged it far too much for what a sketch is for. What remains is the part that
earns its keep: a strict `module-sketch` v2 format, a catalogue of control kinds, and
**limits derived from the hardware instead of chosen** — at most six columns
and six rows, computed in
[Sketch/Catalogue.hs](../toolkit/src/Sketch/Catalogue.hs) from the footprint
courtyards and the 100 mm board.

That derivation answered the open question about grid height. **Eight rows is
not possible**: it forces 11.5 mm spacing and two 3.5 mm jacks cannot stack
closer than 13.6 mm. Seven forces 13.44 mm and is also out. Six is the
ceiling, and six columns already needs the full 20 HP.

Invalid input still fails clearly: twenty-three rejection cases, every problem
reported at once, each naming its path. What is gone is the class of check
that a better data structure removed — a cell holds one component or nothing,
so overlaps cannot be expressed.

### S2: Browser Module Sketcher [DONE 2026-09-16, one gate item open]

`sketcher/index.html` opens in a browser with no backend, login, cloud
storage, CDN or development server. [SKETCHER.md](SKETCHER.md) is its guide.

It is a grid of cells and a palette of control kinds. Place, rename, drag to
move, Backspace to clear, plus and minus for the grid size, undo and redo per
module, several modules in a list. There is no panel drawing, no size picker
and no millimetre anywhere in the interface; the only physical fact it shows
is the minimum panel width a column count implies, as a note.

Gate items met: placement, editing, undo/redo, resize conflicts and
save/reopen equivalence are covered by 21 tests that run under node
(`node sketcher/tests.js`) and in the browser (`sketcher/tests.html`) against
vectors the generator wrote. Malformed input and a cancelled file open leave
the current work intact, and a malformed stored sketch is reported rather than
deleted. Shrinking the grid over a component is refused with the component
named, so nothing is dropped silently. Those tests never touch the DOM, so
`node sketcher/smoke.js` runs the page itself against a minimal DOM stub,
fourteen checks.

**Open gate item: the rendered screenshots.** The browser extension available
in the 2026-09-16 session could not open a local page or a localhost server,
and the check was stopped after three attempts rather than worked around.
Close it by opening `sketcher/index.html`, at a window width and at a phone
width, and looking.

### S3: Generator Bridge And Panel Exports [DEFERRED]

Not the current software task; V0 takes priority. Prerequisites: S1/S2 and a
reviewed mapping from sketch control IDs to a real
design's parts. Consume the reviewed layout as mechanical input to `pcbgen`;
Haskell remains authoritative for circuits, connections and assembly intent.
Do not leave independently editable coordinates in both the sketch and the
design. Derive panel holes, preview geometry and PCB anchors from the same
records, through `toBoard`/`originFor`, including side and rotation offsets.
Only panel-mounted hardware becomes fixed this way; the electronics remain
subject to electrical placement requirements.

Add true-size SVG previews and separate cut/print layers with explicit units,
only occupied control holes and the required mounting features. A preview is
not a laser-ready release: material, thickness, kerf and actual fit must pass
[the mechanical gate](MECHANICAL.md#grid-and-fit-gate) before a cutting file
is approved. Final panel artwork and fabrication still belong to P4.

Gate: coordinate and output tests prove sketch/panel/PCB agreement, including
a rotated offset-origin part and intentionally blank cells; malformed or
unmapped input is rejected before altering an existing design. Use a reviewed
fixture without snapping existing boards to a candidate grid. Any actual
design migration must pass focused regressions, schematic ERC, then layout
DRC with parity. The browser must not directly edit generated KiCad files.

### M4: Method Rehearsal On The Attenuverter [DEFERRED]

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

### P1: The Two Blocks The System Stands On [DEFERRED]

Resume only after V0 and with a consumer in the accepted hardware composition.
M4 supplies a method and skeleton (`Block.Eurorack`, `Block.Power`,
`Block.Precision`; models, error budget, decks and provenance), but its open
review findings and unperformed power-up guide are not a completed safety gate.

1. **The exponential converter.** Matched transistor pair, temperature
   compensating resistor, scale and high-frequency trimmers; coarse and fine
   tune inputs. Deliverables: the device model for the matched pair with
   thermal coupling, a temperature-sweep deck reporting tracking in cents, the
  confirmed pitch-tracking limit, and the bench calibration
   procedure the user will perform five times per round. Used by R2 and R3.
2. **The gain element.** Choose the OTA or VCA part once (the slope's VCA, the
   filter's drive VCA and the SVF's two integrators all use it), model it from
   its datasheet, and record its limits. Choose it before R2 is drawn.

Gate: both blocks have models, decks with stated limits, and a written
calibration or characterisation step; neither has yet been on a board.

### P2: Hardware Rounds [DEFERRED]

The five rounds below retain the earlier dependency order, to be revised if
V0 changes the accepted composition. Each round is the same sequence and the
same gate. **The gate is a
measurement**, not a passing deck: the board is built, powered through a
current-limited supply, calibrated, and measured against the numbers its decks
predicted. Discrepancies are explained and the cheapest informative next
measurement is chosen; a respin gets its own reason, cost and approval.

| Round | Board | What it proves | Why this position |
|---|---|---|---|
| R1 | **IO + Mixer** — USB-C PD supply and rail distribution; four level-controlled mono DC channels, normalled individual outputs and 3.5 mm TRS consumer audio ([SPEC](modules/io-mixer/SPEC.md)) | Quiet supply and precise interfaces; the modelled crosstalk chain against a **two-trace coupon** on spare area | Provides power and world audio interfaces. First-power and switching/precision measurements still require the reviewed bench setup, not just a charger and DAW. |
| R2 | **Slope + VCA** — half a DUSG cycling as a tracking triangle VCO, EOR/EOF triggers, VCA normalled to the slope | The exponential-converter block on the simpler circuit; the shared gain element; the first voice | Audible through R1. Proves P1 on the circuit that is easier to reason about |
| R3 | **Resonant Filter + VCA** — drive stage into a 2-pole SVF, LP/BP/HP/notch, feedback path, tracking at self-oscillation | The same expo block reused, not re-proven; drive and feedback behaviour; the second oscillator | The voice gets its character |
| R4 | **SSG + Noise** — smooth/stepped generator, S&H and T&H, analog white noise, comparator | Hold-stage droop and feedthrough; noise level range and spectrum; comparator behaviour | Modulation and randomness; depends on nothing new but the analog switch |
| R5 | **Boolean + Clock** — shared-threshold logic including `A AND NOT B`, edge triggers, /2 to /16 divider with reset, and a candidate fixed-pattern trigger sequencer ([draft plan](modules/boolean-clock/SPEC.md); architecture asked in [decisions/2026-09-15-logic-module-architecture.md](decisions/2026-09-15-logic-module-architecture.md)) | Logic thresholds and timing; a divider chain five boards deep; the first digital-logic modelling step | Utilities last; nothing depends on them, but its logic levels are fixed early so R2's triggers meet them |

R1's behavior was approved in conversation on 2026-09-14 and is now in
[modules/io-mixer/SPEC.md](modules/io-mixer/SPEC.md); its two answered inbox
files are retired. The agent derives the electrical limits and panel allocation
from those decisions. Later rounds need their own specification and any genuine
user-facing choices resolved when relevant. The pitch tracking limit is already
confirmed; do not reopen it as a blank questionnaire.

Per-round gate: the board's stated behaviours pass both their simulation
assertions and their physical measurements within the chosen cost and space;
calibration is documented and repeatable; evidence is recorded against the
board revision and installed parts. Budget and approve each round separately.

### L1: Build The Home Lab In Stages [FURTHER PROCUREMENT DEFERRED]

Use the agreed budget and the confirmed inventory, not an empty-bench
assumption. No additional bench equipment is required to begin V0. Resume
procurement against the accepted hardware's needs; necessary equipment **must
exist before its boards are powered.** [HOMELAB.md](HOMELAB.md) owns the
candidates, prices and purchase record; do not duplicate a shopping total here.
The agent verifies the exact
equipment, supported setup and delivered price before recommending a basket.
The user confirms purchases and receipt.

Any additional assembly purchase still needs approval. Supply series operation,
precision DC measurement and R1's switching/stability tests need verified methods
before instrument selection is final. Scriptability is a bonus, not a requirement.
No extractor is added against the user's direction; the proposed window/fan
arrangement is not thereby verified as adequate ventilation. The stages below
use HOMELAB's letters, and equipment must precede the tests that need it.

| Stage | Equipment and guidance | Acceptance |
|---|---|---|
| A (part 1): assembly and basic measurements | Temperature-controlled soldering station, tips/stand, solder/flux, cleaning, cutters/tweezers, heat-resistant surface, assessed ventilation, eye protection, ESD basics, an appropriately protected multimeter and rated leads | Guided practice and continuity/resistance checks completed before working on the first module |
| A (part 2): safe first power | Current-limited bench supply capable of bipolar ±12 V (series-capable channels), a USB-C PD charger and PD tester for R1, identified cables, connectors and protection | Exact wiring, polarity, grounding, current-limit settings and shutdown criteria documented and checked without a board attached |
| B: dynamic measurements and scripting | Suitable audio interface, protected adapters and a separate DC-stimulus method; scope and probes selected for R1's converter/amplifier checks | Guided safe probing, a known-signal exercise and an uncertainty budget; a first measurement script reports actual instrument readings |
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

After the accepted hardware rounds: assemble the composition agreed through V0,
using its measured boards and reviewed power arrangement. Write the calibration
and first-power-up guide as the durable
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
- **Embedded digital control plane:** still deferred; desktop VCV Rack
  prototypes do not bring firmware or a processor into the hardware by default.

### Toolkit Obligations Along The Way

- **Ground-plane integrity** as a routing objective and check. The missing
  objective identified in [JLCPCB.md](JLCPCB.md); it becomes concrete on R1,
  where switching converters sit beside precision rails.
- **CI** (M3), before the first order.
- **Board variants** (same SMD, different hand-population) only if a round
  needs them; not speculatively.
- **Shared interface conventions:** finish consistent panel labels, control
  direction, bipolar zero, switch positions and normalled-route notation in
  S1/S2. Derive nominal audio/CV ranges, gate thresholds, loading and protection
  from R1 and later consumers' actual requirements; the connector shape alone
  does not specify electrical compatibility. Keep numerical limits in the
  owning module specifications and reuse them, rather than inventing a universal
  signal level now. Fit, material and hardware-variant choices remain in
  [MECHANICAL.md](MECHANICAL.md), not a new standards questionnaire.

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

- **Fixed-pattern trigger sequencer in R5:** raised by the user on 2026-09-15;
  explore its musical behavior in V0 while its hardware architecture decision
  is deferred. It has no pots per step and selects patterns
  with a maintained switch; see the [R5 plan](modules/boolean-clock/SPEC.md).
  It does not un-park the item below.
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

- **Musical evidence:** installation and an agent's proposed patch are not a
  playtest. Function balance and the user's playing experience gate hardware.
- **Money:** payment readiness is recorded in [HOMELAB.md](HOMELAB.md), not an
  outstanding card-acquisition task. Paid software, lab purchases and board
  orders still need approval; a card does not establish design readiness.
- **Remaining decisions:** R1's approved normalled consumer outputs conflict
  with the proposed unswitched stereo jack; the alternative is still unanswered
  in [the hardware inbox](decisions/2026-09-14-panel-hardware.md). This and R5's
  hardware architecture are deferred, not blockers to virtual prototypes. Do not change
  its behaviour by treating a recommendation as approval. Later SSG details may
  need a choice when that round starts; the two-pole filter and tracking limit
  are already settled. Electrical budgets are agent design work. Option B is
  implemented; readiness findings, part evidence, cost and stock remain open.
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
| This roadmap | Agreed priorities, V0 musical gate, deferred hardware rounds and S1-S3 panel gates; update at every material change |
| [HANDOFF.md](HANDOFF.md) | Agent-maintained compact current/blocked/next state and evidence; Git retains past checkpoints |
| [HOMELAB.md](HOMELAB.md) | Staged lab shopping list with prices, reasons and laptop connectivity; agent-maintained, user-confirmed |
| Stack decision and toolchain record | Agent-maintained versions, installation checks, tested library inputs, and reasons for any migration; build on [SETUP.md](SETUP.md) |
| Per-module specification and tests | `docs/modules/<name>/SPEC.md` owns intent and limits; executable simulations and tests stay with the design/code |
| VCV Rack prototypes and playtest evidence | Reopenable patches, recorded Rack/plugin versions, behavior mappings and limitations, concurrent function counts and user observations; create with the first actual prototype, not as empty scaffolding |
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

**Begin V0 with a playable voice in VCV Rack.** Record the installed Rack
version and available plugins, map the first candidate module behaviors to
digital implementations, and build a saved patch with a voice, VCA, envelope,
independent LFO and mix/output path. Label any stand-ins and count resources
against the starting composition. The immediate result must be something the
user can play, not a new hardware circuit or another planning framework.

Extend that patch into the representative instrument tests in V0, collect the
user's observations, and agree any changes to module grouping or counts before
hardware resumes. Neither the existing hardware inbox nor additional lab
purchases block this work. Use the current specs and compact handoff; add
prototype artifacts only when they contain real work.

The sketcher remains available for control ideas; S3, circuit/layout work and
further lab procurement are deferred. CI and all findings and release gates in
[ORDER-READINESS.md](ORDER-READINESS.md) remain owed before any future order.
