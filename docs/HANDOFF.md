# Current Handoff

> Status: maintained checkpoint. Owner: the agent completing the latest task.
> Read when: starting a session, after reading AGENTS.md and checking the decision inbox.
> Update when: a validated checkpoint, blocker or next action changes; replace superseded prose.
> Retire when: the project ends or another current-state record takes over; Git is the session archive.

Updated 2026-09-11 by Claude (home laptop). This is current state, not an append-only
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

- The attenuverter error budget exists, derived from datasheets fetched on
  2026-09-11 (TI SLOS080W, SBOS737C, SBOS410G; UNI-ROYAL and Yageo resistor
  listings; the Taiwan Alpha RD901F sheet) and from the Mutable Instruments
  Shades v4.0 BOM and Befaco Dual Attenuverter v2 guide as reference designs.
  Limits are proposed in volts and cents; nothing is implemented yet.
- One decision is pending: option A (OPA2197, 0.1 % thin film, REF5050A, 10 pF
  compensation, same topology) or option B (A plus a unity-gain input buffer per
  channel, recommended). Both are costed from LCSC at quantity 10.
- `cabal.project.freeze` pins the Haskell dependency set (M3 pinning item).
  CI is still open.
- The generated routing report now says that matched-group lengths include
  1.6 mm per via, which explains why they differ from the table above them.
  The attenuverter's source comments and schematic note give the simulated
  4.67 V reference instead of the 4.8 V arithmetic; the schematic text changed
  accordingly and ERC/DRC were rerun.
- The documentation consolidation of the previous session (everything under
  `docs/`, lifecycle headers, decision inbox, relocated generated reports) is
  unchanged; Git history has its details.

## Verification

Home laptop, 2026-09-11, after the error-budget session:

| Check | Result |
|---|---|
| `cabal build exe:pcbgen` | passes with the report wording change |
| `cabal run -v0 pcbgen -- all` | all five projects regenerated; only the attenuverter schematic note text and the matched-group wording in its routing report changed; mult and route-test reproduced byte for byte |
| `toolkit/check.sh attenuverter` | ERC clean, DRC clean with parity, `check.ok` written |
| `cabal test` | 65/65 passed |
| `toolkit/sim.sh attenuverter` | 6 decks, 0 failed (unchanged circuit; the decks still assert the historical limits) |
| Markdown integrity | 16 tracked Markdown files carry lifecycle headers; every relative link resolves |

Not rerun this session: `toolkit/test-scripts.sh`, the mult pipeline, the
panels and the Freerouting benchmark; none of their inputs changed. The
previous session's run of those (77 script checks passed, mult board and panel
clean) stands. No manufacturing release or physical measurement was made.

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

Read the user's answer in
[decisions/2026-09-11-attenuverter-precision-parts.md](decisions/2026-09-11-attenuverter-precision-parts.md).
Then, for the chosen option: build OPA2197 and REF5050 models from the cited
datasheet figures in `modules/_models/devices.lib` (with input capacitance and
common-mode limits), change `Attenuverter.hs`, regenerate, extend the decks with
the acceptance limits from the error budget (offset ≤ 1 mV, interaction
≤ 0.1 mV, inversion ≤ 0.3 %, ±10 V at 11.4 V rails, phase margin ≥ 45°), run
`toolkit/pipeline.sh attenuverter` and `toolkit/sim.sh attenuverter`, record the
limits in SPEC.md, and retire the decision file. If the answer is blank, do the
model-building, which both options need, and leave the design untouched.

CI on a runner with KiCad 10 remains owed by M3.