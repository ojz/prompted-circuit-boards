// The saturation curve both modules use, with no dependency on Rack.
//
// Exactly linear below a threshold, then a tanh knee asymptotic to a ceiling,
// continuous in value and in slope at the join so there is no corner to hear.
//
// The linear region is the point of it. A plain `L * tanh(v / L)` bends from
// the first volt: a 5 V signal would leave a 11.5 V saturator at 4.69 V, and a
// knob calibrated in volts would stop reading in volts. Keeping an exact
// region below the threshold is what lets a channel be both a clean DC source
// and a drive.
//
// Each module supplies its own two constants; the shape is what is shared.
#pragma once

#include <cmath>

namespace sat {

/** Linear to `linearV`, then a tanh knee asymptotic to `ceilingV`.
Requires ceilingV > linearV >= 0. */
inline float soft(float v, float linearV, float ceilingV) {
	float a = v < 0.f ? -v : v;
	if (a <= linearV)
		return v;
	const float knee = ceilingV - linearV;
	float out = linearV + knee * std::tanh((a - linearV) / knee);
	return v < 0.f ? -out : out;
}

} // namespace sat
