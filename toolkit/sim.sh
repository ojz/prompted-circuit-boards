#!/usr/bin/env bash
# Run a module's circuit simulations and report.
#
#   toolkit/sim.sh <name>
#
# Regenerates the module's SPICE netlist from its design, then runs every
# deck in modules/<name>/sim/ except the netlist itself. A deck echoes lines
# beginning PASS or FAIL; any FAIL, or any ngspice error, fails the run.
#
# What this is and is not. It is evidence about the circuit: component values
# and topology come from the same design the board is generated from, so the
# netlist cannot drift from what gets fabricated. It is not evidence about
# the board: no parasitics, no tolerances unless a deck sweeps them, and
# device models are the hand-built ones in modules/_models/, whose limits are
# written at the top of that file. "Simulated" and "bench-tested" are as
# different as "generated" and "checks passed".
set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/.." && pwd)"
cd "$root"

name="${1:-}"
if [ -z "$name" ]; then
  echo "usage: toolkit/sim.sh <name>" >&2
  exit 2
fi

simdir="modules/$name/sim"
if [ ! -d "$simdir" ]; then
  echo "no simulation directory: $simdir" >&2
  exit 2
fi

# ngspice: the console build, wherever this workstation keeps it.
ngspice="${NGSPICE:-}"
if [ -z "$ngspice" ]; then
  for c in "$LOCALAPPDATA/ngspice/Spice64/bin/ngspice_con.exe" \
           "/c/Spice64/bin/ngspice_con.exe" \
           "$(command -v ngspice_con 2>/dev/null)" \
           "$(command -v ngspice 2>/dev/null)"; do
    if [ -n "$c" ] && [ -x "$c" ]; then ngspice="$c"; break; fi
  done
fi
if [ -z "$ngspice" ]; then
  echo "ngspice not found; set NGSPICE (see SETUP.md)" >&2
  exit 2
fi

echo "== Simulating $name"
echo "   ngspice: $ngspice"

# The netlist is generated, never edited, and regenerated here so a deck can
# never be run against a stale circuit.
if ! cabal run -v0 exe:pcbgen -- spice "$name" >/dev/null; then
  echo "   could not generate the netlist" >&2
  exit 1
fi
echo "   netlist: $simdir/$name.cir (regenerated)"

fails=0
decks=0
for deck in "$simdir"/*.cir; do
  case "$(basename "$deck")" in
    "$name.cir") continue ;;   # the generated netlist, included by the decks
  esac
  decks=$((decks + 1))
  echo
  echo "-- $(basename "$deck")"
  out="$("$ngspice" -b "$deck" 2>&1)"
  # ngspice reports a bad deck on stderr and still exits 0 often enough that
  # its exit code is not worth trusting on its own.
  if printf '%s\n' "$out" | grep -qiE "^ *error|fatal|singular matrix|no such vector"; then
    echo "   ngspice reported a problem:"
    printf '%s\n' "$out" | grep -iE "^ *error|fatal|singular matrix|no such vector" | sed 's/^/     /'
    fails=$((fails + 1))
    continue
  fi
  printf '%s\n' "$out" | grep -E "^(PASS|FAIL)|^---|^idle:" | sed 's/^/   /'
  n=$(printf '%s\n' "$out" | grep -c "^FAIL" || true)
  if [ "$n" -gt 0 ]; then fails=$((fails + n)); fi
done

echo
if [ "$fails" -eq 0 ]; then
  echo "== $name: $decks decks, 0 failed"
  echo "   Simulated, not measured. No board has been built or probed."
  exit 0
else
  echo "== $name: $decks decks, $fails failed"
  exit 1
fi
