# MULT — passive 2×6 multiple

> Status: maintained requirements. Owner: module-design agent, with user decisions.
> Read when: reviewing connectivity, loading, geometry, assembly or a proposed change to this module.
> Update when: requirements, circuit/geometry or supporting evidence change.
> Retire when: the module is removed or a replacement spec takes ownership; preserve applicable build-revision evidence.

6HP passive multiple. Two independent groups of six Thonkiconn jacks, one
group per column; a solder jumper on the back of the PCB joins the groups into
one 1×12 multiple.

## Function

- J1–J6: group A, left column, all tips wired together (net `MULT_A`).
- J7–J12: group B, right column, all tips wired together (net `MULT_B`).
- JP1 (back side, between the third jacks): open = 2×6, bridged = 1×12.
- All sleeves to GND. Jack switch contacts (TN) are left unconnected.
- No power. The powered-module header rule in [../../../AGENTS.md](../../../AGENTS.md) does not apply.
- No buffering: loading depends on the source and every connected destination.
  A passive multiple is not automatically a precision pitch distribution buffer.

## Why 6HP and two columns

The plan was 4HP with eight jacks in one column. Two hard limits rule that out:

- **Pad geometry.** With the official Thonkiconn footprint the tip pad sits
  11.4 mm below the barrel. The next jack's sleeve pad needs 0.2 mm clearance
  and 0.5 mm hole-to-hole from it, giving a minimum vertical pitch of 13.6 mm.
  At 13.0 mm the pads overlap.
- **Rail clearance.** The PCB behind the panel must stay clear of the rails:
  at most 108 mm tall (110 mm on most rails), centred on the 128.5 mm panel.
  Eight jacks at 13.6 mm pitch need 95.2 mm plus the barrel above the first
  jack and the 12.5 mm body below the last: 110.7 mm. It does not fit.

Two columns of six at 13.7 mm pitch span 68.5 mm and fit with margin.

## Panel (Doepfer 3U, 6HP)

Panel 30.0 × 128.5 mm (Doepfer table value for 6HP), 2 mm aluminium or a
1.6 mm PCB. Coordinates from the panel's top-left corner, y downward.

| Feature | x (mm) | y (mm) | Hole |
|---------|--------|--------|------|
| Column A jacks | 7.5 | 30.0, 43.7, 57.4, 71.1, 84.8, 98.5 | Ø6.4 |
| Column B jacks | 22.5 | same rows | Ø6.4 |
| Rail holes | 7.5 and 22.74 | 3.0 and 125.5 | Ø3.2 |

Rail holes follow Doepfer: 3.0 mm from the top and bottom edges, first hole
7.5 mm from the left edge, further holes on the 5.08 mm grid. The panel is
itself a generated KiCad project in `modules/mult/kicad/panel/` with the legend
on F.SilkS. Paths and commands here are relative to the repository root.

## PCB

- Size 28.0 × 108.0 mm, 1.0 mm corner radius, 2 layers, 1.6 mm FR4.
- Centred behind the panel: PCB origin at panel (1.0, 10.25). Board
  coordinate = panel coordinate − (1.0, 10.25). Jack columns at board x = 6.5
  and 21.5; rows at board y = 19.75 + 13.7 k.
- The board is held by the twelve jack nuts; no separate mounting holes.
- Jack bodies point toward the bottom of the module. The lowest body ends at
  board y = 100.7, inside the board and 17.8 mm from the bottom panel edge.
- Copper: GND pours on both layers with thermal relief on the sleeve pads;
  the tip nets use the grid router at 0.5 mm width. The alternative hand-routed
  buses in the design source are a retained reference, not the current board.
  See [route-report.md](route-report.md) for generated routing details.
- Project DRC rules allow up to 1.5 mm courtyard overlap
  and touching silkscreen between jacks only. The official footprint's
  courtyard is 14.4 mm long, longer than the 10.5 mm body; the barrel sits on
  top of the body so stacked jacks do not physically collide.

## Assembly

All parts are through-hole or hand-soldered; nothing for JLCPCB to assemble,
so no `LCSC Part #` fields are set. Order bare boards only.

| Ref     | Part                                    | Qty |
|---------|-----------------------------------------|-----|
| J1–J12  | Thonkiconn WQP-PJ398SM 3.5 mm mono jack | 12  |
| JP1     | Solder jumper (on PCB, no part)         | —   |

## Source and status

Design sources: [Mult.hs](../../../modules/mult/Mult.hs#L1) and
[MultPanel.hs](../../../modules/mult/MultPanel.hs#L1). Projects in
`modules/mult/kicad/` and its `panel/` subdirectory are generated from them
(`cabal run pcbgen -- all` from the repo root), checked by `toolkit/check.sh mult` and
`toolkit/check.sh mult panel`, fab bundle by `toolkit/fab.sh mult`. Do not edit
the `.kicad_*` files by hand.

Current check results and hardware status belong in
[../../HANDOFF.md](../../HANDOFF.md), not a second status summary here.
