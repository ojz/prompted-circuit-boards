// QuadAmp: four four-quadrant amplifier channels summed on a normalled mix bus.
//
// This is a V0 musical prototype under docs/ROADMAP.md, not a circuit. It
// exists to answer questions a description cannot: does four channels feel
// like enough, does the FINE knob earn its grid cell, and is the offset mode
// (nothing patched) something you reach for or something you forget exists.
//
// One channel:
//
//     OUT = SIG * CV * (COARSE + FINE) / 100
//
// with SIG and CV each normalled to +10 V when their jack is empty, and the
// knobs calibrated in volts (COARSE +/-10, FINE +/-1). The /100 is two
// four-quadrant multiplier scalings of /10 each, which is what makes the
// arithmetic land where it should: at full COARSE with both jacks empty the
// channel emits exactly the knob voltage, and with SIG patched and CV empty
// it is a plain attenuverter at unity.
//
// SUM carries the channels whose own OUT jack is empty. Patching a channel's
// OUT removes it from SUM and nothing else; the channel keeps working.
//
// Deliberately NOT modelled here: the analog error of a real multiplier.
// See docs/modules/quad-amp/SPEC.md, "What this prototype does not model".
#include "plugin.hpp"

// The transfer function itself, Rack-free so it can be tested without the
// runtime: see QuadAmpDsp.hpp and rack/tests/dsp_test.cpp.
#include "QuadAmpDsp.hpp"

using quadamp::CHANNELS;

// Panel geometry, in millimetres from the panel's top-left corner, looking at
// the front. These are the hardware coordinates, not Rack-specific ones: the
// same five rows and five columns the board would be built to.
static const float PANEL_W_MM = 80.90f;   // Doepfer 16 HP
static const float PANEL_H_MM = 128.50f;  // Doepfer 3U
static const float COL_PITCH_MM = 15.00f;
static const float ROW_PITCH_MM = 15.24f; // three nominal HP
static const int COLS = 5;
static const int ROWS = 5;

static float colX(int i) {
	float span = (COLS - 1) * COL_PITCH_MM;
	return (PANEL_W_MM - span) / 2.f + i * COL_PITCH_MM;
}

static float rowY(int i) {
	float span = (ROWS - 1) * ROW_PITCH_MM;
	return (PANEL_H_MM - span) / 2.f + i * ROW_PITCH_MM;
}

static math::Vec cell(int col, int row) {
	return mm2px(math::Vec(colX(col), rowY(row)));
}

struct QuadAmp : Module {
	enum ParamId {
		COARSE_PARAM,
		FINE_PARAM = COARSE_PARAM + CHANNELS,
		PARAMS_LEN = FINE_PARAM + CHANNELS
	};
	enum InputId {
		SIG_INPUT,
		CV_INPUT = SIG_INPUT + CHANNELS,
		INPUTS_LEN = CV_INPUT + CHANNELS
	};
	enum OutputId {
		SIG_OUTPUT,
		SUM_OUTPUT = SIG_OUTPUT + CHANNELS,
		OUTPUTS_LEN = SUM_OUTPUT + 1
	};
	enum LightId {
		LIGHTS_LEN
	};

	QuadAmp() {
		config(PARAMS_LEN, INPUTS_LEN, OUTPUTS_LEN, LIGHTS_LEN);
		for (int c = 0; c < CHANNELS; c++) {
			std::string n = string::f(" %d", c + 1);
			configParam(COARSE_PARAM + c, -10.f, 10.f, 0.f, "Coarse amp" + n, " V");
			configParam(FINE_PARAM + c, -1.f, 1.f, 0.f, "Fine amp" + n, " V");
			configInput(SIG_INPUT + c, "Signal" + n);
			configInput(CV_INPUT + c, "Amp CV" + n);
			configOutput(SIG_OUTPUT + c, "Signal" + n);
			// Say the normal out loud, so the offset mode is discoverable from
			// the tooltip rather than only from the specification.
			inputInfos[SIG_INPUT + c]->description = "Normalled to +10 V when empty";
			inputInfos[CV_INPUT + c]->description = "Normalled to +10 V when empty";
			outputInfos[SIG_OUTPUT + c]->description = "Patching this removes the channel from SUM";
		}
		configOutput(SUM_OUTPUT, "Sum");
		outputInfos[SUM_OUTPUT]->description = "Sum of the channels whose own output is unpatched";
	}

	void process(const ProcessArgs& args) override {
		float out[CHANNELS];
		bool outPatched[CHANNELS];

		for (int c = 0; c < CHANNELS; c++) {
			Input& sigIn = inputs[SIG_INPUT + c];
			Input& cvIn = inputs[CV_INPUT + c];
			Output& sigOut = outputs[SIG_OUTPUT + c];

			out[c] = quadamp::channelOut(
				sigIn.isConnected(), sigIn.getVoltage(),
				cvIn.isConnected(), cvIn.getVoltage(),
				params[COARSE_PARAM + c].getValue(),
				params[FINE_PARAM + c].getValue());

			sigOut.setVoltage(out[c]);
			// The normalled break: an empty output jack leaves the channel on
			// the mix bus. Inserting a plug takes it off and does nothing else.
			outPatched[c] = sigOut.isConnected();
		}
		outputs[SUM_OUTPUT].setVoltage(quadamp::mix(out, outPatched));
	}
};

// Rack's NanoSVG renderer ignores <text>, so the panel's lettering is drawn
// here against the same millimetre grid the graphics were laid out on.
struct QuadAmpLabels : Widget {
	std::shared_ptr<window::Font> font;

	void text(const DrawArgs& args, float x, float y, const char* s, float size, NVGcolor col) {
		nvgFontFaceId(args.vg, font->handle);
		nvgFontSize(args.vg, size);
		nvgTextAlign(args.vg, NVG_ALIGN_CENTER | NVG_ALIGN_MIDDLE);
		nvgTextLetterSpacing(args.vg, 0.6f);
		nvgFillColor(args.vg, col);
		nvgText(args.vg, x, y, s, NULL);
	}

	void draw(const DrawArgs& args) override {
		font = APP->window->loadFont(asset::system("res/fonts/DejaVuSans.ttf"));
		if (!font)
			return;

		NVGcolor bright = nvgRGB(0xe6, 0xe8, 0xee);
		NVGcolor muted = nvgRGB(0x8a, 0x8f, 0x9e);
		NVGcolor faint = nvgRGB(0x5a, 0x60, 0x70);
		NVGcolor accent = nvgRGB(0xe8, 0x83, 0x3a);

		text(args, 120.f, 52.f, "QUAD AMP", 13.f, bright);

		// Channel numbers over their strips.
		for (int c = 0; c < CHANNELS; c++)
			text(args, cell(c, 0).x, 69.f, string::f("%d", c + 1).c_str(), 8.f, muted);

		// The row legend lives in the reserved fifth column: one label per row
		// instead of one per control, which is what the shared-grid panel
		// language asks for. When real I/O fills these cells the legend needs
		// another home; that is a panel decision, not a prototype one.
		const char* legend[4] = {"SIG IN", "AMP CV", "COARSE", "FINE"};
		for (int r = 0; r < 4; r++)
			text(args, cell(4, r).x, cell(4, r).y, legend[r], 7.f, muted);
		text(args, cell(4, 3).x, cell(4, 3).y + 13.f, "RESERVED", 5.5f, faint);

		// Row 5 is where the channels and the bus differ, so it is labelled twice.
		for (int c = 0; c < CHANNELS; c++)
			text(args, cell(c, 4).x, 308.f, "OUT", 7.f, muted);
		text(args, cell(4, 4).x, 308.f, "SUM", 7.5f, accent);

		text(args, 120.f, 356.f, "PROMPTED CIRCUIT BOARDS  ·  V0 PROTOTYPE  ·  NOT A CIRCUIT", 5.5f, faint);
	}
};

struct QuadAmpWidget : ModuleWidget {
	QuadAmpWidget(QuadAmp* module) {
		setModule(module);
		setPanel(createPanel(asset::plugin(pluginInstance, "res/QuadAmp.svg")));

		QuadAmpLabels* labels = new QuadAmpLabels;
		labels->box.size = box.size;
		addChild(labels);

		addChild(createWidget<ScrewSilver>(math::Vec(RACK_GRID_WIDTH, 0)));
		addChild(createWidget<ScrewSilver>(math::Vec(box.size.x - 2 * RACK_GRID_WIDTH, 0)));
		addChild(createWidget<ScrewSilver>(math::Vec(RACK_GRID_WIDTH, RACK_GRID_HEIGHT - RACK_GRID_WIDTH)));
		addChild(createWidget<ScrewSilver>(math::Vec(box.size.x - 2 * RACK_GRID_WIDTH, RACK_GRID_HEIGHT - RACK_GRID_WIDTH)));

		for (int c = 0; c < CHANNELS; c++) {
			addInput(createInputCentered<PJ301MPort>(cell(c, 0), module, QuadAmp::SIG_INPUT + c));
			addInput(createInputCentered<PJ301MPort>(cell(c, 1), module, QuadAmp::CV_INPUT + c));
			// Two identical 9 mm pots on the board; the different caps are what
			// separate coarse from fine in the hand.
			addParam(createParamCentered<RoundBlackKnob>(cell(c, 2), module, QuadAmp::COARSE_PARAM + c));
			addParam(createParamCentered<RoundSmallBlackKnob>(cell(c, 3), module, QuadAmp::FINE_PARAM + c));
			addOutput(createOutputCentered<PJ301MPort>(cell(c, 4), module, QuadAmp::SIG_OUTPUT + c));
		}
		addOutput(createOutputCentered<PJ301MPort>(cell(4, 4), module, QuadAmp::SUM_OUTPUT));
	}
};

Model* modelQuadAmp = createModel<QuadAmp, QuadAmpWidget>("QuadAmp");
