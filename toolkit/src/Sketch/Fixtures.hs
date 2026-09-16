{-# LANGUAGE OverloadedStrings #-}
-- | Sketch fixtures: the sparse mixed-control sketch the roadmap's S1 gate
-- names, a deliberately broken one that exercises every conflict kind, and
-- the invalid texts every reader must refuse. They are written to
-- @sketches/_fixtures/@ as the reference files and, with their expected
-- placements and findings, into @sketcher/vectors.js@ for the browser's
-- tests, so the JavaScript reimplementation of the geometry is held to the
-- Haskell numbers rather than to a second hand-typed table.
module Sketch.Fixtures
  ( fixtures
  , sparseMixed
  , conflicts
  , emptyFour
  , invalidTexts
  ) where

import           Data.Text (Text)

import           Sketch.Catalogue (GridProfile (..), defaultGridOrigin, lookupProfile)
import           Sketch.Model

-- | Named valid fixtures.
fixtures :: [(Text, Sketch)]
fixtures =
  [ ("sparse-mixed", sparseMixed)
  , ("conflicts", conflicts)
  , ("empty-4hp", emptyFour)
  ]

candidate15 :: GridProfile
candidate15 = maybe (error "candidate-15 profile missing") id (lookupProfile "candidate-15")

gridFor :: Int -> Grid
gridFor hp = Grid { grOrigin = defaultGridOrigin hp candidate15, grPitch = gpPitch candidate15, grProfile = gpId candidate15 }

control :: Text -> Text -> (Int, Int) -> Control
control cid hw cell = Control
  { ctId = cid, ctHardware = hw, ctCell = cell, ctSpan = (1, 1), ctOffset = (0, 0)
  , ctRotation = 0, ctLabel = "", ctGroup = Nothing }

-- | One channel of an imaginary 8HP module on the 15 mm candidate grid: a
-- level pot with its pins downward as on the attenuverter, an input and an
-- output jack, the output's indicator LED sitting diagonally inside the
-- output jack's cell, a maintained CYCLE switch and a wide FREQ knob that
-- reserves two columns. Row 2 and several other cells are intentionally
-- empty. It must check clean: notes only, no conflicts and no warnings.
sparseMixed :: Sketch
sparseMixed = Sketch
  { sxName = "Sparse mixed fixture"
  , sxStatus = Provisional
  , sxHP = 8
  , sxGrid = gridFor 8
  , sxControls =
      [ (control "level" "pot-9mm" (0, 0)) { ctRotation = 90, ctLabel = "LEVEL", ctGroup = Just "ch1" }
      , (control "in" "jack-ts" (0, 1)) { ctLabel = "IN", ctGroup = Just "ch1" }
      , (control "out" "jack-ts" (1, 1)) { ctLabel = "OUT", ctGroup = Just "ch1" }
      , (control "out-led" "led-3mm" (1, 1)) { ctOffset = (6, -6), ctGroup = Just "ch1" }
      , (control "cycle" "toggle-spdt" (1, 3)) { ctLabel = "CYCLE" }
      , (control "freq" "pot-9mm" (0, 5)) { ctSpan = (2, 1), ctLabel = "FREQ" }
      ]
  , sxGroups = [ Group "ch1" "Channel 1" ]
  , sxNotes = [ "Fixture for the S1 gate: sparse placement, a multi-cell control and an indicator inside a jack's cell." ]
  }

-- | Every conflict kind at least once on a 6HP panel. The expected findings
-- are asserted in the test suite and exported for the browser.
conflicts :: Sketch
conflicts = Sketch
  { sxName = "Conflicts fixture"
  , sxStatus = Provisional
  , sxHP = 6
  , sxGrid = gridFor 6
  , sxControls =
      [ control "a" "jack-ts" (0, 0)                               -- a and b: same cell, front and back overlap
      , control "b" "jack-ts" (0, 0)
      , control "low" "jack-ts" (0, 6)                             -- body below the PCB zone
      , (control "far" "pot-9mm" (2, 1))                           -- a third column on a two-column panel
      , (control "shift" "led-3mm" (1, 1)) { ctOffset = (0, 8) }   -- offset beyond half a pitch
      , (control "p1" "pot-9mm" (0, 3)) { ctRotation = 90 }        -- finger room only: a warning
      , (control "p2" "pot-9mm" (1, 3)) { ctRotation = 90 }
      , control "top" "toggle-spdt" (0, -1)                        -- on the rail screw and out of the zone
      ]
  , sxGroups = []
  , sxNotes = [ "Fixture: every conflict kind at least once. Nothing here is a design." ]
  }

-- | The smallest policy width with nothing on it: a valid sketch.
emptyFour :: Sketch
emptyFour = Sketch
  { sxName = "Empty 4HP"
  , sxStatus = Provisional
  , sxHP = 4
  , sxGrid = gridFor 4
  , sxControls = []
  , sxGroups = []
  , sxNotes = []
  }

-- | Texts every reader must refuse, with the reason. Each starts from a
-- valid sketch and breaks one thing.
invalidTexts :: [(Text, Text)]
invalidTexts =
  [ ("wrong version", wrap "\"format\": \"pcbgen-sketch\", \"version\": 2, \"hp\": 6, \"grid\": " <> grid <> ", \"controls\": []")
  , ("wrong format", wrap "\"format\": \"kicad\", \"version\": 1, \"hp\": 6, \"grid\": " <> grid <> ", \"controls\": []")
  , ("missing hp", wrap "\"format\": \"pcbgen-sketch\", \"version\": 1, \"grid\": " <> grid <> ", \"controls\": []")
  , ("hp not a panel width", valid "\"hp\": 0, \"controls\": []")
  , ("duplicate control id", valid ("\"hp\": 6, \"controls\": [" <> jack "in" "0, \"row\": 0" <> ", " <> jack "in" "1, \"row\": 0" <> "]"))
  , ("id with a space", valid ("\"hp\": 6, \"controls\": [" <> jack "in put" "0, \"row\": 0" <> "]"))
  , ("unknown hardware", valid "\"hp\": 6, \"controls\": [{\"id\": \"x\", \"hardware\": \"banana\", \"cell\": {\"col\": 0, \"row\": 0}}]")
  , ("non-finite coordinate", wrap "\"format\": \"pcbgen-sketch\", \"version\": 1, \"hp\": 6, \"grid\": {\"origin\": {\"x\": 1e999, \"y\": 20}, \"pitch\": {\"x\": 15, \"y\": 15}}, \"controls\": []")
  , ("NaN literal", wrap "\"format\": \"pcbgen-sketch\", \"version\": 1, \"hp\": 6, \"grid\": {\"origin\": {\"x\": NaN, \"y\": 20}, \"pitch\": {\"x\": 15, \"y\": 15}}, \"controls\": []")
  , ("zero pitch", wrap "\"format\": \"pcbgen-sketch\", \"version\": 1, \"hp\": 6, \"grid\": {\"origin\": {\"x\": 7.5, \"y\": 20}, \"pitch\": {\"x\": 0, \"y\": 15}}, \"controls\": []")
  , ("negative pitch", wrap "\"format\": \"pcbgen-sketch\", \"version\": 1, \"hp\": 6, \"grid\": {\"origin\": {\"x\": 7.5, \"y\": 20}, \"pitch\": {\"x\": 15, \"y\": -15}}, \"controls\": []")
  , ("zero span", valid "\"hp\": 6, \"controls\": [{\"id\": \"x\", \"hardware\": \"pot-9mm\", \"cell\": {\"col\": 0, \"row\": 0}, \"span\": {\"cols\": 0, \"rows\": 1}}]")
  , ("fractional cell", valid "\"hp\": 6, \"controls\": [{\"id\": \"x\", \"hardware\": \"pot-9mm\", \"cell\": {\"col\": 0.5, \"row\": 0}}]")
  , ("rotation not allowed", valid "\"hp\": 6, \"controls\": [{\"id\": \"x\", \"hardware\": \"pot-9mm\", \"cell\": {\"col\": 0, \"row\": 0}, \"rotation\": 45}]")
  , ("unknown top-level field", valid "\"hp\": 6, \"controls\": [], \"netlist\": []")
  , ("unknown control field", valid "\"hp\": 6, \"controls\": [{\"id\": \"x\", \"hardware\": \"pot-9mm\", \"cell\": {\"col\": 0, \"row\": 0}, \"lcsc\": \"C1\"}]")
  , ("offset with an extra axis", valid "\"hp\": 6, \"controls\": [{\"id\": \"x\", \"hardware\": \"pot-9mm\", \"cell\": {\"col\": 0, \"row\": 0}, \"offset\": {\"x\": 0, \"y\": 0, \"z\": 1}}]")
  , ("group not declared", valid "\"hp\": 6, \"controls\": [{\"id\": \"x\", \"hardware\": \"pot-9mm\", \"cell\": {\"col\": 0, \"row\": 0}, \"group\": \"ch9\"}]")
  , ("status invented", valid "\"hp\": 6, \"status\": \"manufacturing-ready\", \"controls\": []")
  , ("not an object", "[]")
  , ("truncated text", "{\"format\": \"pcbgen-sketch\", \"version\": 1, \"hp\": 6")
  , ("trailing comma", valid "\"hp\": 6, \"controls\": [],")
  , ("duplicate key", valid "\"hp\": 6, \"hp\": 8, \"controls\": []")
  , ("empty text", "")
  ]
  where
    grid = "{\"origin\": {\"x\": 7.5, \"y\": 20}, \"pitch\": {\"x\": 15, \"y\": 15}}"
    wrap body = "{" <> body <> "}"
    valid rest = wrap ("\"format\": \"pcbgen-sketch\", \"version\": 1, \"grid\": " <> grid <> ", " <> rest)
    jack cid cell = "{\"id\": \"" <> cid <> "\", \"hardware\": \"jack-ts\", \"cell\": {\"col\": " <> cell <> "}}"
