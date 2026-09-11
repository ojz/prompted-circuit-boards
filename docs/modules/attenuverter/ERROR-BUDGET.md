---
status: "derived 2026-09-11; limits proposed, awaiting the decision in `docs/decisions/`"
owner: "module-design agent"
read_when: "choosing parts or circuit changes for this module, writing its simulation assertions, or planning its bench measurements"
update_when: "a part, the topology, the operating envelope or a datasheet figure changes; when measurements replace predictions"
retire_when: "the module is removed, or the adopted limits and their evidence have been folded into SPEC.md and a measured prototype record supersedes the predictions"
---

# UTIL-01 ATTENUVERTER — precision error budget

This document derives, from manufacturer figures, how far the attenuverter's
output can deviate from the ideal `Vout = (2k − 1)·Vin` and from a stable
offset, in volts and in cents at 1 V/octave. It covers the circuit as designed
(TL072C, 1% thick-film resistors, resistive offset divider) and the proposed
replacements. Every number below is arithmetic on a quoted datasheet figure;
none is a measurement. The generated SPICE evidence in
[SPEC.md](SPEC.md) is nominal and cannot show most of these terms because the
hand-built models omit them ([devices.lib](../../../modules/_models/devices.lib)).

**Unit.** At 1 V/octave one semitone is 83.33 mV and one cent is 0.8333 mV.
"c/oct" below means cents of pitch error per octave of input, the unit for a
gain error; a plain "c" is a fixed pitch shift, the unit for an offset.

## Operating envelope

Stated assumptions; the limits below are only claimed inside them.

| Quantity | Range | Basis |
|---|---|---|
| Supply rails at the header | ±12 V ±5 % (11.4–12.6 V) | Eurorack practice; no tighter spec is guaranteed by every case PSU |
| Rails at the op-amp | rail minus 0.22–0.35 V | series B5819W, forward drop from `devices.lib` fit |
| Ambient temperature | 10–40 °C (ΔT = ±15 °C from 25 °C) | inside a case in a room; not an outdoor or stage-lighting spec |
| Signal range | ±10 V at input and output | Eurorack maximum; pitch CV is normally 0–10 V |
| Source | 0–1 kΩ output resistance | 1 kΩ is the usual Eurorack output resistor |
| Load | ≥ 100 kΩ | the usual Eurorack input impedance |
| Bandwidth of interest | DC for pitch; 20 Hz–20 kHz for audio | |

## Evidence

Datasheets were fetched and read on 2026-09-11; LCSC stock and prices are
from the jlcsearch mirror of the JLCPCB parts library on the same day, at
quantity 10, in USD. Prices move; re-check before ordering.

| Part | Document | Figures used |
|---|---|---|
| TL072CDT (U1, LCSC C6961, $0.16) | TI SLOS080W, July 2025, TL07xC column at ±15 V | V_OS 3 mV typ / 10 mV max at 25 °C, 13 mV max over 0–70 °C; drift 18 µV/°C typ; I_B 65 pA typ, 7 nA max over 0–70 °C; CMRR 70 dB min; PSRR 70 dB min; A_OL 25 V/mV min; V_OM ±12 V min at R_L = 10 kΩ (3 V from each rail); V_CM ±11 V min (4 V above V−); e_n 18 nV/√Hz; SR 8 V/µs min |
| 0805W8F1003T5E, …1001…, …1501… (R1–R8, LCSC C17407/C17513/C4310, $0.003) | UNI-ROYAL, via LCSC listing | thick film, ±1 %, ±100 ppm/°C |
| Alpha RD901F B100K (RV1, RV2) | Taiwan Alpha RD901F catalogue sheet; distributor listings | total resistance ±20 %; B taper = 50 % resistance at 50 % travel; no linearity, residual-resistance or tempco figure is published |
| OPA2197IDR (candidate, LCSC C139363, $0.83, 9 500 in stock) | TI SBOS737C, March 2018, ±4 to ±18 V table | V_OS ±25 µV typ / ±100 µV max; drift ±0.5 typ / ±2.5 max µV/°C (VCM near V+: ±0.8 / ±4.5); I_B ±5 pA typ / ±20 pA max at 25 °C; CMRR 100 dB min for VCM up to (V+) − 1.5 V, 80 dB min in the last 1.5 V; PSRR ±3 µV/V max; A_OL 120 dB min; swing 125 mV max from either rail at 10 kΩ; rail-to-rail input; GBW 10 MHz; SR 20 V/µs; e_n 5.5 nV/√Hz; I_Q 1.3 mA max |
| TL072HIDR (candidate, LCSC C4370389, $0.21) | TI SLOS080W, TL07xH table | V_OS ±1 mV typ / ±4 mV max; drift ±2 µV/°C typ; I_B ±1 pA typ / ±300 pA max; CMRR 80 dB min over temperature; swing 965 mV max from rail at 10 kΩ; V_CM from (V−) + 1.5 V to V+ |
| OPA1678IDR (Mutable Instruments' choice, LCSC C192421, $0.77) | TI SBOS846 | V_OS ±0.5 mV typ / ±2 mV max; I_B ±10 pA; V_CM (V−) + 0.5 V to (V+) − 2 V; SR 9 V/µs |
| REF5050AIDR (candidate, LCSC C27804, $0.97, 21 000 in stock) | TI SBOS410G, standard grade | 5.000 V ±0.1 %; drift 8 ppm/°C max; line regulation 3 ppm/V typ; load regulation 18 typ / 30 max ppm/mA; ±10 mA output; V_IN 5.2–18 V; specified with C_L = 1 µF |
| LM4040B50 (alternative, LCSC C460606/C69315, $0.73–1.08) | TI SNOS644, B grade | 5.000 V ±0.2 %; 100 ppm/°C max; shunt; ±0.85 % total over 65 °C per the datasheet's own sum |
| RT0805BRD07100KL (candidate 100 k, Yageo, LCSC C122537, $0.037, 290 000 in stock) | Yageo RT series via LCSC | thin film, ±0.1 %, ±25 ppm/°C |
| Mutable Instruments Shades v4.0 BOM | `pichenettes/eurorack`, `shades/hardware_design/Shades.xlsx` (CC-BY-SA hardware) | four OPA1678 duals for three channels, LM4040B10 reference, 21 × 100 k thin-film ≤ 0.1 % resistors, 22 pF C0G compensation caps, 1.0 k output resistors |
| Befaco Dual Attenuverter v2 assembly guide | befaco.org, October 2022 | three TL072, ordinary 1 % resistors, four 10 pF caps (one per feedback network), 100 k pots |

Parts rejected on these figures: bipolar-input op-amps (LM4562 I_B up to 72 nA
and NE5532 200 nA into the 50 kΩ inverting node give 3.6 mV and 10 mV of
offset), OPA2277 (0.8 V/µs cannot slew a 20 kHz ±10 V sine, which needs
1.4 V/µs), REF3450 (V_IN max 12 V, exceeded by a +12.6 V rail minus 0.22 V),
LM4040 (its 100 ppm/°C is 12 times the REF5050's and it is not cheaper),
OPA1678 (its common-mode range stops 2 V below V+, so +10 V into the
non-inverting input fails at the low rail).

## Budget

Worst case means every quoted maximum at the worst end of the envelope.
Typical is the datasheet typical at 25 °C and nominal rails. "Proposed"
means the OPA2197, 0.1 %/25 ppm thin-film resistors in the gain path, a
REF5050A reference and a 10 pF C0G feedback capacitor, in either of the two
options in the decision file; option B's buffer changes only the source
loading row and adds its own offset row.

### Fixed shifts (independent of knob position)

| Term | Mechanism | Current typical | Current worst | Proposed worst |
|---|---|---|---|---|
| Op-amp input offset | V_OS × noise gain 2 (the same for every k) | 6 mV = 7 c | 20 mV at 25 °C, 26 mV over 0–70 °C = 24–31 c | 0.20 mV = 0.24 c |
| Offset drift | dV_OS/dT × 2 × 15 °C | 0.5 mV = 0.6 c | not specified | 0.14 mV = 0.16 c |
| Bias current | I_B × R_f at the inverting node; I_B × wiper impedance (≤ 25 kΩ) × 2 at the other | < 0.01 mV | 0.7 + 0.35 mV = 1.3 c | 0.006 mV |
| Buffer offset (option B only) | buffer V_OS × (2k − 1), at most ×1 | — | — | 0.10 mV = 0.12 c |
| **Total offset** | | **≈ 6.5 mV = 8 c** | **≈ 27 mV = 33 c** | **≈ 0.35 mV (A) / 0.45 mV (B) ≈ 0.5 c** |

### Gain at full clockwise (k = 1), the pitch-passing setting

At k = 1 the resistor ratio cancels exactly (`Vin·(1+g)·1 − Vin·g = Vin`),
so only the op-amp and the external loading remain.

| Term | Mechanism | Current worst | Proposed worst |
|---|---|---|---|
| Finite open-loop gain | 1 / (A_OL / 2) | 80 ppm = 1.0 c/oct | 1 ppm |
| Common-mode rejection | the non-inverting input follows Vin; error = Vin / CMRR | 316 ppm = 3.8 c/oct | 100 ppm = 1.2 c/oct (80 dB region within 1.5 V of V+); 10 ppm below it |
| Pot end resistance | k = 1 − r/R at the stop; error 2r/R | not published by Alpha; must be measured | same part, same gap |
| Source loading | 1 kΩ source into R_in = R_a ∥ R_pot = 50 kΩ (44–55 kΩ with the ±20 % pot) | 1.96–2.20 % = 24–26 c/oct | A: unchanged. B: 1 kΩ into 1 MΩ = 0.10 % = 1.2 c/oct |
| Output loading | R_o = 1 kΩ into a 100 kΩ load | 0.99 % = 11.9 c/oct | unchanged by design (see "outside the budget") |

### Gain at full anticlockwise (k = 0), inversion

| Term | Mechanism | Current worst | Proposed worst |
|---|---|---|---|
| Resistor ratio | g = R_f / R_a, two tolerances | 2.02 % = 24 c/oct | 0.20 % = 2.4 c/oct |
| Ratio drift | two tempcos × 15 °C | 0.30 % = 3.6 c/oct | 0.075 % = 0.9 c/oct |
| **Total inversion error** | | **2.3 % = 28 c/oct** | **0.28 % = 3.3 c/oct** |

### Offset reference (unpatched input)

| Term | Mechanism | Current | Proposed (REF5050A) |
|---|---|---|---|
| Nominal | divider 1.5 k / 1 k from the Schottky-dropped rail, loaded by both channels | 4.67 V simulated (4.8 V unloaded arithmetic) | 5.000 V ±5 mV |
| Rail sensitivity | loaded divider ratio 0.39 | 47 mV per 1 % of rail = 56 c; 234 mV = 281 c over the ±5 % envelope | line regulation 3 ppm/V typ: 0.01 mV; 0.27 mV with the over-temperature figure |
| Channel interaction | one channel's 50 kΩ leaving the divider | 41.8 mV simulated = 50 c | load regulation 30 ppm/mA max × 0.1 mA: 0.015 mV = 0.02 c |
| Temperature | divider ratio 200 ppm/°C; diode −2 mV/°C × 0.39 | 14 mV + 12 mV = 31 c | 8 ppm/°C × 15 °C × 5 V = 0.6 mV = 0.7 c |
| Noise | | not modelled | ≤ 25 µV rms (datasheet 3–5 µV rms per volt, 10 Hz–1 kHz) |

The reference's absolute value is not a precision term: the knob sets the
offset and the user tunes by ear or meter. Its stability against rail, load
and temperature is, and that is where the current divider fails by two orders
of magnitude.

### Headroom and input range at the low rail (±11.05 V at the op-amp)

| Term | Current (TL072C) | Proposed (OPA2197) |
|---|---|---|
| Guaranteed output swing | 3 V from each rail: ±8.05 V worst, ±9.55 V typical; ±10 V is not guaranteed even at nominal rails (±8.7 V) | 125 mV from rail at 10 kΩ: ±10.9 V guaranteed |
| Guaranteed input common-mode range | V− + 4 V: −7.05 V worst, −7.7 V at nominal rails; a −10 V input at k = 1 is outside it and TL07x inputs driven below range can invert the output phase | rail-to-rail: ±11.05 V |

The `headroom` deck's "±10 V fits" result is a property of the model, whose
clamp sits 1.5 V from the rail and which has no common-mode limit. The
datasheet does not support the claim for the real part.

### Stability

The circuit has no feedback capacitor. The inverting node's stray and input
capacitance (of order 10 pF) against R_a ∥ R_f = 50 kΩ puts a pole at about
320 kHz inside a loop that crosses over near 1.5 MHz (TL072) or 5 MHz
(OPA2197). Both reference designs compensate: Befaco with 10 pF, Mutable
Instruments with 22 pF across the feedback resistor. A 10 pF C0G across
R_f = 100 kΩ gives a 159 kHz corner and −0.07 dB at 20 kHz. This must be
confirmed by an AC deck once the model carries input capacitance; the current
model has none, so the current `transient` pass is not evidence of stability.

### Noise

18 nV/√Hz × 2 × √20 kHz = 5 µV rms (TL072C); 1.6 µV rms (OPA2197). Not a
constraint at Eurorack levels. Option B's 1 MΩ input resistor adds 18 µV rms.

### Outside the budget, deliberately

- **Knob position.** Intermediate gains are `2k − 1` with k set by hand on a
  carbon pot of unpublished linearity. The knob is the setpoint, not a
  calibrated attenuator; the terms above hold at every k, and the wiper feeds a
  high-impedance input so wiper contact resistance does not enter.
- **The receiver's input impedance.** R_o = 1 kΩ into 100 kΩ loses 0.99 %
  (12 c/oct) at every Eurorack output that follows the same convention,
  including Mutable Instruments'. It is the same for every module the
  oscillator is calibrated against, so it is documented, not budgeted. The 1 kΩ
  stays for short-circuit and cable-capacitance protection.
- **Input protection** against over-voltage or reversed power is not part of
  this budget and is not designed in; it is a separate M4 item.

## Proposed acceptance limits

To be adopted in [SPEC.md](SPEC.md) and asserted by the decks once the
decision file is answered. Each is met with margin by the proposed parts and
failed by the current ones.

| Quantity | Limit | Proposed margin |
|---|---|---|
| Output offset, any k, over the envelope | ≤ 1.0 mV (1.2 c) | 0.35–0.45 mV |
| Unity gain error at k = 1, output open, 0 Ω source | ≤ 0.05 % (0.6 c/oct) | ≈ 0.01 % |
| Inversion gain error at k = 0, same conditions | ≤ 0.3 % (3.6 c/oct) | 0.28 % |
| Change of either channel's output when the other is patched or turned | ≤ 0.1 mV (0.12 c) | 0.015 mV |
| Offset reference change over ±5 % rails | ≤ 0.3 mV | 0.01–0.27 mV |
| Offset reference change over 10–40 °C | ≤ 1.0 mV (1.2 c) | 0.6 mV |
| ±10 V in, ±10 V out at k = ±1, rails at 11.4 V, load 100 kΩ | met by guaranteed figures | 0.9 V of swing, full common-mode range |
| Phase margin of each stage with 10 pF stray | ≥ 45° | to be shown by the AC deck |
| Input impedance | ≥ 44 kΩ (A) or ≥ 900 kΩ (B), stated in the spec | |

## What this does not establish

The figures are manufacturer maxima combined arithmetically, not measured
distributions, and the interaction and loading rows still depend on the
existing SPICE decks whose models omit input capacitance, common-mode
limits and real output stages. Board leakage, jack contact resistance and
pot end resistance are not in any datasheet used here. Physical confirmation
is the M5 gate; until then these are predictions with stated sources.
