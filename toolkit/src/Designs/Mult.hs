{-# LANGUAGE OverloadedStrings #-}
-- | MULT: passive 2x4 multiple, 4HP. See modules/mult/SPEC.md.
module Designs.Mult (mult) where

import           Data.Text (Text)
import qualified Data.Text as T

import           Design

-- Panel ----------------------------------------------------------------------

hp :: Int
hp = 4

panelWidth :: Double
panelWidth = eurorackPanelWidth hp          -- 20.02

-- | Jack barrel centres on the panel, from the panel's top-left corner.
-- 13.7 mm is the minimum pitch the official Thonkiconn footprint allows:
-- tip pad of one jack (11.4 mm below the barrel) vs. sleeve pad of the next,
-- 0.2 mm clearance plus 0.5 mm hole-to-hole.
jackPitch, firstJackY :: Double
jackPitch = 13.7
firstJackY = 11.0

panelJackY :: Int -> Double
panelJackY k = firstJackY + jackPitch * fromIntegral k

-- Board ----------------------------------------------------------------------

-- | The PCB hangs behind the panel with its top-left corner at panel (0.76, 9.0).
boardOffsetX, boardOffsetY :: Double
boardOffsetX = 0.76
boardOffsetY = 9.0

boardW, boardH :: Double
boardW = 18.5
boardH = 111.5

-- | Board coordinates of jack k (0..7): footprint origin is the barrel/sleeve pad.
jackAt :: Int -> (Double, Double)
jackAt k = (panelWidth / 2 - boardOffsetX, panelJackY k - boardOffsetY)   -- x = 9.25

-- Thonkiconn pad offsets from the footprint origin (rotation 0, body pointing down).
tipPadDy :: Double
tipPadDy = 11.4

tipPad :: Int -> (Double, Double)
tipPad k = let (x, y) = jackAt k in (x, y + tipPadDy)

jumperAt :: (Double, Double)
jumperAt = (9.25, 50.0)   -- back side, in the free strip between J4's TN pad and tip pad

-- Parts ------------------------------------------------------------------------

thonkiconnSym, thonkiconnFp, jumperSym, jumperFp :: LibId
thonkiconnSym = LibId "Connector_Audio" "AudioJack2_SwitchT"
thonkiconnFp  = LibId "Connector_Audio" "Jack_3.5mm_QingPu_WQP-PJ398SM_Vertical_CircularHoles"
jumperSym     = LibId "Jumper" "SolderJumper_2_Open"
jumperFp      = LibId "Jumper" "SolderJumper-2_P1.3mm_Open_Pad1.0x1.5mm"

jackRef :: Int -> Text
jackRef k = "J" <> T.pack (show (k + 1))

jacks :: [Part]
jacks =
  [ part (jackRef k) "Thonkiconn" thonkiconnSym thonkiconnFp (jackAt k) (schX, schY)
  | k <- [0 .. 7]
  , let schX = if k < 4 then 50.8 else 152.4
  , let schY = 50.8 + 20.32 * fromIntegral (k `mod` 4)
  ]

jumper :: Part
jumper = (part "JP1" "LINK A-B" jumperSym jumperFp jumperAt (109.22, 134.62)) { partSide = Back }

-- Nets -----------------------------------------------------------------------

nets :: [Net]
nets =
  [ Net "GND"    Power  [ (jackRef k, "S") | k <- [0 .. 7] ]
  , Net "MULT_A" Signal ([ (jackRef k, "T") | k <- [0 .. 3] ] ++ [("JP1", "1")])
  , Net "MULT_B" Signal ([ (jackRef k, "T") | k <- [4 .. 7] ] ++ [("JP1", "2")])
  ]
  -- TN (switch) pins are intentionally unconnected.

-- Copper ---------------------------------------------------------------------

busX :: Double
busX = 12.0

-- | Each group's tips share a vertical bus to the right of the pad column.
tipBus :: Text -> [Int] -> [Trace]
tipBus net ks =
  [ Trace net "F.Cu" 0.5 [tipPad k, (busX, snd (tipPad k))] | k <- ks ]
  ++ [ Trace net "F.Cu" 0.5 [(busX, snd (tipPad (head ks))), (busX, snd (tipPad (last ks)))] ]

-- | Jumper pads (rotation 0, back side) sit 0.65 mm left/right of the origin.
jumperLinks :: [Trace]
jumperLinks =
  let (jx, jy) = jumperAt
      (ax, ay) = tipPad 3          -- last tip of group A
      (bx, by) = tipPad 4          -- first tip of group B
  in [ Trace "MULT_A" "B.Cu" 0.4 [(jx - 0.65, jy), (6.5, jy), (6.5, ay), (ax, ay)]
     , Trace "MULT_B" "B.Cu" 0.4 [(jx + 0.65, jy), (busX, jy), (busX, by), (bx, by)]
     ]

fullBoard :: [(Double, Double)]
fullBoard = [(0, 0), (boardW, 0), (boardW, boardH), (0, boardH)]

board :: Board
board = Board
  { bdWidth = boardW
  , bdHeight = boardH
  , bdCornerRadius = 1.0
  , bdRules = defaultRules
  , bdTraces = tipBus "MULT_A" [0 .. 3] ++ tipBus "MULT_B" [4 .. 7] ++ jumperLinks
  , bdZones =
      [ Zone "GND" "F.Cu" "GND_front" fullBoard 0.3 0.25
      , Zone "GND" "B.Cu" "GND_back"  fullBoard 0.3 0.25
      ]
  , bdTexts =
      [ BoardText "MULT 2x4" "B.SilkS" (4.5, 60) 90 1.0
      , BoardText "LINK A-B" "B.SilkS" (14.6, 50) 90 0.8
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
  , modTitle = "MULT - passive 2x4 multiple"
  , modHP = hp
  , modParts = jacks ++ [jumper]
  , modNets = nets
  , modBoard = board
  , modNotes =
      [ "MULT - passive 2x4 multiple, 4HP"
      , "J1-J4 = group A, J5-J8 = group B."
      , "Bridge JP1 (back of PCB) to join both groups into one 1x8 multiple."
      , "Jack switch (TN) pins intentionally unconnected."
      ]
  }
