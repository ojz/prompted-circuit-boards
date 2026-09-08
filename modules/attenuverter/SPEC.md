# UTIL-01 ATTENUVERTER — dual attenuverter / offset, 6HP

Two channels of the classic single-op-amp attenuverter. Each channel has an
input jack, a centre-detent-free 100k pot and an output jack. With nothing
patched the input is normalled to about +4.8 V, so the channel becomes a
bipolar offset source.

Design source: `toolkit/src/Designs/Attenuverter.hs` (module) and
`toolkit/src/Designs/AttenuverterPanel.hs` (panel). Generated projects:
`modules/attenuverter/` and `modules/attenuverter/panel/`. Do not edit the
generated KiCad files.

## Circuit

Per channel (TL072, one op-amp per channel):

- `R_a` 100k from IN to the inverting input, `R_f` 100k from the output back
  to it: inverting gain −1.
- The pot is a divider across IN and GND; its wiper feeds the non-inverting
  input. With `R_a = R_f` the non-inverting gain is 2, so
  `Vout = (2k − 1) · Vin`, k = pot fraction. Fully anticlockwise −1×,
  centre 0, fully clockwise +1×. The input end of the pot is pin 3 so that
  clockwise is positive.
- `R_o` 1k in series with the output jack.
- Input impedance ≈ 50k (pot ∥ `R_a`).

Offset reference: +12 V → 1.5k / 1k divider → 4.8 V, 100 nF to GND, on the
jacks' switch (TN) pins. Source impedance 600 Ω against a 50k load gives a
1 % error, acceptable for an offset knob.

Power: 2×5 shrouded IDC, series B5819W Schottky on each rail, 10 µF + 100 nF
per rail. Header pins 1–2 = −12 V, 3–8 = GND, 9–10 = +12 V.

## Panel (30.0 × 128.5 mm, Doepfer 6HP)

Coordinates from the panel's top-left corner, mm.

| Item | x | y | Hole |
|------|---|---|------|
| RV1 shaft (channel 1) | 15.0 | 22.0 | 7.2 (Alpha 9 mm bushing, M7) |
| J1 IN 1 | 7.5 | 38.0 | 6.4 |
| J2 OUT 1 | 22.5 | 38.0 | 6.4 |
| RV2 shaft (channel 2) | 15.0 | 64.0 | 7.2 |
| J3 IN 2 | 7.5 | 80.0 | 6.4 |
| J4 OUT 2 | 22.5 | 80.0 | 6.4 |
| Rail holes | 7.5, 22.74 | 3.0, 125.5 | 3.2 |

Pots and jacks alternate rows because a 9 mm pot footprint (13.75 × 12.8 mm)
and a Thonkiconn (9 × 14.4 mm) do not fit side by side on a 28 mm board.

## PCB (28.0 × 108.0 mm)

Board origin at panel (1.0, 10.25): 1 mm inside each side edge, centred
vertically, 108 mm tall so it clears every rail type.

- Front (towards the panel): J1–J4 Thonkiconn, RV1–RV2 Alpha RD901F 9 mm
  (rotated 90°, pins down, lugs left and right of the shaft). Hand-soldered.
- Back: everything else, so JLCPCB assembles one side. TL072 SOIC-8 centred
  at panel (14, 98.5); channel 1 passives in the left column, channel 2 in the
  right; decoupling next to the supply pins; bulk caps and Schottkys in the
  row above the header; offset divider between the jack columns at x = 15.
  Power header centred at panel (14.5, 111.5), long axis horizontal, pins 1–2
  (−12 V) at the right, marked `-12V` on the silkscreen.
- Passives carry no silkscreen reference (JLCPCB places from BOM and CPL);
  U1 and J5 keep theirs.
- Routed entirely by pcbgen's grid router, GND included, with GND pours on
  both layers on top. 0.3 mm traces, 0.6/0.3 mm vias.

## Parts (JLCPCB, verified 2026-09-08)

| Ref | Value | Package | LCSC |
|-----|-------|---------|------|
| U1 | TL072 (TL072CDT) | SOIC-8 | C6961 |
| D1, D2 | B5819W | SOD-123 | C8598 |
| C1, C2 | 10 µF 25 V X5R | 0805 | C15850 |
| C3, C4, C5 | 100 nF 50 V X7R | 0805 | C49678 |
| R1, R2, R4, R5 | 100k 1 % | 0805 | C17407 |
| R3, R6, R8 | 1k 1 % | 0805 | C17513 |
| R7 | 1.5k 1 % | 0805 | C4310 |
| J1–J4 | Thonkiconn PJ398SM | THT | hand |
| RV1, RV2 | Alpha RD901F B100K | THT | hand |
| J5 | 2×5 shrouded IDC | THT | hand |

## Status

- Module and panel generated; ERC and DRC clean with every severity enabled.
- Autorouted: 16 nets, 6 vias, 1.13 detour ratio, 11 negotiation iterations.
- JLCPCB bundle via `toolkit/fab.sh attenuverter` (SMD assembly, back side).
- Not yet built or measured.
