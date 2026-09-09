{-# LANGUAGE OverloadedStrings #-}
-- | UTIL-01 ATTENUVERTER: dual attenuverter with +5 V offset normalling, 6HP.
-- See modules/attenuverter/SPEC.md.
--
-- Each channel is the classic single op-amp attenuverter: the input feeds an
-- inverting stage of gain -1 (R_a = R_f = 100k) and, through the pot as a
-- divider, the non-inverting input of the same op-amp. With the pot fraction
-- k the output is (2k - 1) * Vin: -1x fully anticlockwise, silence in the
-- middle, +1x fully clockwise. With nothing patched the jack's switch pin
-- normals the input to about +4.8 V, so the channel doubles as a bipolar
-- offset source.
--
-- All SMD parts and the power header are on the back of the board (one
-- JLCPCB assembly side); jacks and pots are through-hole on the front.
module Attenuverter
  ( attenuverter
    -- * Geometry shared with the panel design
  , hp, panelWidth, panelHeight
  , jackPanelAt, potPanelAt
  , railHoleX, railHoleY
  ) where

import           Data.Text      (Text)
import qualified Data.Text      as T

import           Design
import           Route.Geometry (rotatePt)

-- Panel ----------------------------------------------------------------------

hp :: Int
hp = 6

panelWidth, panelHeight :: Double
panelWidth = eurorackPanelWidth hp          -- 30.0
panelHeight = eurorackPanelHeight            -- 128.5

-- | Pot shafts on the panel centre line; channel 1 above channel 2.
potPanelAt :: Int -> (Double, Double)
potPanelAt 1 = (15.0, 22.0)
potPanelAt _ = (15.0, 64.0)

-- | Jack barrels: input left, output right, one row per channel below its pot.
-- A 9 mm pot at 13.75 x 12.8 mm footprint and a Thonkiconn at 9 x 14.4 mm
-- cannot share a row on a 28 mm board, hence the alternation.
jackPanelAt :: Int -> Bool -> (Double, Double)
jackPanelAt ch isOut = (if isOut then 22.5 else 7.5, if ch == 1 then 38.0 else 80.0)

railHoleY :: [Double]
railHoleY = [3.0, panelHeight - 3.0]

railHoleX :: [Double]
railHoleX = [7.5, 7.5 + 3 * 5.08]                         -- 7.5, 22.74

-- Board ----------------------------------------------------------------------

boardW, boardH :: Double
boardW = panelWidth - 2.0                                 -- 28.0
boardH = eurorackPcbHeight                                -- 108.0

boardOffsetX, boardOffsetY :: Double
boardOffsetX = 1.0
boardOffsetY = eurorackPcbTop                             -- 10.25

toBoard :: (Double, Double) -> (Double, Double)
toBoard (x, y) = (x - boardOffsetX, y - boardOffsetY)

-- | Footprint origin that puts a footprint-local point at a wanted board
-- position, for the side and rotation the part will get. Mirrors what the
-- PCB emitter does: flip (negate local y) first, then rotate.
originFor :: Side -> Double -> (Double, Double) -> (Double, Double) -> (Double, Double)
originFor side rot (lx, ly) (bx, by) =
  let ly' = if side == Back then negate ly else ly
      (dx, dy) = rotatePt rot (lx, ly')
  in (bx - dx, by - dy)

-- Library ids ----------------------------------------------------------------

jackSym, jackFp, potSym, potFp, opampSym, soic8, rSym, r0805, cSym, c0805, dSym, sod123, hdrSym, hdrFp :: LibId
jackSym  = LibId "Connector_Audio" "AudioJack2_SwitchT"
jackFp   = LibId "Connector_Audio" "Jack_3.5mm_QingPu_WQP-PJ398SM_Vertical_CircularHoles"
potSym   = LibId "Device" "R_Potentiometer"
potFp    = LibId "Potentiometer_THT" "Potentiometer_Alpha_RD901F-40-00D_Single_Vertical"
opampSym = LibId "Amplifier_Operational" "TL072"
soic8    = LibId "Package_SO" "SOIC-8_3.9x4.9mm_P1.27mm"
rSym     = LibId "Device" "R"
r0805    = LibId "Resistor_SMD" "R_0805_2012Metric"
cSym     = LibId "Device" "C"
c0805    = LibId "Capacitor_SMD" "C_0805_2012Metric"
dSym     = LibId "Device" "D_Schottky"
sod123   = LibId "Diode_SMD" "D_SOD-123"
hdrSym   = LibId "Connector_Generic" "Conn_02x05_Odd_Even"
hdrFp    = LibId "Connector_IDC" "IDC-Header_2x05_P2.54mm_Vertical"

-- | JLCPCB parts, verified against jlcpcb.com/partdetail on 2026-09-08.
lcsc :: Text -> [(Text, Text)]
lcsc c = [("LCSC Part #", c)]

-- Parts ----------------------------------------------------------------------

-- Schematic rows (A4 landscape): channel 1, channel 2, power.
rowY1, rowY2, rowY3 :: Double
rowY1 = 45.72
rowY2 = 96.52
rowY3 = 147.32

-- | Thonkiconn: footprint origin is the barrel; body extends +y. Hand
-- soldered. An output jack's switch pin (TN) has nothing to normal to and
-- is declared unconnected; an input jack's TN carries OFFSET.
jack :: Text -> Text -> Int -> Bool -> Part
jack ref val ch isOut =
  (part ref val jackSym jackFp (toBoard (jackPanelAt ch isOut))
        (if isOut then 195.58 else 38.1, if ch == 1 then rowY1 else rowY2))
    { partNoConnect = [ "TN" | isOut ] }

-- | Alpha 9 mm pot, rotated 90 so its pins point down and its lugs sit left
-- and right of the shaft. Footprint origin is pin 1; the shaft is at
-- (7.5, 2.5) in footprint coordinates.
pot :: Text -> Int -> Part
pot ref ch =
  (part ref "B100K" potSym potFp (originFor Front 90 (7.5, 2.5) (toBoard (potPanelAt ch))) (69.85, if ch == 1 then rowY1 else rowY2))
    { partRot = 90 }

-- | Factory-assembled SMD part on the back, at a panel position. JLCPCB
-- places from the BOM and position file, so passives and diodes carry no
-- silkscreen reference; IC and header keep theirs for orientation checks
-- (the diode footprint has its own cathode bar).
smd :: Text -> Text -> LibId -> LibId -> Text -> (Double, Double) -> (Double, Double) -> Part
smd ref val sy fp code panelPos schPos =
  (part ref val sy fp (toBoard panelPos) schPos)
    { partSide = Back, partFields = lcsc code, partRefOnSilk = False, partAssembly = Factory }

withRef :: Part -> Part
withRef p = p { partRefOnSilk = True }

parts :: [Part]
parts =
  [ jack "J1" "IN 1"  1 False
  , jack "J2" "OUT 1" 1 True
  , jack "J3" "IN 2"  2 False
  , jack "J4" "OUT 2" 2 True
  , pot "RV1" 1
  , pot "RV2" 2
    -- Op-amp centred in the SMD strip below the second jack row; units 2 and
    -- 3 of the symbol land in schematic rows 2 and 3.
  , withRef (smd "U1" "TL072" opampSym soic8 "C6961" (14.0, 98.5) (165.1, rowY1))
      { partUnitOffsets = [(0, rowY2 - rowY1), (0, rowY3 - rowY1)] }
    -- Channel 1 passives in the left column, channel 2 in the right one,
    -- 3.5 mm pitch (0805 courtyard is 1.9 mm tall).
  , smd "R1" "100k" rSym r0805 "C17407" (4.5, 94.5)  (95.25, rowY1)
  , smd "R2" "100k" rSym r0805 "C17407" (4.5, 98.0)  (113.03, rowY1)
  , smd "R3" "1k"   rSym r0805 "C17513" (4.5, 101.5) (130.81, rowY1)
  , smd "R4" "100k" rSym r0805 "C17407" (23.5, 94.5) (95.25, rowY2)
  , smd "R5" "100k" rSym r0805 "C17407" (23.5, 98.0) (113.03, rowY2)
  , smd "R6" "1k"   rSym r0805 "C17513" (23.5, 101.5) (130.81, rowY2)
    -- Offset reference: 12 V * 1k / 2.5k = 4.8 V, filtered, on the back
    -- between the jack columns.
  , smd "R7" "1.5k" rSym r0805 "C4310"  (15.0, 44.5) (218.44, rowY3)
  , smd "R8" "1k"   rSym r0805 "C17513" (15.0, 48.0) (236.22, rowY3)
  , smd "C5" "100n" cSym c0805 "C49678" (15.0, 51.5) (200.66, rowY3)
    -- Rail decoupling beside the op-amp's supply pins (mirrored on the back:
    -- pin 4 V- top-left, pin 8 V+ bottom-right), bulk caps and Schottkys in
    -- the row above the header.
  , smd "C4" "100n" cSym c0805 "C49678" (8.3, 94.5)   (182.88, rowY3)
  , smd "C3" "100n" cSym c0805 "C49678" (19.7, 101.5) (147.32, rowY3)
  , smd "D1" "B5819W" dSym sod123 "C8598" (4.5, 105.0)  (66.04, rowY3)
  , smd "C1" "10u"  cSym c0805 "C15850" (9.5, 105.0)  (111.76, rowY3)
  , smd "C2" "10u"  cSym c0805 "C15850" (18.5, 105.0) (129.54, rowY3)
  , smd "D2" "B5819W" dSym sod123 "C8598" (23.5, 105.0) (91.44, rowY3)
    -- 2x5 shrouded IDC header along the bottom edge, on the back, pins 1-2
    -- (-12 V) at the right. Footprint origin is pin 1; the pad field is
    -- centred at (1.27, 5.08). Through-hole, soldered by hand.
  , (part "J5" "POWER" hdrSym hdrFp (originFor Back 90 (1.27, 5.08) (toBoard (14.5, 111.5))) (38.1, rowY3))
      { partSide = Back, partRot = 90, partAssembly = Hand }
  ]

-- Nets -----------------------------------------------------------------------

nets :: [Net]
nets =
  [ Net "GND"  Power  ([ (j, "S") | j <- ["J1", "J2", "J3", "J4"] ] ++ [("RV1", "1"), ("RV2", "1")]
                       ++ [ (c, "2") | c <- ["C1", "C2", "C3", "C4", "C5"] ] ++ [("R8", "2")]
                       ++ [ ("J5", T.pack (show p)) | p <- [3 .. 8 :: Int] ])
  , Net "+12V" Power  [("D2", "1"), ("C1", "1"), ("C3", "1"), ("R7", "1"), ("U1", "8")]
  , Net "-12V" Power  [("D1", "2"), ("C2", "1"), ("C4", "1"), ("U1", "4")]
  , Net "P12_RAW" Signal [("J5", "9"), ("J5", "10"), ("D2", "2")]
  , Net "N12_RAW" Signal [("J5", "1"), ("J5", "2"), ("D1", "1")]
  , Net "OFFSET"  Signal [("J1", "TN"), ("J3", "TN"), ("R7", "2"), ("R8", "1"), ("C5", "1")]
    -- Pot end 3 carries the input so that clockwise means positive gain.
  , Net "IN1"     Signal [("J1", "T"), ("R1", "1"), ("RV1", "3")]
  , Net "INV1"    Signal [("R1", "2"), ("R2", "1"), ("U1", "2")]
  , Net "WIPER1"  Signal [("RV1", "2"), ("U1", "3")]
  , Net "OA1"     Signal [("U1", "1"), ("R2", "2"), ("R3", "1")]
  , Net "OUT1"    Signal [("R3", "2"), ("J2", "T")]
  , Net "IN2"     Signal [("J3", "T"), ("R4", "1"), ("RV2", "3")]
  , Net "INV2"    Signal [("R4", "2"), ("R5", "1"), ("U1", "6")]
  , Net "WIPER2"  Signal [("RV2", "2"), ("U1", "5")]
  , Net "OA2"     Signal [("U1", "7"), ("R5", "2"), ("R6", "1")]
  , Net "OUT2"    Signal [("R6", "2"), ("J4", "T")]
  ]
  -- J2.TN and J4.TN are intentionally unconnected: see 'jack' (partNoConnect).

-- | Everything is routed as copper, GND included: the ground pours on both
-- layers are a bonus on top, not the only connection, so a trace cutting a
-- pour into islands cannot strand a pad.
routedNets :: [Text]
routedNets = map netName nets

-- Board ----------------------------------------------------------------------

fullBoard :: [(Double, Double)]
fullBoard = [(0, 0), (boardW, 0), (boardW, boardH), (0, boardH)]

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
        -- Red-stripe marker under the header's pin-1 end.
      , BoardText "-12V" "B.SilkS" (toBoard (24.0, 117.0)) 0 0.8
      ]
  , bdCustomRules = ""
  }

attenuverter :: Module
attenuverter = Module
  { modName = "attenuverter"
  , modOutDir = "modules/attenuverter/kicad"
  , modTitle = "UTIL-01 ATTENUVERTER - dual attenuverter / offset"
  , modHP = hp
  , modParts = parts
  , modNets = nets
  , modBoard = board
  , modNotes =
      [ "UTIL-01 ATTENUVERTER - dual attenuverter with offset normalling, 6HP"
      , "Vout = (2k - 1) * Vin per channel; k = pot fraction (CW = +1x, CCW = -1x)."
      , "Unpatched inputs are normalled to OFFSET (~ +4.8 V): bipolar offset source."
      , "SMD and power header on the back (JLCPCB assembly side); jacks and pots on the front."
      , "J2.TN and J4.TN intentionally unconnected."
      ]
  }
