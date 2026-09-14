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
follow the project. The current two tracks have one working document each:

| Track | Open This | What You Decide |
|---|---|---|
| Finish the first module, R1 IO + Mixer | [modules/io-mixer/SPEC.md](modules/io-mixer/SPEC.md) | Musical behavior and meaningful scope/cost tradeoffs. The agent owns the circuit, parts, calculations and checks. |
| Prepare the home lab for its first boards | [HOMELAB.md](HOMELAB.md) | Approve the exact purchase basket and confirm what arrived. The agent checks equipment capability, compatibility and the delivered total first. |

[HANDOFF.md](HANDOFF.md) holds current progress and the next actions.
[decisions/README.md](decisions/README.md) explains the inbox for new, genuinely
necessary questions. Answered questions are integrated into their owning document
and deleted after the checkpoint, not kept as another set of notes.

## Complete Register

| Document | Authoritative purpose |
|---|---|
| [../README.md](../README.md) | Repository introduction and code-first workflow. |
| [../AGENTS.md](../AGENTS.md) | Standing operating rules, document lifecycle and decision processing. |
| [../CLAUDE.md](../CLAUDE.md) | Thin entry point importing the shared agent rules. |
| [HANDOFF.md](HANDOFF.md) | Current checkpoint, verified evidence, limitations and next action. |
| [ORDER-READINESS.md](ORDER-READINESS.md) | Current hold verdict, electrical and bring-up findings, review coverage and requirements before a prototype order. |
| [ROADMAP.md](ROADMAP.md) | Direction, constraints, and the phased plan: shared blocks, five rounds (one board each), one row, then compounding. Agent-maintained. |
| [SETUP.md](SETUP.md) | Installation, reproduction commands and known tool pitfalls. |
| [HOMELAB.md](HOMELAB.md) | Staged home-lab shopping list (bol.com, debit card): what to buy, why, prices seen, and which instruments the laptop can drive. |
| [JLCPCB.md](JLCPCB.md) | What the fab actually charges for, and which routing objectives that justifies. |
| [MECHANICAL.md](MECHANICAL.md) | Panel-to-board stack, module depth and the fit review of each board, from manufacturer drawings until a build measures them. |
| [decisions/README.md](decisions/README.md) | Editable decision inbox: how the user answers and the agent integrates answers. |
| [modules/io-mixer/SPEC.md](modules/io-mixer/SPEC.md) | R1's approved four-channel mono/DC behavior and 3.5 mm stereo consumer audio boundary; implementation requirements. |
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

These are laptop design tools, not firmware inside the analog modules.

| Example | What It Does |
|---|---|
| [Attenuverter.hs](../modules/attenuverter/Attenuverter.hs#L1) | An existing module's parts, connections and physical placement, written as Haskell data. R1 does not have an implementation yet. |
| [Block/Precision.hs](../toolkit/src/Block/Precision.hs#L1) | A reusable circuit definition used by a module. |
| [Main.hs](../toolkit/app/Main.hs#L1) | Runs the generator and selects the requested design. |
| [Emit/Pcb.hs](../toolkit/src/Emit/Pcb.hs#L1) | Converts a circuit description into a KiCad board file. Other emitters produce schematics and simulation netlists. |
| [Route/Router.hs](../toolkit/src/Route/Router.hs#L1) | Searches for copper connections between placed parts. |
| [pipeline.sh](../toolkit/pipeline.sh#L1) | Runs generation, native checks and optional export; simulation is run separately by [sim.sh](../toolkit/sim.sh#L1). |

## What Stays Outside Docs

Haskell designs, simulation decks/models, KiCad library assets and generated
KiCad projects remain beside the code that uses them. Ignored `build/`
directories contain diagnostic reports, renders and fabrication artifacts,
not authoritative requirements. Installed software and datasheet caches do
not become tracked documentation by being copied into this folder.

The only tracked Markdown entry points outside this folder are the root
README and agent instruction files. Custom `pcbgen --out DIR` exports keep
their Markdown inside `DIR/docs/`; do not commit scratch bundles into the
source tree.