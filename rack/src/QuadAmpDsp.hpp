// The Quad Amp transfer function, with no dependency on Rack.
//
// It lives apart from QuadAmp.cpp so it can be tested without the Rack
// runtime, which has no headless mode: rack/tests/dsp_test.cpp compiles this
// header on its own and checks the four patch states, unity gain, the
// normalled break and the saturation curve. The module calls these functions
// rather than repeating the arithmetic, so the tested behaviour and the played
// behaviour cannot drift apart.
//
// One channel, revised 2026-09-21 from a level knob and a level trim to an
// initial gain plus an attenuverted modulation:
//
//     gain = (BIAS + MOD * DEPTH / 10) / 10
//     OUT  = saturate(SIG * gain)
//
// The bias is what makes it a VCA rather than a multiplier. With the previous
// arrangement a patched CV at zero volts meant silence and nothing could be
// done about it, so a channel could never sit half open with modulation on
// top -- which is what a VCA is for most of the time.
//
// Everything here is ideal. See docs/modules/quad-amp/SPEC.md, "What this
// prototype does not model": no multiplier error, offset, drift or noise.
#pragma once

#include "Saturate.hpp"

namespace quadamp {

/** The voltage an empty SIG jack is normalled to. This is what makes a channel
with nothing patched into it a DC offset whose dial reads in volts, and a
channel with only MOD patched a scale-and-shift utility.

MOD deliberately has no normal: an unpatched MOD jack is 0 V, so DEPTH visibly
does nothing without a cable rather than quietly becoming a second level knob. */
const float SIG_NORMAL_V = 10.f;

/** Knob full scale. Both BIAS and DEPTH span +/-FULL_SCALE and read in volts;
unity gain falls at BIAS = +10 V, and again at DEPTH = +10 V with a 10 V
modulation. */
const float FULL_SCALE = 10.f;

/** Saturation. Below LINEAR_V the channel is exactly linear, which is what
keeps the offset and scale-and-shift modes reading in volts across the whole
knob range. Above it the curve is a tanh knee onto CEILING_V.

CEILING_V is a rail-to-rail output stage on +/-12 V rails (the OPA2197 already
used in Block.Precision swings to within a few hundred millivolts of its
rails). That is what makes the knee 1.5 V wide and no wider: it is the room
physics leaves between an honest linear range and the supply. A deliberately
voiced soft clipper would lower LINEAR_V and colour everything below it too;
that is a hardware voicing decision, and this is the one constant to change
for it. Neither number is measured. */
const float LINEAR_V = 10.f;
const float CEILING_V = 11.5f;

const int CHANNELS = 4;

/** The shared curve in Saturate.hpp, at this module's two constants. */
inline float saturate(float v) {
	return sat::soft(v, LINEAR_V, CEILING_V);
}

/** The gain a channel is set to, before the signal is applied. Can exceed
unity -- BIAS and DEPTH both at full with a 10 V modulation give a gain of two,
which is the intended overdrive and is what the saturation above is for. */
inline float gain(float bias, float mod, float depth) {
	return (bias + mod * depth / FULL_SCALE) / FULL_SCALE;
}

/** One channel. `mod` is the MOD jack's voltage, already 0 when unpatched;
`sig` is ignored and the normal used when SIG is unpatched. */
inline float channelOut(bool sigPatched, float sig, float mod,
                        float bias, float depth) {
	float s = sigPatched ? sig : SIG_NORMAL_V;
	return saturate(s * gain(bias, mod, depth));
}

/** The mix bus: the channels whose own output jack is empty, summed and
saturated by the sum stage, which has its own rails and so saturates
independently of the channels feeding it. `outPatched[i]` is whether channel
i's individual output has a plug in it. */
inline float mix(const float* out, const bool* outPatched) {
	float sum = 0.f;
	for (int c = 0; c < CHANNELS; c++) {
		if (!outPatched[c])
			sum += out[c];
	}
	return saturate(sum);
}

} // namespace quadamp
