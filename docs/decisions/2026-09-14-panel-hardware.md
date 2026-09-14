---
status: "pending"
owner: "user answer; agent research and integration"
read_when: "choosing or placing any panel-mounted part, designing R1's jack layout, or after the user edits this file"
update_when: "the user answers, evidence changes, or the agent records the outcome"
retire_when: "the answers are recorded in docs/MECHANICAL.md (hardware standard) and docs/modules/io-mixer/SPEC.md and the resulting footprints are checkpointed"
---

# Panel hardware: the choices only you can make

## Decision Needed

The panel hardware standard in [../MECHANICAL.md](../MECHANICAL.md) names one
part per role (jack, pot, knob, trimmer, toggle, LED, USB-C inlet). The
engineering side is done: each part fits the 10 mm panel stack, has or can
have a footprint, and has a source. What remains is (1) one real design
decision that the research forced, about how R1's normalling works, and
(2) a set of preference questions whose answers change which variant is
bought but not whether the design works. Nothing can be ordered, and R1's
jack layout cannot be drawn, until section 1 is answered; section 2 can wait
until the first order but decides the knob and pot variant, so it is cheaper
to answer now.

## 1. R1 normalling with an unswitched stereo jack

**No switched 3.5 mm TRS jack fits the module stack.** The only vertical
stereo jack that shares the Thonkiconn's bushing, hole, pitch and panel gap
(QingPu WQP-WQP419GR, the "Stereo Thonkiconn") has no switch contact. Every
switched alternative is too tall, too wide, rated for a thinner panel, or a
right-angle part; the table in MECHANICAL.md lists them. So the approved
R1 behaviour "inserting a plug into a channel's individual output removes
that channel from the mix" cannot be sensed by the world-side jack.

| Option | What changes | Cost |
|---|---|---|
| **A. Individual outputs become synth-side mono jacks (recommended)** | The four per-channel outputs use the switched mono Thonkiconn at synth level, so the normalling works exactly as approved. The stereo TRS jacks are used only where the outside world actually connects: the stereo consumer input and the consumer-level mix output. | Changes the approved wording "individual outputs at consumer audio level" to "at synth level". A phone or laptop still gets the mix at consumer level; a single channel goes to the outside world only through the mix. No new footprint risk, no new mechanics. |
| **B. Keep consumer-level individual outputs and add a mix-defeat toggle per channel** | Four stereo TRS individual outputs plus four sub-mini toggles that take a channel out of the mix by hand. | Four switches at about £2.20 each, four more panel holes and wider panel; the mix state no longer follows what is plugged in, which is a different musical behaviour from the one you approved. |
| C. Rebuild the panel stack around a switched TRS jack | Taller pot bushings or spacers, 8 mm panel holes, a hand-drawn footprint for a jack with no published drawing. | Throws away the validated stack for one connector. Not recommended. |

The recommendation is **A**. The acceptance check is that the R1 spec's
"Adopted behavior" table is updated to say where each jack type sits and
that the generated-netlist tests still cover normalled, removed and restored
contributions.

**Your answer (A, B, C or your own):**

**Notes:**

## 2. Preference questions

Each answer has one engineering consequence, stated after the arrow. A blank
means the agent uses the recommendation in bold.

### Knobs and pots

1. **One knob size on every module, or a size hierarchy (bigger for the main
   control)?** → One size means 15 mm pot centres everywhere and one line
   item; a hierarchy lets the biggest knob set the spacing and may force 8HP
   where 6HP would do. **Recommended: one size.**
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
4. **A pointer line on the knob, or a plain knob with the marking on the
   panel?** → Panel graphics are deferred, so a plain knob would be unreadable
   until then. **Recommended: pointer line.**
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
13. **Where a middle position makes musical sense, three-position switches
    (about £0.70 more each) or two-position?** **Recommended: three where it
    removes a menu.**
    Answer:
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

Empty until the user answers.
