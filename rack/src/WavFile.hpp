// A small WAV reader, with no dependency on Rack.
//
// The Rack SDK ships no audio file reader, so this is written here rather than
// pulled in. It reads what a drum loop is actually likely to be -- RIFF/WAVE,
// PCM 8/16/24/32-bit or 32-bit float, any channel count -- and downmixes to
// mono, because these modules are mono as the hardware would be.
//
// It parses files the user chose, so every read is bounds-checked against the
// buffer length and every length field is treated as untrusted. A malformed
// file must come back as a diagnostic, never as a crash or a silent misread;
// rack/tests/dsp_test.cpp feeds it truncated and corrupt input on purpose.
#pragma once

#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

namespace wav {

struct Audio {
	int sampleRate = 0;
	std::vector<float> mono;   ///< one sample per frame, channels averaged

	bool empty() const {
		return mono.empty();
	}
	size_t frames() const {
		return mono.size();
	}
	/** Seconds, or 0 if the rate is unknown. */
	float seconds() const {
		return sampleRate > 0 ? float(mono.size()) / float(sampleRate) : 0.f;
	}
};

namespace detail {

inline uint32_t rd32(const uint8_t* p) {
	return uint32_t(p[0]) | (uint32_t(p[1]) << 8) | (uint32_t(p[2]) << 16) | (uint32_t(p[3]) << 24);
}
inline uint16_t rd16(const uint8_t* p) {
	return uint16_t(uint16_t(p[0]) | (uint16_t(p[1]) << 8));
}

/** One sample, as a float in -1..1, from `bits`-wide little-endian data. */
inline float sampleAt(const uint8_t* p, int bits, bool isFloat) {
	if (isFloat) {
		uint32_t bitsLE = rd32(p);
		float f;
		std::memcpy(&f, &bitsLE, 4);
		return f;
	}
	switch (bits) {
		case 8:
			// 8-bit WAV is unsigned, every other width is signed two's complement.
			return (float(p[0]) - 128.f) / 128.f;
		case 16:
			return float(int16_t(rd16(p))) / 32768.f;
		case 24: {
			int32_t v = int32_t(uint32_t(p[0]) << 8 | uint32_t(p[1]) << 16 | uint32_t(p[2]) << 24);
			return float(v >> 8) / 8388608.f;
		}
		case 32:
			return float(int32_t(rd32(p))) / 2147483648.f;
		default:
			return 0.f;
	}
}

} // namespace detail

/** Parse a whole WAV file held in memory. Returns false and sets `error` on
anything it does not understand; `out` is only written on success. */
inline bool parse(const uint8_t* data, size_t len, Audio& out, std::string& error) {
	using namespace detail;

	if (!data || len < 12) {
		error = "too short to be a WAV file";
		return false;
	}
	if (std::memcmp(data, "RIFF", 4) != 0 || std::memcmp(data + 8, "WAVE", 4) != 0) {
		error = "not a RIFF/WAVE file";
		return false;
	}

	int channels = 0, bits = 0, rate = 0;
	bool isFloat = false, haveFmt = false;
	const uint8_t* pcm = NULL;
	size_t pcmLen = 0;

	size_t pos = 12;
	while (pos + 8 <= len) {
		const uint8_t* id = data + pos;
		uint32_t size = rd32(data + pos + 4);
		size_t body = pos + 8;
		// A chunk claiming to run past the end of the file is the usual shape of
		// a truncated download. Take what is really there rather than trusting it.
		size_t avail = len - body;
		size_t take = size_t(size) <= avail ? size_t(size) : avail;

		if (std::memcmp(id, "fmt ", 4) == 0 && take >= 16) {
			uint16_t format = rd16(data + body);
			channels = rd16(data + body + 2);
			rate = int(rd32(data + body + 4));
			bits = rd16(data + body + 14);
			if (format == 0xFFFE && take >= 40) {
				// WAVE_FORMAT_EXTENSIBLE: the real format is the subformat GUID's
				// first two bytes.
				format = rd16(data + body + 24);
			}
			if (format == 3)
				isFloat = true;
			else if (format != 1) {
				error = "unsupported WAV encoding (only PCM and float are read)";
				return false;
			}
			haveFmt = true;
		}
		else if (std::memcmp(id, "data", 4) == 0) {
			pcm = data + body;
			pcmLen = take;
		}

		// Chunks are word-aligned, and a zero size would never advance.
		size_t advance = size_t(size) + (size & 1);
		if (advance == 0)
			break;
		pos = body + advance;
	}

	if (!haveFmt) {
		error = "no fmt chunk";
		return false;
	}
	if (!pcm || pcmLen == 0) {
		error = "no audio data";
		return false;
	}
	if (channels <= 0 || channels > 32) {
		error = "unsupported channel count";
		return false;
	}
	if (rate < 1000 || rate > 768000) {
		error = "implausible sample rate";
		return false;
	}
	if (isFloat ? bits != 32 : (bits != 8 && bits != 16 && bits != 24 && bits != 32)) {
		error = "unsupported sample width";
		return false;
	}

	const size_t bytes = size_t(bits) / 8;
	const size_t frameBytes = bytes * size_t(channels);
	const size_t frames = pcmLen / frameBytes;
	if (frames == 0) {
		error = "audio data is shorter than one frame";
		return false;
	}

	out.sampleRate = rate;
	out.mono.assign(frames, 0.f);
	for (size_t f = 0; f < frames; f++) {
		float sum = 0.f;
		for (int c = 0; c < channels; c++)
			sum += sampleAt(pcm + f * frameBytes + size_t(c) * bytes, bits, isFloat);
		out.mono[f] = sum / float(channels);
	}
	error.clear();
	return true;
}

} // namespace wav
