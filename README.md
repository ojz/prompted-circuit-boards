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
one-line command that produces byte-identical files. The MCP server has since
been removed.

## What we use, and why

| Tool | Role | Why |
|------|------|-----|
| **KiCad 10** | Symbol and footprint libraries, ERC/DRC, zone filling, Gerber/drill/position export, renders. | The libraries are the reference for real parts, the checks are the industry standard, and everything we need runs from `kicad-cli` without a GUI. `kicad-cli pcb drc --refill-zones --save-board` fills copper pours headlessly, which removed the last reason to open the editor. |
| **pcbgen** (`toolkit/`, Haskell) | Turns a design description into a complete KiCad project. | Designs become reviewable code with stable diffs. Library symbols and footprints are embedded verbatim from KiCad's own files, so the generated project passes KiCad's "matches library" check. Deterministic UUIDs keep regenerated files identical. Haskell because the s-expression format maps cleanly onto algebraic data types and the type checker catches malformed output before KiCad does. |
| **pcbgen router** (`toolkit/src/Route/`) | Autoroutes every board: two-layer grid A* per net with negotiated congestion, then string pulling into any-angle traces. | Written in Haskell to get to the bottom of the problem rather than treat routing as a black box. Every result is verified by KiCad's DRC, never by the router itself, and `route-report.md` next to each board scores every net (length, vias, detour ratio) so changes are comparable across commits. |
| **kicad-cli** | ERC, DRC with schematic parity, zone refill, SVG/PNG renders, fabrication exports. | Exit codes gate commits. The repo rule is that no schematic or layout change lands without a clean ERC and DRC. |
| **KiKit** | JLCPCB fabrication bundle (Gerbers, drill, BOM, CPL) and panelization of several modules into one order. | Headless, scriptable, supports KiCad 10 since v1.8.0, and replaces the GUI-only Fabrication Toolkit plugin. Runs on KiCad's bundled Python. |
| **kicad-happy** skills | Design review, EMC and DFM checks, distributor lookups. | Independent second opinion on a generated design before ordering. |
| **Freerouting** | Available as a fallback, unused. | Kept in case a board outgrows the in-house router. |

## Workflow

1. Describe or change a module in `modules/<name>/<Name>.hs` and write or
   update `modules/<name>/SPEC.md` next to it with the panel geometry and
   intent. The design file is the netlist and the placement; there is no other
   input.
2. Generate the KiCad projects from the repository root (`all`, or one design
   name):
   ```
   cabal run pcbgen -- all
   ```
   Files land in `modules/<name>/kicad/` (and `modules/<name>/kicad/panel/`
   for a front panel), together with `route-report.md`. Generated files are
   never edited by hand; they are committed so the repo shows the result.
3. Verify headlessly. This copies the project to `modules/<name>/build/`, runs
   ERC, DRC with zone refill and schematic parity, and renders both sides:
   ```
   toolkit/check.sh mult
   toolkit/check.sh mult panel
   ```
4. Look at the renders in `build/`, or open the project in KiCad to inspect it.
5. Export for JLCPCB with KiKit. Output goes to `build/fab/` and is never
   committed:
   ```
   toolkit/fab.sh mult
   toolkit/fab.sh mult panel
   ```

## Repository layout

```
pcbgen.cabal        the Haskell package; cabal runs from the repo root
toolkit/src/        pcbgen: design model, KiCad emitters, router
toolkit/app/        pcbgen executable and design registry
toolkit/*.sh        check.sh (ERC/DRC/renders) and fab.sh (JLCPCB bundle)
lib/footprints/     footprints the official KiCad library lacks
modules/<name>/     one directory per module:
  <Name>.hs           design source (module), <Name>Panel.hs (front panel)
  SPEC.md             hand-written intent and geometry
  kicad/, kicad/panel/  generated KiCad projects (committed)
  build/              verification and fabrication output (ignored)
CLAUDE.md           rules the agent follows (panel geometry, power, footprints)
SETUP.md            workstation bootstrap
RESEARCH.md         background and tool survey
MODULES.md          module roadmap
```

## Modules

| Module | HP | Status |
|--------|----|--------|
| [mult](modules/mult/SPEC.md) | 6 | 2×6 passive multiple. Module and panel generated, ERC and DRC clean, JLCPCB bundle via KiKit. |
| [attenuverter](modules/attenuverter/SPEC.md) | 6 | UTIL-01: dual attenuverter with offset normalling, TL072. Autorouted (16 nets, 6 vias), ERC and DRC clean, JLCPCB assembly bundle for the SMD side. Not yet built. |

## Eurorack conventions baked in

Doepfer 3U, from Doepfer's own construction notes: panel height 128.5 mm,
width from Doepfer's table (4HP = 20.0, 6HP = 30.0, 8HP = 40.3 mm, roughly
`HP × 5.08 − 0.3`), rail holes Ø3.2 mm at 3.0 mm from the top and bottom
edges, first hole 7.5 mm from the left edge and further holes on the 5.08 mm
grid. The PCB behind the panel is at most 108 mm tall and centred, so it clears
the rails on every case, and at least 1 mm narrower than the panel per side.
Panel-mounted parts are placed from exact panel coordinates, never eyeballed.
Power enters on a 2×5 shrouded IDC header with series Schottky diodes on ±12 V
and 10 µF + 100 nF per rail. Official KiCad footprints are used where they
exist; the Thonkiconn jack is `Jack_3.5mm_QingPu_WQP-PJ398SM_Vertical_CircularHoles`,
which forces a 13.7 mm pitch when jacks are stacked in a column.
