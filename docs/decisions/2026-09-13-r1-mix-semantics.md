---
status: "pending"
owner: "user answer; agent research and integration"
read_when: "writing the R1 IO + Mixer specification, or after the user edits this file"
update_when: "the user answers, evidence changes, or the agent records the outcome"
retire_when: "the answer is recorded in docs/modules/io-mixer/SPEC.md and that spec is checkpointed"
---

# R1: what does the mixer do?

## Decision Needed

R1's second half is a mixer: "line-level inputs summed to a mix, independent
line-level outputs" ([../ROADMAP.md](../ROADMAP.md), P2). That sentence
leaves open what a musician actually reaches for, and each answer changes
the circuit, the panel and the error budget. The SPEC cannot be written
until these are fixed:

1. **How many channels**, and are they Eurorack-level (±10 V from the case)
   going *out* to line level, line level coming *in* to Eurorack level, or
   both directions?
2. **Level control per channel, or none?** A pot per channel is a small
   mixer; no pots is a unity summer with a single master level.
3. **DC-coupled or audio only?** A DC-coupled mixer also sums control
   voltages (then it is a CV mixer too and its offset and gain fall under the
   precision rules); an AC-coupled one only passes audio and is immune to
   offsets.
4. **Where does the mix go?** Only to the world-side outputs, or also to a
   Eurorack-level mix output for feeding back into the case (the filter, for
   instance)?
5. **Normalling.** When nothing is plugged into a channel's own output, does
   that channel join the mix, and leave it when its output is patched? That
   is the Serge and Doepfer convention and is what makes "independent outputs"
   and "a mix" one set of jacks rather than two.

## Options And Recommendation

Two coherent shapes, either of which the agent can build with the block
library already started (the buffered CV channel of the attenuverter is the
input stage of either):

| Shape | Channels | Levels | Coupling | Mix out | Normalling |
|---|---|---|---|---|---|
| **A. Output mixer** | 4 Eurorack inputs, each with its own line-level output | one pot per channel | DC-coupled (the pot is then also a CV attenuator) | mix to a stereo pair of line outputs (each channel has a pan or an L/R switch) and one Eurorack-level mix jack | yes: a channel leaves the mix when its own output is patched |
| **B. Unity summer plus line I/O** | 4 Eurorack inputs summed at unity, 2 line inputs scaled up to Eurorack level | one master pot on the mix | AC-coupled mix; the line inputs DC-coupled | mono line output and one Eurorack-level mix jack | none |

The recommendation is **A**, with one change worth making explicit: **mono
first, stereo later**. A stereo mix doubles the output stages and the panel;
the case it feeds is a mono synth voice through R2 and R3. The agent's
proposal is therefore: four DC-coupled channels with a level pot each, each
with a line-level output that removes it from the mix when patched, one
line-level mono mix output and one Eurorack-level mix output. Line inputs
into the case (the other direction) are a separate small block that can sit
on this board if the width allows and is otherwise dropped, since the plan
has no external audio source yet.

Cost and scope: shape A is one op-amp per channel plus two for the mix, all
the same OPA2197 as the attenuverter, so no new device model; the precision
rules apply to the DC path (offset at the mix output must stay under the
attenuverter's 1 mV, otherwise a CV summed here detunes the oscillator).
Shape B is cheaper by two op-amps and simpler to lay out; it gives up
per-channel levels and DC mixing.

Acceptance check for the chosen shape: an R1 SPEC with an error budget for
the DC path, decks asserting offset, gain, channel independence and the
normalling behaviour on the generated netlist, and a panel that fits the
agreed width.

## Your Answer

Shape (A, B, or describe your own):

Channel count:

Mono or stereo mix:

DC-coupled (CV mixing too) or audio only:

Normalling (channel leaves the mix when its output is patched): yes / no

Notes or constraints (what you will mix, and into what):

Ready for integration: no

## Processing Record

Empty until the user answers.
