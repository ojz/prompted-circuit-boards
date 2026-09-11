#!/usr/bin/env bash
# The single entry point: preflight, generate, check, and optionally export.
#
#   toolkit/pipeline.sh <module> [--fab]     e.g. toolkit/pipeline.sh mult
#                                                 toolkit/pipeline.sh attenuverter --fab
#
# Steps, in order, each reported PASS / FAIL / SKIPPED in the final table:
#
#   preflight       cabal, kicad-cli; with --fab also KiCad python + KiKit
#   generated       cabal run pcbgen -- <module>   (and <module>-panel when
#                   modules/<module>/kicad/panel exists)
#   checks passed   toolkit/check.sh <module>      (and ... <module> panel)
#   exported        toolkit/fab.sh <module>        (only with --fab, and only
#                   after every check passed)
#
# Exit status is non-zero when any step failed. "Checks passed" means ERC,
# DRC with zone refill and schematic parity, and (with --fab) the fabrication
# sanity checks passed; it does not make the module a reviewed prototype
# candidate, which is a separate human/agent review step (docs/ROADMAP.md, M4).
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools.sh
. "$HERE/tools.sh"

usage() { echo "usage: toolkit/pipeline.sh <module> [--fab]" >&2; exit 2; }
MODULE=""
FAB=0
for a in "$@"; do
  case "$a" in
    --fab) FAB=1 ;;
    -*) usage ;;
    *) [ -z "$MODULE" ] || usage; MODULE="$a" ;;
  esac
done
[ -n "$MODULE" ] || usage
[ -f pcbgen.cabal ] || { echo "pipeline.sh: run from the repository root" >&2; exit 2; }
[ -d "modules/$MODULE" ] || { echo "pipeline.sh: no modules/$MODULE" >&2; exit 2; }
HAS_PANEL=0
[ -d "modules/$MODULE/kicad/panel" ] && HAS_PANEL=1

ROWS=()
FAILED=0
row() {  # row <stage> <command> <status>
  ROWS+=("$(printf '   %-15s %-38s %s' "$1" "$2" "$3")")
  case "$3" in FAIL*) FAILED=1 ;; esac
}
banner() { echo; echo "==== [$1] $2"; }

# ---- preflight -------------------------------------------------------------
banner preflight "tool versions"
missing=()
if command -v cabal >/dev/null 2>&1; then
  echo "   cabal:     $(cabal --version 2>/dev/null | head -1)"
else
  missing+=("cabal (Haskell build tool; see docs/SETUP.md)")
fi
if KCLI="$(find_kicad_cli)"; then
  echo "   kicad-cli: $("$KCLI" version 2>/dev/null | tr -d '\r') ($KCLI)"
else
  missing+=("kicad-cli (KiCad 10; set KICAD_CLI or install to the default location)")
fi
if [ "$FAB" = 1 ]; then
  if PY="$(find_kicad_python)"; then
    echo "   python:    $("$PY" --version 2>&1 | tr -d '\r') ($PY)"
    if kv="$("$PY" -c 'import kikit; print(kikit.__version__)' 2>/dev/null | tr -d '\r')"; then
      echo "   kikit:     $kv"
    else
      missing+=("kikit (pip install kikit from the KiCad Command Prompt)")
    fi
    "$PY" -c 'import pcbnew' 2>/dev/null || missing+=("pcbnew python bindings (KiCad's bundled python)")
  else
    missing+=("KiCad python.exe (set KIKIT_PYTHON)")
  fi
fi
if [ "${#missing[@]}" -gt 0 ]; then
  echo "pipeline.sh: missing tools:" >&2
  printf '   - %s\n' "${missing[@]}" >&2
  row preflight "tool versions" "FAIL (missing: ${#missing[@]})"
  echo; echo "== pipeline status: $MODULE"; printf '%s\n' "${ROWS[@]}"
  exit 2
fi
row preflight "tool versions" PASS

# ---- generate --------------------------------------------------------------
GEN_OK=1
generate() {  # generate <design>
  banner generated "cabal run pcbgen -- $1"
  if cabal run -v1 pcbgen -- "$1"; then
    row generated "pcbgen $1" PASS
  else
    row generated "pcbgen $1" FAIL
    GEN_OK=0
  fi
}
generate "$MODULE"
[ "$HAS_PANEL" = 1 ] && generate "$MODULE-panel"
if [ "$GEN_OK" = 1 ] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  # git diff / ls-files rather than git status: the diff machinery applies the
  # `* text=auto eol=lf` filter from .gitattributes, and pcbgen writes CRLF on
  # Windows, which git status reports as a change on every single run even
  # though the committed content is byte-identical.
  generated_paths=("modules/$MODULE/kicad" "docs/modules/$(basename "$MODULE")/route-report.md")
  changed="$( { git diff --name-only -- "${generated_paths[@]}"
                git ls-files --others --exclude-standard -- "${generated_paths[@]}"; } 2>/dev/null )"
  if [ -n "$changed" ]; then
    echo "   note: regeneration changed project files or the routing report (review and commit):"
    echo "$changed" | sed 's/^/     /'
  else
    echo "   regenerated files match the committed project"
  fi
fi

# ---- check -----------------------------------------------------------------
CHECK_OK=1
check() {  # check <sub-or-empty>
  local label="check.sh $MODULE${1:+ $1}"
  if [ "$GEN_OK" != 1 ]; then
    row "checks passed" "$label" "SKIPPED (generation failed)"
    CHECK_OK=0
    return
  fi
  banner "checks passed" "toolkit/check.sh $MODULE${1:+ $1}"
  if "$HERE/check.sh" "$MODULE" ${1:+"$1"}; then
    row "checks passed" "$label" PASS
  else
    row "checks passed" "$label" FAIL
    CHECK_OK=0
  fi
}
check ""
[ "$HAS_PANEL" = 1 ] && check panel

# ---- export ----------------------------------------------------------------
if [ "$FAB" = 1 ]; then
  if [ "$CHECK_OK" = 1 ]; then
    banner exported "toolkit/fab.sh $MODULE"
    if "$HERE/fab.sh" "$MODULE"; then
      row exported "fab.sh $MODULE" PASS
    else
      row exported "fab.sh $MODULE" FAIL
    fi
  else
    row exported "fab.sh $MODULE" "SKIPPED (a check failed)"
  fi
else
  row exported "fab.sh $MODULE" "SKIPPED (no --fab)"
fi

# ---- status ----------------------------------------------------------------
echo
echo "== pipeline status: $MODULE"
printf '   %-15s %-38s %s\n' stage step status
printf '%s\n' "${ROWS[@]}"
if [ "$FAILED" = 1 ]; then
  echo "   overall: FAILED"
  exit 1
fi
if [ "$FAB" = 1 ]; then
  echo "   overall: generated, checks passed, exported -> modules/$MODULE/build/fab/"
else
  echo "   overall: generated, checks passed (not exported; add --fab)"
fi
echo "   This is not a reviewed prototype candidate; design review is a separate step."
exit 0
