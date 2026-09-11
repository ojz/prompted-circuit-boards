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
  , pinchWide
  , crosstalk
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
      , bdAnalog = noAnalog
      }
  , modNotes = [ "Synthetic benchmark fixture: full permutation reversal." ]
  }

revNets :: [Net]
revNets =
  [ Net ("X" <> tshow k) Signal [("J1", tshow k), ("J2", tshow (21 - k))]
  | k <- [1 .. 20 :: Int] ]

-- pinch ------------------------------------------------------------------------

-- | One legal path, narrower than any router here can see.
--
-- A 3.2 mm hole sits in the middle of a 5.14 mm tall sliver. Below the hole
-- there is no room at all. Above it a corridor survives, but only about
-- 0.04 mm of it: a trace centre is legal between 4.45 mm and 4.49 mm from the
-- top, and nowhere else.
--
-- The band is real, and both routers miss it: ours because no grid cell centre
-- lands inside it and because it refuses cells within 0.8 mm of a board edge,
-- and Freerouting because it returns an empty session. So completeness is a
-- property neither router provides, which is the measurement.
--
-- Treat it as a theoretical probe, not a target. No board house holds 0.04 mm,
-- so a board that needed this corridor could not be manufactured anyway.
-- 'pinchWide' is the version that matters.
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
      , bdAnalog = noAnalog
      }
  , modNotes = [ "Synthetic benchmark fixture: sub-grid corridor." ]
  }

-- | The same board with 0.21 mm more height, which widens the only corridor
-- from about 0.04 mm to about 0.25 mm.
--
-- This is the useful half of the pair. A 0.04 mm corridor is a theoretical
-- probe: no fab holds that tolerance, so a board relying on it could not be
-- built anyway. A quarter of a millimetre is tight but ordinary, and a router
-- that misses it is losing real boards. Together the two bracket where
-- completeness actually breaks.
pinchWide :: Module
pinchWide = pinch
  { modName = "pinch-wide"
  , modOutDir = "modules/_bench/pinch-wide/kicad"
  , modTitle = "Bench: a corridor a router should find"
  , modBoard = (modBoard pinch) { bdHeight = 5.35 }
  , modNotes = [ "Synthetic benchmark fixture: 0.25 mm corridor." ]
  }

-- crosstalk ---------------------------------------------------------------------

-- | A quiet net and a noisy net whose shortest routes run side by side.
--
-- Both must cross a 40 mm board, and their pads sit 2 mm apart, so the
-- shortest routing runs them alongside each other for 32 mm. The solved
-- coupling for that is about 0.13 pF, which a 5 V gate edge turns into 85 mV
-- on a 1M node: eight times the 10 mV the design allows.
--
-- There is a way out, and it is the move a person would make. The board is
-- 18 mm tall and the pads are at 12 and 14 mm, so the quiet net can bow away
-- into the empty half of the board. Past about 3 mm of separation the
-- coupling stops mattering, and buying that costs a few millimetres of
-- copper and no vias at all.
--
-- The board is tall for a reason. At 6 mm, which is where this fixture
-- started, the via keepout around the four 0805 pads covered every cell on
-- the board, so no via could be placed anywhere and the back layer was
-- unreachable -- the fixture offered an escape that did not exist, and the
-- router was blamed for not taking it.
--
-- What it measures: whether the router will spend copper to keep a spec it
-- has been told about. A router that counts only copper and vias takes the
-- straight route every time and is right to, because nothing has told it
-- that the 0.13 pF matters.
crosstalk :: Module
crosstalk = Module
  { modName = "crosstalk"
  , modOutDir = "modules/_bench/crosstalk/kicad"
  , modTitle = "Bench: a quiet net and a noisy net in one channel"
  , modHP = 8
  , modParts =
      [ (part "R1" "0" rSym r0805 (4.0, 12.0) (50.8, 50.8)) { partNoConnect = ["1"] }
      , (part "R2" "0" rSym r0805 (36.0, 12.0) (101.6, 50.8)) { partNoConnect = ["2"] }
      , (part "R3" "0" rSym r0805 (4.0, 14.0) (50.8, 76.2)) { partNoConnect = ["1"] }
      , (part "R4" "0" rSym r0805 (36.0, 14.0) (101.6, 76.2)) { partNoConnect = ["2"] }
      ]
  , modNets =
      [ Net "QUIET" Signal [("R1", "2"), ("R2", "1")]
      , Net "NOISY" Signal [("R3", "2"), ("R4", "1")]
      ]
  , modBoard = Board
      { bdWidth = 40.0
      , bdHeight = 18.0
      , bdCornerRadius = 0.0
      , bdRules = defaultRules
      , bdTraces = []
      , bdAutoRoute = Just (autoRoute ["QUIET", "NOISY"])
      , bdZones = []
      , bdTexts = []
      , bdCustomRules = ""
      , bdAnalog = Analog
          { anRoles = [("QUIET", Quiet 1e6), ("NOISY", Noisy 5 1e-6)]
          , anMaxLength = []
          , anMatched = []
            -- 10 mV on a 5 V edge is -54 dB. Deliberately not stricter: the
            -- quiet net's pads sit 2 mm from the noisy net whatever the
            -- router does, and the stubs from those pads alone inject about
            -- 5.6 mV, so a 1 mV limit would be unreachable by any routing and
            -- the fixture would measure nothing. 10 mV is missed by 8x on the
            -- front layer and met on the back, which is the choice the
            -- fixture exists to put in front of the router.
          , anInjectMv = 10.0
          , anSameCircuit = []
          , anNodePf = 5
          }
      }
  , modNotes = [ "Synthetic benchmark fixture: quiet and noisy in one channel." ]
  }

-- Registry ---------------------------------------------------------------------

-- | Every synthetic fixture, in the order the report should list them.
benchFixtures :: [(String, Module)]
benchFixtures =
  [ ("reversal", reversal)
  , ("pinch", pinch)
  , ("pinch-wide", pinchWide)
  , ("crosstalk", crosstalk)
  ]

tshow :: Show a => a -> Text
tshow = T.pack . show
