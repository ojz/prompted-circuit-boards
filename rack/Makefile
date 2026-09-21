# Rack plugin build. Use build.sh: it finds the SDK and the MSYS2 toolchain,
# checks the two identifiers below against plugin.json and fails closed on a
# mismatch. RACK_DIR must point at an unpacked Rack SDK.
RACK_DIR ?= ../../Rack-SDK

# plugin.mk reads these out of plugin.json with jq, which MSYS2 does not ship
# by default. `override` keeps our values and makes that read irrelevant.
# build.sh is what holds them equal to plugin.json.
override SLUG := PromptedCircuitBoards
override VERSION := 2.0.0

SOURCES += $(wildcard src/*.cpp)

DISTRIBUTABLES += res   # plugin.mk adds plugin.json itself

include $(RACK_DIR)/plugin.mk
