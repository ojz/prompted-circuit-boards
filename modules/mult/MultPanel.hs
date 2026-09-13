{-# LANGUAGE OverloadedStrings #-}
-- | Front panel for MULT as a PCB (aluminium or black FR4 from JLCPCB).
-- Geometry comes from "Mult" so the two can never disagree; the panel
-- outline, hole library and rail holes come from the shared skeleton
-- ("Block.Eurorack").
module MultPanel (multPanel) where

import qualified Data.Text as T

import           Block.Eurorack
import           Design
import           Mult (colX, rowY, rows, sk)

jackHoles :: [Part]
jackHoles =
  [ hole ("H" <> T.pack (show n)) "Jack" jackHoleFp (colX col, rowY k) (sx, sy)
  | (n, (col, k)) <- zip [1 :: Int ..] [ (c, k) | c <- [0, 1], k <- rows ]
  , let sx = 50.8 + 25.4 * fromIntegral col
  , let sy = 38.1 + 12.7 * fromIntegral k
  ]

legend :: [BoardText]
legend =
  [ BoardText "MULT" "F.SilkS" (panelWidth / 2, 16.0) 0 3.0
  , BoardText "A"    "F.SilkS" (colX 0, 23.0) 0 2.0
  , BoardText "B"    "F.SilkS" (colX 1, 23.0) 0 2.0
  , BoardText "2x6"  "F.SilkS" (panelWidth / 2, 110.0) 0 2.0
  ]
  where panelWidth = skPanelWidth sk

multPanel :: Module
multPanel = Module
  { modName = "panel"
  , modOutDir = "modules/mult/kicad/panel"
  , modTitle = "MULT front panel, 6HP"
  , modHP = skHP sk
  , modParts = jackHoles ++ railHoles sk 13
  , modNets = []
  , modBoard = panelBoard sk legend
  , modNotes =
      [ "MULT front panel: 6HP Doepfer 3U, 30.0 x 128.5 mm, 2 mm aluminium PCB or 1.6 mm FR4."
      , "H1-H12: 6.4 mm holes for Thonkiconn jacks. H13-H16: 3.2 mm rail mounting holes."
      ]
  }
