---
status: "maintained"
owner: "collaborating agents"
read_when: "finding a document, starting work, or deciding where new information belongs"
update_when: "a document is added, moved or retired; do not duplicate its current results here"
retire_when: "a replacement index is agreed and all incoming links are updated"
---

# Documentation

## Start Here

This is the single document register. The folder is `docs/`; there is no parallel
`notes/` tree. You do not need to read the code or every technical report to
follow the project. **VCV Rack musical prototypes are the current priority**;
hardware design and further procurement are deferred under the roadmap's V0
gate. Each current or retained track has one owning document:

| Track | Open This | What You Decide |
|---|---|---|
| Play digital module prototypes and test the instrument balance | [ROADMAP.md](ROADMAP.md#v0-playable-digital-modules-and-function-balance-current) | What works when played, which functions run short or go unused, and which composition should become hardware. The agent builds reproducible prototypes and accounts for shared resources. |
| Sketch control ideas, when useful | [SKETCHER.md](SKETCHER.md) | What goes where on a module. The local grid editor is not an audio simulator; the generator bridge (S3) remains deferred. |
| Retained R1 IO + Mixer requirements | [modules/io-mixer/SPEC.md](modules/io-mixer/SPEC.md) | Existing behavior informs virtual prototypes; physical connector, circuit and layout decisions resume after the musical gate. |
| Equipment inventory and deferred lab procurement | [HOMELAB.md](HOMELAB.md) | Confirm owned equipment and approve any later spending. The inventory and payment readiness are recorded separately from unverified historical shopping candidates. |

[HANDOFF.md](HANDOFF.md) holds current progress and the next actions.
[decisions/README.md](decisions/README.md) explains the inbox for new, genuinely
necessary questions. Answered questions are integrated into their owning document
and deleted after the checkpoint, not kept as another set of notes.

## Complete Register

| Document | Authoritative purpose |
|---|---|
| [../README.md](../README.md) | Repository introduction, virtual-first workflow and retained hardware pipeline. |
| [../AGENTS.md](../AGENTS.md) | Standing operating rules, document lifecycle and decision processing. |
| [../CLAUDE.md](../CLAUDE.md) | Thin entry point importing the shared agent rules. |
| [HANDOFF.md](HANDOFF.md) | Current checkpoint, verified evidence, limitations and next action. |
| [ORDER-READINESS.md](ORDER-READINESS.md) | Current hold verdict, electrical and bring-up findings, review coverage and requirements before a prototype order. |
| [ROADMAP.md](ROADMAP.md) | Direction, V0 digital prototypes and musical acceptance, retained hardware constraints/rounds and S1-S3 panel milestones. Agent-maintained. |
| [SETUP.md](SETUP.md) | VCV Rack setup status and reproduction requirements; retained hardware toolchain, commands and known pitfalls. |
| [HOMELAB.md](HOMELAB.md) | Confirmed equipment purchases, payment readiness, deferred procurement, historical candidates and safety/capability checks. Not a buy-all basket. |
| [JLCPCB.md](JLCPCB.md) | What the fab actually charges for, and which routing objectives that justifies. |
| [MECHANICAL.md](MECHANICAL.md) | Adopted sparse panel language, provisional grid and laser-material fit gate, panel-to-board stack, module depth and hardware catalogue; distinguishes in-use parts, proposals and unmeasured fit. |
| [SKETCHER.md](SKETCHER.md) | The module sketcher: how to use it, the `module-sketch` format, how a sketch is exchanged, and why the grid is at most six by six. |
| [decisions/README.md](decisions/README.md) | Editable decision inbox: how the user answers and the agent integrates answers. |
| [decisions/2026-09-14-panel-hardware.md](decisions/2026-09-14-panel-hardware.md) | Retained, deferred hardware inbox: persistent-switch policy settled; R1 normalling and exact hardware variants still unanswered. Does not block V0. |
| [modules/io-mixer/SPEC.md](modules/io-mixer/SPEC.md) | R1's approved four-channel mono/DC behavior and 3.5 mm stereo consumer audio boundary; implementation requirements. |
| [modules/boolean-clock/SPEC.md](modules/boolean-clock/SPEC.md) | R5's draft plan from the user's 2026-09-15 notes: `A AND NOT B`, proposed behavior table, budget items to derive, and the staged plan. Not approved behavior. |
| [decisions/2026-09-15-logic-module-architecture.md](decisions/2026-09-15-logic-module-architecture.md) | Unanswered hardware architecture choice, deferred during V0; desktop prototypes do not select CMOS, ROM, programmable logic or firmware for the board. |
| [modules/attenuverter/SPEC.md](modules/attenuverter/SPEC.md) | Attenuverter intent, the option B decision record, the precision circuit, simulated results against the adopted limits, parts. |
| [modules/attenuverter/ERROR-BUDGET.md](modules/attenuverter/ERROR-BUDGET.md) | Attenuverter precision error budget: envelope, datasheet evidence, first versus adopted parts, the adopted acceptance limits. |
| [modules/attenuverter/POWER-UP.md](modules/attenuverter/POWER-UP.md) | Draft first-power-up procedure; do not use unchanged until the safety and measurement findings in ORDER-READINESS.md are closed. |
| [modules/mult/SPEC.md](modules/mult/SPEC.md) | Passive mult intent, connectivity, geometry and assembly. |
| [BENCH.md](BENCH.md) | Recorded routing benchmark output, not a fabrication or SOTA approval. |
| [modules/attenuverter/route-report.md](modules/attenuverter/route-report.md) | Generated attenuverter routing and predicted analog findings. |
| [modules/mult/route-report.md](modules/mult/route-report.md) | Generated mult routing report. |
| [modules/route-test/route-report.md](modules/route-test/route-report.md) | Generated routing-fixture report. |

Every document carries its status, owner and lifecycle as YAML frontmatter at
the very top of the file, fenced by `---`. It is metadata, so it sits outside
the prose and can be read without parsing the body. A file is not a permanent
archive simply because it is Markdown: retain one current owner for a fact and
use Git for superseded versions. Closed decisions are removed after their
answers and outcomes have been integrated and checkpointed.

Before adding a document, use an existing authoritative home where possible.
Any new document must have a distinct job, an index entry and retirement criteria.
Keep numerical detail in specifications/reports, shopping detail in HOMELAB and
current progress in HANDOFF. Frontmatter is a rule the agent must apply, not a
background process that automatically removes stale files.

## Where The Code Lives

These are the existing laptop hardware-design tools and sketcher, not firmware
inside the modules or an implementation of the planned VCV Rack prototypes.

| Example | What It Does |
|---|---|
| [Attenuverter.hs](../modules/attenuverter/Attenuverter.hs#L1) | An existing module's parts, connections and physical placement, written as Haskell data. R1 does not have an implementation yet. |
| [Block/Precision.hs](../toolkit/src/Block/Precision.hs#L1) | A reusable circuit definition used by a module. |
| [Block/Eurorack.hs](../toolkit/src/Block/Eurorack.hs#L1) | Panel/PCB skeleton and centre-to-footprint transforms that the planned sketcher bridge must reuse. |
| [Main.hs](../toolkit/app/Main.hs#L1) | Runs the generator and selects the requested design. |
| [Emit/Pcb.hs](../toolkit/src/Emit/Pcb.hs#L1) | Converts a circuit description into a KiCad board file. Other emitters produce schematics and simulation netlists. |
| [Route/Router.hs](../toolkit/src/Route/Router.hs#L1) | Searches for copper connections between placed parts. |
| [Sketch/Model.hs](../toolkit/src/Sketch/Model.hs#L1) | The sketch interchange format a module idea is written in. The grid limits are derived beside it in `Sketch/Catalogue.hs`. |
| [sketcher/index.html](../sketcher/index.html) | The browser grid editor. Open the file; there is no server or build step. |
| [pipeline.sh](../toolkit/pipeline.sh#L1) | Runs generation, native checks and optional export; simulation is run separately by [sim.sh](../toolkit/sim.sh#L1). |

The sketcher is a local HTML page under `sketcher/`, two of whose files the
generator writes. It places components on a grid and nothing more: no KiCad
file, no circuit, no cutting file. The bridge that would consume a reviewed
sketch is [S3 in the roadmap](ROADMAP.md#s3-generator-bridge-and-panel-exports-deferred).

## What Stays Outside Docs

Haskell designs, simulation decks/models, KiCad library assets and generated
KiCad projects remain beside the code that uses them. The sketcher's page and
scripts live in `sketcher/` and sketch files in `sketches/`, because they are
code and data rather than documentation. Ignored `build/`
directories contain diagnostic reports, renders and fabrication artifacts,
not authoritative requirements. Installed software and datasheet caches do
not become tracked documentation by being copied into this folder.

The only tracked Markdown entry points outside this folder are the root
README and agent instruction files. Custom `pcbgen --out DIR` exports keep
their Markdown inside `DIR/docs/`; do not commit scratch bundles into the
source tree.