---
status: "behavior sketched 2026-09-21 from the user's description and revised the same evening; VCV Rack prototype built; no circuit, part or layout chosen"
owner: "the user owns musical behavior; the agent owns derivation and evidence"
read_when: "playing or changing the Rack prototype, or resuming hardware for this module"
update_when: "playtesting changes the behavior, an open question below is answered, or hardware work begins"
retire_when: "the module is dropped, or a hardware specification with measured evidence takes over"
---

# Quad Amp

Four amplifier channels on a normalled mix bus. Described by the user on
2026-09-21, built as a VCV Rack module the same day, and revised the same
evening from a coarse/fine level pair to an initial gain plus an attenuverted
modulation under [V0](../../ROADMAP.md#v0-playable-digital-modules-and-function-balance-current).

**This is a musical prototype, not a circuit.** No topology, part, error budget
or layout is chosen. Nothing here is a purchase, fabrication or precision
approval, and the Rack module is ideal arithmetic, not a model of any hardware.

## Behaviour

Each of the four channels, top to bottom on the panel:

```
gain = (BIAS + MOD * DEPTH / 10) / 10
OUT  = saturate(SIG * gain)
```

- `SIG` is **normalled to +10 V** when its jack is empty.
- `MOD` is **not normalled**: an empty jack is 0 V, so DEPTH visibly does
  nothing without a cable rather than quietly becoming a second level knob.
- `BIAS` and `DEPTH` both span -10 V to +10 V and read in volts.
- The gain may exceed unity; see [Overdrive](#overdrive).

`SUM` carries the sum of the channels whose own `OUT` is **unpatched**.
Patching a channel's output removes that channel from `SUM` and does nothing
else: the channel keeps working, and unpatching restores it. This is the same
normalled-break rule already approved for [R1](../io-mixer/SPEC.md).

### Why the bias, and what it fixed

The first version multiplied three things: `SIG * CV * (COARSE + FINE)`. That
has a defect the user found by asking whether FINE earned its grid cell: **with
a CV patched, a channel could never sit half open.** CV at zero volts meant
silence and no knob could change it, so the modulation could only ever
attenuate downward from the knob's setting. A base level under modulation is
what a VCA is for most of the time, and the old arrangement could not produce
one. Replacing the fine trim with a bias on the gain is the standard topology
(Doepfer A-132, Veils, Quad VCA all do initial gain plus attenuated CV), so it
also serves [reuse proven circuits](../../../AGENTS.md#rules) better.

### What the normals buy

| SIG | MOD | The channel is | |
|---|---|---|---|
| open | open | a DC offset | `OUT = BIAS`, the dial reading in volts |
| patched | open | an attenuverter | `OUT = SIG * BIAS/10`, unity at full |
| patched | patched | **a VCA with a base level** | `BIAS` sets how open it sits, `MOD * DEPTH` moves it |
| open | patched | **offset plus attenuverted CV** | `OUT = BIAS + MOD * DEPTH/10`: scale-and-shift |

Ring modulation is still available (BIAS 0, DEPTH full, audio into MOD), and
the gain is still four-quadrant, so negative BIAS or negative DEPTH inverts.
With four channels summing, the module is also a four-input mixer and a
four-input CV adder. That breadth is the point, not a side effect.

## Panel

Five columns by five rows, which the [five-row rule](../../../AGENTS.md#rules)
and the column count together fix at **16 HP**. Columns one to four are the
channels; the fifth holds `SUM` at the bottom and **four cells reserved for I/O
not yet decided**.

| | col 1 | col 2 | col 3 | col 4 | col 5 |
|---|---|---|---|---|---|
| row 1 | SIG IN | SIG IN | SIG IN | SIG IN | *reserved* |
| row 2 | BIAS | BIAS | BIAS | BIAS | *reserved* |
| row 3 | MOD | MOD | MOD | MOD | *reserved* |
| row 4 | DEPTH | DEPTH | DEPTH | DEPTH | *reserved* |
| row 5 | OUT | OUT | OUT | OUT | **SUM** |

The order is two pairs and a result -- the signal and how much of it, the
modulation and how much of it, then the output -- so each knob sits under the
jack it belongs to and the column reads in signal-flow order.

**The known cost of that order:** jacks and knobs alternate, so with a channel
fully patched a cable hangs over each of its knobs, eight cables over eight
knobs across the module. The conventional alternative puts all knobs above all
jacks and gives that up. Adopted deliberately for the reading; the true-size
mockup required by [MECHANICAL.md](../../MECHANICAL.md#grid-and-fit-gate) must
check it with real cables, and this is not settled until it does.

Control centres, in millimetres from the panel's top-left corner, viewed from
the front, implemented in `rack/src/QuadAmp.cpp` from these same numbers so the
prototype previews the real panel:

- Panel 80.90 mm wide (Doepfer 16 HP) by 128.50 mm.
- Columns at 15.00 mm pitch, centred: **10.45, 25.45, 40.45, 55.45, 70.45**.
- Rows at 15.24 mm pitch (three nominal HP), centred: **33.77, 49.01, 64.25, 79.49, 94.73**.

Both pitches are candidates. The fit gate still owns them, and no board
coordinate has been changed to match.

## Overdrive

`BIAS` and `DEPTH` both at full with a 10 V modulation give a **gain of two**.
That is intended: it makes the module a drive as well as an amplifier. The
prototype saturates rather than clipping to a corner --

- exactly **linear below 10 V**, which is what keeps the offset and
  scale-and-shift modes reading in volts across the whole knob range;
- a **tanh knee above it**, asymptotic to 11.5 V, continuous in value and slope
  at the join so there is no corner to hear.

11.5 V is a rail-to-rail output stage on ±12 V rails; the OPA2197 already used
in `Block.Precision` swings to within a few hundred millivolts of its rails.
That is what makes the knee 1.5 V wide and no wider: it is the room physics
leaves between an honest linear range and the supply. **A deliberately voiced
soft clipper is a different thing** -- it would lower the linear limit and
colour everything below it too, which is a hardware voicing decision and one
constant (`LINEAR_V`) to change. Neither number is measured.

Both saturations are modelled: a channel's own output, and the sum, which has
its own rails. Four channels at 10 V ask the sum for 40 V.

## The multiplication, and one multiplier per channel

`MOD * DEPTH` is a pot scaling the modulation by -1..+1, and adding `BIAS` is a
summing amplifier. Neither needs a multiplier. So the channel needs **one
four-quadrant multiplier, on the signal path**, not the two that the original
three-way product implied. This matters for
[precision first](../../../AGENTS.md#rules) as much as for the parts count: a
precision pot attenuverter is far better at its job than a Gilbert cell.

## Why pitch CV should not pass through this module

Not a prohibition -- a statement about where the error lands.

V/octave leaves very little room:

| | volts |
|---|---|
| one semitone | 83.3 mV |
| one cent | 0.83 mV |
| a 5-cent tuning budget | 4.2 mV |

A four-quadrant multiplier's total error is specified as a percentage of full
scale, and full scale here is 10 V. At **1% that is 100 mV, about 1.2
semitones**, before any trimming; at 2% it is nearly two and a half semitones.
A pure gain error is gentler but cumulative: 1% costs 12 cents per octave, about
60 cents over five octaves. Offsets and gain errors trim once; their drift with
temperature does not, and the
[visible, persistent controls](../../../AGENTS.md#rules) rule expects a setup to
survive a power cycle and a warm-up.

**The bias structure sharpens the available fix.** The multiplier is only
genuinely needed when *both* jacks are patched; in every other state one of its
operands is a constant. So bypassing it when `MOD` is unpatched would make the
attenuverter and the offset precision-grade, and bypassing it when `SIG` is
unpatched would do the same for scale-and-shift -- which is exactly where
someone would want to transpose a pitch CV. That costs an analog switch per
channel and is **open**: a hardware decision, not a prototype one.

The percentages above are the order of magnitude for this class of part, not
figures read from a datasheet for a chosen one. Selecting the part and deriving
a real budget belongs to the hardware stage.

## Open questions

1. **Is `SUM` a jack or an inter-module bus?** The user's description says the
   sum is "sent to the next module", which may mean a bus rather than a panel
   jack. The panel above assumes a jack. A bus changes the connector standard
   and frees a cell.
2. **The four reserved cells.** Intended for I/O, not yet specified.
3. **Cable-over-knob ergonomics** of the alternating row order, above.
4. **Whether the multiplier bypass is worth its switch**, above.
5. **Relationship to R1.** This is R1's approved mixer behaviour plus CV control
   and bipolar gain, minus the entire consumer-audio interface. Whether this
   replaces R1, sits upstream of it, or is a separate module is undecided.

### Settled on 2026-09-21

- **FINE is gone**; BIAS and DEPTH replace COARSE and FINE. The accepted cost is
  resolution: BIAS alone on a 300° pot gives roughly ±0.1 V by hand, which is
  1.2 semitones, so a precise transpose cannot be dialled in the scale-and-shift
  mode. Accepted knowingly rather than narrowing BIAS's range.
- **Gain above unity is allowed**, and saturates as described above.
- **MOD carries no normal.**

## What the Rack prototype does and does not model

`rack/` builds a VCV Rack plugin; see [SETUP.md](../../SETUP.md#vcv-rack) for the
toolchain and [rack/build.sh](../../../rack/build.sh) for the build. The
transfer function is in `rack/src/QuadAmpDsp.hpp`, apart from the module so it
can be tested without the Rack runtime, which has no headless mode.

**Modelled:** the transfer function, the SIG normal and MOD's lack of one, the
normalled-break mix bus, gain above unity, the saturation curve at both the
channel and sum stages, and the panel grid at true size.

**Not modelled:** every analog property. No multiplier error, offset, drift,
noise, bandwidth or distortion beyond the deliberate saturation; no loading,
protection or power behaviour; no part is chosen. The prototype is ideal
arithmetic in floating point, so it cannot answer any precision question,
including the pitch-CV one above. It is monophonic, as the hardware would be.

Playtesting this answers musical questions only: whether four channels is
enough, whether the scale-and-shift mode gets reached for or forgotten, whether
the overdrive is worth having, and whether the normalled-break bus behaves the
way the instrument wants.
