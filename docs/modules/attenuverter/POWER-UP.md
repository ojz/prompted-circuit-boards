---
status: "written 2026-09-13 for the option B board and the Stage A lab; never yet performed"
owner: "the agent writes it; the user performs it and records what happened"
read_when: "an assembled attenuverter is on the bench for the first time, or when planning the Stage A purchases"
update_when: "the circuit, the expected numbers, the lab equipment or a step that went wrong changes"
retire_when: "a general first-power-up guide for all modules takes over and this module's expected values move into its prototype record"
---

# First power-up: UTIL-01 ATTENUVERTER

How to power an assembled attenuverter for the first time without damaging
it, and what the meter should read at each step. Written for the Stage A lab
in [../../HOMELAB.md](../../HOMELAB.md): two Rosfix RAVED-3205 bench supplies
in series, the UNI-T UT60EU multimeter, jumper wires and test leads. Every
expected value comes from the datasheets and the decks in `sim/`; none has
been measured on a real board yet, so **the first time through, this guide
is being tested as much as the board is**. Note anything that disagrees.

The panel stays off for this. The board works without it, and the test
points are under it.

## What to have on the bench

- The assembled board: factory SMD on the back, jacks J1 to J4, pots RV1 and
  RV2 and the power header J5 soldered by you.
- Two bench supplies, each with a voltage knob and a current-limit knob.
- The multimeter, with the beeper (continuity) mode found.
- Three jumper wires with a socket end that fits the header pins, three
  test leads with crocodile clips, one patch cable.
- The ESD wrist strap, clipped to a supply's ground terminal. Safety glasses
  are not needed for this part; nothing is hot.

## 1. Look before you power

With the board unpowered, on the silicone mat, back side up.

1. **Chip orientation.** U1, U2 and U3 each have a dot at pin 1 on the
   package and a matching mark on the silkscreen outline. All three must
   agree. A chip mounted backwards is the one fault that can destroy parts
   at first power, and the factory places them, so this is a check on the
   factory, not on you.
2. **Diodes.** The two SOD-123 diodes either side of U2 have a bar at the
   cathode end. Their footprints have a bar too. They must agree.
3. **Header.** The silkscreen `-12V` sits beside the pin-1 end of J5. Pin 1
   is the square pad. Remember which end that is.
4. **Your own joints.** Every jack has three pads, every pot three pins and
   two lugs, the header ten pins: all shiny, none bridged to a neighbour.
   The pot lugs are mechanical only and may stay unsoldered for this test.

## 2. Check for shorts

Meter in continuity (beeper) mode, probes on the header pads from the back.
The header's pins are numbered like the schematic: pins 1 and 2 are −12 V
(the `-12V` end), pins 3 to 8 are ground, pins 9 and 10 are +12 V.

| Between | Expected | If it beeps |
|---|---|---|
| pin 9 (+12) and pin 3 (GND) | no beep | a short on the +12 V side: stop, look for a solder bridge at J5, U1, U2, U3 or the capacitors beside U2 |
| pin 1 (−12) and pin 3 (GND) | no beep | a short on the −12 V side: same search |
| pin 9 and pin 1 | no beep | rails shorted to each other |
| pin 3 and any jack's barrel pad (the round pad the barrel sits on) | **beep** | no beep means a jack sleeve is not soldered to ground |

Then switch the meter to ohms and read between pin 9 and pin 3, and between
pin 1 and pin 3. Both readings should start low and climb as the 10 µF
capacitors charge from the meter, settling above 100 kΩ or showing
over-range within a few seconds. A reading that stays below 1 kΩ is a
short the beeper was too slow to catch.

## 3. Set up the supplies, board not connected

Two single supplies in series make the bipolar rail. **Both outputs must be
floating** (isolated from mains earth); HOMELAB.md asks you to confirm this
on the product page before buying, and it matters here because the junction
of the two supplies becomes the board's ground.

1. Turn both supplies on with nothing connected. Set each to **12.0 V**.
2. Set each current limit to about **50 mA**: turn the current knob fully
   down, briefly short that supply's own output with a test lead, turn the
   current knob up until the display reads 0.05 A, remove the short. The
   voltage returns to 12.0 V. Repeat for the other supply. Fifty milliamps
   into a fault cannot heat anything on this board; the working board draws
   about a tenth of it.
3. Wire the series junction: supply A's **−** terminal to supply B's **+**
   terminal with a test lead. That junction is ground. Supply A's **+** is
   +12 V; supply B's **−** is −12 V.
4. Turn both supplies **off** (or their outputs off) before touching the
   board.

## 4. Connect and power

Three jumper wires from the supplies into the header, all visible, no
ribbon cable:

| Supply point | Header pin |
|---|---|
| ground (the junction) | pin 3, or any of 3 to 8 |
| supply A + (+12 V) | pin 9 or 10 |
| supply B − (−12 V) | pin 1 or 2, the `-12V` end |

Check the three wires once more against the table. Then turn both supplies
on together, or supply A first and B immediately after; the order does not
matter for this circuit, but do not leave one rail on alone for long.

**Watch the current displays for the first five seconds.**

| Reading | Meaning |
|---|---|
| Supply A (+12 V) 4 to 7 mA, supply B (−12 V) 3 to 6 mA | normal: two OPA2197 at 1.0 mA per amplifier typical (1.3 max) plus the REF5050 at 0.8 mA (1.0 max) on the positive side |
| either display at its limit (0.05 A) or its CC light on | a short or a reversed part: **off at once**, back to step 1 |
| either display at 0 mA | that rail is not connected; check the wire on that pin |
| current climbing over the first seconds | not expected here (nothing on the board charges slowly); off, and look for a hot part after 30 s |

Nothing on this board should feel warm at 5 mA. If anything does, power
off and find it.

## 5. What the meter should read

Meter on DC volts, black probe on header pin 3 (ground) for every reading.
Values assume the supplies are at 12.00 V. The meter reads 1 mV up to
9.999 V and 10 mV above.

| Point | Where to probe (back side) | Expected | Why |
|---|---|---|---|
| +12 V raw | header pin 9 | 12.00 V | the supply |
| −12 V raw | header pin 1 | −12.00 V | the supply |
| +12 V rail | U1 pin 8 (the corner opposite the pin-1 dot) | 11.6 to 11.8 V | 12 V less the B5819W drop, 0.2 to 0.35 V at 5 mA over the temperature envelope |
| −12 V rail | U1 pin 4 (the last pin on the dot side) | −11.6 to −11.8 V | same |
| Reference | the square pad above J1's barrel (J1's switch pin, the OFFSET net); or U3 pin 6 | 4.995 to 5.005 V, steady to the last digit | REF5050A, ±0.1 %; it is fully up within 50 ms of power |
| OUT 1, RV1 fully clockwise, nothing patched | the round pad furthest below J2's barrel (its tip) | +5.00 V ±0.01 | unpatched input is normalled to the reference; gain +1 |
| OUT 1, RV1 fully anticlockwise | same | −5.00 V ±0.02 | gain −1; the extra 10 mV allows for the 0.1 % resistors |
| OUT 1, RV1 at its centre | same | 0 V ±0.02, and reaches exactly 0 somewhere near centre | the null; the pot's centre is only nominally at 50 % |
| OUT 2 | same on J4, turning RV2 | the same three readings | channel 2 |

A note on what the meter can and cannot confirm. Its own DC accuracy is
about 0.5 %, which is 25 mV at 5 V. It confirms that the reference is alive,
within a few tens of millivolts of 5 V and steady; it cannot confirm the
0.1 % the datasheet promises, nor the 1 mV offset limit in the error budget.
Those wait for a better reference or the audio-interface method in Stage B.
What the meter *does* catch is every gross fault: a dead reference, a
missing rail, a wrong gain, an oscillating stage (the reading will not
settle).

## 6. Patch tests, still on the bench

1. **Cross-channel.** With RV1 fully clockwise, read OUT 1. Now turn RV2 from
   end to end and plug a cable into IN 2 and out again. OUT 1 must not
   change by a visible digit. The budget's limit is 0.1 mV and the model says
   1 µV, so the meter should see nothing at all; if the last digit moves,
   write it down.
2. **Through a cable.** Patch OUT 1 to IN 2. With RV1 fully clockwise OUT 1 is
   +5 V; RV2 fully clockwise gives OUT 2 = +5.00 V (±0.02: the 1 kΩ output
   resistor into 1 MΩ costs 0.1 %); RV2 fully anticlockwise gives −5.00 V.
3. **A dead cable.** Patch a cable into IN 1 with nothing on its other end.
   OUT 1 goes to 0 V at every knob position: the 1 MΩ input resistor reads
   an open cable as zero, and the reference is disconnected by the switch.

## 7. Stop conditions

Power off immediately if: a current display sits at its limit; a part is
warm to a fingertip after 30 s; a rail reads below 11 V or above 12.1 V; a
reading will not settle. Then back to step 1, and do not skip the beeper.

## 8. Record

Write down, for this board and this date: both supply currents at 12.00 V;
the four rail and reference readings; the six output readings; the
cross-channel observation; the room temperature if a thermometer is handy;
anything that disagreed with this guide. That record, not this guide, is
the evidence the M5 gate in [../../ROADMAP.md](../../ROADMAP.md) asks for.
