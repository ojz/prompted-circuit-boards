{-# LANGUAGE OverloadedStrings #-}
-- | The panel hardware a sketch may place, with the geometry the sketcher's
-- checks need: hole, what stands in front of the panel, what stands behind
-- it, and where the footprint's origin is relative to the control centre.
--
-- One record per role, as docs/MECHANICAL.md's hardware standard wants, and
-- every dimension carries where it came from. Courtyards and anchors were
-- read from KiCad 10's official footprint files on 2026-09-16 (the fab and
-- courtyard layers of the @.kicad_mod@); the front envelopes are the
-- provisional numbers the mechanical document says still need a mockup, and
-- they are marked 'Unverified' so a sketch can never claim fit from them.
--
-- This is data about the panel side of a part. It knows nothing about
-- circuits, nets or assembly: a sketch places a jack, a design decides what
-- the jack is wired to.
module Sketch.Catalogue
  ( Evidence (..)
  , Shape (..)
  , Box (..)
  , Hardware (..)
  , GridProfile (..)
  , catalogue
  , lookupHardware
  , gridProfiles
  , lookupProfile
  , defaultGridOrigin
  , roundMm
  , columnsFor
  , rowsFor
  , railKeepoutRadius
  , minCentreEdgeDistance
  , boxRotate
  , boxTranslate
  , shapeRotate
  ) where

import           Data.Text (Text)

import           Design         (LibId (..), eurorackPanelWidth, eurorackPcbHeight, eurorackPcbTop)
import           Block.Eurorack (alphaPotFp, thonkiconnFp)

-- | How far a number can be trusted. 'InUse' dimensions come from a footprint
-- or drawing that a generated board already relies on; 'Proposed' ones from
-- a datasheet or drawing for a part not yet designed in; 'Unverified' ones
-- are estimates awaiting a mockup or a sample. An 'Unverified' envelope may
-- drive a warning but never a fit claim.
data Evidence = InUse | Proposed | Unverified
  deriving (Eq, Show)

-- | An envelope centred on the control centre, at rotation 0. Diameters and
-- widths in millimetres; a 'Rect' is width along x and height along y.
data Shape = Circle Double | Rect Double Double
  deriving (Eq, Show)

-- | An axis-aligned rectangle relative to the control centre at rotation 0,
-- panel frame (x right, y down). Courtyards are not centred on the shaft or
-- barrel, which is exactly why they are boxes rather than shapes.
data Box = Box { bxX1, bxY1, bxX2, bxY2 :: Double }
  deriving (Eq, Show)

data Hardware = Hardware
  { hwId            :: Text          -- ^ stable identifier used in sketches
  , hwName          :: Text
  , hwRole          :: Text          -- ^ jack, pot, switch, led
  , hwHoleDiameter  :: Double        -- ^ the panel hole, mm
  , hwFrontBody     :: Shape         -- ^ hard envelope in front of the panel: nut, knob base, bushing
  , hwFrontAccess   :: Maybe Shape   -- ^ soft envelope: fingers, plugged cable, bat swing
  , hwCourtyard     :: Box           -- ^ footprint courtyard behind the panel, relative to the centre
  , hwFootprint     :: Maybe LibId   -- ^ Nothing while the footprint still has to be drawn
  , hwAnchor        :: (Double, Double) -- ^ the control centre in footprint-local coordinates
  , hwRotations     :: [Int]         -- ^ rotations a sketch may ask for, degrees
  , hwReservesCell  :: Bool          -- ^ False for an indicator that shares its jack's cell
  , hwDefaultRotation :: Int        -- ^ what the sketcher places by default (a pot pins-down, as the attenuverter has it)
  , hwHeight        :: Double        -- ^ body height above the PCB top, mm
  , hwStatus        :: Evidence      -- ^ the part as a whole
  , hwFrontEvidence :: Evidence      -- ^ the front envelopes specifically
  , hwSource        :: Text          -- ^ where the numbers come from
  , hwNotes         :: Text
  } deriving (Show)

quarterTurns :: [Int]
quarterTurns = [0, 90, 180, 270]

-- | The catalogue. Order is the palette order in the sketcher.
catalogue :: [Hardware]
catalogue =
  [ Hardware
      { hwId = "jack-ts"
      , hwName = "3.5 mm TS jack, switched (Thonkiconn, QingPu WQP-WQP518MA)"
      , hwRole = "jack"
      , hwHoleDiameter = 6.4
      , hwFrontBody = Circle 8.0
      , hwFrontAccess = Just (Circle 10.0)
        -- Jack_3.5mm_QingPu_WQP-PJ398SM_Vertical_CircularHoles: origin at the
        -- sleeve pad under the barrel, body towards +y, courtyard x ±5.0,
        -- y -1.42 .. 12.98.
      , hwCourtyard = Box (-5.0) (-1.42) 5.0 12.98
      , hwFootprint = Just thonkiconnFp
      , hwAnchor = (0, 0)
      , hwRotations = quarterTurns
      , hwReservesCell = True
      , hwDefaultRotation = 0
      , hwHeight = 9.0
      , hwStatus = InUse
      , hwFrontEvidence = Unverified
      , hwSource = "KiCad 10 Connector_Audio footprint (courtyard, anchor); docs/MECHANICAL.md hardware standard (hole, height)"
      , hwNotes = "Front envelopes are estimates: an M6 knurled nut of about 8 mm and a plug barrel of about 10 mm. Nuts and washers are ordered separately."
      }
  , Hardware
      { hwId = "jack-trs"
      , hwName = "3.5 mm TRS jack, unswitched (Stereo Thonkiconn, QingPu WQP-WQP419GR)"
      , hwRole = "jack"
      , hwHoleDiameter = 6.4
      , hwFrontBody = Circle 8.0
      , hwFrontAccess = Just (Circle 10.0)
        -- The unmerged upstream footprint is the mono one 0.5 mm wider each side.
      , hwCourtyard = Box (-5.5) (-1.42) 5.5 12.98
      , hwFootprint = Nothing
      , hwAnchor = (0, 0)
      , hwRotations = quarterTurns
      , hwReservesCell = True
      , hwDefaultRotation = 0
      , hwHeight = 10.0
      , hwStatus = Proposed
      , hwFrontEvidence = Unverified
      , hwSource = "docs/MECHANICAL.md hardware standard; kicad-footprints PR 823 (never merged) for the 0.5 mm wider courtyard"
      , hwNotes = "No switch contact. Body height 9 to 10 mm is unverified; at 10 mm it touches the panel. Footprint still to be added to lib/footprints/pcbgen.pretty."
      }
  , Hardware
      { hwId = "pot-9mm"
      , hwName = "9 mm pot, Alpha RD901F-40 with a Davies 1900h-class knob"
      , hwRole = "pot"
      , hwHoleDiameter = 7.2
      , hwFrontBody = Circle 12.0
      , hwFrontAccess = Just (Circle 18.0)
        -- Potentiometer_Alpha_RD901F-40-00D_Single_Vertical: origin pin 1,
        -- shaft at (7.5, 2.5); courtyard x -1.15 .. 12.6, y -3.91 .. 8.91 in
        -- footprint coordinates, so relative to the shaft x -8.65 .. 5.1,
        -- y -6.41 .. 6.41.
      , hwCourtyard = Box (-8.65) (-6.41) 5.1 6.41
      , hwFootprint = Just alphaPotFp
      , hwAnchor = (7.5, 2.5)
      , hwRotations = quarterTurns
      , hwReservesCell = True
      , hwDefaultRotation = 90
      , hwHeight = 10.0
      , hwStatus = InUse
      , hwFrontEvidence = Unverified
      , hwSource = "KiCad 10 Potentiometer_THT footprint (courtyard, anchor); docs/MECHANICAL.md (hole, stack); Thonk knob page (12 mm base)"
      , hwNotes = "The 18 mm access circle is a finger estimate for the ergonomic mockup, not a measurement. The pot sets the panel height."
      }
  , Hardware
      { hwId = "toggle-spdt"
      , hwName = "Sub-mini toggle SPDT on-off-on (Dailywell 2MS3T1B1M2QES)"
      , hwRole = "switch"
      , hwHoleDiameter = 5.0
      , hwFrontBody = Circle 8.0
      , hwFrontAccess = Just (Rect 10.0 20.0)
        -- Body 8.13 across the pins by 8.64 along the throw, plus 0.25 mm of
        -- courtyard; the three pins are on 2.54 mm along y at rotation 0.
      , hwCourtyard = Box (-4.315) (-4.57) 4.315 4.57
      , hwFootprint = Nothing
      , hwAnchor = (0, 0)
      , hwRotations = quarterTurns
      , hwReservesCell = True
      , hwDefaultRotation = 0
      , hwHeight = 9.84
      , hwStatus = Proposed
      , hwFrontEvidence = Unverified
      , hwSource = "docs/MECHANICAL.md hardware standard (Dailywell 2M datasheet callouts)"
      , hwNotes = "Throw is along y at rotation 0. The access rectangle allows for the 9.4 mm bat swinging plus a fingertip. Footprint still to be drawn."
      }
  , Hardware
      { hwId = "toggle-dpdt"
      , hwName = "Sub-mini toggle DPDT on-off-on (Dailywell 2MD3T1B1M2QES)"
      , hwRole = "switch"
      , hwHoleDiameter = 5.0
      , hwFrontBody = Circle 8.0
      , hwFrontAccess = Just (Rect 10.0 20.0)
      , hwCourtyard = Box (-4.82) (-4.57) 4.82 4.57
      , hwFootprint = Nothing
      , hwAnchor = (0, 0)
      , hwRotations = quarterTurns
      , hwReservesCell = True
      , hwDefaultRotation = 0
      , hwHeight = 9.84
      , hwStatus = Proposed
      , hwFrontEvidence = Unverified
      , hwSource = "docs/MECHANICAL.md hardware standard (9.14 mm body for two poles)"
      , hwNotes = "The 4.06 mm row spacing of the two pole rows must be checked on the drawing before the footprint is drawn."
      }
  , Hardware
      { hwId = "led-3mm"
      , hwName = "3 mm indicator LED, bare in the panel hole"
      , hwRole = "led"
      , hwHoleDiameter = 3.2
      , hwFrontBody = Circle 3.2
      , hwFrontAccess = Nothing
        -- LED_D3.0mm: origin pin 1, body centre at (1.27, 0); courtyard
        -- x -1.15 .. 3.69, y ±2.21, so relative to the body x ±2.42.
      , hwCourtyard = Box (-2.42) (-2.21) 2.42 2.21
      , hwFootprint = Just (LibId "LED_THT" "LED_D3.0mm")
      , hwAnchor = (1.27, 0)
      , hwRotations = quarterTurns
      , hwReservesCell = False
      , hwDefaultRotation = 0
      , hwHeight = 8.0
      , hwStatus = Proposed
      , hwFrontEvidence = Proposed
      , hwSource = "KiCad 10 LED_THT footprint (courtyard, anchor); docs/MECHANICAL.md (leads hold the body 7 to 9 mm off the board)"
      , hwNotes = "Meant to sit diagonally off the jack it reports, inside that jack's cell; the offset is what the sketcher's checks decide. A bipolar red/green part has the same geometry."
      }
  ]

lookupHardware :: Text -> Maybe Hardware
lookupHardware k = case filter ((== k) . hwId) catalogue of
  (h : _) -> Just h
  []      -> Nothing

-- Grid profiles ----------------------------------------------------------------

-- | A candidate spacing of control centres. Every profile is provisional
-- until docs/MECHANICAL.md's grid and fit gate passes; a sketch records which
-- one it used so the same idea can be re-laid on the approved pitch later.
data GridProfile = GridProfile
  { gpId       :: Text
  , gpPitch    :: (Double, Double)
  , gpFirstRow :: Double   -- ^ panel y of the first row of centres
  , gpStatus   :: Text     -- ^ always "candidate" today
  , gpNote     :: Text
  } deriving (Show)

gridProfiles :: [GridProfile]
gridProfiles =
  [ GridProfile "candidate-15" (15.0, 15.0) 20.0 "candidate"
      "15 mm knob spacing proposed in docs/MECHANICAL.md; needs the ergonomic mockup with cables installed."
  , GridProfile "candidate-15.24" (15.24, 15.24) 20.0 "candidate"
      "Three nominal HP; the panel width table and fixed rail holes still apply, so columns do not continue across modules."
  , GridProfile "thonkiconn-13.7" (13.7, 13.7) 20.0 "candidate"
      "The minimum Thonkiconn column pitch from the official footprint pads; dense, and not shown to give comfortable access."
  ]

lookupProfile :: Text -> Maybe GridProfile
lookupProfile k = case filter ((== k) . gpId) gridProfiles of
  (p : _) -> Just p
  []      -> Nothing

-- | A control centre closer than this to a panel side edge puts the widest
-- courtyard in the catalogue (a jack's, ±5 mm) outside the PCB zone, which
-- begins 1 mm inside the panel edge.
minCentreEdgeDistance :: Double
minCentreEdgeDistance = 6.0

-- | How many columns of the given pitch fit a panel of the given width with
-- 'minCentreEdgeDistance' at each side; at least one.
columnsFor :: Int -> Double -> Int
columnsFor hp pitch =
  max 1 (floor ((eurorackPanelWidth hp - 2 * minCentreEdgeDistance) / pitch) + 1)

-- | How many rows fit between the profile's first row and the bottom of the
-- PCB zone, leaving room for the deepest courtyard below a centre (the jack's
-- 12.98 mm); at least one.
rowsFor :: GridProfile -> Int
rowsFor gp =
  let (_, py) = gpPitch gp
      lastCentre = eurorackPcbTop + eurorackPcbHeight - deepestBelow
  in max 1 (floor ((lastCentre - gpFirstRow gp) / py) + 1)
  where deepestBelow = maximum [ bxY2 (hwCourtyard h) | h <- catalogue ]

-- | The default grid origin for a width: columns centred on the panel, rows
-- starting at the profile's first row. A sketch stores the origin it used, so
-- changing this rule never moves an existing sketch.
defaultGridOrigin :: Int -> GridProfile -> (Double, Double)
defaultGridOrigin hp gp =
  let (px, _) = gpPitch gp
      n = columnsFor hp px
      w = eurorackPanelWidth hp
  in (roundMm ((w - fromIntegral (n - 1) * px) / 2), roundMm (gpFirstRow gp))

-- | Round a derived coordinate to a nanometre. Two things want this. A
-- sketch is read and hand-edited, and @(40.3 - 15) \/ 2@ writing itself as
-- @12.649999999999999@ is noise in a file that says millimetres. And the
-- browser derives the same defaults, so the two sides must agree exactly:
-- @floor (x + 0.5)@ is what JavaScript's @Math.round@ does, including at a
-- half, which Haskell's banker's-rounding 'round' is not.
roundMm :: Double -> Double
roundMm x = fromIntegral (floor (x * 1e6 + 0.5) :: Integer) / 1e6

-- | Keep-out radius around a rail screw: an M3 screw head of about 5.5 to
-- 6 mm plus a little for the panel's hole tolerance.
railKeepoutRadius :: Double
railKeepoutRadius = 3.5

-- Geometry helpers -------------------------------------------------------------

-- | Rotate a box about the control centre by a multiple of 90 degrees, in the
-- same sense as the board emitter and 'Block.Eurorack.originFor' (positive is
-- counter-clockwise on screen with y down): (x, y) -> (y, -x) for 90.
boxRotate :: Int -> Box -> Box
boxRotate rot (Box x1 y1 x2 y2) =
  case ((rot `mod` 360) + 360) `mod` 360 of
    0   -> Box x1 y1 x2 y2
    90  -> Box y1 (negate x2) y2 (negate x1)
    180 -> Box (negate x2) (negate y2) (negate x1) (negate y1)
    270 -> Box (negate y2) x1 (negate y1) x2
    _   -> error "boxRotate: not a quarter turn"

boxTranslate :: (Double, Double) -> Box -> Box
boxTranslate (dx, dy) (Box x1 y1 x2 y2) = Box (x1 + dx) (y1 + dy) (x2 + dx) (y2 + dy)

-- | A circle is unchanged; a rectangle swaps its sides at odd quarter turns.
shapeRotate :: Int -> Shape -> Shape
shapeRotate _ (Circle d) = Circle d
shapeRotate rot (Rect w h)
  | odd ((rot `div` 90) `mod` 2) = Rect h w
  | otherwise = Rect w h
