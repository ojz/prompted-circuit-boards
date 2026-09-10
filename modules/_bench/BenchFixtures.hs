{-# LANGUAGE OverloadedStrings #-}
-- | Synthetic boards that exist only to be hard to route. Not modules, not
-- manufacturable, never emitted as KiCad projects: the benchmark builds their
-- routing problem in memory and throws the result away.
--
-- Each one isolates a single difficulty, so a score change points at a cause.
-- Real circuits (a Serge slope generator, a fixed filterbank) are a better
-- test of the objective than of the router and belong in a later phase.
module BenchFixtures
  ( reversal
  , pinch
  , benchFixtures
  ) where

import           Data.Text (Text)
import qualified Data.Text as T

import           Design

-- Library ids ------------------------------------------------------------------

hdrSym, hdrFp, rSym, r0805, holeSym, holeFp :: LibId
hdrSym  = LibId "Connector_Generic" "Conn_02x10_Odd_Even"
hdrFp   = LibId "Connector_PinHeader_2.54mm" "PinHeader_2x10_P2.54mm_Vertical"
rSym    = LibId "Device" "R"
r0805   = LibId "Resistor_SMD" "R_0805_2012Metric"
holeSym = LibId "Mechanical" "MountingHole"
holeFp  = LibId "MountingHole" "MountingHole_3.2mm_M3"

-- reversal ---------------------------------------------------------------------

-- | Maximum crossing. Two 2x10 headers face each other and pin @k@ on the left
-- must reach pin @21-k@ on the right, so every one of the 20 nets crosses every
-- other. One layer cannot do it; the router has to spend vias and negotiate.
--
-- What it measures: via count and how gracefully congestion resolves. The
-- ideal-length column is meaningless here by design, since no routing can be
-- anywhere near the spanning tree.
reversal :: Module
reversal = Module
  { modName = "reversal"
  , modOutDir = "modules/_bench/reversal/kicad"
  , modTitle = "Bench: 20 nets that all cross"
  , modHP = 8
  , modParts =
      [ part "J1" "LEFT"  hdrSym hdrFp (4.0, 2.5)  (50.8, 50.8)
      , part "J2" "RIGHT" hdrSym hdrFp (27.5, 2.5) (177.8, 50.8)
      ]
  , modNets = revNets
  , modBoard = Board
      { bdWidth = 34.0
      , bdHeight = 28.0
      , bdCornerRadius = 1.0
      , bdRules = defaultRules
      , bdTraces = []
      , bdAutoRoute = Just (autoRoute (map netName revNets))
      , bdZones = []
      , bdTexts = []
      , bdCustomRules = ""
      }
  , modNotes = [ "Synthetic benchmark fixture: full permutation reversal." ]
  }

revNets :: [Net]
revNets =
  [ Net ("X" <> tshow k) Signal [("J1", tshow k), ("J2", tshow (21 - k))]
  | k <- [1 .. 20 :: Int] ]

-- pinch ------------------------------------------------------------------------

-- | One legal path, narrower than the search grid can see.
--
-- A 3.2 mm hole sits in the middle of a 5.14 mm tall sliver. Below the hole
-- there is no room at all. Above it a corridor survives, but only about
-- 0.04 mm of it: a trace centre is legal between 4.45 mm and 4.49 mm from the
-- top, and nowhere else. That is a real path a continuous router can take and
-- a 0.2 mm grid cannot, both because no cell centre lands inside the band and
-- because the grid conservatively refuses cells within 0.8 mm of a board edge.
--
-- So this fixture is expected to FAIL on the grid router, and that failure is
-- the measurement: it is the completeness cost of discretising the board,
-- turned into a number. If a future router routes it, the cost went to zero.
pinch :: Module
pinch = Module
  { modName = "pinch"
  , modOutDir = "modules/_bench/pinch/kicad"
  , modTitle = "Bench: a corridor finer than the grid"
  , modHP = 4
  , modParts =
      [ (part "R1" "10k" rSym r0805 (3.0, 2.5) (50.8, 50.8)) { partNoConnect = ["1"] }
      , (part "R2" "10k" rSym r0805 (17.0, 2.5) (101.6, 50.8)) { partNoConnect = ["2"] }
      , (part "H1" "obstacle" holeSym holeFp (10.0, 2.5) (152.4, 50.8))
          { partAssembly = Mechanical }
      ]
  , modNets = [ Net "SIG" Signal [("R1", "2"), ("R2", "1")] ]
  , modBoard = Board
      { bdWidth = 20.0
      , bdHeight = 5.14
      , bdCornerRadius = 0.0
      , bdRules = defaultRules
      , bdTraces = []
      , bdAutoRoute = Just (autoRoute ["SIG"])
      , bdZones = []
      , bdTexts = []
      , bdCustomRules = ""
      }
  , modNotes = [ "Synthetic benchmark fixture: sub-grid corridor." ]
  }

-- Registry ---------------------------------------------------------------------

-- | Every synthetic fixture, in the order the report should list them.
benchFixtures :: [(String, Module)]
benchFixtures =
  [ ("reversal", reversal)
  , ("pinch", pinch)
  ]

tshow :: Show a => a -> Text
tshow = T.pack . show
