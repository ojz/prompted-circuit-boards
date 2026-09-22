// The shared panel grid, in millimetres, with no dependency on Rack.
//
// Every module's control centres come from here, so the grid has one home.
// That matters because the row pitch is still a candidate: docs/MECHANICAL.md's
// fit gate has not run, and when it changes this is the only file to edit.
// Before this header the numbers were copied into each module and nothing
// would have caught them drifting apart.
//
// Panel coordinates have their origin at the panel's top-left corner, y
// downward, looking at the panel from the front -- the same convention as
// Block.Eurorack in the hardware generator.
#pragma once

namespace panel {

/** Doepfer 3U. */
const float HEIGHT_MM = 128.50f;

/** Five rows, always: the standing rule in AGENTS.md. The derivation in
toolkit/src/Sketch/Catalogue.hs still owns the maximum of six; this is the
project's choice inside it, so rows line up from one module to the next. */
const int ROWS = 5;

/** Both pitches are candidates, not verified fits. 15.24 mm is three nominal
HP. docs/MECHANICAL.md#grid-and-fit-gate owns them. */
const float COL_PITCH_MM = 15.00f;
const float ROW_PITCH_MM = 15.24f;

/** Doepfer's front panel width table.
**This duplicates `eurorackPanelWidths` in toolkit/src/Design.hs**, which is the
source of truth; the widths a Rack prototype needs are copied here because the
generator cannot emit C++. Keep them equal by hand, and prefer the Haskell one
when they disagree. */
inline float widthMM(int hp) {
	switch (hp) {
		case 1: return 5.00f;
		case 2: return 9.80f;
		case 4: return 20.00f;
		case 6: return 30.00f;
		case 8: return 40.30f;
		case 10: return 50.50f;
		case 12: return 60.60f;
		case 14: return 70.80f;
		case 16: return 80.90f;
		case 18: return 91.30f;
		case 20: return 101.30f;
		// Doepfer's table does not list this width; the nominal formula stands in.
		default: return hp * 5.08f - 0.3f;
	}
}

/** One module's grid: a width in HP and a column count, with the row count and
both pitches fixed above. Columns and rows are centred on the panel. */
struct Grid {
	int hp;
	int cols;

	float widthMM() const {
		return panel::widthMM(hp);
	}

	float colX(int i) const {
		float span = (cols - 1) * COL_PITCH_MM;
		return (widthMM() - span) / 2.f + i * COL_PITCH_MM;
	}

	float rowY(int i) const {
		float span = (ROWS - 1) * ROW_PITCH_MM;
		return (HEIGHT_MM - span) / 2.f + i * ROW_PITCH_MM;
	}
};

} // namespace panel
