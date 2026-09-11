# Handout for a collaborating model

You are being asked to work on this repository alongside me (Claude Opus 5,
working from Olmo's home laptop). You are most likely reading this through
GitHub Copilot on the work laptop. We are collaborators on the same codebase,
not reviewers of each other, and Olmo is the one who decides.

`AGENTS.md` is the contract and you should follow it exactly. This document
is the thing `AGENTS.md` cannot be: an honest account of what is solid, what
is merely modelled, what I am unsure about, and where I would like to be
argued with.

---

## Orientation in sixty seconds

A Eurorack module is described in Haskell. `pcbgen` generates the KiCad
project, the SPICE netlist and the routing from that description. KiCad's
command-line tools verify the result. The GUI is a viewer and nothing else.

```
modules/<name>/<Name>.hs     the design: the single source of truth
        |
        +-- cabal run pcbgen -- <name>
        |     -> kicad/*.kicad_{sch,pcb,pro,dru}   (committed)
        |     -> kicad/route-report.md             (routing + analog findings)
        |
        +-- cabal run pcbgen -- spice <name>
              -> sim/<name>.cir                    (netlist, committed)

toolkit/check.sh <name>   ERC + DRC with schematic parity
toolkit/sim.sh   <name>   regenerate netlist, run the hand-written decks
cabal test                65 tests, about 15 minutes
cabal run pcbgen -- bench routing benchmark against Freerouting
```

Nothing generated is ever hand-edited. If a generated file is wrong, the
design or the generator is wrong.

---

## The rules that will bite you

All of these are in `AGENTS.md`; these are the ones that have actually caused
damage.

1. **Never launch a KiCad GUI window, never save from one.** There is a stray
   file in git history that the GUI recreated behind the repo's back.
2. **Never hand-edit a generated `.kicad_*` or `.cir` file.** It will be
   silently overwritten and your change will look like a regression later.
3. **Two workstations.** Olmo works from a home laptop (me) and a work laptop
   (you), and forgets to push. `git fetch` and report both directions before
   touching anything. If the two have diverged, stop and say so rather than
   guessing.
4. **Every fixed bug gets a test.** This is not ceremony. Several bugs below
   were found twice before the test existed.
5. **"Generated", "checks passed" and "reviewed prototype candidate" are
   three different states**, and only the first two are ever claimed
   automatically. Do not blur them, especially in a commit message.
6. **Do not commit `build/`.** Generated KiCad projects and the SPICE netlist
   *are* committed, so that a change in output shows up in a diff.

---

## What is true, what is modelled, what is assumed

This is the section I would most want if I were arriving. Please keep it
current if you change what is in it.

### Verified by a tool that could have said no

- Both modules pass ERC and DRC with schematic parity, and so do their
  panels. `toolkit/check.sh` writes `check.ok` only when they do, and
  `fab.sh` refuses to export unless every hash in it still matches.
- The fault-injection tests (`toolkit/test-scripts.sh`, 54 checks) prove those
  refusals actually fire, by tampering with sources and boards, and exercise
  the simulation runner's success, failure and missing-result paths.
- The router's output is checked by geometry code that does not trust the
  router: no via in a pad, every net one copper island. The same checks are
  applied to Freerouting's output in the benchmark.
- 65 Haskell tests. They take about fifteen minutes, mostly because every
  routing test runs six net orderings.

### Modelled, self-consistent, and never measured

Treat everything here as a claim about a model until a bench says otherwise.
Say so in anything you write.

- **Crosstalk.** `Route/Coupling.hs` predicts how much a switching net injects
  into a high-impedance one. The capacitance comes from a 2D field solve
  (`toolkit/xsection.py`) that agrees with the Hammerstad closed form to a few
  percent; the injection formula agrees with ngspice to 0.2% in both limits
  (`toolkit/nodebudget.py verify`). Every link in the chain checks out and the
  chain as a whole has never met an oscilloscope.
- **The attenuverter's circuit behaviour.** Six decks in
  `modules/attenuverter/sim/`. The device models in `modules/_models/` are
  hand-built from datasheet figures, and their limits are written at the top
  of that file. The op-amp model in particular draws quiescent supply current
  but **not load current**, so nothing there is evidence about power draw
  under load.
- **The coupling integral is deliberately conservative** for short or skewed
  neighbours, and ignores the opposite layer entirely. Both are stated in the
  module docs.

### Assumed, and worth doubting

- `rcViaCost = 40` cells. Swept twice; no value is undominated across the
  benchmark boards, so it stays where it is. It is a guess with evidence that
  a better guess is not available, not a tuned number.
- The 0.2 mm routing grid. It costs completeness — the `pinch` fixture exists
  to record exactly that — and nobody has tried anything else.
- Every mechanical tolerance in `AGENTS.md` (jack pitch, PCB height, panel
  geometry) comes from Doepfer's published table and datasheet dimensions. No
  physical part has been offered up against a real rail.

---

## Traps, concretely

These all cost me time. They are written here so they cost you none.

**KiCad numbers a diode's cathode pin 1 and its anode pin 2.** SPICE wants the
anode first. Getting this backwards reverses every protection diode and the
netlist simulates perfectly happily. Check `Device.kicad_sym` rather than
assuming, as I failed to.

**Node-name scrubbing can merge two nets.** `+12V` and `-12V` both became
`_12V`, shorting the supply rails, in a netlist that read fine.
`Emit.Spice.nodeCollisions` now refuses this; do not remove it.

**ngspice's `reset` starts a new plot**, so any vector you captured before it
is gone and expressions using it fail or silently read as zero. Copy values
into shell variables (`set x = $&vec`) to carry them across.

**A patch cable does two things.** Inserting a plug opens the jack's
normalling switch *and* connects a source. A deck that only does the second
drives the normalled net through a closed switch. Mine drove the shared
offset reference to 5 V and produced a confident, entirely fake test failure.

**A post-process can undo an objective.** The router's string-pulling
straightened a quiet net back alongside the aggressor it had just been paid
to avoid, and the router reported success while the board was 8x over its
crosstalk limit. Anything you add to the search has to survive everything
that runs after it.

**An acceptance test has to use the cost you just added.** The descent pass
rejected every coupling detour because it compared copper and vias only, so
the new term did nothing at all.

**`cabal build` does not rebuild the test suite.** Use `cabal build
pcbgen-test`, or you will read a stale pass count.

**Simulator exit status and assertion output both matter.** On the work
laptop, substituting `NGSPICE=/usr/bin/false` originally reported six decks
and zero failures. `sim.sh` now rejects nonzero exits, missing assertions and
zero experiment decks; stub-based regression tests keep those refusals live.

**Never `git checkout` a file with uncommitted work in it.** I destroyed a
subagent's changes that way.

**Measure the quantity that matters, not the one that is easy.** A transient
test failed at 137 mV. The 137 mV was real and it was 0.8 degrees of phase
lag, not amplitude loss. Asserting on it would have demanded a utility module
be phase-linear to a fraction of a degree.

---

## Where the work is

Ranked by what I would pick up, with what blocks it. `HANDOFF.md` has the
detail; this is the shortlist.

1. **M4's remaining bullets.** Not blocked, and the gate before anything can
   be ordered. Datasheet provenance with source URLs and versions for every
   part; the mechanical stack (jack bodies, bushings, PCB-to-panel spacing,
   knobs, rails, tolerances); itemised cost and stock against JLCPCB. This is
   paperwork rather than engineering and it has to be right.
2. **A short simulation pass on the mult.** It is passive so there is less to
   learn, but its jack normalling is worth confirming. The harness exists.
3. **The headroom decision.** Clipping starts at about ±10.35 V against a
   ±10 V full-scale signal. It passes; 0.35 V is thinner than a utility
   module usually wants. Widening it is a circuit change, so it should be
   settled before a board is ordered rather than after. **This is Olmo's call,
   not ours.**
4. **CI and dependency pinning**, owed from M3. I did not attempt CI because I
   cannot verify a GitHub Actions run from here and did not want to add
   unverified automation to a repository whose whole culture is about not
   claiming more than was checked. **You may be better placed to do this**
   than I am — if you can actually run it, please take it.
5. **Bench validation of the crosstalk model.** Blocked: Olmo is waiting on
   payment cards and cannot order from JLCPCB. When that clears, a two-trace
   coupon settles whether the whole modelled chain means anything.

---

## Where I would like to be argued with

I would rather be corrected than agreed with. These are the decisions I am
least sure of, in order.

- **Six net orderings, best kept.** This took the crossing fixture from
  illegal-with-202-vias to 14 vias, which is a bigger win than anything else
  in the router. It also smells like it could be papering over a convergence
  problem rather than solving one. If a single good ordering should be enough,
  I would like to know why mine is not.
- **`rcViaCost = 40`.** I declined to move it twice on the grounds that no
  value dominates. That may be the right call or it may be a failure of
  nerve — a better objective might make the choice obvious.
- **The coupling model over-estimates skewed geometry** and I accepted that
  because over-estimating is the safe direction for a budget. It also blunts
  the very distinction the objective depends on. A locality correction using
  the neighbour's extent would be better and I did not write it.
- **Hand-built device models instead of TI's.** I chose provenance and no
  redistribution question over fidelity. If you think a vendor model is worth
  the licensing care, make the case.
- **The 4 mm coupling cutoff and the 0.1 mm integration step** are round
  numbers I picked. The cutoff at least has an argument behind it; the step
  does not.
- **The analog objective may be solving a problem our boards do not have.**
  Cross-channel coupling on the attenuverter measures exactly zero. I built
  the machinery on a synthetic fixture. If you think that is optimising for an
  imagined future, say so — it is a fair reading.

---

## How we work together

- **Pull before you start, push before you stop.** Neither of us can see the
  other's working tree, and Olmo moves between the two machines daily.
- **Leave your session in `HANDOFF.md`,** newest first, in the same shape as
  the existing entries: what was run, what passed, **what was not run**, and
  the next action with its prerequisites. The "not run, not done, not proven"
  section is the one that makes the file worth having.
- **Sign your entries** so we can tell who concluded what. Mine say Claude
  Opus 5 via the commit trailer; please make yours identifiable too.
- **If you disagree with something I did, change it and say why in the commit
  message.** You do not need my agreement and you will not hurt my feelings.
  Do leave the reasoning, because the next reader is likely to be one of us
  with none of the context.
- **If a number in this file or in `HANDOFF.md` turns out to be wrong,
  correct it in place** rather than adding a note that contradicts it. Two
  numbers and no verdict is worse than one wrong number.
- **Olmo is not an electrical engineer and is explicit about that.** Explain
  in plain language, give the number and what it means, and do not present a
  simulation as a measurement. They have said they prefer symbolic and
  metaheuristic methods over learned models, and that no model should be
  placing components or choosing where copper goes — generation stays
  deterministic.

Welcome aboard. The interesting problem here is not making a router; it is
knowing which of its numbers deserve to be believed.
