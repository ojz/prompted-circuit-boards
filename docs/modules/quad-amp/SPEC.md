---
status: "behavior sketched 2026-09-21 from the user's description; VCV Rack prototype built; no circuit, part or layout chosen"
owner: "the user owns musical behavior; the agent owns derivation and evidence"
read_when: "playing or changing the Rack prototype, or resuming hardware for this module"
update_when: "playtesting changes the behavior, an open question below is answered, or hardware work begins"
retire_when: "the module is dropped, or a hardware specification with measured evidence takes over"
---

# Quad Amp

Four four-quadrant amplifier channels on a normalled mix bus. Described by the
user on 2026-09-21 and built as a VCV Rack module the same day under
[V0](../../ROADMAP.md#v0-playable-digital-modules-and-function-balance-current).

**This is a musical prototype, not a circuit.** No topology, part, error budget
or layout is chosen. Nothing here is a purchase, fabrication or precision
approval, and the Rack module is ideal arithmetic, not a model of any hardware.

## Behaviour

Each of the four channels:

```
SIG OUT = SIG IN * AMP CV * (COARSE + FINE) / 100
```

- `SIG IN` and `AMP CV` are each **normalled to +10 V** when nothing is patched.
- `COARSE` spans -10 V to +10 V, `FINE` spans -1 V to +1 V, and both read in volts.
- The `/100` is two four-quadrant multiplier scalings of ten volts each.

`SUM` carries the sum of the channels whose own `SIG OUT` is **unpatched**.
Patching a channel's output removes that channel from `SUM` and does nothing
else: the channel keeps working, and unpatching restores it. This is the same
normalled-break rule already approved for [R1](../io-mixer/SPEC.md).

### What the normals buy

The 10 V normals and the `/100` scaling are what make the arithmetic land
where it should, and they are why one circuit covers four jobs:

| SIG IN | AMP CV | The channel is | Because |
|---|---|---|---|
| patched | patched | a VCA, or a ring modulator | full four-quadrant product; negative gain inverts |
| patched | open | an attenuverter | `OUT = SIG * COARSE/10`, unity at full knob |
| open | patched | a CV-controlled DC source | knob sets depth and polarity |
| open | open | a DC offset | `OUT = COARSE + FINE`, the dial reads in volts |

With four channels summing, it is also a four-input mixer and a four-input CV
adder. That breadth is the point of the module, not a side effect.

## Panel

Five columns by five rows, which the [five-row rule](../../../AGENTS.md#rules)
and the column count together fix at **16 HP**. Columns one to four are the
channels; the fifth column holds `SUM` at the bottom and **four cells reserved
for I/O not yet decided**.

| | col 1 | col 2 | col 3 | col 4 | col 5 |
|---|---|---|---|---|---|
| row 1 | SIG IN | SIG IN | SIG IN | SIG IN | *reserved* |
| row 2 | AMP CV | AMP CV | AMP CV | AMP CV | *reserved* |
| row 3 | COARSE | COARSE | COARSE | COARSE | *reserved* |
| row 4 | FINE | FINE | FINE | FINE | *reserved* |
| row 5 | SIG OUT | SIG OUT | SIG OUT | SIG OUT | **SUM** |

Control centres, in millimetres from the panel's top-left corner, viewed from
the front. Derived in [MECHANICAL.md](../../MECHANICAL.md#grid-and-fit-gate) and
implemented in `rack/src/QuadAmp.cpp`, which uses these same numbers so the
prototype previews the real panel rather than an arbitrary one:

- Panel 80.90 mm wide (Doepfer 16 HP) by 128.50 mm.
- Columns at 15.00 mm pitch, centred: **10.45, 25.45, 40.45, 55.45, 70.45**.
- Rows at 15.24 mm pitch (three nominal HP), centred: **33.77, 49.01, 64.25, 79.49, 94.73**.

Both pitches are candidates. The fit gate in MECHANICAL.md still owns them, and
no board coordinate has been changed to match.

## The multiplication regroups

As described, the channel is two cascaded multiplications, which would need
eight four-quadrant multipliers. It regroups:

```
SIG * CV * (COARSE + FINE)  ==  SIG * [ CV * (COARSE + FINE) ]
```

The bracketed term is a pot scaling `CV` by -1..+1 -- an attenuverter, one pot
and one op-amp. So the module needs **one multiplier and one attenuverter per
channel, not two multipliers**. The transfer function is identical; only the
association changes. This matters for [precision first](../../../AGENTS.md#rules):
a precision pot attenuverter is far better at this job than a Gilbert cell, so
regrouping removes a whole multiplication from the error budget as well as four
parts from the board.

Consequence worth recording: the attenuverter then sits on the **CV** path and
the multiplier on the **signal** path.

## Why pitch CV should not pass through this module

Not a prohibition on the idea -- a statement about where the error lands.

V/octave leaves very little room. One octave is one volt, so:

| | volts |
|---|---|
| one semitone | 83.3 mV |
| one cent | 0.83 mV |
| a 5-cent tuning budget | 4.2 mV |

A four-quadrant multiplier's total error is specified as a percentage of full
scale, and full scale here is 10 V. At **1% that is 100 mV, about 1.2
semitones**, before any trimming; at 2% it is nearly two and a half semitones.
A pure *gain* error is gentler but still cumulative: 1% costs 12 cents per
octave, so about 60 cents at the top of a five-octave run. Offsets and gain
errors can be trimmed once; their drift with temperature cannot, and the
[visible, persistent controls](../../../AGENTS.md#rules) rule expects the setup
to survive a power cycle and a warm-up.

So the boundary is:

- **Any path through the multiplier is an amplitude path.** 1% is inaudible on
  a VCA and disqualifying on pitch.
- **A path that avoids the multiplier can be precision-grade.** Because the
  regrouping puts the multiplier on the signal path, a channel whose `AMP CV`
  is unpatched is doing nothing a multiplier is needed for. Bypassing it in
  that state would make the attenuverter and offset modes accurate enough for
  pitch, at the cost of an analog switch per channel. Whether that is worth it
  depends on whether transposing and summing pitch CV is something the
  instrument should do here or in a dedicated module.

That choice is **open**, and it is a hardware decision, not a prototype one.
The percentages above are the order of magnitude for this class of part, not
figures read off a datasheet for a chosen one; selecting the part and deriving
a real budget belongs to the hardware stage.

## Open questions

1. **Is `SUM` a jack or an inter-module bus?** The user's description says the
   sum is "sent to the next module", which may mean a bus rather than a panel
   jack. The panel above assumes a jack. A bus changes the connector standard
   and frees a cell.
2. **The four reserved cells.** Intended for I/O, not yet specified.
3. **Summing headroom.** Four channels at 10 V is 40 V into supply rails that
   cannot deliver it. Unity-sum and clip, or scale the sum? The prototype hard
   clips at +/-11 V so the question is audible; that number is a stand-in, not
   a measured limit. Same open item as [R1](../io-mixer/SPEC.md) design work item 3.
4. **`COARSE + FINE` reaches +/-11 V**, outside the stated +/-10 V range. Is the
   overshoot intended, or should FINE trim within the coarse range?
5. **Relationship to R1.** This is R1's approved mixer behaviour plus CV control
   and bipolar gain, minus the entire consumer-audio interface. Whether this
   replaces R1, sits upstream of it, or is a separate module is undecided.

## What the Rack prototype does and does not model

`rack/` builds a VCV Rack plugin; see [SETUP.md](../../SETUP.md#vcv-rack) for the
toolchain and [rack/build.sh](../../../rack/build.sh) for the build.

**Modelled:** the transfer function, both normals, the normalled-break mix bus,
the panel grid at true size, and saturation at the output and sum stages.

**Not modelled:** every analog property. No multiplier error, offset, drift,
noise, bandwidth or distortion; no loading, protection or power behaviour; no
part is chosen. The prototype is ideal arithmetic in floating point, so it
cannot answer any precision question, including the pitch-CV one above. It is
monophonic, as the hardware would be.

Playtesting this answers musical questions only: whether four channels is
enough, whether FINE earns its grid cell, whether the offset mode gets used,
and whether the normalled-break bus behaves the way the instrument wants.
