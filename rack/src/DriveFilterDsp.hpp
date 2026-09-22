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
// Variable Filters with soft-saturating resonance feedback to ring smoothly
// into self-oscillation without digital runaway.
#pragma once

#include <cmath>
#include <algorithm>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

namespace drivefilter {

const float BASE_FREQ_HZ = 261.626f; // Middle C (C4)
const float LINEAR_V = 4.0f;
const float CEILING_V = 8.5f;

/** Soft saturation curve: exact linear below LINEAR_V, smooth tanh knee onto CEILING_V.
    Continuous in value and slope at the join. */
inline float saturate(float v, float linearV = LINEAR_V, float ceilingV = CEILING_V) {
	float a = v < 0.f ? -v : v;
	if (a <= linearV)
		return v;
	const float knee = ceilingV - linearV;
	float out = linearV + knee * std::tanh((a - linearV) / knee);
	return v < 0.f ? -out : out;
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

/** Frequency from 1 V/Oct CV and knob offset.
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
		// Damping factor R: 1.0 (critically damped) down to 0.02 (self-oscillation)
		float R = 1.0f - 0.98f * resNorm;

		float h = 1.0f / (1.0f + 2.0f * R * g + g * g);
		float hp = (in - (2.0f * R + g) * s1 - s2) * h;
		float bp = g * hp + s1;

		// Soft saturation in resonance feedback prevents blowup at high Q
		float bpSat = 5.0f * std::tanh(bp / 5.0f);
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
