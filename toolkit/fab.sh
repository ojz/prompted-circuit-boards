#!/usr/bin/env bash
# Produce the JLCPCB fabrication bundle for a checked module with KiKit.
#
#   toolkit/fab.sh <module-dir> [stem]      e.g. toolkit/fab.sh mult
#                                                toolkit/fab.sh mult/panel
#
# Requires toolkit/check.sh to have run first: KiKit works on the zone-filled
# board in modules/<module-dir>/build/. Output: build/fab/gerbers.zip, plus
# bom.csv and pos.csv when the module has JLCPCB-assembled parts.
#
# KiKit lives in KiCad's bundled Python (pip install kikit from the KiCad
# Command Prompt); KIKIT_PYTHON overrides the interpreter.
set -euo pipefail

# Repository footprint library, referenced as ${PCBGEN_LIB} by each module's
# fp-lib-table. KiCad wants a native Windows path under Git Bash.
if command -v cygpath >/dev/null 2>&1; then
  export PCBGEN_LIB="$(cygpath -m "$PWD")/lib/footprints"
else
  export PCBGEN_LIB="$PWD/lib/footprints"
fi

REL="${1:?usage: fab.sh <module-dir> [stem]}"
MOD="${2:-$(basename "$REL")}"
BUILD="modules/$REL/build"
OUT="$BUILD/fab"

if [ -n "${KIKIT_PYTHON:-}" ]; then
  PY="$KIKIT_PYTHON"
else
  for c in "$LOCALAPPDATA/Programs/KiCad/10.0/bin/python.exe" \
           "/c/Program Files/KiCad/10.0/bin/python.exe"; do
    if [ -x "$c" ]; then PY="$c"; break; fi
  done
fi
: "${PY:?KiCad python.exe not found; set KIKIT_PYTHON}"

[ -f "$BUILD/$MOD.kicad_pcb" ] || { echo "run toolkit/check.sh $REL first"; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT"

# Only request assembly files when some part carries an LCSC Part # field.
# Parts without one (jacks, pots, the power header) are hand-soldered; pcbgen
# marks their footprints exclude_from_pos_files, which keeps them out of the
# CPL and, through KiKit, out of the assembly BOM. (KiKit's own --ignore
# option crashes KiCad 10's plot bindings, so it is not used.)
ASSEMBLY=()
if grep -q '"LCSC Part #"' "$BUILD/$MOD.kicad_sch" 2>/dev/null; then
  ASSEMBLY=(--assembly --schematic "$BUILD/$MOD.kicad_sch" --field "LCSC Part #" --missingError)
fi

# --no-drc: KiKit's built-in DRC pass crashes in KiCad 10's Python bindings
# (access violation in WriteDRCReport, KiKit 1.8.1). DRC has already run via
# kicad-cli in check.sh, which is the authoritative check anyway.
"$PY" -m kikit.ui fab jlcpcb --no-drc "${ASSEMBLY[@]}" "$BUILD/$MOD.kicad_pcb" "$OUT"
echo
echo "bundle: $OUT/gerbers.zip"
"$PY" -c "import zipfile,sys; [print('  ', n) for n in zipfile.ZipFile(sys.argv[1]).namelist()]" "$OUT/gerbers.zip"
