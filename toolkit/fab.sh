#!/usr/bin/env bash
# Produce the JLCPCB fabrication bundle for a checked module with KiKit.
#
#   toolkit/fab.sh <module> [sub]      e.g. toolkit/fab.sh mult
#                                           toolkit/fab.sh mult panel
#
# Requires a clean toolkit/check.sh run: its check.ok in modules/<module>/build/
# names the sources and the zone-filled board it verified, and this script
# refuses to export when any of them has changed since. Output is built in a
# temporary directory and moved to build/fab/ only after KiKit and the
# assembly checks (toolkit/fabcheck.py) succeed; a failed run leaves no bundle.
#
#   build/fab/gerbers.zip          gerbers + drill
#   build/fab/bom.csv, pos.csv     assembly files, when parts carry LCSC Part #
#   build/fab/manifest.txt         sha256 of every output, source hashes, tool versions
#
# KiKit lives in KiCad's bundled Python (pip install kikit from the KiCad
# Command Prompt); KIKIT_PYTHON overrides the interpreter.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools.sh
. "$HERE/tools.sh"
export_pcbgen_lib

MODULE="${1:?usage: fab.sh <module> [sub]}"
SUB="${2:-}"
MOD="${SUB:-$(basename "$MODULE")}"
SRC="modules/$MODULE/kicad${SUB:+/$SUB}"
BUILD="modules/$MODULE/build${SUB:+/$SUB}"
OUT="$BUILD/fab"
TMP="$BUILD/fab.tmp.$$"
OK="$BUILD/check.ok"
RERUN="rerun toolkit/check.sh $MODULE${SUB:+ $SUB}"

refuse() { echo "fab.sh: REFUSED: $*" >&2; exit 1; }

PY="$(find_kicad_python)" || refuse "KiCad python.exe not found; set KIKIT_PYTHON"
KCLI="$(find_kicad_cli)" || refuse "kicad-cli not found; set KICAD_CLI"

# 1. A clean check must have run on exactly these files.
[ -f "$OK" ] || refuse "no $OK; $RERUN first"
grep -q '^erc: clean$' "$OK" || refuse "$OK does not record a clean ERC; $RERUN"
grep -q '^drc: clean$' "$OK" || refuse "$OK does not record a clean DRC; $RERUN"
[ "$(sed -n 's/^stem: //p' "$OK")" = "$MOD" ] || refuse "$OK belongs to another project (stem $(sed -n 's/^stem: //p' "$OK")); $RERUN"

stale=()
while read -r kind hash name; do
  case "$kind" in
    source)       f="$SRC/$name" ;;
    filled-board) f="$BUILD/$name" ;;
    *) continue ;;
  esac
  if [ ! -f "$f" ]; then
    stale+=("$f (missing)")
  elif [ "$(sha256_file "$f")" != "$hash" ]; then
    stale+=("$f (changed)")
  fi
done < <(grep -E '^(source|filled-board) ' "$OK")
grep -q '^source ' "$OK" || stale+=("$OK lists no sources")
grep -q '^filled-board ' "$OK" || stale+=("$OK lists no filled board")
if [ "${#stale[@]}" -gt 0 ]; then
  printf '   %s\n' "${stale[@]}" >&2
  refuse "sources changed since check.sh ran; $RERUN"
fi
echo "== check.ok verified ($(grep -c '^source ' "$OK") sources + filled board unchanged)"

# 2. Build into a temporary directory. The old bundle goes now: after this
#    point it could only be mistaken for this run's output.
rm -rf "$OUT" "$BUILD"/fab.tmp.*
mkdir -p "$TMP"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

# Only request assembly files when some part carries an LCSC Part # field.
# Parts without one (jacks, pots, the power header) are hand-soldered; pcbgen
# marks their footprints exclude_from_pos_files, which keeps them out of the
# CPL and, through KiKit, out of the assembly BOM. (KiKit's own --ignore
# option crashes KiCad 10's plot bindings, so it is not used.)
ASSEMBLY=()
MODE=--no-assembly
if grep -q '"LCSC Part #"' "$BUILD/$MOD.kicad_sch" 2>/dev/null; then
  ASSEMBLY=(--assembly --schematic "$BUILD/$MOD.kicad_sch" --field "LCSC Part #" --missingError)
  MODE=--assembly
fi

# --no-drc: KiKit's built-in DRC pass crashes in KiCad 10's Python bindings
# (access violation in WriteDRCReport, KiKit 1.8.1). DRC has already run via
# kicad-cli in check.sh, which is the authoritative check anyway.
echo "== KiKit fab jlcpcb ($MODE)"
"$PY" -m kikit.ui fab jlcpcb --no-drc "${ASSEMBLY[@]}" "$BUILD/$MOD.kicad_pcb" "$TMP"

# 3. KiKit must not have touched the checked board.
[ "$(sha256_file "$BUILD/$MOD.kicad_pcb")" = "$(sed -n 's/^filled-board \([0-9a-f]*\) .*/\1/p' "$OK")" ] \
  || refuse "the filled board changed while exporting; $RERUN"

# 4. Assembly and gerber sanity checks.
"$PY" "$HERE/fabcheck.py" "$BUILD/$MOD.kicad_pcb" "$TMP" "$MODE"

# 5. Manifest: every output hashed, the source hashes it derives from, tools.
# A board whose parts are all hand-soldered gets no pos.csv at all, and an
# assembled one may still have a header-only CPL; both are legitimate, so this
# is spelled out instead of `[ -f ... ] && ...`, which `set -e` would treat as
# a failed run.
placements=0
if [ -f "$TMP/pos.csv" ]; then
  placements=$(($(wc -l < "$TMP/pos.csv") - 1))
  [ "$placements" -ge 0 ] || placements=0
fi
kikit_version="$("$PY" -c 'import kikit; print(kikit.__version__)' 2>/dev/null | tr -d '\r' || echo unknown)"
pcbnew_version="$("$PY" -c 'import pcbnew; print(pcbnew.Version())' 2>/dev/null | tr -d '\r' || echo unknown)"
py_version="$("$PY" --version 2>&1 | tr -d '\r' || echo unknown)"
{
  echo "manifest 1"
  echo "module: $MODULE"
  echo "sub: ${SUB:--}"
  echo "stem: $MOD"
  echo "timestamp: $(utc_now)"
  echo "kicad-cli: $("$KCLI" version 2>/dev/null | tr -d '\r' || echo unknown)"
  echo "python: $py_version"
  echo "pcbnew: $pcbnew_version"
  echo "kikit: $kikit_version"
  echo "assembly: ${MODE#--} ($placements placements)"
  echo "check.ok-timestamp: $(sed -n 's/^timestamp: //p' "$OK")"
  echo "git-head: $(sed -n 's/^git-head: //p' "$OK")"
  echo "git-dirty: $(sed -n 's/^git-dirty: //p' "$OK")"
  grep -E '^(source|filled-board) ' "$OK"
  # Every output except the manifest itself, which is still being written and
  # cannot contain its own hash. Names are relative to build/fab/, so
  #   cd build/fab && grep '^output ' manifest.txt | cut -c8- | sha256sum -c
  # verifies the bundle.
  (cd "$TMP" && find . -type f ! -name manifest.txt | sort | sed 's|^\./||') | while read -r f; do
    echo "output $(sha256_file "$TMP/$f")  $f"
  done
} > "$TMP/manifest.txt"

# 6. Everything passed: publish.
trap - EXIT
mv "$TMP" "$OUT"
echo
echo "bundle: $OUT/gerbers.zip"
"$PY" -c "import zipfile,sys; [print('  ', n) for n in zipfile.ZipFile(sys.argv[1]).namelist()]" "$OUT/gerbers.zip"
if [ -f "$OUT/pos.csv" ]; then
  echo "assembly: $OUT/bom.csv, $OUT/pos.csv ($placements placements)"
fi
echo "manifest: $OUT/manifest.txt"
