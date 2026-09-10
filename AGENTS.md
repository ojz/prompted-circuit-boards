# prompted-circuit-boards

Prompt-driven design of Eurorack modules. Designs are Haskell; KiCad 10 files are generated from them and are the verification format; JLCPCB is the fab.
Background and tool survey: `RESEARCH.md`. Current state and next action: `HANDOFF.md`.
Workstation bootstrap and verification: `SETUP.md`.

## Toolchain

- **KiCad 10**. Install location differs per workstation (`C:\Program Files\KiCad\10.0` or `%LOCALAPPDATA%\Programs\KiCad\10.0`). `kicad-cli` lives in that `bin` directory and may not be on PATH in Git Bash; `toolkit/check.sh` finds it or honours `KICAD_CLI`. The KiCad GUI is a viewer only: never launch KiCad windows from the agent, never save from the GUI.
- **pcbgen** (Haskell, cabal package at the repo root, generator code in `toolkit/`) generates every KiCad project from the module's design file `modules/<name>/<Name>.hs`. Generated `.kicad_sch/.kicad_pcb/.kicad_pro/.kicad_dru` files in `modules/<name>/kicad/` are never edited by hand, in KiCad or otherwise; change the design and regenerate with `cabal run pcbgen -- <name>` (or `all`) from the repo root. Verify with `toolkit/check.sh <name> [panel]` (ERC, DRC with zone refill and schematic parity, renders in `modules/<name>/build/`).
  - Boards are routed by pcbgen's own grid router (`toolkit/src/Route/`): set `bdAutoRoute` and list the nets; `modules/<name>/kicad/route-report.md` records per-net length, vias and detour ratio. Route GND as copper too and add the pours on top, so a pour cut into islands never strands a pad.
  - Multi-unit symbols (dual op-amps) work: one instance per unit, placed with `partUnitOffsets`. Horizontal power pins get global labels, vertical ones power symbols.
  - Footprints the official library lacks live in `lib/footprints/<nick>.pretty/` (`LibId "pcbgen" "Hole_7.2mm"`). pcbgen writes an `fp-lib-table` into such a project referencing `${PCBGEN_LIB}`; check.sh and fab.sh export it. To view those projects in the KiCad GUI, define `PCBGEN_LIB` in Preferences → Configure Paths.
  - SMD passives carry no silkscreen reference (`partRefOnSilk = False`); JLCPCB places from BOM and CPL. Assembly intent is declared per part with `partAssembly` (`Factory` needs an `LCSC Part #` field and is placed by JLCPCB; `Hand`, `DNP` and `Mechanical` must not carry one and are left out of the assembly files). `part` defaults to `Hand`.
  - Every design is validated before anything is written (`toolkit/src/Validate.hs`): unique references and net names, every `(ref, pin)` must exist on the library symbol, every symbol pin must be on exactly one net or listed in `partNoConnect` (e.g. `partNoConnect = ["TN"]` for a jack's unused switch pin), assembly class and LCSC field must agree, dimensions and routing settings must be positive. On any diagnostic pcbgen prints them to stderr and exits non-zero without touching the project.
  - `cabal run pcbgen -- bench [board ...]` scores every router in `strategies` against the benchmark boards and writes `BENCH.md` (committed, so a change in routing quality shows in a diff). A router is a `Bench.Strategy`, a record of functions, so alternatives sit side by side; scores stay a vector and the harness never declares a winner. Synthetic fixtures live in `modules/_bench/BenchFixtures.hs` and are never emitted as projects: `pinch` is deliberately unroutable and records the completeness cost of the 0.2 mm grid.
  - `cabal run pcbgen -- sweep-via [--iters N] [--costs N,N,...] [board ...]` prices a via several ways over the benchmark boards and prints the scores without writing `BENCH.md`: a sweep answers a question once, and the answer belongs in the default. It doubles as the convergence probe. If a setting leaves contested cells, rerun it with a larger `--iters`: if more rounds fix it the negotiation is merely slow, and if they do not it has stalled, which is a bug in the negotiation and not in the setting. That is how the history-congestion defect was found.
  - `cabal test` runs the regression suite in `toolkit/test/` (needs KiCad's libraries). Every validation fault or router bug that gets fixed gets a test there.
- **KiKit** (installed into KiCad's bundled Python, run from the KiCad Command Prompt) produces the JLCPCB fabrication bundle via `toolkit/fab.sh <name> [panel]` and can panelize modules headlessly. Its own DRC and `--ignore` crash in KiCad 10's bindings; the scripts avoid both.
- **One entry point**: `toolkit/pipeline.sh <name> [--fab]` runs preflight, generation, `check.sh` for the module and its panel, then `fab.sh`, and prints a PASS/FAIL/SKIPPED table. It fails closed: `check.sh` writes `modules/<name>/build/[panel/]check.ok` (tool versions, git provenance, sha256 of every source and of the zone-filled board) only when ERC and DRC are both clean, and `fab.sh` refuses to export unless every one of those hashes still matches, builds into a temporary directory and publishes `build/fab/` only after KiKit and `toolkit/fabcheck.py` pass, so no bundle can come from stale or unchecked input. `build/fab/manifest.txt` hashes every output.
- "Generated", "checks passed" and "reviewed prototype candidate" are three different states; the scripts only ever claim the first two. `toolkit/test-scripts.sh` fault-injects the attenuverter fixture (tampered source byte, tampered filled board, missing `check.ok`, a board fattened until DRC fails) to prove the refusals fire, and must end in `0 failed`.
- **Freerouting** 2.4.1 is a plain jar in `%LOCALAPPDATA%/freerouting`, run by the Temurin 25 JRE on PATH (`FREEROUTING_JAR` overrides the path). It is the benchmark's parity baseline, not part of generation: `toolkit/freeroute.py` does the Specctra round trip through KiCad's own exporter and importer, and `Bench.freeroutingRouter` reads the copper back and scores it with our checks. Its telemetry is switched off in `%APPDATA%/freerouting/freerouting.json`; leave it off. Note it connects same-net pads to a ground plane, so a board whose pours are `PadsUnbonded` is not a fair comparison.
- **kicad-happy** skills (kicad, spice, emc, bom, lcsc, jlcpcb, ...) are installed globally for review and fab prep.
- No MCP server is used. Konnect was dropped after the first module; everything runs through `kicad-cli`.

## Rules

- Every schematic change must pass `kicad-cli sch erc --exit-code-violations` before moving to layout.
- Every layout change must pass `kicad-cli pcb drc --schematic-parity --exit-code-violations` before export.
- Front panels are deferred (2026-09-10): the modules work and can be bench-tested without them, so no panel art or panel fabrication until the electronics are proven. The generated panel projects stay in the tree and keep passing checks; just do not invest in them.
- Panel-mounted parts (jacks, pots, switches, LEDs) are placed at exact panel coordinates, never eyeballed. Doepfer 3U: panel 128.5 mm high (`eurorackPanelHeight`), width from Doepfer's table (`eurorackPanelWidth`: 4HP = 20.0, 6HP = 30.0, 8HP = 40.3 mm), rail holes Ø3.2 at 3.0 mm from top and bottom edges, first hole 7.5 mm from the left edge, further holes on the 5.08 mm grid.
- The PCB behind the panel is at most 108 mm tall (`eurorackPcbHeight`; 110 mm is the common limit, 108 clears every rail type), centred on the panel (`eurorackPcbTop` = 10.25 mm below the panel's top edge), and at least 1 mm narrower than the panel on each side. Components that stand between PCB and panel (jack bodies) must also stay inside that zone.
- Thonkiconn jacks stacked in a column need a 13.6 mm minimum pitch with the official footprint (tip pad against the next sleeve pad); use 13.7 mm.
- Power: 2×5 shrouded IDC header, series Schottky on ±12 V, 10 µF + 100 nF per rail.
- Fill the `LCSC Part #` symbol field for anything JLCPCB should assemble, and verify the number on jlcpcb.com. JLCPCB assembles one side per order, so all SMD goes on one side.
- Use official KiCad footprints where they exist: `Jack_3.5mm_QingPu_WQP-PJ398SM_Vertical_CircularHoles` (Thonkiconn), `Potentiometer_Alpha_RD901F-40-00D_Single_Vertical` (Alpha 9 mm).
- **Two workstations.** This project is worked on from a home laptop and a work laptop, the latter through GitHub Copilot with other models. Commits can exist on the other machine, and pushing is sometimes forgotten. So: `git fetch` at the start of a session and report both directions before touching anything (`git log --oneline main..origin/main` for work waiting to be pulled, `origin/main..main` for work waiting to be pushed); pull before starting, and offer to push before finishing. If the two have diverged, say so and stop rather than guessing.
- Do not commit fabrication output (`build/`) or binaries; regenerate them. Generated KiCad projects are committed.

## Layout

```
pcbgen.cabal, cabal.project   the Haskell package (run cabal from here)
toolkit/src/                  generator: Design model, KiCad emitters, router
toolkit/app/Main.hs           registry of designs by name
toolkit/pipeline.sh           preflight, generate, check, export: the entry point
toolkit/check.sh, fab.sh      verification and fabrication, gated by check.ok
toolkit/tools.sh, fabcheck.py shared shell helpers, assembly/gerber checks
toolkit/test-scripts.sh       fault-injection tests for those scripts
modules/_bench/               synthetic router benchmark fixtures (never emitted)
BENCH.md                      routing benchmark scores (generated, committed)
lib/footprints/               repository footprint libraries
modules/<name>/
  <Name>.hs, <Name>Panel.hs   the design (source of truth), a Haskell module per project
  SPEC.md                     hand-written intent and panel geometry
  kicad/                      generated module project (committed)
  kicad/panel/                generated front-panel project (committed)
  build/                      check.sh and fab.sh output (ignored)
```

Adding a module: create `modules/<name>/<Name>.hs`, add its directory to `hs-source-dirs` and its module to `exposed-modules` in `pcbgen.cabal`, register it in `toolkit/app/Main.hs`, write `SPEC.md`, and add it to the valid-design cases in `toolkit/test/ValidateTests.hs`.
