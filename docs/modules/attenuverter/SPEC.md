---
status: "maintained requirements; precision redesign pending a decision in `docs/decisions/`"
owner: "module-design agent, with user decisions"
read_when: "designing, reviewing, simulating or preparing to build this module"
update_when: "requirements, approved parts/circuit, evidence or model limitations change"
retire_when: "the module is removed or a replacement spec takes ownership; retain build-revision evidence in its checkpoint"
---

# UTIL-01 ATTENUVERTER — dual attenuverter / offset, 6HP

Two channels of the classic single-op-amp attenuverter. Each channel has an
input jack, a centre-detent-free 100k pot and an output jack. With nothing
patched the input is normalled to about +4.7 V, so the channel becomes a
bipolar offset source.

Design source: [Attenuverter.hs](../../../modules/attenuverter/Attenuverter.hs#L1)
and [AttenuverterPanel.hs](../../../modules/attenuverter/AttenuverterPanel.hs#L1).
Commands and artifact paths below are relative to the repository root, not
this documentation directory. Projects live in `modules/attenuverter/kicad/`
and its `panel/` subdirectory; regenerate
with `cabal run pcbgen -- all` from the repo root, verify with
`toolkit/check.sh attenuverter [panel]`, fab bundle with
`toolkit/fab.sh attenuverter`. Do not edit the generated KiCad files.

## Precision Requirement (2026-09-11)

Precision, including pitch-CV accuracy and stability, is a requirement rather
than an optional upgrade. The circuit and simulation results below describe
the current implementation, not an accepted precision design.

The roughly 41.8 mV channel-patching shift is an open defect to correct before
recommending an order. Its historical 50 mV test budget does not establish
precision suitability. The agent must derive a numerical error budget covering
gain, offset, input/output loading, channel independence, noise, supply and
temperature drift, and headroom. Express pitch errors in cents at 1 V/octave
as well as volts, with explicit operating conditions and model limitations.

The budget is derived in [ERROR-BUDGET.md](ERROR-BUDGET.md) (2026-09-11) from
the TL072C, resistor, pot, OPA2197 and REF5050 datasheets, with proposed
acceptance limits. Beyond the reference defect it finds, for the parts as
designed: a worst-case output offset of about 27 mV (33 cents), an inversion
gain error of 2.3 % (28 cents per octave), an output swing the datasheet does
not guarantee to reach ±10 V, an input common-mode range that a −10 V input
exceeds, no feedback compensation capacitor, and a 50 kΩ input impedance that
loads a 1 kΩ source 2 %. The parts and topology choice is the open decision in
[../../decisions/2026-09-11-attenuverter-precision-parts.md](../../decisions/2026-09-11-attenuverter-precision-parts.md).

Those limits and circuit improvements are not implemented yet. The existing
decks remain characterization/regression evidence; they must be extended with
the new acceptance limits and meaningful corners, not loosened to pass. Real
accuracy must ultimately be checked with a board-specific measurement plan.

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

Offset reference: +12 V → 1.5k / 1k divider, 100 nF to GND, on the jacks'
switch (TN) pins. The open-circuit arithmetic gives 4.8 V, and that is what
this line used to claim; simulation says **4.67 V with both channels idle**
([interaction.cir](../../../modules/attenuverter/sim/interaction.cir#L1)). The difference is two things the arithmetic left
out: the series Schottky drops the rail to about 11.84 V, and the two
channels' pots and input resistors load the divider. Nothing depends on the
exact nominal value for basic knob operation, but reference stability matters
for pitch use; the current supply-derived divider is not a precision reference.

Patching a cable into one channel lifts that channel's loading off the
divider and moves the reference. Simulated: **+41.8 mV**, which appears at the
other channel's output at full gain. It passes the interaction deck's historical
50 mV budget, but does not meet the precision-first requirement above.
This is a DC shift through the shared reference, not a complete bound on all
possible cross-channel effects.

In practical terms, with channel 2's input empty and its knob fully clockwise,
its output changes from about +4.67 V to +4.71 V when a cable is inserted into
channel 1's input, even though nobody touched channel 2. Into a 1 V/octave
pitch input, a 41.8 mV change would mean about 50 cents, half a semitone. The
effect depends on the knob setting and load; this particular shared-reference
mechanism applies when the other channel uses its internal offset source.

Power: 2×5 shrouded IDC, series B5819W Schottky on each rail, 10 µF + 100 nF
per rail. Header pins 1–2 = −12 V, 3–8 = GND, 9–10 = +12 V.

## Simulated behaviour

`toolkit/sim.sh attenuverter` runs the decks in `modules/attenuverter/sim/`. The netlist is
generated from the Haskell design, the same source the board is generated
from, so it cannot describe a different circuit than the one being built.
The device models are hand-built from datasheet figures and their limits are
stated in [devices.lib](../../../modules/_models/devices.lib#L1).

| Question | Answer | Deck |
|---|---|---|
| Does `Vout = (2k − 1)·Vin` hold? | Yes, within 6 mV — the op-amp's 3 mV input offset at a noise gain of 2 | `transfer` |
| Does ±10 V full scale fit? | In the model, yes at nominal supply and light load: its output limits are +10.34 V and −10.37 V. The TL072C datasheet does not support this: it guarantees only 3 V from each rail and an input common-mode range 4 V above the negative rail, so ±10 V is not assured (see ERROR-BUDGET.md) | `headroom` |
| What is the offset reference really? | 4.67 V, not the 4.8 V the open-circuit arithmetic gives | `interaction` |
| Do the channels interact? | Yes, 41.8 mV: patching one moves the other's idle output | `interaction` |
| What does a load cost? | 0.99% into 100k, 1.96% into 50k, 9.1% into 10k — the 1k output resistor dividing | `loading` |
| Will the knob null at centre? | Within −44 to +55 mV on a 5 V input with 1% resistors, so about 1% | `corners` |
| Does matching affect the gain? | Not at full clockwise: `Vin·(1+g)·k − Vin·g` is exactly `Vin` at k=1 for any g | `corners` |
| Does a 10% low supply matter? | The tested 5 V signal still passes; the offset reference moves to 4.22 V. This does not establish ±10 V headroom at low supply | `corners` |
| Does it keep up at 20 kHz full scale? | Amplitude error 0.05%. The 137 mV of instantaneous error is 0.8° of phase lag, not amplitude | `transient` |

Headroom is spare output range before clipping, not extra gain. At full
clockwise, a +5 V input should produce about +5 V and a +10 V input about
+10 V. A larger input asking for +11 V exceeds the model's roughly +10.35 V
output limit, so the waveform stops following and its peak flattens. The
roughly 0.35 V margin is the difference between the chosen 10 V signal peak
and that nominal model limit; it is not an automatic 0.35 V added to a signal,
a safety limit, or a guaranteed capability of the real part. Negative peaks
have the corresponding lower limit. Supply, load and part variation matter.

**This is simulation, not measurement.** No board has been built or probed.
The netlist carries no parasitics, no component tolerances unless a deck
sweeps them, and the op-amp model accounts for quiescent supply current only
— it does not draw load current from the rails, so nothing here is evidence
about power consumption under load. Overload behaviour is a clamp in the
model, not an output stage, so where clipping *starts* is meaningful and
what happens beyond it is not.

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

## Parts (JLCPCB, verified 2026-09-08; LCSC numbers re-checked 2026-09-11)

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

- Precision acceptance pending: correct channel interaction and establish the full error budget before recommending an order; existing simulation passes are not precision approval.
- Latest checks and hardware status: [../../HANDOFF.md](../../HANDOFF.md).
- Computed routing and analog findings: [route-report.md](route-report.md).
- Diagnostic fabrication command: `toolkit/fab.sh attenuverter` (SMD assembly, back side); this is not purchase approval.
