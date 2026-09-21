---
status: "partly integrated; unanswered R1 normalling and hardware variants deferred during V0"
owner: "user answer; agent research and integration"
read_when: "choosing or placing any panel-mounted part, designing R1's jack layout, or after the user edits this file"
update_when: "the user answers, evidence changes, or the agent records the outcome"
retire_when: "the answers are recorded in docs/MECHANICAL.md (hardware standard) and docs/modules/io-mixer/SPEC.md and the resulting footprints are checkpointed"
---

# Panel hardware: the choices only you can make

**Deferred, 2026-09-21:** the project is prototyping and playing digital modules
in VCV Rack first, under
[V0](../ROADMAP.md#v0-playable-digital-modules-and-function-balance-current).
These physical-hardware choices do not block virtual behavior prototypes.
Retain the unanswered fields; revisit when hardware work resumes or the user
explicitly supplies answers. The new direction selects none of the options.

## Decision Needed

The panel hardware standard in [../MECHANICAL.md](../MECHANICAL.md) names one
candidate per role (jack, pot, knob, trimmer, toggle, LED, USB-C inlet).
Research is not finished mechanical verification: some drawing dimensions,
footprints and sample fits remain unresolved. Section 1 concerns R1's normalled
outputs; section 2 retains hardware preferences, not permission to buy anything.
The shared panel language and visible-control policy were adopted on 2026-09-15
and are recorded in their owning documents, not left as unanswered questions.

R1's eventual physical jack allocation waits on section 1 and its engineering checks.
VCV Rack prototypes and conceptual sketches can proceed independently.
A sketch is not an orderable design. Prototype board orders still need the
applicable review and explicit purchase approval; final panel cutting needs
the mechanical fit gate. Buying samples for that gate remains a separate,
user-approved purchase, not something blocked on already having fit evidence.

## 1. R1 normalling with an unswitched stereo jack

**None of the checked switched 3.5 mm TRS jacks fits the proposed stack.**
The proposed QingPu WQP-WQP419GR ("Stereo Thonkiconn") has no switch contact,
and its mounting height still needs confirmation. The checked switched
alternatives have incompatible dimensions or mounting arrangements; the table
in MECHANICAL.md lists them. This is not an exhaustive market claim. The
approved behaviour "inserting a plug into a channel's individual output
removes that channel from the mix" cannot be sensed by the WQP419GR's own
contacts.

| Option | What changes | Cost |
|---|---|---|
| **A. Individual outputs become synth-side mono jacks (recommended)** | The four per-channel outputs use the switched mono Thonkiconn at synth level, retaining plug-controlled removal from the mix. Stereo TRS jacks serve the consumer input and consumer-level mix output. | Changes the approved individual outputs from consumer to synth level. A single channel reaches the outside world through the consumer mix output. The mono footprint exists; the world-side stereo footprint and fit still need verification. |
| **B. Keep consumer-level individual outputs and add a mix-defeat toggle per channel** | Four stereo TRS individual outputs plus four sub-mini toggles that take a channel out of the mix by hand. | Four switches at about £2.20 each, four more panel holes and wider panel; the mix state no longer follows what is plugged in, which is a different musical behaviour from the one you approved. |
| C. Rebuild the panel stack around a switched TRS jack | Select a documented switched jack, then redesign and verify the related bushings, holes, footprint and stack. | Reworks the drawing-derived stack; feasibility is not established without a verified candidate. Not recommended on the present evidence. |

The recommendation is **A**, not an approved change. The acceptance check is
that the R1 spec's "Adopted behavior" table says where each jack type sits and
that the future generated-netlist tests cover the agreed included, removed and
restored contributions. R1 has no implemented circuit or tests yet.

**Your answer (A, B, C or your own):**

**Notes:**

## 2. Preference questions

Each answer has an engineering consequence stated alongside it. **A blank is
unanswered, not permission to use the recommendation.** Provisional sketch
defaults are allowed when clearly marked; they do not choose an orderable part.
Question 13's general interaction choice is settled; the remaining hardware
variants are not implied by approving the grid language.

### Knobs and pots

1. **One knob size on every module, or a size hierarchy (bigger for the main
    control)?** One size simplifies stocking and spacing; a hierarchy may use
    several grid cells or more panel width. Final spacing requires the mockup
    in MECHANICAL.md; neither 15 nor 15.24 mm is approved. **Recommended: one size.**
   Answer:
2. **Push-on knurled shaft (T18) that indexes in 20° steps and can be pulled
   off, or a D-shaft whose pointer is fixed at the moulding, or a two-part
   Sifam knob with a freely indexed pointer at two to three times the
   price?** → Decides the pot order code (K, F or R shaft) for every board.
   **Recommended: T18 push-on.**
   Answer:
3. **Colour: one colour everywhere, or colour by function (for example blue
   for CV attenuators, red for level)?** → Stocking only; same price.
   **Recommended: one colour, decide which.**
   Answer (colour or scheme):
4. **Pointer line or another unmistakable position indicator on the knob?**
    The adopted visible-control rule requires readable position; a rotationally
    symmetric unmarked knob cannot provide it, even with a panel scale.
    **Recommended: pointer line.**
   Answer:
5. **Skirted (a disc hiding the nut) or unskirted?** → A skirt adds 2 to 3 mm
   of diameter and raises the minimum pot spacing. **Recommended: unskirted.**
   Answer:
6. **Are calibration trimmers set once at build, or something you expect to
   adjust later yourself?** → "Set once" allows the cheap single-turn SMD
   trimmer on the back for offsets; "adjust later" argues for the 12-turn
   part everywhere and possibly a panel access hole. Either way they are on
   the back and reachable with the module out of the case.
   **Recommended: set once, multiturn only for scale trims.**
   Answer:

### Jacks

7. **Nut style: knurled (round, ridged) or hex (needs a spanner)?** → Same
   price at Thonk. **Recommended: knurled.**
   Answer:
8. **Nut finish: silver or black, and the same on jacks and pots?** → Stocking
   only. **Recommended: silver everywhere.**
   Answer:
9. **Washers under the jack nuts?** → A washer and a nut do not both fit on the
   jack's 2.5 mm of thread above a 2 mm panel, so a washer means the nut sits
   on one thread. **Recommended: no washers on jacks; a washer under each pot
   nut is fine.**
   Answer:
10. **Should the outside-world jacks look different from the patch jacks?**
    → The stereo body is green and the mono black, but both hide behind the
    panel; a visible difference would come from nut colour or a silkscreen
    box. **Recommended: same nuts, a printed box around the world-side group
    when panels are done.**
    Answer:
11. **Threaded jacks with a visible nut, or threadless jacks held only by the
    pot nuts?** → Threadless is a cleaner face and less secure; the panel
    would hang on the pots alone. **Recommended: threaded.**
    Answer:

### Switches and LEDs

12. **Toggle bat length: standard 9.4 mm, short 5.3 mm or long 10.4 mm?**
    → Longer is easier by feel and catches cables; shorter is tidier. Same
    switch, same price. **Recommended: standard.**
    Answer:
13. **Persistent modes: settled 2026-09-15.** Use maintained, labelled switches,
    not menus or momentary buttons that toggle hidden operating modes. The
    user's example is a CYCLE switch that stays on across power removal.
    The number of positions follows the actual supported functions; it is not
    a blanket preference for three-position switches. The standing rule lives
    in [AGENTS.md](../../AGENTS.md#rules).
14. **LED brightness: visible in a dark studio (1 to 2 mA) or in daylight
    (10 to 20 mA)?** → Eight bright LEDs draw 160 mA from the PD-derived rail
    and add ripple when they blink. **Recommended: dim, 2 mA.**
    Answer:
15. **Bare LEDs in plain holes, or metal bezels?** → Bezels look finished and
    hold the LED, but need a bigger hole, a new footprint and a hand-fitted
    part. **Recommended: bare, panel used as the jig.**
    Answer:
16. **Colour meaning: red/green for bipolar CV, and which single colour for
    gates and triggers?** → Red/green is one two-lead part; other pairs need a
    three-lead LED and a second drive net. **Recommended: red/green bipolar,
    a single colour of your choice for gates.**
    Answer:

### USB-C and case

17. **May the USB-C power inlet live on the back of the module, where the
    ribbon cable goes today, or must you plug it in from the front?** → Back:
    factory-placed, no panel cutout, 7 mm of depth. Front: a 12 mm round hole
    for a panel-mount coupler with four flying wires, or a hand-soldered
    fine-pitch receptacle taking the plug's insertion force. **Recommended:
    back.**
    Answer:
18. **Must modules fit a shallow "skiff" case of about 40 mm, or is a standard
    80 mm case assumed?** → Skiff rules out a rear-facing vertical receptacle
    and any deep part on the back. **Recommended: design for skiff depth;
    it costs nothing here.**
    Answer:

Ready for integration: no

## Processing Record

2026-09-15, explicit approval in conversation: the sparse Paperface-inspired
panel language, own printed/laser-cut faceplates and direct persistent controls
are recorded in [MECHANICAL.md](../MECHANICAL.md#panel-layout-language) and
[AGENTS.md](../../AGENTS.md#rules). The user clarified that power cycling concerns
visible maintained control positions, not detailed dynamic-state restoration.
Question 13 is therefore integrated, with no universal position count selected.

No answer selected A/B/C for R1 or the remaining exact hardware variants. Their
answer fields are unchanged. Retain this file until those choices and resulting
engineering work are integrated.

2026-09-21: deferred under the user's VCV Rack-first direction. The next trigger
is resuming hardware after V0 or an explicit answer, not a token reset. New fit
evidence may inform that later choice; researching hardware is not the current
task. Digital normalling can be evaluated without choosing a physical jack.
