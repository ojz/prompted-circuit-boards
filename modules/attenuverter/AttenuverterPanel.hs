{-# LANGUAGE OverloadedStrings #-}
-- | Front panel for UTIL-01 ATTENUVERTER as a PCB. Geometry comes from
-- "Attenuverter" so the two can never disagree; the panel outline, hole
-- library and rail holes come from the shared skeleton ("Block.Eurorack").
module AttenuverterPanel (attenuverterPanel) where

import           Block.Eurorack
import           Design
import           Attenuverter (jackPanelAt, potPanelAt, sk)

holes :: [Part]
holes =
  [ hole "H1" "Jack IN 1"  jackHoleFp (jackPanelAt 1 False) (50.8, 38.1)
  , hole "H2" "Jack OUT 1" jackHoleFp (jackPanelAt 1 True)  (76.2, 38.1)
  , hole "H3" "Jack IN 2"  jackHoleFp (jackPanelAt 2 False) (50.8, 50.8)
  , hole "H4" "Jack OUT 2" jackHoleFp (jackPanelAt 2 True)  (76.2, 50.8)
  , hole "H5" "Pot 1"      potHoleFp  (potPanelAt 1)        (50.8, 63.5)
  , hole "H6" "Pot 2"      potHoleFp  (potPanelAt 2)        (76.2, 63.5)
  ]
  ++ railHoles sk 7

legend :: [BoardText]
legend =
  [ BoardText "ATTENUVERTER" "F.SilkS" (panelWidth / 2, 10.0) 0 1.8
  , BoardText "1"   "F.SilkS" (panelWidth / 2, 31.5) 0 2.0
  , BoardText "IN"  "F.SilkS" (fst (jackPanelAt 1 False), 45.0) 0 1.5
  , BoardText "OUT" "F.SilkS" (fst (jackPanelAt 1 True), 45.0) 0 1.5
  , BoardText "2"   "F.SilkS" (panelWidth / 2, 73.5) 0 2.0
  , BoardText "IN"  "F.SilkS" (fst (jackPanelAt 2 False), 87.0) 0 1.5
  , BoardText "OUT" "F.SilkS" (fst (jackPanelAt 2 True), 87.0) 0 1.5
  , BoardText "-  0  +" "F.SilkS" (panelWidth / 2, 100.0) 0 1.5
  ]
  where panelWidth = skPanelWidth sk

attenuverterPanel :: Module
attenuverterPanel = Module
  { modName = "panel"
  , modOutDir = "modules/attenuverter/kicad/panel"
  , modTitle = "UTIL-01 ATTENUVERTER front panel, 6HP"
  , modHP = skHP sk
  , modParts = holes
  , modNets = []
  , modBoard = panelBoard sk legend
  , modNotes =
      [ "UTIL-01 ATTENUVERTER front panel: 6HP Doepfer 3U, 30.0 x 128.5 mm."
      , "H1-H4: 6.4 mm holes for Thonkiconn jacks. H5-H6: 7.2 mm holes for Alpha 9 mm pots."
      , "H7-H10: 3.2 mm rail mounting holes."
      ]
  }
