// The Quad Amp transfer function, with no dependency on Rack.
//
// It lives apart from QuadAmp.cpp so it can be tested without the Rack
// runtime, which has no headless mode: rack/tests/dsp_test.cpp compiles this
// header on its own and checks the four patch states, unity gain, the
// normalled break and both saturation points. The module calls these
// functions rather than repeating the arithmetic, so the tested behaviour and
// the played behaviour cannot drift apart.
//
// Everything here is ideal. See docs/modules/quad-amp/SPEC.md, "What this
// prototype does not model": no multiplier error, offset, drift or noise.
#pragma once

namespace quadamp {

/** The voltage an empty SIG or CV jack is normalled to, and the multiplier's
full-scale reference. */
const float NORMAL_V = 10.f;

/** Two cascaded four-quadrant multiplications, each scaled by the reference.
This is what puts unity gain at COARSE = +10 V with CV normalled, and what
makes the knob read in volts with nothing patched at all. */
const float SCALE = NORMAL_V * NORMAL_V;

/** Where the hardware would saturate: a stand-in for op-amp output swing on
+/-12 V rails, not a measured limit. It is modelled so the headroom question
(four channels at 10 V is 40 V of sum) is audible rather than deferred. */
const float CLIP_V = 11.f;

const int CHANNELS = 4;

inline float clip(float v) {
	if (v < -CLIP_V)
		return -CLIP_V;
	if (v > CLIP_V)
		return CLIP_V;
	return v;
}

/** One channel: OUT = SIG * CV * (COARSE + FINE) / 100, with an unpatched
input standing in at the normal. `sig` and `cv` are ignored when their
respective jack is not patched. */
inline float channelOut(bool sigPatched, float sig,
                        bool cvPatched, float cv,
                        float coarse, float fine) {
	float s = sigPatched ? sig : NORMAL_V;
	float c = cvPatched ? cv : NORMAL_V;
	return clip(s * c * (coarse + fine) / SCALE);
}

/** The mix bus: the channels whose own output jack is empty, summed and
saturated at the sum stage's own rails. `outPatched[i]` is whether channel i's
individual output has a plug in it. */
inline float mix(const float* out, const bool* outPatched) {
	float sum = 0.f;
	for (int c = 0; c < CHANNELS; c++) {
		if (!outPatched[c])
			sum += out[c];
	}
	return clip(sum);
}

} // namespace quadamp
