---
status: "pending"
owner: "user answer; agent research and integration"
read_when: "working on R5 Boolean + Clock or after the user edits this file"
update_when: "the user answers, evidence changes, or the agent records the outcome"
retire_when: "the answer and rationale are integrated into docs/modules/boolean-clock/SPEC.md and the roadmap, and the resulting work is checkpointed"
---

# R5 Logic Module: How The Multi-Input Digital Part Is Realised

## Decision Needed

Your 2026-09-15 note asked for "a digital chip that can handle multiple inputs
and outputs, so we can have more complex logic operations (such as a
pre-programmed trigger sequencer)" in the logic module. The rest of the note is
integrated into the [R5 plan](../modules/boolean-clock/SPEC.md) without a
question. This one is an architecture choice: it decides whether the fifth
analog board carries firmware or a programming step, what the lab needs, and
whether the digital control plane starts early. Nothing in the roadmap's R5
row depends on it except the sequencer.

The standing rules constrain every option the same way: pattern selection is
a maintained, labelled switch, never a menu or a hidden latch, and the module
comes back doing the same thing after a power cycle.

## Options And Recommendation

| Option | What it is | Costs and consequences |
|---|---|---|
| **A. Hardwired CMOS with a diode matrix (recommended)** | A CMOS counter steps through 8 positions; a diode matrix is the pattern memory, one diode per beat; a rotary or toggle switch selects one of a few pattern banks. The Baby-8 lineage, documented for fifty years. | No firmware, no programmer, every part factory-placed by JLCPCB. The patterns are literally visible in the copper and in the Haskell design, and pcbgen can generate the matrix from a pattern list (Euclidean rhythms, for instance). About 8 steps × 4 outputs × 4 banks = up to 128 cheap diodes, fewer in practice since only set beats need one. Patterns cannot change after fabrication. |
| B. Parallel ROM | The counter addresses an EEPROM; its data bits are the outputs; the switch selects the bank on high address lines. | Patterns are richer and more numerous, still no firmware. Needs a device programmer in the lab and a hand-programming step per board; suitable parallel EEPROMs are old, large packages with uncertain JLCPCB stock. |
| C. Small CPLD or FPGA | The logic, counters and patterns as a synthesised bitstream. | The whole board's logic in one part with any function. Needs a 3.3 V or lower core rail, a fine-pitch package, a configuration flash and a programming step, and a synthesis toolchain in the repo. Heavy for the analog-first phase. |
| D. Microcontroller | Firmware implements patterns, dividers and logic. | Cheapest and most flexible, but it is the digital control plane arriving in R5. Firmware is a second thing to design, verify and flash, and the temptation to add modes is exactly what the visible-controls rule forbids. The roadmap parks sequencing until P4 for this reason. |
| E. Defer | Keep R5 as the roadmap row: logic, edges and divider only. | Nothing new; the sequencer waits for the control plane. |

**Recommendation: A.** It answers the note (several inputs, several outputs,
a pre-programmed trigger sequencer), it is a proven circuit, it stays inside
the analog-first phase, it costs nothing in the lab, and the pattern set is
part of the design file, so the repo's own checks verify it the same way they
verify the rest of the board. Option D is the right home for a *programmable*
sequencer later; it should not be brought forward for a fixed one.

Acceptance check for A: the Haskell truth-table check enumerates every step of
every bank against the declared pattern list, the ngspice deck shows the
trigger outputs at the right beats, and the built board is measured against
the same table in R5's round. Purchase boundary: none; this is design work
until R5's order is approved separately.

### Two follow-up numbers, only if you choose A or B

1. **Sequencer shape:** steps per pattern, number of trigger outputs, number of
   selectable banks. **Recommended: 8 steps, 4 outputs, 4 banks**, selected by
   a 4-position rotary switch or two toggles. More banks multiply diodes and
   panel space; more steps need a second counter stage.
2. **Does R5 need its own clock oscillator?** The roadmap makes R2's cycling
   slope the row's master clock. A RATE knob on R5 would let the logic board
   run alone. **Recommended: no**, keep R5 a divider and sequencer of an
   external clock, so the five boards share one tempo source.

## Your Answer

Choice (A/B/C/D/E):

Sequencer shape (steps / outputs / banks):

Own clock oscillator (yes/no):

Notes or constraints:

Ready for integration: no

## Processing Record

2026-09-15: created while processing the user's inbox note. The note's
other two points are integrated without a question: `A AND NOT B` is defined
and provided in both orders in the [R5 plan](../modules/boolean-clock/SPEC.md),
and the diagonally offset LED convention is recorded provisionally in
[MECHANICAL.md](../MECHANICAL.md#panel-layout-language). No circuit or part
was chosen.
