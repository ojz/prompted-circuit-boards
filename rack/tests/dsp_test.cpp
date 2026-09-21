// Behaviour tests for the Quad Amp transfer function.
//
// Rack Free has no headless mode, so the played module cannot be driven from a
// script. This compiles QuadAmpDsp.hpp on its own instead and checks the
// behaviour the specification claims -- the four patch states, unity gain, the
// knob reading in volts, the normalled break and both saturation points.
// The module calls the same functions, so these cannot drift apart.
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
	if (std::fabs(got - want) > 1e-4f) {
		std::printf("FAIL  %s: got %.6f, expected %.6f\n", what, got, want);
		failures++;
	}
	else {
		std::printf("ok    %-58s %8.3f V\n", what, got);
	}
}

/* Shorthands for the four patch states of one channel. */
static float openOpen(float coarse, float fine) {
	return channelOut(false, 0.f, false, 0.f, coarse, fine);
}
static float sigOnly(float sig, float coarse, float fine) {
	return channelOut(true, sig, false, 0.f, coarse, fine);
}
static float both(float sig, float cv, float coarse, float fine) {
	return channelOut(true, sig, true, cv, coarse, fine);
}

int main() {
	std::printf("Quad Amp transfer function\n\n");

	std::printf("-- nothing patched: a DC offset, the dial reading in volts --\n");
	eq("coarse +5.0, fine 0", openOpen(5.f, 0.f), 5.f);
	eq("coarse -5.0, fine 0", openOpen(-5.f, 0.f), -5.f);
	eq("coarse  0.0, fine 0 is silent", openOpen(0.f, 0.f), 0.f);
	eq("coarse +3.0, fine +0.25 adds", openOpen(3.f, 0.25f), 3.25f);
	eq("fine alone is a tenth of coarse range", openOpen(0.f, 1.f), 1.f);

	std::printf("\n-- signal patched, CV open: an attenuverter --\n");
	eq("unity at full coarse", sigOnly(5.f, 10.f, 0.f), 5.f);
	eq("inverting at full negative coarse", sigOnly(5.f, -10.f, 0.f), -5.f);
	eq("half at half coarse", sigOnly(5.f, 5.f, 0.f), 2.5f);
	eq("silent at zero coarse", sigOnly(5.f, 0.f, 0.f), 0.f);

	std::printf("\n-- both patched: a VCA, four-quadrant --\n");
	eq("5 V signal, 5 V CV, full coarse", both(5.f, 5.f, 10.f, 0.f), 2.5f);
	eq("10 V CV restores unity", both(5.f, 10.f, 10.f, 0.f), 5.f);
	eq("negative CV inverts", both(5.f, -10.f, 10.f, 0.f), -5.f);
	eq("negative CV and negative coarse do not", both(5.f, -10.f, -10.f, 0.f), 5.f);
	eq("zero CV is silent whatever the knob", both(5.f, 0.f, 10.f, 1.f), 0.f);

	std::printf("\n-- saturation --\n");
	eq("a 12 V input at unity clips to the rail", sigOnly(12.f, 10.f, 0.f), CLIP_V);
	eq("and symmetrically", sigOnly(-12.f, 10.f, 0.f), -CLIP_V);
	eq("full knobs on both normals reach the rail exactly", openOpen(10.f, 1.f), 11.f);

	std::printf("\n-- the mix bus --\n");
	{
		float out[CHANNELS] = {1.f, 2.f, 3.f, 4.f};
		bool none[CHANNELS] = {false, false, false, false};
		eq("nothing patched out: all four sum", mix(out, none), 10.f);

		bool third[CHANNELS] = {false, false, true, false};
		eq("patching channel 3 removes only its 3 V", mix(out, third), 7.f);

		bool all[CHANNELS] = {true, true, true, true};
		eq("patching every output leaves the bus silent", mix(out, all), 0.f);

		// The headroom question from docs/modules/io-mixer/SPEC.md item 3.
		float loud[CHANNELS] = {10.f, 10.f, 10.f, 10.f};
		eq("four channels at 10 V want 40 V and cannot have it", mix(loud, none), CLIP_V);
	}

	std::printf("\n%d checked, %d failed\n", checks, failures);
	return failures == 0 ? 0 : 1;
}
