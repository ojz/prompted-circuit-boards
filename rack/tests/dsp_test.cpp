// Behaviour tests for the Quad Amp and Drive Filter transfer functions.
//
// Rack Free has no headless mode, so the played module cannot be driven from a
// script. This compiles the DSP headers on their own instead and checks the
// behaviour the specifications claim -- unity gain, normalled breaks,
// saturation curves and filter stability. The modules call the same functions,
// so these cannot drift apart.
//
// Built and run by rack/build.sh before the plugin is packaged.
#include "../src/QuadAmpDsp.hpp"
#include "../src/DriveFilterDsp.hpp"

#include <cstdio>
#include <cmath>

using namespace quadamp;

static int failures = 0;
static int checks = 0;

static void eq(const char* what, float got, float want) {
	checks++;
	if (std::fabs(got - want) > 1e-3f) {
		std::printf("FAIL  %s: got %.6f, expected %.6f\n", what, got, want);
		failures++;
	}
	else {
		std::printf("ok    %-58s %8.3f V\n", what, got);
	}
}

static void greater(const char* what, float got, float least) {
	checks++;
	if (!(got > least)) {
		std::printf("FAIL  %s: got %.6f, expected more than %.6f\n", what, got, least);
		failures++;
	}
	else {
		std::printf("ok    %-58s %8.3f V\n", what, got);
	}
}

/* Shorthands. MOD is 0 V when unpatched; there is no normal on it. */
static float nothing(float bias) {
	return channelOut(false, 0.f, 0.f, bias, 0.f);
}
static float sigOnly(float sig, float bias) {
	return channelOut(true, sig, 0.f, bias, 0.f);
}
static float modOnly(float mod, float bias, float depth) {
	return channelOut(false, 0.f, mod, bias, depth);
}
static float both(float sig, float mod, float bias, float depth) {
	return channelOut(true, sig, mod, bias, depth);
}

int main() {
	std::printf("Quad Amp transfer function\n\n");

	std::printf("-- nothing patched: a DC offset, the dial reading in volts --\n");
	eq("bias +5.0", nothing(5.f), 5.f);
	eq("bias -5.0", nothing(-5.f), -5.f);
	eq("bias  0.0 is silent", nothing(0.f), 0.f);
	eq("bias at full scale is still exact", nothing(10.f), 10.f);

	std::printf("\n-- signal patched, mod open: an attenuverter --\n");
	eq("unity at full bias", sigOnly(5.f, 10.f), 5.f);
	eq("inverting at full negative bias", sigOnly(5.f, -10.f), -5.f);
	eq("half at half bias", sigOnly(5.f, 5.f), 2.5f);
	eq("silent at zero bias", sigOnly(5.f, 0.f), 0.f);
	eq("depth does nothing with no cable in MOD",
	   channelOut(true, 5.f, 0.f, 5.f, 10.f), 2.5f);

	std::printf("\n-- signal open, mod patched: offset plus attenuverted CV --\n");
	eq("bias 2 V, 4 V mod at full depth, shifts and scales", modOnly(4.f, 2.f, 10.f), 6.f);
	eq("half depth halves the mod, not the offset", modOnly(4.f, 2.f, 5.f), 4.f);
	eq("negative depth inverts the mod only", modOnly(4.f, 2.f, -10.f), -2.f);

	std::printf("\n-- both patched: a VCA with a base level --\n");
	eq("bias alone with the mod at rest", both(5.f, 0.f, 5.f, 10.f), 2.5f);
	eq("mod at 10 V opens it the rest of the way", both(5.f, 10.f, 5.f, 5.f), 5.f);
	eq("this is what the old design could not do: never silent at CV 0",
	   both(5.f, 0.f, 10.f, 10.f), 5.f);
	eq("zero bias and full depth is a plain VCA", both(5.f, 10.f, 0.f, 10.f), 5.f);
	eq("and a ring modulator on negative mod", both(5.f, -10.f, 0.f, 10.f), -5.f);

	std::printf("\n-- gain above unity, which is the point of the overdrive --\n");
	eq("bias and mod both full give a gain of two", gain(10.f, 10.f, 10.f), 2.f);
	eq("a 5 V signal at gain two is still inside the linear range",
	   both(5.f, 10.f, 10.f, 10.f), 10.f);

	std::printf("\n-- saturation: linear to %.0f V, tanh knee onto %.1f V --\n",
	            LINEAR_V, CEILING_V);
	eq("exact just below the knee", saturate(9.999f), 9.999f);
	eq("exact at the knee", saturate(LINEAR_V), LINEAR_V);
	greater("just above the knee it compresses", saturate(11.f), LINEAR_V);
	eq("and by the expected amount", saturate(11.f),
	   LINEAR_V + (CEILING_V - LINEAR_V) * std::tanh(1.f / (CEILING_V - LINEAR_V)));
	eq("hard overdrive approaches the ceiling", saturate(40.f), CEILING_V);
	eq("symmetrically", saturate(-40.f), -CEILING_V);
	{
		// No corner to hear: the slope either side of the join must match.
		float d = 1e-3f;
		float below = (saturate(LINEAR_V - d) - saturate(LINEAR_V - 2 * d)) / d;
		float above = (saturate(LINEAR_V + 2 * d) - saturate(LINEAR_V + d)) / d;
		checks++;
		if (std::fabs(below - above) > 5e-3f) {
			std::printf("FAIL  slope is discontinuous at the knee: %.6f vs %.6f\n", below, above);
			failures++;
		}
		else {
			std::printf("ok    %-58s %8.3f\n", "slope is continuous across the knee", above);
		}
	}

	std::printf("\n-- the mix bus --\n");
	{
		float out[CHANNELS] = {1.f, 2.f, 3.f, 4.f};
		bool none[CHANNELS] = {false, false, false, false};
		eq("nothing patched out: all four sum, exactly", mix(out, none), 10.f);

		bool third[CHANNELS] = {false, false, true, false};
		eq("patching channel 3 removes only its 3 V", mix(out, third), 7.f);

		bool all[CHANNELS] = {true, true, true, true};
		eq("patching every output leaves the bus silent", mix(out, all), 0.f);

		// The headroom question from docs/modules/io-mixer/SPEC.md item 3.
		float loud[CHANNELS] = {10.f, 10.f, 10.f, 10.f};
		eq("four channels at 10 V want 40 V and are saturated instead",
		   mix(loud, none), CEILING_V);
	}

	std::printf("\nDrive Filter transfer function and normalled routing\n\n");
	{
		using namespace drivefilter;

		DriveFilterProcessor proc;
		const float sr = 48000.f;

		std::printf("-- distortion stage --\n");
		float d0 = processDistortion(0.f, 0.f, 0.f, 10.0f);
		eq("zero input gives zero distortion out", d0, 0.f);

		// Clean input (small signal, drive at 0, level at unity 10.0 V)
		float dClean = processDistortion(1.0f, 0.f, 0.f, 10.0f);
		eq("clean small signal at unity level is 1.0 V", dClean, 1.0f);

		// High drive pushes into saturation ceiling (below 8.5 V)
		float dHot = processDistortion(5.0f, 10.f, 0.f, 10.0f);
		greater("high drive boosts signal above linear 5 V", dHot, 7.5f);
		checks++;
		if (dHot < 8.51f) {
			std::printf("ok    %-58s %8.3f V\n", "high drive saturates smoothly under ceiling", dHot);
		} else {
			std::printf("FAIL  high drive exceeded expected ceiling: %.3f V\n", dHot);
			failures++;
		}

		// Positive CV increases drive
		float dCv = processDistortion(1.0f, 0.f, 2.0f, 10.0f);
		greater("drive CV increases gain", dCv, dClean);

		std::printf("\n-- normalled chain: DIST -> HPF -> LPF --\n");
		float distOut = 0.f, hpfOut = 0.f, lpfOut = 0.f;
		proc.reset();
		// Feed a 200 Hz sine wave through the normalled chain
		// HPF open (-5 V ~16 Hz), LPF open (+5 V ~16 kHz), clean drive (0 V, level unity)
		float maxLpf = 0.f;
		for (int i = 0; i < 480; i++) {
			float in = 2.0f * std::sin(2.0f * float(M_PI) * 200.f * i / sr);
			proc.step(
				true, in, 0.f, 0.f, 10.0f, // dist
				false, 0.f, -5.f, 0.f, 0.f, // hpf unpatched (normalled from distOut)
				false, 0.f, 5.f, 0.f, 0.f,  // lpf unpatched (normalled from hpfOut)
				sr, distOut, hpfOut, lpfOut
			);
			if (std::fabs(lpfOut) > maxLpf) maxLpf = std::fabs(lpfOut);
		}
		greater("normalled chain passes audio from DIST IN to LPF OUT", maxLpf, 1.8f);

		std::printf("\n-- normalled breaks --\n");
		proc.reset();
		// Break HPF normal by patching HPF IN with silence (0 V) while DIST IN has 5 V
		proc.step(
			true, 5.0f, 0.f, 0.f, 10.0f,
			true, 0.0f, -5.f, 0.f, 0.f, // HPF patched with 0 V!
			false, 0.f, 5.f, 0.f, 0.f,  // LPF normalled to HPF OUT
			sr, distOut, hpfOut, lpfOut
		);
		greater("distOut still active when HPF IN is patched", distOut, 4.0f);
		eq("patching HPF IN with 0 V silences HPF OUT", hpfOut, 0.f);
		eq("and LPF OUT follows silenced HPF OUT", lpfOut, 0.f);

		// Break LPF normal by patching LPF IN with silence (0 V) while HPF OUT has audio
		proc.reset();
		proc.step(
			true, 5.0f, 0.f, 0.f, 10.0f,
			false, 0.0f, -5.f, 0.f, 0.f, // HPF normalled from distOut
			true, 0.0f, 5.f, 0.f, 0.f,   // LPF patched with 0 V!
			sr, distOut, hpfOut, lpfOut
		);
		greater("hpfOut still active when LPF IN is patched", hpfOut, 4.0f);
		eq("patching LPF IN with 0 V silences LPF OUT", lpfOut, 0.f);

		std::printf("\n-- filter responses --\n");
		// Test HPF attenuation: 50 Hz tone through HPF with cutoff at 1 kHz (+1.93 V knob)
		SvfFilter testHpf;
		float hpCutoff = 1000.f;
		float maxHpfOut = 0.f;
		for (int i = 0; i < 480; i++) {
			float in = 5.0f * std::sin(2.0f * float(M_PI) * 50.f * i / sr);
			float lp, hp, bp;
			testHpf.process(in, hpCutoff, 0.f, sr, lp, hp, bp);
			if (i > 100 && std::fabs(hp) > maxHpfOut) maxHpfOut = std::fabs(hp);
		}
		checks++;
		if (maxHpfOut < 1.0f) {
			std::printf("ok    %-58s %8.3f V\n", "HPF strongly attenuates 50 Hz when set to 1 kHz", maxHpfOut);
		} else {
			std::printf("FAIL  HPF failed to attenuate low frequency: %.3f V\n", maxHpfOut);
			failures++;
		}

		// Test LPF attenuation: 5 kHz tone through LPF with cutoff at 300 Hz
		SvfFilter testLpf;
		float lpCutoff = 300.f;
		float maxLpfOut = 0.f;
		for (int i = 0; i < 480; i++) {
			float in = 5.0f * std::sin(2.0f * float(M_PI) * 5000.f * i / sr);
			float lp, hp, bp;
			testLpf.process(in, lpCutoff, 0.f, sr, lp, hp, bp);
			if (i > 100 && std::fabs(lp) > maxLpfOut) maxLpfOut = std::fabs(lp);
		}
		checks++;
		if (maxLpfOut < 0.5f) {
			std::printf("ok    %-58s %8.3f V\n", "LPF strongly attenuates 5 kHz when set to 300 Hz", maxLpfOut);
		} else {
			std::printf("FAIL  LPF failed to attenuate high frequency: %.3f V\n", maxLpfOut);
			failures++;
		}

		std::printf("\n-- resonance stability --\n");
		// Feed impulse with resonance at maximum (10 V)
		SvfFilter ringFilter;
		float maxRing = 0.f;
		bool hasNan = false;
		for (int i = 0; i < 2000; i++) {
			float in = (i == 0) ? 5.0f : 0.f;
			float lp, hp, bp;
			ringFilter.process(in, 1000.f, 10.f, sr, lp, hp, bp);
			if (std::isnan(lp) || std::isinf(lp)) hasNan = true;
			if (std::fabs(lp) > maxRing) maxRing = std::fabs(lp);
		}
		checks++;
		if (!hasNan && maxRing < 10.0f) {
			std::printf("ok    %-58s %8.3f V\n", "max resonance self-oscillates stably without runaway", maxRing);
		} else {
			std::printf("FAIL  filter resonance unstable or NaN: max=%.3f\n", maxRing);
			failures++;
		}
	}

	std::printf("\n%d checked, %d failed\n", checks, failures);
	return failures == 0 ? 0 : 1;
}
