---
status: "maintained checkpoint"
owner: "the agent completing the latest task"
read_when: "starting a session, after reading AGENTS.md and checking the decision inbox"
update_when: "a validated checkpoint, blocker or next action changes; replace superseded prose"
retire_when: "the project ends or another current-state record takes over; Git is the session archive"
---

# Current Handoff

Updated 2026-09-13 by Claude Fable 5.1 (home laptop). This is current state,
not an append-only diary. The roadmap owns priorities, module specs own circuit
requirements and setup owns tool versions and commands. See
[README.md](README.md).

## Current Position

- Two module designs exist: the passive mult and the dual attenuverter. KiCad
  projects and the attenuverter's simulation netlist come from Haskell.
  Neither module has been built or measured.
- **The attenuverter is now the option B precision design** (implemented
  2026-09-13): one OPA2197 per channel as unity-gain buffer plus attenuverter
  stage, 10 kΩ 0.1 % thin-film gain resistors with 10 pF C0G compensation,
  1 MΩ input, a REF5050 offset reference. Every acceptance limit in
  [modules/attenuverter/ERROR-BUDGET.md](modules/attenuverter/ERROR-BUDGET.md)
  is asserted by one of eight decks and passes; the results are tabulated in
  [modules/attenuverter/SPEC.md](modules/attenuverter/SPEC.md), which also
  carries the decision record. The decision file is retired; the inbox is
  empty.
- **Every PCB is 100 mm tall** (`eurorackPcbHeight`, was 108): JLCPCB's cheap
  tier. The attenuverter's SMD was re-laid into the two pad-free strips
  between the panel controls, which did not move; the mult regenerated with
  the same placement on a shorter board. AGENTS.md carries the rule.
- M1/M2 complete; M3 has pinned dependencies but no CI; M4's circuit work is
  done and its skeleton, provenance and paperwork items remain (roadmap).
- The home lab list ([HOMELAB.md](HOMELAB.md)) was cut to about EUR 300 for
  assembly and power-up and about EUR 500 for everything on 2026-09-13, after
  the user rejected the EUR 1,680 version; no fume extractor, ever. No
  purchases are approved or made. Panel development remains deferred.

## Latest Change

- **Option B, end to end.** `modules/attenuverter/Attenuverter.hs` is the
  new circuit; `modules/_models/devices.lib` gains OPA2197 and REF5050
  subcircuits built from the datasheet maxima read from TI's HTML datasheet
  viewer on 2026-09-13 (offset 100 µV with 2.5 µV/°C, 1.6 pF + 6.4 pF input
  capacitance, a second pole at 20 MHz which is an assumption and says so,
  125 mV swing clamp, 375 Ω open-loop output resistance; the reference's
  3 ppm/V, 30 ppm/mA and 8 ppm/°C, its 0.2 V dropout and the NR pin's
  internal resistor). Temperature enters through SPICE's `TEMPER`, which a
  deck sets with `option temp` *after* `reset` (before it, `reset` discards
  it; that cost one wrong run).
- **The netlist generator emits a loop-gain probe.** `Emit.Spice` now puts a
  0 V source `V<ref>_o<pin>` between every op-amp unit's output and its net,
  and knows `Reference_Voltage` symbols (Vin, GND, Trim/NR, Vout order). The
  probe is a wire at DC and in transient analysis; in AC a deck gives it an
  amplitude and reads the Middlebrook voltage-injection loop gain
  `-V(amp side)/V(net side)`. That is how the `stability` deck measures phase
  margin on the generated circuit instead of on a copy of it: 72° for the
  attenuverter stage with 10 pF of stray, 27° with `C_f` removed.
- **One design value changed on deck evidence.** The decision file assumed
  100 kΩ gain resistors. With the op-amp's input capacitance in the model the
  full-clockwise gain rose 1.3 % at 20 kHz (4.6 % with 10 pF stray), because
  the capacitance's current flows through `R_f` and shelves the response
  towards `1 + C_in/C_f`. With 10 kΩ it is 0.05 %, the inversion corner moves
  from 159 kHz to 1.6 MHz and the phase margin is unchanged; the buffer makes
  the value invisible outside the board. Recorded in the budget's stability
  section and SPEC.md.
- **Eight decks** replace the six: `transfer`, `headroom` (at 11.4 V rails,
  100 kΩ load), `interaction` (patched, turned and driven), `corners`
  (0.1 % parts, ±5 % rails), `loading` (output and source), `transient`,
  `stability` (loop gain and audio-band flatness) and `temperature`
  (10–40 °C). Their limits are the budget's, not the models'.
- **LCSC numbers** for the new parts were verified against LCSC's product
  data on 2026-09-13: OPA2197IDR C139363, REF5050AIDR C27804, 10 kΩ 0.1 %
  C110775, 10 pF C0G C344177, 1 µF C28323, 1 MΩ C17514. All extended except
  the 1 µF and 1 MΩ.
- Home-lab rewrite and the height rule change are in the same session; see
  Current Position.

## Verification

Home laptop, 2026-09-13, GHC 9.6.7 / cabal 3.18.1.0, KiCad 10:

| Check | Result |
|---|---|
| `cabal run -v0 pcbgen -- all` | all five projects regenerated; attenuverter routed in 12 iterations, 0 contested cells, 22 vias, detour 1.18, no analog findings, zero predicted cross-channel coupling |
| `cabal test` | 65/65 passed |
| `toolkit/sim.sh attenuverter` | 8 decks, 0 failed (25 PASS lines); numbers in SPEC.md |
| `toolkit/pipeline.sh attenuverter` | module and panel: ERC clean, DRC clean with schematic parity, renders, `check.ok` written; not exported |
| `toolkit/pipeline.sh mult` | module and panel clean at the new 100 mm height; not exported |

Not rerun: `toolkit/test-scripts.sh` (its fixture is the attenuverter; the
fault injections do not depend on the circuit), the benchmark, the
field-solver and `nodebudget.py` checks (inputs unchanged). No manufacturing
release or physical measurement was made.

Native reports, renders and `check.ok` manifests live under each module's
ignored `build/`, with panels in `build/panel/`. Artifact paths and commands
here are relative to the repository root.

## Remaining Limits

- Simulated, not measured. The models have no finite CMRR or PSRR, no noise,
  no output stage beyond a clamp, and draw no load current from the rails; the
  budget carries CMRR and PSRR from the datasheets. The buffer's phase margin
  rests on the model's assumed second pole. Pot end resistance and linearity
  are unpublished and need measurement.
- Input over-voltage protection is not designed in (separate M4 item). The
  mechanical fit of the new SMD strips against the jack and pot bodies has
  been checked only geometrically (pads and courtyards clear); a render review
  is owed before any order. No first-power-up guide exists yet.
- The REF5050 starts slowly: 10 kΩ internal against 1 µF on the NR pin is a
  10 ms time constant, plus 200 µs to settle. Harmless for a module, worth
  knowing when a bench measurement starts at power-up.
- CI on a runner with KiCad 10 is still owed by M3. Freerouting rows in
  BENCH.md are not deterministic; only grid-astar rows are the diff.

## Next Action

**M4's remaining items** (roadmap): factor the reusable parts of the
attenuverter into the generator (power entry and protection, precision
buffer, module skeleton), then datasheet provenance with URLs for every part,
the mechanical stack, itemised cost and stock against JLCPCB, assembly views
and the first-power-up guide. Then P1's exponential-converter block, whose
tracking limit (±2 cents over 5 octaves, proposed) the user has not yet
confirmed.

For the user: Stage A of [HOMELAB.md](HOMELAB.md) can be bought whenever
convenient; confirm the supply's floating output on its product page first.
