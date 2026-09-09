#!/usr/bin/env bash
# Headless verification of a generated module: ERC, DRC with zone refill and
# schematic parity, then renders. Fails closed: a previous check.ok is removed
# before anything runs and a new one is written only when ERC and DRC are both
# clean. Renders are optional and never change the result.
#
#   toolkit/check.sh <module> [sub]     e.g. toolkit/check.sh mult
#                                            toolkit/check.sh mult panel
#
# <module> is a directory under modules/ whose generated project lives in
# modules/<module>/kicad/; <sub> selects a sub-project such as the front
# panel in modules/<module>/kicad/<sub>/. Run from the repository root.
# Output lands in modules/<module>/build/[<sub>/]:
#
#   <stem>.kicad_*   copy of the project; the .kicad_pcb is the zone-filled board
#   erc.rpt, drc.rpt reports (kept after a failure for diagnosis)
#   *.svg, *.png     renders (optional)
#   check.ok         manifest, present only after a clean run; fab.sh needs it
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools.sh
. "$HERE/tools.sh"
export_pcbgen_lib

MODULE="${1:?usage: check.sh <module> [sub]}"
SUB="${2:-}"
MOD="${SUB:-$(basename "$MODULE")}"
SRC="modules/$MODULE/kicad${SUB:+/$SUB}"
OUT="modules/$MODULE/build${SUB:+/$SUB}"

[ -d "$SRC" ] || { echo "check.sh: no generated project in $SRC (run cabal run pcbgen -- ...)" >&2; exit 2; }
[ -f "$SRC/$MOD.kicad_sch" ] || { echo "check.sh: $SRC/$MOD.kicad_sch missing" >&2; exit 2; }
[ -f "$SRC/$MOD.kicad_pcb" ] || { echo "check.sh: $SRC/$MOD.kicad_pcb missing" >&2; exit 2; }

KCLI="$(find_kicad_cli)" || { echo "check.sh: kicad-cli not found; set KICAD_CLI" >&2; exit 2; }

mkdir -p "$OUT"

# Fail closed: nothing from an earlier run may be mistaken for this run's
# result. The previous manifest, the copied project (including the old filled
# board) and any fabrication bundle built from it go first. erc.rpt/drc.rpt are
# overwritten below and may stay for diagnosis if kicad-cli dies early.
rm -f "$OUT/check.ok" "$OUT/fp-lib-table"
for ext in kicad_sch kicad_pcb kicad_pro kicad_dru kicad_prl; do
  rm -f "$OUT/$MOD.$ext"
done
rm -rf "$OUT/fab" "$OUT"/fab.tmp*

# DRC with --refill-zones --save-board rewrites the board with filled copper.
# Work on a copy so the module directory stays exactly what pcbgen produced
# and regeneration never shows spurious diffs. The filled board in build/ is
# what KiKit and the renders use.
COPIED=()
for f in "$MOD.kicad_sch" "$MOD.kicad_pcb" "$MOD.kicad_pro" "$MOD.kicad_dru" fp-lib-table; do
  if [ -f "$SRC/$f" ]; then
    cp "$SRC/$f" "$OUT/"
    COPIED+=("$f")
  fi
done

erc=FAILED
drc=FAILED
renders=ok

echo "== ERC"
if "$KCLI" sch erc --exit-code-violations --severity-all \
     -o "$OUT/erc.rpt" "$OUT/$MOD.kicad_sch"; then
  erc=clean
  echo "   ERC clean"
else
  echo "   ERC FAILED"
  if [ -f "$OUT/erc.rpt" ]; then
    sed -n '/^\[/,/^$/p' "$OUT/erc.rpt" | head -60
    echo "   full report: $OUT/erc.rpt"
  fi
fi

echo "== DRC (refill zones, save board, schematic parity)"
if "$KCLI" pcb drc --refill-zones --save-board --schematic-parity \
     --exit-code-violations --severity-all \
     -o "$OUT/drc.rpt" "$OUT/$MOD.kicad_pcb"; then
  drc=clean
  echo "   DRC clean"
else
  echo "   DRC FAILED"
  if [ -f "$OUT/drc.rpt" ]; then
    grep -E '^\[' "$OUT/drc.rpt" | sort | uniq -c | sort -rn
    echo "   full report: $OUT/drc.rpt"
  fi
fi

# Renders are diagnostics for humans. A failing render is reported but must
# not turn a clean ERC/DRC into a failure or hide a real one.
echo "== Renders"
render() {
  if ! "$KCLI" "$@" >/dev/null 2>"$OUT/render.err"; then
    renders=FAILED
    echo "   render FAILED: $*"
    sed 's/^/     /' "$OUT/render.err" | head -10
  fi
}
render sch export svg -o "$OUT/" "$OUT/$MOD.kicad_sch"
render pcb export svg --layers "F.Cu,F.SilkS,F.CrtYd,Edge.Cuts" --page-size-mode 2 \
     -o "$OUT/$MOD-front.svg" "$OUT/$MOD.kicad_pcb"
render pcb export svg --layers "B.Cu,B.SilkS,Edge.Cuts" --page-size-mode 2 --mirror \
     -o "$OUT/$MOD-back.svg" "$OUT/$MOD.kicad_pcb"
# Square frame: kicad-cli fits the whole board inside it whatever its aspect.
render pcb render --side top    --width 1600 --height 1600 --background opaque \
     -o "$OUT/$MOD-top.png"    "$OUT/$MOD.kicad_pcb"
render pcb render --side bottom --width 1600 --height 1600 --background opaque \
     -o "$OUT/$MOD-bottom.png" "$OUT/$MOD.kicad_pcb"
rm -f "$OUT/render.err"
# Spelled out rather than `[ ... ] && echo`: as the last command of a `set -e`
# script that form would abort the run whenever a render failed, and renders
# must never decide the result.
if [ "$renders" = ok ]; then echo "   $OUT/"; fi

# Provenance. A commit id alone says nothing when the tree is dirty.
git_head="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  # Content-level dirtiness. `git diff HEAD` applies the `eol=lf` filter from
  # .gitattributes, so pcbgen writing CRLF on Windows does not make every tree
  # look dirty; `ls-files --others` adds files that are new but not ignored.
  dirt="$(git diff --name-only HEAD 2>/dev/null)$(git ls-files --others --exclude-standard 2>/dev/null)"
  if [ -n "$dirt" ]; then git_dirty=yes; else git_dirty=no; fi
else
  git_dirty=unknown
fi
kcli_version="$("$KCLI" version 2>/dev/null | tr -d '\r' || echo unknown)"

echo "== Summary: $MODULE${SUB:+ $SUB}"
echo "   ERC:     $erc"
echo "   DRC:     $drc (schematic parity included)"
echo "   renders: $renders"
if [ "$erc" = clean ] && [ "$drc" = clean ]; then
  {
    echo "check.ok 1"
    echo "module: $MODULE"
    echo "sub: ${SUB:--}"
    echo "stem: $MOD"
    echo "timestamp: $(utc_now)"
    echo "kicad-cli: $kcli_version"
    echo "git-head: $git_head"
    echo "git-dirty: $git_dirty"
    echo "erc: $erc"
    echo "drc: $drc"
    echo "renders: $renders"
    # Source files as copied from $SRC (names relative to that directory) and
    # the zone-filled board that DRC saved into $OUT. fab.sh recomputes both.
    for f in "${COPIED[@]}"; do
      echo "source $(sha256_file "$SRC/$f")  $f"
    done
    echo "filled-board $(sha256_file "$OUT/$MOD.kicad_pcb")  $MOD.kicad_pcb"
  } > "$OUT/check.ok"
  echo "   result:  checks passed -> $OUT/check.ok"
  exit 0
else
  echo "   result:  FAILED (no check.ok written)"
  exit 1
fi
