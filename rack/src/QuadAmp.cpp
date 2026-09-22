// QuadAmp: four amplifier channels summed on a normalled mix bus.
//
// This is a V0 musical prototype under docs/ROADMAP.md, not a circuit. It
// exists to answer questions a description cannot: does four channels feel
// like enough, does the scale-and-shift mode get reached for or forgotten,
// and is the overdrive worth having.
//
// One channel, top to bottom on the panel: SIG IN, BIAS, MOD, DEPTH, OUT.
//
//     gain = (BIAS + MOD * DEPTH / 10) / 10
//     OUT  = saturate(SIG * gain)
//
// SIG is normalled to +10 V when its jack is empty, so a channel with nothing
// patched is a DC offset whose dial reads in volts. MOD is deliberately not
// normalled, so DEPTH visibly does nothing without a cable. Both knobs span
// +/-10 V and read in volts, and the gain may exceed unity.
//
// SUM carries the channels whose own OUT jack is empty. Patching a channel's
// OUT removes it from SUM and nothing else; the channel keeps working.
//
// The transfer function, its constants and the saturation curve live in
// QuadAmpDsp.hpp so they can be tested without the Rack runtime.
//
// Deliberately NOT modelled here: the analog error of a real multiplier.
// See docs/modules/quad-amp/SPEC.md, "What this prototype does not model".
#include "plugin.hpp"

#include "PanelGrid.hpp"

#include "QuadAmpDsp.hpp"

using quadamp::CHANNELS;

// Panel geometry. The grid itself is in PanelGrid.hpp so there is one
// home for the pitches and the row count; this names only what is this
// module's own: how wide it is and how many columns it uses.
// Four channel columns plus the reserved fifth: 16 HP.
static const panel::Grid GRID = {16, 5};

static math::Vec cell(int col, int row) {
	return mm2px(math::Vec(GRID.colX(col), GRID.rowY(row)));
}

struct QuadAmp : Module {
	enum ParamId {
		BIAS_PARAM,
		DEPTH_PARAM = BIAS_PARAM + CHANNELS,
		PARAMS_LEN = DEPTH_PARAM + CHANNELS
	};
	enum InputId {
		SIG_INPUT,
		MOD_INPUT = SIG_INPUT + CHANNELS,
		INPUTS_LEN = MOD_INPUT + CHANNELS
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
			configParam(BIAS_PARAM + c, -quadamp::FULL_SCALE, quadamp::FULL_SCALE,
				0.f, "Bias" + n, " V");
			configParam(DEPTH_PARAM + c, -quadamp::FULL_SCALE, quadamp::FULL_SCALE,
				0.f, "Mod depth" + n, " V");
			configInput(SIG_INPUT + c, "Signal" + n);
			configInput(MOD_INPUT + c, "Mod" + n);
			configOutput(SIG_OUTPUT + c, "Signal" + n);
			// Say the normals out loud, so the offset and scale-and-shift modes
			// are discoverable from the tooltip and not only from the spec.
			inputInfos[SIG_INPUT + c]->description = "Normalled to +10 V when empty";
			inputInfos[MOD_INPUT + c]->description = "Not normalled; depth does nothing without a cable";
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
			Input& modIn = inputs[MOD_INPUT + c];
			Output& sigOut = outputs[SIG_OUTPUT + c];

			// An unconnected Rack input already reads 0 V, which is exactly
			// MOD's unpatched behaviour, so it needs no test of its own.
			out[c] = quadamp::channelOut(
				sigIn.isConnected(), sigIn.getVoltage(),
				modIn.getVoltage(),
				params[BIAS_PARAM + c].getValue(),
				params[DEPTH_PARAM + c].getValue());

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
		// Two pairs and a result: the signal and how much of it, the
		// modulation and how much of it, then the output.
		const char* legend[4] = {"SIG IN", "BIAS", "MOD", "DEPTH"};
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
			// Two pairs and a result: the signal and how much of it, the
			// modulation and how much of it, then the output. Each knob sits
			// under the jack it belongs to.
			addInput(createInputCentered<PJ301MPort>(cell(c, 0), module, QuadAmp::SIG_INPUT + c));
			// Two identical 9 mm pots on the board; the different caps are what
			// separate the two in the hand.
			addParam(createParamCentered<RoundBlackKnob>(cell(c, 1), module, QuadAmp::BIAS_PARAM + c));
			addInput(createInputCentered<PJ301MPort>(cell(c, 2), module, QuadAmp::MOD_INPUT + c));
			addParam(createParamCentered<RoundSmallBlackKnob>(cell(c, 3), module, QuadAmp::DEPTH_PARAM + c));
			addOutput(createOutputCentered<PJ301MPort>(cell(c, 4), module, QuadAmp::SIG_OUTPUT + c));
		}
		addOutput(createOutputCentered<PJ301MPort>(cell(4, 4), module, QuadAmp::SUM_OUTPUT));
	}
};

Model* modelQuadAmp = createModel<QuadAmp, QuadAmpWidget>("QuadAmp");
