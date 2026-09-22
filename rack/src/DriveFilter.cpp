// DriveFilter: distortion into resonant high-pass and resonant low-pass filters.
//
// This is a V0 musical prototype under docs/ROADMAP.md, not a circuit.
//
// Signal flow:
//     Distortion -> Resonant HPF -> Resonant LPF
//
// Normalling:
//     - HPF IN is normalled to Distortion OUT when empty.
//     - LPF IN is normalled to HPF OUT when empty.
//     - Plugging into HPF IN or LPF IN breaks the normal.
//     - Distortion OUT and HPF OUT remain available as individual tap points.
//
// The transfer functions and filter maths live in DriveFilterDsp.hpp so they
// can be tested without the Rack runtime.
#include "plugin.hpp"

#include "DriveFilterDsp.hpp"

// Panel geometry in millimetres from the panel's top-left corner.
static const float PANEL_W_MM = 50.50f;   // Doepfer 10 HP
static const float PANEL_H_MM = 128.50f;  // Doepfer 3U
static const float COL_PITCH_MM = 15.00f;
static const float ROW_PITCH_MM = 15.24f; // three nominal HP
static const int COLS = 3;
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

struct DriveFilter : Module {
	enum ParamId {
		DRIVE_PARAM,
		LEVEL_PARAM,
		HPF_FREQ_PARAM,
		HPF_RES_PARAM,
		LPF_FREQ_PARAM,
		LPF_RES_PARAM,
		PARAMS_LEN
	};
	enum InputId {
		DIST_INPUT,
		DRIVE_CV_INPUT,
		HPF_INPUT,
		HPF_CV_INPUT,
		LPF_INPUT,
		LPF_CV_INPUT,
		INPUTS_LEN
	};
	enum OutputId {
		DIST_OUTPUT,
		HPF_OUTPUT,
		LPF_OUTPUT,
		OUTPUTS_LEN
	};
	enum LightId {
		LIGHTS_LEN
	};

	drivefilter::DriveFilterProcessor processor;

	DriveFilter() {
		config(PARAMS_LEN, INPUTS_LEN, OUTPUTS_LEN, LIGHTS_LEN);

		// Distortion controls
		configParam(DRIVE_PARAM, 0.f, 10.f, 0.f, "Drive", " V");
		configParam(LEVEL_PARAM, 0.f, 10.f, 10.f, "Distortion Level", " V");
		configInput(DIST_INPUT, "Distortion In");
		configInput(DRIVE_CV_INPUT, "Drive CV");
		configOutput(DIST_OUTPUT, "Distortion Out");
		inputInfos[DIST_INPUT]->description = "Audio input to distortion stage";
		inputInfos[DRIVE_CV_INPUT]->description = "Modulates drive amount";
		outputInfos[DIST_OUTPUT]->description = "Distortion stage output (normalled to HPF IN)";

		// HPF controls: default knob at -5 V (~16 Hz, wide open bass)
		configParam(HPF_FREQ_PARAM, -5.f, 5.f, -5.f, "HPF Cutoff", " Hz", 2, drivefilter::BASE_FREQ_HZ);
		configParam(HPF_RES_PARAM, 0.f, 10.f, 0.f, "HPF Resonance", " V");
		configInput(HPF_INPUT, "HPF In");
		configInput(HPF_CV_INPUT, "HPF 1V/Oct CV");
		configOutput(HPF_OUTPUT, "HPF Out");
		inputInfos[HPF_INPUT]->description = "Normalled to DIST OUT when empty";
		inputInfos[HPF_CV_INPUT]->description = "1 V/Oct cutoff frequency modulation";
		outputInfos[HPF_OUTPUT]->description = "High-pass output (normalled to LPF IN)";

		// LPF controls: default knob at +5 V (~16.7 kHz, wide open treble)
		configParam(LPF_FREQ_PARAM, -5.f, 5.f, 5.f, "LPF Cutoff", " Hz", 2, drivefilter::BASE_FREQ_HZ);
		configParam(LPF_RES_PARAM, 0.f, 10.f, 0.f, "LPF Resonance", " V");
		configInput(LPF_INPUT, "LPF In");
		configInput(LPF_CV_INPUT, "LPF 1V/Oct CV");
		configOutput(LPF_OUTPUT, "LPF Out");
		inputInfos[LPF_INPUT]->description = "Normalled to HPF OUT when empty";
		inputInfos[LPF_CV_INPUT]->description = "1 V/Oct cutoff frequency modulation";
		outputInfos[LPF_OUTPUT]->description = "Final low-pass output";
	}

	void onReset() override {
		processor.reset();
	}

	void onSampleRateChange() override {
		processor.reset();
	}

	void process(const ProcessArgs& args) override {
		float distOut = 0.f;
		float hpfOut = 0.f;
		float lpfOut = 0.f;

		processor.step(
			inputs[DIST_INPUT].isConnected(),
			inputs[DIST_INPUT].getVoltage(),
			params[DRIVE_PARAM].getValue(),
			inputs[DRIVE_CV_INPUT].getVoltage(),
			params[LEVEL_PARAM].getValue(),

			inputs[HPF_INPUT].isConnected(),
			inputs[HPF_INPUT].getVoltage(),
			params[HPF_FREQ_PARAM].getValue(),
			inputs[HPF_CV_INPUT].getVoltage(),
			params[HPF_RES_PARAM].getValue(),

			inputs[LPF_INPUT].isConnected(),
			inputs[LPF_INPUT].getVoltage(),
			params[LPF_FREQ_PARAM].getValue(),
			inputs[LPF_CV_INPUT].getVoltage(),
			params[LPF_RES_PARAM].getValue(),

			args.sampleRate,
			distOut, hpfOut, lpfOut
		);

		outputs[DIST_OUTPUT].setVoltage(distOut);
		outputs[HPF_OUTPUT].setVoltage(hpfOut);
		outputs[LPF_OUTPUT].setVoltage(lpfOut);
	}
};

// Panel labels rendered via NanoVG
struct DriveFilterLabels : Widget {
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

		text(args, 75.f, 52.f, "DRIVE FILTER", 11.f, bright);

		// Section headers over columns
		text(args, cell(0, 0).x, 69.f, "DIST", 8.f, muted);
		text(args, cell(1, 0).x, 69.f, "HPF", 8.f, muted);
		text(args, cell(2, 0).x, 69.f, "LPF", 8.f, muted);

		// Row 0: Inputs
		text(args, cell(0, 0).x, cell(0, 0).y + 13.f, "IN", 6.5f, muted);
		text(args, cell(1, 0).x, cell(1, 0).y + 13.f, "IN", 6.5f, accent);
		text(args, cell(2, 0).x, cell(2, 0).y + 13.f, "IN", 6.5f, accent);

		// Row 1: Primary Knobs
		text(args, cell(0, 1).x, cell(0, 1).y + 16.f, "DRIVE", 6.5f, muted);
		text(args, cell(1, 1).x, cell(1, 1).y + 16.f, "FREQ", 6.5f, muted);
		text(args, cell(2, 1).x, cell(2, 1).y + 16.f, "FREQ", 6.5f, muted);

		// Row 2: CV Inputs
		text(args, cell(0, 2).x, cell(0, 2).y + 13.f, "CV", 6.5f, muted);
		text(args, cell(1, 2).x, cell(1, 2).y + 13.f, "CV", 6.5f, muted);
		text(args, cell(2, 2).x, cell(2, 2).y + 13.f, "CV", 6.5f, muted);

		// Row 3: Secondary Knobs
		text(args, cell(0, 3).x, cell(0, 3).y + 14.f, "LEVEL", 6.5f, muted);
		text(args, cell(1, 3).x, cell(1, 3).y + 14.f, "RES", 6.5f, muted);
		text(args, cell(2, 3).x, cell(2, 3).y + 14.f, "RES", 6.5f, muted);

		// Row 4: Outputs
		text(args, cell(0, 4).x, 308.f, "OUT", 7.f, accent);
		text(args, cell(1, 4).x, 308.f, "OUT", 7.f, accent);
		text(args, cell(2, 4).x, 308.f, "OUT", 7.f, muted);

		text(args, 75.f, 356.f, "V0 PROTOTYPE", 5.5f, faint);
	}
};

struct DriveFilterWidget : ModuleWidget {
	DriveFilterWidget(DriveFilter* module) {
		setModule(module);
		setPanel(createPanel(asset::plugin(pluginInstance, "res/DriveFilter.svg")));

		DriveFilterLabels* labels = new DriveFilterLabels;
		labels->box.size = box.size;
		addChild(labels);

		// Four panel mounting screws (10 HP: width is box.size.x)
		addChild(createWidget<ScrewSilver>(math::Vec(RACK_GRID_WIDTH, 0)));
		addChild(createWidget<ScrewSilver>(math::Vec(box.size.x - 2 * RACK_GRID_WIDTH, 0)));
		addChild(createWidget<ScrewSilver>(math::Vec(RACK_GRID_WIDTH, RACK_GRID_HEIGHT - RACK_GRID_WIDTH)));
		addChild(createWidget<ScrewSilver>(math::Vec(box.size.x - 2 * RACK_GRID_WIDTH, RACK_GRID_HEIGHT - RACK_GRID_WIDTH)));

		// Col 0: Distortion
		addInput(createInputCentered<PJ301MPort>(cell(0, 0), module, DriveFilter::DIST_INPUT));
		addParam(createParamCentered<RoundBlackKnob>(cell(0, 1), module, DriveFilter::DRIVE_PARAM));
		addInput(createInputCentered<PJ301MPort>(cell(0, 2), module, DriveFilter::DRIVE_CV_INPUT));
		addParam(createParamCentered<RoundSmallBlackKnob>(cell(0, 3), module, DriveFilter::LEVEL_PARAM));
		addOutput(createOutputCentered<PJ301MPort>(cell(0, 4), module, DriveFilter::DIST_OUTPUT));

		// Col 1: HPF
		addInput(createInputCentered<PJ301MPort>(cell(1, 0), module, DriveFilter::HPF_INPUT));
		addParam(createParamCentered<RoundBlackKnob>(cell(1, 1), module, DriveFilter::HPF_FREQ_PARAM));
		addInput(createInputCentered<PJ301MPort>(cell(1, 2), module, DriveFilter::HPF_CV_INPUT));
		addParam(createParamCentered<RoundSmallBlackKnob>(cell(1, 3), module, DriveFilter::HPF_RES_PARAM));
		addOutput(createOutputCentered<PJ301MPort>(cell(1, 4), module, DriveFilter::HPF_OUTPUT));

		// Col 2: LPF
		addInput(createInputCentered<PJ301MPort>(cell(2, 0), module, DriveFilter::LPF_INPUT));
		addParam(createParamCentered<RoundBlackKnob>(cell(2, 1), module, DriveFilter::LPF_FREQ_PARAM));
		addInput(createInputCentered<PJ301MPort>(cell(2, 2), module, DriveFilter::LPF_CV_INPUT));
		addParam(createParamCentered<RoundSmallBlackKnob>(cell(2, 3), module, DriveFilter::LPF_RES_PARAM));
		addOutput(createOutputCentered<PJ301MPort>(cell(2, 4), module, DriveFilter::LPF_OUTPUT));
	}
};

Model* modelDriveFilter = createModel<DriveFilter, DriveFilterWidget>("DriveFilter");
