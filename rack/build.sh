#!/usr/bin/env bash
# Build the VCV Rack plugin and install it into Rack's user plugin directory.
#
#   rack/build.sh [--clean] [--no-install]
#
# Runs from Git Bash or from an MSYS2 shell. VCV's own toolchain is MSYS2, and
# MSYS2's make will not run correctly under Git Bash's runtime -- it cannot
# place its temporary files and every recipe dies with exit 127 -- so if this
# is started outside MSYS2 it re-executes itself inside the MINGW64 environment.
#
# MINGW64, not UCRT64, and the difference is not cosmetic. Rack's Windows build
# links msvcrt.dll; MSYS2's UCRT64 toolchain links the UCRT. Those are two
# separate C runtime heaps, so memory allocated inside libRack and released in
# the plugin is freed against the wrong heap. It compiles, links, loads and
# reports its version quite happily, then segfaults in RtlFreeHeap the first
# time a module widget is built. The check at the end of this script compares
# the two binaries' CRT imports so that never passes silently again.
#
# Overrides, found the way toolkit/check.sh finds kicad-cli:
#   RACK_SDK    path to an unpacked Rack SDK  (default: %LOCALAPPDATA%/Rack-SDK)
#   RACK_USER   Rack's user directory         (default: %LOCALAPPDATA%/Rack2)
#   MSYS2_ROOT  MSYS2 installation            (default: C:/msys64)
#
# Fails closed: a missing tool, a slug or version that disagrees with
# plugin.json, or a failed compile stops the script before anything installs.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() { printf 'rack/build.sh: %s\n' "$*" >&2; exit 1; }

msys_root="${MSYS2_ROOT:-/c/msys64}"

# %LOCALAPPDATA% arrives as a Windows path with backslashes, which bash reads as
# escapes; everything downstream wants the POSIX form.
posix() { [ -z "${1:-}" ] && return 0; cygpath -u "$1" 2>/dev/null || printf '%s' "$1"; }

reexec=0
clean=0
install=1
local_app=""
while [ $# -gt 0 ]; do
  case "$1" in
    --clean) clean=1 ;;
    --no-install) install=0 ;;
    --reexec) reexec=1 ;;
    --local-app) shift; local_app="${1:-}" ;;
    *) die "unknown argument: $1" ;;
  esac
  shift
done
[ -n "$local_app" ] || local_app="$(posix "${LOCALAPPDATA:-}")"

# --- re-enter under MSYS2 if we are not already there ------------------------
# Do not test MSYSTEM to decide this: Git Bash sets MSYSTEM=MINGW64 itself and
# ships no compiler, so that check silently passes in the one shell that cannot
# build. Ask for a working cross-target g++ instead.
# A UCRT64 g++ also reports x86_64-w64-mingw32, so the triple alone is not
# enough to tell the two environments apart. Its sysroot is.
have_toolchain() {
  command -v g++ >/dev/null 2>&1 || return 1
  [ "$(g++ -dumpmachine 2>/dev/null)" = "x86_64-w64-mingw32" ] || return 1
  case "$(command -v g++)" in /mingw64/*|"$msys_root"/mingw64/*) return 0 ;; *) return 1 ;; esac
}
if [ "$reexec" -eq 0 ] && ! have_toolchain; then
  msys_bash="$msys_root/usr/bin/bash.exe"
  [ -x "$msys_bash" ] || die "MSYS2 not found at $msys_root. Install it from msys2.org and
  its MINGW64 toolchain (pacman -S mingw-w64-x86_64-gcc), or set MSYS2_ROOT."
  args=(--reexec --local-app "$local_app")
  [ "$clean" -eq 1 ] && args+=(--clean)
  [ "$install" -eq 0 ] && args+=(--no-install)
  # MSYS2_PATH_TYPE=inherit keeps the Windows PATH, which is where node lives.
  # Its login shell starts in its own home and drops variables it does not know,
  # so the script path is absolute and %LOCALAPPDATA% travels as an argument.
  exec env MSYSTEM=MINGW64 MSYS2_PATH_TYPE=inherit \
       "$msys_bash" -l "$here/build.sh" "${args[@]}"
fi

cd "$here"
[ -n "$local_app" ] || die "could not determine %LOCALAPPDATA%; pass --local-app or set RACK_SDK and RACK_USER."

# --- the SDK ----------------------------------------------------------------
sdk="$(posix "${RACK_SDK:-}")"
if [ -z "$sdk" ]; then
  for candidate in "$local_app/Rack-SDK" "$HOME/Rack-SDK" "/c/Rack-SDK"; do
    [ -f "$candidate/plugin.mk" ] && { sdk="$candidate"; break; }
  done
fi
[ -n "$sdk" ] && [ -f "$sdk/plugin.mk" ] || die "no Rack SDK found. Unpack one and set RACK_SDK:
    curl -LO https://vcvrack.com/downloads/Rack-SDK-2.6.6-win-x64.zip
  Its version must match the installed Rack -- see docs/SETUP.md."
sdk="$(cd "$sdk" && pwd)"

# --- the toolchain ----------------------------------------------------------
command -v g++ >/dev/null 2>&1 || die "no g++ on PATH inside MSYS2 (${MSYSTEM:-?}).
  Install it with: pacman -S mingw-w64-x86_64-gcc"
machine="$(g++ -dumpmachine)"
[ "$machine" = "x86_64-w64-mingw32" ] \
  || die "g++ targets $machine; this Rack needs x86_64-w64-mingw32."

# --- node, for reading plugin.json ------------------------------------------
# MSYS2's login shell does not reliably inherit the Windows PATH, so look in
# the usual install locations as well.
node_bin="$(command -v node 2>/dev/null || true)"
if [ -z "$node_bin" ]; then
  for candidate in "/c/Program Files/nodejs/node.exe" "$local_app/Programs/nodejs/node.exe" "/c/nvm4w/nodejs/node.exe"; do
    [ -x "$candidate" ] && { node_bin="$candidate"; break; }
  done
fi
[ -n "$node_bin" ] || die "node not found; it is what reads plugin.json."

# plugin.mk reads plugin.json with jq, which MSYS2 does not ship. The Makefile
# pins SLUG and VERSION with `override`, so the value is unused -- but without
# something named jq on PATH every build prints a "No such file or directory"
# that looks like a failure and is not. This answers the two queries it makes.
shim="$here/.build-tools"   # outside build/, which `make clean` deletes
mkdir -p "$shim"
cat > "$shim/jq" <<SHIM
#!/usr/bin/env bash
# Minimal stand-in for \`jq -r .<key> <file.json>\`; written by rack/build.sh.
exec "$node_bin" -p "JSON.parse(require('fs').readFileSync(process.argv[2],'utf8'))[process.argv[1].slice(1)]" "\$2" "\$3"
SHIM
chmod +x "$shim/jq"
export PATH="$shim:$PATH"

# --- plugin.json must agree with the Makefile -------------------------------
makefile_slug="$(sed -n 's/^override SLUG := *//p' Makefile)"
makefile_version="$(sed -n 's/^override VERSION := *//p' Makefile)"
json_slug="$("$node_bin" -p "require('./plugin.json').slug")"
json_version="$("$node_bin" -p "require('./plugin.json').version")"
[ "$makefile_slug" = "$json_slug" ] || die "Makefile SLUG '$makefile_slug' != plugin.json '$json_slug'"
[ "$makefile_version" = "$json_version" ] || die "Makefile VERSION '$makefile_version' != plugin.json '$json_version'"

# --- build ------------------------------------------------------------------
printf 'Building %s %s\n' "$json_slug" "$json_version"
printf '  SDK        %s\n' "$sdk"
printf '  toolchain  %s g++ %s\n' "${MSYSTEM:-?}" "$(g++ -dumpversion)"

[ "$clean" -eq 1 ] && make RACK_DIR="$sdk" clean >/dev/null

# The panel SVG, before anything tries to draw it. rack::window::Svg keeps a
# NULL handle when NanoSVG fails and logs "Loaded SVG" regardless, so a bad
# panel surfaces as a segfault in a constructor rather than as a parse error.
mkdir -p build   # `make clean` has just removed it
gcc -O1 -o build/svgcheck.exe tools/svgcheck.c -I"$sdk/dep/include" -lm
./build/svgcheck.exe --expect 240x380 res/*.svg

# The transfer function, which Rack Free cannot be driven headlessly to check.
printf '
'
g++ -std=c++11 -O1 -Wall -Wextra -o build/dsp_test.exe tests/dsp_test.cpp
./build/dsp_test.exe
printf '
'

make -j"$(nproc)" RACK_DIR="$sdk" dist

# --- the plugin and Rack must share a C runtime -----------------------------
# See the note at the top. Compare what each binary imports and refuse to
# install a plugin that would free libRack's memory on the wrong heap.
crt_of() {
  if objdump -p "$1" 2>/dev/null | grep -qi 'DLL Name: *msvcrt\.dll'; then
    printf 'msvcrt'
  elif objdump -p "$1" 2>/dev/null | grep -qi 'DLL Name: *\(api-ms-win-crt\|ucrtbase\)'; then
    printf 'ucrt'
  else
    printf 'unknown'
  fi
}
rack_exe="/c/Program Files/VCV/Rack2Free/Rack.exe"
if [ -f "$rack_exe" ]; then
  rack_crt="$(crt_of "$rack_exe")"
  plugin_crt="$(crt_of plugin.dll)"
  printf '  C runtime  Rack=%s plugin=%s
' "$rack_crt" "$plugin_crt"
  if [ "$rack_crt" != "$plugin_crt" ] || [ "$plugin_crt" = "unknown" ]; then
    die "C runtime mismatch: Rack links $rack_crt, this plugin links $plugin_crt.
  They are separate heaps. The plugin will load and then segfault in
  RtlFreeHeap as soon as a module widget is built -- which the module browser
  does for every installed module, so right-clicking the rack takes Rack down.
  Build in MSYS2's MINGW64 environment (msvcrt), not UCRT64."
  fi
else
  printf '  C runtime  plugin=%s (Rack.exe not found, parity unchecked)
' "$(crt_of plugin.dll)"
fi

# --- install ----------------------------------------------------------------
if [ "$install" -eq 1 ]; then
  user_dir="$(posix "${RACK_USER:-}")"
  [ -n "$user_dir" ] || user_dir="$local_app/Rack2"
  [ -d "$user_dir" ] || die "Rack user directory not found: $user_dir
  Start Rack once, or set RACK_USER."
  target="$user_dir/plugins-win-x64/$json_slug"
  # Install the unpacked directory rather than the .vcvplugin archive: Rack
  # loads either, and an unpacked one is inspectable and removable by hand.
  rm -rf "$target"
  mkdir -p "$(dirname "$target")"
  cp -r "dist/$json_slug" "$target"
  printf '\nInstalled to %s\n' "$target"
  printf 'Restart Rack to load it.\n'
else
  printf '\nBuilt dist/%s (not installed)\n' "$json_slug"
fi
