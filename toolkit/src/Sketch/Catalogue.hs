{-# LANGUAGE OverloadedStrings #-}
-- | What can go in a cell, and how big the grid may be.
--
-- A sketch is conceptual: it says "a knob here, a jack there" and nothing
-- about part numbers. But how many cells there can be is not a matter of
-- taste, so it is derived here from the hardware the boards actually use and
-- the form factor in "Design": the answer is at most six columns and six
-- rows, and 'gridLimits' shows its working.
--
-- The dimensions come from KiCad 10's own footprints (the courtyard layer of
-- the @.kicad_mod@, read 2026-09-16) and from the hardware standard in
-- docs/MECHANICAL.md. They are here to bound the grid, not to describe a
-- part: choosing the actual component is the design's job, later.
module Sketch.Catalogue
  ( Kind (..)
  , kinds
  , kindId
  , kindLabel
  , lookupKind
  , Envelope (..)
  , envelopeOf
  , GridLimits (..)
  , gridLimits
  , maxColumns
  , maxRows
  , smallestWidthFor
  , gridPitch
  , jackStackMinimum
  ) where

import           Data.List (find)
import           Data.Text (Text)

import           Design    (eurorackPcbHeight, eurorackPcbTop, eurorackPanelWidths)

-- | What a cell can hold. Deliberately conceptual: a "knob" is any rotary
-- control, not the Alpha 9 mm pot that will probably realise it.
data Kind = Knob | Jack | Switch | Led
  deriving (Eq, Show, Enum, Bounded)

kinds :: [Kind]
kinds = [minBound .. maxBound]

-- | The word a sketch file uses.
kindId :: Kind -> Text
kindId Knob   = "knob"
kindId Jack   = "jack"
kindId Switch = "switch"
kindId Led    = "led"

-- | What it is, for a human reading the palette.
kindLabel :: Kind -> Text
kindLabel Knob   = "Knob"
kindLabel Jack   = "Jack"
kindLabel Switch = "Switch"
kindLabel Led    = "LED"

lookupKind :: Text -> Maybe Kind
lookupKind t = find ((== t) . kindId) kinds

-- | How much room the part behind a cell takes, in millimetres from the
-- control centre. Only used to bound the grid.
data Envelope = Envelope
  { envAbove  :: Double   -- ^ towards the top of the panel
  , envBelow  :: Double   -- ^ towards the bottom
  , envSide   :: Double   -- ^ either side
  , envSource :: Text
  } deriving (Show)

-- | Courtyards from the official footprints, relative to the hole centre.
-- The jack is the awkward one: its body hangs 12.98 mm below the barrel,
-- which is what limits how many rows fit.
envelopeOf :: Kind -> Envelope
envelopeOf Knob = Envelope 6.41 6.41 8.65
  "Potentiometer_Alpha_RD901F-40-00D_Single_Vertical courtyard, shaft at footprint (7.5, 2.5)"
envelopeOf Jack = Envelope 1.42 12.98 5.0
  "Jack_3.5mm_QingPu_WQP-PJ398SM_Vertical_CircularHoles courtyard, origin at the barrel"
envelopeOf Switch = Envelope 4.57 4.57 4.82
  "Dailywell 2M body 8.13 x 8.64 (9.14 for two poles) plus 0.25 mm, docs/MECHANICAL.md"
envelopeOf Led = Envelope 2.21 2.21 2.42
  "LED_D3.0mm courtyard, body centre at footprint (1.27, 0)"

-- | The spacing the grid is reckoned at. A candidate, not an approved pitch:
-- docs/MECHANICAL.md's fit gate still owns that question. It is used to
-- answer "how many columns fit", which is all the sketcher needs.
gridPitch :: Double
gridPitch = 15.0

-- | Two Thonkiconns stacked in a column: one jack's tip pad against the
-- next jack's sleeve pad at the 0.2 mm clearance is 13.6 mm. Any row
-- spacing below this cannot hold jacks, which is what rules out a tall grid.
jackStackMinimum :: Double
jackStackMinimum = 13.6

-- | The derivation, kept as data so a report can print it rather than
-- restate the numbers.
data GridLimits = GridLimits
  { glMaxColumns   :: Int
  , glMaxRows      :: Int
  , glPitch        :: Double
  , glBand         :: Double            -- ^ vertical travel available to centres
  , glFirstRowY    :: Double            -- ^ panel y of the topmost centre
  , glRowPitchAt   :: Int -> Double     -- ^ the spacing a given row count forces
  , glWidthFor     :: Int -> Maybe Int  -- ^ smallest HP that holds n columns
  }

gridLimits :: GridLimits
gridLimits = GridLimits
  { glMaxColumns = maxColumns
  , glMaxRows = maxRows
  , glPitch = gridPitch
  , glBand = band
  , glFirstRowY = firstRow
  , glRowPitchAt = rowPitchAt
  , glWidthFor = smallestWidthFor
  }

-- The vertical band a control centre may sit in: inside the PCB, with room
-- for the tallest thing above a centre and the deepest thing below one.
firstRow, lastRow, band :: Double
firstRow = eurorackPcbTop + maximum [ envAbove (envelopeOf k) | k <- kinds ]
lastRow  = eurorackPcbTop + eurorackPcbHeight - maximum [ envBelow (envelopeOf k) | k <- kinds ]
band     = lastRow - firstRow

-- | The spacing @n@ rows forces. Fewer rows, more room between them.
rowPitchAt :: Int -> Double
rowPitchAt n | n <= 1 = band
             | otherwise = band / fromIntegral (n - 1)

-- | The tallest grid whose rows are still far enough apart for two jacks.
-- Six: seven rows would put them 13.44 mm apart, under the 13.6 mm the
-- footprint needs.
maxRows :: Int
maxRows = last (1 : [ n | n <- [2 .. 12], rowPitchAt n >= jackStackMinimum ])

-- | Columns are bounded by the widest panel the module policy allows, 20 HP.
-- Six.
maxColumns :: Int
maxColumns = maximum (1 : [ n | (hp, _) <- eurorackPanelWidths, hp <= 20, Just n <- [columnsAt hp] ])

-- | How many columns a panel of the given width holds at 'gridPitch', with
-- room at each edge for the widest part and the 1 mm the board sits inside
-- the panel.
columnsAt :: Int -> Maybe Int
columnsAt hp = do
  w <- lookup hp eurorackPanelWidths
  let margin = maximum [ envSide (envelopeOf k) | k <- kinds ] + 1.0
      usable = w - 2 * margin
  pure (if usable < 0 then 0 else floor (usable / gridPitch) + 1)

-- | The narrowest panel in the 4 to 20 HP policy that holds @n@ columns.
-- This is what a sketch's column count implies about the real module, and
-- the only place the sketcher mentions HP at all.
smallestWidthFor :: Int -> Maybe Int
smallestWidthFor n =
  case [ hp | (hp, _) <- eurorackPanelWidths, hp >= 4, hp <= 20, columnsAt hp >= Just n ] of
    (hp : _) -> Just hp
    []       -> Nothing
