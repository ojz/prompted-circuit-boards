// Behaviour tests for the Quad Amp transfer function.
//
// Rack Free has no headless mode, so the played module cannot be driven from a
// script. This compiles QuadAmpDsp.hpp on its own instead and checks the
// behaviour the specification claims -- the four patch states, unity gain, the
// knob reading in volts, gain above unity, the saturation curve and the
// normalled break. The module calls the same functions, so these cannot drift
// apart.
//
// Built and run by rack/build.sh before the plugin is packaged.
#include "../src/QuadAmpDsp.hpp"

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

	std::printf("\n%d checked, %d failed\n", checks, failures);
	return failures == 0 ? 0 : 1;
}
