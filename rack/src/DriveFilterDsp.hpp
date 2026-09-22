// The Drive Filter transfer function, with no dependency on Rack.
//
// It lives apart from DriveFilter.cpp so it can be tested without the Rack
// runtime, which has no headless mode: rack/tests/dsp_test.cpp compiles this
// header on its own and checks the distortion curve, filter responses,
// resonance saturation and normalled break logic.
//
// Signal flow:
//     Distortion -> Resonant HPF -> Resonant LPF
//
// Normalling:
//     - HPF IN is normalled to Distortion OUT when unpatched.
//     - LPF IN is normalled to HPF OUT when unpatched.
//     - Inserting a plug into HPF IN or LPF IN breaks that normal.
//     - Distortion OUT and HPF OUT remain available as individual tap points.
//
// Filters are 2-pole (12 dB/oct) Topology-Preserving Transform (TPT) State
// Variable Filters. The resonance feedback is saturated, which is what lets
// the damping go slightly negative at the top of the knob: the filter sustains
// a bounded limit cycle -- self-oscillation -- instead of either ringing down
// or growing without limit.
#pragma once

#include "Saturate.hpp"

#include <cmath>
#include <algorithm>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

namespace drivefilter {

const float BASE_FREQ_HZ = 261.626f; // Middle C (C4), the frequency at 0 V

/** How far the damping travels as resonance opens. Greater than 1 so the top
of the knob reaches negative damping and the filter sustains; the saturated
feedback below is what keeps that bounded.

Chosen from a sweep at 1 kHz, measuring the sustained amplitude 0.75 s after an
impulse. The knob position where damping crosses zero is 1/RES_SPAN, so the
span decides both how much of the travel oscillates and how loud it gets:

    span   oscillates over   amplitude at full
    1.02   top 2.0%          0.51 V
    1.10   top 9.1%          1.14 V
    1.20   top 16.7%         1.62 V
    1.40   top 28.6%         2.36 V

1.10 keeps nine tenths of the knob as ordinary resonance while still reaching a
clean sine. If the oscillating sliver proves too narrow to find in play, 1.20 is
the next stop. The amplitude is set by the feedback saturation constant below,
not by this, so that is the separate lever if it wants to be louder. */
const float RES_SPAN = 1.10f;
/** Where the resonance feedback saturates, and so the scale of the
self-oscillation limit cycle. Not measured. */
const float RES_SAT_V = 5.0f;

const float LINEAR_V = 4.0f;
const float CEILING_V = 8.5f;

/** The shared curve in Saturate.hpp, at this module's two constants. */
inline float saturate(float v, float linearV = LINEAR_V, float ceilingV = CEILING_V) {
	return sat::soft(v, linearV, ceilingV);
}

/** Distortion stage: calculates distorted output from input, drive, and level.
    driveParam: 0.0 to 10.0 V (maps to 1.0x to 25.0x gain)
    driveCv: bipolar CV (1.0 V adds ~2.0x gain)
    levelParam: 0.0 to 10.0 V (0.0 to 1.0x output attenuator; 10 V is unity)
*/
inline float processDistortion(float in, float driveParam, float driveCv, float levelParam) {
	float driveFactor = 1.0f + 2.4f * driveParam + 2.0f * driveCv;
	if (driveFactor < 0.1f)
		driveFactor = 0.1f;

	float levelFactor = std::max(0.0f, levelParam * 0.1f);
	float driven = in * driveFactor;
	return levelFactor * saturate(driven, LINEAR_V, CEILING_V);
}

/** Frequency from 1 V/Oct CV and knob offset. The knob spans five octaves
    either side of middle C, so -5 V is 8.2 Hz (raised to the 10 Hz floor) and
    +5 V is 8.4 kHz -- not the 16 Hz and 16 kHz an earlier comment claimed.
    knobVolts: -5.0 to +5.0 V
    cvVolts: standard 1 V/Oct pitch CV
    Returns frequency in Hz, clamped to [10 Hz, 0.45 * sampleRate].
*/
inline float cvToFrequency(float knobVolts, float cvVolts, float sampleRate) {
	float totalVolts = knobVolts + cvVolts;
	float freq = BASE_FREQ_HZ * std::pow(2.0f, totalVolts);
	float maxFreq = 0.45f * sampleRate;
	if (freq < 10.0f) freq = 10.0f;
	if (freq > maxFreq) freq = maxFreq;
	return freq;
}

/** 2-pole TPT State Variable Filter */
struct SvfFilter {
	float s1 = 0.f;
	float s2 = 0.f;

	void reset() {
		s1 = 0.f;
		s2 = 0.f;
	}

	void process(float in, float freqHz, float resParam, float sampleRate,
	             float& lpOut, float& hpOut, float& bpOut) {
		float g = std::tan(float(M_PI) * freqHz / sampleRate);
		// resParam: 0.0 to 10.0 V -> resNorm: 0.0 to 1.0
		float resNorm = std::max(0.0f, std::min(1.0f, resParam * 0.1f));
		// Damping R, from 1.0 (well damped) through 0 (marginal) to slightly
		// negative at the top of the knob, which is what sustains instead of
		// ringing down. It is safe to go past zero only because the resonance
		// feedback below is saturated: the tanh bounds the limit cycle that
		// negative damping would otherwise grow without limit. A floor of
		// +0.02 was the previous value and could not self-oscillate at all --
		// it decayed to nothing in about 80 ms -- while three places claimed
		// it could. docs/ROADMAP.md wants the filter usable as an oscillator.
		float R = 1.0f - RES_SPAN * resNorm;

		float h = 1.0f / (1.0f + 2.0f * R * g + g * g);
		float hp = (in - (2.0f * R + g) * s1 - s2) * h;
		float bp = g * hp + s1;

		// Saturated resonance feedback. This is what bounds the limit cycle once
		// R goes negative, so it is also what sets how loud self-oscillation is.
		float bpSat = RES_SAT_V * std::tanh(bp / RES_SAT_V);
		float lp = g * bpSat + s2;

		s1 = 2.0f * bpSat - s1;
		s2 = 2.0f * lp - s2;

		// Anti-denormal / NaN protection
		if (std::isnan(s1) || std::isinf(s1)) s1 = 0.f;
		if (std::isnan(s2) || std::isinf(s2)) s2 = 0.f;

		lpOut = lp;
		hpOut = hp;
		bpOut = bp;
	}
};

/** Full module processing logic, resolving normals. */
struct DriveFilterProcessor {
	SvfFilter hpf;
	SvfFilter lpf;

	void reset() {
		hpf.reset();
		lpf.reset();
	}

	void step(
		bool distInPatched, float distIn,
		float driveParam, float driveCv, float levelParam,
		bool hpfInPatched, float hpfInCustom,
		float hpfFreqKnob, float hpfCv, float hpfResKnob,
		bool lpfInPatched, float lpfInCustom,
		float lpfFreqKnob, float lpfCv, float lpfResKnob,
		float sampleRate,
		float& distOut, float& hpfOut, float& lpfOut
	) {
		// 1. Distortion
		float dIn = distInPatched ? distIn : 0.0f;
		distOut = processDistortion(dIn, driveParam, driveCv, levelParam);

		// 2. HPF input: normalled to distOut if unpatched
		float hIn = hpfInPatched ? hpfInCustom : distOut;
		float hFreq = cvToFrequency(hpfFreqKnob, hpfCv, sampleRate);
		float dummyLp, dummyBp;
		hpf.process(hIn, hFreq, hpfResKnob, sampleRate, dummyLp, hpfOut, dummyBp);

		// 3. LPF input: normalled to hpfOut if unpatched
		float lIn = lpfInPatched ? lpfInCustom : hpfOut;
		float lFreq = cvToFrequency(lpfFreqKnob, lpfCv, sampleRate);
		float dummyHp;
		lpf.process(lIn, lFreq, lpfResKnob, sampleRate, lpfOut, dummyHp, dummyBp);
	}
};

} // namespace drivefilter
