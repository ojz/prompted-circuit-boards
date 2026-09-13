{-# LANGUAGE OverloadedStrings #-}
-- | UTIL-01 ATTENUVERTER: dual precision attenuverter with +5 V offset
-- normalling, 6HP. See docs/modules/attenuverter/SPEC.md.
--
-- Each channel is two op-amp units of one OPA2197. The first is a unity-gain
-- buffer on the input jack, so the attenuverter stage behind it sees a 0 ohm
-- source and the module presents 1 M to the cable instead of 50 k. The
-- second is the classic single op-amp attenuverter: the buffered input feeds
-- an inverting stage of gain -1 (R_a = R_f = 10k, 0.1 %) and, through the
-- pot as a divider, the non-inverting input of the same unit. With the pot
-- fraction k the output is (2k - 1) * Vin: -1x fully anticlockwise, silence
-- in the middle, +1x fully clockwise. A 10 pF C0G across R_f compensates the
-- inverting node's capacitance, as both reference designs do.
--
-- Why 10k and not the customary 100k: the op-amp's input capacitance (8 pF
-- on the datasheet, more with pads) draws its current through R_f, so at
-- full clockwise the gain shelves up towards 1 + C_in/C_f above the audio
-- band. The stability deck measured that shelf at +4.6 % at 20 kHz with
-- 100k and 10 pF of stray; with 10k it is 0.05 %, the inversion's roll-off
-- moves from 159 kHz to 1.6 MHz, and the phase margin is unchanged. The
-- buffer makes the value free to choose: nothing outside the board sees it.
--
-- With nothing patched the jack's switch pin normals the input to a REF5050
-- 5.000 V reference, so the channel doubles as a bipolar offset source that
-- does not move when the rail, the other channel or the room temperature
-- does. docs/modules/attenuverter/ERROR-BUDGET.md derives every one of these
-- choices from the datasheets; the decision that fixed them (option B) is
-- recorded in SPEC.md.
--
-- All SMD parts and the power header are on the back of the board (one
-- JLCPCB assembly side); jacks and pots are through-hole on the front.
module Attenuverter
  ( attenuverter
    -- * Geometry shared with the panel design
  , sk
  , jackPanelAt, potPanelAt
  ) where

import           Data.Text      (Text)
import qualified Data.Text      as T

import           Block.Eurorack
import           Design

-- Panel ----------------------------------------------------------------------

-- | 6HP: 30.0 x 128.5 mm panel, 28.0 x 100.0 mm board.
sk :: Skeleton
sk = skeleton 6

-- | Pot shafts on the panel centre line; channel 1 above channel 2.
potPanelAt :: Int -> (Double, Double)
potPanelAt 1 = (15.0, 22.0)
potPanelAt _ = (15.0, 64.0)

-- | Jack barrels: input left, output right, one row per channel below its pot.
-- A 9 mm pot at 13.75 x 12.8 mm footprint and a Thonkiconn at 9 x 14.4 mm
-- cannot share a row on a 28 mm board, hence the alternation.
jackPanelAt :: Int -> Bool -> (Double, Double)
jackPanelAt ch isOut = (if isOut then 22.5 else 7.5, if ch == 1 then 38.0 else 80.0)

-- Board ----------------------------------------------------------------------

boardW, boardH :: Double
boardW = skBoardWidth sk                                  -- 28.0
boardH = skBoardHeight sk                                 -- 100.0

-- | Panel coordinates to board coordinates, for this module's skeleton.
onBoard :: (Double, Double) -> (Double, Double)
onBoard = toBoard sk

-- Library ids ----------------------------------------------------------------

opampSym, vrefSym, soic8, rSym, r0805, cSym, c0805, dSym, sod123, hdrSym, hdrFp :: LibId
opampSym = LibId "Amplifier_Operational" "OPA2197xD"
vrefSym  = LibId "Reference_Voltage" "REF5050AD"
soic8    = LibId "Package_SO" "SOIC-8_3.9x4.9mm_P1.27mm"
rSym     = LibId "Device" "R"
r0805    = LibId "Resistor_SMD" "R_0805_2012Metric"
cSym     = LibId "Device" "C"
c0805    = LibId "Capacitor_SMD" "C_0805_2012Metric"
dSym     = LibId "Device" "D_Schottky"
sod123   = LibId "Diode_SMD" "D_SOD-123"
hdrSym   = LibId "Connector_Generic" "Conn_02x05_Odd_Even"
hdrFp    = LibId "Connector_IDC" "IDC-Header_2x05_P2.54mm_Vertical"

-- | JLCPCB parts. Passives, diodes and the original codes were verified on
-- jlcpcb.com on 2026-09-08; the precision parts and the new passives against
-- LCSC's product data on 2026-09-13 (SPEC.md has the table).
lcsc :: Text -> [(Text, Text)]
lcsc c = [("LCSC Part #", c)]

-- Parts ----------------------------------------------------------------------

-- Schematic rows (A4 landscape): channel 1, channel 2, power and reference.
rowY1, rowY2, rowY3 :: Double
rowY1 = 45.72
rowY2 = 96.52
rowY3 = 147.32

-- | Thonkiconn: footprint origin is the barrel; body extends +y. Hand
-- soldered. An output jack's switch pin (TN) has nothing to normal to and
-- is declared unconnected; an input jack's TN carries OFFSET.
jack :: Text -> Text -> Int -> Bool -> Part
jack ref val ch isOut =
  (part ref val thonkiconnSym thonkiconnFp (onBoard (jackPanelAt ch isOut))
        (if isOut then 203.20 else 38.1, if ch == 1 then rowY1 else rowY2))
    { partNoConnect = [ "TN" | isOut ] }

-- | Alpha 9 mm pot, rotated 90 so its pins point down and its lugs sit left
-- and right of the shaft. Footprint origin is pin 1; the shaft is at
-- (7.5, 2.5) in footprint coordinates. Pins land 7.5 mm below the shaft
-- (y = 29.5 and 71.5 on the panel), lugs 4.8 mm either side of it.
pot :: Text -> Int -> Part
pot ref ch =
  (part ref "B100K" alphaPotSym alphaPotFp (originFor Front 90 (7.5, 2.5) (onBoard (potPanelAt ch))) (96.52, if ch == 1 then rowY1 else rowY2))
    { partRot = 90 }

-- | Factory-assembled SMD part on the back, at a panel position. JLCPCB
-- places from the BOM and position file, so passives and diodes carry no
-- silkscreen reference; ICs and the header keep theirs for orientation
-- checks (the diode footprint has its own cathode bar).
smd :: Text -> Text -> LibId -> LibId -> Text -> (Double, Double) -> (Double, Double) -> Part
smd ref val sy fp code panelPos schPos =
  (part ref val sy fp (onBoard panelPos) schPos)
    { partSide = Back, partFields = lcsc code, partRefOnSilk = False, partAssembly = Factory }

withRef :: Part -> Part
withRef p = p { partRefOnSilk = True }

-- | One channel's SMD parts. The back of the board has two strips free of
-- through-hole pads that are 11.5 mm tall and the full 28 mm wide: between
-- the first jack row's tip pads and the second pot's lugs (panel y 50.5 to
-- 62, channel 1), and between the second jack row's tip pads and the power
-- header (y 93 to 104.5, channel 2). Each strip holds three rows of 0805s at
-- 4 mm pitch with a SOIC-8 in the middle row; the decoupling capacitors sit
-- in the row nearest the supply pin they serve (mirrored on the back: pin 4
-- V- is at the top-left of the package, pin 8 V+ at the bottom-right).
--
-- Reference designators per channel: ch 1 uses U1, R1 R2 R3 R9 C3 C4 C9;
-- ch 2 uses U2, R4 R5 R6 R10 C11 C12 C10. Passed in explicitly so the
-- netlist below reads the same as the schematic.
channel :: Int -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Double -> Double -> [Part]
channel ch u rA rF rO rIn cF cVp cVn uY rowY =
  let top = uY - 4.0
      bot = uY + 4.0
      -- Channel 1 shares its strip with the reference, so its op-amp sits
      -- left and its decoupling goes in slots 0 (V-) and 2 (V+); channel 2
      -- sits centred, next to the bulk capacitors and Schottkys in its own
      -- row, with decoupling in slots 2 (V-) and 4 (V+).
      (uX, vnSlot, vpSlot, uSlot) = if ch == 1 then (7.5, 0, 2, 1) else (14.0, 2, 4, 3)
      slot i = 3.5 + 3.5 * fromIntegral (i :: Int)
      topSlots = filter (/= vnSlot) [0 .. 3]
      -- The op-amp's reference designator is printed below its package on
      -- the back, over the bottom-row slot under it (uSlot), so that slot
      -- stays empty.
      botSlots = filter (\i -> i /= vpSlot && i /= uSlot) [0 .. 3]
      at i y = (slot i, y)
      sch x = (x, rowY)
  in
  [ withRef (smd u "OPA2197" opampSym soic8 "C139363" (uX, uY) (sch 73.66))
      -- Unit A (buffer) in the channel row, unit B (attenuverter) to its
      -- right, the power unit in the third row.
      { partUnitOffsets = [(83.82, 0), (if ch == 1 then -12.70 else 7.62, rowY3 - rowY)] }
  , smd cVn "100n" cSym c0805 "C49678"  (at vnSlot top) (if ch == 1 then (175.26, rowY3) else (205.74, rowY3))
  , smd rIn "1M"   rSym r0805 "C17514"  (at (topSlots !! 0) top) (55.88, rowY + 10.16)
  , smd rA  "10k"  rSym r0805 "C110775" (at (topSlots !! 1) top) (sch 114.30)
  , smd rF  "10k"  rSym r0805 "C110775" (at (topSlots !! 2) top) (sch 134.62)
  , smd rO  "1k"   rSym r0805 "C17513"  (at (botSlots !! 0) bot) (sch 180.34)
    -- In the schematic the capacitor sits well above R_f: at 12.7 mm their
    -- pin stubs met and KiCad merged INV and OA into one net.
  , smd cF  "10p"  cSym c0805 "C344177" (at (botSlots !! 1) bot) (134.62, rowY - 22.86)
  , smd cVp "100n" cSym c0805 "C49678"  (at vpSlot bot) (if ch == 1 then (160.02, rowY3) else (190.50, rowY3))
  ]

parts :: [Part]
parts =
  [ jack "J1" "IN 1"  1 False
  , jack "J2" "OUT 1" 1 True
  , jack "J3" "IN 2"  2 False
  , jack "J4" "OUT 2" 2 True
  , pot "RV1" 1
  , pot "RV2" 2
  ]
  ++ channel 1 "U1" "R1" "R2" "R3" "R9"  "C9"  "C3"  "C4"  56.0 rowY1
  ++ channel 2 "U2" "R4" "R5" "R6" "R10" "C10" "C11" "C12" 98.5 rowY2
  ++
    -- Offset reference in the right half of channel 1's strip: REF5050 with
    -- its 1 uF input bypass, 1 uF output capacitor (the datasheet's stability
    -- condition) and 1 uF on the noise-reduction pin, all in the top row.
  [ withRef (smd "U3" "REF5050" vrefSym soic8 "C27804" (20.5, 56.0) (238.76, rowY3))
      { partNoConnect = ["3"] }                            -- TEMP: not used
  , smd "C6" "1u" cSym c0805 "C28323" (17.5, 52.0) (223.52, rowY3 + 15.24)
  , smd "C7" "1u" cSym c0805 "C28323" (21.0, 52.0) (256.54, rowY3 + 15.24)
  , smd "C8" "1u" cSym c0805 "C28323" (24.5, 52.0) (238.76, rowY3 + 22.86)
    -- Bulk caps and Schottkys either side of U2 in its middle row (a
    -- SOD-123 courtyard is 4.7 mm wide, so the diodes take the outer spots).
  , smd "D1" "B5819W" dSym sod123 "C8598" (4.3, 98.5)  (99.06, rowY3)
  , smd "C1" "10u"  cSym c0805 "C15850" (8.5, 98.5)  (129.54, rowY3)
  , smd "C2" "10u"  cSym c0805 "C15850" (20.0, 98.5) (144.78, rowY3)
  , smd "D2" "B5819W" dSym sod123 "C8598" (24.5, 98.5) (114.30, rowY3)
    -- 2x5 shrouded IDC header along the bottom edge, on the back, pins 1-2
    -- (-12 V) at the right. Footprint origin is pin 1; the pad field is
    -- centred at (1.27, 5.08) and the shroud reaches 4.45 mm either side of
    -- it, so a centre at panel y 109.5 keeps it 0.3 mm inside the board's
    -- bottom edge at 114.25. Through-hole, soldered by hand.
  , (part "J5" "POWER" hdrSym hdrFp (originFor Back 90 (1.27, 5.08) (onBoard (14.5, 109.5))) (38.1, rowY3))
      { partSide = Back, partRot = 90, partAssembly = Hand }
  ]

-- Nets -----------------------------------------------------------------------

-- | One channel's signal nets. Unit A of the OPA2197 (pins 1, 2, 3) is the
-- buffer, unit B (pins 5, 6, 7) the attenuverter stage. Pot end 3 carries the
-- buffered input so that clockwise means positive gain.
channelNets :: Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> [Net]
channelNets n u jIn jOut rv rA rF rO rIn cF =
  [ Net ("IN" <> n)    Signal [(jIn, "T"), (rIn, "1"), (u, "3")]
  , Net ("BUF" <> n)   Signal [(u, "1"), (u, "2"), (rA, "1"), (rv, "3")]
  , Net ("INV" <> n)   Signal [(rA, "2"), (rF, "1"), (cF, "1"), (u, "6")]
  , Net ("WIPER" <> n) Signal [(rv, "2"), (u, "5")]
  , Net ("OA" <> n)    Signal [(u, "7"), (rF, "2"), (cF, "2"), (rO, "1")]
  , Net ("OUT" <> n)   Signal [(rO, "2"), (jOut, "T")]
  ]

nets :: [Net]
nets =
  [ Net "GND"  Power  ([ (j, "S") | j <- ["J1", "J2", "J3", "J4"] ] ++ [("RV1", "1"), ("RV2", "1")]
                       ++ [ (c, "2") | c <- ["C1", "C2", "C3", "C4", "C6", "C7", "C8", "C11", "C12"] ]
                       ++ [("R9", "2"), ("R10", "2"), ("U3", "4")]
                       ++ [ ("J5", T.pack (show p)) | p <- [3 .. 8 :: Int] ])
  , Net "+12V" Power  [("D2", "1"), ("C1", "1"), ("C3", "1"), ("C11", "1"), ("C6", "1"), ("U1", "8"), ("U2", "8"), ("U3", "2")]
  , Net "-12V" Power  [("D1", "2"), ("C2", "1"), ("C4", "1"), ("C12", "1"), ("U1", "4"), ("U2", "4")]
  , Net "P12_RAW" Signal [("J5", "9"), ("J5", "10"), ("D2", "2")]
  , Net "N12_RAW" Signal [("J5", "1"), ("J5", "2"), ("D1", "1")]
    -- The reference output is normalled to both input jacks' switch pins.
  , Net "OFFSET"  Signal [("J1", "TN"), ("J3", "TN"), ("U3", "6"), ("C7", "1")]
  , Net "NR"      Signal [("U3", "5"), ("C8", "1")]
  ]
  ++ channelNets "1" "U1" "J1" "J2" "RV1" "R1" "R2" "R3" "R9"  "C9"
  ++ channelNets "2" "U2" "J3" "J4" "RV2" "R4" "R5" "R6" "R10" "C10"
  -- J2.TN and J4.TN are intentionally unconnected: see 'jack' (partNoConnect).
  -- U3.3 (TEMP) is intentionally unconnected: see 'parts'.

-- | Everything is routed as copper, GND included: the ground pours on both
-- layers are a bonus on top, not the only connection, so a trace cutting a
-- pour into islands cannot strand a pad.
routedNets :: [Text]
routedNets = map netName nets

-- Board ----------------------------------------------------------------------

fullBoard :: [(Double, Double)]
fullBoard = boardOutline sk

board :: Board
board = Board
  { bdWidth = boardW
  , bdHeight = boardH
  , bdCornerRadius = 1.0
  , bdRules = defaultRules
  , bdTraces = []
  , bdAutoRoute = Just (autoRoute routedNets)
  , bdZones =
      -- Redundant shielding: every net is routed as copper, so the pours do
      -- not bond to pads (see PadConnect).
      [ Zone "GND" "F.Cu" "GND_front" fullBoard 0.3 0.25 PadsUnbonded
      , Zone "GND" "B.Cu" "GND_back"  fullBoard 0.3 0.25 PadsUnbonded
      ]
  , bdTexts =
      [ BoardText "ATTENUVERTER" "B.SilkS" (boardW / 2, 3.0) 0 1.5
      , BoardText "UTIL-01"      "B.SilkS" (boardW / 2, 5.3) 0 1.0
        -- Red-stripe marker beside the header's pin-1 end, below J5's own
        -- reference text.
      , BoardText "-12V" "B.SilkS" (onBoard (26.5, 112.8)) 0 0.8
      ]
  , bdCustomRules = ""
  , bdAnalog = attenuverterIntent
  }

-- | What this board has to achieve electrically, beyond connecting the pads.
--
-- The spec that matters for a dual utility module is channel-to-channel
-- crosstalk, and on this circuit there is exactly one mechanism for it: each
-- channel's low-impedance nodes (its buffer output and its stage output)
-- swing the full rail at audio rate on the same board as the other
-- channel's pot wiper, which is the only high-impedance node in the signal
-- path. The input jack node is 1 M to ground but sees the cable's 1 k source
-- when patched and the reference when not, so it is not a victim.
--
-- Numbers, none of them guessed:
--
-- * A wiper's source impedance is the pot's two halves in parallel, worst
--   case 100k/4 = 25k at centre detent. That is the 'Quiet' figure.
--
-- * An output is a low-impedance op-amp swinging about 22 V peak-to-peak. Its
--   fastest edge is a full-scale 20 kHz sine, 2*pi*20k*11 = 1.38 V/us, which
--   is 22 V in 16 us. That is the 'Noisy' figure. The outputs are named as
--   the aggressors rather than the wipers because the model assumes the
--   aggressor holds its voltage regardless of the coupling current, which is
--   true of an op-amp output and not of a wiper.
--
-- * The victim node carries the OPA2197's common-mode input capacitance
--   (6.4 pF, SBOS737C) and its pads; 'anNodePf' is 6, deliberately on the low
--   side so the prediction errs towards alarming.
--
-- * -80 dB of crosstalk on a 22 V swing is 2.2 mV, which is the limit taken
--   here. That is a normal figure to quote for a utility module and it is the
--   number 'anInjectMv' has to be justified against if anyone changes it.
--
-- The two channels are also declared as a matched pair. Nothing electrical
-- turns on their copper lengths matching at audio -- the length budget below
-- is 9 times slack -- but a 10 mm tolerance catches the case where one
-- channel gets routed the short way round and the other the long way, which
-- is worth knowing about even when it costs nothing.
attenuverterIntent :: Analog
attenuverterIntent = Analog
  { anRoles =
      [ ("WIPER1", Quiet 25e3)
      , ("WIPER2", Quiet 25e3)
      , ("BUF1", Noisy 22 16e-6)
      , ("BUF2", Noisy 22 16e-6)
      , ("OA1", Noisy 22 16e-6)
      , ("OA2", Noisy 22 16e-6)
      , ("OUT1", Noisy 22 16e-6)
      , ("OUT2", Noisy 22 16e-6)
      ]
    -- 25k against 20 kHz allows 6965 mm of copper (`nodebudget.py length
    -- --r 25k`), so nothing on a 6HP board can come near it. Written at
    -- 120 mm, a little over the longest trace the board can hold, purely so a
    -- wiper that somehow got routed right round the board would be noticed.
  , anMaxLength = [("WIPER1", 120), ("WIPER2", 120)]
  , anMatched = [("channels", ["IN1", "IN2"], 10), ("outputs", ["OUT1", "OUT2"], 10)]
  , anInjectMv = 2.2
    -- Each channel is one signal path, so an output near its own wiper is
    -- feedback and not crosstalk. Without this the only non-zero numbers in
    -- the report are WIPER1 against OA1 and WIPER2 against OA2, which are
    -- exactly the two pairs nobody should care about, and a tighter limit
    -- would have the router spend copper prising each op-amp away from its
    -- own feedback network.
  , anSameCircuit =
      [ ["IN1", "BUF1", "INV1", "WIPER1", "OA1", "OUT1"]
      , ["IN2", "BUF2", "INV2", "WIPER2", "OA2", "OUT2"]
      ]
  , anNodePf = 6
  }

attenuverter :: Module
attenuverter = Module
  { modName = "attenuverter"
  , modOutDir = "modules/attenuverter/kicad"
  , modTitle = "UTIL-01 ATTENUVERTER - dual attenuverter / offset"
  , modHP = skHP sk
  , modParts = parts
  , modNets = nets
  , modBoard = board
  , modNotes =
      [ "UTIL-01 ATTENUVERTER - dual precision attenuverter with offset normalling, 6HP"
      , "Per channel: OPA2197 unity-gain input buffer (1M input) into a single op-amp attenuverter, 0.1% 100k, 10p C0G across R_f."
      , "Vout = (2k - 1) * Vin; k = pot fraction (CW = +1x, CCW = -1x)."
      , "Unpatched inputs are normalled to OFFSET, a REF5050 5.000 V reference: bipolar offset source."
      , "SMD and power header on the back (JLCPCB assembly side); jacks and pots on the front."
      , "J2.TN, J4.TN and U3.3 (TEMP) intentionally unconnected."
      ]
  }
