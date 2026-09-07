# prompted-circuit-boards

Prompt-driven design of Eurorack modules. Each module is described in code, the
KiCad project is generated from that description, and KiCad's command-line
tools verify it and produce the files JLCPCB needs. The KiCad GUI is a viewer,
not an editor.

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
one-line command that produces byte-identical files.

## What we use, and why

| Tool | Role | Why |
|------|------|-----|
| **KiCad 10** | Symbol and footprint libraries, ERC/DRC, zone filling, Gerber/drill/position export, renders. | The libraries are the reference for real parts, the checks are the industry standard, and everything we need runs from `kicad-cli` without a GUI. `kicad-cli pcb drc --refill-zones --save-board` fills copper pours headlessly, which removed the last reason to open the editor. |
| **pcbgen** (`toolkit/`, Haskell) | Turns a design description into a complete KiCad project. | Designs become reviewable code with stable diffs. Library symbols and footprints are embedded verbatim from KiCad's own files, so the generated project passes KiCad's "matches library" check. Deterministic UUIDs keep regenerated files identical. Haskell because the s-expression format maps cleanly onto algebraic data types and the type checker catches malformed output before KiCad does. |
| **kicad-cli** | ERC, DRC with schematic parity, zone refill, SVG/PNG renders, fabrication exports. | Exit codes gate commits. The repo rule is that no schematic or layout change lands without a clean ERC and DRC. |
| **KiKit** | JLCPCB fabrication bundle (Gerbers, drill, BOM, CPL) and panelization of several modules into one order. | Headless, scriptable, supports KiCad 10 since v1.8.0, and replaces the GUI-only Fabrication Toolkit plugin. Runs on KiCad's bundled Python. |
| **Konnect** MCP server | Read-only inspection: rendering a schematic, listing pins, searching libraries, checking a board. | Its library search and renders are useful during design. It is no longer used to edit files. |
| **kicad-happy** skills | Design review, EMC and DFM checks, distributor lookups. | Independent second opinion on a generated design before ordering. |
| **Freerouting** | Available, unused so far. | Utility modules route by hand from explicit coordinates in the design. Kept for larger boards. |

## Workflow

1. Describe or change a module in `toolkit/src/Designs/<Name>.hs` and write
   or update `modules/<name>/SPEC.md` with the panel geometry and intent.
2. Generate the KiCad project:
   ```
   cd toolkit && cabal run pcbgen -- <name>
   ```
   Files land in `modules/<name>/`. Generated files are never edited by hand.
3. Verify headlessly. This runs ERC, DRC with zone refill and schematic
   parity, and writes renders to `modules/<name>/build/`:
   ```
   toolkit/check.sh <name>
   ```
4. Look at the renders, or open the project in KiCad to inspect it.
5. Export for JLCPCB with KiKit (`kikit fab jlcpcb`), or panelize several
   modules first. Fabrication output is regenerated, never committed.

## Repository layout

```
toolkit/          pcbgen: Haskell generator, one module per design in src/Designs
modules/<name>/   generated KiCad project + hand-written SPEC.md
CLAUDE.md         rules the agent follows (panel geometry, power, footprints)
SETUP.md          workstation bootstrap
RESEARCH.md       background and tool survey
MODULES.md        module roadmap
```

## Modules

| Module | HP | Status |
|--------|----|--------|
| [mult](modules/mult/SPEC.md) | 4 | Generated. ERC clean, DRC clean, panel project pending. |

## Eurorack conventions baked in

Doepfer 3U: panel height 128.5 mm, width `HP × 5.08 − 0.3` mm, rail slots
3.2 mm wide at 3.0 mm from the top and bottom edges. Panel-mounted parts are
placed from exact panel coordinates, never eyeballed. Power enters on a 2×5
shrouded IDC header with series Schottky diodes on ±12 V and 10 µF + 100 nF per
rail. Official KiCad footprints are used where they exist; the Thonkiconn jack
is `Jack_3.5mm_QingPu_WQP-PJ398SM_Vertical_CircularHoles`.
