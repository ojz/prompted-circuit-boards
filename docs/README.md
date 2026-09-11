---
status: "maintained"
owner: "collaborating agents"
read_when: "finding a document, starting work, or deciding where new information belongs"
update_when: "a document is added, moved or retired; do not duplicate its current results here"
retire_when: "a replacement index is agreed and all incoming links are updated"
---

# Documentation

## Where To Go

| Document | Authoritative purpose |
|---|---|
| [../AGENTS.md](../AGENTS.md) | Standing operating rules, document lifecycle and decision processing. |
| [HANDOFF.md](HANDOFF.md) | Current checkpoint, verified evidence, limitations and next action. |
| [ROADMAP.md](ROADMAP.md) | Product direction, precision requirements, acceptance gates and research wishlist. |
| [SETUP.md](SETUP.md) | Installation, reproduction commands and known tool pitfalls. |
| [JLCPCB.md](JLCPCB.md) | What the fab actually charges for, and which routing objectives that justifies. |
| [decisions/README.md](decisions/README.md) | Editable decision inbox: how the user answers and the agent integrates answers. |
| [modules/attenuverter/SPEC.md](modules/attenuverter/SPEC.md) | Attenuverter intent, operating requirements, current circuit and model limitations. |
| [modules/attenuverter/ERROR-BUDGET.md](modules/attenuverter/ERROR-BUDGET.md) | Attenuverter precision error budget: envelope, datasheet evidence, current versus proposed parts, proposed limits. |
| [decisions/2026-09-11-attenuverter-precision-parts.md](decisions/2026-09-11-attenuverter-precision-parts.md) | Pending: attenuverter parts swap alone, or with input buffers. |
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