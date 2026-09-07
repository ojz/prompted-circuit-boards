# MULT — passive 2×4 multiple

4HP passive multiple. Two independent groups of four Thonkiconn jacks; a solder
jumper on the back of the PCB joins the groups into one 1×8 multiple.

## Function

- J1–J4: group A, all tips wired together (net `MULT_A`).
- J5–J8: group B, all tips wired together (net `MULT_B`).
- JP1 (back side, between J4 and J5): open = 2×4, bridged = 1×8.
- All sleeves to GND. Jack switch contacts (TN) are left unconnected.
- No power. The 2×5 power header rule in CLAUDE.md does not apply.

## Panel (Doepfer 3U, 4HP)

Panel is 20.02 mm wide (4 × 5.08 − 0.3) and 128.5 mm high. All hole centres are
on the panel centreline, x = 10.01 mm. Coordinates from the panel's top-left
corner, y downward.

| Jack | Panel y (mm) | Hole   |
|------|--------------|--------|
| J1   | 11.0         | Ø6.2   |
| J2   | 24.7         | Ø6.2   |
| J3   | 38.4         | Ø6.2   |
| J4   | 52.1         | Ø6.2   |
| J5   | 65.8         | Ø6.2   |
| J6   | 79.5         | Ø6.2   |
| J7   | 93.2         | Ø6.2   |
| J8   | 106.9        | Ø6.2   |

Rail slots: 3.2 mm wide at y = 3.0 and y = 125.5, x = 7.5 (Doepfer standard).

Jack pitch is 13.7 mm. This is the minimum the official KiCad footprint allows:
the tip pad of one jack (11.4 mm below the barrel) and the sleeve pad of the next
need 0.2 mm clearance plus 0.5 mm hole-to-hole. At 13.0 mm they overlap.

## PCB

- Size 18.5 × 111.5 mm, 1.0 mm corner radius, 2 layers, 1.6 mm FR4.
- PCB origin sits at panel (0.76, 9.0). Board y = panel y − 9.0; board x = panel
  x − 0.76, so every jack is at board x = 9.25.
- Jacks are held by their nuts; there are no separate mounting holes.
- Jack bodies point toward the bottom of the module. The lowest body ends at
  panel y ≈ 119.4 and the PCB at 120.5, so the board must clear the bottom rail
  by 8 mm from the panel edge. Check this against the actual rail profile before
  ordering.
- Copper: GND pour on both layers, thermal relief on the sleeve pads. Tip buses
  are 0.5 mm traces on F.Cu at x = 12.0; the jumper links are 0.4 mm on B.Cu.
- Project DRC rules (`mult.kicad_dru`) allow up to 1.5 mm courtyard overlap and
  touching silkscreen between jacks only. The official footprint's courtyard is
  14.4 mm long, longer than the 10.5 mm body; the barrel sits on top of the body
  so stacked jacks do not physically collide.

## Assembly

All parts are through-hole or hand-soldered; nothing for JLCPCB to assemble,
so no `LCSC Part #` fields are set. Order bare boards only.

| Ref    | Part                                   | Qty |
|--------|----------------------------------------|-----|
| J1–J8  | Thonkiconn WQP-PJ398SM 3.5 mm mono jack | 8   |
| JP1    | Solder jumper (on PCB, no part)         | —   |

## Status

- Schematic: ERC clean (`kicad-cli sch erc --exit-code-violations`).
- Layout: routed, zero unconnected items. Remaining DRC items are being
  resolved (footprint library refresh, zone consolidation).
- Panel PCB project: not yet created (`panel/`).
