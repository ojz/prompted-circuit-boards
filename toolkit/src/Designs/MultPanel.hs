{-# LANGUAGE OverloadedStrings #-}
-- | Front panel for MULT as a PCB (aluminium or black FR4 from JLCPCB).
-- Geometry comes from "Designs.Mult" so the two can never disagree.
module Designs.MultPanel (multPanel) where

import           Data.Text (Text)
import qualified Data.Text as T

import           Design
import           Designs.Mult (colX, panelHeight, panelWidth, railHoleX, railHoleY, rowY, rows)

holeSym :: LibId
holeSym = LibId "Mechanical" "MountingHole"

-- | Thonkiconn barrel is M6; the official 6.4 mm M6 clearance hole fits it.
jackHoleFp, railHoleFp :: LibId
jackHoleFp = LibId "MountingHole" "MountingHole_6.4mm_M6"
railHoleFp = LibId "MountingHole" "MountingHole_3.2mm_M3"

-- | A hole with no reference printed on the panel face.
hole :: Text -> Text -> LibId -> (Double, Double) -> (Double, Double) -> Part
hole ref val fp at schAt = (part ref val holeSym fp at schAt) { partRefOnSilk = False }

jackHoles :: [Part]
jackHoles =
  [ hole ("H" <> T.pack (show n)) "Jack" jackHoleFp (colX col, rowY k) (sx, sy)
  | (n, (col, k)) <- zip [1 :: Int ..] [ (c, k) | c <- [0, 1], k <- rows ]
  , let sx = 50.8 + 25.4 * fromIntegral col
  , let sy = 38.1 + 12.7 * fromIntegral k
  ]

railHoles :: [Part]
railHoles =
  [ hole ("H" <> T.pack (show n)) "Rail" railHoleFp (x, y) (127.0 + 25.4 * fromIntegral i, 38.1 + 12.7 * fromIntegral j)
  | (n, (i, x, j, y)) <- zip [13 :: Int ..] [ (i, x, j, y) | (i, x) <- zip [0 :: Int ..] railHoleX, (j, y) <- zip [0 :: Int ..] railHoleY ]
  ]

legend :: [BoardText]
legend =
  [ BoardText "MULT" "F.SilkS" (panelWidth / 2, 16.0) 0 3.0
  , BoardText "A"    "F.SilkS" (colX 0, 23.0) 0 2.0
  , BoardText "B"    "F.SilkS" (colX 1, 23.0) 0 2.0
  , BoardText "2x6"  "F.SilkS" (panelWidth / 2, 110.0) 0 2.0
  ]

multPanel :: Module
multPanel = Module
  { modName = "panel"
  , modOutDir = "modules/mult/panel"
  , modTitle = "MULT front panel, 6HP"
  , modHP = 6
  , modParts = jackHoles ++ railHoles
  , modNets = []
  , modBoard = Board
      { bdWidth = panelWidth
      , bdHeight = panelHeight
      , bdCornerRadius = 1.0
      , bdRules = defaultRules
      , bdTraces = []
      , bdZones = []
      , bdTexts = legend
      , bdCustomRules = ""
      }
  , modNotes =
      [ "MULT front panel: 6HP Doepfer 3U, 30.0 x 128.5 mm, 2 mm aluminium PCB or 1.6 mm FR4."
      , "H1-H12: 6.4 mm holes for Thonkiconn jacks. H13-H16: 3.2 mm rail mounting holes."
      ]
  }
