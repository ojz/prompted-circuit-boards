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
| +12V | F+B | 30 | 5 | 78.95 | 71.58 | 1.10 |
| -12V | F+B | 27 | 4 | 68.04 | 59.92 | 1.14 |
| BUF1 | B | 10 | 0 | 32.21 | 31.62 | 1.02 |
| BUF2 | B | 19 | 0 | 41.46 | 34.09 | 1.22 |
| IN1 | B | 8 | 0 | 7.40 | 6.49 | 1.14 |
| IN2 | F+B | 11 | 1 | 16.45 | 13.42 | 1.23 |
| INV1 | B | 12 | 0 | 12.54 | 10.90 | 1.15 |
| INV2 | F+B | 21 | 2 | 25.00 | 18.16 | 1.38 |
| N12_RAW | F+B | 12 | 1 | 23.89 | 22.07 | 1.08 |
| NR | B | 3 | 0 | 2.30 | 2.17 | 1.06 |
| OA1 | F+B | 13 | 2 | 25.15 | 20.90 | 1.20 |
| OA2 | B | 20 | 0 | 22.97 | 19.42 | 1.18 |
| OFFSET | F+B | 16 | 2 | 56.18 | 52.84 | 1.06 |
| OUT1 | F+B | 4 | 1 | 21.12 | 20.96 | 1.01 |
| OUT2 | F+B | 8 | 1 | 24.13 | 21.22 | 1.14 |
| P12_RAW | F+B | 11 | 0 | 25.25 | 21.89 | 1.15 |
| WIPER1 | B | 11 | 0 | 31.75 | 25.10 | 1.26 |
| WIPER2 | B | 8 | 0 | 30.87 | 25.14 | 1.23 |
| GND | F+B | 104 | 4 | 199.58 | 160.61 | 1.24 |
| **total** |  | 348 | 23 | 745.23 | 638.51 | 1.17 |

Iterations: 20. Contested cells left: 0.
Via/pad violations: 0.
Disconnected nets: none.

## Analog intent

- matched group channels spans 10.65 mm (tolerance 10.00 mm; lengths count 1.6 mm per via): IN1 7.40 mm, IN2 18.05 mm

Coupling predicted from the copper, limit 2.20 mV:

| quiet net | noisy net | coupled pF | injected mV |
|---|---|--:|--:|
| WIPER1 | BUF2 | 0.0000 | 0.000 |
| WIPER1 | OA2 | 0.0000 | 0.000 |
| WIPER1 | OUT2 | 0.0000 | 0.000 |
| WIPER2 | BUF1 | 0.0000 | 0.000 |
| WIPER2 | OA1 | 0.0000 | 0.000 |
| WIPER2 | OUT1 | 0.0000 | 0.000 |
