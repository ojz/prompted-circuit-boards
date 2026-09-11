---
status: "maintained checkpoint"
owner: "the agent completing the latest task"
read_when: "starting a session, after reading AGENTS.md and checking the decision inbox"
update_when: "a validated checkpoint, blocker or next action changes; replace superseded prose"
retire_when: "the project ends or another current-state record takes over; Git is the session archive"
---

# Current Handoff

Updated 2026-09-11 by Claude Fable 5.1 (home laptop), after pulling the work laptop's five commits. This is current state, not an append-only
diary. The roadmap owns priorities, module specs own circuit requirements and
setup owns tool versions and commands. See [README.md](README.md).

## Current Position

- Two module designs exist: the passive mult and dual attenuverter. KiCad
  projects and the attenuverter's simulation netlist come from Haskell.
  Neither module has been built or measured.
- M1/M2's rejection, routing and assembly-intent work is complete for existing
  fixtures. M3 has pinned dependencies but no CI. M4 has nominal attenuverter
  simulations and a derived error budget, but not precision acceptance or a
  reviewed prototype.
- Precision-first design and reuse of proven circuit approaches are settled
  user decisions. The attenuverter's precision error budget is derived in
  [modules/attenuverter/ERROR-BUDGET.md](modules/attenuverter/ERROR-BUDGET.md):
  the 41.8 mV channel-patching shift is one of several datasheet-level defects
  (27 mV worst-case offset, 2.3 % inversion error, unguaranteed ±10 V swing and
  input range, no feedback compensation). The parts/topology choice is waiting
  in [decisions/2026-09-11-attenuverter-precision-parts.md](decisions/2026-09-11-attenuverter-precision-parts.md).
- No purchases are approved. Panel development remains deferred. Joint
  placement/routing is planned, not implemented, and does not replace circuit
  validation. See [ROADMAP.md](ROADMAP.md) for the gates and wishlist.

## Latest Change

- **The toolchain split broke the home laptop, and is fixed.** `cabal.project.freeze`
  (added in `1ea98dc`) pins `base ==4.18.3.0`, which ships only with GHC 9.6.7. The
  home laptop had GHC 9.2.8, so dependency resolution failed before compiling
  anything. On the user's instruction GHC 9.6.7 and cabal 3.18.1.0 were installed
  to match the work laptop rather than widening the pin. SETUP.md had said "GHC 9.2
  or newer", which invited the break; it now says 9.6.7 exactly and why. A freeze
  file is the one change the machine that makes it cannot validate.
- **Lifecycle metadata is YAML frontmatter.** All 17 tracked Markdown files carry
  `status`, `owner`, `read_when`, `update_when`, `retire_when` fenced by `---` at
  the top, replacing the blockquote headers. Generated reports get theirs from
  `frontMatter` in `toolkit/app/Main.hs`, which escapes quotes because the
  regeneration command carries its own when `--out` names a directory with a
  space. `test-scripts.sh` checks the new keys and that the block starts at
  line 1; its custom-bundle check now expects the YAML-escaped command.
- **[JLCPCB.md](JLCPCB.md) records what the fab actually charges for**, read from
  JLCPCB's capability and surcharge pages on 2026-09-11. Vias and trace length cost
  nothing at our size: the attenuverter has 38 drilled holes against a 453-hole
  free allowance. Two real thresholds sit close: the via drill (0.3 mm) is exactly
  on the free boundary, and the board (108 mm) misses the 100 mm cheap tier by
  8 mm. Electrically a via is worth about 0.5 mm of trace at audio; the router
  charges 8 mm. `rcViaCost` is therefore documented as a congestion heuristic in
  AGENTS.md, ROADMAP.md and the BENCH.md caveats, not as a price. Not confirmed
  against an invoice: no order has been placed.
- **Decision B is recorded** in the decision file from the user's conversational
  answer (not a file edit), with their reasoning quoted. ROADMAP.md gains "Cost Is
  Not An Optimisation Target": only market parity against buying a commercial
  module matters. Implementation has not started; see Next Action.
- **Benchmark caveat on Freerouting.** Regenerating BENCH.md moved the attenuverter
  freerouting row from 2.22 to 2.31 mV with no change on our side; grid-astar rows
  were identical. The harness now says freerouting rows are not deterministic and
  only grid-astar rows are the diff.

## Verification

Home laptop, 2026-09-11, GHC 9.6.7 / cabal 3.18.1.0, after this session:

| Check | Result |
|---|---|
| `cabal build exe:pcbgen` | passes with the freeze file (failed on GHC 9.2.8 before the upgrade) |
| `cabal run -v0 pcbgen -- all` | all five projects regenerated; **no KiCad file changed content**; only report frontmatter changed. The one `.kicad_sch` that showed as modified was CRLF-only and was restored |
| `cabal test` | 65/65 passed under the pinned toolchain |
| `toolkit/test-scripts.sh` | 79 passed, 0 failed (77 before, plus two frontmatter-position checks) |
| `toolkit/sim.sh attenuverter` | 6 decks, 0 failed (unchanged circuit) |
| `cabal run pcbgen -- bench` | regenerated; grid-astar rows byte-identical, one freerouting row moved (see above) |
| Frontmatter | 17 files parse with PyYAML; every required key present; every generated report starts at `---` |

Not rerun: `toolkit/check.sh`, the pipelines and the panels, because no design
or KiCad output changed; the field-solver and `nodebudget.py` checks, because
none of their inputs changed. No manufacturing release or physical measurement
was made.

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

- The error budget covers the electrical terms with datasheet evidence; pot
  end resistance and linearity are unpublished and need measurement. Input
  protection, mechanical-fit review, current sourcing at order time and a
  complete first-power-up guide remain outstanding. No hardware has been
  assembled, powered or measured.
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

**Implement option B**, now that the answer is recorded in
[decisions/2026-09-11-attenuverter-precision-parts.md](decisions/2026-09-11-attenuverter-precision-parts.md):
build OPA2197 and REF5050 models from the cited datasheet figures in
`modules/_models/devices.lib` (with input capacitance and common-mode limits),
add the unity-gain input buffer per channel and the 1 M input resistor in
`Attenuverter.hs`, regenerate, extend the decks with the acceptance limits from
the error budget (offset <= 1 mV, interaction <= 0.1 mV, inversion <= 0.3 %,
+/-10 V at 11.4 V rails, phase margin >= 45 deg), run
`toolkit/pipeline.sh attenuverter` and `toolkit/sim.sh attenuverter`, record the
limits in SPEC.md, and retire the decision file.

One placement question for the user, not for the agent: the board is 108 mm tall
and JLCPCB's cheap tier ends at 100 mm. Components reach y = 106.75, so fitting
100 mm means moving panel controls; that is an ergonomics decision. It is the
largest cost lever on the board and has nothing to do with routing.

CI on a runner with KiCad 10 remains owed by M3.
