# Routing benchmark

| Board | Router | Legal | Nets | Segments | Vias | Copper mm | Ideal mm | Detour | CPU s |
|---|---|:-:|--:|--:|--:|--:|--:|--:|--:|
| attenuverter | grid-astar | yes | 16 | 202 | 8 | 690.74 | 626.36 | 1.10 | 4.81 |
| mult | grid-astar | yes | 2 | 63 | 0 | 159.62 | 150.70 | 1.06 | 2.25 |
| pinch | grid-astar | **no** | 0 | 0 | 0 | 0.00 | 0.00 | - | 0.00 |
| reversal | grid-astar | yes | 20 | 251 | 18 | 762.04 | 549.74 | 1.39 | 8.78 |
| route-test | grid-astar | yes | 21 | 255 | 27 | 717.67 | 524.57 | 1.37 | 4.83 |

Faults:
- pinch / grid-astar: 1 nets unrouted

Boards: 5. Legal: 4.

Detour is copper length over the minimum spanning tree of the pad centres:
the shortest any routing of those nets could be. 1.00 is not reachable on a
real board. Legal means the router finished, nothing is contested, no via
touches a pad and every net is a single copper island.
