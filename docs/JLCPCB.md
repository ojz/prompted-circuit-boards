---
status: maintained
owner: collaborating agents
read_when: pricing a board, choosing a design rule, or justifying a routing objective on cost grounds
update_when: JLCPCB publishes new thresholds, or a board crosses one of the limits below
retire_when: a different fab becomes the target and its cost model replaces this one
sources_checked: 2026-09-11
---

# What JLCPCB actually charges for

This document exists because the router has priced a via at 40 grid cells
since it was written, and nobody had ever checked that number against a price
list. It turns out the fab does not charge for vias at all on boards this
size. The generator should optimise against real costs, so the real costs are
recorded here.

Every figure below was read from JLCPCB's own capability and surcharge pages
on 2026-09-11. Prices are USD. Links are at the bottom. **Nothing here has
been confirmed against an actual invoice** — no order has been placed.

## The short version

| Question | Answer |
|---|---|
| Does trace length cost money? | No. It appears nowhere in the price list. |
| Does via count cost money? | Not until 150,000 holes/m². We are at 8% of that. |
| Does via *size* cost money? | Yes, below 0.3 mm hole. We sit exactly on the line. |
| What does cost money? | Board area, layer count, quantity, finish, and crossing 100 mm. |

## What the price is actually made of

Ranked by how much it matters for a 6HP Eurorack module:

1. **Board area, and one hard cliff at 100 × 100 mm.** Two-layer boards up to
   100 × 100 mm are the standard prototype tier, currently about $2 for five
   pieces. Above that dimension the price leaves the tier and climbs. This is
   by far the largest single lever on our cost.
2. **Layer count.** Two layers is the cheap tier; four is a step up. We use two.
3. **Quantity**, with the usual economies. Engineering and setup fees are
   per-order, so at five boards the fixed fees dominate the per-board cost.
4. **Surface finish.** ENIG runs 20–40% above HASL, plus $0.90/m² for every 1%
   of gold coverage beyond 30% at 1 microinch thickness.
5. **Non-standard options.** Board colour other than the default, lead-bearing
   HASL, non-standard thickness and 1 oz copper each carry a charge.

## The surcharges with explicit thresholds

These are the ones worth designing around, because they are cliffs rather
than slopes:

| Trigger | Threshold | Charge |
|---|---|---|
| Drill count, prototype | more than 4,000 holes per order | $16.29 |
| Drill count, batch | more than 150,000 holes per m² | per exceeding hole |
| Small via | hole < 0.3 mm **or** via diameter ≤ 0.4 mm | extra; $16.29/order at 0.1 mm hole |
| Small board | either dimension ≤ 30 mm | scaled by the smaller dimension |
| Burr removal | one side 15–30 mm | $0.02/piece |
| Board length | ≥ 600 mm | $31.43/design |
| Test points | ≥ 8,000 per piece | per table |
| Slot milling | 0.8–1.0 mm slots beyond 80 m/m² | routing fee |

## Where our boards actually sit

The attenuverter (option B revision, 2026-09-13) is 28.0 × 100.0 mm, so
2,800 mm² = 0.0028 m². Its hole count is in
[modules/attenuverter/route-report.md](modules/attenuverter/route-report.md)
(vias) plus 33 component holes; the first revision had 38 in total.

| Limit | Allowance | We use | Headroom |
|---|--:|--:|--:|
| Holes at 150,000/m² | 453 | 38 | 415 more vias |
| Prototype holes, 5 boards | 4,000 | 190 | 21× |

**We could add four hundred more vias to this board before it cost a single
cent.** The router currently emits five.

Two thresholds we are genuinely close to, and both are worth knowing:

- **Via drill is 0.3 mm, exactly on the free boundary.** `drViaDrill = 0.3`
  and `drViaDiameter = 0.6` in `toolkit/src/Design.hs`. The free tier needs
  hole ≥ 0.3 mm **and** diameter ≥ 0.4 mm. Shrinking the drill by one step to
  buy routing density would move the whole order into a surcharge tier. This
  is a tripwire, not a margin.
- **The board is 100 mm tall since 2026-09-13**, so it sits inside the
  100 × 100 mm tier. The first revision was 108 mm and missed it by 8 mm;
  `eurorackPcbHeight` now fixes 100 mm for every module (the panel controls
  did not have to move: the attenuverter's SMD strips were re-laid instead).

The board is also 28 mm wide, under the 30 mm small-board threshold, so it
attracts the small-board handling charge and $0.02/piece for burr removal.
That is structural to 6HP and not worth fighting; panelising several modules
together is the normal mitigation.

## So why minimise vias at all?

Honestly ranked, now that money is off the list:

1. **Ground-plane fragmentation — the only one that really matters.** Every
   via on the back layer punches a hole in the ground pour. Return current has
   to detour around it, and enough of them in the wrong place turn a plane
   into a maze. **We do not currently measure this at all**, which is the real
   gap.
2. **Routing congestion.** A via consumes keepout area on both layers. The
   `pinch` fixture exists precisely to record that cost. This is a genuine
   reason to charge for vias — but it is a *search* heuristic, not a cost.
3. **Reliability.** Each plated barrel is a possible open. Real, but at five
   vias on a hand-checked prototype it is noise.
4. **Electrical cost — essentially zero at audio.** A via is roughly 1 nH and
   about 1.2 mΩ of barrel resistance (0.3 mm drill, 25 µm plating, 1.6 mm
   board). At 20 kHz the inductive part is 0.13 mΩ. Our 0.2 mm trace on 35 µm
   copper is 2.46 mΩ/mm, so **a via is worth about half a millimetre of
   trace.** The router charges it 8 mm — forty cells at the 0.2 mm grid. That
   is roughly **16× more than the electrical cost.**

## What this means for the generator

The conclusion is not "delete the via cost". It is that `rcViaCost` is a
**congestion heuristic and should be documented as one**, not defended as an
economic or electrical figure. Three consequences:

- Via count is a diagnostic, not a quality score. `BENCH.md` now says so in the
  caveats the harness emits, and `Legal` and `Spec` are the columns that carry
  a verdict.
- The long-running question of whether `rcViaCost = 40` is the right value was
  never answerable on the terms it was asked. No cost curve exists to optimise
  against, so "no value dominates" was the correct finding for the wrong reason.
- **The objective that is missing is plane integrity**, not a better via price.
  Return-path continuity is what via placement actually damages, it is
  measurable from the emitted copper, and nothing in the toolkit looks at it today.

Length is the same story and was settled earlier: it costs nothing at the fab,
and `nodebudget.py report` showed a 100 kΩ node tolerates 1.7 m of copper
before losing 3 dB at 20 kHz, against a 110 mm longest possible trace. Both
length and via count are cheap. Coupling and plane integrity are not.

## Buying the module instead

Worth stating plainly, since it sets expectations. At quantity five to ten, a
self-built module is generally **more expensive than a mass-produced one**,
and that gap is widest against Behringer, whose prices sit below what the
parts alone cost in small quantities. Doepfer is closer and sometimes beatable.

The fixed costs are what do it: per-order engineering and setup fees, roughly
$3 per part type for every JLCPCB "extended" part in an assembly order, and a
panel, which for DIY Eurorack is often the most expensive single item. These
are amortised by quantity, not by better layout. No amount of routing
cleverness moves this number.

An actual quote is the only way to settle it, and that needs a finished BOM
and a panel decision. Neither exists yet.

## Sources

- [PCB pricing breakdown](https://jlcpcb.com/blog/pcb-pricing-breakdown)
- [PCB capabilities](https://jlcpcb.com/capabilities/pcb-capabilities)
- [In what cases will there be charged extra?](https://jlcpcb.com/help/article/in-what-cases-will-there-be-charged-extra)
- [Instant quote tool](https://cart.jlcpcb.com/quote) — the authority; the pages above document it
