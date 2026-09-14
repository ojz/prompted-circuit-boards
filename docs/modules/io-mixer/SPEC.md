---
status: "user-facing behavior approved 2026-09-14; circuit, parts, simulations and layout not implemented"
owner: "collaborating design agents; user owns musical behavior and purchase decisions"
read_when: "designing R1, checking phone/laptop compatibility, or preparing its prototype review"
update_when: "implementation evidence, operating limits or an explicit user decision changes; do not duplicate run results"
retire_when: "R1 is removed or a replacement specification takes ownership; preserve approved decisions and build-revision evidence"
---

# R1: IO + Mixer

The first planned instrument module: a four-channel mono mixer and an interface
between the synthesizer and consumer audio devices, with the system's USB-C
Power Delivery supply. This is the authoritative behavior specification, not
an orderable circuit or a claim that the design is finished.

## Approved Decisions

The user answered in conversation on 2026-09-14; the two decision files were
not edited. Their exact answers were:

> jacks => everything that interfaces with the outside world, we'll standardize on 3.5mm stereo, so that we can easily hook up our smartphone and laptop to the synthesizer. I do not currently own any 6.35 equipment.

> mixer => Shape A; 4 channels; mono; DC-coupled; normalling yes.

These answers supersede the old recommendation for 6.35 mm TS connectors and
the stereo version of shape A. They approve the behavior below, not a parts
order, a final price, or the untested circuit assumptions in those questions.

| Requirement | Adopted behavior |
|---|---|
| Mixer | Shape A, output mixer, with four independently level-controlled channels. |
| Mix format | One mono mix; no pan controls or stereo mixing bus. |
| Signal path | The synth-side channel and mix paths pass DC, so they can process CV as well as audio. |
| Individual outputs | One per channel, at consumer audio level on the world side; patching it removes that channel from the common mix. |
| Mix outputs | One synth-level mono mix output and one consumer-level mix output. |
| Outside-world analog audio | 3.5 mm TRS, conventional unbalanced stereo contacts: tip left, ring right, sleeve common. Not balanced mono. |
| Synth patching | Existing 3.5 mm TS mono/CV convention remains; do not connect an external audio source to a CV output. |
| System power | Retain the roadmap's USB-C PD input and protected +/-12 V and +5 V distribution. USB-C is a power connector, not replaced by the audio-jack decision. |

## How It Should Behave

Each channel's level control affects its individual output and its contribution
to the mix. With its individual output empty, the channel contributes to the
mix. Inserting a plug removes only that contribution; the individual output
continues to work. Removing the plug restores it. Turning or patching one
channel must not cause an unintended change in another channel's output.

The mono mix is available both at synth level for patching back into the case
and at a safe consumer audio level. The individual consumer outputs and consumer
mix output carry the same mono signal on left and right contacts through a
properly designed output network. A stereo plug does not imply stereo mixing.

Phone/laptop playback is an intended input source, not something to omit because
the older question assumed there was no external source. A stereo input must
combine left and right through a summing circuit with controlled loading; never
short a phone's or laptop's two output channels together. There are still four
mixer channels total. The agent must propose how the consumer input is assigned
to those channels and how it coexists with synth inputs before fixing the jack
layout; this does not authorize extra channels or a separate stereo mixer.

## Consumer Compatibility Boundary

- Most phone/laptop audio sockets are headphone outputs, not recording inputs.
  Playing their audio into R1 and recording R1 back into the device are different
  connections. A recording path needs a suitable line-input interface or a
  device-specific headset-input adapter; a TRS cable alone is not sufficient.
- A USB-C audio dongle needs an actual DAC/ADC function appropriate to the
  direction required. R1's USB-C PD power connection does not provide USB audio.
- Four-contact headset sockets have their own TRRS wiring, microphone bias and
  signal-level requirements. Do not claim universal phone recording compatibility
  from the 3.5 mm connector diameter. Check the actual devices/adapters first.
- The approved DC coupling applies to the synth/CV paths. The consumer-facing
  audio interface must prevent damaging DC or synth-level voltages reaching
  external equipment, including on startup and shutdown. Derive the necessary
  DC blocking, attenuation and protection without silently AC-coupling the CV path.
- Line outputs are not automatically headphone drivers. Do not promise direct
  headphone drive without choosing its load, driver and protection requirements.
- Account for USB/laptop grounding, plug insertion shorts, wrong-port patching
  and powered-off drive. No blind TRS/TS adapter or joined output channels.

These are implementation and compatibility constraints, not new user choices
about mono/stereo, connector size, coupling or normalling. A material change
to the approved behavior or hardware cost still needs an explained decision.

## Design Work And Acceptance

Start from proven input, summing, output and PD supply circuits. Reuse the
existing Haskell blocks only within the limits established by
[../../ORDER-READINESS.md](../../ORDER-READINESS.md); a passing attenuverter
deck does not make its present output stage a load-independent pitch buffer.

Before layout, the agent must establish:

1. A connection diagram showing consumer playback, synth mixing/CV and the
   separate recording route, with the four channels and normalled outputs.
2. Exact supported source/load/voltage ranges, input impedance, DC error, gain,
   drift, noise and cross-channel limits at the connectors. Assign each part
   of the pitch error budget; do not hide source or destination loading.
3. Summing gain and clipping behavior. Four full-scale inputs at unity cannot
   all be summed without clipping on +/-12 V rails. Specify usable headroom
   and overload recovery rather than silently promising impossible swing.
4. Proven protection for hot-plugging, unpowered inputs, output shorts and
   consumer equipment. **Jack finding, 2026-09-14:** no switched 3.5 mm TRS
   jack fits the module's panel stack ([../../MECHANICAL.md](../../MECHANICAL.md),
   panel hardware standard). The only stereo jack that fits, the QingPu
   WQP-WQP419GR, has no switch contact, so the normalled individual outputs
   cannot be sensed at a world-side stereo jack. How the approved normalling
   is kept is the user's choice in
   [../../decisions/2026-09-14-panel-hardware.md](../../decisions/2026-09-14-panel-hardware.md),
   section 1; the jack layout waits on it.
5. The PD rail/current budget and switching-noise limits for this board and
   its intended downstream modules. Current `Block.Power` is protection and
   filtering, not a PD converter. Preserve accessible first-power test points.
6. A physical layout within the roadmap's 4-20 HP range and 100 mm PCB height,
   fixed control coordinates and one factory SMD side. Final width and jack
   allocation must follow the complete interface requirements, not guesswork.

Generated-netlist tests must cover every channel alone and together, signed
DC and audio transfer, normalled/removed/restored contributions, both stereo
input contacts independently, consumer-output DC safety, loading, clipping,
power sequencing, protection and switching interference. Native ERC/DRC,
part/assembly review, CI and a board-specific measurement plan remain required.
Use [../../HOMELAB.md](../../HOMELAB.md) for equipment procurement and
[../../HANDOFF.md](../../HANDOFF.md) for current progress, not new status files.