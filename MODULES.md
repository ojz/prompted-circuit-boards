# Modules

- eurorack compatible

## POW-01

- power management within the project
- power distribution
- voltage regulation

## UTIL-01 ATTENUVERTER

- dual attenuverter, 6HP: `Vout = (2k − 1) · Vin` per channel, one TL072
- unpatched inputs normalled to +4.8 V, so each channel doubles as a bipolar offset source
- SMD on the back for JLCPCB assembly; Thonkiconn jacks, Alpha 9 mm pots and power header hand-soldered
- first module routed entirely by pcbgen's autorouter
- project: `modules/attenuverter/`, spec: `modules/attenuverter/SPEC.md`
- later ideas from the original UTIL-01 sketch, not in this board: status LED, push button

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
- standalone device, Eurorack compatible.
- lasercut wood enclosure
- open source hardware, open source software
- built-in monitor + speaker
- check the original's licence/permission before publishing derivative files
