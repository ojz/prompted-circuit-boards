# Current Handoff

> Status: maintained checkpoint. Owner: the agent completing the latest task.
> Read when: starting a session, after reading AGENTS.md and checking the decision inbox.
> Update when: a validated checkpoint, blocker or next action changes; replace superseded prose.
> Retire when: the project ends or another current-state record takes over; Git is the session archive.

Updated 2026-09-11 by GitHub Copilot. This is current state, not an append-only
diary. The roadmap owns priorities, module specs own circuit requirements and
setup owns tool versions and commands. See [README.md](README.md).

## Current Position

- Two module designs exist: the passive mult and dual attenuverter. KiCad
  projects and the attenuverter's simulation netlist come from Haskell.
  Neither module has been built or measured.
- M1/M2's rejection, routing and assembly-intent work is complete for existing
  fixtures. M3 still needs CI and dependency/library pinning. M4 has nominal
  attenuverter simulations but not precision acceptance or a reviewed prototype.
- Precision-first design and reuse of proven circuit approaches are settled
  user decisions. The roughly 41.8 mV simulated channel-patching shift is an
  unresolved precision defect; the historical 50 mV test budget does not approve it.
- No purchases are approved. Panel development remains deferred. Joint
  placement/routing is planned, not implemented, and does not replace circuit
  validation. See [ROADMAP.md](ROADMAP.md) for the gates and wishlist.

## Latest Change

- Maintained and generated Markdown now lives under `docs/`, except the root
  README and agent instruction files. Code, decks, KiCad projects and ignored
  build artifacts retain their original locations.
- [decisions/README.md](decisions/README.md) defines an editable inbox for
  researched user choices. Read edited answers before affected work; preserve
  and integrate the decision in the owning spec/roadmap, validate and checkpoint,
  then delete the processed inbox file. Blanks and recommendations are not approval.
  There are no pending questions: precision and circuit reuse are already decided.
- Every document states when to read, update and retire it. The old module
  list, duplicate collaborator handout and obsolete broad tool survey are retired.
  Live ideas are in the roadmap; useful tool cautions and references are in
  [SETUP.md](SETUP.md). Git retains the original discussions and older handoffs.
- The report writer targets `docs/modules/<name>/route-report.md` and
  `docs/BENCH.md`; custom `--out DIR` exports use `DIR/docs/` without changing
  canonical reports. The pipeline also checks the relocated report for drift.
- Benchmark scores and findings are preserved, not rerun or improved. The
  report explanation now qualifies the spanning-tree reference and selected
  legality checks. Circuit topology, routing algorithms and assertion limits
  have not changed. Source/deck comment references were updated.

## Migration Verification

| Check | Result |
|---|---|
| `cabal build exe:pcbgen` | passes with the updated report writer |
| `toolkit/test-scripts.sh` | 77 passed, 0 failed; includes native attenuverter checks, scratch export, simulation stubs, report paths/headers and custom-output isolation |
| `toolkit/pipeline.sh mult` | board and panel ERC/DRC/parity pass; relocated report changes are detected |
| `cabal run -v0 exe:pcbgen -- all` | all five projects generated; three routing reports emitted under docs |
| `toolkit/sim.sh attenuverter` | six decks, 13 assertions pass after updating documentation pointers |
| Document integrity and output comparisons | 14 Markdown files have valid locations/lifecycle headers; 61 local links resolve; generated KiCad content and all three routing results match the prior checkpoint |

The full Freerouting benchmark and expensive Haskell routing test suite were
not rerun for the documentation migration. The report-writer test deliberately
uses an unavailable external router in a scratch directory; it tests reporting,
not routing quality. No manufacturing release or physical measurement was made.

## Earlier Circuit Evidence

Before this migration, on 2026-09-11 the work laptop passed all 65 Haskell
tests, both module pipelines and their panels, and native checks for route-test.
The six attenuverter decks passed 13 assertions. `nodebudget.py verify` agreed
with ngspice to 0.2%; `xsection.py verify --pitch 0.025` passed with maximum
7.4% difference from the closed form (5.9% at 0.3 mm trace width).

Use Git Bash for shell scripts and KiCad's bundled Python for the numerical
checks; [SETUP.md](SETUP.md) records the verified versions and paths. Earlier
fixes include simulation failure rejection in `d8c9001` and precision-first
requirements in `57f1bb8`; home-laptop work was pulled at `b9b5a2b`.

Native reports, renders and `check.ok` manifests live under each module's
ignored `build/`, with panels in `build/panel/`. The Haskell test log is under
`dist-newstyle/build/x86_64-windows/ghc-9.6.7/pcbgen-0.1.0.0/t/pcbgen-test/test/`.
Artifact paths and commands here are relative to the repository root.

SHA-256 of the earlier validation artifacts (filled boards depend on KiCad version):

| Artifact | SHA-256 |
|---|---|
| `modules/attenuverter/build/attenuverter.kicad_pcb` | `a0d681edb2584c6cadb99a9388eb325b04898df8e1b1b622f197036b77b42b10` |
| `modules/mult/build/mult.kicad_pcb` | `0838974db2ab529ac17e138bbf1fb7afb91d5f44c26b490bc8c6ea7dce1e29fe` |
| `modules/attenuverter/sim/attenuverter.cir` | `220bcae4dfc813f2198f468c12f1de0c9afd5370940a1739a94998b97916824d` |

## Remaining Limits

- Exact-part/datasheet verification, a numerical precision error budget,
  mechanical-fit review, current sourcing and a complete first-power-up guide
  remain outstanding. No hardware has been assembled, powered or measured.
- Roughly 0.35 V of nominal headroom is a model prediction, not a worst-case
  guarantee. The low-supply assertion tests a 5 V signal, not +/-10 V. Output
  loading, offset and shared-reference movement matter for pitch use.
- The model does not draw output load current from its rails and omits noise,
  temperature drift and realistic protection/overload behavior. Read
  [../modules/_models/devices.lib](../modules/_models/devices.lib) before relying
  on such effects. The mult has no experiment decks.
- The default 0.0125 mm field-solver check was stopped after more than
  12 CPU-minutes before completing its first width. Only the bounded check
  above was completed here; grid convergence was not repeated.
- No fresh full EMC/thermal or manufacturing review was done. The script
  suite's export is a disposable control, not a retained release or purchase approval.
- Freerouting's standalone default jar path is not configured on this laptop;
  a PCM jar is not automatically found. The recorded benchmark has the fairness,
  coverage and model limitations listed in the roadmap.

## Next Action

Derive the attenuverter's precision error budget and compare established
reference/buffer/attenuverter approaches using exact-part manufacturer evidence.
Cover source/load, gain/offset, channel interaction, noise, drift and headroom
over explicit conditions; express pitch errors in cents. No payment card is
needed. Do not invent circuitry instead of evaluating proven approaches or
weaken limits to pass the existing design.

When the evidence exposes a real cost, scope or architecture choice for the
user, create a focused decision file with options, a recommendation and an
acceptance check. Integrate the answer before implementing that scope. Physical
confirmation remains a later hardware gate; CI/pinning is still owed by M3.