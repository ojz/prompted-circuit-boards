# prompted-circuit-boards

Prompt-driven design of Eurorack modules. Designs are Haskell; KiCad 10 files are generated from them and are the verification format; JLCPCB is the fab.
Background and tool survey: `RESEARCH.md`.
Workstation bootstrap and verification: `SETUP.md`.

## Toolchain

- **KiCad 10**. Install location differs per workstation (`C:\Program Files\KiCad\10.0` or `%LOCALAPPDATA%\Programs\KiCad\10.0`). `kicad-cli` lives in that `bin` directory and may not be on PATH in Git Bash; `toolkit/check.sh` finds it or honours `KICAD_CLI`. The KiCad GUI is a viewer only: never launch KiCad windows from the agent, never save from the GUI.
- **pcbgen** (Haskell, cabal package at the repo root, generator code in `toolkit/`) generates every KiCad project from the module's design file `modules/<name>/<Name>.hs`. Generated `.kicad_sch/.kicad_pcb/.kicad_pro/.kicad_dru` files in `modules/<name>/kicad/` are never edited by hand, in KiCad or otherwise; change the design and regenerate with `cabal run pcbgen -- <name>` (or `all`) from the repo root. Verify with `toolkit/check.sh <name> [panel]` (ERC, DRC with zone refill and schematic parity, renders in `modules/<name>/build/`).
  - Boards are routed by pcbgen's own grid router (`toolkit/src/Route/`): set `bdAutoRoute` and list the nets; `modules/<name>/kicad/route-report.md` records per-net length, vias and detour ratio. Route GND as copper too and add the pours on top, so a pour cut into islands never strands a pad.
  - Multi-unit symbols (dual op-amps) work: one instance per unit, placed with `partUnitOffsets`. Horizontal power pins get global labels, vertical ones power symbols.
  - Footprints the official library lacks live in `lib/footprints/<nick>.pretty/` (`LibId "pcbgen" "Hole_7.2mm"`). pcbgen writes an `fp-lib-table` into such a project referencing `${PCBGEN_LIB}`; check.sh and fab.sh export it. To view those projects in the KiCad GUI, define `PCBGEN_LIB` in Preferences → Configure Paths.
  - SMD passives carry no silkscreen reference (`partRefOnSilk = False`); JLCPCB places from BOM and CPL. Parts without an `LCSC Part #` field are treated as hand-soldered and left out of the assembly files.
- **KiKit** (installed into KiCad's bundled Python, run from the KiCad Command Prompt) produces the JLCPCB fabrication bundle via `toolkit/fab.sh <name> [panel]` and can panelize modules headlessly. Its own DRC and `--ignore` crash in KiCad 10's bindings; the scripts avoid both.
- **Freerouting** jar lives in KiCad's 3rdparty/plugins/freerouting; Java 25 (portable Temurin JRE) is on the user PATH. Unused fallback in case a board outgrows the in-house router.
- **kicad-happy** skills (kicad, spice, emc, bom, lcsc, jlcpcb, ...) are installed globally for review and fab prep.
- No MCP server is used. Konnect was dropped after the first module; everything runs through `kicad-cli`.

## Rules

- Every schematic change must pass `kicad-cli sch erc --exit-code-violations` before moving to layout.
- Every layout change must pass `kicad-cli pcb drc --schematic-parity --exit-code-violations` before export.
- Panel-mounted parts (jacks, pots, switches, LEDs) are placed at exact panel coordinates, never eyeballed. Doepfer 3U: panel 128.5 mm high (`eurorackPanelHeight`), width from Doepfer's table (`eurorackPanelWidth`: 4HP = 20.0, 6HP = 30.0, 8HP = 40.3 mm), rail holes Ø3.2 at 3.0 mm from top and bottom edges, first hole 7.5 mm from the left edge, further holes on the 5.08 mm grid.
- The PCB behind the panel is at most 108 mm tall (`eurorackPcbHeight`; 110 mm is the common limit, 108 clears every rail type), centred on the panel (`eurorackPcbTop` = 10.25 mm below the panel's top edge), and at least 1 mm narrower than the panel on each side. Components that stand between PCB and panel (jack bodies) must also stay inside that zone.
- Thonkiconn jacks stacked in a column need a 13.6 mm minimum pitch with the official footprint (tip pad against the next sleeve pad); use 13.7 mm.
- Power: 2×5 shrouded IDC header, series Schottky on ±12 V, 10 µF + 100 nF per rail.
- Fill the `LCSC Part #` symbol field for anything JLCPCB should assemble, and verify the number on jlcpcb.com. JLCPCB assembles one side per order, so all SMD goes on one side.
- Use official KiCad footprints where they exist: `Jack_3.5mm_QingPu_WQP-PJ398SM_Vertical_CircularHoles` (Thonkiconn), `Potentiometer_Alpha_RD901F-40-00D_Single_Vertical` (Alpha 9 mm).
- Do not commit fabrication output (`build/`) or binaries; regenerate them. Generated KiCad projects are committed.

## Layout

```
pcbgen.cabal, cabal.project   the Haskell package (run cabal from here)
toolkit/src/                  generator: Design model, KiCad emitters, router
toolkit/app/Main.hs           registry of designs by name
toolkit/check.sh, fab.sh      verification and fabrication scripts
lib/footprints/               repository footprint libraries
modules/<name>/
  <Name>.hs, <Name>Panel.hs   the design (source of truth), a Haskell module per project
  SPEC.md                     hand-written intent and panel geometry
  kicad/                      generated module project (committed)
  kicad/panel/                generated front-panel project (committed)
  build/                      check.sh and fab.sh output (ignored)
```

Adding a module: create `modules/<name>/<Name>.hs`, add its directory to `hs-source-dirs` and its module to `exposed-modules` in `pcbgen.cabal`, register it in `toolkit/app/Main.hs`, write `SPEC.md`.
