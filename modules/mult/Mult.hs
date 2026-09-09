{-# LANGUAGE OverloadedStrings #-}
-- | MULT: passive 2x6 multiple, 6HP. See modules/mult/SPEC.md.
--
-- Why 6HP and two columns rather than 4HP and one column: with the official
-- Thonkiconn footprint the minimum vertical pitch is 13.6 mm (tip pad of one
-- jack against sleeve pad of the next), and a rail-safe PCB is at most 108 mm
-- tall, centred. Eight jacks in one column need 95 mm of pitch plus the
-- barrel above the first and the 12.5 mm body below the last: 110.7 mm. It
-- does not fit. Two columns of six fit with room to spare.
module Mult
  ( mult
  , handRouted
    -- * Geometry shared with the panel design
  , hp, panelWidth, panelHeight
  , colX, rowY, rows
  , railHoleX, railHoleY
  ) where

import           Data.Text (Text)
import qualified Data.Text as T

import           Design

-- Panel ----------------------------------------------------------------------

hp :: Int
hp = 6

panelWidth, panelHeight :: Double
panelWidth = eurorackPanelWidth hp          -- 30.0 (Doepfer table)
panelHeight = eurorackPanelHeight            -- 128.5

-- | Jack barrel centres on the panel, from its top-left corner.
-- 13.7 mm pitch: the official footprint needs 13.6 mm minimum (tip pad of one
-- jack vs. sleeve pad of the next, 0.2 mm clearance, 0.5 mm hole-to-hole).
jackPitch, firstRowY :: Double
jackPitch = 13.7
firstRowY = 30.0

rows :: [Int]
rows = [0 .. 5]

rowY :: Int -> Double
rowY k = firstRowY + jackPitch * fromIntegral k          -- 30.0 .. 98.5

-- | Column centres, 15 mm apart: 9 mm bodies leave 6 mm between them.
colX :: Int -> Double
colX 0 = 7.5
colX _ = 22.5

-- | Doepfer: holes 3.0 mm from the top and bottom edges, first hole 7.5 mm
-- from the left edge, further holes on the 5.08 mm grid.
railHoleY :: [Double]
railHoleY = [3.0, panelHeight - 3.0]

railHoleX :: [Double]
railHoleX = [7.5, 7.5 + 3 * 5.08]                         -- 7.5, 22.74

-- Board ----------------------------------------------------------------------

-- | Rail-safe board: 108 mm tall, centred on the 128.5 mm panel, 1 mm inside
-- each side edge.
boardW, boardH :: Double
boardW = panelWidth - 2.0                                 -- 28.0
boardH = eurorackPcbHeight                                -- 108.0

boardOffsetX, boardOffsetY :: Double
boardOffsetX = 1.0
boardOffsetY = eurorackPcbTop                             -- 10.25

toBoard :: (Double, Double) -> (Double, Double)
toBoard (x, y) = (x - boardOffsetX, y - boardOffsetY)

-- | Footprint origin is the barrel / sleeve pad; body extends +y (downwards).
jackAt :: Int -> Int -> (Double, Double)
jackAt col k = toBoard (colX col, rowY k)                 -- x 6.5 / 21.5, y 19.75 + 13.7k

tipPadDy :: Double
tipPadDy = 11.4

tipPad :: Int -> Int -> (Double, Double)
tipPad col k = let (x, y) = jackAt col k in (x, y + tipPadDy)

-- | Solder jumper on the back, on the tip-pad row of the third jacks, so both
-- links are straight horizontal traces.
jumperAt :: (Double, Double)
jumperAt = (boardW / 2, snd (tipPad 0 2))                 -- (14.0, 58.55)

-- Parts ------------------------------------------------------------------------

thonkiconnSym, thonkiconnFp, jumperSym, jumperFp :: LibId
thonkiconnSym = LibId "Connector_Audio" "AudioJack2_SwitchT"
thonkiconnFp  = LibId "Connector_Audio" "Jack_3.5mm_QingPu_WQP-PJ398SM_Vertical_CircularHoles"
jumperSym     = LibId "Jumper" "SolderJumper_2_Open"
jumperFp      = LibId "Jumper" "SolderJumper-2_P1.3mm_Open_Pad1.0x1.5mm"

-- | J1..J6 are column A (left), J7..J12 column B (right), top to bottom.
jackRef :: Int -> Int -> Text
jackRef col k = "J" <> T.pack (show (col * 6 + k + 1))

-- | Hand-soldered Thonkiconns. A passive multiple has nothing to normal an
-- unpatched jack to, so every switch pin (TN) is declared unconnected.
jacks :: [Part]
jacks =
  [ (part (jackRef col k) "Thonkiconn" thonkiconnSym thonkiconnFp (jackAt col k) (schX, schY))
      { partNoConnect = ["TN"] }
  | col <- [0, 1], k <- rows
  , let schX = if col == 0 then 50.8 else 152.4
  , let schY = 38.1 + 17.78 * fromIntegral k
  ]

-- | Solder jumper: bridged by hand, nothing for the factory to place.
jumper :: Part
jumper = (part "JP1" "LINK A-B" jumperSym jumperFp jumperAt (101.6, 152.4)) { partSide = Back, partAssembly = Hand }

-- Nets -----------------------------------------------------------------------

nets :: [Net]
nets =
  [ Net "GND"    Power  [ (jackRef c k, "S") | c <- [0, 1], k <- rows ]
  , Net "MULT_A" Signal ([ (jackRef 0 k, "T") | k <- rows ] ++ [("JP1", "1")])
  , Net "MULT_B" Signal ([ (jackRef 1 k, "T") | k <- rows ] ++ [("JP1", "2")])
  ]
  -- TN (switch) pins are intentionally unconnected: see 'jacks' (partNoConnect).

-- Copper ---------------------------------------------------------------------

-- | Hand routing, available via 'handRouted' if the autorouter is ever
-- switched off for this board.
handRouted :: [Trace]
handRouted = tipBus "MULT_A" 0 ++ tipBus "MULT_B" 1 ++ jumperLinks

-- | Each column's tips share a vertical bus 3 mm inboard of the pad column.
busX :: Int -> Double
busX 0 = fst (jackAt 0 0) + 3.0                           -- 9.5
busX _ = fst (jackAt 1 0) - 3.0                           -- 18.5

tipBus :: Text -> Int -> [Trace]
tipBus net col =
  [ Trace net "F.Cu" 0.5 [tipPad col k, (busX col, snd (tipPad col k))] | k <- rows ]
  ++ [ Trace net "F.Cu" 0.5 [(busX col, snd (tipPad col (head rows))), (busX col, snd (tipPad col (last rows)))] ]

-- | Jumper pads sit 0.65 mm left/right of its origin; each links straight to
-- the tip pad of the third jack in its column on the back layer.
jumperLinks :: [Trace]
jumperLinks =
  let (jx, jy) = jumperAt
  in [ Trace "MULT_A" "B.Cu" 0.4 [(jx - 0.65, jy), tipPad 0 2]
     , Trace "MULT_B" "B.Cu" 0.4 [(jx + 0.65, jy), tipPad 1 2]
     ]

fullBoard :: [(Double, Double)]
fullBoard = [(0, 0), (boardW, 0), (boardW, boardH), (0, boardH)]

board :: Board
board = Board
  { bdWidth = boardW
  , bdHeight = boardH
  , bdCornerRadius = 1.0
  , bdRules = defaultRules
    -- The hand routing (tipBus, jumperLinks) is kept as a reference; the
    -- board is routed by the grid router so the mult doubles as its test.
  , bdTraces = []
  , bdAutoRoute = Just (autoRoute ["MULT_A", "MULT_B"]) { arWidth = 0.5 }
  , bdZones =
      -- GND is not routed as copper here: the jack sleeves are connected by
      -- these pours alone, so the pours must bond to their pads.
      [ Zone "GND" "F.Cu" "GND_front" fullBoard 0.3 0.25 ThermalRelief
      , Zone "GND" "B.Cu" "GND_back"  fullBoard 0.3 0.25 ThermalRelief
      ]
  , bdTexts =
      [ BoardText "MULT 2x6" "B.SilkS" (boardW / 2, 8.0) 0 1.5
      , BoardText "A"        "B.SilkS" (fst (jackAt 0 0), 14.0) 0 1.5
      , BoardText "B"        "B.SilkS" (fst (jackAt 1 0), 14.0) 0 1.5
      , BoardText "LINK A-B" "B.SilkS" (fst jumperAt, snd jumperAt - 3.0) 0 0.8
      ]
  , bdCustomRules = T.unlines
      [ "# The official Thonkiconn footprint's courtyard is 14.4 mm long (-1.42 .. 12.98 mm"
      , "# from the barrel) but the body is 10.5 mm and the barrel sits on top of it, so"
      , "# stacked jacks at 13.7 mm pitch do not collide. Allow the overlap between jacks only."
      , "(rule \"jack_column_courtyard_overlap\""
      , "  (condition \"A.Reference == 'J*' && B.Reference == 'J*'\")"
      , "  (constraint courtyard_clearance (min -1.5mm)))"
      , ""
      , "# Jack body outline touches the next jack's pin marker on F.SilkS, which is"
      , "# under the panel and never visible."
      , "(rule \"jack_column_silk_touch\""
      , "  (severity ignore)"
      , "  (condition \"A.Reference == 'J*' && B.Reference == 'J*'\")"
      , "  (constraint silk_clearance (min 0mm)))"
      ]
  }

mult :: Module
mult = Module
  { modName = "mult"
  , modOutDir = "modules/mult/kicad"
  , modTitle = "MULT - passive 2x6 multiple"
  , modHP = hp
  , modParts = jacks ++ [jumper]
  , modNets = nets
  , modBoard = board
  , modNotes =
      [ "MULT - passive 2x6 multiple, 6HP"
      , "J1-J6 = group A (left column), J7-J12 = group B (right column)."
      , "Bridge JP1 (back of PCB) to join both groups into one 1x12 multiple."
      , "Jack switch (TN) pins intentionally unconnected."
      ]
  }
