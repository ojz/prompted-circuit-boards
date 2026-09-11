---
status: "pending"
owner: "user answer; agent research and integration"
read_when: "working on the attenuverter or after the user edits this file"
update_when: "the user answers, evidence changes, or the agent records the outcome"
retire_when: "the answer and rationale are integrated into `docs/modules/attenuverter/SPEC.md` and the resulting design is generated, simulated, checked and checkpointed"
---

# Attenuverter precision: parts swap only, or parts swap plus input buffers?

## Decision Needed

The attenuverter as designed cannot meet a cents-level pitch budget. The
[error budget](../modules/attenuverter/ERROR-BUDGET.md) derives, from the
TL072C, 1 % resistor and Alpha pot datasheets, a worst-case output offset of
about 27 mV (33 cents), an inversion gain error of 2.3 % (28 cents per
octave), an offset reference that moves 47 mV (56 cents) per 1 % of supply
rail and 42 mV (50 cents) when the other channel is patched, an output swing
that is not guaranteed to reach ±10 V, and an input common-mode range that a
−10 V input exceeds. It also lacks the feedback capacitor both reference
designs use.

Every one of those is fixed by a parts change inside the existing topology.
One remaining term is not: the input impedance is 50 kΩ (44–55 kΩ with the
pot's ±20 %), half the Eurorack convention, so a source with the usual 1 kΩ
output resistor loses 2 % (24 cents per octave) into it instead of the 1 %
it loses into every other module. Removing that term needs an input buffer per
channel, which is an architecture change and therefore your call. Both
options keep the 1 kΩ output resistor, the jacks, the pots, the panel layout
and the 6HP board.

Depends on this: the new SPICE models and assertions, the regenerated board,
and the prototype order list. Nothing is bought either way.

## Options And Recommendation

Prices are LCSC/JLCPCB at quantity 10 in USD on 2026-09-11; all listed parts
are in stock in thousands and all are JLCPCB "extended" parts, so each new
part type adds a one-time assembly fee (about $3 per type per order).

**Option A — parts swap, same topology.**
OPA2197 dual op-amp ($0.83, replaces the $0.16 TL072C in the same SOIC-8),
0.1 %/25 ppm thin-film 100 k resistors in the four gain positions ($0.037
each), a REF5050A 5.000 V series reference (SOIC-8, $0.97) with its 1 µF
input and output capacitors replacing the 1.5 k/1 k divider, and a 10 pF C0G
capacitor across each feedback resistor. Active-part cost rises from $0.18 to
about $1.98 per board. Layout: one added SOIC-8 and three added 0805s where
the divider was; two op-amp channels as before.
Result: offset 0.35 mV (0.4 c), inversion 0.28 % (3.3 c/oct), reference
interaction 0.015 mV, drift 0.6 mV over 10–40 °C, guaranteed ±10.9 V swing
with full input range. Input impedance stays 50 kΩ and is stated in the spec
as a known deviation: a 1 kΩ source reads 2 % low, which an oscillator
calibrated through this module absorbs, but two sources with different output
resistances will differ by up to 2 %.

**Option B — option A plus a unity-gain input buffer per channel (recommended).**
A second OPA2197 ($0.83) so each channel has its own dual: one half buffers
the jack, the other is the attenuverter stage, which then sees a 0 Ω source.
A 1 MΩ resistor from the jack tip to ground defines the input when a cable is
inserted with nothing on the far end. Active-part cost about $2.88 per board,
so +$0.90 over A and +$2.70 over the current design. Layout: one more SOIC-8
and two 0805s per board, which fit in the existing passive columns.
Result: everything in A, plus source loading of 0.10 % (1.2 c/oct) from a 1 kΩ
source, an input impedance of 1 MΩ, and the offset reference loaded by 10 µA
instead of 200 µA. The buffer adds its own ≤ 0.1 mV offset, for 0.45 mV total.
This is the proven shape: Mutable Instruments' Shades bill of materials has
eight op-amps for three channels, thin-film 0.1 % resistors and an LM4040
reference, so more than one stage per channel; its schematic is an Eagle
binary the agent could not read, so the exact wiring is not claimed here.

**Option C — fix only the reference.** Not recommended: the 27 mV offset,
2.3 % inversion error and the unguaranteed swing and input range remain.

**Recommendation: B.** The extra $0.90 per board is well inside the
EUR 150–300 prototype round, and it removes the last term that is specific to
this design rather than to Eurorack as a whole. Choose A if you prefer the
simpler board and accept the stated 2 % source-loading term; A still fixes
every defect the roadmap names.

Either choice leads to the same work: an OPA2197 model and a REF5050 model
built from the datasheet figures in `modules/_models/devices.lib` (with input
capacitance and common-mode limits this time), the decks extended with the
limits in the error budget's acceptance table, a regenerated and DRC-checked
board, and an updated parts table. The acceptance check is that every new
assertion passes at nominal and at the envelope corners, and that the
interaction deck's limit drops from 50 mV to 0.1 mV.

Unknowns that stay open either way: pot end resistance and linearity are not
published by Alpha and must be measured on a real part; input over-voltage
protection is a separate M4 item; the hand-built models remain models.

## Your Answer

Choice (A or B): **B**

Notes or constraints:

Given in conversation on 2026-09-11, not by editing this file. The user's
reasoning, in their words: *"i have a token budget that i can spend on finding
the best circuits, and i don't want to be ordering sub-par modules. and so
making the board a couple bucks more expensive means nothing for me."*

So **cost is not an optimisation target**. The one cost constraint is looser
than a budget and is about the market, not the bill: if a module built this way
ends up more expensive than simply buying an equivalent commercial module
(Doepfer, Behringer), the user would rather buy the commercial one. Recorded as
a standing requirement in [ROADMAP.md](../ROADMAP.md); see
[JLCPCB.md](../JLCPCB.md) for what the fab actually charges for.

Ready for integration: yes

## Processing Record

Answer recorded 2026-09-11 by Claude Fable 5.1 (home laptop) from an explicit
conversational instruction; the user did not edit this file.

**Implementation is not done yet**, and this file stays until it is. It was
blocked on the toolchain: the `cabal.project.freeze` added in `1ea98dc` pins
`base ==4.18.3.0` (GHC 9.6.7), and the home laptop had only GHC 9.2.8, so
nothing could be built or regenerated here. GHC 9.6.7 was installed to match
the work laptop rather than widening the pin, on the user's instruction.

Remaining work, unchanged from the options section above: OPA2197 and REF5050
models in `modules/_models/devices.lib` with input capacitance and common-mode
limits, the `Attenuverter.hs` change, regeneration, the decks extended with the
error budget's acceptance limits, `toolkit/pipeline.sh attenuverter` and
`toolkit/sim.sh attenuverter`, and the record in SPEC.md. Retire this file then.
