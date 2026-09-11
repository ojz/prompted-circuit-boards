#!/usr/bin/env bash
# Fault-injection tests for check.sh, fab.sh and sim.sh. Run from the
# repository root; takes a few minutes (two real check.sh runs).
#
#   toolkit/test-scripts.sh
#
# Uses the committed attenuverter module as the fixture. Scratch copies live in
# modules/_tests/scripts-scratch/ and are removed on exit.
#
#   a  check.sh attenuverter passes; check.ok exists and its hashes are right
#   b  a one-byte change to the source .kicad_pcb makes fab.sh refuse
#   b2 a one-byte change to the filled board in build/ makes fab.sh refuse
#   c  a board whose tracks are fattened to 3 mm fails check.sh, a planted
#      check.ok is removed, and none is written
#   d  fab.sh without check.ok refuses and leaves no bundle
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools.sh
. "$HERE/tools.sh"
[ -f pcbgen.cabal ] || { echo "test-scripts.sh: run from the repository root" >&2; exit 2; }

FIXTURE=attenuverter
SCRATCH=modules/_tests/scripts-scratch
LOG="$(mktemp -t pcbgen-test-XXXXXX.log)"
cleanup() { rm -rf "$SCRATCH" "$LOG"; }
trap cleanup EXIT

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); echo "PASS  $*"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL  $*"; }
expect() {  # expect <description> <command...>   (command must succeed)
  local d="$1"; shift
  if "$@"; then pass "$d"; else fail "$d"; fi
}
log_has() { grep -q -- "$1" "$LOG"; }
# Change exactly one byte in place: find <literal> and overwrite the byte
# <index> bytes into it. `sed -i` cannot be used for this - it rewrites the
# whole file and silently drops a byte on the CRLF files pcbgen writes on
# Windows, which turns a one-byte tamper into a two-byte one.
flip_byte() {  # flip_byte <file> <literal> <index-in-literal> <new-byte>
  local off
  off="$(grep -aboF -m1 -e "$2" "$1" | head -1 | cut -d: -f1)"
  [ -n "$off" ] || { echo "flip_byte: '$2' not found in $1" >&2; return 1; }
  printf '%s' "$4" | dd of="$1" bs=1 seek=$((off + $3)) conv=notrunc status=none
}
show_log_tail() { echo "----- last lines of output:"; tail -n 15 "$LOG" | sed 's/^/  | /'; }

rm -rf "$SCRATCH"
mkdir -p "$SCRATCH"

# ---- a: a real check passes and writes a correct check.ok -------------------
echo "== a: toolkit/check.sh $FIXTURE"
if "$HERE/check.sh" "$FIXTURE" > "$LOG" 2>&1; then
  pass "a: check.sh $FIXTURE exits 0"
else
  fail "a: check.sh $FIXTURE exits 0"; show_log_tail
fi
OK="modules/$FIXTURE/build/check.ok"
expect "a: check.ok written" test -f "$OK"
if [ -f "$OK" ]; then
  for key in module stem timestamp kicad-cli git-head git-dirty erc drc renders; do
    expect "a: check.ok has '$key:'" grep -q "^$key: " "$OK"
  done
  expect "a: check.ok records erc clean and drc clean" \
    bash -c "grep -q '^erc: clean\$' '$OK' && grep -q '^drc: clean\$' '$OK'"
  expect "a: check.ok lists sch, pcb, pro, dru sources" \
    bash -c "for e in sch pcb pro dru; do grep -q \"^source [0-9a-f]\\{64\\}  $FIXTURE.kicad_\$e\$\" '$OK' || exit 1; done"
  bad=0
  while read -r kind hash name; do
    case "$kind" in
      source)       f="modules/$FIXTURE/kicad/$name" ;;
      filled-board) f="modules/$FIXTURE/build/$name" ;;
      *) continue ;;
    esac
    [ "$(sha256_file "$f")" = "$hash" ] || { echo "   hash mismatch: $f"; bad=1; }
  done < <(grep -E '^(source|filled-board) ' "$OK")
  expect "a: every hash in check.ok matches the file on disk" test "$bad" = 0
  expect "a: filled board hash differs from the unfilled source (zones were filled)" \
    test "$(sed -n 's/^filled-board \([0-9a-f]*\) .*/\1/p' "$OK")" != "$(grep "^source .*  $FIXTURE.kicad_pcb$" "$OK" | cut -d' ' -f2)"
fi
expect "a: summary block printed" bash -c "grep -q '^== Summary' '$LOG' && grep -q 'result:  checks passed' '$LOG'"

# Scratch copy of the checked module. check.sh/fab.sh address it as
# _tests/scripts-scratch/attenuverter; the file stem stays "attenuverter".
COPY="$SCRATCH/$FIXTURE"
mkdir -p "$COPY"
cp -r "modules/$FIXTURE/kicad" "modules/$FIXTURE/build" "$COPY/"
rm -rf "$COPY/build/fab"
COPY_MOD="_tests/scripts-scratch/$FIXTURE"

# ---- d: no check.ok -> fab.sh refuses ---------------------------------------
echo "== d: fab.sh without check.ok"
NOOK="$SCRATCH/nook/$FIXTURE"
mkdir -p "$NOOK"
cp -r "$COPY/kicad" "$COPY/build" "$NOOK/"
rm -f "$NOOK/build/check.ok"
if "$HERE/fab.sh" "_tests/scripts-scratch/nook/$FIXTURE" > "$LOG" 2>&1; then
  fail "d: fab.sh exits non-zero without check.ok"; show_log_tail
else
  pass "d: fab.sh exits non-zero without check.ok"
fi
expect "d: refusal names check.ok" log_has "REFUSED: no .*check.ok"
expect "d: no fab/ directory left" test ! -e "$NOOK/build/fab"
expect "d: no fab.tmp directory left" bash -c "! ls -d '$NOOK'/build/fab.tmp.* >/dev/null 2>&1"

# ---- b: source changed after check -> fab.sh refuses ------------------------
echo "== b: one-byte change to the source .kicad_pcb"
PCB="$COPY/kicad/$FIXTURE.kicad_pcb"
before="$(sha256_file "$PCB")"
# Flip one byte: the first "(width 0.3)" becomes "(width 0.4)".
flip_byte "$PCB" '(width 0.3)' 9 4
expect "b: the tamper changed exactly one byte" \
  test "$(cmp -l "modules/$FIXTURE/kicad/$FIXTURE.kicad_pcb" "$PCB" | wc -l)" = 1
expect "b: the source hash changed" test "$(sha256_file "$PCB")" != "$before"
if "$HERE/fab.sh" "$COPY_MOD" > "$LOG" 2>&1; then
  fail "b: fab.sh exits non-zero on a changed source"; show_log_tail
else
  pass "b: fab.sh exits non-zero on a changed source"
fi
expect "b: refusal says sources changed since check.sh ran" log_has "sources changed since check.sh ran; rerun toolkit/check.sh $COPY_MOD"
expect "b: refusal names the changed file" log_has "$FIXTURE.kicad_pcb (changed)"
expect "b: no fab/ directory left" test ! -e "$COPY/build/fab"
cp "modules/$FIXTURE/kicad/$FIXTURE.kicad_pcb" "$PCB"

echo "== b2: one-byte change to the filled board in build/"
FILLED="$COPY/build/$FIXTURE.kicad_pcb"
flip_byte "$FILLED" '(width 0.3)' 9 4
if "$HERE/fab.sh" "$COPY_MOD" > "$LOG" 2>&1; then
  fail "b2: fab.sh exits non-zero on a changed filled board"; show_log_tail
else
  pass "b2: fab.sh exits non-zero on a changed filled board"
fi
expect "b2: refusal names the filled board" log_has "build/$FIXTURE.kicad_pcb (changed)"
expect "b2: no fab/ directory left" test ! -e "$COPY/build/fab"
cp "modules/$FIXTURE/build/$FIXTURE.kicad_pcb" "$FILLED"

# Control: with everything restored the same copy must export.
echo "== b3: restored copy exports"
if "$HERE/fab.sh" "$COPY_MOD" > "$LOG" 2>&1; then
  pass "b3: fab.sh exits 0 on the untouched copy"
else
  fail "b3: fab.sh exits 0 on the untouched copy"; show_log_tail
fi
expect "b3: gerbers.zip and manifest.txt produced" \
  bash -c "test -f '$COPY/build/fab/gerbers.zip' && test -f '$COPY/build/fab/manifest.txt'"
expect "b3: manifest hashes every output" \
  bash -c "cd '$COPY/build/fab' && grep '^output ' manifest.txt | awk '{print \$2\"  \"\$3}' | sha256sum -c --quiet"
expect "b3: manifest carries the source hashes from check.ok" \
  bash -c "diff <(grep -E '^(source|filled-board) ' '$COPY/build/check.ok') <(grep -E '^(source|filled-board) ' '$COPY/build/fab/manifest.txt')"

# ---- c: DRC failure -> check.sh fails, removes a planted check.ok -----------
echo "== c: check.sh on a board whose tracks are fattened to 3 mm"
BROKEN="$SCRATCH/drcfail/$FIXTURE"
mkdir -p "$BROKEN/build"
cp -r "modules/$FIXTURE/kicad" "$BROKEN/"
# Fault: widen every routed track to 3.0 mm, which shorts nets and breaks
# clearance all over the board (390 violations on the attenuverter fixture).
# Deleting a track is not a usable fault here: every net is poured as well, so
# the pour keeps its pads connected and DRC stays clean. Retagging a track to
# another net does not work either: KiCad recomputes track nets from the pads
# when it loads the board, so the edit is gone before DRC sees it.
awk 'BEGIN { seg = 0 }
     /^\t\(segment$/ { seg = 1 }
     seg && /^\t\t\(width [0-9.]+\)$/ { sub(/\(width [0-9.]+\)/, "(width 3.0)") }
     /^\t\)$/ { seg = 0 }
     { print }' "modules/$FIXTURE/kicad/$FIXTURE.kicad_pcb" > "$BROKEN/kicad/$FIXTURE.kicad_pcb"
expect "c: the fault was injected (tracks widened to 3 mm)" \
  test "$(grep -c '(width 3\.0)' "$BROKEN/kicad/$FIXTURE.kicad_pcb")" -gt 0
echo "check.ok 1 (planted by test-scripts.sh; must be removed)" > "$BROKEN/build/check.ok"
echo "stale" > "$BROKEN/build/$FIXTURE.kicad_pcb"
if "$HERE/check.sh" "_tests/scripts-scratch/drcfail/$FIXTURE" > "$LOG" 2>&1; then
  fail "c: check.sh exits non-zero on the broken board"; show_log_tail
else
  pass "c: check.sh exits non-zero on the broken board"
fi
expect "c: ERC still clean (only the board was broken)" log_has "ERC:     clean"
expect "c: DRC reported failed" log_has "DRC:     FAILED"
expect "c: summary says no check.ok written" log_has "result:  FAILED (no check.ok written)"
expect "c: planted check.ok removed and none written" test ! -e "$BROKEN/build/check.ok"
expect "c: stale board copy replaced (not the planted 'stale' file)" \
  bash -c "! grep -q '^stale$' '$BROKEN/build/$FIXTURE.kicad_pcb'"
expect "c: drc.rpt kept for diagnosis" test -f "$BROKEN/build/drc.rpt"
if "$HERE/fab.sh" "_tests/scripts-scratch/drcfail/$FIXTURE" > "$LOG" 2>&1; then
  fail "c: fab.sh refuses after the failed check"; show_log_tail
else
  pass "c: fab.sh refuses after the failed check"
fi

echo "== s: sim.sh rejects failed or empty simulations"
SIM_ROOT="$SCRATCH/sim"
mkdir -p "$SIM_ROOT/toolkit" "$SIM_ROOT/bin" "$SIM_ROOT/modules/fixture/sim"
SIM_ROOT="$(cd "$SIM_ROOT" && pwd)"
cp "$HERE/sim.sh" "$SIM_ROOT/toolkit/sim.sh"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$SIM_ROOT/bin/cabal"
cat > "$SIM_ROOT/bin/ngspice" <<'STUB'
#!/usr/bin/env bash
case "$SIM_STUB_MODE" in
  pass) echo 'PASS stub assertion' ;;
  fail) echo 'FAIL stub assertion' ;;
  error) echo 'Error: stub simulator error' >&2 ;;
  empty) : ;;
  exitfail) echo 'PASS stub assertion'; exit 9 ;;
esac
STUB
chmod +x "$SIM_ROOT/bin/cabal" "$SIM_ROOT/bin/ngspice"
printf '%s\n' '* synthetic netlist' > "$SIM_ROOT/modules/fixture/sim/fixture.cir"
sim_expect() {
  local description="$1" mode="$2" expected="$3" diagnostic="$4" status=0
  env PATH="$SIM_ROOT/bin:$PATH" NGSPICE="$SIM_ROOT/bin/ngspice" \
    SIM_STUB_MODE="$mode" bash "$SIM_ROOT/toolkit/sim.sh" fixture > "$LOG" 2>&1 || status=$?
  expect "$description exits $expected" test "$status" = "$expected"
  expect "$description names the result" log_has "$diagnostic"
}
sim_expect "s: no experiment decks" pass 1 "no simulation decks found"
printf '%s\n' '* synthetic experiment' > "$SIM_ROOT/modules/fixture/sim/test.cir"
sim_expect "s: simulator fails despite printing PASS" exitfail 1 "ngspice exited with status 9"
sim_expect "s: simulator reports no assertions" empty 1 "no PASS/FAIL assertions reported"
sim_expect "s: simulator reports an error despite exiting 0" error 1 "ngspice reported a problem"
sim_expect "s: failed assertion" fail 1 "1 decks, 1 failed"
sim_expect "s: successful assertion" pass 0 "1 decks, 0 failed"

echo
echo "== test-scripts.sh: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
