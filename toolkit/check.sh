#!/usr/bin/env bash
# Headless verification of a generated module: ERC, DRC with zone refill,
# schematic parity, and renders. Exits non-zero on any violation.
#
#   toolkit/check.sh <module-dir> [stem]     e.g. toolkit/check.sh mult
#                                                 toolkit/check.sh mult/panel
#
# <module-dir> is relative to modules/; the project file stem defaults to the
# last path component. Run from the repository root. Output lands in
# modules/<module-dir>/build/.
set -euo pipefail

REL="${1:?usage: check.sh <module-dir> [stem]}"
MOD="${2:-$(basename "$REL")}"
SRC="modules/$REL"
OUT="$SRC/build"
mkdir -p "$OUT"

# DRC with --refill-zones --save-board rewrites the board with filled copper.
# Work on a copy so the module directory stays exactly what pcbgen produced
# and regeneration never shows spurious diffs. The filled board in build/ is
# what KiKit and the renders use.
DIR="$OUT"
for ext in kicad_sch kicad_pcb kicad_pro kicad_dru; do
  [ -f "$SRC/$MOD.$ext" ] && cp "$SRC/$MOD.$ext" "$DIR/"
done

if [ -n "${KICAD_CLI:-}" ]; then
  KCLI="$KICAD_CLI"
elif command -v kicad-cli >/dev/null 2>&1; then
  KCLI="kicad-cli"
else
  for c in "$LOCALAPPDATA/Programs/KiCad/10.0/bin/kicad-cli.exe" \
           "/c/Program Files/KiCad/10.0/bin/kicad-cli.exe"; do
    if [ -x "$c" ]; then KCLI="$c"; break; fi
  done
fi
: "${KCLI:?kicad-cli not found; set KICAD_CLI}"

status=0

echo "== ERC"
if "$KCLI" sch erc --exit-code-violations --severity-all \
     -o "$OUT/erc.rpt" "$DIR/$MOD.kicad_sch"; then
  echo "   ERC clean"
else
  status=1; sed -n '/^\[/,/^$/p' "$OUT/erc.rpt" | head -60
fi

echo "== DRC (refill zones, save board, schematic parity)"
if "$KCLI" pcb drc --refill-zones --save-board --schematic-parity \
     --exit-code-violations --severity-all \
     -o "$OUT/drc.rpt" "$DIR/$MOD.kicad_pcb"; then
  echo "   DRC clean"
else
  status=1
  grep -E '^\[' "$OUT/drc.rpt" | sort | uniq -c | sort -rn
  echo "   full report: $OUT/drc.rpt"
fi

echo "== Renders"
"$KCLI" sch export svg -o "$OUT/" "$DIR/$MOD.kicad_sch" >/dev/null
"$KCLI" pcb export svg --layers "F.Cu,F.SilkS,F.CrtYd,Edge.Cuts" --page-size-mode 2 \
     -o "$OUT/$MOD-front.svg" "$DIR/$MOD.kicad_pcb" >/dev/null
"$KCLI" pcb export svg --layers "B.Cu,B.SilkS,Edge.Cuts" --page-size-mode 2 --mirror \
     -o "$OUT/$MOD-back.svg" "$DIR/$MOD.kicad_pcb" >/dev/null
"$KCLI" pcb render --side top    --width 600 --height 2400 --background opaque \
     -o "$OUT/$MOD-top.png"    "$DIR/$MOD.kicad_pcb" >/dev/null
"$KCLI" pcb render --side bottom --width 600 --height 2400 --background opaque \
     -o "$OUT/$MOD-bottom.png" "$DIR/$MOD.kicad_pcb" >/dev/null
echo "   $OUT/"

exit $status
