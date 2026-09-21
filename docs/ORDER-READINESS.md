---
status: "hold; hardware deferred behind V0; partial review of checkpoint 6f1d417 on 2026-09-14"
owner: "collaborating agents; user approves scope and purchases"
read_when: "considering a prototype order or using the current blocks and first-power-up procedure"
update_when: "a finding is closed with evidence, design or ordering direction changes, or a reviewed quote and release package are available"
retire_when: "all findings are integrated into their owning requirements and a newer reviewed prototype checkpoint supersedes this assessment"
---

# Order Readiness

**Verdict: HOLD. Do not order the current attenuverter as a precision-approved
module, and R1 is not yet an orderable design.** This is a partial engineering
assessment, not a completed fabrication sign-off or a claim of measured behavior.
No design files, part choices or acceptance thresholds were changed by this review.

**Direction update, 2026-09-21:** playable digital prototypes in VCV Rack and
user evaluation of the instrument's function balance now precede new hardware
work. The [V0 gate](ROADMAP.md#v0-playable-digital-modules-and-function-balance-current)
is additional to, not a replacement for, the findings below. Hardware orders
are deferred; credit-card availability is recorded in
[HOMELAB.md](HOMELAB.md#payment-readiness) and grants no purchase approval.
This documentation update adds no circuit-review or physical evidence.

Decision update, 2026-09-14: the R1 connector and mixer answers are now adopted
in [modules/io-mixer/SPEC.md](modules/io-mixer/SPEC.md), and their inbox files are
retired. The later normalling/jack implementation conflict remains in the
[hardware inbox](decisions/2026-09-14-panel-hardware.md); the approved behavior
does not close engineering or release findings. The original review's circuit
evidence remains unchanged.

## What Exists

| Area | Retained hardware baseline, with current planning status |
|---|---|
| Toolchain | Haskell generation, independent native checks, gated local exports and real failure-injection tests work. Haskell dependencies are pinned; CI is still missing. |
| Reusable blocks | Module geometry, protected power entry and buffered attenuverter channel exist. They are not bench-tested blocks. |
| Attenuverter | 28 x 100 mm, 31 components, 24 SMD placements, eight passing characterization decks. Reference-capacitor margin, input protection and loaded pitch performance remain open. |
| Passive mult | 28 x 100 mm, 12 hand-installed jacks plus a solder jumper. Native checks pass. It provides no gain or buffering and cannot establish active-circuit precision. |
| Planned instrument | R1 IO + Mixer, R2 Slope + VCA, R3 Filter + VCA, R4 SSG + Noise, R5 Boolean + Clock are the starting composition for V0, not five finished PCB designs. |
| First order | Deferred behind V0. The earlier plan starts with R1, not five attenuverters; confirm the composition before resuming it. R1's power architecture, circuit, models and board are not implemented. |
| Physical evidence | No board has been built or measured. A lab plan and first-power-up guide exist, but equipment capability and procedures are not fully validated. |

See [ROADMAP.md](ROADMAP.md) for the agreed sequence. No rehearsal order is an
automatic alternative to V0; changing that scope would require an explicit
decision as well as closing its findings and approving its quote.

## Findings Before Ordering

### OR-01: Reference Output Capacitor Margin

**Priority: high. Confidence: high, manufacturer document plus design values.**
U3 is REF5050AIDR. TI SBOS410O, PDF page 26, section 8.4.1 / Figure 8-6,
specifies an output capacitor of 1 to 50 uF for the AI/I grades, with ESR no
greater than 1.5 ohms. C7 is a nominal 1 uF X7R capacitor with +/-10% tolerance.
Its tolerance alone permits 0.9 uF, before DC-bias, temperature and aging effects.
The effective minimum capacitance required by the reference has not been shown.

This is not proof that the present reference will oscillate. It is an unsupported
stability margin that the idealized REF5050 model cannot resolve. The same model
does not simulate the output capacitor's control-loop interaction. Ceramic ESR
is not automatically disallowed by this revision of the datasheet.

**Closure:** choose and document sufficient effective capacitance/ESR over the
operating envelope; check startup and stability with a suitable model or bounded
prototype experiment. Preserve the precision and noise requirements.

### OR-02: Patch Inputs Are Not Protected Against Powered-Off Drive

**Priority: high. Confidence: high, connectivity plus manufacturer limits.**
J1/J3 tips connect directly to the OPA2197 buffer inputs. The 1 Mohm resistors
R9/R10 go from those inputs to ground; they are not series current limiters.
TI SBOS737C, PDF page 5, section 6.1, limits input voltage to the actual rails
plus/minus 0.5 V and input current to +/-10 mA. Pages 25-26, section 7.3.7,
explain why internal ESD structures do not by themselves provide in-circuit
overstress protection.

A live patch source while this module is off, or a source outside its rails,
can forward-bias internal protection. The source impedance and rail back-powering
path are not controlled by this design. Nominal powered simulation does not test it.

**Closure:** specify powered/unpowered patch faults and permissible source
conditions; implement a proven protection approach with leakage, capacitance,
noise and current limits included in the budget. Validate rail sequencing and
recovery without claiming that an absolute-maximum rating is an operating target.

### OR-03: Open-Circuit Accuracy Is Not Loaded Pitch Accuracy

**Priority: high for pitch use. Confidence: high, circuit topology and arithmetic.**
R3/R6 are 1 kohm output resistors outside feedback. At unity gain, a 100 kohm
destination receives 100/101 of the internal output. At 5 V this is a 49.505 mV
loss, corresponding to 59.406 cents at 1 V/octave, or 11.88 cents per octave.
A 1 kohm source into the 1 Mohm input adds about 0.1% loss independently.

The [error budget](modules/attenuverter/ERROR-BUDGET.md) explicitly excludes
receiver loading and the decks characterize the loss. The tests are not failing;
the problem is treating that characterized interface as sufficient evidence of
system pitch precision. Calibration can absorb a fixed path's scale error but
does not automatically cancel changes of source, load, fan-out or patch path.
The oscillator's agreed tracking target is not proof that this utility meets it.

**Closure:** allocate the whole signal-path error at the connector under defined
loads, including calibration assumptions. Evaluate a stable, protected precision
output approach before reusing this block where load-independent pitch accuracy
is required. Do not simply remove the resistor or weaken the required accuracy.

### OR-04: The Bring-Up And Measurement Plan Needs Correction

**Priority: high before powering hardware. Confidence: high for the identified
claims; the actual supply and meter specifications remain unverified.**
Do not follow [the current power-up guide](modules/attenuverter/POWER-UP.md)
unchanged. In particular:

- A 12 V, 50 mA rail can supply 0.6 W; two rails can supply more. Current
  limiting reduces risk but cannot guarantee that nothing heats or is damaged.
  Stored energy and protection response also matter.
- Series operation must be explicitly supported by the chosen supplies, with
  output-to-earth isolation and ratings checked in their manuals. Wiring must
  be changed with outputs disabled. Set current limits using the manufacturer's
  procedure, not an unverified generic instruction.
- A 1 mV display increment is not 1 mV accuracy. Using the guide's own 0.5%
  accuracy estimate gives 25 mV at 5 V before count errors. Absence of a visible
  change cannot demonstrate a 0.1 mV interaction limit.
- An AC-coupled audio interface cannot establish static DC offset, reference
  voltage or an accurate DC stimulus. A calibrated DC measurement/stimulus
  method is needed for pitch-scale and offset validation.
- A steady multimeter reading does not rule out high-frequency oscillation.
  The selected scope/bandwidth and probe setup must match the stability test.

This calls for a task-appropriate measurement plan, not an automatic purchase
of a more expensive bench. Equipment purchases and physical work remain separate.

### OR-05: Part And Mechanical Evidence Is Incomplete

**Priority: before the affected board is ordered. Confidence: mixed, see below.**
The 24 factory-placed attenuverter parts have LCSC identifiers, so the analyzer's
blank-MPN warning does not mean all assembly identities are unknown. Nevertheless,
MPN/manufacturer/datasheet fields are empty, hand parts are not a complete exact
shopping list, and full part-to-package evidence is not closed.

Manufacturer PDFs were obtained during this review for OPA2197, REF50, the Yageo
RT series, JSCJ B5819W and Samsung MLCCs. Yageo RT series V.16, 2025-05-06,
page 2 supports the selected resistor's B = 0.1% and D = 25 ppm/C codes. The
JSCJ family sheet, D/Mar/2015, page 1 supports 40 V, 1 A, 0.6 V maximum at 1 A
and the cathode marking for B5819W. Those checks do not validate every assumption
in the diode model. Samsung catalogue page 27 contains the selected part family;
its exact effective-capacitance behavior is not closed.

The existing drawing-based mechanical review identifies a 1 mm gap between jack
shoulders and the panel supported by the pots. The actual hardware/thread stack
needs a bounded fit check before final panel assembly. The renders omit the jack
and pot bodies, so they cannot validate that stack by themselves. Panels are
deferred; lack of final panel art or a case need not block a bench-only PCB.

### OR-06: Release And Commercial Gates Are Still Open

**Priority: before payment. Confidence: high, repository/artifact inventory.**
- R1's requested behavior is recorded, but the jack/normalling tradeoff remains
  unanswered; its engineering specification and full design/check cycle still
  need completion after V0.
- The roadmap explicitly requires CI before the first order; it is absent.
- No current retained Gerber/BOM/CPL release, assembly-preview review or delivered
  quote is present. The earlier scratch export is not an approved release.
- Recheck exact JLCPCB assembly allocation, substitutions, orientation, side,
  handling/panelization requirements, PCB versus assembly quantities, hand parts,
  VAT, shipping and fees. Public LCSC stock is not reserved JLCPCB assembly stock.

JLCPCB's [assembly capabilities](https://jlcpcb.com/capabilities/pcb-assembly-capabilities)
page, consulted 2026-09-14, lists Economic order volume **2-50** and Standard
**2-80000**. Thus five bare PCBs must not be treated as necessarily five fully
assembled units. The selected service and live quote must confirm the actual
quantities. This quantity finding did not change the instrument composition;
the separate 2026-09-21 direction now makes that composition a starting point
to evaluate in VCV Rack.

## Evidence And Review Limits

Assessment input: clean, synchronized checkpoint `6f1d417`. Existing evidence
from the preceding recovery task that day: 82 Haskell tests, 79 script checks,
eight circuit decks, and attenuverter/panel ERC/DRC/parity passed. Those were not
rerun solely for this review. The mult's native checks and renders were rerun
here and passed. No board or simulator model was changed.

| Review activity | Scope and result |
|---|---|
| `analyze_schematic.py` | Ran for attenuverter and mult. Component counts 31 and 13; no missing footprints. Missing structured manufacturer evidence remains. |
| `analyze_pcb.py --full --proximity` | Ran on both zone-filled build boards. Both report complete connectivity and dimensions of 28 x 100 mm. |
| `cross_analysis.py` | Ran for both; no schematic/PCB consistency finding. Decoupling/power checks had missing inputs or zero examined items, not comprehensive passes. |
| Named-net pin comparison | All 88 attenuverter and 26 mult physical-component assignments agree between the two analyzer outputs. Schematic-only power symbols and unnamed/no-connect nets excluded. This is internal consistency. |
| Manufacturer checks | OPA2197 pins match SBOS737C page 4; REF50 functional pins match SBOS410O page 4. Critical requirements above were read directly. Not a complete all-part physical pad audit. |
| `analyze_emc.py` | Ran for both, four categories evaluated. Treat findings as screening, not an emissions verdict. No certification claim. |
| `analyze_thermal.py` | Invoked for both; **SKIPPED**, zero components assessed, due to missing quantifiable power/MPN/extraction inputs. Not a thermal pass. |
| Circuit simulation | Reused the same-day eight-deck ngspice run. Generic isolated-subcircuit simulation and extracted-PCB-parasitic simulation were not run; current models do not establish reference output-loop, protection or loaded-supply behavior. |
| BOM analysis / sourcing | Read-only BOM analysis and selected public product pages; not a complete current stock/lifecycle audit or delivered quote. |
| Gerbers / CPL | No current release bundle exists, so Gerber analysis and supplier placement preview were not performed. No files uploaded to JLCPCB. |
| Prior-review delta | Compared against the current spec, budget, mechanical and lab documents; no prior analyzer run in this checkout to diff. |

The bulk datasheet-sync helper failed with Windows `FileExistsError` replacing
its manifest. Direct PDF downloads succeeded; no structured extraction cache or
complete lifecycle audit was produced. Review JSON and PDFs are local ignored
artifacts under `modules/<name>/build/`; they are not portable release evidence.

## False Positives And Residual Risks

- The mult's jack courtyard overlaps are intentional and covered by its native
  custom rules. They are not proof that jack bodies collide.
- The attenuverter header courtyard extends 0.2 mm outside the board; the
  documented body boundary is 0.3 mm inside. Distinguish courtyard from body,
  and confirm the exact purchased header and assembler handling clearance.
- Missing named test points does not mean pads are inaccessible. It does mean
  the guide needs clear, safe probe locations and a realistic measurement method.
- JLCPCB's [FAQ](https://jlcpcb.com/help/article/pcb-assembly-faqs) says it can
  add fiducials. Their absence is not independently an ordering blocker here.
- Generic EMC errors for every unfiltered passive jack, and assumed 100/150 MHz
  stitching rules, do not demonstrate emissions failure on these audio boards.
  The attenuverter's reported gaps near OA2/BUF2 and feedback-route transitions
  still merit a circuit-aware return-path review; do not dismiss all findings
  or equate the model's zero cross-channel coupling with physical zero.
- The mult has no powered heat source, but its passive loading and permissible
  patch currents still need an intended-use check. It is not a pitch buffer.

## Path To A First Order

This is a deferred hardware path, not the current task queue.

1. Complete V0's musical evaluation and agree the composition that should become
  hardware. Then confirm the first board; R1 is the retained starting plan.
2. Develop that board from its specification. For R1, preserve its approved
  [behavior](modules/io-mixer/SPEC.md), resolve the retained jack/normalling
  tradeoff and derive its engineering limits. Do not reopen settled answers.
3. Close the reusable-block findings, especially capacitor margin, input faults
   and complete interface accuracy, before relying on them in another board.
4. Establish the first-power and measurement procedure with supported equipment
   and uncertainty; implement CI as required by the roadmap.
5. Freeze a reviewed candidate, generate/check its release bundle, inspect the
   supplier preview and obtain an all-in quote. The user approves that exact order.

A prototype order is allowed to precede measurement of that prototype. What
must precede it is a defensible design and bounded experiment, not perfect
certainty. The present gaps are specific engineering and release work, not a
reason to wait indefinitely or continue open-ended router research.