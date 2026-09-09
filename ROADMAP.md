# Roadmap: From A Musical Idea To A Tested Module

Updated: 2026-09-09. Status: agreed direction; implementation milestones below are not complete.

## Goal And Constraints

Make it practical for a non-technical musician to describe a Eurorack module,
have an agent maintain its design and generate manufacturing files, then
assemble and test it using detailed instructions. Success is a working
instrument and a repeatable process, not a more elaborate CAD framework.

| Decision | Direction |
|---|---|
| First priority | A reliable agent-driven design, verification, and export workflow |
| Long-term modules | Serge DUSG (Dual Universal Slope Generator) and SSG (Smooth & Stepped Generator) behavior and patching possibilities |
| Fidelity | Musical behavior matters more than historical circuitry; modern components are acceptable |
| Human role | Describe features, choose between explained alternatives, approve purchases, install larger parts, and perform guided measurements |
| Agent role | Own design code, tooling, sourcing research, calculations, checks, documentation, and troubleshooting |
| Assembly | Prefer factory-installed SMD; hand-install jacks, pots, headers, and other suitable large parts |
| Work cadence | Approximately one session per week, using a variable remaining token budget; progress must survive gaps and model changes |
| Prototype budget | EUR 150-300 per round, including boards, assembly, parts, VAT, shipping, and applicable fees; each round requires approval |
| Home lab | Start from an empty bench; EUR 500-1000 initial budget, purchased in stages from Belgium/EU-compatible sources |
| Eurorack case | Deferred and budgeted separately; first boards use a safe, current-limited test setup |
| Release intent | Personal instrument; a public repository is acceptable, but commercial readiness is not a current goal |
| Stack policy | Code-first and headless; retain working pieces and replace weak ones on evidence |

The user should not need to learn Haskell, manually repair KiCad files, resolve
Python installations, interpret a DRC report unaided, or invent a test plan.
The agent must explain choices in terms of musical behavior, cost, risk, and
work required from the user. It must not invent measurements or treat its own
confidence as evidence that a circuit works.

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
| SPICE | Add a pinned, headless ngspice workflow unless a tested compatibility need favors another simulator | Executable, model provenance, complete test circuits, assertions, and useful failure reports work on the supported workstation |
| Datasheets and sourcing | Add structured part records and a local evidence cache; use distributor helpers as replaceable adapters | Exact part identity, package, pin mapping, ratings, tolerances, and assembly availability can be checked without relying on a chat assertion |
| Automated checks | Add real regression tests and CI; retain native ERC/DRC as separate checks | Fault-injection tests fail for the right reason; positive fixture projects still pass |
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

The 2026-09-09 local review established the following. These results do not
constitute fabrication approval, and ignored local review files are not a
dependency of this roadmap.

| Capability | Actual state |
|---|---|
| Generator | Builds; fresh mult and attenuverter generation matched current working-tree artifacts byte-for-byte on that workstation |
| Native checks | Both circuit boards, both front panels, and the routing fixture passed ERC, DRC with zone refill, and schematic parity |
| Export | KiCad CLI 10.0.3 and KiKit 1.8.1 produced attenuverter Gerbers, a seven-line BOM, and 16 matching SMD placements |
| Test suite | `cabal test all` reported no test suites; the routing fixture is not a substitute for assertions |
| Electrical evidence | No completed manufacturer-datasheet audit, supported SPICE executable, or measured prototype |
| Procurement | No approved equipment list, chosen mechanical stack, or approved prototype order |

Carry these review findings into tracked regression tests, not just a narrative:

| Finding | Reproduction / source | Required outcome |
|---|---|---|
| Implicit no-connects and power flags hide errors | Removing U1.8, mistyping it as U1.88, assigning it to both rails, or removing D2.1 from the positive rail all passed ERC. See [toolkit/src/Emit/Schematic.hs](toolkit/src/Emit/Schematic.hs). | Design validation rejects each fault before emission; intentional NC and power sourcing are explicit |
| SMD pad drills | Native KiCad geometry found 0.3 mm via drills inside C1.2, C4.2, R3.2, and R4.1 solder lands. See [toolkit/src/Route/Router.hs](toolkit/src/Route/Router.hs). | Ordinary assembly forbids these intersections; fix the four current locations |
| Pre-route connectivity | Pads at (2,5) and (18,5), with an existing trace only from (15,5) to (18,5), produced router success without connecting the first pad. | Treat copper islands as separate components to connect, and test the final connectivity |
| Export accepts stale or failed inputs | [toolkit/fab.sh](toolkit/fab.sh) only requires a build PCB; [toolkit/check.sh](toolkit/check.sh) leaves copied files after failures. | Export requires successful checks on exactly the artifacts being exported |
| Sourcing omission changes assembly | [toolkit/src/Emit/Pcb.hs](toolkit/src/Emit/Pcb.hs) interprets a missing LCSC field as hand assembly. | Missing data for an intended factory-installed part fails validation |

## Delivery Sequence

```text
M0 Direction recorded [DONE]
  -> M1 Explicit design intent and rejection tests [NEXT]
  -> M2 Routing and assembly correctness
  -> M3 Reproducible, fail-closed pipeline
  -> M4 Circuit evidence and complete prototype package
  -> human approval -> order -> delivery -> M5 guided build and measurements
  -> M6 one DUSG core, then the complete module
  -> M7 one SSG core, then the complete module

L1 Staged home-lab plan can progress alongside M1-M4.
L1 equipment, training, and safe test setup must be ready before M5 power-up.
```

Milestones are acceptance gates, not weekly deadlines. Split each into work
items that fit the available session budget. A later stage must not assume
that an earlier stage's artifacts, equipment, or approvals exist.

### M1: Make Invalid Designs Fail

Prerequisites: current design model and the review reproductions above.

- Add a real Cabal test suite and tracked negative fixtures. Convert diagnostic probes into assertions; reproducing a bug is not a passing release test.
- Validate unique references/net names, existing references and pin numbers, conflicting assignments, symbol-to-pad mappings, and supported features. Reject invalid numerical dimensions and routing settings.
- Distinguish unassigned pins from explicitly intentional no-connects. Treat power flags as declarations supported by an intended source path, not blanket ERC suppression.
- Migrate existing modules without silently changing their intended connections. Include multi-unit symbols and front/back transforms in coverage.

Gate: the four wiring faults are rejected with useful diagnostics, intentional
NC cases succeed, and all existing native-check fixtures still pass. These
tests establish compiler behavior, not manufacturer-level circuit correctness.

### M2: Make Routing And Assembly Intent Explicit

Prerequisites: M1 tests and validated existing designs.

- Block ordinary via drills in SMD solder lands; test drill/pad geometry independently of the router's success flag. Repair the attenuverter layout.
- Fix disconnected pre-routed islands and respect supplied manual trace widths. Treat incomplete/conflicted routes as failures, not stderr-only warnings.
- Model factory-installed, hand-installed, DNP, and mechanical items separately. Require supplier identity for every factory-installed part; never infer hand assembly from missing data.
- Check BOM/placement reference parity, assembly sides, explicit exclusions, rotations, and footprint mappings. Generate a complete manual-parts/hardware list as well as the factory BOM.

Gate: positive and negative routing/assembly fixtures pass their assertions;
current boards pass native DRC/parity; no unresolved SMD pad drills remain.
If the router cannot meet this gate economically, run the bounded replacement
evaluation described above before building more routing features.

### M3: One Reproducible Pipeline

Prerequisites: M1-M2 passing tests. The command described here is a deliverable,
not a command that already exists.

- Provide a single documented entry point for tool preflight, validation, generation, checks, and prototype export. Keep inexpensive test-only use available.
- Stage fresh outputs: validate -> schematic -> ERC -> layout -> DRC with refill/parity -> assembly/manufacturing checks -> exports -> manifest. Publish a successful package only after all required steps succeed.
- Bind results to source/library/model inputs, tool versions, and hashes of the actual checked schematic, filled PCB, and exported files. Record dirty-tree provenance explicitly; a commit ID alone is insufficient.
- Test failure, interruption, stale input, missing tool, and missing-part behavior. A failed run must not leave an old package appearing to be its successful output. Separate optional renders from mandatory checks in the status report.
- Pin or reproducibly retrieve supported dependencies and used libraries. Add CI for regression tests and native fixture checks. Fix setup mismatches before treating them as design defects.
- Install and smoke-test headless SPICE. Remove reliance on globally installed agent skills for essential gates; document and version required adapters and their failure behavior.

Gate: an agent in a fresh checkout can reproduce the fixture checks and
diagnostic export without hidden manual repair. An interrupted or faulty run
cannot yield a package labeled as passing. Documentation distinguishes
"generated," "checks passed," and "reviewed prototype candidate."

### M4: Evidence And A Complete Prototype Package

Prerequisites: M3 and the existing attenuverter as the end-to-end test vehicle.
The passive mult can be a mechanical/soldering exercise, but does not prove
active-circuit design. Do not enlarge the utility's feature set to fill time.

- Define the utility's operating envelope and tolerances. Account for knob-dependent input loading, the shared supply-derived offset, output loading, input headroom, patch faults, startup, and power consumption.
- Obtain exact IC, diode, passive, jack, pot, and header identities and relevant datasheets. Record source URLs, document/model versions, permitted redistribution, and missing evidence. Library agreement is not a datasheet check.
- Add readable functional schematic views and parameterized tests for the actual circuit. Simulate DC transfer, loading, both channels' interaction, transients, and relevant tolerance/supply corners. State model limitations, especially overload and protection behavior.
- Review layout by circuit function, local feedback/decoupling, sensitive-node routing, and return paths. Check manufacturing constraints against the selected assembly service; triage heuristic EMC/thermal results instead of interpreting scores as approval.
- Check the complete mechanical stack: XY alignment, body/bushing heights, PCB-to-panel spacing, thickness, knobs, nuts, rails, and tolerances. Do not buy a final case merely to discover these constraints.
- Deliver manufacturing files, order settings, current itemized cost/stock, supplier-placement review, full hand-parts/accessories list, annotated assembly views, and a board-revision-specific first-power-up/test guide.

Gate: every consequential electrical, mechanical, sourcing, and assembly
assumption has evidence or an explicit prototype experiment with bounded
risk. The human receives a plain-language preview and an all-in quote within
the approved budget. No purchase is automatic. A reviewed prototype candidate
is allowed to be unbuilt; it must not be labeled bench-tested or production-ready.

### L1: Build The Home Lab In Stages

Prerequisites for planning: the agreed budget and an empty bench. This work can
start before M4; purchases remain optional until an equipment plan is approved.

Produce a Belgium/EU shopping and setup guide with exact models, current
VAT-inclusive delivered prices, compatibility, essential accessories, reasons
for each item, and one suitable alternative. Separate required-now items from
later upgrades and consumables. The EUR 500-1000 is a planning envelope, not a
price quotation; show the complete total before recommending a purchase.

| Stage | Equipment and guidance | Acceptance |
|---|---|---|
| Assembly and basic measurements | Temperature-controlled soldering station, suitable tips/stand, practice material, solder/flux, cleaning, cutters/tweezers, magnification, heat-resistant work surface, appropriate fume control, eye protection, and a suitable fused-input DMM with leads | Guided practice and continuity/resistance checks completed before working on the first module |
| Safe first power | Commercial current-limited supply solution suitable for the required bipolar rails, or explicitly series-capable isolated channels; identified test cables, connectors, and protection | Exact wiring, polarity, grounding, current-limit settings, and shutdown criteria documented and checked without a board attached |
| Dynamic measurements | Oscilloscope and probes suitable for the planned signals; a compatible signal/CV stimulus source or integrated generator if economical | Guided probe compensation and known-signal exercise; the user can capture and return meaningful readings/traces |
| Later expansion | Eurorack case/power, additional measurement equipment, and specialized rework tools | Buy only when a named task requires them; case/power have a separate budget |

No DIY mains wiring, PSU internals, mains probing, or defeated protective earth.
Use commercially enclosed mains-powered equipment and follow its documentation.
Ordinary oscilloscope probe grounds are common and usually earth-referenced;
the guide must identify the correct circuit reference and must not assume a
channel or supply can float. In-circuit tests use a low-voltage, current-limited
setup; unexplained current, heating, polarity, or ground ambiguity stops testing.

### M5: Guided Physical Proof

Prerequisites: approved M4 package, purchased/delivered hardware, and the L1
equipment and training needed for each step. Until delivery, status is
"waiting for hardware," not "testing in progress."

- The agent provides numbered steps with annotated photos/diagrams, instrument settings, expected ranges, and stop conditions. The user reports observations; neither party fills in an unmeasured result.
- Inspect and assemble, perform unpowered checks, then follow the reviewed current-limited first-power sequence. Check rails/current before signal tests.
- Measure gain/null, offset interaction, loading, bandwidth/transients, safe overload behavior, and mechanical fit against M4 limits. Identify the board revision, installed parts, instruments, and test conditions.
- Explain any discrepancy and choose the cheapest informative next measurement. A respin receives a separate reason, cost estimate, and approval.

Gate: a physical active utility passes its stated tests and the user can
complete the procedure without writing code or inventing electrical tests.
Record measurement evidence and lessons; only then promote blocks as
bench-tested. A hobby prototype pass is not certification or approval for sale.

### M6: DUSG Behavior, Then Hardware

Prerequisites: M5 for ordering complex hardware. Reference research and
specification drafts may begin earlier, but do not bypass the pipeline gates.

The agent selects a credible reference and presents musical tradeoffs, while
checking permissions before copying or publishing derivative material. Define
rise/fall ranges, CV response, trigger/retrigger behavior, cycling, end outputs,
signal levels, and any audio-rate or pitch-tracking requirement. The agent
proposes technical limits from desired patches; the user chooses outcomes.

Prototype one slope core with appropriate device models, complete transient
feedback behavior, corner tests, and accessible measurements. Reuse tested
power/interface blocks only within their established limits. Extend to the
dual module and final panel after the core passes bench tests, then test
channel interaction and the promised patches.

Gate: the stated DUSG behaviors pass both relevant simulation assertions and
physical tests within the chosen cost/space limits. Budget and approve each
hardware round separately.

### M7: SSG Behavior, Then Hardware

Prerequisites: the reusable workflow and tested support blocks. DUSG-first is
the proposed default, not a claim that the SSG electrically depends on a DUSG;
the user can reprioritize before core work begins.

Select the reference behavior and define smooth/stepped interaction, sampling,
hold droop, acquisition/settling, feedthrough, comparator behavior, loading,
and musical patch examples. Allocate an error budget across switches, buffers,
capacitors, protection, and PCB surface leakage; do not assume a generic SPICE
model captures all of them. Prototype and measure the hold/sampling core before
the complete layout, then validate the full module and its interactions.

Gate: the selected SSG behaviors and numerical limits are supported by measured
hardware, with calibration and a repeatable build/test package.

## Weekly Session Contract

The agent may choose and execute a bounded task within this roadmap. It asks
at material design decisions, budget changes, purchases, uncertain safety
steps, or stack migrations. It does not require approval for every routine
code edit or test. Repository writes, commits, and upstream pushes remain
subject to the user's explicit instructions; a roadmap is not push authority.

1. Read this roadmap, the current operating rules in [CLAUDE.md](CLAUDE.md), and the last tracked handoff. Check actual inputs and worktree state before choosing work.
2. Select one main outcome: a named failing behavior, an evidence gap, or a guide with a concrete acceptance check. Announce the scope and what would disprove the proposed solution.
3. Implement in small steps and run the narrow relevant checks. Escalate only on evidence; do not use remaining tokens as a reason to add unrelated features or endlessly compare tools.
4. Before stopping, leave a tested checkpoint or explicitly mark partial work as blocked/non-releasable. Preserve existing user changes and record which edits belong to this task.
5. Update durable state with the exact result, artifact paths/hashes, commands and tool versions, remaining risks, open questions, and one next action with its prerequisites. Say what has not been run.

There is no promise of background work between sessions. Every new agent must
be able to resume from tracked documents, not private memory or ignored scratch
files. Avoid recreating already answered questions or repeatedly running broad
analysis when the relevant inputs have not changed.

## Durable Deliverables

Create these when their milestone supplies real content, not as empty process
scaffolding. The first M1 work item should start the compact session handoff.

| Artifact | Purpose / owner |
|---|---|
| This roadmap | Agreed priorities, constraints, milestone status; update at material decisions |
| Tracked session handoff and artifact index | Agent-maintained current/blocked/next state, actual outputs, evidence locations, and missing prerequisites |
| Stack decision and toolchain record | Agent-maintained versions, installation checks, tested library inputs, and reasons for any migration; build on [SETUP.md](SETUP.md) |
| Per-module specification and tests | Musical intent translated into numerical limits, simulations, and measurement assertions; build on the existing specifications |
| Part evidence and manufacturing recipe | Exact identities/ratings, sourcing checks, assembly intent, approved process options, and complete order list |
| Lab and board-specific assembly/test guides | Instructions sufficient for a beginner to buy, set up, measure, and stop safely |
| Prototype record | Human observations plus agent analysis, tied to board revision and actual installed parts |

Commit source designs, tests, guides, status, and suitable summaries. Generated
KiCad projects remain tracked; fabrication output and binaries remain outside
git as required by the repository. Retain purchased-revision bundles and bench
evidence in a durable user-controlled archive with hashes/locations recorded
in tracked state, not only ephemeral CI artifacts. Keep secrets, addresses,
order credentials, and personal history out of public files. Respect datasheet
and model redistribution terms.

## Next Work Item

**M1, first slice: explicit unassigned/NC handling and rejected pin references.**
Add the test harness, make the missing-U1.8 and nonexistent-U1.88 cases fail at
design validation, and preserve the existing intentionally unused jack switch
pins. Run the focused tests and required native checks after regeneration.
Record the result in the tracked handoff. Address duplicate assignments and
explicit power-source validation as the following small slices, rather than
attempting a complete compiler redesign in one session.

After M1, progress through the gates above. Further technical questions should
be asked when they control the next decision, not presented to the user as a
prerequisite to learning the entire engineering discipline.