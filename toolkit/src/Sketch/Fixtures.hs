{-# LANGUAGE OverloadedStrings #-}
-- | Reference sketches, and the texts a reader must refuse. They are written
-- to @sketches/_fixtures/@ and, with their expected results, into
-- @sketcher/vectors.js@, so the browser is held to the Haskell rather than to
-- a second hand-typed table.
module Sketch.Fixtures
  ( fixtures
  , mixerSketch
  , emptySketch
  , invalidTexts
  ) where

import           Data.Text        (Text)
import qualified Data.Text        as T

import           Sketch.Catalogue
import           Sketch.Model

fixtures :: [(Text, Sketch)]
fixtures =
  [ ("mixer", mixerSketch)
  , ("empty", emptySketch)
  ]

cell :: Int -> Int -> Kind -> Text -> Cell
cell = Cell

-- | A four-in mixer sketched the way the tool is meant to be used: a column
-- of level knobs beside a column of inputs, the output and its indicator at
-- the bottom, and empty cells where nothing goes.
mixerSketch :: Sketch
mixerSketch = Sketch
  { sxName = "Mixer"
  , sxColumns = 3
  , sxRows = 6
  , sxCells =
      [ cell 0 0 Knob "CH1", cell 1 0 Jack "IN 1"
      , cell 0 1 Knob "CH2", cell 1 1 Jack "IN 2"
      , cell 0 2 Knob "CH3", cell 1 2 Jack "IN 3"
      , cell 0 3 Knob "CH4", cell 1 3 Jack "IN 4"
      , cell 0 5 Switch "AC/DC"
      , cell 1 5 Jack "OUT", cell 2 5 Led "CLIP"
      ]
  }

-- | The smallest thing the format can say.
emptySketch :: Sketch
emptySketch = Sketch
  { sxName = "Empty"
  , sxColumns = 1
  , sxRows = 1
  , sxCells = []
  }

-- | One broken thing each. Every reader must refuse all of them.
invalidTexts :: [(Text, Text)]
invalidTexts =
  [ ("wrong format", wrap "\"format\": \"pcbgen-sketch\", \"version\": 2, \"columns\": 2, \"rows\": 2, \"cells\": []")
  , ("wrong version", wrap "\"format\": \"module-sketch\", \"version\": 1, \"columns\": 2, \"rows\": 2, \"cells\": []")
  , ("missing columns", wrap "\"format\": \"module-sketch\", \"version\": 2, \"rows\": 2, \"cells\": []")
  , ("missing cells", valid "\"columns\": 2, \"rows\": 2")
  , ("zero columns", valid "\"columns\": 0, \"rows\": 2, \"cells\": []")
  , ("too many columns", valid "\"columns\": 7, \"rows\": 2, \"cells\": []")
  , ("too many rows", valid "\"columns\": 2, \"rows\": 7, \"cells\": []")
  , ("fractional columns", valid "\"columns\": 2.5, \"rows\": 2, \"cells\": []")
  , ("non-finite columns", wrap "\"format\": \"module-sketch\", \"version\": 2, \"columns\": 1e999, \"rows\": 2, \"cells\": []")
  , ("NaN literal", wrap "\"format\": \"module-sketch\", \"version\": 2, \"columns\": NaN, \"rows\": 2, \"cells\": []")
  , ("cell off the grid", valid ("\"columns\": 2, \"rows\": 2, \"cells\": [" <> at 2 0 "knob" <> "]"))
  , ("negative cell", valid ("\"columns\": 2, \"rows\": 2, \"cells\": [" <> at (-1) 0 "knob" <> "]"))
  , ("two components in one cell", valid ("\"columns\": 2, \"rows\": 2, \"cells\": [" <> at 0 0 "knob" <> ", " <> at 0 0 "jack" <> "]"))
  , ("unknown kind", valid ("\"columns\": 2, \"rows\": 2, \"cells\": [" <> at 0 0 "banana" <> "]"))
  , ("missing kind", valid "\"columns\": 2, \"rows\": 2, \"cells\": [{\"col\": 0, \"row\": 0}]")
  , ("unknown cell field", valid "\"columns\": 2, \"rows\": 2, \"cells\": [{\"col\": 0, \"row\": 0, \"kind\": \"knob\", \"lcsc\": \"C1\"}]")
  , ("unknown top-level field", valid "\"columns\": 2, \"rows\": 2, \"cells\": [], \"netlist\": []")
  , ("label too long", valid "\"columns\": 2, \"rows\": 2, \"cells\": [{\"col\": 0, \"row\": 0, \"kind\": \"knob\", \"label\": \"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"}]")
  , ("not an object", "[]")
  , ("truncated", "{\"format\": \"module-sketch\", \"version\": 2")
  , ("trailing comma", valid "\"columns\": 2, \"rows\": 2, \"cells\": [],")
  , ("duplicate key", valid "\"columns\": 2, \"columns\": 3, \"rows\": 2, \"cells\": []")
  , ("empty text", "")
  ]
  where
    wrap body = "{" <> body <> "}"
    valid rest = wrap ("\"format\": \"module-sketch\", \"version\": 2, " <> rest)
    at c r k = "{\"col\": " <> num c <> ", \"row\": " <> num r <> ", \"kind\": \"" <> k <> "\"}"
    num :: Int -> Text
    num = T.pack . show
