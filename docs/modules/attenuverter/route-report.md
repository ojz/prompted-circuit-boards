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
| +12V | F+B | 33 | 4 | 78.89 | 71.58 | 1.10 |
| -12V | F+B | 31 | 5 | 72.01 | 59.92 | 1.20 |
| BUF1 | B | 12 | 0 | 32.64 | 31.62 | 1.03 |
| BUF2 | B | 19 | 0 | 36.89 | 34.09 | 1.08 |
| IN1 | B | 8 | 0 | 7.40 | 6.49 | 1.14 |
| IN2 | F+B | 10 | 2 | 19.51 | 13.42 | 1.45 |
| INV1 | B | 11 | 0 | 12.52 | 10.90 | 1.15 |
| INV2 | F+B | 22 | 2 | 24.94 | 18.16 | 1.37 |
| N12_RAW | F+B | 10 | 1 | 24.15 | 22.07 | 1.09 |
| NR | B | 3 | 0 | 2.30 | 2.17 | 1.06 |
| OA1 | F+B | 12 | 2 | 24.90 | 20.90 | 1.19 |
| OA2 | B | 22 | 0 | 25.35 | 19.42 | 1.31 |
| OFFSET | F+B | 15 | 1 | 56.41 | 52.84 | 1.07 |
| OUT1 | F+B | 5 | 1 | 21.05 | 20.96 | 1.00 |
| OUT2 | F+B | 8 | 1 | 24.33 | 21.22 | 1.15 |
| P12_RAW | F+B | 12 | 0 | 24.52 | 21.89 | 1.12 |
| WIPER1 | B | 10 | 0 | 31.70 | 25.10 | 1.26 |
| WIPER2 | B | 8 | 0 | 30.87 | 25.14 | 1.23 |
| GND | F+B | 100 | 3 | 201.70 | 160.61 | 1.26 |
| **total** |  | 351 | 22 | 752.08 | 638.51 | 1.18 |

Iterations: 12. Contested cells left: 0.
Via/pad violations: 0.
Disconnected nets: none.

## Analog intent

- matched group channels spans 15.30 mm (tolerance 10.00 mm; lengths count 1.6 mm per via): IN1 7.40 mm, IN2 22.71 mm

Coupling predicted from the copper, limit 2.20 mV:

| quiet net | noisy net | coupled pF | injected mV |
|---|---|--:|--:|
| WIPER1 | BUF2 | 0.0000 | 0.000 |
| WIPER1 | OA2 | 0.0000 | 0.000 |
| WIPER1 | OUT2 | 0.0000 | 0.000 |
| WIPER2 | BUF1 | 0.0000 | 0.000 |
| WIPER2 | OA1 | 0.0000 | 0.000 |
| WIPER2 | OUT1 | 0.0000 | 0.000 |
