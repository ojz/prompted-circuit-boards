# Research: AI-prompted PCB workflows for Eurorack (Sept 2026)

Goal: describe a module in a prompt, end up with a KiCad 10 project, verified, exported and ordered from JLCPCB.

## 1. State of the art in one paragraph

Hackaday (5 Sep 2026) summarises it well: the models are good enough for hobby boards, the bottleneck is
tooling and verification. GPT-6 Astra and Claude Opus 5 both score ~69% on EEBench. A head-to-head AI
layout had 168 DRC violations versus 0 for a professional. Yet a commenter has shipped three "vibe coded"
boards designed with Fable and all worked first time. Schematic generation is the weak spot (dangling
pins, open nets); footprint creation from PDF datasheets is unreliable. Every serious workflow keeps a
human review step and a hard DRC/ERC gate. Eurorack analog audio is forgiving electrically (kHz, ±12 V,
no RF, no high-speed), which is why hobby AI boards tend to work. Mechanics (panel alignment) is where
Eurorack actually bites.

## 2. Three families of tooling

### A. KiCad-native agent tooling (KiCad stays the source of truth)

| Tool | What it is | KiCad 10 / Windows | Notes |
|---|---|---|---|
| **Konnect** (mixelpixx) | Single Rust binary, native KiCad 10 plugin, MCP server with 171-217 tools. Schematic editing via own S-expression engine, PCB editing via KiCad IPC API, Freerouting DSN/SES, JLCPCB 2.5M-part local catalog, gerber/BOM/CPL via kicad-cli. Bundles 6 Claude skills + 2 agents. | Windows is the most-tested platform. Installs via Plugin and Content Manager. | Beta. AGPL-3.0 (fine for a personal public repo). Most PCB tools need KiCad open with the board loaded. Successor of KiCAD-MCP-Server (MIT, KiCad 9, SWIG based, older). |
| **KiCad-AI-Assistant** (paul356) | Action plugin for KiCad 10 with a chat panel + embedded MCP server. Anthropic/OpenAI/custom endpoints. Schematic symbol/wire edits, footprint placement, DRC rules, zones, BOM. | Tested on KiCad 10 Windows + Linux. | MIT. Chat lives inside KiCad rather than in Claude Code. |
| **kicad-happy** (aklofas) | 11 Claude Code / Codex skills: parse sch/pcb/gerbers, SPICE testbenches, 44 EMC checks, datasheet extraction, LCSC/DigiKey/Mouser search, JLCPCB pre-order checklist and BOM formatting. | KiCad 5-10, Python 3.10, no required deps. | Analysis and fab prep only, does not generate designs. Excellent as the review gate. |
| **claude-kicad-skills** (Prithvi-0g) | `/create` prompts to .kicad_sch/.kicad_pcb, `/kicad` review. | | Generates files directly; less mature than the above. |
| **Freerouting MCP** | `npx @freerouting/freerouting-mcp-server`. Agent uploads DSN, runs multi-pass autoroute, gets SES back. Local mode keeps files private. | Java, Windows OK. | Konnect wraps this already. |

Substrate facts for KiCad 10 (verified in the CLI docs and dev docs):
- `kicad-cli` is fully headless for: `sch erc`, `sch export netlist|bom`, `pcb drc --schematic-parity`, `pcb export gerbers|drill|pos|step`. `--exit-code-violations` makes ERC/DRC usable as a CI gate.
- IPC API in KiCad 10 is **PCB editor only** and needs the GUI running. Headless `kicad-cli api-server` and schematic IPC arrive in KiCad 11. So schematics are edited by writing the S-expression file (Konnect, kicad-skip, or our own tool).

### B. Code-as-hardware (write source, compile to a board)

| Tool | Model | Layout | Fab | Agent story |
|---|---|---|---|---|
| **atopile** (MIT, YC W24) | `.ato` declarative language: modules, interfaces, units, tolerances, assertions. Compiler solves constraints, picks parts parametrically (LCSC/JLCPCB registry), updates a `.kicad_pcb`. | **No autoplace/route.** You open the generated board in pcbnew and lay it out by hand (or with Freerouting). Layouts are reused across builds. | JLCPCB stackups built in; KiCad exports. | Repo ships AGENTS.md, `.claude/`, `.cursor/`. Hackaday calls it "a strong focus on use by AI agents". `pip install atopile` or the VS Code extension. Pre-release, moves fast. |
| **tscircuit** (MIT) | React/TypeScript JSX components → circuit JSON. | Built-in autorouter, schematic autolayout, 3D. | Gerbers, JLCPCB part import, "order from JLCPCB" flow. Has a Claude Code skill (`tscircuit` skill). Adafruit showed Codex + tscircuit designing a fabbable board with no CAD tool. | Strongest "prompt to gerber" path today, but KiCad is not in the loop and Eurorack footprints (Thonkiconn, Alpha 9 mm) are not in its registry. |
| **SKiDL + skidl-skills** (nickkraakman) | Python netlist DSL. Claude Code plugin with 9 agents: `/new-circuit` → SPEC.md → architecture → part sourcing → SKiDL code → ERC report. | None. Netlist only, layout manual. Author says it gets you "80% of the way", 30-60 min with many permission prompts. | Standard KiCad flow afterwards. | Good pattern to copy (spec → architecture → BOM → code → ERC), even if we do not use SKiDL itself. |

### C. Research direction
- pcbGPT (arXiv 2606.01188): natural-language requirements → schematic synthesis.
- "Agentic EDA: a handoff perspective" (arXiv 2606.19795): the field agrees the win is in clean tool handoffs and verification, not bigger prompts.

## 3. Alternatives to KiCad, and why to stay

- **tscircuit**: viable if we accept a non-KiCad toolchain and make our own Eurorack footprints. Best autorouting UX. Consider for a second experiment.
- **EasyEDA Pro**: JLCPCB's own tool, LCSC parts native, but weak scripting and no real agent tooling.
- **Flux.ai**: browser EDA with an AI copilot, proprietary, closed file format.
- **Verdict**: stay on KiCad 10. Already installed, official libraries contain the Eurorack parts, every agent tool above targets it, and `kicad-cli` gives us a headless verification and export loop.

## 4. Eurorack specifics the agent must know

Mechanical (Doepfer standard):
- Panel 128.5 mm high, width n × 5.08 mm (HP) minus ~0.3 mm. Mounting slots 7.5 mm from left edge, 3.0 mm from top/bottom (some templates use 5.08 mm from each edge).
- Main PCB height limits: about 108-110 mm if it sits behind the panel, plus module depth budget (aim ≤ 25 mm total for "skiff friendly").
- Panel-mounted parts sit at fixed panel coordinates. Their PCB footprints must mirror those coordinates exactly. This is deterministic and should be scripted, not left to the LLM.

Power:
- 2×5 (10-pin) shrouded IDC header, -12 V on the red-stripe side (pins 1-2), +12 V on pins 9-10, GND on 3-8. 16-pin adds +5 V, CV and gate buses; not needed for simple modules.
- Series Schottky (1N5817/1N5819, or SS14 in SMD) on each rail for reverse-polarity protection, then 10 µF electrolytic + 100 nF ceramic per rail. Ferrite beads optional.

Standard parts (all in official KiCad libs):
- Jack: `Jack_3.5mm_QingPu_WQP-PJ398SM_Vertical_CircularHoles` (Thonkiconn). LCSC has the QingPu WQP-PJ398SM.
- Pot: `Potentiometer_Alpha_RD901F-40-00D_Single_Vertical` (Alpha 9 mm vertical).
- Op-amps: TL072 / TL074 (through-hole DIP or SOIC for JLCPCB assembly).
- Community libs: clacktronics/AudioJacks, nebs/eurocad, danroblewis/kicad-eurorack-tools (draws outlines and generates faceplates aligned to Alpha pots and Thonkiconn jacks), joem/kicad-eurorack-panel-generator.
- Templates: clacktronics/Eurorack_KiCAD_templates, JonathanBedrava/eurorack-kicad-templates.

JLCPCB:
- Panel = second PCB order (FR4 black matte soldermask with white silk, or aluminium PCB). Cheap at 100 mm × n HP; 128.5 mm exceeds the 100 mm cheap-pool limit, so quote it.
- Assembly is one side per order. Fill the `LCSC Part #` symbol field before export. Check the assembly preview for 90/180° rotation errors on ICs and diodes (4ms keeps a rotation-correction DB for this).
- Fabrication Toolkit plugin (via Plugin and Content Manager) gives one-click Gerber zip + bom.csv + positions.csv in JLCPCB's exact column format. Headless equivalent: `kicad-cli pcb export gerbers/drill/pos` + `kicad-cli sch export bom`, then rename columns (Reference→Designator, Value→Comment, PosX→Mid X, PosY→Mid Y, Rot→Rotation, Side→Layer).

## 5. Recommended workflow

```
prompt ──▶ SPEC.md (function, HP, jacks/pots, power) ──▶ BOM with LCSC numbers
        ──▶ schematic (.kicad_sch)  ──▶ kicad-cli sch erc --exit-code-violations   (loop until clean)
        ──▶ board: outline + panel parts placed deterministically from SPEC
        ──▶ remaining placement by agent, routing by Freerouting
        ──▶ kicad-cli pcb drc --schematic-parity --exit-code-violations          (loop until clean)
        ──▶ human review in KiCad (power rails, ground, silkscreen)
        ──▶ gerbers + bom + cpl (Fabrication Toolkit or kicad-cli) ──▶ JLCPCB
        ──▶ panel PCB from the same SPEC ──▶ JLCPCB
```

Stack, first choice:
1. **KiCad 10** (installed) as source of truth.
2. **Konnect** as the MCP server in Claude Code (`.mcp.json` in this repo). It covers schematic write, IPC placement, Freerouting, JLCPCB catalog and kicad-cli exports in one binary and is Windows-first.
3. **kicad-happy** skills as the independent review gate (ERC/DRC parse, SPICE sanity check of filters/VCAs, JLCPCB pre-order checklist).
4. **Fabrication Toolkit** for the final export, or kicad-cli when running headless.
5. A small **Go tool in this repo** for the deterministic parts: given HP, jack/pot list and grid, emit Edge.Cuts, mounting slots, panel-part coordinates and a matching panel PCB. This is the piece the LLM is worst at and the piece every Eurorack module needs. Fits the "mostly golang" nature of the repo.

Fallback if Konnect is unstable: atopile for schematic/netlist (agent writes `.ato`, compiler picks LCSC parts and emits the `.kicad_pcb`), then the same Go placement tool + Freerouting + kicad-cli loop.

## 6. First module candidates (simple, panel-heavy, low risk)

1. **Passive mult / attenuator** (2-4 HP): jacks and pots only, no power. Tests the whole mechanical + fab pipeline with zero electrical risk.
2. **Buffered mult or dual attenuverter** (4-6 HP): TL074, power header with Schottky protection, decoupling. First "real" module; still trivial electrically.
3. **Simple LFO or VCA** after the pipeline is proven.

## Sources

- Hackaday, Can AI now design PCBs that just work (5 Sep 2026): https://hackaday.com/2026/09/05/can-ai-now-design-pcbs-that-just-work/
- Konnect: https://github.com/mixelpixx/Konnect
- KiCAD-MCP-Server: https://github.com/mixelpixx/KiCAD-MCP-Server
- KiCad-AI-Assistant (KiCad 10 plugin): https://github.com/paul356/KiCad-AI-Assistant
- kicad-happy skills: https://github.com/aklofas/kicad-happy
- claude-kicad-skills: https://github.com/Prithvi-0g/claude-kicad-skills
- skidl-skills: https://github.com/nickkraakman/skidl-skills
- atopile: https://github.com/atopile/atopile and https://docs.atopile.io/
- tscircuit: https://github.com/tscircuit/tscircuit and https://docs.tscircuit.com/
- Adafruit on Codex + tscircuit: https://blog.adafruit.com/2026/05/07/making-electronics-with-tscircuit-via-codex-no-kicad-altium-eagle/
- Freerouting (MCP server): https://www.freerouting.app/
- KiCad CLI docs: https://docs.kicad.org/master/en/cli/cli.html
- KiCad IPC API dev docs: https://dev-docs.kicad.org/en/apis-and-binding/ipc-api/for-addon-developers/index.html
- JLCPCB, BOM and CPL from KiCad 10: https://jlcpcb.com/help/article/how-to-generate-the-bom-and-centroid-file-from-kicad
- 4ms JLCPCB assembly export notes: https://github.com/4ms/pcb-rules/blob/master/howto-export-for-jlcpcb-pcba/How%20to%20Export%20a%20PCB%20for%20Assembly%20at%20JLCPCB.md
- Bouni kicad-jlcpcb-tools: https://github.com/Bouni/kicad-jlcpcb-tools
- Eurorack KiCad templates: https://github.com/clacktronics/Eurorack_KiCAD_templates and https://github.com/JonathanBedrava/eurorack-kicad-templates
- kicad-eurorack-tools: https://github.com/danroblewis/kicad-eurorack-tools
- Panel generator: https://github.com/joem/kicad-eurorack-panel-generator
- Thonkiconn footprint PR: https://github.com/KiCad/kicad-footprints/pull/807 and Eurorack parts PR https://github.com/KiCad/kicad-footprints/pull/1073
- Eurorack power protection discussion: https://www.modwiggler.com/forum/viewtopic.php?t=113628
- Eurorack power distribution best practices: https://pd.takazudomodular.com/docs/learning/eurorack-power-distribution/
- pcbGPT paper: https://arxiv.org/html/2606.01188
- Agentic EDA handoff paper: https://arxiv.org/pdf/2606.19795
