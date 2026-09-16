---
status: "maintained; panel language adopted 2026-09-15; drawing-derived stack and proposed hardware still need choices and physical fit checks"
owner: "the agent keeps it current; the first assembled board confirms or corrects it; the user answers the taste questions in docs/decisions/"
read_when: "placing a panel-mounted part, choosing a jack, pot, knob, switch, LED, trimmer or connector, checking whether a board fits a case, or reviewing a render before an order"
update_when: "a panel-mounted part, panel material or connector changes, a taste answer is integrated, or a build measures a different number"
retire_when: "a measured mechanical record of the built modules supersedes the drawing-derived stack and the hardware standard has moved into the block library"
sources_checked: "2026-09-14"
---

# Mechanical stack and panel hardware

What sits at which height between the front panel and the back of a module,
how much depth a module takes, and which panel-mounted part is used for each
role. Published hardware dimensions and derived stack estimates are identified
below; proposed grid pitches are design candidates, not manufacturer specifications.
Nothing has been measured on a built module. The form-factor rules themselves
(panel height and width, 100 mm board, board centred 1 mm inside the panel edges)
live in [../AGENTS.md](../AGENTS.md) and are implemented once in
[Block.Eurorack](../toolkit/src/Block/Eurorack.hs).

## Panel Layout Language

Adopted in conversation on 2026-09-15. The visual reference is
[Serge Paperface](https://serge-modular.com/paperface), inspected that day:
regular control centres, clear functional groups and a consistent vocabulary
of hardware and markings. Borrow those organizing principles, not Serge's
artwork, circuits, banana-jack mechanics or panel dimensions. We keep Eurorack
and make our own printed graphics and laser-cut faceplates, not ordered
Paperface panels. Final artwork and fabrication remain deferred under
[the standing panel policy](../AGENTS.md#rules).

- **A grid of centres, not a universal hole.** Knobs, jacks, switches and LEDs
  share placement coordinates but retain their own holes, body dimensions,
  mounting stack and clearance envelopes.
- **Sparse by design.** Empty cells are useful space, not missing components.
  Do not pre-populate or cut every grid position. Large controls and functional
  groups may reserve several cells. Mounting holes and service connectors have
  their own geometry; they are not mandatory musical-control cells.
- **Common rows across modules.** Choose one row origin and pitch once fit is
  demonstrated. Do not restrict the approved module widths merely to obtain
  uninterrupted columns across module boundaries. Functional grouping and
  access take precedence over visual density.
- **Consistent meanings.** Use one convention for inputs versus outputs,
  synth TS versus consumer TRS ports, control direction and bipolar zero,
  ranges/units, switch positions and normalled connections. Colour reinforces
  labels or symbols, never replaces them. Exact symbols, typography, colours
  and knob variants are not selected by this policy.
- **Controls remain readable.** Apply the instrument's visible, persistent
  control rule in [AGENTS.md](../AGENTS.md#rules). Show the routing consequences
  of inserting a plug as well as the function of each control. Routine build
  calibration is distinct from a hidden performance mode.
- **State LEDs sit diagonally off their jack (provisional).** The user's
  Paperface observation of 2026-09-15: an output's indicator LED is offset
  diagonally from the jack it reports, less than half a cell away, so it reads
  as belonging to that jack and takes no grid cell of its own. **The offset is
  still not a chosen number.** The geometry to choose it with now exists: the
  sketcher places an LED inside another control's cell without calling it a
  clash and checks the offset against the jack's nut and cable barrel in front
  and its courtyard behind ([SKETCHER.md](SKETCHER.md)). Its sparse fixture
  uses 6 mm diagonally as an illustration, not a convention. R5 is the first
  board that will use it ([R5 plan](modules/boolean-clock/SPEC.md)).
- **Check both sides of the panel.** Allow for fingers, plugged-in cable
  barrels, knob skirts, switch travel, nuts, tool access, adjacent modules and
  the component bodies/pads behind the panel. Hole clearance alone is not fit.

### Grid And Fit Gate

**15 mm and 15.24 mm are mockup candidates, not approved pitches.** The latter
is three nominal HP, but the panel width table, edge gaps and fixed rail holes
still apply. The existing 13.7 mm Thonkiconn column pitch and proposed 15 mm
small-knob spacing do not establish comfortable access with cables installed.
Leave present board coordinates unchanged until a deliberate, checked migration.

Panel coordinates are millimetres from the top-left, viewed from the front,
with y downward. Grid origin is an explicit offset in that coordinate system.
The shaft/barrel/hole centre is not necessarily a footprint origin:
`Block.Eurorack.toBoard` and `originFor` already provide the board transform and
side/rotation-aware footprint offset. The planned shared layout model must
reuse that geometry, including the distinction between display and rear views.

Before freezing the standard, inspect a true-size mockup with the selected
knobs, switches and patch cables; verify body/pad clearances against drawings
and then samples. Choose the laser-compatible panel material and thickness,
check stiffness and thread engagement, and establish hole/kerf allowances with
a test coupon. The current 2 mm aluminium stack is a reference calculation,
not a decision about the user's laser or stock. Changing it requires rechecking
every mounting stack. This gate does not block a sketcher using explicitly
provisional hardware records.

The programming sequence and acceptance checks live in
[ROADMAP.md](ROADMAP.md#s1-shared-panel-model-and-checks-done-2026-09-16). The sketcher and the shared
interchange format exist ([SKETCHER.md](SKETCHER.md)) and draw the candidate
pitches as candidates; no laser export is implemented, and nothing the
sketcher shows closes this gate.

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
| Pot shaft end ("15 mm" shaft) | about 25.0 | Alpha's shaft length is measured from the mounting surface and includes the 5 mm bushing: Uraltone lists the RD901F-40-15K as "shaft length 8.5 mm (total with thread 15 mm)", and Thonk's 20 mm "long" pots have a 10 mm bushing. Corrected 2026-09-14 from 30.0; **confirm with a caliper on the first pot** |
| Sub-mini toggle body plus bushing shoulder (Dailywell 2M) | 9.84 | derived from the 2M datasheet callouts (body 8.64, shoulder 1.20), not read off a dimensioned drawing; see the hardware standard |
| Stereo Thonkiconn body (WQP-WQP419GR) | 9.0 to 10.0 | Exploding-Shed states "effective total body height 10 mm"; whether that is the plastic body or body plus bushing is **unverified**. If it is the body, it touches the panel with zero clearance. Measure a sample before R1's layout |

What that means for assembly:

- **The pots set the panel height, not the jacks.** A jack's bushing shoulder
  stops 1.0 mm short of the panel underside. Its nut therefore clamps the
  panel against nothing on the jack itself; the jack is held by its solder
  joints and the nut only keeps the panel from lifting. No source found on
  2026-09-14 states this 1 mm figure explicitly, so it is a derivation from
  the two drawings, not a confirmed practice. What the DIY sources do agree
  on is the procedure that makes a small gap harmless: fit the jacks and pots
  loosely, fix the panel with its nuts, check every jack is square and
  centred, and only then solder (N8 Synthesizers' mounting guide). If the
  first build still shows the jacks loose or the board bowing, the fix is a
  1 mm washer under the panel at each jack or leaving the jack nuts
  finger-tight.
- **Thread above a 2 mm panel:** jack 2.5 mm, pot 3.0 mm, toggle 2.23 mm. The
  pot's nut is 2.0 mm thick (SLH-211: "NUT 1PC, 2.0"). The Thonkiconn's nut
  thickness is not published; comparable M6 × 0.5 audio-jack nuts are 1.5 mm
  (Kobiconn, knurled) and 2.0 mm (Amphenol, hex), so it fits either way.
  **Thonk and Exploding-Shed ship the jacks bare: nuts and washers are
  separate bagged items and must be on the order.** A washer plus a nut
  will not both fit on the jack's 2.5 mm; the washer goes only under the pot
  nuts if anywhere.
- **Panel holes:** 6.4 mm for the jacks (M6 clearance), 7.2 mm for the pots
  (M7 bushing; the repository footprint library carries `Hole_7.2mm`),
  5.0 mm for a sub-mini toggle, 3.2 mm for a 3 mm LED and for the rail
  screws. The generated panel projects use the first two and the last.

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
  each rail, clear by inspection of the numbers). The pot shaft against a
  knob is covered by the hardware standard below: about 13 mm of shaft stands
  above a 2 mm panel, which a Davies 1900h-class bore swallows.

## Panel hardware standard

The goal is one checked part per role, so boards can share footprints, panel
holes, the stack and the shopping list. This is not yet a fully approved or
physically verified catalogue. Researched on 2026-09-14 from manufacturer drawings,
distributor pages and KiCad 10's own footprint library; the research reports
with every URL opened are summarised here and their conclusions are what is
recorded. **Status** says whether a part is already in use, proposed with
choices outstanding in
[decisions/2026-09-14-panel-hardware.md](decisions/2026-09-14-panel-hardware.md),
or blocked on a measurement. Blank answers do not approve proposed variants.
Prices are ex VAT as displayed on 2026-09-14
(Thonk GBP, LCSC USD).

| Role | Part | Stack fit | Footprint | Source and price | Status |
|---|---|---|---|---|---|
| Synth-side jack, 3.5 mm TS, switched | QingPu **WQP-WQP518MA** (the Thonkiconn; older names PJ398SM, PJ301M-12; the 518MA bushing is rated 20 000 cycles against 5 000) | body 9.0, M6 × 0.5 thread 4.5 mm, 6.4 mm hole, 13.7 mm column pitch | official `Jack_3.5mm_QingPu_WQP-PJ398SM_Vertical_CircularHoles` | Thonk £0.38 (1+), £0.29 (100+); Exploding-Shed; **not on LCSC**. Nuts and washers separate | **In use** |
| World-side jack, 3.5 mm TRS stereo, unswitched | QingPu **WQP-WQP419GR** (ex PJ366ST, "Stereo Thonkiconn") | same bushing, hole and pitch; body 1 mm wider; height 9 to 10 mm, **measure** | none official; the upstream proposal (kicad-footprints PR 823, never merged) is the mono footprint with silk and courtyard 0.5 mm wider and pins S/R/T. Copy ours into `lib/footprints/pcbgen.pretty` | Thonk £0.49; Exploding-Shed about €0.53 | **Proposed**; it has no switch contact, see below |
| Pot | Taiwan Alpha **RD901F-40-15K-B…-00D** (T18 knurled 6 mm shaft; `F` D-shaft and `R1` 6.35 mm round are the same footprint) | body 10.0, M7 × 0.75 5 mm bushing, 7.2 mm hole, footprint 9.5 × 12.0, shaft end about 25 mm above the PCB | official `Potentiometer_Alpha_RD901F-40-00D_Single_Vertical` | Thonk £1.69; Uraltone €1.25; on LCSC as Extended plug-in (C5340289 B10K T18, C20619172 B100K round) but hand-installed here anyway | **In use** (B100K); shaft type waits on the knob answer |
| Pot tapers | `B` linear for CV attenuators and attenuverters; `A` log for audio level; `C` reverse log exists; no `W` taper in Alpha's catalogue | | | Thonk stocks B 5K–1M, A 10K–1M, C50K, centre-detent B10K/B50K/B100K | Rule adopted |
| Knob | **Davies 1900h clone, T18 push-on** (Thonk) | 12 mm base x 16 mm tall, about 13 mm bore; proposed 15 mm pot centres need an ergonomic mockup, and larger controls may reserve multiple cells | none needed | Thonk £0.68–0.75, 21 colours; alternatives Rogan PT-1P 11.4 mm £1.65, Sifam/Intellijel cap-and-body £1.12–4.07 with free pointer indexing | **Proposed**, waits on taste answers |
| Scale trimmer (V/oct scale, HF trim) | **Bourns 3224W** 12-turn SMD, top adjust, ±10 %, ±100 ppm/°C | 4.8 × 3.5 mm on the back: factory placed, adjusted from the back with the module out of the case, no panel hole | official `Potentiometer_Bourns_3224W_Vertical` | LCSC C81348, Extended, $1.18 (1) to $0.73 (1k) | **Proposed** |
| Offset trimmer | **Bourns 3314J** single-turn SMD, ±20 %, ±100 ppm/°C; Vishay TS53YJ (official footprint, 0.1 % or 3 Ω end resistance, no LCSC number found) where end resistance matters | 4.5 mm square on the back, as above | official `Potentiometer_Bourns_3314J_Vertical` | LCSC C36376, Extended, $0.57 to $0.28 | **Proposed** |
| Rejected trimmers | Bourns 3362P (no KiCad 10 footprint, through-hole, 200-cycle life), 3323 (in Bourns' obsolete-parts tree) | | | | Do not design in |
| Panel toggle | **Dailywell 2MS3T1B1M2QES** SPDT on-off-on (Thonk DW2); **2MD3T1B1M2QES** DPDT on-off-on (DW4) where two poles are needed; Taiway 200-series is the interchangeable twin | body 8.64 + shoulder 1.20 = 9.84 mm to the panel face, 0.16 mm short of the 10 mm gap; 10-48 UNS thread 4.39 mm leaves 2.23 mm above a 2 mm panel; **5.0 mm hole**; bat T1 9.4 mm | **none in KiCad 10**; needs a `lib/footprints/` entry: three (or six) 2.54 mm holes, 8.13 × 8.64 (9.14 for DPDT) courtyard; the DPDT row spacing reads 4.06 mm and must be checked on the drawing | Thonk £2.20 (DW2), £2.19 (DW4), two nuts and a lock washer included; LCSC has only the larger 1M series | **Proposed**; slide switches rejected (2–4 mm actuators cannot reach the panel) |
| Indicator LED | **3 mm through-hole**, bare, body in the panel hole, the panel used as the soldering jig; long-lead variants exist (Bivar `-LL`). For bipolar CV: **Bivar 3BC / 3SBC** two-lead red/green | 3.2 mm hole; leads hold the body about 7–9 mm off the board; no holder footprint exists in KiCad | official `LED_D3.0mm` | Bivar 3SBC on LCSC C5519661 but flagged wave-solder, so hand-soldered regardless; any 3 mm diffused single colour for gates | **Proposed**; drive at 2 mA (5.1 kΩ from 12 V); a bipolar indicator is driven from a buffer, never from the CV node |
| USB-C PD inlet (R1) | **GCT USB4125-GF-A-0190**, 6-pin power-only; A5 = CC1 and B5 = CC2 are present, which is all a PD sink needs; 3 A, 48 V | on the **back**, near the bottom edge, opening down, plug lying flat along the board: no panel cutout, about 7 mm of added depth. A front-side receptacle sits 1.6 mm above the PCB and cannot reach a panel 10 mm away; a receptacle on the top or bottom edge fires the plug into a rail | official `USB_C_Receptacle_GCT_USB4125-xx-x-0190_6P_TopMnt_Horizontal` | DigiKey (USB4135 sibling $0.58 at 10); **JLCPCB stock of any 6-pin power-only part unverified**. Fallback that JLCPCB does assemble: Korean Hroparts TYPE-C-31-M-12, 16-pin, C165948, $0.17, unused pins listed in `partNoConnect` | **Proposed**, waits on the front-or-back answer; front access would use a panel-mount coupler with a 12 mm hole, not a hand-soldered vertical receptacle |
| Power header | 2×5 shrouded IDC, DIN 41651 | 9.1 mm housing on the back | official | any | **In use** |

**None of the checked switched TRS 3.5 mm jacks fits the proposed stack.**
The search compared candidates against the 10 mm gap, the 13.7 mm pitch and a
2 mm panel: the WQP419GR has
no switch; QingPu's PJ3410 switches the tip only and has a 13 mm body and an
M8 bushing, which would lift the panel above the pot bushings; Amphenol's
ACJS-MV35-5 switches both contacts but is 15.8 mm square, 24 mm tall and rated
for a 1.15 mm panel; the Kobiconn 161-3508-E and Same Sky SJ1-3535NG are
right-angle parts; the PJ3420 has a plastic bushing. R1's approved behaviour
("patching an individual output removes the channel from the mix") therefore
cannot come from the proposed WQP419GR's own contacts. The decision file
presents alternatives; their tradeoffs and unverified fit must not be treated
as an approved change to R1's behaviour or an exhaustive market search.

**Footprints to add to `lib/footprints/pcbgen.pretty`** before R1's layout:
the stereo Thonkiconn (copy of the mono footprint, pins S/R/T, silk and
courtyard 0.5 mm wider) and the sub-mini toggle (SPDT and DPDT). Both need
the datasheet dimensions confirmed on the drawing image or a sample.

**What the pot does not publish.** End (residual) resistance, linearity,
wiper contact variation and element tempco are absent from Alpha's catalogue
and every distributor page opened. Tolerance is ±20 % linear, ±30 % log per
Rapid; power rating is quoted as 125 mW by Uraltone and 50 mW by Rapid. An
error budget must either measure these on the first batch or be designed so
they do not matter: keep panel pots out of gain-defining positions in
precision paths, put the precision in fixed resistors plus a cermet trimmer
whose range is bounded by fixed resistors (a ±100 ppm/°C trimmer across a
small fraction of a divider has its tempco divided down with its range).

### Provenance of the hardware standard

| Part | Source opened | What it gave |
|---|---|---|
| WQP-WQP518MA, WQP-WQP419GR | qingpu-electronics.com product pages 362 and 364; thonk.co.uk/shop/thonkiconn and stereo-thonkiconn; exploding-shed.com 100516P020; kicad-footprints PR 823 diff and PR 1073; n8synth.co.uk mounting guide | naming history and cycle ratings, prices, "same footprints as the mono jack", the unmerged footprint's pad and courtyard numbers, "the B pad becomes the ring", nuts sold separately, the 10 mm body statement |
| PJ3410, ACJS-MV35-5, 161-3508-E, SJ1-3535NG | exploding-shed.com 100680; jlcpcb.com C5146694; amphenol-sine.com ACJS-MV35-5 drawing; retroamplis.com J-3508E drawing; sameskydevices.com SJ1-3535NG | the dimensions and contact sets that rule each one out |
| Alpha RD901F-40 | taiwanalpha.com downloads id=113 (the PDF the KiCad footprint cites); thonk.co.uk Alpha 9 mm pages (T18, D-shaft, vertical, long); uraltone.com RD901F-40-15K; rapidonline.com RD901F-20B3; lovemyswitches.com 9 mm 18T; jlcpcb.com C5340289, C20619172 | order code (K/F/S/R shafts, 15/20/25/30 lengths, A/B/C tapers, 00D bracket), 300° ± 5°, 15 000 cycles, torque, 50 V AC, the shaft-length convention, stock values, LCSC presence |
| Davies 1900h clone, Rogan, Sifam | thonk.co.uk knob pages | sizes, bores, shaft fits, colours, prices; Rogan dimensions from a blocked page are unverified |
| Bourns 3224W, 3314J, 3296W, 3362P; Vishay TS53 | KiCad 10 `Potentiometer_THT.pretty` and `Potentiometer_SMD.pretty` listings; lcsc.com C81348, C36376, C34846, C58159; Bourns 3362 and Vishay TS53 datasheets | which footprints exist, tolerances, tempco, turns, end resistance where published, prices and stock; the 3224W and 3314J datasheets themselves returned 403 and their end resistance is unverified |
| Dailywell 2M, Taiway 200 | thonk.co.uk sub-mini toggle page and its DW2 hardware sheet; taydaelectronics.com Dailywell 2M series PDF; lovemyswitches.com Taiway datasheet and 200-MSP1-T1B1M2QE page; taiway.com; n8synth.co.uk | part numbers, body 8.13/9.14 × 8.64, bushing 5.59 with 4.39 of 10-48 UNS-2A thread over a Ø6.00 shoulder, actuators, M2 pins, 5 mm hole, prices |
| Bivar 3BC/3SBC, Kingbright L-934 | bivar.com 3BC-X datasheet; jlcpcb.com C5519661; lcsc.com C19406435; rapidonline.com L-934 | two-lead red/green part, ratings, `-F` flanged and `-LL` long-lead variants, wave-solder flag; no lead length published |
| GCT USB4125/4135/4085, Hroparts TYPE-C-31-M-12, G-Switch GT-USB-7051A | gct.co drawings usb4125, usb4135, usb4085; digikey.com USB4135-GF-A; jlcpcb.com C165948; lcsc.com C165948, C2843970; KiCad 10 `Connector_USB.pretty` | pinouts with CC1/CC2 on the 6-pin parts, ratings, body sections, mounting, which footprints exist, JLCPCB assembly status and prices |
