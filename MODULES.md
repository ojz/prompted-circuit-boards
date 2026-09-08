# Modules

This file gives an overview of all the modules that I want to include in this project.

## POW-01

- power management within the project
- power distribution
- voltage regulation

## UTIL-01

- voltage source
- attenuverter
- status LED
- push button

## OUT-01

- output stage
- signal amplification
- level control
- stereo output

## MULT

- passive 2×6 multiple, 6HP, no power (4HP × 8 jacks does not clear the rails with the official Thonkiconn footprint)
- solder jumper joins the two groups into 1×12
- project: `modules/mult/`

## 3TRINS-SMT (idea, parked)

- SMT remake of Gijs Gieskes' 3TrinsRGB+1c video synthesizer, assembled by JLCPCB
- more capable MCU than the original
- standalone device, not Eurorack: needs its own panel and enclosure conventions
- check the original's licence/permission before publishing derivative files
