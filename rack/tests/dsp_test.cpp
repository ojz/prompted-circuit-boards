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
#include "../src/BreakDsp.hpp"
#include "../src/PanelGrid.hpp"

#include <cstdio>
#include <cmath>
#include <cstring>
#include <string>
#include <vector>

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
		// HPF open (-5 V, floored at 10 Hz), LPF open (+5 V, 8.4 kHz),
		// clean drive (0 V, level unity)
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

		std::printf("\n-- resonance: it has to sustain, not just stay finite --\n");
		{
			// The test this replaces only checked that the filter stayed finite,
			// which a filter decaying to nothing also does -- so it passed while
			// nothing could self-oscillate at all. Measure the tail instead.
			SvfFilter f;
			float lp, hp, bp;
			const int n = 40000;               // 0.83 s at 48 kHz
			float tail[3] = {0.f, 0.f, 0.f};
			float res[3] = {10.f, 5.f, 10.f / RES_SPAN * 0.95f};
			bool bad = false;
			for (int k = 0; k < 3; k++) {
				f.reset();
				float peak = 0.f;
				for (int i = 0; i < n; i++) {
					float in = (i == 0) ? 5.0f : 0.f;
					f.process(in, 1000.f, res[k], sr, lp, hp, bp);
					if (std::isnan(lp) || std::isinf(lp))
						bad = true;
					if (i > n - 4000) {
						float a = lp < 0.f ? -lp : lp;
						if (a > peak) peak = a;
					}
				}
				tail[k] = peak;
			}

			checks++;
			if (!bad && tail[0] > 0.5f)
				std::printf("ok    %-58s %8.3f V\n", "at full resonance it sustains", tail[0]);
			else {
				std::printf("FAIL  full resonance does not sustain: tail %.6f V\n", tail[0]);
				failures++;
			}

			eq("at half resonance it rings down to nothing", tail[1], 0.f);
			eq("and still nothing just below the oscillation onset", tail[2], 0.f);

			checks++;
			if (tail[0] < 5.f && tail[0] > 0.f)
				std::printf("ok    %-58s %8.3f V\n", "the saturated feedback bounds the limit cycle", tail[0]);
			else {
				std::printf("FAIL  limit cycle not bounded sensibly: %.6f V\n", tail[0]);
				failures++;
			}
		}
	}

	std::printf("\nPanel grid\n\n");
	{
		// The grid the modules share. If the fit gate moves the row pitch these
		// numbers move with it, which is the point of having one home for them.
		panel::Grid quad = {16, 5};
		panel::Grid drive = {10, 3};
		panel::Grid brk = {8, 2};

		eq("16 HP is 80.90 mm wide", quad.widthMM(), 80.90f);
		eq("10 HP is 50.50 mm wide", drive.widthMM(), 50.50f);
		eq("8 HP is 40.30 mm wide", brk.widthMM(), 40.30f);

		eq("five columns on 16 HP start at 10.45 mm", quad.colX(0), 10.45f);
		eq("and end at 70.45 mm", quad.colX(4), 70.45f);
		eq("three columns on 10 HP start at 10.25 mm", drive.colX(0), 10.25f);
		eq("two columns on 8 HP start at 12.65 mm", brk.colX(0), 12.65f);

		// Rows are identical across every module: that is the standing rule.
		eq("row 1 is at 33.77 mm", quad.rowY(0), 33.77f);
		eq("row 3 is the panel centre", quad.rowY(2), 64.25f);
		eq("row 5 is at 94.73 mm", quad.rowY(4), 94.73f);
		checks++;
		if (drive.rowY(0) == quad.rowY(0) && brk.rowY(4) == quad.rowY(4))
			std::printf("ok    %-58s\n", "all three modules put their rows in the same places");
		else {
			std::printf("FAIL  row positions differ between modules\n");
			failures++;
		}
	}

	std::printf("\nWAV reader\n\n");
	{
		// Built here rather than committed: the point of the loader is that the
		// sample stays the user's own file. See BreakDsp.hpp.
		std::vector<uint8_t> w;
		struct Put {
			static void u32(std::vector<uint8_t>& v, uint32_t x) {
				v.push_back(uint8_t(x)); v.push_back(uint8_t(x >> 8));
				v.push_back(uint8_t(x >> 16)); v.push_back(uint8_t(x >> 24));
			}
			static void u16(std::vector<uint8_t>& v, uint16_t x) {
				v.push_back(uint8_t(x)); v.push_back(uint8_t(x >> 8));
			}
			static void tag(std::vector<uint8_t>& v, const char* t) {
				for (int i = 0; i < 4; i++) v.push_back(uint8_t(t[i]));
			}
		};
		// 16-bit stereo, 4 frames; the last frame's channels differ so the
		// downmix is visible rather than assumed.
		Put::tag(w, "RIFF"); Put::u32(w, 0); Put::tag(w, "WAVE");
		Put::tag(w, "fmt "); Put::u32(w, 16);
		Put::u16(w, 1); Put::u16(w, 2); Put::u32(w, 44100);
		Put::u32(w, 176400); Put::u16(w, 4); Put::u16(w, 16);
		Put::tag(w, "data"); Put::u32(w, 16);
		int16_t frames[4][2] = {{0, 0}, {32767, 32767}, {-32768, -32768}, {16384, 0}};
		for (int f = 0; f < 4; f++)
			for (int c = 0; c < 2; c++) Put::u16(w, uint16_t(frames[f][c]));

		wav::Audio a;
		std::string err;
		checks++;
		if (wav::parse(w.data(), w.size(), a, err))
			std::printf("ok    %-58s\n", "a 16-bit stereo file parses");
		else {
			std::printf("FAIL  valid WAV rejected: %s\n", err.c_str());
			failures++;
		}
		eq("its sample rate is read", float(a.sampleRate), 44100.f);
		eq("its frame count is read", float(a.frames()), 4.f);
		eq("silence stays silence", a.mono[0], 0.f);
		eq("full scale positive is about +1", a.mono[1], 0.99997f);
		eq("full scale negative is -1", a.mono[2], -1.f);
		eq("the channels are averaged, not summed", a.mono[3], 0.25f);

		// Malformed input must come back as a diagnostic, never a crash.
		std::vector<uint8_t> empty;
		std::vector<uint8_t> shortHdr(w.begin(), w.begin() + 20);
		std::vector<uint8_t> notRiff = w; notRiff[0] = 'X';
		std::vector<uint8_t> badBits = w; badBits[34] = 7;
		std::vector<uint8_t> badFmt = w; badFmt[20] = 2;
		const char* names[5] = {"an empty buffer", "a truncated header",
			"a file that is not RIFF", "an unsupported sample width",
			"an unsupported encoding"};
		const std::vector<uint8_t>* bads[5] = {&empty, &shortHdr, &notRiff, &badBits, &badFmt};
		for (int i = 0; i < 5; i++) {
			wav::Audio out;
			std::string e;
			checks++;
			const uint8_t* p = bads[i]->empty() ? NULL : bads[i]->data();
			if (!wav::parse(p, bads[i]->size(), out, e))
				std::printf("ok    %-58s %s\n", names[i], e.c_str());
			else {
				std::printf("FAIL  %s was accepted\n", names[i]);
				failures++;
			}
		}
		{
			// A data chunk claiming far more bytes than the file holds: the usual
			// shape of a truncated download. Read what is there, do not run off.
			std::vector<uint8_t> over = w;
			over[42] = 0xFF; over[43] = 0xFF; over[44] = 0xFF; over[45] = 0x7F;
			wav::Audio out;
			std::string e;
			checks++;
			if (wav::parse(over.data(), over.size(), out, e) && out.frames() == 4)
				std::printf("ok    %-58s\n", "an overlong data chunk is clamped to the file");
			else {
				std::printf("FAIL  overlong data chunk mishandled (%s)\n", e.c_str());
				failures++;
			}
		}
	}

	std::printf("\nBreak engine\n\n");
	{
		using namespace brk;
		BreakEngine e;
		e.reset();
		float mix = 0.f, env = 0.f, peak = 0.f, envPeak = 0.f;
		const float sr2 = 48000.f;
		// Two bars at 174 BPM on the internal clock.
		int n = int(2.f * 4.f * 60.f / 174.f * sr2);
		for (int i = 0; i < n; i++) {
			e.process(false, false, false, 174.f, brk::FULL_SCALE, 1.f, sr2, mix, env);
			float a = mix < 0.f ? -mix : mix;
			if (a > peak) peak = a;
			if (env > envPeak) envPeak = env;
		}
		checks++;
		if (peak > 1.f && peak < 12.f)
			std::printf("ok    %-58s %8.3f V\n", "the built-in break makes a usable signal", peak);
		else {
			std::printf("FAIL  built-in break peak out of range: %.3f V\n", peak);
			failures++;
		}
		checks++;
		if (envPeak > 0.5f && envPeak <= brk::FULL_SCALE)
			std::printf("ok    %-58s %8.3f V\n", "the envelope follower tracks it", envPeak);
		else {
			std::printf("FAIL  envelope follower out of range: %.3f V\n", envPeak);
			failures++;
		}

		// LEVEL is the same convention as the other modules: unity at 10 V.
		e.reset();
		float halfPeak = 0.f;
		for (int i = 0; i < n; i++) {
			e.process(false, false, false, 174.f, brk::FULL_SCALE / 2.f, 1.f, sr2, mix, env);
			float a = mix < 0.f ? -mix : mix;
			if (a > halfPeak) halfPeak = a;
		}
		eq("level at half gives half the amplitude", halfPeak, peak / 2.f);

		// An external clock drives the steps, and reset returns to the start.
		e.reset();
		for (int i = 0; i < 5; i++)
			e.process(true, true, false, 174.f, brk::FULL_SCALE, 1.f, sr2, mix, env);
		eq("five clock edges reach step 5", float(e.step), 4.f);
		e.process(true, false, true, 174.f, brk::FULL_SCALE, 1.f, sr2, mix, env);
		eq("reset returns to before the first step", float(e.step), -1.f);

		// The pattern is the length it claims to be.
		int hits = 0;
		for (int i = 0; i < STEPS; i++)
			hits += (hitAt(kickPattern(), i) ? 1 : 0)
			      + (hitAt(snarePattern(), i) ? 1 : 0)
			      + (hitAt(hatPattern(), i) ? 1 : 0);
		checks++;
		if (int(std::strlen(kickPattern())) == STEPS && hits > 40)
			std::printf("ok    %-58s %8d\n", "four bars of sixteen, with hits in them", hits);
		else {
			std::printf("FAIL  pattern length or density wrong: %d hits\n", hits);
			failures++;
		}
	}

	std::printf("\n%d checked, %d failed\n", checks, failures);
	return failures == 0 ? 0 : 1;
}
