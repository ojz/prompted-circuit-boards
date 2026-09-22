// Break: a drum loop to test the other modules with.
//
// A bench instrument, not a candidate module. It must not be counted in V0's
// function balance -- it exists to feed the modules being evaluated, the way a
// signal generator does, and no hardware version of it is proposed.
//
// It plays a WAV you point it at, and synthesises a break of its own when no
// file is loaded so it is never silent. The reason it does not ship with the
// Amen break in it is in BreakDsp.hpp: that recording is still under copyright.
//
// Panel, two columns by the standing five rows:
//
//     CLOCK IN   RESET IN
//     TEMPO      LEVEL
//     reserved   reserved
//     SPEED      reserved
//     MIX OUT    ENV OUT
#include "plugin.hpp"

#include "PanelGrid.hpp"
#include "BreakDsp.hpp"

#include <osdialog.h>

#include <cstdio>
#include <string>
#include <vector>

// Panel geometry. The grid itself is in PanelGrid.hpp so there is one home for
// the pitches and the row count; this names only what is this module's own.
// Clock and voice on the left, level and outputs on the right: 8 HP.
static const panel::Grid GRID = {8, 2};

static math::Vec cell(int col, int row) {
	return mm2px(math::Vec(GRID.colX(col), GRID.rowY(row)));
}

struct Break : Module {
	enum ParamId {
		TEMPO_PARAM,
		LEVEL_PARAM,
		SPEED_PARAM,
		PARAMS_LEN
	};
	enum InputId {
		CLOCK_INPUT,
		RESET_INPUT,
		INPUTS_LEN
	};
	enum OutputId {
		MIX_OUTPUT,
		ENV_OUTPUT,
		OUTPUTS_LEN
	};
	enum LightId {
		LIGHTS_LEN
	};

	brk::BreakEngine engine;
	wav::Audio audio;
	std::string samplePath;   ///< empty means the built-in break
	std::string sampleError;  ///< shown in the menu when a load failed

	dsp::SchmittTrigger clockTrigger;
	dsp::SchmittTrigger resetTrigger;

	Break() {
		config(PARAMS_LEN, INPUTS_LEN, OUTPUTS_LEN, LIGHTS_LEN);
		configParam(TEMPO_PARAM, 40.f, 240.f, 174.f, "Tempo", " BPM");
		configParam(LEVEL_PARAM, 0.f, brk::FULL_SCALE, brk::FULL_SCALE, "Level", " V");
		configParam(SPEED_PARAM, 0.25f, 4.f, 1.f, "Speed", "x");
		configInput(CLOCK_INPUT, "Clock");
		configInput(RESET_INPUT, "Reset");
		configOutput(MIX_OUTPUT, "Mix");
		configOutput(ENV_OUTPUT, "Envelope");
		inputInfos[CLOCK_INPUT]->description = "Sixteenth notes; the internal clock runs at TEMPO when empty";
		inputInfos[RESET_INPUT]->description = "Back to the first step";
		outputInfos[ENV_OUTPUT]->description = "Follows the mix, 0 to 10 V: a modulation source for the modules under test";
		engine.reset();
	}

	/** 174 BPM is the tempo the Amen break is usually quoted at, which is why
	it is the default: a loop of it loaded here lines up without hunting. */

	void loadSample(const std::string& path) {
		sampleError.clear();
		if (path.empty()) {
			audio = wav::Audio();
			samplePath.clear();
			engine.player.audio = NULL;
			return;
		}
		std::FILE* f = std::fopen(path.c_str(), "rb");
		if (!f) {
			sampleError = "could not open the file";
			return;
		}
		std::fseek(f, 0, SEEK_END);
		long size = std::ftell(f);
		std::fseek(f, 0, SEEK_SET);
		// A drum loop is a few megabytes at most; refuse anything absurd rather
		// than trying to read it into memory.
		if (size <= 0 || size > 128L * 1024 * 1024) {
			std::fclose(f);
			sampleError = "file is empty or implausibly large";
			return;
		}
		// A named length, not `buf(size_t(size))`: that form is a function
		// declaration, not a vector.
		const size_t length = size_t(size);
		std::vector<uint8_t> buf(length);
		size_t got = std::fread(buf.data(), 1, buf.size(), f);
		std::fclose(f);
		buf.resize(got);

		wav::Audio parsed;
		std::string err;
		if (!wav::parse(buf.data(), buf.size(), parsed, err)) {
			sampleError = err;
			return;
		}
		audio = parsed;
		samplePath = path;
		engine.player.audio = &audio;
		engine.player.rewind();
	}

	void onReset(const ResetEvent& e) override {
		Module::onReset(e);
		loadSample("");
		engine.reset();
	}

	json_t* dataToJson() override {
		json_t* root = json_object();
		// The path, not the audio: a patch file should stay small, and the
		// sample is the user's own file wherever they keep it.
		json_object_set_new(root, "samplePath", json_string(samplePath.c_str()));
		return root;
	}

	void dataFromJson(json_t* root) override {
		json_t* p = json_object_get(root, "samplePath");
		if (p && json_is_string(p))
			loadSample(json_string_value(p));
	}

	void process(const ProcessArgs& args) override {
		bool clockPatched = inputs[CLOCK_INPUT].isConnected();
		bool clocked = clockPatched
			&& clockTrigger.process(inputs[CLOCK_INPUT].getVoltage(), 0.1f, 1.f);
		bool resetEdge = resetTrigger.process(inputs[RESET_INPUT].getVoltage(), 0.1f, 1.f);

		float mix = 0.f, env = 0.f;
		engine.process(clockPatched, clocked, resetEdge,
			params[TEMPO_PARAM].getValue(),
			params[LEVEL_PARAM].getValue(),
			params[SPEED_PARAM].getValue(),
			args.sampleRate, mix, env);

		outputs[MIX_OUTPUT].setVoltage(mix);
		outputs[ENV_OUTPUT].setVoltage(env);
	}
};

// Rack's NanoSVG renderer ignores <text>, so the lettering is drawn here.
struct BreakLabels : Widget {
	Break* module = NULL;
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
		NVGcolor accent = nvgRGB(0x6f, 0xc2, 0x8a);

		text(args, box.size.x / 2.f, 52.f, "BREAK", 13.f, bright);

		// Which source is actually playing, since that is not otherwise visible.
		const char* src = (module && !module->samplePath.empty()) ? "SAMPLE" : "BUILT-IN";
		text(args, box.size.x / 2.f, 68.f, src, 5.5f, accent);

		text(args, cell(0, 0).x, cell(0, 0).y - 14.f, "CLOCK", 6.5f, muted);
		text(args, cell(1, 0).x, cell(1, 0).y - 14.f, "RESET", 6.5f, muted);
		text(args, cell(0, 1).x, cell(0, 1).y - 15.f, "TEMPO", 6.5f, muted);
		text(args, cell(1, 1).x, cell(1, 1).y - 15.f, "LEVEL", 6.5f, muted);
		text(args, cell(0, 3).x, cell(0, 3).y - 13.f, "SPEED", 6.5f, muted);
		text(args, cell(1, 3).x, cell(1, 3).y, "RESERVED", 5.f, faint);
		text(args, cell(0, 2).x, cell(0, 2).y, "RESERVED", 5.f, faint);
		text(args, cell(1, 2).x, cell(1, 2).y, "RESERVED", 5.f, faint);
		text(args, cell(0, 4).x, cell(0, 4).y + 14.f, "MIX", 6.5f, muted);
		text(args, cell(1, 4).x, cell(1, 4).y + 14.f, "ENV", 6.5f, accent);

		text(args, box.size.x / 2.f, 356.f, "BENCH TOOL  ·  NOT A MODULE", 5.f, faint);
	}
};

struct BreakWidget : ModuleWidget {
	BreakWidget(Break* module) {
		setModule(module);
		setPanel(createPanel(asset::plugin(pluginInstance, "res/Break.svg")));

		BreakLabels* labels = new BreakLabels;
		labels->module = module;
		labels->box.size = box.size;
		addChild(labels);

		addChild(createWidget<ScrewSilver>(math::Vec(RACK_GRID_WIDTH, 0)));
		addChild(createWidget<ScrewSilver>(math::Vec(box.size.x - 2 * RACK_GRID_WIDTH, RACK_GRID_HEIGHT - RACK_GRID_WIDTH)));

		addInput(createInputCentered<PJ301MPort>(cell(0, 0), module, Break::CLOCK_INPUT));
		addInput(createInputCentered<PJ301MPort>(cell(1, 0), module, Break::RESET_INPUT));
		addParam(createParamCentered<RoundBlackKnob>(cell(0, 1), module, Break::TEMPO_PARAM));
		addParam(createParamCentered<RoundBlackKnob>(cell(1, 1), module, Break::LEVEL_PARAM));
		addParam(createParamCentered<RoundSmallBlackKnob>(cell(0, 3), module, Break::SPEED_PARAM));
		addOutput(createOutputCentered<PJ301MPort>(cell(0, 4), module, Break::MIX_OUTPUT));
		addOutput(createOutputCentered<PJ301MPort>(cell(1, 4), module, Break::ENV_OUTPUT));
	}

	void appendContextMenu(Menu* menu) override {
		Break* m = dynamic_cast<Break*>(module);
		if (!m)
			return;

		menu->addChild(new MenuSeparator);
		menu->addChild(createMenuLabel(
			m->samplePath.empty() ? "Playing the built-in break" : m->samplePath));
		if (!m->sampleError.empty())
			menu->addChild(createMenuLabel("Last load failed: " + m->sampleError));

		menu->addChild(createMenuItem("Load WAV...", "", [m]() {
			osdialog_filters* filters = osdialog_filters_parse("WAV audio:wav");
			char* path = osdialog_file(OSDIALOG_OPEN, NULL, NULL, filters);
			osdialog_filters_free(filters);
			if (path) {
				m->loadSample(path);
				std::free(path);
			}
		}));
		menu->addChild(createMenuItem("Use the built-in break", "",
			[m]() { m->loadSample(""); },
			m->samplePath.empty()));
	}
};

Model* modelBreak = createModel<Break, BreakWidget>("Break");
