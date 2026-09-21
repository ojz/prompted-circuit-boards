---
status: "maintained inventory; further procurement deferred; candidate capability checks open"
owner: "the agent keeps it current; the user buys and confirms"
read_when: "checking owned equipment or payment readiness, buying lab equipment, or planning measurements"
update_when: "a purchase is made, a price or listing changes, or a measurement need appears"
retire_when: "the lab exists and its inventory is recorded elsewhere"
prices_checked: "2026-09-13"
---

# Home Lab

Updated: 2026-09-21. Purchases and payment readiness below are user-reported;
historical candidate prices have not been refreshed.

The single shopping and equipment record for assembling and testing the modules
in Belgium. The user buys and confirms delivery; the agent checks capabilities,
compatibility and an itemized delivered total. The bench is no longer empty;
the confirmed purchases below must be accounted for before recommending more.
The number of populated PCBs is a separate fabrication quote decision, not a
reason to assume five assembly jobs; see [ORDER-READINESS.md](ORDER-READINESS.md).

**Further procurement is deferred while VCV Rack prototypes are the priority.**
Bench equipment is not a prerequisite for virtual patching. Resume shopping
against the needs of the accepted hardware design, under
[the roadmap](ROADMAP.md#v0-playable-digital-modules-and-function-balance-current),
not by completing the old empty-bench basket automatically.

**Do not buy this entire list unchanged.** Prices below are historical candidates,
not a current checkout basket. The 2026-09-14 review found unsupported supply and
measurement assumptions. This update corrects the guidance but does not verify
the product manuals or refresh prices.

The first EUR 1,680 proposal was rejected as too expensive. Retain the agreed
EUR 500-1000 planning envelope and choose economical equipment that demonstrably
does the required job. Scriptability is a bonus, not a requirement. No extractor
has been added against the user's direction; that does not establish that the
proposed room ventilation is adequate. See Safety.

## Confirmed Purchases

| Item | Status | Still Unknown |
|---|---|---|
| Soldering iron | Already bought, confirmed by the user on 2026-09-21 | Model, temperature control, tips, stand and accessories; do not assume it is the station candidate below |
| Solder | Already bought, confirmed by the user on 2026-09-21 | Alloy, diameter, flux/core specification and quantity |
| Desolder wick | Already bought, confirmed by the user on 2026-09-21 | Width, flux specification and quantity; this does not imply ownership of a desoldering pump |

Purchase prices and suitability for a particular assembly task are not yet
recorded. No other lab equipment is confirmed owned here. These purchases do
not establish a complete assembly bench or a safe first-power/measurement setup.
Identify the actual tools when preparing a relevant hardware task; no need to
delay VCV Rack work to fill those details in now.

## Payment Readiness

The user confirmed on 2026-09-21 that a credit card is now available. Obtaining
a card is no longer a blocker, and supplier selection need not be restricted
to Bancontact-only options. A particular merchant's acceptance, delivered quote
and user approval still need checking when a purchase is actually proposed.
This does not increase the budget or authorize software, equipment, parts or
board orders. Do not record card numbers or other payment credentials here.

## Purchase Readiness

These are checks for when hardware procurement resumes, not the current work queue.

| Group | Next Step Before Buying |
|---|---|
| Assembly essentials | Start from the confirmed inventory; check stand/tip compatibility, consumable specifications and safe work area, then price only missing items. Do not reorder an iron, solder or wick from the historical list by default. |
| Power supplies and harness | Hold the named supply candidates until their manuals explicitly support the required series operation and current-limit procedure. Select a clearly keyed power connection. |
| Meter and precision measurements | Separate a basic continuity/rail meter from the instruments needed to substantiate CV accuracy. Check actual DC accuracy, range and uncertainty, not just display counts. |
| Audio interface and cables | Select for real line inputs/outputs and supported levels. User owns no 6.35 mm equipment; external audio is 3.5 mm TRS stereo. Buy a 6.35 mm adapter only for an explicitly chosen instrument that requires it. |
| PD accessories and scope | Derive R1's PD profiles, current and switching/stability measurement needs first. Do not assume any USB-C meter or inexpensive scope can perform those checks. |

When procurement resumes, the agent's deliverable is an exact, priced basket of
remaining needs and verified instrument recommendations in this file, not
another shopping document. The user approves spending and reports further
purchases; card availability does not turn this deferred task into approval.

How to read the price column:

- **verified** is the older label for a price seen on that date, not verified
  suitability, current stock or delivered cost. The 2026-09-13 pass read search
  cards, not product pages or manuals. Capability remains unverified unless
  evidence is recorded explicitly.
- **unverified** means the number is from memory or another shop; check it.
- **own it?** means most people already have one; check before buying.

Prices differ by a few euros between the .be and .nl storefronts and between
days; the .be storefront was used.

## The four jobs the lab must do

1. **Assemble.** Solder jacks, potentiometers, IDC power headers, trimmers,
   LEDs and possibly a USB-C receptacle onto boards whose surface-mount parts
   are already placed. Undo mistakes. Inspect. Do not zap the chips with
   static, do not breathe the smoke, do not get flux in your eye.
2. **Reduce first-power risk.** Inspect and check unpowered boards before using
  a reviewed, current-limited setup. Current limiting reduces fault energy but
  does not guarantee against damage or heat. Existing modules require bipolar
  rails; R1's PD converter has a separate first-power procedure still to design.
3. **Measure against a stated uncertainty.** A meter can check DC, but resolving
  1 mV is not proof of 1 mV accuracy. An audio interface can measure audio-band
  signals within its calibrated limits; it cannot supply or measure static CV
  or exclude high-frequency oscillation. Pitch tests also need a sufficiently
  accurate DC stimulus and a checked frequency timebase. R1's switching supply
  needs a suitable scope and probing method, whether bought or borrowed.
4. **Connect things.** Patch cables, test leads, jumper wires.

## Stage A: Assembly And First-Power Candidates

Historical subtotal about EUR 300. Listings were seen in stock in the original
price pass; neither present availability nor the whole basket is verified.

| Item | What it is, in plain language | Job | bol.com listing (roughly as titled) | Price | Note |
|---|---|---|---|---|---|
| Soldering station | A temperature-controlled 50 W iron in a base. Temperature control is what lets you solder a big ground pad without melting the jack next to it. 50 W is enough for 2.54 mm and 3.5 mm pads on a two-layer board. | 1 | Velleman soldeerstation instelbaar 50 W, 175-480 °C (VGBrandShop) | EUR 29.95, verified | Ships with one tip; buy a finer conical tip later if the stock one feels clumsy. A 48 W no-name at EUR 37.50 (Cotubex) is the fallback if this sells out. |
| Solder | Lead-free, 1.0 mm, 100 g, rosin core. Confirm alloy, flux and the supplier's recommended soldering temperature. | 1 | Loodvrije soldeertin Ø 1,0 mm, spoel 100 g (Cotubex) | EUR 23.99, verified | Alternative historical candidate: Stannol HS10 0.5 mm at EUR 26.28, seen 2026-09-12; verify alloy and flux before choosing. |
| Desoldering pump | A spring-loaded syringe that sucks molten solder out of a filled hole. This is how a jack comes out again. | 1 | Desoldeer pomp - extreme (Prolech.nl) | EUR 8.95, verified 2026-09-12 | A pump is distinct from wick; consult the confirmed inventory and actual rework need before buying. |
| Silicone soldering mat | Heat-resistant, non-slip work surface; check its temperature rating and secure the board. | 1 | MMOBIEL siliconen soldeermat 35 x 22 cm (MMOBIEL NL) | EUR 10.59, verified | Not ESD-rated. A wrist strap does not make an insulating surface ESD-safe. |
| ESD wrist strap | Current-limited ESD strap used with a manufacturer-approved grounding arrangement. | 1 | Kotebonk antistatische ESD polsband (EFshop.nl) | EUR 7.95, verified 2026-09-12 | Verify the safety resistor and ground connection. Do not use an arbitrary radiator or mains contact. |
| Flush side cutters | Small pliers that cut leads flat against the board. | 1 | Compacte zij-kniptang 125 mm (WH!.be) | EUR 8.29, verified | A EUR 47 Knipex does the same to a 2.54 mm lead. |
| Tweezers | For holding a trimmer or LED lead while soldering. | 1 | Precisie pincet ESD 6 stuks set (Knaak) | EUR 7.95, verified 2026-09-12 | |
| Safety glasses | Flux spits and clipped leads fly. EN166 is the impact standard. | 1 | Giss veiligheidsbril EN166 (SJUSJU) | EUR 10.95, verified 2026-09-12 | Any EN166 glasses from a DIY shop do; EUR 3-5 there. |
| Isopropyl alcohol | 99.9 %, 1 litre. Removes flux residue, which is slightly conductive on high-impedance nodes. | 1 | Isopropanol 99,9 % zuiver 1 liter (Werken met Merken) | EUR 12.95, verified | |
| Multimeter | Basic volts, resistance and continuity candidate. Obtain the DC accuracy specification, ranges, temperature limits, current-input protection and appropriately rated leads before assigning tests. | 2, 3 | UNI-T UT60EU digitale multimeter, True RMS, 9999 counts (sold by bol) | EUR 44.99, verified | 9999 counts is a display property, not proof of sub-millivolt accuracy. UT123D at EUR 29.77 was a cheaper candidate, not a verified substitute for the precision tests. |
| Bench power supply, x2 | Adjustable voltage and current ceiling (CC). Two outputs may form bipolar rails only within manufacturer-supported series and grounding limits. | 2 | Rosfix RAVED-3205 labvoeding 0-32 V, 0-5 A, CV/CC (VENTIQA) | EUR 54.99 each, EUR 109.98 for two, verified | **Hold pending the manual:** series permission, output-to-earth ratings, current-limit setting, startup behavior and protection. Floating outputs alone do not establish safe series operation. The old Stamos EUR 59 fallback is also unverified. |
| Test leads | Banana plugs on one end, insulated crocodile clips on the other. Connect the supplies to each other and to the board. | 2 | Velleman set meetsnoeren banaan / krokodil, 3 leads (DutchDo) | EUR 7.37, verified 2026-09-12 | |
| Power connection / jumper wires | First-power wiring needs secured, identified conductors and verified header polarity. Select the harness with the board-specific procedure. | 2, 4 | Historical candidate: Dupont kabels voor breadboard, 65 stuks (Conrad.be) | EUR 15.39, verified 2026-09-12 | Generic loose jumpers are not an approved substitute for a keyed power harness; exact connectors, wire ratings and insulation still need selection. |

**Historical Stage A subtotal: EUR 299.30.** This includes the unverified supply
pair and jumper candidate; it is not the final basket, the remaining spend or
a safety approval. Do not substitute these candidate prices for the unrecorded
costs of the user's actual purchases.

**For R1's USB-C PD board only, not for the attenuverter:**

| Item | Why | Listing | Price | Note |
|---|---|---|---|---|
| USB-C PD charger | Must support the actual PD profiles and power budget R1 requires; its converter has not been selected. | own it? Check the actual charger model first. Historical candidate: UGREEN Nexode 65 W (sold by bol) | EUR 0 or EUR 34.99, verified 2026-09-12 | Wattage or a USB-C socket alone is insufficient. Confirm supported profiles and a correctly rated cable; do not buy a generic 45 W minimum by assumption. |
| USB-C inline meter | Candidate aid for observing negotiated voltage/current, not a substitute for rail ripple and transient measurements. | USB C Tester, spanning en stroom (bestekoopjes.nl) | EUR 34.95, verified | Confirm voltage/current ratings, PD pass-through and effects on negotiation. An output-rail reading alone does not identify the PD contract. |

Avoid automatic upgrades, but verify that the actual method provides stable board
support, adequate inspection, suitable flux and insulated wiring. A phone camera
may help inspection; its zoom setting is not an acceptance criterion for a joint.
Buy small accessories when the assembly or probing method needs them.

## Stage B: Measurement Candidates

Choose instruments from the required tests before recommending a purchase. Some
R1 switching-supply checks are first-power work, not optional measurements to defer
until after normal operation is assumed. Buying, borrowing or supervised access
can each satisfy a measurement need if capability is established.

| Item | What it is | Job | Source | Price | Note |
|---|---|---|---|---|---|
| USB audio interface | Candidate audio stimulus/recorder. Verify two genuine line channels where the test needs them, voltage limits, impedance, bandwidth, noise, clock accuracy and Windows support. Nominal bit depth does not establish usable dynamic range. | 3 | own it? Check the model. Behringer UMC202HD remains a candidate from Thomann or Bax; not priced there in the previous pass. | EUR 0, or about EUR 60-70 previously estimated, unverified | Do not treat the previously listed UMC22 as an equivalent two-line-channel interface. No universal +20 dBu limit or 100 dB measurement capability is established for these candidates. |
| Protected measurement adapter | Attenuation, DC protection and grounding designed for the selected interface's actual input limits and impedance. | 3 | Parts and enclosure/insulated cabling to be selected after the interface | Not quoted | No raw synth-level or DC connection to an unverified audio input. A nominal two-resistor ratio alone does not establish protection or the loaded gain. |
| External audio / instrument cables | 3.5 mm TRS stereo for the consumer ports. Instrument-side plugs follow the equipment actually selected. | 4 | Old candidate only if needed: 3.5 mm TRS naar 2x 6.35 mm TS splitter, 30 cm (Provium) | Old splitter EUR 12.99, verified 2026-09-12; final cable basket unquoted | User has no 6.35 mm equipment. Do not buy this splitter by default or confuse stereo TRS with balanced mono. Ordinary phone/laptop headphone outputs are not recording inputs. |
| Patch cables | 3.5 mm mono, the Eurorack standard. Five is enough to test one board. | 4 | Bowl Modular 5 patchkabels eurorack, recht, 30 cm, zwart | EUR 18.49, verified | The 15-cable combo pack at EUR 42.99 is for when a row exists. |

**Stage B is not fully costed.** The old EUR 32 / EUR 95-105 totals assumed an
unverified interface, a simple pad and one particular splitter. They do not price
the supported setup, precision DC stimulus or timebase verification.

**Oscilloscope: select against R1's tests.** A steady meter and a clean audio-band
recording cannot exclude MHz oscillation. Required bandwidth, sample rate, probe
loading, noise floor and ground connection must come from the actual converter
and amplifier checks. These are historical price candidates, not approved scopes:

| Option | What you get | Price | Note |
|---|---|---|---|
| FNIRSI DSO-TC3 (iCables.eu) | Advertised handheld scope/component tester/generator. | EUR 63.99, verified | Bandwidth, sampling, probes and input protection were not checked. Do not assume it can examine R1's switching edges. |
| FNIRSI 2C53P (iCables.eu) | Advertised two-channel scope with a generator. | EUR 130.99, verified | Specification, supplied probes, grounding and measurement capability remain to be verified before recommendation. |

The old Hantek 6022BE (about EUR 60-70, unverified) and Rigol DS1054Z (EUR 429)
suggestions are not current recommendations either. Compare an exact measurement
need and total probe/accessory cost; do not select by scriptability or price alone.

## Totals

| Group | Price Status |
|---|---|
| Stage A candidates | EUR 299.30 for the historical empty-bench list, not the remaining basket; account for confirmed purchases and verify suitability and harness selection. |
| PD charger and inline meter | Old estimate EUR 35-70, dependent on owned equipment and the selected power design. |
| Measurement setup | Not yet fully costed; audio interface, protection, precision DC method, scope/probes and appropriate cables must be matched to the tests. |
| Delivered total | Not established. Include VAT, shipping and accessories, subtract confirmed owned items, and ask before exceeding the agreed budget. |

The previous "about EUR 500 worst case" claim is withdrawn: it was not a verified
complete setup. No budget increase or purchase is approved by this correction.

## How the laptop talks to the instruments

The audio interface is a candidate for laptop-driven audio tests. The exact
instruments and calibration method are not selected, and the scripts do not yet
exist. Automation is useful only after signal levels and measurement uncertainty
are established.

| Instrument | Library | What the ritual measures with it |
|---|---|---|
| USB audio interface | Candidate tools: `sounddevice` (PortAudio), `numpy`, `scipy`; verify Windows driver and raw audio path for the selected model | Calibrated audio transfer, noise, crosstalk and oscillator frequency. Check loopback response, clipping, gain, input loading and timebase first; disable processing and automatic gain. |
| DC stimulus and meter | Method still to select | Set and verify the actual CV at the module connector. An AC-coupled audio output cannot provide the static voltages needed for pitch calibration. |
| Supplies, USB-C meter and scope | Depends on selected models | Record settings and observations against the board revision. Scope measurements need suitable probes and bandwidth; screen resolution alone is not uncertainty. |

## Safety, in plain language

**Static (ESD).** Handle unpowered boards with an approved, current-limited ESD
grounding arrangement and appropriate work surface; keep them in their anti-static
bags when not in use. Do not improvise a connection to mains earth, a radiator or
an unidentified supply terminal. The strap must include its safety resistor.

**Fumes.** Flux fumes can irritate and sensitise the lungs; lead-free solder does
not remove that risk. Keep the plume out of the breathing zone and away from
other occupants, and follow the solder/flux safety data. The proposed window and
fan have not been assessed as adequate capture or ventilation. Establish a suitable
work arrangement before soldering; do not treat a few hours per month as a safety
guarantee. No extractor purchase is added here.

**Eyes.** Flux spits, a clipped lead flies, a hot blob drops. The safety
glasses go on before the iron goes on and stay on until it is cold.

**The hot iron.** The tip is 300-350 °C and does not look hot. Always return
it to its stand, never lay it on the mat. Do not solder with the cable across
your lap. Keep flammable IPA away from heat and ignition; allow cleaning solvent
to evaporate before soldering or powering the board. Wash your hands before eating.

**Never mains.** Nothing in this lab works on 230 V except the plugs of the
instruments themselves. Do not open a supply's case, do not probe inside a
wall charger.

**Series operation and grounding.** Require the manufacturer's series-operation
instructions, output-to-earth limits and protection requirements for the exact
supplies; floating outputs alone are not permission. Document the whole ground
path before connecting the board, scope, laptop, charger and audio equipment.
Ordinary scope probe grounds are normally common and earth-referenced; never
attach one to a supply rail or switching node. Use an appropriate measurement
method, not defeated protective earth. A battery scope is not automatically
isolated, especially with USB or charging cables attached. Laptop/audio grounds
can be connected through other equipment even when a charger itself is isolated.

**Current limiting is risk reduction, not immunity.** At 12 V, even 50 mA is
0.6 W per rail, and output capacitors can discharge before a limit responds.
Choose limits from the specific board's expected draw and fault conditions, not
a universal 100 mA recipe. Follow the supply manual's setting procedure; do not
short leads together unless that is its documented method. Disable outputs and
disconnect power before changing wiring, allow stored charge to discharge, then
verify the harness voltages and polarity with no board attached. Unexpected
current, heat, smell or voltage is a stop condition, not permission to raise the
limit. The old [attenuverter power-up guide](modules/attenuverter/POWER-UP.md)
remains a draft under review and must not be followed unchanged.

## What was not verified on 2026-09-13

- All prices marked verified this date were read from bol.com search-result
  cards; no product page was opened. The supply's series support and current
  behavior, the meter's actual accuracy and the scopes' capabilities still need
  manufacturer evidence. No price or stock refresh was performed on 2026-09-14.
- Items marked "verified 2026-09-12" were read from product pages by the
  first pass and were not re-checked.
- Behringer interfaces were not found on bol.com (.be or .nl) under any model
  name; the EUR 60-70 figure is from memory of Thomann's pricing. Merchant
  payment acceptance was not checked; current payment readiness is recorded
  above. A generic "USB audio
  interface" search on bol.com was not run and may turn up an equivalent.
- No Eurorack power supply or ribbon cable is listed on bol.com; Thomann
  (Doepfer) is the source when a case exists, which is a separate budget.
- Hantek 6022BE, Pinecil at a sane price (bol.com lists one at EUR 197), TS101,
  Aneng meters, UT33D+, UT61E+: not listed or not priced.
- Old alternative-source prices were estimates, not delivered quotes. A used
  supply or an ATX computer supply is not approved here for first-power testing.
