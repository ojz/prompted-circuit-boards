---
status: "maintained"
owner: "the agent verifying the workstation"
read_when: "setting up a machine, reproducing checks, or diagnosing a tool mismatch"
update_when: "a verified tool version, command, dependency or integration pitfall changes"
retire_when: "a supported workflow is replaced; remove obsolete recipes after transferring required behavior"
---

# Workstation Setup

This project is developed on Windows with KiCad 10. The versions below are a
known-good baseline, not strict pins unless stated otherwise.

## Required tools

1. Install KiCad 10. The per-user installer puts it in
   `%LOCALAPPDATA%\Programs\KiCad\10.0`, the machine-wide one in
   `C:\Program Files\KiCad\10.0`. Adding its `bin` directory to `PATH` is
   convenient but not required: `toolkit/check.sh` finds `kicad-cli` in either
   location, or honours `KICAD_CLI`.
2. Install the Haskell toolchain with [ghcup](https://www.haskell.org/ghcup/):
   **GHC 9.6.7 specifically**, and cabal 3.10 or newer:
   ```
   ghcup install ghc 9.6.7 && ghcup set ghc 9.6.7
   ```
   The version is not a recommendation. `cabal.project.freeze` pins
   `base ==4.18.3.0`, which ships only with GHC 9.6.7, so any other GHC fails
   dependency resolution before compiling anything. Both workstations must
   match. Then, once, from the repository root:
   ```
   cabal update
   cabal build
   ```
   This builds `pcbgen`, which generates every KiCad project in `modules/`.
   `cabal.project.freeze` pins every dependency version, so a fresh checkout
   resolves the same set; only run `cabal freeze` again when a dependency
   change is intended, and commit the result. A freeze file is the one kind of
   change the machine that makes it cannot validate: it constrains the *other*
   workstation's compiler. Re-pinning means checking both machines still build.
3. Install KiKit into KiCad's own Python. Open **KiCad 10 Command Prompt** from
   the Start menu (an ordinary shell will not see KiCad's Python) and run:
   ```
   pip install kikit
   kikit --help
   ```
   KiKit 1.8.0 or newer is required for KiCad 10.
4. ngspice is required for `toolkit/sim.sh` and for re-deriving analog budgets
   in `toolkit/nodebudget.py`; generation and native ERC/DRC do not need it. KiCad ships
   only `ngspice.dll` for its internal simulator, there is no batch
   executable in it, and ngspice is not in winget, so fetch the console
   build from the [ngspice
   downloads](https://sourceforge.net/projects/ngspice/files/ng-spice-rework/)
   (`ngspice-47_64.7z`; the verified copy has sha256
   `59225971bd68cdd1199443649aa4615a9e6d684933f205ab49006a3942518f5a`) and
   unpack its `Spice64` directory to `%LOCALAPPDATA%\ngspice`. Windows'
   built-in `tar.exe` reads .7z, so no archiver is needed. The scripts look
   there, on `PATH`, and at `NGSPICE`.

   SourceForge can return an HTML download page with a successful HTTP status.
   This PowerShell download worked on the work laptop; compare its SHA-256
   with the value above before extracting or executing anything:
   ```powershell
   curl.exe --fail --location --user-agent "Wget/1.21.4" --output "$env:TEMP\ngspice-47_64.7z" "https://downloads.sourceforge.net/project/ngspice/ng-spice-rework/47/ngspice-47_64.7z?download=1"
   Get-FileHash "$env:TEMP\ngspice-47_64.7z" -Algorithm SHA256
   ```

   Check the installed console build with:
   ```
   "%LOCALAPPDATA%\ngspice\Spice64\bin\ngspice_con.exe" --version
   python toolkit/nodebudget.py verify
   ```
   Then run `toolkit/sim.sh attenuverter` from Git Bash. Its experiment
   assertions must pass. The runner rejects nonzero simulator exits, error
   diagnostics, missing assertions and an empty set of experiment decks.
   `toolkit/xsection.py` needs numpy rather than ngspice; KiCad's bundled
   Python has it, so run that one the way `freeroute.py` is run. For a bounded
   workstation check use `toolkit/xsection.py verify --pitch 0.025`; the
   default 0.0125 mm grid takes substantially longer. A coarse-grid pass is
   not a substitute for a refinement study when changing the field solver.
5. Optional: Freerouting from KiCad's Plugin and Content Manager plus a Java 25
   runtime on `PATH` (the verified setup uses the Temurin 25 JRE). It is the
   routing benchmark's parity baseline, not part of generation; pcbgen routes
   the boards itself. The headless adapter needs `FREEROUTING_JAR` pointing to
   the installed jar, or a copy named `freerouting-2.4.1.jar` in
   `%LOCALAPPDATA%/freerouting`. A PCM install alone does not configure that
   path. Leave telemetry disabled; do not use a cloud routing endpoint as a
   substitute for the local comparison.
6. Optional: the global [kicad-happy](https://github.com/aklofas/kicad-happy)
   agent skills for design review.

## Local configuration

On the work laptop, bare `bash` resolves to the WSL launcher and bare `python`
to MSYS2. Use Git Bash explicitly from PowerShell:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' toolkit/pipeline.sh mult
& 'C:\Program Files\KiCad\10.0\bin\python.exe' toolkit/nodebudget.py verify
```

The Python path differs for a per-user KiCad install. Do not change project
source to compensate for choosing the wrong interpreter.

Nothing in the normal workflow needs the KiCad GUI: designs are generated by
`pcbgen` and checked by `kicad-cli`, and the GUI is only a viewer. Never save a
generated project from the GUI.

Modules that use a footprint from the repository's own library
(`lib/footprints/pcbgen.pretty`, e.g. the 7.2 mm pot hole on a panel) carry an
`fp-lib-table` that refers to `${PCBGEN_LIB}`. `toolkit/check.sh` and
`toolkit/fab.sh` export that variable themselves. To open such a project in
the KiCad GUI without a missing-library warning, add `PCBGEN_LIB` under
`Preferences > Configure Paths`, pointing at `<repo>/lib/footprints`.

`pcbgen` finds KiCad's libraries in the standard install locations;
`PCBGEN_KICAD_SHARE` overrides the `share/kicad` directory.

## Verify the installation

`toolkit/pipeline.sh` is the single entry point: tool preflight, generation,
ERC, DRC with zone refill and schematic parity, renders, and with `--fab` the
JLCPCB bundle. Run both of these from the repository root:

```
toolkit/pipeline.sh mult
toolkit/pipeline.sh attenuverter --fab
```

Each ends with a status table; every row must read `PASS` (or `SKIPPED (no
--fab)`) and the exit status must be 0. Renders are reported separately and
never decide the result. `pipeline.sh` also reports regeneration differences
in `modules/<name>/kicad/` and `docs/modules/<name>/route-report.md`. Unchanged
input should reproduce the committed content after Git line-ending
normalization. A change is reported for review, not silently accepted as
equivalent. Custom `pcbgen <name> --out DIR` bundles put their report in
`DIR/docs/route-report.md` without changing the canonical report.

The stages are available on their own too:

```
cabal run pcbgen -- mult       # generate    -> modules/mult/kicad/
toolkit/check.sh mult          # ERC + DRC   -> modules/mult/build/
toolkit/check.sh mult panel    # the front panel project
toolkit/fab.sh attenuverter    # JLCPCB      -> modules/attenuverter/build/fab/
```

`check.sh` writes `modules/<name>/build/[panel/]check.ok` only when both ERC
and DRC are clean; it records the tool versions, the git provenance and the
sha256 of every source file and of the zone-filled board it checked. `fab.sh`
refuses to export unless that manifest is there and every hash still matches,
builds into a temporary directory, and publishes `build/fab/` only after KiKit
and the assembly checks (`toolkit/fabcheck.py`) pass. `build/fab/manifest.txt`
then carries the sha256 of every output; verify a bundle with:

```
cd modules/attenuverter/build/fab && grep '^output ' manifest.txt | cut -c8- | sha256sum -c
```

To verify the scripts rather than a module, `toolkit/test-scripts.sh`
fault-injects the attenuverter fixture - a single tampered source byte, a
tampered filled board, a missing `check.ok`, and a board whose tracks are
widened until DRC fails - and exercises the simulation runner with isolated
stubs. It also builds the generator and checks default/custom report locations,
lifecycle headers, and preservation of the canonical report in scratch fixtures.
It must end in `0 failed`. It takes a few minutes and removes its scratch copies
on exit; the simulator failure tests do not need ngspice.

Expected tool versions:

```text
KiCad CLI 10.0.x
GHC 9.6.7 exactly, cabal 3.10 or newer
KiKit 1.8.1 on KiCad's bundled Python 3.11.5
```

KiCad patch versions may differ; the compatibility requirement is KiCad 10.
**GHC is the exception and is pinned exactly**, for the reason in step 2.

Work-laptop verification on 2026-09-11: KiCad CLI 10.0.3, GHC 9.6.7,
cabal 3.14.2.0, KiKit 1.8.1, bundled Python 3.11.5, NumPy 2.4.2 and ngspice 47.
Home laptop ran GHC 9.2.8 until 2026-09-11, when the freeze file made the
project unbuildable there and it was upgraded to 9.6.7 to match. Current
results and reproduction gaps are recorded only in [HANDOFF.md](HANDOFF.md).

## Known Development Traps

- `cabal build` does not rebuild the test suite. Use `cabal test` or
   `cabal build pcbgen-test` before trusting a test binary.
- The SPICE emitter preserves supply-node signs and checks collisions. A diode's
   symbol pin numbering is not SPICE element order: verify polarity against the
   symbol and actual part evidence, not a remembered convention. Regressions
   belong in [../toolkit/test/SpiceTests.hs](../toolkit/test/SpiceTests.hs).
- ngspice `reset` replaces the current plot. Use shell variables to retain
   earlier measurements across reset, as the existing interaction deck does.
- A patch-cable experiment must both open the jack's normalling contact and
   connect its source. Doing only one can create a different circuit.
- Phase lag and amplitude error are different quantities. Assert the behavior
   the requirement actually specifies, and retain the other result as context.
- The hand-built models document what they omit in
   [../modules/_models/devices.lib](../modules/_models/devices.lib). In particular,
   output load current is not drawn from the modeled supply rails; do not infer
   loaded power consumption, temperature drift or protection from these models.

## Reference Entry Points

These are navigation aids, not a completed datasheet or capability audit.
Read them for a concrete task and recheck the relevant version before relying
on a changing tool claim. The obsolete broad tool survey has been retired.

- [KiCad CLI documentation](https://docs.kicad.org/master/en/cli/cli.html)
- [KiCad IPC boundaries](https://dev-docs.kicad.org/en/apis-and-binding/ipc-api/for-addon-developers/index.html)
- [Freerouting source and releases](https://github.com/freerouting/freerouting)
- [JLCPCB KiCad BOM/CPL guide](https://jlcpcb.com/help/article/how-to-generate-the-bom-and-centroid-file-from-kicad)
- [Doepfer mechanical construction notes](https://doepfer.de/a100_man/a100m_e.htm)
- [atopile documentation](https://docs.atopile.io/) and [tscircuit documentation](https://docs.tscircuit.com/), only for an approved, bounded alternative-tool evaluation.

## Development utilities

The current workstation also has Git, Go, Python, Node.js/npm/NVM, .NET,
ripgrep, CMake, GitHub CLI, GitLab CLI, jq, SQLite, and Bun on `PATH`. These are
useful for development and automation but are not all required to edit and
verify a KiCad module.

Do not commit installed plugins, JARs, fabrication output, or other binaries.
