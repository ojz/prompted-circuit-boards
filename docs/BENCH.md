# Routing benchmark

> Status: generated. Owner: pcbgen benchmark harness.
> Read when: comparing routing strategies; interpret scores with docs/ROADMAP.md's benchmark caveats.
> Update when: regenerate with `cabal run pcbgen -- bench` after a routing or fixture change; do not hand-edit scores.
> Retire when: replaced by a validated benchmark; Git retains the previous results.

| Board | Router | Legal | Spec | Nets | Segments | Vias | Copper mm | Ideal mm | Detour |
|---|---|:-:|:-:|--:|--:|--:|--:|--:|--:|
| attenuverter | freerouting | **no** | **2.22 mV** | 16 | 114 | 8 | 540.58 | 626.36 | 0.86 |
| attenuverter | grid-astar | yes | ok 0.00 mV | 16 | 211 | 5 | 689.85 | 626.36 | 1.10 |
| crosstalk | freerouting | yes | **85.00 mV** | 2 | 2 | 0 | 60.35 | 60.35 | 1.00 |
| crosstalk | grid-astar | yes | ok 0.55 mV | 2 | 8 | 0 | 62.04 | 60.35 | 1.03 |
| mult | freerouting | yes | - | 2 | 47 | 0 | 162.42 | 150.70 | 1.08 |
| mult | grid-astar | yes | - | 2 | 63 | 0 | 159.62 | 150.70 | 1.06 |
| pinch | freerouting | **no** | - | 1 | 0 | 0 | 0.00 | 12.17 | - |
| pinch | grid-astar | **no** | - | 1 | 0 | 0 | 0.00 | 12.17 | - |
| pinch-wide | freerouting | **no** | - | 1 | 0 | 0 | 0.00 | 12.17 | - |
| pinch-wide | grid-astar | yes | - | 1 | 5 | 0 | 13.21 | 12.17 | 1.09 |
| reversal | freerouting | **no** | - | 20 | 162 | 10 | 647.82 | 549.74 | 1.18 |
| reversal | grid-astar | yes | - | 20 | 267 | 14 | 717.85 | 549.74 | 1.31 |
| route-test | freerouting | yes | - | 21 | 157 | 6 | 690.79 | 524.57 | 1.32 |
| route-test | grid-astar | yes | - | 21 | 226 | 9 | 689.45 | 524.57 | 1.31 |

Faults:
- attenuverter / freerouting: crosstalk 2.22 mV over a limit of 2.20 mV, 1 nets not one island (GND)
- pinch / grid-astar: produced no copper, 1 nets unrouted, 1 nets not one island (/SIG, /SIG)
- pinch / freerouting: produced no copper, note: import added no copper (0 tracks before, 0 after), 1 nets not one island (/SIG)
- pinch-wide / freerouting: produced no copper, note: import added no copper (0 tracks before, 0 after), 1 nets not one island (/SIG)
- reversal / freerouting: 1 nets not one island (/X1)

Rows: 14. Legal: 9.

Detour is copper length over the sum of the minimum spanning trees of each
net's pad centres. This is a reference length, not a lower bound: branched
copper and pad geometry can reduce it. A detour below 1.00 alone does not
prove missing connections; use the connectivity findings. Legal combines
our connectivity and via/pad checks with router-reported failures and
contested cells; it is not full independent KiCad DRC. Spec is a modelled
coupling check, not measured circuit performance. Time is omitted because
the recorded process CPU time excludes external-router execution. See
docs/ROADMAP.md for comparison limitations and planned benchmark work.
