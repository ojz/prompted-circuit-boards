---
status: "maintained"
owner: "collaborating agents"
read_when: "arriving at the repository or locating the workflow and documents"
update_when: "entry points, architecture or document locations change; keep live test results in the handoff"
retire_when: "the repository is retired or a replacement entry point is deliberately adopted"
---

# prompted-circuit-boards

Prompt-driven design of Eurorack modules. Each module is described in code, the
KiCad project is generated from that description, and KiCad's command-line
tools verify it and produce the files JLCPCB needs. The KiCad GUI is a viewer,
not an editor.

[docs/README.md](docs/README.md) is the document index. Start with
[docs/HANDOFF.md](docs/HANDOFF.md) for the current evidence and next action,
[docs/ROADMAP.md](docs/ROADMAP.md) for priorities and acceptance gates, and
[docs/SETUP.md](docs/SETUP.md) for workstation setup. Standing agent rules are
in [AGENTS.md](AGENTS.md).

For a short explanation of the code, use the
[code map](docs/README.md#where-the-code-lives). These are tools that design and
check analog hardware on the laptop, not software running inside the modules.

The design direction is to reuse proven circuit approaches and validate them
to explicit precision requirements, not invent new circuitry for novelty.
When a researched decision needs the user's input, the agent creates an editable
question in [docs/decisions/README.md](docs/decisions/README.md)'s inbox workflow.

## Why this shape

The first module (a passive multiple) was built by driving KiCad's editor
through an MCP server. Everything that touched files directly worked; everything
that needed a live editor window was brittle: routing and copper pours only
worked over KiCad's API, zones could not be deleted, footprints could not be
flipped, and footprints created through the API were degraded copies that
failed KiCad's own library check. Half the session went to opening and closing
windows.

The fix is to treat KiCad as a compile target. A design is a small Haskell
value. A generator turns it into `.kicad_sch`, `.kicad_pcb`, `.kicad_pro` and
`.kicad_dru` files that KiCad accepts as its own, and headless tools do the
rest. Nothing depends on a window being open, and regenerating a module is a
one-line command that produces byte-identical files. The MCP server has since
been removed.

## What we use, and why

| Tool | Role | Why |
|------|------|-----|
| **KiCad 10** | Symbol and footprint libraries, ERC/DRC, zone filling, exports and renders. | Headless native checks provide independent design-consistency evidence. Library agreement is not manufacturer-datasheet verification. |
| **pcbgen** (`toolkit/`, Haskell) | Turns a design description into a complete KiCad project. | Structured circuit definitions, design validation and deterministic identifiers make changes reviewable. Types, tests and native checks address different failure modes; none alone proves electrical correctness. |
| **pcbgen router** (`toolkit/src/Route/`) | Routes the declared nets on a two-layer grid, with negotiated congestion and any-angle simplification. | Generates per-design reports under `docs/modules/`. Native KiCad checks remain a separate gate; the benchmark's selected geometry checks are not full DRC. |
| **kicad-cli** | ERC, DRC with schematic parity, zone refill, SVG/PNG renders, fabrication exports. | Exit codes gate commits. The repo rule is that no schematic or layout change lands without a clean ERC and DRC. |
| **KiKit** | JLCPCB fabrication bundle (Gerbers, drill, BOM, CPL) and panelization of several modules into one order. | Headless, scriptable, supports KiCad 10 since v1.8.0, and replaces the GUI-only Fabrication Toolkit plugin. Runs on KiCad's bundled Python. |
| **kicad-happy** skills | Design review, EMC and DFM checks, distributor lookups. | Independent second opinion on a generated design before ordering. |
| **ngspice and NumPy** | Circuit experiments and supporting field calculations. | Numerical evidence with explicit model limits; not a substitute for physical measurement. |
| **Freerouting** | External comparison baseline for the routing benchmark. | Compared through KiCad's DSN/SES interface; not the generator's production routing path. |

## Workflow

1. Describe or change a module in `modules/<name>/<Name>.hs` and write or
   update `docs/modules/<name>/SPEC.md` with the operating limits, geometry and
   intent. Today the Haskell design supplies the netlist and placement. The
   planned sketcher/layout bridge is not implemented or an additional input yet.
2. Generate the KiCad projects from the repository root (`all`, or one design
   name):
   ```
   cabal run pcbgen -- all
   ```
   Files land in `modules/<name>/kicad/` (and `modules/<name>/kicad/panel/`
   for an existing front panel), with reports in `docs/modules/<name>/route-report.md`.
   Generated files are never edited by hand; they are committed so the repo
   shows the result. `--out DIR` keeps a custom bundle's report in `DIR/docs/`.
3. Verify headlessly. This copies the project to `modules/<name>/build/`, runs
   ERC, DRC with zone refill and schematic parity, and renders both sides:
   ```
   toolkit/check.sh mult
   toolkit/check.sh mult panel
   ```
4. Look at the renders in `build/`, or open the project in KiCad to inspect it.
5. Run circuit experiments separately with `toolkit/sim.sh <name>` where
   decks exist. The source netlist is generated from the same Haskell design.
6. After checks and the documented design review, export a diagnostic JLCPCB
   bundle with KiKit. Output goes to `build/fab/` and is never committed:
   ```
   toolkit/fab.sh mult
   ```

`toolkit/pipeline.sh <name> [--fab]` combines generation, native checks and
optional export. Final panel artwork and fabrication remain deferred; the
[shared panel language](docs/MECHANICAL.md#panel-layout-language) and
[browser-only sketcher milestones](docs/ROADMAP.md#s1-shared-panel-model-and-checks-queued)
are authorized work now. An export does not constitute approval to purchase
or a claim of measured performance.

## Repository layout

```
pcbgen.cabal        the Haskell package; cabal runs from the repo root
toolkit/src/        pcbgen: design model, KiCad emitters, router
toolkit/app/        pcbgen executable and design registry
toolkit/*.sh        generation/check/export orchestration and regression checks
lib/footprints/     footprints the official KiCad library lacks
modules/<name>/     one directory per module:
  <Name>.hs           design source (module), <Name>Panel.hs (front panel)
  kicad/, kicad/panel/  generated KiCad projects (committed)
  build/              verification and fabrication output (ignored)
docs/              specifications, setup, roadmap, handoff and generated reports
   decisions/         editable user decision inbox; processed files are retired
   modules/<name>/    specification and generated routing report
AGENTS.md          standing rules, including documentation lifecycle
CLAUDE.md          imports AGENTS.md
```

## Modules

| Module | HP | Scope |
|--------|----|--------|
| [docs/modules/io-mixer/SPEC.md](docs/modules/io-mixer/SPEC.md) | Not fixed | R1: four-channel mono/DC mixer, 3.5 mm stereo consumer audio and USB-C PD power; requirements, not an implemented circuit yet. |
| [docs/modules/mult/SPEC.md](docs/modules/mult/SPEC.md) | 6 | 2x6 passive multiple; no power. |
| [docs/modules/attenuverter/SPEC.md](docs/modules/attenuverter/SPEC.md) | 6 | Dual buffered attenuverter with reference offset normalling. |

Current check results and hardware status belong in
[docs/HANDOFF.md](docs/HANDOFF.md), not a second status table here.

## Eurorack conventions baked in

Mechanical and power conventions are owned by [AGENTS.md](AGENTS.md) and
implemented in [Design.hs](toolkit/src/Design.hs#L1). Each module's specification
records its exact coordinates and exceptions. Manufacturing and physical-fit
evidence must support those conventions before an order; a passing CAD check
does not establish that real parts have been test-fitted.
