/* Parse a panel SVG with the same NanoSVG that Rack uses, and fail if it does
 * not come out usable.
 *
 * This exists because of a silent failure mode that is very easy to hit and
 * very hard to read: rack::window::Svg keeps `handle = NULL` when NanoSVG
 * cannot parse the file, logs "Loaded SVG <path>" anyway, and the segfault
 * lands later in SvgWidget::wrap() dereferencing it -- inside the module
 * widget's constructor, which is nowhere near the actual mistake.
 *
 * NanoSVG is not a conforming XML parser. It ends a <!...> block at the first
 * '>' it meets, so a comment containing a tag name in angle brackets silently
 * corrupts the rest of the document. That is exactly what happened here.
 *
 *   svgcheck [--expect WxH] FILE...
 *
 * Exits non-zero on the first file that fails to parse, has no shapes, or does
 * not match --expect. Built and run by rack/build.sh before packaging.
 */
/* nanosvg.h's implementation calls sscanf without including stdio itself. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define NANOSVG_IMPLEMENTATION
#include "nanosvg.h"

/* Rack's own DPI for panel SVGs: window/Svg.hpp, SVG_DPI. */
#define RACK_SVG_DPI 75.0f

static int nearly(float a, float b) {
	float d = a - b;
	return (d < 0 ? -d : d) < 0.5f;
}

int main(int argc, char** argv) {
	float wantW = 0.f, wantH = 0.f;
	int i = 1, failures = 0, checked = 0;

	if (i < argc && strcmp(argv[i], "--expect") == 0) {
		if (i + 1 >= argc || sscanf(argv[i + 1], "%fx%f", &wantW, &wantH) != 2) {
			fprintf(stderr, "svgcheck: --expect needs WxH, e.g. 240x380\n");
			return 2;
		}
		i += 2;
	}
	if (i >= argc) {
		fprintf(stderr, "usage: svgcheck [--expect WxH] FILE...\n");
		return 2;
	}

	for (; i < argc; i++) {
		const char* path = argv[i];
		NSVGimage* img = nsvgParseFromFile(path, "px", RACK_SVG_DPI);
		checked++;

		if (!img) {
			printf("FAIL  %s: NanoSVG could not parse it.\n", path);
			printf("      Check for '<' or '>' inside a comment, and for any\n");
			printf("      element NanoSVG does not implement (<text> above all).\n");
			failures++;
			continue;
		}

		int shapes = 0;
		for (NSVGshape* s = img->shapes; s; s = s->next)
			shapes++;

		if (shapes == 0) {
			printf("FAIL  %s: parsed, but has no shapes. Rack would draw an empty panel.\n", path);
			failures++;
		}
		else if (wantW > 0.f && !(nearly(img->width, wantW) && nearly(img->height, wantH))) {
			printf("FAIL  %s: page is %.2f x %.2f px, expected %.2f x %.2f.\n",
			       path, img->width, img->height, wantW, wantH);
			failures++;
		}
		else {
			printf("ok    %s: %.2f x %.2f px (%.2f x %.2f mm), %d shapes\n",
			       path, img->width, img->height,
			       img->width * 25.4f / RACK_SVG_DPI,
			       img->height * 25.4f / RACK_SVG_DPI, shapes);
		}
		nsvgDelete(img);
	}

	printf("%d checked, %d failed\n", checked, failures);
	return failures == 0 ? 0 : 1;
}
