---
status: "maintained requirements; option B precision design implemented and simulated 2026-09-13, not built"
owner: "module-design agent, with user decisions"
read_when: "designing, reviewing, simulating or preparing to build this module"
update_when: "requirements, approved parts/circuit, evidence or model limitations change"
retire_when: "the module is removed or a replacement spec takes ownership; retain build-revision evidence in its checkpoint"
---

# UTIL-01 ATTENUVERTER — dual precision attenuverter / offset, 6HP

Two channels, each an input jack, a 100k pot and an output jack. A channel
multiplies its input by anything from −1 (knob fully anticlockwise) through
0 (centre) to +1 (fully clockwise). With nothing patched the input is
normalled to a 5.000 V reference, so the channel becomes a bipolar offset
source from −5 V to +5 V that does not move with the supply, the other
channel or the room.

Design source: [Attenuverter.hs](../../../modules/attenuverter/Attenuverter.hs#L1)
and [AttenuverterPanel.hs](../../../modules/attenuverter/AttenuverterPanel.hs#L1).
Commands and artifact paths below are relative to the repository root, not
this documentation directory. Projects live in `modules/attenuverter/kicad/`
and its `panel/` subdirectory; regenerate with `cabal run pcbgen -- all` from
the repo root, verify with `toolkit/check.sh attenuverter [panel]`, simulate
with `toolkit/sim.sh attenuverter`, fab bundle with
`toolkit/fab.sh attenuverter`. Do not edit the generated KiCad files.

## Precision Requirement And The Decision That Met It

Precision, including pitch-CV accuracy and stability, is a requirement rather
than an optional upgrade (roadmap, 2026-09-11). The first circuit (TL072C,
1 % resistors, a resistive divider off the +12 V rail as the offset reference)
failed it: [ERROR-BUDGET.md](ERROR-BUDGET.md) derived from the datasheets a
worst-case output offset of 27 mV (33 cents), 2.3 % of inversion error, a
reference that moved 47 mV per 1 % of rail and 41.8 mV when the other
channel was patched, an output swing not guaranteed to reach ±10 V, an input
common-mode range a −10 V input exceeded, and a 50 kΩ input impedance that
loaded a 1 kΩ source 2 %.

The user was asked (decision file of 2026-09-11) whether to swap parts inside
the same topology (option A) or also add a unity-gain input buffer per
channel (option B), the latter being an architecture change. **The answer,
given in conversation on 2026-09-11, was B**, with the reasoning, in their
words: *"i have a token budget that i can spend on finding the best circuits,
and i don't want to be ordering sub-par modules. and so making the board a
couple bucks more expensive means nothing for me."* Cost is therefore not an
optimisation target for module parts; the only cost constraint is market
parity with buying a commercial module (recorded in
[../../ROADMAP.md](../../ROADMAP.md)). Option B was implemented on
2026-09-13 and the decision file retired; this section is its record.

The acceptance limits are the table at the end of
[ERROR-BUDGET.md](ERROR-BUDGET.md); every one of them is asserted by a deck
in `modules/attenuverter/sim/` and the results are below. One design value
was changed during implementation on evidence from those decks: the gain
resistors are 10 kΩ rather than the 100 kΩ the decision file assumed,
because with 100 kΩ the op-amp's input capacitance bent the full-clockwise
response by 1.3 % at 20 kHz in the model (4.6 % with 10 pF of stray). The
buffer makes the value invisible to anything outside the board.

## Circuit

Per channel, one OPA2197 dual precision op-amp:

- **Unit A, input buffer.** Non-inverting input on the jack tip, output tied
  to its inverting input: unity gain. `R_in` 1 MΩ from the tip to ground
  defines the input when a cable is inserted with nothing on the far end.
  Input impedance is therefore 1 MΩ, and a 1 kΩ source loses 0.1 %.
- **Unit B, attenuverter.** `R_a` 10 kΩ 0.1 % from the buffer output to the
  inverting input, `R_f` 10 kΩ 0.1 % from the output back to it, `C_f` 10 pF
  C0G across `R_f`. The pot is a divider across the buffer output and ground;
  its wiper feeds the non-inverting input. With `R_a = R_f` the
  non-inverting gain is 2, so `Vout = (2k − 1) · Vin`, k = pot fraction. The
  buffer output is on pot pin 3 so that clockwise is positive.
- `R_o` 1 kΩ in series with the output jack: short-circuit and cable
  protection. Into a 100 kΩ input it costs 0.99 %, the same as every Eurorack
  output built this way, and is documented rather than budgeted.

Why `C_f` matters: the inverting node carries about 8 pF of op-amp input
capacitance plus strays, a pole in the feedback path. The `stability` deck
measures the loop gain of the generated netlist and finds 72° of phase
margin with `C_f` and 27° without it. Do not remove it as a part that
"does nothing".

**Offset reference.** A REF5050 (5.000 V ±0.1 %, 8 ppm/°C max, 3 ppm/V line,
30 ppm/mA load) fed from +12 V through the series Schottky, with 1 µF on its
input, 1 µF on its output (the datasheet's stability condition) and 1 µF on
its noise-reduction pin. Its output is normalled to both input jacks' switch
pins. Each channel loads it with about 5 µA through the buffer, so patching
or turning one channel moves the other by about 1 µV.

**Power.** 2×5 shrouded IDC, series B5819W Schottky on each rail, 10 µF +
100 nF per rail plus 100 nF at each op-amp's supply pins. Header pins 1–2 =
−12 V, 3–8 = GND, 9–10 = +12 V.

## Simulated behaviour

`toolkit/sim.sh attenuverter` runs the eight decks in
`modules/attenuverter/sim/`. The netlist is generated from the Haskell design,
the same source the board is generated from, so it cannot describe a
different circuit than the one being built. The device models are hand-built
from datasheet figures at their maxima and their limits are stated in
[devices.lib](../../../modules/_models/devices.lib#L1). Every limit below is
from the acceptance table in [ERROR-BUDGET.md](ERROR-BUDGET.md).

| Question | Limit | Simulated | Deck |
|---|---|---|---|
| Does `Vout = (2k − 1)·Vin` hold? | offset ≤ 1 mV, unity gain ≤ 0.05 % | offset 0.21 mV at k = 0.5; unity gain error 0.006 % | `transfer` |
| Does ±10 V pass at the low rail (11.4 V), 100 kΩ load? | ±10 V at the op-amp output, k = 0 and k = 1 | yes; clipping starts at about ±11.1 V | `headroom` |
| Do the channels interact? | ≤ 0.1 mV when the other is patched, turned or driven full scale | 1.3 µV, 1.3 µV, 1.3 µV | `interaction` |
| Will the knob null at centre, and how good is the inversion? | null ≤ 0.15 % of input; inversion ≤ 0.3 % at the worst 0.1 % corner | 0.104 %; 0.202 % | `corners` |
| Do the rails matter? | signal ≤ 1 mV and reference ≤ 0.3 mV over ±5 % rails | 0.2 µV; 10 µV | `corners` |
| What does a load cost? | ≤ 1.1 % into 100 kΩ, ≤ 2.5 % into 50 kΩ | 0.99 %, 1.96 % (the 1 kΩ output resistor) | `loading` |
| What does a 1 kΩ source cost? | ≤ 0.15 % | 0.10 % | `loading` |
| Does it keep up at 20 kHz full scale? | amplitude within 0.5 % at k = 0 and k = 1 | 0.015 % at k = 1, 0.008 % at k = 0 | `transient` |
| Is each loop stable with 10 pF of stray? | phase margin ≥ 45° | stage 72°, buffer 67° (the buffer's rests on the model's assumed second pole); stage without `C_f`: 27° | `stability` |
| Is the audio band flat? | 20 kHz within 0.1 % of 1 kHz at both knob ends | 0.049 % at k = 1, 0.006 % at k = 0 | `stability` |
| What does 10–40 °C do? | reference ≤ 1 mV, offset ≤ 1 mV | reference ±0.60 mV; offset 0.12 mV at 10 °C, 0.27 mV at 40 °C | `temperature` |

**This is simulation, not measurement.** No board has been built or probed.
The netlist carries no parasitics except the 10 pF of stray the stability
deck adds by hand, no component tolerances unless a deck sweeps them, and the
op-amp model draws quiescent current but not load current from the rails, so
nothing here is evidence about power consumption under load. Overload
behaviour is a clamp in the model: where clipping *starts* is meaningful and
what happens beyond it is not. Finite CMRR and PSRR, noise and the pot's
end resistance and linearity are not modelled; the budget carries the first
two from the datasheets and the pot's figures are unpublished and must be
measured on a real part.

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

## PCB (28.0 × 100.0 mm)

Board origin at panel (1.0, 14.25): 1 mm inside each side edge, centred
vertically, 100 mm tall so it sits in JLCPCB's 100 × 100 mm tier
([../../JLCPCB.md](../../JLCPCB.md)) and still clears every rail type.

- Front (towards the panel): J1–J4 Thonkiconn, RV1–RV2 Alpha RD901F 9 mm
  (rotated 90°, pins down, lugs left and right of the shaft). Hand-soldered.
- Back: everything else, so JLCPCB assembles one side. Two strips of the
  back are free of through-hole pads and 11.5 mm tall across the full width:
  between the first jack row's tip pads and the second pot's lugs (panel
  y 50.5–62) and between the second jack row's tip pads and the power header
  (y 93–104.5). Each holds three rows of 0805s at 4 mm pitch around a SOIC-8
  in the middle row. Channel 1's OPA2197 (U1) sits left in the upper strip
  with the REF5050 (U3) and its three capacitors to its right; channel 2's
  OPA2197 (U2) sits centred in the lower strip with the Schottkys and bulk
  capacitors either side. Decoupling sits in the row nearest the supply pin
  it serves. The power header is centred at panel (14.5, 109.5), long axis
  horizontal, pins 1–2 (−12 V) at the right, marked `-12V` on the silkscreen.
- Passives carry no silkscreen reference (JLCPCB places from BOM and CPL);
  U1–U3 and J5 keep theirs.
- Routed entirely by pcbgen's grid router, GND included, with GND pours on
  both layers on top. 0.3 mm traces, 0.6/0.3 mm vias. Routing and crosstalk
  results: [route-report.md](route-report.md).

## Parts

LCSC numbers verified against LCSC's product data on 2026-09-13 (precision
parts and new passives) and jlcpcb.com on 2026-09-08 (the rest). All SMD
parts are JLCPCB "extended" except where marked basic; each extended type
carries a one-time assembly fee per order.

| Ref | Value | Package | LCSC |
|-----|-------|---------|------|
| U1, U2 | OPA2197IDR | SOIC-8 | C139363 |
| U3 | REF5050AIDR | SOIC-8 | C27804 |
| D1, D2 | B5819W | SOD-123 | C8598 |
| C1, C2 | 10 µF 25 V X5R | 0805 | C15850 |
| C3, C4, C11, C12 | 100 nF 50 V X7R | 0805 | C49678 |
| C6, C7, C8 | 1 µF 50 V X7R (Samsung CL21B105KBFNNNE) | 0805 | C28323 (basic) |
| C9, C10 | 10 pF 50 V C0G | 0805 | C344177 |
| R1, R2, R4, R5 | 10k 0.1 % 25 ppm/°C thin film (Yageo RT0805BRD0710KL) | 0805 | C110775 |
| R3, R6 | 1k 1 % | 0805 | C17513 |
| R9, R10 | 1M 1 % | 0805 | C17514 (basic) |
| J1–J4 | Thonkiconn PJ398SM | THT | hand |
| RV1, RV2 | Alpha RD901F B100K | THT | hand |
| J5 | 2×5 shrouded IDC | THT | hand |

### Datasheet provenance

Where every figure this design rests on came from, fetched headlessly on
2026-09-13 unless stated. "Used for" says which numbers were taken, so a
revision change can be checked against exactly those. The device models in
[devices.lib](../../../modules/_models/devices.lib#L1) record the same
sources for the parameters they encode. Anything marked **unverified** was
not reachable as a document from this workstation; the figure used came from
a distributor listing and the verification is owed by hand before an order.

| Part | Manufacturer | Document, revision | URL | Used for |
|---|---|---|---|---|
| OPA2197IDR | Texas Instruments | SBOS737C, Rev. C, January 2016 – March 2018 | [ti.com/lit/gpn/OPA2197](https://www.ti.com/lit/gpn/OPA2197) (PDF); [HTML viewer](https://www.ti.com/document-viewer/OPA2197/datasheet) | V_OS ±100 µV max, drift ±2.5 µV/°C max, I_Q 1.0 typ / 1.3 mA max per amplifier, C_in 1.6 pF differential ∥ 6.4 pF common-mode, swing 125 mV from rail at 10 kΩ, supply ±2.25 to ±18 V, CMRR, PSRR, A_OL, GBW, slew ([ERROR-BUDGET.md](ERROR-BUDGET.md)) |
| REF5050AIDR | Texas Instruments | SBOS410O, Rev. O, June 2007 – October 2025 | [ti.com/lit/gpn/REF50](https://www.ti.com/lit/gpn/REF50) (PDF); [HTML viewer](https://www.ti.com/document-viewer/REF50/datasheet) | 5.000 V ±0.1 % (AI grade), 8 ppm/°C max, 3 ppm/V, 30 ppm/mA max, I_Q 0.8 typ / 1.0 mA max, V_IN ≥ V_OUT + 0.2 V, C_L = 1 µF condition. The older path `ti.com/lit/ds/symlink/ref5050.pdf` now returns 404; TI hosts the family under REF50 |
| B5819W SL (C8598) | JSCJ, Jiangsu Changjing Electronics Technology | **unverified**: LCSC's datasheet link is an in-page viewer, JSCJ's site offers no direct PDF | [LCSC C8598](https://www.lcsc.com/product-detail/C8598.html) | 40 V, 1 A, V_F 0.6 V at 1 A, SOD-123, from the LCSC listing. The model in devices.lib is a fitted generic Schottky curve and says so; only the series drop (0.2–0.35 V at 5 mA) enters the budget |
| RT0805BRD0710KL (C110775) | Yageo | RT thin-film series; **unverified**: yageo.com redirects to a script-rendered site and the Mouser mirror timed out | [LCSC C110775](https://www.lcsc.com/product-detail/C110775.html) | ±0.1 %, ±25 ppm/°C, from the LCSC listing; these two numbers are the inversion-error and ratio-drift rows of the budget, so confirm them on Yageo's PYu-RT datasheet before ordering |
| CL21B105KBFNNNE (C28323) | Samsung Electro-Mechanics | Part-number code confirmed on Samsung's [Component Library](https://product.samsungsem.com/mlcc/basic-search.do) (21 = 0805, B = X7R, 105 = 1 µF, K = ±10 %, B = 50 V, F = 1.25 mm); MLCC catalogue December 2025; per-part page is script-only, **unverified** | [samsungsem.com catalogue](https://product.samsungsem.com/resources/file/product-catalog/MLCC_2512.pdf) | value and voltage only (the REF5050's 1 µF stability condition) |
| 10 µF C15850, 100 nF C49678, 10 pF C0G C344177, 1 k C17513, 1 M C17514 | various | LCSC listings only, **unverified** as documents | jlcpcb.com parts library, 2026-09-08 and 2026-09-13 | value, tolerance class and voltage; no figure from these enters the error budget except the 10 pF C0G's dielectric (stability) |
| Thonkiconn PJ398SM | QingPu (WQP), sold by Thonk | Thonk drawing, ver. 1, undated (JPG) | [thonk.co.uk drawing](https://www.thonk.co.uk/wp-content/uploads/2018/07/Thonkiconn_Jack_Datasheet-new.jpg); [product page](https://www.thonk.co.uk/shop/thonkiconn/) | body 9 mm, bushing 5.5 mm (M6, 4.5 threaded), footprint 9 × 10.5 mm, DC 30 V 0.5 A ([../../MECHANICAL.md](../../MECHANICAL.md)) |
| Alpha RD901F-40-00D B100K | Taiwan Alpha Electronic | 9 mm single metal-shaft catalogue, 5 pages, undated; Thonk's vertical drawing SLH-211 (directory dated 2014-12-10) | [taiwanalpha.com catalogue](https://www.taiwanalpha.com/downloads?target=products&id=113); [Thonk drawings](https://www.thonk.co.uk/wp-content/uploads/Documents/alpha/9mm/) | body 10 mm, M7 × 0.75 bushing 5 mm, shaft 15 mm, footprint 9.5 × 12.0 mm, pins at 2.5 mm, bracket slots 11.4 mm apart, 300°, nut 2.0 mm; ±20 % total resistance from distributor listings; no linearity or tempco figure is published |
| 2×5 shrouded IDC header | generic DIN 41651; Würth 61201021621 as the representative drawing | Würth datasheet rev. 002.001, 2026-08-30 | [we-online.com 61201021621](https://www.we-online.com/components/products/datasheet/61201021621.pdf); mating socket [61201023021](https://www.we-online.com/components/products/datasheet/61201023021.pdf) rev. 002.000, 2022-08-30 | housing 9.1 mm tall, 20.36 × 8.75 mm; socket 8.45 mm plus strain relief ([../../MECHANICAL.md](../../MECHANICAL.md)). Record the header actually bought when it is |

## Status

- Precision design implemented and simulated against the adopted limits;
  not built, not measured. Physical confirmation is the M5 gate.
- The design is built from the block library: the module skeleton
  (`Block.Eurorack`), power entry and protection (`Block.Power`) and the
  buffered attenuverter channel (`Block.Precision`), placed by
  `Attenuverter.hs`. The channel block is the one that reappears on every CV
  input of the five-board system.
- Mechanical stack and the fit review of the SMD strips:
  [../../MECHANICAL.md](../../MECHANICAL.md). First power-up procedure with
  the expected readings: [POWER-UP.md](POWER-UP.md).
- Outstanding before an order: input over-voltage protection (a separate M4
  item), the hand verification of the datasheets marked unverified above,
  and an itemised cost and stock check against JLCPCB.
- Latest checks and hardware status: [../../HANDOFF.md](../../HANDOFF.md).
- Diagnostic fabrication command: `toolkit/fab.sh attenuverter` (SMD
  assembly, back side); this is not purchase approval.
