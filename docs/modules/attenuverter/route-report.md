---
status: "generated"
owner: "pcbgen"
read_when: "comparing this design's routing or predicted analog margins"
update_when: "regenerate with `cabal run pcbgen -- attenuverter`; do not hand-edit results"
retire_when: "the corresponding design is removed; Git retains superseded results"
---

# Routing report: attenuverter

| Net | Layers | Segments | Vias | Length mm | Ideal mm | Detour |
|---|---|--:|--:|--:|--:|--:|
| +12V | B | 20 | 0 | 75.63 | 72.32 | 1.05 |
| -12V | B | 19 | 0 | 34.24 | 24.99 | 1.37 |
| IN1 | F+B | 6 | 0 | 67.63 | 67.54 | 1.00 |
| IN2 | F+B | 6 | 1 | 37.75 | 37.67 | 1.00 |
| INV1 | B | 7 | 0 | 11.86 | 11.62 | 1.02 |
| INV2 | B | 6 | 0 | 10.13 | 10.06 | 1.01 |
| N12_RAW | B | 10 | 0 | 22.51 | 20.07 | 1.12 |
| OA1 | B | 6 | 0 | 10.61 | 10.52 | 1.01 |
| OA2 | B | 7 | 0 | 10.63 | 10.50 | 1.01 |
| OFFSET | F+B | 20 | 1 | 50.81 | 48.79 | 1.04 |
| OUT1 | F+B | 6 | 1 | 56.43 | 54.83 | 1.03 |
| OUT2 | B | 5 | 0 | 11.76 | 10.28 | 1.14 |
| P12_RAW | F+B | 7 | 0 | 19.31 | 19.12 | 1.01 |
| WIPER1 | B | 16 | 0 | 74.89 | 68.45 | 1.09 |
| WIPER2 | B | 3 | 0 | 25.49 | 25.14 | 1.01 |
| GND | F+B | 67 | 2 | 170.15 | 134.46 | 1.27 |
| **total** |  | 211 | 5 | 689.85 | 626.36 | 1.10 |

Iterations: 11. Contested cells left: 0.
Via/pad violations: 0.
Disconnected nets: none.

## Analog intent

- matched group channels spans 28.28 mm (tolerance 10.00 mm; lengths count 1.6 mm per via): IN1 67.63 mm, IN2 39.35 mm
- matched group outputs spans 46.27 mm (tolerance 10.00 mm; lengths count 1.6 mm per via): OUT1 58.03 mm, OUT2 11.76 mm

Coupling predicted from the copper, limit 2.20 mV:

| quiet net | noisy net | coupled pF | injected mV |
|---|---|--:|--:|
| WIPER1 | OA2 | 0.0000 | 0.000 |
| WIPER1 | OUT2 | 0.0000 | 0.000 |
| WIPER2 | OA1 | 0.0000 | 0.000 |
| WIPER2 | OUT1 | 0.0000 | 0.000 |
