# Shared helpers for toolkit/check.sh, fab.sh and pipeline.sh. Sourced, not run.
#
# All scripts run from the repository root under Git Bash; KiCad's tools are
# located here so every script agrees on which binaries it used.

# Repository footprint library, referenced as ${PCBGEN_LIB} by each module's
# fp-lib-table. KiCad wants a native Windows path under Git Bash.
export_pcbgen_lib() {
  if command -v cygpath >/dev/null 2>&1; then
    export PCBGEN_LIB="$(cygpath -m "$PWD")/lib/footprints"
  else
    export PCBGEN_LIB="$PWD/lib/footprints"
  fi
}

# Print the kicad-cli path, honouring KICAD_CLI. Returns 1 when not found.
find_kicad_cli() {
  if [ -n "${KICAD_CLI:-}" ]; then
    echo "$KICAD_CLI"; return 0
  fi
  if command -v kicad-cli >/dev/null 2>&1; then
    echo "kicad-cli"; return 0
  fi
  local c
  for c in "${LOCALAPPDATA:-}/Programs/KiCad/10.0/bin/kicad-cli.exe" \
           "/c/Program Files/KiCad/10.0/bin/kicad-cli.exe"; do
    if [ -x "$c" ]; then echo "$c"; return 0; fi
  done
  return 1
}

# Print KiCad's bundled python.exe (where KiKit and pcbnew live), honouring
# KIKIT_PYTHON. Returns 1 when not found.
find_kicad_python() {
  if [ -n "${KIKIT_PYTHON:-}" ]; then
    echo "$KIKIT_PYTHON"; return 0
  fi
  local c
  for c in "${LOCALAPPDATA:-}/Programs/KiCad/10.0/bin/python.exe" \
           "/c/Program Files/KiCad/10.0/bin/python.exe"; do
    if [ -x "$c" ]; then echo "$c"; return 0; fi
  done
  return 1
}

# sha256 of one file, hex digest only. GNU coreutils on Windows prefixes the
# digest with a backslash when the path needs escaping; strip it.
sha256_file() {
  sha256sum "$1" | awk '{ sub(/^\\/, "", $1); print $1 }'
}

utc_now() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}
