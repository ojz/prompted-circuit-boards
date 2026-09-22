// Break: a drum loop to test the other modules with, Rack-free so it can be
// tested without the runtime.
//
// Why this exists, and what it deliberately is not:
//
// The obvious source for testing a drive and a filter is the Amen break -- the
// drum bar from The Winstons' "Amen, Brother" (1969). That recording is still
// under copyright; Wikipedia's clip of it is non-free content used under fair
// use, so it cannot be committed to this repository. **Point the module at your
// own copy instead**: it reads any WAV from disk.
//
// So that it makes a sound with no file at all, it also synthesises a break of
// its own from a kick, a snare and a hat. That pattern is written here by ear
// as a plausible breakbeat; it is **not a transcription of the Amen break** and
// is not claimed to be one. Rhythms are not the copyrightable part, the
// recording is, but there is no reason to pretend to an accuracy this does not
// have.
//
// This module is a **bench instrument, not a candidate for the hardware
// composition.** It must not be counted in V0's function balance: it exists to
// feed the modules that are being evaluated, the way a signal generator does.
#pragma once

#include "WavFile.hpp"

#include <cmath>
#include <cstdint>

namespace brk {

/** Sixteenth-note steps in the built-in pattern: four bars of sixteen. */
const int STEPS = 64;

/** Output level convention, shared with the other modules: the LEVEL knob
spans 0 to 10 V and unity is at 10. */
const float FULL_SCALE = 10.f;

/** A deterministic noise source, so a test that runs the engine gets the same
numbers twice. */
struct Rng {
	uint32_t state = 0x13579bdfu;

	void reset() {
		state = 0x13579bdfu;
	}
	/** -1 to 1. */
	float next() {
		state = state * 1664525u + 1013904223u;
		return float(int32_t(state >> 8)) / 8388608.f - 1.f;
	}
};

/** The built-in break: four bars of sixteen steps. An 'x' is a hit.
Written by ear; see the note at the top of this file. */
inline const char* kickPattern() {
	return "x..x......x....."
	       "x..x......x....."
	       "x..x............"
	       "..x.............";
}
inline const char* snarePattern() {
	return "....x.......x..."
	       "....x.......x.x."
	       "....x.....x.x..."
	       "x...x......x.x..";
}
inline const char* hatPattern() {
	return "x.x.x.x.x.x.x.x."
	       "x.x.x.x.x.x.x.x."
	       "x.x.x.x.x.x.x.x."
	       "x.x.x.x.x.x.x.x.";
}

inline bool hitAt(const char* pattern, int step) {
	if (step < 0 || step >= STEPS)
		return false;
	return pattern[step] == 'x';
}

/** One percussive voice: an exponentially decaying envelope, and for the kick
a pitch that falls as it decays. All three voices are one struct because they
differ only in their constants. */
struct Voice {
	float env = 0.f;      ///< amplitude envelope, 0 to 1
	float pitchEnv = 0.f; ///< falls from 1 to 0, used by the kick
	float phase = 0.f;

	void trigger() {
		env = 1.f;
		pitchEnv = 1.f;
		phase = 0.f;
	}

	void decay(float ampTau, float pitchTau, float sampleRate) {
		env -= env / (ampTau * sampleRate);
		pitchEnv -= pitchEnv / (pitchTau * sampleRate);
		if (env < 1e-6f)
			env = 0.f;
		if (pitchEnv < 1e-6f)
			pitchEnv = 0.f;
	}

	float tone(float freqHz, float sampleRate) {
		phase += freqHz / sampleRate;
		if (phase >= 1.f)
			phase -= 1.f;
		return std::sin(2.f * 3.14159265358979323846f * phase);
	}
};

/** Plays a loaded sample, looping, at a rate multiplier. Linear interpolation
is enough for a test source; nothing here is claimed to be a clean resampler. */
struct SamplePlayer {
	const wav::Audio* audio = NULL;
	double pos = 0.0;

	void rewind() {
		pos = 0.0;
	}

	bool ready() const {
		return audio && !audio->empty();
	}

	/** `speed` is a rate multiplier; the file's own rate is corrected against
	the engine's so a 44.1 kHz loop plays at pitch in a 48 kHz session. */
	float next(float speed, float engineRate) {
		if (!ready())
			return 0.f;
		const size_t n = audio->frames();
		size_t i = size_t(pos);
		if (i >= n) {
			pos = 0.0;
			i = 0;
		}
		size_t j = (i + 1 < n) ? i + 1 : 0;
		float frac = float(pos - double(i));
		float s = audio->mono[i] * (1.f - frac) + audio->mono[j] * frac;

		double rate = double(speed) * double(audio->sampleRate) / double(engineRate);
		pos += rate;
		if (pos >= double(n))
			pos -= double(n);
		return s;
	}
};

/** Follows the output's magnitude, so there is always a modulation source to
patch into the modules being tested. Rises fast, falls slowly. */
struct EnvelopeFollower {
	float value = 0.f;

	float process(float in, float sampleRate) {
		float a = in < 0.f ? -in : in;
		float tau = (a > value) ? 0.005f : 0.150f;
		value += (a - value) / (tau * sampleRate);
		if (value < 0.f)
			value = 0.f;
		return value;
	}
};

/** The whole module, minus its panel. */
struct BreakEngine {
	Voice kick, snare, hat;
	Rng rng;
	SamplePlayer player;
	EnvelopeFollower follower;

	int step = -1;          ///< -1 before the first clock edge
	double stepPhase = 0.0; ///< internal clock accumulator, 0 to 1 per step
	float hatHp = 0.f;      ///< one-pole high-pass state for the hat

	void reset() {
		kick = snare = hat = Voice();
		rng.reset();
		player.rewind();
		follower.value = 0.f;
		step = -1;
		stepPhase = 0.0;
		hatHp = 0.f;
	}

	/** Advance to the next sixteenth. Fires the voices the pattern asks for,
	and restarts a loaded sample at the top of the four bars. */
	void advance() {
		step = (step + 1) % STEPS;
		if (step == 0)
			player.rewind();
		if (player.ready())
			return; // a loaded sample plays itself; the voices stay quiet
		if (hitAt(kickPattern(), step))
			kick.trigger();
		if (hitAt(snarePattern(), step))
			snare.trigger();
		if (hitAt(hatPattern(), step))
			hat.trigger();
	}

	/** Sixteenth notes per second at a given tempo. */
	static float stepsPerSecond(float bpm) {
		return bpm * 4.f / 60.f;
	}

	/** One sample.
	`clocked` is true on a rising edge of an external clock; when `clockPatched`
	is false the internal clock at `bpm` drives the steps instead.
	`level` is the LEVEL knob in volts, `speed` the rate multiplier. */
	void process(bool clockPatched, bool clocked, bool resetEdge,
	             float bpm, float level, float speed, float sampleRate,
	             float& mixOut, float& envOut) {
		if (resetEdge) {
			step = -1;
			stepPhase = 0.0;
			player.rewind();
		}

		if (clockPatched) {
			if (clocked)
				advance();
		}
		else {
			stepPhase += double(stepsPerSecond(bpm)) / double(sampleRate);
			while (stepPhase >= 1.0) {
				stepPhase -= 1.0;
				advance();
			}
			if (step < 0)
				advance();
		}

		float v = 0.f;
		if (player.ready()) {
			v = player.next(speed, sampleRate) * 5.f;
		}
		else {
			// Kick: a sine whose pitch falls from 110 Hz to about 45 Hz.
			float kf = (45.f + 65.f * kick.pitchEnv) * speed;
			v += 4.5f * kick.env * kick.tone(kf, sampleRate);
			kick.decay(0.12f, 0.03f, sampleRate);

			// Snare: noise plus a short body tone.
			float body = snare.tone(185.f * speed, sampleRate);
			v += snare.env * (2.6f * rng.next() + 1.6f * body);
			snare.decay(0.10f, 0.06f, sampleRate);

			// Hat: noise through a one-pole high-pass, very short.
			float n = rng.next();
			hatHp += (n - hatHp) * (6000.f / sampleRate);
			v += 1.6f * hat.env * (n - hatHp);
			hat.decay(0.025f, 0.025f, sampleRate);
		}

		float levelFactor = level / FULL_SCALE;
		if (levelFactor < 0.f)
			levelFactor = 0.f;
		mixOut = v * levelFactor;
		envOut = follower.process(mixOut, sampleRate) * 2.f;
		if (envOut > FULL_SCALE)
			envOut = FULL_SCALE;
	}
};

} // namespace brk
