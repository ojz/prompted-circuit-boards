{-# LANGUAGE OverloadedStrings #-}
-- | Synthetic router stress test, not a module. Two 2x8 headers face each
-- other across a field of resistors; header pins are cross-wired so the nets
-- must cross, which is impossible on one layer and forces vias and
-- negotiation. Output goes to modules/_tests/route-test.
module RouteTest (routeTest) where

import           Data.Text (Text)
import qualified Data.Text as T

import           Design

boardW, boardH :: Double
boardW = 40.0
boardH = 32.0

headerSym, headerFp, resSym, resFp :: LibId
headerSym = LibId "Connector_Generic" "Conn_02x08_Odd_Even"
headerFp  = LibId "Connector_PinHeader_2.54mm" "PinHeader_2x08_P2.54mm_Vertical"
resSym    = LibId "Device" "R"
resFp     = LibId "Resistor_SMD" "R_0805_2012Metric"

-- | Left header J1 and right header J2, pin 1 at the top. Footprint origin is
-- pin 1; the 2x8 header runs 17.78 mm downward and 2.54 mm to the right.
headers :: [Part]
headers =
  [ part "J1" "LEFT"  headerSym headerFp (4.0, 7.0)  (50.8, 63.5)
  , part "J2" "RIGHT" headerSym headerFp (33.5, 7.0) (152.4, 63.5)
  ]

-- | Six resistors standing in the routing channel, three on each side.
resistors :: [Part]
resistors =
  -- 17.78 mm apart on the sheet: a vertical R is 7.62 mm pin to pin and each
  -- pin gets a 2.54 mm stub, so 12.7 mm would make neighbouring stubs touch.
  [ (part ("R" <> T.pack (show n)) "10k" resSym resFp (x, y) (101.6, 30.48 + 17.78 * fromIntegral n)) { partRot = 90, partSide = side }
  | (n, (x, y, side)) <- zip [1 :: Int ..]
      [ (14.0, 9.0, Front), (14.0, 16.0, Front), (14.0, 23.0, Front)
      , (24.0, 9.0, Back),  (24.0, 16.0, Back),  (24.0, 23.0, Back) ]
  ]

-- | Cross-wire: J1 pin k to J2 pin 17-k. Odd pins are the left column of a
-- 2x8 header, even pins the right column, so this mixes columns too.
crossNets :: [Net]
crossNets =
  [ Net ("X" <> T.pack (show k)) Signal [("J1", T.pack (show k)), ("J2", T.pack (show (17 - k)))]
  | k <- [1 .. 12 :: Int] ]

-- | Resistor chains hanging off the remaining header pins.
resNets :: [Net]
resNets =
  [ Net "RA" Signal [("J1", "13"), ("R1", "1")]
  , Net "RB" Signal [("R1", "2"), ("R2", "1")]
  , Net "RC" Signal [("R2", "2"), ("R3", "1")]
  , Net "RD" Signal [("R3", "2"), ("J2", "4")]
  , Net "RE" Signal [("J1", "14"), ("R4", "1")]
  , Net "RF" Signal [("R4", "2"), ("R5", "1")]
  , Net "RG" Signal [("R5", "2"), ("R6", "1")]
  , Net "RH" Signal [("R6", "2"), ("J2", "3")]
  , Net "GND" Power [("J1", "15"), ("J1", "16"), ("J2", "1"), ("J2", "2")]
  ]

nets :: [Net]
nets = crossNets ++ resNets

routeTest :: Module
routeTest = Module
  { modName = "route-test"
  , modOutDir = "modules/_tests/route-test/kicad"
  , modTitle = "Router stress test (not a module)"
  , modHP = 8
  , modParts = headers ++ resistors
  , modNets = nets
  , modBoard = Board
      { bdWidth = boardW
      , bdHeight = boardH
      , bdCornerRadius = 1.0
      , bdRules = defaultRules
      , bdTraces = []
      , bdAutoRoute = Just (autoRoute (map netName nets))
      , bdZones = []
      , bdTexts = [ BoardText "ROUTE TEST" "F.SilkS" (boardW / 2, 2.0) 0 1.0 ]
      , bdCustomRules = ""
      , bdAnalog = noAnalog
      }
  , modNotes =
      [ "Synthetic autorouter test. 12 crossing nets between two 2x8 headers,"
      , "two resistor chains as obstacles, GND routed as copper (no pour)."
      ]
  }

_t :: Text
_t = ""
