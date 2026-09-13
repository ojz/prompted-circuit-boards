---
status: "maintained"
owner: "the agent keeps it current; the user buys and confirms"
read_when: "buying lab equipment, or planning a measurement or calibration session"
update_when: "a purchase is made, a price or listing changes, or a measurement need appears"
retire_when: "the lab exists and its inventory is recorded elsewhere"
prices_checked: "2026-09-13"
---

# Home lab: the cheapest bench that can build and test the boards

A shopping list for one person in Belgium, paying with a debit card on bol.com,
who has to take five factory-assembled Eurorack boards per order, solder the
through-hole parts onto them, power them up without burning anything, and then
measure them against what the simulation predicted.

This is the second version. The first (2026-09-12) came to about EUR 1,680 and
the user rejected it as far too expensive. The cost was in brand names and
scriptability: a Weller station, two programmable supplies, a Rigol scope, a
Focusrite interface. None of those does the job better for these boards; they
do it more comfortably. This version buys the cheapest thing that does the
job, treats "scriptable" as a bonus rather than a requirement, and defers the
oscilloscope until a measurement actually asks for one. **There is no fume
extractor on this list and there never will be**; an open window and a desk
fan are the answer, see Safety.

How to read the price column:

- **verified** means the price was read from the bol.com listing on the date
  in the frontmatter. This pass read search-result cards, not product pages,
  so the price is real but the product's fine print (wattage, count, whether a
  supply's output floats) was not always visible. Where it matters, the note
  says what to confirm on the page before paying.
- **unverified** means the number is from memory or another shop; check it.
- **own it?** means most people already have one; check before buying.

Prices differ by a few euros between the .be and .nl storefronts and between
days; the .be storefront was used.

## The four jobs the lab must do

1. **Assemble.** Solder jacks, potentiometers, IDC power headers, trimmers,
   LEDs and possibly a USB-C receptacle onto boards whose surface-mount parts
   are already placed. Undo mistakes. Inspect. Do not zap the chips with
   static, do not breathe the smoke, do not get flux in your eye.
2. **Power up safely.** Check for shorts with a meter first. Then feed the
   board from a supply with a current limit set low enough that a wiring error
   cannot heat anything. Eurorack wants +12 V and -12 V at once, so two
   current-limited outputs in series are needed. One board in the queue (R1's
   IO board) is itself a USB-C Power Delivery supply, so a PD charger and a
   USB-C meter are needed for that board only.
3. **Measure, from the laptop where it is cheap to do so.** DC voltages to
   about 1 mV (a multimeter). Oscillator frequency to 0.1 % or better, which
   is what "within 2 cents" means (a USB audio interface and Python).
   Waveforms, filter responses, noise spectra and millivolt crosstalk (the
   same interface). Time-domain shape and switching edges (a scope, later,
   if ever).
4. **Connect things.** Patch cables, test leads, jumper wires.

## Stage A: assemble and power up safely, about EUR 300

Must exist before the first boards arrive. Everything here was seen in stock
on bol.com on 2026-09-13.

| Item | What it is, in plain language | Job | bol.com listing (roughly as titled) | Price | Note |
|---|---|---|---|---|---|
| Soldering station | A temperature-controlled 50 W iron in a base. Temperature control is what lets you solder a big ground pad without melting the jack next to it. 50 W is enough for 2.54 mm and 3.5 mm pads on a two-layer board. | 1 | Velleman soldeerstation instelbaar 50 W, 175-480 °C (VGBrandShop) | EUR 29.95, verified | Ships with one tip; buy a finer conical tip later if the stock one feels clumsy. A 48 W no-name at EUR 37.50 (Cotubex) is the fallback if this sells out. |
| Solder | Lead-free, 1.0 mm, 100 g, rosin core. Thick enough to feed easily, thin enough for these pads. Lead-free melts at about 227 °C; set the iron to 350 °C. | 1 | Loodvrije soldeertin Ø 1,0 mm, spoel 100 g (Cotubex) | EUR 23.99, verified | The Stannol HS10 0.5 mm at EUR 26.28 (seen 2026-09-12) is nicer wire for the same money if you prefer thin. |
| Desoldering pump | A spring-loaded syringe that sucks molten solder out of a filled hole. This is how a jack comes out again. | 1 | Desoldeer pomp - extreme (Prolech.nl) | EUR 8.95, verified 2026-09-12 | Wick (EUR 16) can wait until a bridge actually needs it. |
| Silicone soldering mat | Heat-proof, non-slip mat with pockets for screws. Protects the desk. A 100 x 100 mm board does not need a big one. | 1 | MMOBIEL siliconen soldeermat 35 x 22 cm (MMOBIEL NL) | EUR 10.59, verified | Not ESD-rated; the wrist strap does the ESD job. |
| ESD wrist strap | Elastic band with a resistor and a clip lead. Static from your body is enough to damage the op-amps; the strap bleeds it away. Clip it to the bench supply's ground terminal or a radiator. | 1 | Kotebonk antistatische ESD polsband (EFshop.nl) | EUR 7.95, verified 2026-09-12 | Cheapest strap found on 2026-09-13 was EUR 18.95; the Kotebonk one is the buy if still listed. |
| Flush side cutters | Small pliers that cut leads flat against the board. | 1 | Compacte zij-kniptang 125 mm (WH!.be) | EUR 8.29, verified | A EUR 47 Knipex does the same to a 2.54 mm lead. |
| Tweezers | For holding a trimmer or LED lead while soldering. | 1 | Precisie pincet ESD 6 stuks set (Knaak) | EUR 7.95, verified 2026-09-12 | |
| Safety glasses | Flux spits and clipped leads fly. EN166 is the impact standard. | 1 | Giss veiligheidsbril EN166 (SJUSJU) | EUR 10.95, verified 2026-09-12 | Any EN166 glasses from a DIY shop do; EUR 3-5 there. |
| Isopropyl alcohol | 99.9 %, 1 litre. Removes flux residue, which is slightly conductive on high-impedance nodes. | 1 | Isopropanol 99,9 % zuiver 1 liter (Werken met Merken) | EUR 12.95, verified | |
| Multimeter | Volts, ohms, continuity beeper. 9999 counts gives 1 mV resolution up to 9.999 V, which reads a 5 V reference and any CV to the millivolt; the 12 V rails read to 10 mV, which is fine for rails. The beeper is the short-circuit check before first power. | 2, 3 | UNI-T UT60EU digitale multimeter, True RMS, 9999 counts (sold by bol) | EUR 44.99, verified | If EUR 15 matters: UNI-T UT123D, 4000 counts, EUR 29.77, reads 1 mV only below 4 V. |
| Bench power supply, x2 | A box that gives an adjustable voltage with an adjustable current ceiling ("CC"). Two single-channel units in series make the bipolar rail: the plus of one wired to the minus of the other becomes ground, the free ends are +12 V and -12 V, each with its own limit. Not programmable; you turn two knobs. | 2 | Rosfix RAVED-3205 labvoeding 0-32 V, 0-5 A, CV/CC (VENTIQA) | EUR 54.99 each, EUR 109.98 for two, verified | The card states CV/CC. **Confirm on the product page or in the manual that the outputs are floating (isolated from earth)**, or the series wiring is not safe; see Safety. Fallback: Stamos 0-30 V 0-5 A at EUR 59.00 (Expondo), CC not stated on the card. |
| Test leads | Banana plugs on one end, insulated crocodile clips on the other. Connect the supplies to each other and to the board. | 2 | Velleman set meetsnoeren banaan / krokodil, 3 leads (DutchDo) | EUR 7.37, verified 2026-09-12 | |
| Jumper wires | Pre-terminated 2.54 mm wires. They plug straight into the board's power header for the first power-up: three wires, all visible. No ribbon cable needed. | 2, 4 | Dupont kabels voor breadboard, 65 stuks (Conrad.be) | EUR 15.39, verified 2026-09-12 | |

**Stage A subtotal: EUR 299.30.** Over a third of it is the pair of supplies,
which is the one part of the list that buys safety rather than convenience.

**For R1's USB-C PD board only, not for the attenuverter:**

| Item | Why | Listing | Price | Note |
|---|---|---|---|---|
| USB-C PD charger, 45 W or more | The IO board negotiates PD; it needs a source that can. | own it? A USB-C laptop charger is exactly this. Otherwise UGREEN Nexode 65 W (sold by bol) | EUR 0 or EUR 34.99, verified 2026-09-12 | Check the charger's label for "20V 3.25A" or similar; that is PD. |
| USB-C inline meter | A pass-through with a screen showing the volts and amps on the cable, so you can see whether the board negotiated 15 V or 20 V and what it draws. | USB C Tester, spanning en stroom (bestekoopjes.nl) | EUR 34.95, verified | Nothing under EUR 20 on bol.com. The same device is EUR 10-15 on Amazon or AliExpress (unverified); buy there if you are willing, or skip it and read the board's own rails with the multimeter. |

Skipped on purpose, with the reason: PCB holder (tape the board to the mat),
magnifier lamp (the phone camera at 2x zoom inspects 0603 joints fine), flux
pen (rosin-core solder carries its own flux; buy one at EUR 13 only if a joint
refuses to wet), Kapton tape, heat-shrink, hook-up wire and breadboard
(nothing planned needs them), a second multimeter, and every "nice" version of
every tool above.

## Stage B: measure, about EUR 90 plus an optional scope

Needed when the first boards work and it is time to compare them with the
simulation. Buy after Stage A, not with it.

| Item | What it is | Job | Source | Price | Note |
|---|---|---|---|---|---|
| USB audio interface | A box with two line inputs and two line outputs, 24-bit, 48 kHz or better. From Python (`sounddevice`, `numpy`) it is a two-channel signal generator and a two-channel spectrum analyser with about 100 dB of dynamic range. This one instrument does pitch tracking, filter response, noise floor and crosstalk. Also a music tool later. | 3 | own it? Any interface with line inputs works. Otherwise Behringer UMC202HD or UMC22 from Thomann or Bax; not listed on bol.com under any Behringer name on 2026-09-13 | EUR 0, or about EUR 60-70 unverified | The Focusrite 2i2 at EUR 180 was the previous pick; it is a better microphone preamp, which no board here needs. |
| Attenuator pad | Two resistors in series (say 30 k and 10 k) soldered into a cable, so a ±10 V module output arrives at the interface's line input as ±2.5 V. The interface is AC-coupled and clips near +20 dBu; without the pad a full-scale module output distorts. | 3 | two resistors from the parts drawer, a 3.5 mm plug | about EUR 1 | Never measure DC with the interface; that is the multimeter's job. |
| 3.5 mm to 6.35 mm cable | Module output to interface input (the interface takes 6.35 mm plugs). | 4 | 3.5 mm TRS naar 2x 6.35 mm TS splitter, 30 cm (Provium) | EUR 12.99, verified 2026-09-12 | Or solder your own with the pad inside it. |
| Patch cables | 3.5 mm mono, the Eurorack standard. Five is enough to test one board. | 4 | Bowl Modular 5 patchkabels eurorack, recht, 30 cm, zwart | EUR 18.49, verified | The 15-cable combo pack at EUR 42.99 is for when a row exists. |

**Stage B subtotal: about EUR 32 with an interface you already own, about
EUR 95-105 with a Behringer.**

**Oscilloscope: not yet.** The multimeter covers DC and the interface covers
everything periodic below 20 kHz, which is every measurement the attenuverter
and the filter need. A scope earns its place at R1, whose PD board has a
switching converter with edges the interface cannot see, and it is the tool
you want in your hand when a power-up looks wrong. Two cheap ways to get one
when that day comes, both in stock on bol.com:

| Option | What you get | Price | Note |
|---|---|---|---|
| FNIRSI DSO-TC3 (iCables.eu) | Pocket single-channel scope with a component tester and a signal generator built in. Enough to see a rail wobble, a waveform's shape or a switching node. Not scriptable. | EUR 63.99, verified | Bandwidth and sample rate are not on the card; expect audio-grade, not MHz-grade. Confirm on the page. |
| FNIRSI 2C53P (iCables.eu) | Two channels, bench form, 4.3 inch screen, with a signal generator. Two channels let you see input and output at once. Not scriptable. | EUR 130.99, verified | The scope to buy if one is bought at all. |

The scriptable path (a Hantek 6022BE USB scope with `sigrok`, about EUR 60-70
from Amazon, unverified; or a Rigol DS1054Z at EUR 429) is on record from the
first version of this list and is not recommended at this budget. If a
measurement ever runs out of resolution, that is the moment to revisit it.

## Totals

| | This list | First version (2026-09-12) |
|---|---|---|
| Stage A: assemble and power up | EUR 299 | EUR 924 |
| R1 extras (PD charger if not owned, USB-C meter) | EUR 35-70 | included above |
| Stage B: measure, interface owned / bought | EUR 32 / about 100 | EUR 752 (with scope) |
| Optional scope | EUR 64 or 131 | included above |
| **Everything, worst case** | **about EUR 500** | **EUR 1,680** |
| Everything, owning a charger and an interface, no scope | about EUR 365 | |

The original envelope of EUR 500-1000 holds with room to spare.

## Where the money went, and why it does not have to

**The supplies.** The question "why not a second-hand computer PSU" deserves
a straight answer. An ATX supply does have a -12 V rail, but it is rated at
0.3-0.5 A, often absent on modern units, and poorly regulated; and none of its
rails has an adjustable current limit. The +12 V rail will push 20 A into a
solder bridge. The current limit is the entire reason to own a bench supply:
set to 100 mA it turns a shorted board into a warm spot and a lit CC lamp
instead of a smoking chip (see Safety). That feature costs EUR 55 per rail
in a no-name box with two knobs. Programmability, which the first list paid
EUR 115 extra per unit for, is only worth it once a calibration script needs
to sweep a rail, and nothing planned does. A used bench supply from 2dehands
or Marktplaats at EUR 30-40 is a perfectly good answer too, if it has a CC
knob and its output floats.

**The iron.** A Weller lasts twenty years and has tips in every shop. A EUR 30
Velleman solders 2.54 mm pads exactly as well; if it dies in three years, buy
another. Tip selection is smaller; the stock tip is fine for everything on
these boards.

**The meter.** 9999 counts at EUR 45 gives the millivolt where it matters
(references, CVs, offsets, all below 10 V). The EUR 79 UT139C had fewer counts.

**The interface.** Any 24-bit USB audio interface is a better audio-band
analyser than any scope on this page, and a Behringer at EUR 60 has the same
converters as the Focusrite at EUR 180 for this purpose.

**The scope.** Deferred, see above. EUR 429 was a quarter of the first list.

## How the laptop talks to the instruments

Only one instrument on this list is scriptable, and it is the one that does
the precision measurements.

| Instrument | Library | What the ritual measures with it |
|---|---|---|
| USB audio interface | `sounddevice` (PortAudio), `numpy`, `scipy`; WASAPI works without a vendor driver, ASIO with one | Pitch tracking: record the oscillator, estimate frequency from the zero-crossing period over one second, convert to cents against the expected 1 V/octave point. Filter response: play a swept sine out of channel 1, record the filter output, divide spectra. Noise floor: record a module output at rest. Crosstalk: drive a noisy net, record a quiet one, read the injected millivolts off the spectrum (this is the check the router's coupling model in `toolkit/src/Route/Analog.hs` predicts). Turn any "auto gain" or "air" feature off. |
| Multimeter, bench supplies, USB-C meter, FNIRSI scope | none | Read by eye, typed into the log. |

A small `instruments.toml` in the repo (not yet written) names the interface's
device name and sample rate so the ritual scripts read it from one place.

## Safety, in plain language

**Static (ESD).** Walking across a room can charge you to several thousand
volts; touching a chip's pin discharges that through the chip. Wear the wrist
strap clipped to a known ground whenever you handle a bare board, keep boards
in their anti-static bags until needed, and do not slide them across a plastic
desk.

**Fumes.** The smoke from soldering is vapourised flux, not lead. It is an
irritant and a sensitiser. Open a window, put a desk fan behind the board
blowing across the joint away from your face, and do not lean in over the
smoke. That is the whole answer for a few hours of through-hole soldering a
month; no extractor is planned.

**Eyes.** Flux spits, a clipped lead flies, a hot blob drops. The safety
glasses go on before the iron goes on and stay on until it is cold.

**The hot iron.** The tip is 300-350 °C and does not look hot. Always return
it to its stand, never lay it on the mat. Do not solder with the cable across
your lap. Wash your hands before eating.

**Never mains.** Nothing in this lab works on 230 V except the plugs of the
instruments themselves. Do not open a supply's case, do not probe inside a
wall charger.

**Series supplies must float.** With two supplies in series, the junction
where the first supply's plus meets the second's minus is the board's 0 V.
That is only safe if both supplies' outputs are isolated from mains earth.
Most bench supplies are, and the series connection depends on it; confirm it
in the manual before the first power-up, and if an output turns out to be
earth-referenced, do not wire the two in series. The same rule bites twice
more: a mains-powered scope's probe ground clip *is* earth, so it goes only on
the board's 0 V, never on a rail; and the audio interface's input sleeve is
the laptop's ground, which is earth if the laptop is on its charger. A
battery-powered handheld scope has no such issue, which is a point in favour
of the FNIRSI.

**How the current limit protects a first power-up.** A finished module draws
perhaps 20-60 mA per rail. Before connecting it, set both supplies to 12.00 V
and their current limits to about 100 mA (short the output leads together
briefly with the current knob turned down, then turn it up until the display
reads 0.10 A). Check with the meter that the header shows no short between
any rail and ground. Switch on: a correct board draws its few tens of
milliamps and the voltage reads 12 V. A board with a bridge or a reversed part
tries to draw more, the supply refuses, its voltage collapses, and the CC
light comes on. Nothing gets hot enough to matter. Switch off, find the fault.
Raise the limit only once the board has proven itself at the low one.

## What was not verified on 2026-09-13

- All prices marked verified this date were read from bol.com search-result
  cards; no product page was opened. Fine print to confirm before paying:
  the Rosfix supply's floating output and CC behaviour; the UT60EU's count
  and beeper (the card said 9999 counts); the DSO-TC3's bandwidth.
- Items marked "verified 2026-09-12" were read from product pages by the
  first pass and were not re-checked.
- Behringer interfaces were not found on bol.com (.be or .nl) under any model
  name; the EUR 60-70 figure is from memory of Thomann's pricing. Whether
  Thomann or Bax take Bancontact was not checked. A generic "USB audio
  interface" search on bol.com was not run and may turn up an equivalent.
- No Eurorack power supply or ribbon cable is listed on bol.com; Thomann
  (Doepfer) is the source when a case exists, which is a separate budget.
- Hantek 6022BE, Pinecil at a sane price (bol.com lists one at EUR 197), TS101,
  Aneng meters, UT33D+, UT61E+: not listed or not priced.
- The ATX -12 V rail figures and the Amazon/AliExpress prices for the USB-C
  meter and the Hantek are from memory.
