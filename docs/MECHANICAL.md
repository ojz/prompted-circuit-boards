---
status: "maintained; derived from manufacturer drawings on 2026-09-13, not yet measured on a built module"
owner: "the agent keeps it current; the first assembled board confirms or corrects it"
read_when: "placing a panel-mounted part, choosing a header, checking whether a board fits a case, or reviewing a render before an order"
update_when: "a panel-mounted part, panel material or connector changes, or a build measures a different number"
retire_when: "a measured mechanical record of the built modules supersedes the drawing-derived stack"
sources_checked: "2026-09-13"
---

# Mechanical stack

What sits at which height between the front panel and the back of a module,
and how much depth a module takes. Every number below was read from a
manufacturer drawing on the date in the frontmatter; none has been measured
on a built module. The first assembled board is where this document gets its
first correction. The form-factor rules themselves (panel height and width,
100 mm board, board centred 1 mm inside the panel edges) live in
[../AGENTS.md](../AGENTS.md) and are implemented once in
`toolkit/src/Block/Eurorack.hs`.

## The stack, front to back

Heights are along the axis perpendicular to the panel. Zero is the top
surface of the PCB, the side that faces the panel.

| Layer | Height above PCB top, mm | Source |
|---|--:|---|
| Alpha RD901F-40-00D pot body, PCB to bushing base | 10.0 | Taiwan Alpha 9 mm catalogue, RD901F-40-00D outline; Thonk's Alpha vertical drawing SLH-211 |
| Thonkiconn PJ398SM jack body, PCB to bushing base | 9.0 | Thonk PJ398SM drawing (side view: bushing 5.5, body 9, terminals 3.5) |
| **Panel underside** | **10.0** | set by the pot bodies, which are the taller of the two |
| Panel top, 2 mm aluminium | 12.0 | Doepfer panels are 2 mm; a JLCPCB FR4 panel is 1.6 mm (11.6) |
| Jack bushing top (M6, 5.5 mm long, 4.5 mm threaded) | 14.5 | Thonk drawing |
| Pot bushing top (M7 × 0.75, 5.0 mm threaded) | 15.0 | Taiwan Alpha catalogue |
| Pot shaft end (15 mm shaft) | 30.0 | Thonk: "Shaft Length 15 mm" |

What that means for assembly:

- **The pots set the panel height, not the jacks.** A jack's bushing shoulder
  stops 1.0 mm short of the panel underside. Its nut therefore clamps the
  panel against nothing on the jack itself; the jack is held by its solder
  joints and the nut only keeps the panel from lifting. This is the normal
  Thonkiconn-plus-Alpha arrangement and is why the jack pads are large
  through-hole pads, but it has not been confirmed on our boards. If the
  first build shows the jacks loose or the board bowing when the jack nuts
  are tightened, the fix is a 1 mm washer under the panel at each jack or
  leaving the jack nuts finger-tight.
- **Thread above a 2 mm panel:** jack 2.5 mm, pot 3.0 mm. The pot's nut is
  2.0 mm thick (SLH-211: "NUT 1PC, 2.0"); the jack's nut thickness is not on
  the drawing but a standard M6 thin nut is 2 mm or less. Both fit; neither
  leaves room for a washer *and* a nut on the jack, so the jack's washer, if
  supplied, stays off.
- **Panel holes:** 6.4 mm for the jacks (M6 clearance), 7.2 mm for the pots
  (M7 bushing; the repository footprint library carries `Hole_7.2mm`),
  3.2 mm for the rail screws. These are the values the generated panel
  projects use.

## The back of the board

The back carries every SMD part and the power header, so it is the side
that decides how deep the module is.

| Part | Height above PCB back, mm | Source |
|---|--:|---|
| 0805 passives | 0.9 to 1.25 | package standard; Samsung's "F" thickness code is 1.25 |
| SOD-123 diode | 1.35 max | package standard |
| SOIC-8 | 1.75 max | JEDEC MS-012 |
| 2×5 shrouded IDC header housing | 9.1 | Würth 61201021621 drawing (rev 002.001, 2026-08-30), a representative DIN 41651 header; the generic header bought may differ by a few tenths |
| Mated IDC socket with strain relief, no cable bend | about 12.5 | Würth 61201023021: socket 8.45 with 3.45 of strain relief, of which about 6.5 sits inside the shroud |
| Ribbon cable leaving the socket | add 5 to 10 | the cable bends away from the board; allow for it |

## Module depth

| Configuration | Depth behind the panel front, mm |
|---|--:|
| Panel 2.0 + pot bodies 10.0 + PCB 1.6 + header housing 9.1 | 22.7 |
| Same, power cable plugged and bent away | about 30 to 35 |

Doepfer's standard case depth is 80 mm behind the panel; shallow "skiff"
cases start at about 40 mm. The attenuverter fits both with the cable in.

## Fit review of the attenuverter, 2026-09-13

Reviewed on the renders `check.sh` produces (`modules/attenuverter/build/
attenuverter-top.png` and `-bottom.png`), against the drawings above.

- **Front.** Four Thonkiconns and two pots only; nothing else stands between
  the board and the panel, so the 10 mm stack holds with no interference.
  The pot bodies (9.5 × 12.0 mm) and jack bodies (9 × 10.5 mm) are on
  alternating rows and do not touch each other; DRC agrees (courtyards
  clear).
- **Back.** The SMD sits in the two pad-free strips between the jack tip
  pads and the next row's pot lugs (panel y 50.5 to 62) and between the
  second jack row's tip pads and the header (y 93 to 104.5). The tallest SMD
  part (SOIC-8, 1.75 mm) is well inside the header's 9.1 mm, so the header
  alone sets the depth.
- **Header at the edge.** The shroud stops 0.3 mm inside the board's bottom
  edge. That is deliberate (it keeps the header as far from the SMD as
  possible) but leaves no room for the board outline tolerance of about
  0.2 mm to overlap the shroud; if a delivered board shows the shroud
  overhanging, it is cosmetic and does not affect the fit in a case.
- **Under the panel.** The jack switch pads (the square pad above each
  barrel) sit under the panel and are the OFFSET test point; they are only
  reachable with the panel off, which is how the first power-up is done.
- **Not reviewed:** the panel-to-rail fit of the 100 mm board (14.25 mm to
  each rail, clear by inspection of the numbers) and the pot shaft length
  against a knob, since no knob has been chosen.
