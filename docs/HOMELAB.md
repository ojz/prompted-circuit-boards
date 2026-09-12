---
status: "maintained"
owner: "the agent keeps it current; the user buys and confirms"
read_when: "buying lab equipment, or planning a measurement or calibration session"
update_when: "a purchase is made, a price or listing changes, or a measurement need appears"
retire_when: "the lab exists and its inventory is recorded elsewhere"
prices_checked: "2026-09-12"
---

# Home lab: from an empty desk to measured modules

A shopping list for one person in Belgium, paying with a debit card on bol.com,
who has to take five factory-assembled Eurorack boards per order, solder the
through-hole parts onto them, power them up without burning anything, and then
measure them against what the simulation predicted. Everything below is tied to
one of those jobs. Prices are what I saw on bol.com on 2026-09-12; the last
section lists every number I could not confirm.

How to read the price column:

- **verified** means I opened the product page and the price was shown.
- **unverified** means the number came from a search snippet or I could not open
  the page; treat it as a rough figure and check before paying.
- **not on bol.com** means I searched and found no suitable listing, so a nearby
  EU source is named instead. Whether that source takes Bancontact is not
  something I could check.

bol.com is a marketplace: many of these are sold by third parties (Conrad.be,
VGBrandShop, DutchDo, Lemona) through bol.com's checkout, so the payment method
is bol.com's regardless of seller. Prices on the same listing differ between
the .nl and .be storefronts by a few euros; I quote the one I saw.

## The four jobs the lab must do

1. **Assemble.** Solder jacks, potentiometers, IDC power headers, trimmers, LEDs
   and possibly a USB-C receptacle onto boards whose small surface-mount parts
   are already placed. Undo mistakes. Inspect. Do not zap the chips with static,
   do not breathe the smoke, do not get flux in your eye.
2. **Power up safely.** Check for shorts with a meter first. Then feed the board
   from a bench supply with a current limit set low enough that a wiring error
   cannot heat anything. Eurorack wants +12 V and -12 V at once, so the supply
   must produce both. One board in the queue is itself a USB-C Power Delivery
   supply, so a PD charger and an inline USB-C meter are needed as well.
3. **Measure, from the laptop.** DC voltages to about 1 mV. Oscillator
   frequency to 0.1 % or better (that is what "within 2 cents" means: 2 cents
   is 0.116 % in frequency). Waveforms, filter responses, noise spectra and
   millivolt-level crosstalk. Ideally every instrument is scriptable from
   Python so the calibration ritual can be a script rather than a clipboard.
4. **Connect things.** Patch cables, power ribbons, scope leads, jumper wires,
   and the small consumables that make all of the above possible.

## Stage A: assemble and power up safely

Must exist before the first boards arrive. Every price in this table is
verified unless marked.

| Item | What it is, in plain language | Why (job) | bol.com listing (roughly as titled) | Price seen 2026-09-12 | Scriptable? |
|---|---|---|---|---|---|
| Soldering station | A temperature-controlled iron in a base unit. Temperature control is what lets you solder a big ground pad without cooking the plastic of the jack next to it. 70 W recovers heat fast on the thick pours these boards have. | 1 | Weller WE 1010 - 1-Kanaals Digitaal Soldeerstation - 70W / 230V (sold by Weller) | EUR 164.00, verified | no |
| Solder, lead-free | 0.5 mm wire with flux inside. Thin wire is right for the 2.54 mm and 3.5 mm pads on these boards. Lead-free melts hotter (about 227 C) and needs a little more patience than leaded. | 1 | Stannol HS10 2,5% 0,5MM SN99,3CU0,7 CD 100G Soldeertin, loodvrij (Lemona electronics) | EUR 26.28, verified | no |
| Solder, leaded (alternative) | 60/40 tin-lead, 0.6 mm. Easier to work with if you are rusty; wash hands afterwards. Either is fine for boards you keep. | 1 | Velleman Soldeer, Sn 60 % Pb 40 %, 0.6 mm, 100 g, spoel | in stock, price not shown: unverified | no |
| Flux pen | Liquid flux in a felt pen. A dab on a pad makes solder flow where it should; the cure for a joint that "won't take". | 1 | Stannol flux pen - 10ml (Lemona electronics) | EUR 12.93, verified | no |
| Desoldering wick | Copper braid that soaks up molten solder. This is how you remove a bridge or free a pin. | 1 | Velleman Desoldeerlint, 4 stuks, in dispenser, 150 cm (DutchDo) | EUR 16.00, verified | no |
| Desoldering pump | A spring-loaded syringe that sucks molten solder out of a through-hole. Wick for small amounts, pump for a filled hole. | 1 | Desoldeer pomp - extreme (Prolech.nl) | EUR 8.95, verified | no |
| ESD silicone work mat | Heat-proof, static-dissipative mat with pockets for screws. Protects the desk and gives the wrist strap something to clip to. | 1 | Velleman Soldeermat van siliconen, 450 x 300 mm, antistatische ESD-werkmat (VGBrandShop) | EUR 25.01, verified | no |
| ESD wrist strap | Elastic band with a resistor and a clip lead. Static from your body is enough to damage the op-amps and any microcontroller; the strap bleeds it away. | 1 | Kotebonk Antistatische ESD polsband (EFshop.nl) | EUR 7.95, verified | no |
| PCB holder | A clamp that holds the board on edge and rotates, so you can solder one side while the parts sit flat on the other. | 1 | Velleman Klemkit voor printplaat, 360 graden houder, printplaten tot 14 mm (VGBrandShop) | EUR 21.29, verified | no |
| Flush side cutters | Small pliers that cut component leads flat against the board. | 1 | Knipex 77 02 130 Zijkniptang Elektronica en fijnmechanica 130 mm (sold by bol) | EUR 47.45, verified | no |
| ESD tweezers | Fine tweezers for holding a trimmer or LED lead in place while soldering. | 1 | Precisie pincet ESD 6 stuks set (Knaak) | EUR 7.95, verified | no |
| Safety glasses | Flux spits and clipped leads fly. EN166 is the standard for impact-rated eyewear. | 1 | Giss - Veiligheidsbril - EN166 en EN175 (SJUSJU) | EUR 10.95, verified | no |
| Magnifier lamp | A lit magnifying glass on an arm. Enough to check the factory-placed 0603 parts for tombstones and bridges, and your own joints for wetting. | 1 | W&Z Loeplamp met LED Verlichting - 72 LEDs - 10x Vergroting - Tafelklem (Calvion) | EUR 29.89 deal price (regular 34.95), verified | no |
| Isopropyl alcohol | 99.9 % IPA, 1 litre. Removes flux residue, which otherwise looks ugly and can be slightly conductive on high-impedance nodes. | 1 | Degros - Isopropyl Alcohol - 1 liter - 99,9% Zuiver (Uitverkoop Online) | EUR 16.99, verified | no |
| Kapton tape | Heat-resistant tape. Masks a neighbouring part while you rework, holds a wire down. | 1 | Kapton Hittebestendige Tape 10 mm x 30 Meter (Actie4you.nl) | EUR 8.95, verified | no |
| Multimeter | Hand-held meter for volts, ohms and continuity. 6000 counts means 1 mV resolution below 6 V (offsets, references) and 10 mV on the 12 V rails. The continuity beeper is the short-circuit check before first power. | 2, 3 | Multimeter UNI-T UT139C - True RMS en temperatuurmeting (sold by bol) | EUR 79.00, verified | no PC link; see Stage C for the 1 mV-on-the-rails upgrade |
| Bench power supply, x2 | A box that gives an adjustable voltage with an adjustable current ceiling. Two identical single-channel units in series make the bipolar rail: the plus of one wired to the minus of the other becomes ground, the free ends are +12 V and -12 V, each with its own current limit. Both have USB and vendor Windows software. | 2 | Velleman Laboratoriumvoeding, programmeerbaar via PC, regelbaar, 0-30 VDC/5 A, stroombegrenzing, USB-aansluiting (VGBrandShop) | EUR 169.90 each, EUR 339.80 for two, verified | USB serial with Velleman software; see "How the laptop talks" |
| USB-C PD charger | A 65 W GaN wall charger. The PD-powered Eurorack supply board needs a source that can negotiate at least 45 W. | 2 | UGREEN Nexode RG GaN Oplader 65W Fast Charger 2x USB-C 1x USB-A (sold by bol) | EUR 34.99, verified | no |
| USB-C inline meter | A small pass-through with a screen that shows the volts and amps actually flowing on the USB-C cable. Tells you whether the board negotiated 15 V or 20 V and what it draws. | 2 | USB C Tester 240W - Oplaadtester, Voltmeter en Spanningsmeter (PM. Producten) | EUR 41.71, verified; whether it names the PD protocol is unverified | no |
| Banana test leads | Leads with 4 mm banana plugs on one end and insulated crocodile clips on the other. Connect the supplies to the board's power header and to each other. | 2 | Velleman SET MEETSNOEREN - BANAANSTEKKER / GEISOLEERDE KROKODILLENKLEM, 3 leads (DutchDo Belgie) | EUR 7.37, verified | no |
| Heat-shrink assortment | Tubing that shrinks with heat to insulate a joint. For the home-made power harness and pads. | 4 | Krimpkous Assortiment - Krimpkousen Set in Doos - 5 kleuren, 12 maten, 530 stuks | EUR 16.95, unverified (snippet) | no |

Also needed, not priced here: a USB-C to USB-C cable marked 60 W / 3 A (a few
euros, any brand) for the PD charger, and a spare Weller ET tip or two in a
finer size for the small pads (the station ships with one 1.6 mm chisel).

**Stage A subtotal: EUR 924.41** (EUR 907.46 of it verified; the heat-shrink
line is the only unverified number). Two-thirds of that is three items: the
station, the pair of supplies, and the multimeter.

A leaner Stage A, if EUR 900 before the first board is too much: the Knipex
cutter can be a EUR 10 no-name cutter for now, the magnifier lamp can wait
for Stage C, and the second supply can be bought a week after the first once
you have seen the first one work. That takes Stage A to roughly EUR 680 with
one supply, EUR 850 with two.

### Where a choice matters in Stage A

**Two single supplies (EUR 339.80, verified) vs one dual-channel supply
(EUR 281, unverified).** bol.com lists a QJE "Regelbare voeding 2x30V/5A
digitaal programmeerbaar" (model QJ3005P III) with USB control and series
mode, which is the textbook Eurorack bench supply, but I could not get its
page to show a price (a search snippet said EUR 281 from ElectronicaNL.nl) and
its USB protocol is undocumented. The Velleman single is in stock at a
confirmed price and belongs to a family whose serial protocol the community
has already reverse-engineered. Recommendation: two Vellemans unless the QJE
price confirms at checkout and you are content to drive it from its own
Windows program rather than Python. The Korad KA3005P and its RND relabel,
which would have been the obvious cheaper single, are both "not available" on
bol.com today.

**UT139C (EUR 79, verified) vs UT61E+ (EUR 174.65, unverified).** The UT61E+
has 22,000 counts, which means 1 mV resolution all the way up to 22 V, so the
12 V rails read to the millivolt, and it has a USB link. The UT139C is
6000 counts: 1 mV below 6 V, 10 mV above. For rails 10 mV is plenty; for
offsets and references you are below 6 V anyway. Recommendation: UT139C now,
and if millivolt rails matter later, buy the UT61E+ from a specialist shop
where it is usually around EUR 100 (that figure is from memory and
unverified), not at the bol.com price.

**Weller WE 1010 (EUR 164) vs a EUR 40-80 station.** bol.com has cheaper
digital stations (Trotec PSIS 10 was "not available"; Toolcraft ST-100D and
Velleman VTSSC-series exist but I did not price them). The Weller is a
decision you make once; tips are available everywhere for a decade. If money
is tight, this is not the place to save it, the second supply is.

## Stage B: measure and script

What the calibration ritual needs. Buy the audio interface first; it covers
more of the ritual than people expect, and the scope can follow when funds
allow.

| Item | What it is | Why (job) | bol.com listing | Price seen 2026-09-12 | Scriptable? |
|---|---|---|---|---|---|
| USB audio interface | A box with two line/instrument inputs and two line outputs, 24-bit at up to 192 kHz. From Python it is a two-channel signal generator and a two-channel spectrum analyser with about 110 dB of dynamic range. Also a music tool later. | 3 | Focusrite Scarlett 2i2 (4e Generatie) - 2-in, 2-out USB-C Audio-interface (GitaarSessies.nl) | EUR 179.90, verified | yes: `sounddevice` |
| Oscilloscope, bench | Shows voltage against time. Four channels at 50 MHz is far more bandwidth than audio needs, but four channels lets you watch input, output and both rails at once, and it has USB and LAN for remote control. 8-bit resolution. Four probes included. | 3 | Rigol DS1054Z Digitale oscilloscoop 50 MHz 4-kanaals 1 GSa/s 24 Mpts 8 Bit (Conrad.be) | EUR 429.00, verified | yes: `pyvisa`, SCPI over USB-TMC or LAN |
| Patch cables | 3.5 mm mono cables, the Eurorack standard. Fifteen in four lengths. | 4 | Bowl Modular - Combo-pack van 15 patchkabels voor eurorack - recht - 75, 90, 120 en 150 cm | EUR 42.99, verified | no |
| BNC to crocodile lead | Lets the scope, or a generator, clip onto a pad or a patch cable tip without a probe. | 4 | Velleman coaxkabel 1m - BNC mannelijk + 2 krokodillenklemmen (VGBrandShop) | EUR 19.48, verified | no |
| 3.5 mm to 2x 6.35 mm cable | Connects a module's output to the interface's two jack inputs (the interface takes 6.35 mm plugs, the module 3.5 mm). Buy two so both interface outputs can also drive a module. | 4 | 3.5mm Jack AUX TRS naar 2X 6.35mm TS Splitter Audio Kabel - 30 CM (Provium) | EUR 12.99, verified | no |
| Dupont jumper wires | Thin pre-terminated wires with 2.54 mm pins. They plug straight into the board's IDC header for a temporary bench power connection, and into the breadboard. | 4 | Dupont kabels voor breadboard / Arduino (65 stuks) - Diverse lengtes (Conrad.be) | EUR 15.39, verified | no |
| Breadboard | A plug-in board for tiny experiments: the attenuator pad below, a test load, an LED indicator. | 4 | Velleman Breadboard, soldeervrij, 830 contacten (DutchDo) | EUR 12.73, verified | no |
| Hook-up wire | Solid-core wire in six colours for the bench power harness and the pads. | 4 | Hook-up Wire Spool Set - 22AWG Solid Core - 6 x 25 ft Adafruit 1311 (VanAllesEnMeer.nl) | EUR 40.01, verified | no |
| Eurorack power ribbons | 16-pin to 10-pin (2x8 to 2x5) ribbon cables with IDC sockets, the cable every module ships with. | 4 | not on bol.com (only PCB-mount box headers, EUR 7.24 and 7.29, and 20-pin cable sockets were found) | see note | no |

**Power ribbons note.** bol.com has no ready-made Eurorack power cable. Nearest
EU sources: Thomann (Germany) sells Doepfer and generic 16-to-10-pin bus
cables, and Conrad.be carries 10- and 16-way IDC sockets plus 1.27 mm ribbon
to crimp your own in a vice (Conrad.be also sells through bol.com, so a
targeted search there may turn one up). Whether either takes Bancontact I did
not check. For the very first power-up you do not need a ribbon at all: the
supplies go to the header pins with Dupont wires, which is also safer because
you connect exactly three wires and can see all of them.

**Attenuation note, important.** Eurorack signals swing plus or minus 10 V
(about 7 V RMS, roughly +19 dBu). A Scarlett 2i2 line input clips somewhere
around +22 dBu at minimum gain (from memory; check the manual), so a full-scale
module output is right at the edge, and the interface is AC-coupled, so it
cannot see DC at all. Two consequences: build a 4:1 resistive pad (two
resistors on the breadboard, or soldered into a 3.5 mm to 6.35 mm cable) for
any signal you send into the interface, and use the scope or the multimeter,
never the interface, for anything DC: offsets, CV levels, rails. In the other
direction the interface's line output gives a few volts peak at most, which
is fine as a stimulus for a filter but will not drive a module to full scale.

**Stage B subtotal: EUR 752.49** (all verified). Split: audio interface and
cables EUR 323.49, scope EUR 429.00.

**Running total after A + B: EUR 1,676.90.** That is above the EUR 1,000
ceiling, which is why the stages are ordered as they are: Stage A
(EUR 924) is what the first boards need; Stage A plus the audio-interface
half of Stage B (EUR 1,248) already runs the pitch-tracking, filter-response,
noise and crosstalk measurements at audio frequencies from Python; the scope
(EUR 429) adds DC, waveform shape, power-up behaviour and the USB-PD board's
switching, and is the last thing to buy, not the first.

### Where a choice matters in Stage B

**Bench scope (Rigol DS1054Z, EUR 429, 8-bit, verified) vs USB scope
(PicoScope 2204A, not available on bol.com today).** A PicoScope is a box with
no screen that turns the laptop into the scope, with a genuinely good Python
SDK and a built-in signal generator; the 2204A is 10 MHz, 8-bit, two
channels, and elsewhere costs on the order of EUR 150-180 (unverified; Pico's
own shop or Batronix in Germany). It is enough for audio work and half the
price, but bol.com's listing is "not available", it has two channels, and
there is no screen to glance at while you hold a probe. Recommendation: the
Rigol if the budget stretches to it, because four channels and a front panel
make first power-up less nerve-racking, and a scope you can poke at without
opening a laptop gets used more. If not, the PicoScope from a specialist,
with the same scripting story.

**12-bit or not.** A 12-bit scope resolves 16 times finer than an 8-bit one,
which is what you want when you look for a millivolt of crosstalk riding on a
10 V signal. Rigol's DHO804 and Siglent's SDS800X HD are the affordable 12-bit
scopes and neither is on bol.com. Voltcraft's DOV704 (70 MHz, 4 channels,
12-bit, USB, LAN and HDMI, USB-C powered) is sold by Amazon.de, Galaxus and
SOS electronic; one search result claimed it appears on bol.com but I could
not find the listing, and its price is unverified everywhere. Its spec sheet
matches the Rigol DHO804 line for line; if it is a relabel it speaks the same
SCPI, but that is inference, not verification. Practical answer: the
interface's 24-bit converter is the millivolt-crosstalk instrument at audio
frequencies; the scope's job is time-domain and DC, where 8 bits is fine.
Buy 8-bit now, and revisit 12-bit only if a measurement actually runs out of
resolution.

**Scope with a built-in generator.** The Rigol DS1104Z-S Plus (100 MHz, two
25 MHz arbitrary generator channels) is EUR 765.00 on bol.com from Conrad.be,
verified. It would replace the interface as stimulus source, but not as
spectrum analyser, and costs EUR 336 more than the DS1054Z. The interface
already is a two-channel generator up to 20 kHz, which is the band that
matters. Not recommended at this budget.

## Stage C: nice to have

Buy when a specific need appears, not before.

| Item | Why | bol.com listing | Price seen 2026-09-12 |
|---|---|---|---|
| Fume extractor | A fan behind a carbon filter that pulls the flux smoke away from your face. Stage A relies on an open window and a desk fan; this is the proper version. Every stand-alone extractor I opened on bol.com was "not available" (BLANKO ZD-153, Vevor 38 W, Speeddrones 30 W, Corenia 100 W). | Weller WE 1010 ZeroSmog Shield Kit (station plus 20 W extraction, Conrad.nl) is the one verified in-stock option, but it duplicates the Stage A station | EUR 389.00, verified |
| Better multimeter | UT61E+: 22,000 counts, 1 mV on the 12 V rails, USB link. | Multimeter True RMS - USB-communicatie - UT61E+ | EUR 174.65, unverified; typically about EUR 100 from Welectron or Batronix (unverified). Brymen BM235 from Welectron is the other classic in this class, not on bol.com |
| Second multimeter | Reading current and voltage at the same time during power-up. A cheap manual-ranging meter is enough. | UNI-T UT131B Compacte digitale multimeter (in stock, no price shown); UNI-T UT33D was "not available" | unverified |
| USB microscope | For inspecting 0603 solder joints properly; the magnifier lamp is the poor man's version. Both listings I opened were "not available". | OEM Digitale USB microscoop camera 1600x (not available) | n/a |
| Third hand with magnifier | Holds wires while both hands are busy. | Hanse Werkzeuge Derde Hand/Printplaathouder (not available); Weller WLACCHHB-02 exists, not priced | unverified |
| Decent tweezers | A single pair of good stainless tweezers instead of the six-pack. | not searched | n/a |
| IDC crimp sockets and ribbon | To make Eurorack power cables to length. | 16-Pin 2x8 Male IDC Box Header EUR 7.29 and 10-Pin 2x5 EUR 7.24 are PCB headers, not cable sockets; cable sockets not confirmed | see Stage B note |
| Fluke 117 | Mentioned so nobody wonders: it is EUR 352.98 on bol.com (verified), 6000 counts, no PC link. Good meter, wrong purchase for this lab. | Fluke 117 EUR Digitale True-RMS multimeter (Get Goods) | EUR 352.98, verified |

**Stage C subtotal: about EUR 175-565** depending on what is picked (the two
priced items are EUR 389.00 verified and EUR 174.65 unverified).
**Running total after A + B + C: EUR 1,850-2,240.**

## How the laptop talks to the instruments

The laptop is Windows 11 with Python 3.13. Nothing here needs a specific IDE.
No scripts are written in this document; this is the wiring diagram for them.

| Instrument | Library | Connection | Windows gotcha | What the ritual measures with it |
|---|---|---|---|---|
| Rigol DS1054Z | `pyvisa` with either NI-VISA or the pure-Python `pyvisa-py` backend | USB-TMC (the rear USB-B) or Ethernet. The bol.com listing only mentions USB; Rigol's datasheet lists LAN as standard on the DS1000Z, and LAN is the one to use. | Over USB, Windows needs a USB-TMC driver: NI-VISA installs one, and `pyvisa-py` needs libusb, which on Windows usually means swapping the driver with Zadig. Over LAN there is no driver at all: give the scope a fixed IP and open `TCPIP::<ip>::INSTR`. | Frequency counter and `:MEASure:FREQuency` per channel for pitch tracking (though see the interface row: the interface does this better); rail voltages at power-up; rise and fall of the PD board's switching node; DC offsets; waveform captures via `:WAVeform:DATA?` for anything the interface cannot see. |
| Voltcraft DOV704 / Rigol DHO804 (if ever bought) | `pyvisa` | USB-TMC or LAN | as above | as above, with 16x the vertical resolution |
| PicoScope 2204A (if chosen instead) | `picosdk` (Pico's `picosdk-python-wrappers`) on top of the PicoSDK C libraries | USB, bus-powered | Install PicoSDK (the 64-bit installer) before the Python package; the wrappers find the DLLs through it. | Same as the Rigol row, plus its built-in generator as a stimulus for filter sweeps. |
| Velleman programmable supply (each of the two) | `pyserial`. The supply enumerates as a USB serial port. | USB | Windows assigns a COM port per supply; note which is which, or read the identification string at start-up. The Velleman software is the fallback. The command set is not documented on the listing; this family is widely reported to answer Korad-style text commands (`VSET1:12.00`, `ISET1:0.100`, `VOUT1?`), which is unverified for this exact unit and should be confirmed with a terminal before anything is automated. | Set both rails to 12.00 V with a 100 mA limit, switch on, read back the current on each rail, ramp, and log. |
| QJE dual supply (if chosen instead) | vendor Windows software only, until its protocol is found | USB, galvanically isolated | Unknown protocol: budget an evening with a serial sniffer or treat it as manual. | as above, by hand |
| Focusrite Scarlett 2i2 | `sounddevice` (PortAudio) with `numpy` and `scipy` | USB-C, USB-audio class | Install Focusrite's driver for ASIO and low latency; `sounddevice` also works through WASAPI without it. Set the sample rate in the Focusrite control panel and match it in Python or you get resampling. Turn "Air" and "Auto Gain" off. Inputs are AC-coupled: no DC. | Pitch tracking: play nothing, record the oscillator, estimate frequency from the zero-crossing period over one second, convert to cents against the expected 1 V/octave point. Filter response: play a swept sine or a multitone out of channel 1, record the filter output, divide spectra. Noise floor: record with the input patched to a module output at rest. Crosstalk: drive a noisy net, record a quiet one, read the injected millivolts off the spectrum (this is the check the router's coupling model in `toolkit/src/Route/Analog.hs` predicts). |
| UNI-T UT139C | none | none | n/a | Continuity before power; rail and reference voltages read by eye and typed in. |
| UNI-T UT61E+ (Stage C) | UNI-T's own PC software over its opto-isolated USB cable (sold separately as UT-D04); `sigrok` supports the UT61 family, UT61E+ specifically unverified | USB via the optical cable | Cable not included in most listings. | Logged rail and reference voltages to the millivolt. |
| USB-C inline meter | none | none | n/a | Read negotiated voltage and current by eye during PD board bring-up. |

Two conventions worth fixing early: a fixed IP for the scope so scripts never
hunt for it, and a small `instruments.toml` in the repo (not yet written) that
names each COM port and VISA resource, so the ritual scripts read the address
from one place.

## Safety, in plain language

**Static (ESD).** Walking across a room can charge you to several thousand
volts; touching a chip's pin with that discharges it through the chip. Wear
the wrist strap clipped to the mat or to a known ground whenever you handle
a bare board, keep boards in their anti-static bags until needed, and do not
slide them across a plastic desk.

**Fumes.** The smoke from soldering is vapourised flux, not lead, but it is an
irritant and a sensitiser: enough exposure and you become allergic to it.
Open a window, put a small desk fan behind the board blowing across the joint
away from your face, and do not lean in over the smoke. A carbon-filter
extractor (Stage C) replaces the fan properly.

**Eyes.** Flux spits, a clipped lead flies, a hot blob drops. The safety
glasses go on before the iron goes on and stay on until it is cold.

**The hot iron.** The tip is 300-350 C, hotter than a kitchen pan, and it does
not look hot. Always return it to its stand, never lay it on the mat. Do not
solder with the cable draped across your lap. Put a leaded solder spool and
your sandwich on different tables and wash your hands before eating. Keep the
iron off when you are reading the schematic; the stand-by timer is there for
the times you forget.

**Never mains.** Nothing in this lab works on 230 V except the plugs of the
instruments themselves. The bench supplies, the boards, the scope inputs, the
interface: all of it is 30 V or less. Do not open a supply's case, do not
probe inside a wall charger, and if a project ever needs mains, that is a
different document and a different set of rules.

**The scope's ground clip is mains earth.** Every oscilloscope input shares one
ground, and on a mains-powered scope that ground is the protective earth of
the wall socket. So the black crocodile clip on a probe is not "a second test
lead": it connects whatever it touches to earth, hard. Two rules follow. Clip
it **only to the board's ground (0 V)**, which with two supplies in series is
the junction where the first supply's plus meets the second's minus; clipping
it to the +12 V or -12 V terminal shorts that supply straight through the
scope and the wall. And that arrangement is only safe if both supplies'
outputs are **floating**, meaning isolated from earth. Most bench supplies
are, and the series connection depends on it; confirm it in the Velleman
manual before the first power-up, and if an output turns out to be
earth-referenced, do not wire the two in series. The audio interface has the
same property in a milder form: its input sleeve is the laptop's ground, which
is earth if the laptop is on its charger.

**How the current-limited supply protects a first power-up.** A finished
module draws perhaps 20-60 mA from each rail. Before you connect it, set both
supplies to 12.00 V and their current limits to about 100 mA, then check with
the meter that the header shows no short between any rail and ground. When you
switch on, a correct board draws its few tens of milliamps and the voltage
reads 12 V. A board with a solder bridge or a reversed part tries to draw more,
the supply refuses to give more than 100 mA, its voltage collapses to whatever
that current produces across the fault, and the CC (constant current) light
comes on. Nothing gets hot enough to matter, because 100 mA into a short is
a fraction of a watt spread over a copper pour. You switch off, look for the
fault, and nothing is lost. Without the limit, a wall adapter or a Eurorack
bus board would push amps into the same short and something would smoke.
Raise the limit only once the board has proven itself at the low one.

## What I could not verify

Listings and prices I could not confirm from the product page on 2026-09-12:

- **QJE Regelbare voeding 2x30V/5A digitaal programmeerbaar (QJ3005P III).**
  Page shows "in stock" but no price to my fetcher; a search snippet said
  EUR 281.00 from ElectronicaNL.nl. USB protocol unknown.
- **UNI-T UT61E+.** Page shows "in stock" but no price; a search snippet said
  EUR 174.65, which is well above the usual street price. The EUR 100 figure I
  give for specialist shops is from memory.
- **Velleman Soldeer Sn60/Pb40 0.6 mm 100 g.** In stock, no price shown.
- **Krimpkous assortiment 530 stuks.** EUR 16.95 from a search snippet only.
- **USB C Tester 240W (EUR 41.71).** Price verified; whether it displays the PD
  protocol and negotiated contract, rather than just live volts and amps, is
  not stated on the listing. The FNIRSI FNB58 listing (which does sniff PD) is
  in stock on bol.com with no price shown.
- **Behringer U-Phoria UMC202HD.** Search snippet said EUR 116.30; the page
  showed out of stock. Would have been the cheaper interface.
- **Voltcraft DOV704.** Could not find it on bol.com despite a search claiming
  it is there; Amazon.de, Galaxus and SOS electronic list it; no price seen
  anywhere. Its identity as a Rigol DHO804 relabel is inference from the spec
  sheet.
- **PicoScope 2204A.** bol.com listing is "not available"; the EUR 150-180
  elsewhere is from memory.
- **Eurorack power ribbon cables.** Not found on bol.com; Thomann and Conrad.be
  named as sources without checking their payment methods.
- **UNI-T UT131B, UT61B+, Baku BK-493 fume extractor, Velleman VTS60SF
  station-with-extraction, Stannol HS10 60/40 1.5 mm, McPower 60/40
  dispenser, Ugreen GaN X 65 W, DrPhone TC66.** All show "in stock" with no
  price visible to me.
- **Not available on bol.com today** (listing exists, cannot be bought):
  Rigol DS1102Z-E, PicoScope 2204A, Trotec PSIS 10, Korad KA3005P, Korad
  KD3005D, RND 320-KA3005P, Hantek DSO2D15, Voltcraft DSO-2020, Anker Nano II
  65 W, Felder ISO-Core EL 0.5 mm, Stannol Kristall 400 0.5 mm, BLANKO ZD-153,
  Vevor 38 W and Corenia 100 W extractors, OEM USB microscope, Hanse third
  hand, PolarNoise 5-pack patch cables (blue 30 cm variant), Fay-Trading and
  AA Commerce heat-shrink sets, the unbranded 2x 0-30 V + 5 V supply.
- **Technical claims from memory, not from a datasheet opened today:** the
  Scarlett 2i2 4th-gen maximum line input level (about +22 dBu); the
  DS1054Z having LAN; the Velleman supply answering Korad-style commands;
  `sigrok` support for the UT61E+.
- **Payment.** I did not and cannot check that any seller outside bol.com
  accepts Bancontact.
