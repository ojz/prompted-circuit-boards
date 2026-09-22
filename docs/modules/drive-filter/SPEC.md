---
status: "behavior sketched 2026-09-22 from the user's description; VCV Rack prototype built; no circuit, part or layout chosen"
owner: "the user owns musical behavior; the agent owns derivation and evidence"
read_when: "playing or changing the Rack prototype, or resuming hardware for this module"
update_when: "playtesting changes the behavior, an open question below is answered, or hardware work begins"
retire_when: "the module is dropped, or a hardware specification with measured evidence takes over"
---

# Drive Filter

A normalled series processing chain: distortion into a resonant high-pass filter
(HPF) and a resonant low-pass filter (LPF). Described by the user on
2026-09-22 and built as a VCV Rack prototype under
[V0](../../ROADMAP.md#v0-playable-digital-modules-and-function-balance-current).

**This is a musical prototype, not a circuit.** No topology, part, error budget
or layout is chosen. Nothing here is a purchase, fabrication or precision
approval, and the Rack module is ideal arithmetic, not a model of any hardware.

## Behaviour

The module contains three functional stages:
1. **Distortion**: input overdrive with variable gain (1x to 25x), soft tanh
   saturation curve up to an 8.5 V ceiling, CV modulation input, and an output level
   control.
2. **Resonant HPF**: 2-pole (12 dB/oct) high-pass filter with 1 V/Oct cutoff CV
   tracking and variable resonance, reaching self-oscillation at the top of the
   knob. See [Resonance](#resonance) for what that means and what it measured.
3. **Resonant LPF**: the same filter, low-pass.

## Resonance

**Corrected 2026-09-22.** This document, a code comment and a test all claimed
the filter reached "clean self-oscillation". It did not. The damping floor was
`R = 1 - 0.98 * res`, so R bottomed out at +0.02 and the filter was always
stable: at full resonance an impulse decayed to nothing in about 80 ms. The test
that was supposed to cover it measured only that the output stayed finite, which
a filter decaying to zero also does, so it passed throughout.

The fix is one constant. The damping now travels past zero
(`R = 1 - RES_SPAN * res`, `RES_SPAN = 1.10`), which is safe only because the
resonance feedback is saturated: the tanh bounds the limit cycle that negative
damping would otherwise grow without limit.

`RES_SPAN` was chosen from a sweep at 1 kHz, measuring the sustained amplitude
0.75 s after an impulse. The knob position where damping crosses zero is
`1 / RES_SPAN`, so the same number sets both how much of the travel oscillates
and how loud it gets:

| RES_SPAN | oscillates over | amplitude at full |
|---|---|---|
| 1.02 | top 2.0% | 0.51 V |
| **1.10** | **top 9.1%** | **1.14 V** |
| 1.20 | top 16.7% | 1.62 V |
| 1.40 | top 28.6% | 2.36 V |

1.10 keeps nine tenths of the knob as ordinary resonance while still reaching a
clean sine. If that sliver proves too narrow to find in play, 1.20 is the next
stop. The amplitude is set by the feedback saturation constant (`RES_SAT_V`),
not by the span, so that is the separate lever if it should be louder.

This matters beyond tidiness: [ROADMAP.md](../../ROADMAP.md) states the
instrument hypothesis as "Serge-style: the slope and filter can be oscillators".
As first built, this filter could not be one.

**Not verified:** none of these numbers is measured against hardware, and no
circuit is proposed. 1.14 V is also quiet next to a typical 5 V signal; whether
the self-oscillation is loud and findable enough is a playtest question.

### Cutoff range

The knob spans five octaves either side of middle C, so **-5 V is 8.2 Hz**
(raised to the module's 10 Hz floor) and **+5 V is 8.4 kHz**. Earlier comments
in the source and tests said 16 Hz and 16 kHz; both were an octave out and have
been corrected.

### Normalled Signal Flow

```
[DIST IN] --> [ Distortion ] --> [DIST OUT]
                                       | (normalled)
                                       v
[ HPF IN] ---------------------> [ Resonant HPF ] --> [HPF OUT]
                                                            | (normalled)
                                                            v
[ LPF IN] ------------------------------------------> [ Resonant LPF ] --> [LPF OUT]
```

- When `HPF IN` is **unpatched**, it automatically receives the output of the
  `Distortion` stage.
- When `LPF IN` is **unpatched**, it automatically receives the output of the
  `Resonant HPF` stage.
- Plugging a cable into `HPF IN` breaks the normal from distortion, allowing the
  filters to process an external signal while the distortion remains usable on its
  own.
- Plugging a cable into `LPF IN` breaks the normal from the HPF, allowing all
  three stages to operate completely independently on separate audio signals.
- `DIST OUT` and `HPF OUT` remain live tap points at all times, whether the
  normals are broken or not.

### What the normals buy

| Patching state | Resulting behaviour |
|---|---|
| In at `DIST IN`, out from `LPF OUT` | **Full serial chain**: Overdrive / distortion shaped by resonant bandpass response (stripping sub-mud and harsh fizzy highs, or dual-peak formant shaping). |
| In at `DIST IN`, out from `HPF OUT` | **Distortion + HPF**: High-frequency harmonic excitement or sharp bass-cut lead drive. |
| In at `HPF IN`, out from `LPF OUT` | **Clean Dual Filter**: Breaks distortion normal; acts as a clean 12 dB/oct bandpass filter with independent low and high resonance and cutoffs. |
| All three inputs patched | **Three independent processors**: Standalone distortion, standalone HPF, and standalone LPF operating concurrently on three separate voices. |

## Panel

Three columns by five rows, which the [five-row rule](../../../AGENTS.md#rules)
and the column count together fix at **10 HP** (50.5 mm width, 128.5 mm height,
Doepfer 3U). The row centres line up exactly with [Quad Amp](../quad-amp/SPEC.md)
on the candidate 15.24 mm row pitch and 15.0 mm column pitch.

| | Col 0: DIST | Col 1: HPF | Col 2: LPF |
|---|---|---|---|
| Row 0 | **DIST IN** | **HPF IN** *(normalled to DIST OUT)* | **LPF IN** *(normalled to HPF OUT)* |
| Row 1 | **DRIVE** (knob) | **FREQ** (knob) | **FREQ** (knob) |
| Row 2 | **DRIVE CV** (jack) | **HPF CV** (1 V/Oct jack) | **LPF CV** (1 V/Oct jack) |
| Row 3 | **LEVEL** (knob) | **RES** (knob) | **RES** (knob) |
| Row 4 | **DIST OUT** | **HPF OUT** | **LPF OUT** |

## Transfer Functions (Ideal DSP)

- **Distortion**:
  $$\text{gain} = \max(0.1, 1.0 + 2.4 \times V_{\text{drive}} + 2.0 \times V_{\text{cv}})$$
  $$V_{\text{driven}} = V_{\text{in}} \times \text{gain}$$
  $$V_{\text{dist}} = (V_{\text{level}} / 10) \times \text{saturate}(V_{\text{driven}}, 4.0, 8.5)$$
  where $\text{saturate}(v)$ is exactly linear below 4.0 V and transitions smoothly
  via a $\tanh$ knee onto an 8.5 V ceiling with $C^1$ continuity.
- **Filters**:
  Topology-Preserving Transform (TPT) 2-pole State Variable Filters.
  Cutoff frequency tracks 1 V/Oct:
  $$f_c = 261.626 \times 2^{V_{\text{knob}} + V_{\text{cv}}}$$
  Resonance damping factor $R = 1.0 - 0.98 \times (V_{\text{res}} / 10)$.
  Resonance feedback incorporates soft $\tanh$ saturation to bound oscillation
  within $\pm 5\text{ V}$.
