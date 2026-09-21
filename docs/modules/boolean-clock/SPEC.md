---
status: "draft behavior for VCV Rack evaluation; hardware architecture deferred; no circuit or parts verified"
owner: "collaborating design agents; the user owns musical behavior and the architecture answer in docs/decisions/"
read_when: "prototyping R5 in VCV Rack, resuming hardware design, answering its architecture decision, or checking clock/divider behavior"
update_when: "the user approves or changes behavior, the architecture decision is answered, or implementation evidence exists; do not duplicate run results"
retire_when: "R5 is removed or a replacement specification takes ownership; preserve approved decisions and build-revision evidence"
---

# R5: Boolean + Clock

The earlier hardware plan's fifth board: shared-threshold Boolean logic, edge-to-trigger
converters and a clock divider with reset, and now a candidate hardwired
trigger sequencer. This is the plan for the module, not an orderable circuit.
The retained hardware round is in
[ROADMAP.md](../../ROADMAP.md#p2-hardware-rounds-deferred).

**Current phase, 2026-09-21:** explore the candidate logic, divider and pattern
behaviors in VCV Rack under
[V0](../../ROADMAP.md#v0-playable-digital-modules-and-function-balance-current)
before choosing hardware. Check truth tables, normalling, clock/reset behavior
and the demand for a separate clock when a slope is already serving as a voice
or LFO. The proposed table remains unapproved. Virtual code does not select a
microcontroller, CMOS, ROM or programmable logic for the physical module, and
the unanswered hardware architecture file does not block this exploration.

## User Input, 2026-09-15

The user left these notes in the decision inbox on 2026-09-15 and asked for
them to be processed into a coherent plan. Their exact text:

> process these random thoughts and ideas into a coherent plan for improving
> the logic module that we have, some things i was thinking about:
> - we need an A and NOT B operation (is this A-B?)
> - there should also be a digital chip that can handle multiple inputs and outputs,
>   so we can have more complex logic operations (such as a pre-programmed trigger sequencer)
> - paperplate also allows for (or frequently contains) LEDs in a kind of diagonally offset arrangement
>   which could be useful for visualizing the logic states of the module.

The notes are requests for a plan, not approvals of a circuit or a part. The
plan below records how each one is read and what work follows from it.

### A AND NOT B

Yes: in Boolean algebra `A AND NOT B` is the set difference, written `A − B`
or `A \ B`, and the gate that implements it is called an **inhibit** gate: A
passes unless B is high. It is the one common two-input function the usual
AND/OR/XOR set cannot make without an inverter, and it is musically distinct
(a gate that is suppressed by another gate; a clock with beats removed by a
pattern). It is **not** analog subtraction. Subtracting the voltages and
thresholding the result gives the same truth table only while B's high level
is at least A's, which nothing in a patch guarantees, so R5 implements it as
logic after the comparators, and both orders `A AND NOT B` and `B AND NOT A`
are provided because the two inputs are otherwise symmetric.

### A multi-input, multi-output digital part

Read as: one part that takes several logic inputs and produces several
outputs from a fixed function, so that R5 can offer more than two-input gates,
with a pre-programmed trigger sequencer as the motivating example. "Pre-programmed"
means the patterns are fixed at design time and chosen with a visible switch,
which is exactly what the [visible, persistent controls rule](../../../AGENTS.md#rules)
permits and a menu-driven programmable sequencer would violate. How that part
is realised (hardwired CMOS and a diode matrix, a ROM, a CPLD or a
microcontroller) is a hardware architecture choice with consequences for the
toolchain and the lab, so it is retained in
[decisions/2026-09-15-logic-module-architecture.md](../../decisions/2026-09-15-logic-module-architecture.md)
with the agent's recommendation, deferred during V0. Nothing below assumes the answer.

### Diagonally offset LEDs

Read as a panel convention: each logic output's state LED sits diagonally
offset from its jack, close enough to read as belonging to it, without taking
a grid cell of its own. The convention is recorded as a provisional rule in
[MECHANICAL.md](../../MECHANICAL.md#panel-layout-language); the exact offset
needs later mechanical checks against the jack nut on the front and the
jack courtyard on the back. The simplified sketcher does not establish that
fit. R5 is the first planned board
with LEDs, so the per-board LED indication the user chose on 2026-09-13 is
decided here; there is still no LED driver block until a second board needs
one.

## Proposed Behavior

Nothing in this table is approved. It is the agent's proposal for the user
to confirm or edit; approval in conversation or in the decision file is
recorded here afterwards, as R1's was.

| Section | Proposed behavior |
|---|---|
| Logic inputs | Two inputs A and B, accepting any Eurorack signal, DC-coupled, protected against ±12 V. B is normalled to A so a single input gives NOT A on the inhibit outputs and A on AND/OR. The normalling is drawn on the panel. |
| Threshold | One shared THRESHOLD knob sets the comparison level for both inputs, with fixed hysteresis, so audio and CV can be turned into gates. Its scale is printed in volts. |
| Logic outputs | Simultaneous outputs, one jack each, no mode switch: AND, OR, XOR, A AND NOT B, B AND NOT A, NOT A. Each has a state LED. |
| Edge triggers | Rising-edge and falling-edge trigger outputs from the A input, fixed width, for firing R2 and R4 from a gate's ends. |
| Divider | Clock input, reset input, outputs /2, /4, /8 and /16, each with a state LED. Reset restarts the chain in a defined state. The /16 output drives the next board's clock input. |
| Sequencer candidate | A fixed set of trigger patterns stepped by the clock and reset input, several outputs, pattern selected by a maintained switch. Steps, outputs and pattern count are asked in the decision file. Independent of the divider, so both can run. |
| Power-up | With cables and switch positions unchanged, the module comes back doing the same thing: the divider and sequencer start from their reset state on power-up, and no state is hidden. |
| Chaining | Clock in and /16 out on every board of the row are the chain. Five boards deep the last output runs at 1/2^20 of the clock; the timing budget below covers that depth. |
| Indication | One LED per logic and divider output at the diagonal offset convention, driven from the output buffer, never from the signal node, at the brightness the pending hardware answer selects. |

## Precision And Electrical Budget To Derive

The [precision-first rule](../../../AGENTS.md#rules) applies to a logic module
as thresholds, levels and timing rather than gain and offset. The agent derives
these limits before the circuit is fixed and records them here with the
evidence; none of them are numbers for the user to supply.

- **Threshold accuracy and hysteresis.** The printed THRESHOLD scale must hold
  over supply and temperature; the hysteresis must reject the noise of a slow
  CV crossing the threshold without hiding fast triggers.
- **Input behaviour.** Loading, protection to the full ±12 V rail, and the
  response to the shortest trigger R2 and R4 can emit.
- **Output levels and drive.** Gate high and low levels, drive into a
  Eurorack input and into a passive mult, and short-circuit tolerance. The
  choice between the +5 V rail R1 distributes and a higher level from the
  ±12 V rails is made against what R2 and R4 need to receive.
- **Timing.** Propagation from input crossing to output, trigger width and its
  tolerance, divider skew, and the accumulated delay and jitter five boards
  deep in the chain.
- **Reset and power-up.** The defined state after reset and after power-up,
  and how long after power-up the outputs are valid.
- **Indication load.** The LED current per output and its total on the rail
  it draws from, so blinking LEDs cannot modulate a precision rail.

## Plan

The current task is V0's playable behavior evaluation, not a chip choice.
The steps below are retained for **hardware after V0** and must be reconciled
with the accepted behavior and composition then. Each step names its gate;
none runs between sessions.

1. **Architecture answer.** The user answers the decision file. The
   recommended option keeps R5 in the analog-first phase with no firmware and
   no programmer; the alternatives are explained there with their costs.
2. **Behavior approval.** The user confirms or edits the proposed behavior
   table, including the output list and the sequencer shape. Gate: this
   specification records the approved rows and the exact answers.
3. **Reference circuits and provenance.** Following the
   [reuse-proven-circuits rule](../../../AGENTS.md#rules), select documented
   comparator, CMOS logic, edge-detector and counter circuits with sources and
   licences, and verify every part on JLCPCB. Gate: a provenance table like the
   attenuverter's, with unverified items marked.
4. **Hardware logic modelling.** Independently of any Rack implementation,
  add two checks that fall out of the same `Module`: an exhaustive
   truth-table and cycle check of the combinational logic and counters in
   Haskell, and ngspice decks using XSPICE digital code models with A/D bridges
   for the comparator and trigger timing. Gate: a deliberately wrong gate
   wiring fails the Haskell check, and the decks report the trigger width and
   threshold within the derived limits.
5. **Design and sketch.** Write `modules/boolean-clock/BooleanClock.hs` from
   the block library, and lay its panel out in the S2 sketcher on the shared
   grid with the LED convention, keeping unverified pitches provisional. Gate:
   the pipeline passes for module and panel and the sketch agrees with the
   generated panel project.
6. **R5 in its round.** Build, first power, and measure thresholds, levels
   and timing against the derived limits, with the chain test across boards.
   Gate: the M5 measurement, as for every round.

## What This Does Not Decide

- No part numbers, logic family, rail or trigger width are chosen here; they
  follow from the budget above and the architecture answer.
- No panel width or grid coordinates: the sparse grid pitch is still a mockup
  candidate, and R5's width follows from its approved output list.
- Whether R5 also carries a clock oscillator. R2's cycling slope is the
  intended master clock of the row; a dedicated oscillator is asked in the
  decision file rather than assumed.
- The parked 4-step chainable pot sequencer is unchanged by this plan. The
  candidate here is a fixed-pattern trigger sequencer with no pots per step,
  and the roadmap records both.
