# prompted-circuit-boards

Prompt-driven design of Eurorack modules. KiCad 10 is the source of truth, JLCPCB is the fab.
Background and tool survey: `RESEARCH.md`.
Workstation bootstrap and verification: `SETUP.md`.

## Toolchain

- **KiCad 10**. Install location differs per workstation (`C:\Program Files\KiCad\10.0` or `%LOCALAPPDATA%\Programs\KiCad\10.0`); `konnect.toml` holds the paths that apply here. `kicad-cli` lives in that `bin` directory and may not be on PATH in Git Bash.
- **pcbgen** (`toolkit/`, Haskell) generates every KiCad project from `toolkit/src/Designs/<Name>.hs`. Generated `.kicad_sch/.kicad_pcb/.kicad_pro/.kicad_dru` files are never edited by hand, in KiCad or otherwise; change the design and regenerate with `cd toolkit && cabal run pcbgen -- <name>`. Verify with `toolkit/check.sh <name>` (ERC, DRC with zone refill and schematic parity, renders in `modules/<name>/build/`).
- **Konnect** MCP server (`.mcp.json`, settings in `konnect.toml`) is for read-only work: rendering schematics, listing pins, searching libraries, checking boards. Do not use it to edit files, and never launch KiCad windows from the agent.
- **KiKit** (installed into KiCad's bundled Python, run from the KiCad Command Prompt) produces the JLCPCB fabrication bundle and panelizes modules headlessly.
- **Freerouting** jar lives in KiCad's 3rdparty/plugins/freerouting; Java 25 (portable Temurin JRE) is on the user PATH. Use Konnect's `check_freerouting` → `export_specctra_dsn` → `route_specctra_dsn` → `apply_specctra_ses`.
- **kicad-happy** skills (kicad, spice, emc, bom, lcsc, jlcpcb, ...) are installed globally for review and fab prep. Konnect's own skills (kicad-schematic, kicad-pcb, kicad-manufacture, kicad-review, kicad-library) are installed globally too.
- **Fabrication Toolkit** plugin is installed in KiCad but superseded by KiKit; `kicad-cli pcb export gerbers|drill|pos` remains the raw fallback.

## Rules

- Every schematic change must pass `kicad-cli sch erc --exit-code-violations` before moving to layout.
- Every layout change must pass `kicad-cli pcb drc --schematic-parity --exit-code-violations` before export.
- Panel-mounted parts (jacks, pots, switches, LEDs) are placed at exact panel coordinates, never eyeballed. Doepfer 3U: panel 128.5 mm high, width from Doepfer's table (`eurorackPanelWidth`: 4HP = 20.0, 6HP = 30.0, 8HP = 40.3 mm), rail holes Ø3.2 at 3.0 mm from top and bottom edges, first hole 7.5 mm from the left edge, further holes on the 5.08 mm grid.
- The PCB behind the panel is at most 108 mm tall (110 mm is the common limit, 108 clears every rail type), centred on the panel, and at least 1 mm narrower than the panel on each side. Components that stand between PCB and panel (jack bodies) must also stay inside that zone.
- Thonkiconn jacks stacked in a column need a 13.6 mm minimum pitch with the official footprint (tip pad against the next sleeve pad); use 13.7 mm.
- Power: 2×5 shrouded IDC header, series Schottky on ±12 V, 10 µF + 100 nF per rail.
- Fill the `LCSC Part #` symbol field for anything JLCPCB should assemble. JLCPCB assembles one side per order.
- Use official KiCad footprints where they exist: `Jack_3.5mm_QingPu_WQP-PJ398SM_Vertical_CircularHoles` (Thonkiconn), `Potentiometer_Alpha_RD901F-40-00D_Single_Vertical` (Alpha 9 mm).
- Do not commit fabrication output or binaries; regenerate them.

## Layout

One directory per module under `modules/`, each a self-contained generated KiCad project (`<name>.kicad_pro`, `.kicad_sch`, `.kicad_pcb`, `.kicad_dru`) plus a hand-written `SPEC.md` and, if separate, a `panel/` KiCad project. The design source is `toolkit/src/Designs/<Name>.hs`, registered in `toolkit/app/Main.hs`.
