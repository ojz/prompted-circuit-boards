# prompted-circuit-boards

Prompt-driven design of Eurorack modules. KiCad 10 is the source of truth, JLCPCB is the fab.
Background and tool survey: `RESEARCH.md`.
Workstation bootstrap and verification: `SETUP.md`.

## Toolchain

- **KiCad 10** at `C:\Program Files\KiCad\10.0`, `kicad-cli` on PATH.
- **Konnect** MCP server (`.mcp.json`, settings in `konnect.toml`). Schematic edits go through it; PCB edits need KiCad open with the board loaded and the API enabled (Preferences > Plugins > Enable KiCad API).
- **Freerouting** jar lives in KiCad's 3rdparty/plugins/freerouting; Java 25 (portable Temurin JRE) is on the user PATH. Use Konnect's `check_freerouting` → `export_specctra_dsn` → `route_specctra_dsn` → `apply_specctra_ses`.
- **kicad-happy** skills (kicad, spice, emc, bom, lcsc, jlcpcb, ...) are installed globally for review and fab prep. Konnect's own skills (kicad-schematic, kicad-pcb, kicad-manufacture, kicad-review, kicad-library) are installed globally too.
- **Fabrication Toolkit** plugin installed in KiCad for one-click JLCPCB gerber/BOM/CPL export. Headless alternative: `kicad-cli pcb export gerbers|drill|pos` and `kicad-cli sch export bom`.

## Rules

- Every schematic change must pass `kicad-cli sch erc --exit-code-violations` before moving to layout.
- Every layout change must pass `kicad-cli pcb drc --schematic-parity --exit-code-violations` before export.
- Panel-mounted parts (jacks, pots, switches, LEDs) are placed at exact panel coordinates, never eyeballed. Doepfer 3U: panel 128.5 mm high, width = HP × 5.08 mm − 0.3 mm.
- Power: 2×5 shrouded IDC header, series Schottky on ±12 V, 10 µF + 100 nF per rail.
- Fill the `LCSC Part #` symbol field for anything JLCPCB should assemble. JLCPCB assembles one side per order.
- Use official KiCad footprints where they exist: `Jack_3.5mm_QingPu_WQP-PJ398SM_Vertical_CircularHoles` (Thonkiconn), `Potentiometer_Alpha_RD901F-40-00D_Single_Vertical` (Alpha 9 mm).
- Do not commit fabrication output or binaries; regenerate them.

## Layout

One directory per module under `modules/`, each a self-contained KiCad project (`<name>.kicad_pro`, `.kicad_sch`, `.kicad_pcb`) plus `SPEC.md` and, if separate, a `panel/` KiCad project.
