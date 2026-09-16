{-# LANGUAGE OverloadedStrings #-}
-- | Where a sketch's controls land and what is wrong with where they land.
--
-- The geometry goes through 'Block.Eurorack' ('skeleton', 'toBoard',
-- 'originFor'), so a sketch and a generated board agree by construction on
-- panel size, PCB zone, rail holes and the footprint-origin transform. The
-- browser reimplements the same arithmetic in JavaScript and is held to
-- these results by the test vectors 'Sketch.Export' writes.
--
-- Findings come in three severities. A 'Conflict' means the sketch cannot be
-- built as drawn (a hole off the panel, a body outside the PCB zone, two
-- courtyards overlapping). A 'Warning' is a comfort or policy concern (finger
-- room, a width outside the module policy). A 'Note' records what the sketch
-- cannot claim: provisional pitch, unverified envelopes, footprints still to
-- be drawn. Nothing here ever moves a control; the sketch is reported as it
-- is, and the user decides.
module Sketch.Check
  ( Placement (..)
  , Severity (..)
  , Finding (..)
  , placeControl
  , placeSketch
  , checkSketch
  , boardZone
  , shapesOverlap
  , boxesOverlap
  ) where

import           Data.List (nub, sortOn)
import           Data.Text (Text)
import qualified Data.Text as T

import           Block.Eurorack
import           Design           (Side (..), eurorackPanelWidths)
import           Sketch.Catalogue
import           Sketch.Model

data Placement = Placement
  { plControl         :: Control
  , plHardware        :: Hardware
  , plCentre          :: (Double, Double)  -- ^ panel coordinates
  , plBoardCentre     :: (Double, Double)  -- ^ board coordinates
  , plFootprintOrigin :: (Double, Double)  -- ^ board coordinates of the footprint's origin
  , plCourtyard       :: Box               -- ^ panel coordinates, rotated
  , plFrontBody       :: Shape             -- ^ rotated
  , plFrontAccess     :: Maybe Shape
  } deriving (Show)

data Severity = Conflict | Warning | Note
  deriving (Eq, Ord, Show)

data Finding = Finding
  { fnKind     :: Text
  , fnSeverity :: Severity
  , fnControls :: [Text]
  , fnMessage  :: Text
  } deriving (Eq, Show)

-- | The centre of a control: the middle of its block of cells plus its offset.
controlCentre :: Grid -> Control -> (Double, Double)
controlCentre g c =
  let (ox, oy) = grOrigin g
      (px, py) = grPitch g
      (col, row) = ctCell c
      (cols, rows) = ctSpan c
      (dx, dy) = ctOffset c
  in ( ox + (fromIntegral col + fromIntegral (cols - 1) / 2) * px + dx
     , oy + (fromIntegral row + fromIntegral (rows - 1) / 2) * py + dy )

-- | Every panel-mounted part goes on the front side of the board, so the
-- footprint origin is what 'originFor' gives for 'Front' at the control's
-- rotation: the same call the attenuverter makes for its pots.
placeControl :: Skeleton -> Grid -> Control -> Hardware -> Placement
placeControl sk g c hw =
  let centre = controlCentre g c
      bc = toBoard sk centre
      rot = ctRotation c
  in Placement
       { plControl = c
       , plHardware = hw
       , plCentre = centre
       , plBoardCentre = bc
       , plFootprintOrigin = originFor Front (fromIntegral rot) (hwAnchor hw) bc
       , plCourtyard = boxTranslate centre (boxRotate rot (hwCourtyard hw))
       , plFrontBody = shapeRotate rot (hwFrontBody hw)
       , plFrontAccess = shapeRotate rot <$> hwFrontAccess hw
       }

-- | Controls whose hardware the catalogue knows; decoding already refused
-- the others, so a decoded sketch places every control.
placeSketch :: Sketch -> [Placement]
placeSketch s =
  [ placeControl sk (sxGrid s) c hw | c <- sxControls s, Just hw <- [lookupHardware (ctHardware c)] ]
  where sk = skeleton (sxHP s)

-- | The PCB zone in panel coordinates: everything between panel and board
-- must lie inside it (AGENTS.md).
boardZone :: Skeleton -> Box
boardZone sk =
  let (ox, oy) = skBoardOrigin sk
  in Box ox oy (ox + skBoardWidth sk) (oy + skBoardHeight sk)

checkSketch :: Sketch -> [Finding]
checkSketch s = sortOn fnSeverity $ concat
  [ concatMap single ps
  , pairs ps
  , policy
  , notes
  ]
  where
    sk = skeleton (sxHP s)
    ps = placeSketch s
    w = skPanelWidth sk
    h = skPanelHeight sk
    zone = boardZone sk
    (px, py) = grPitch (sxGrid s)
    railHoles = [ (x, y) | x <- skRailHoleX sk, y <- skRailHoleY sk ]

    single p =
      let c = plControl p
          cid = ctId c
          (cx, cy) = plCentre p
          r = hwHoleDiameter (plHardware p) / 2
          Box bx1 by1 bx2 by2 = plCourtyard p
          (dx, dy) = ctOffset c
      in concat
        [ [ Finding "outside-panel" Conflict [cid]
              (cid <> ": its " <> mm (2 * r) <> " hole leaves the " <> mm w <> " x " <> mm h <> " panel")
          | cx - r < 0 || cx + r > w || cy - r < 0 || cy + r > h ]
        , [ Finding "outside-board-zone" Conflict [cid]
              (cid <> ": its body behind the panel leaves the PCB zone (panel x " <> mm (bxX1 zone) <> " to " <> mm (bxX2 zone)
               <> ", y " <> mm (bxY1 zone) <> " to " <> mm (bxY2 zone) <> ")")
          | bx1 < bxX1 zone - eps || bx2 > bxX2 zone + eps || by1 < bxY1 zone - eps || by2 > bxY2 zone + eps ]
        , [ Finding "rail-keepout" Conflict [cid]
              (cid <> ": stands within " <> mm railKeepoutRadius <> " of the rail screw at (" <> mm rx <> ", " <> mm ry <> ")")
          | (rx, ry) <- railHoles
          , shapesOverlap (plFrontBody p, plCentre p) (Circle (2 * railKeepoutRadius), (rx, ry)) ]
        , [ Finding "offset-too-large" Conflict [cid]
              (cid <> ": offset (" <> mm dx <> ", " <> mm dy <> ") leaves its cell; keep it within half a pitch")
          | abs dx > px / 2 + eps || abs dy > py / 2 + eps ]
        ]

    pairs qs = concat
      [ concat
          [ [ Finding "cell-overlap" Conflict [a, b] (a <> " and " <> b <> " reserve the same cell " <> cellText cell)
            | hwReservesCell (plHardware p), hwReservesCell (plHardware q)
            , let shared = [ cell | cell <- controlCells (plControl p), cell `elem` controlCells (plControl q) ]
            , cell <- take 1 shared ]
          , [ Finding "front-overlap" Conflict [a, b] (a <> " and " <> b <> " collide in front of the panel (nut, knob or bushing)")
            | shapesOverlap (plFrontBody p, plCentre p) (plFrontBody q, plCentre q) ]
          , [ Finding "back-overlap" Conflict [a, b] (a <> " and " <> b <> " have overlapping footprint courtyards behind the panel")
            | boxesOverlap (plCourtyard p) (plCourtyard q) ]
          , [ Finding "access-overlap" Warning [a, b] (a <> " and " <> b <> ": finger, cable or bat room overlaps; check on the mockup")
            | not (shapesOverlap (plFrontBody p, plCentre p) (plFrontBody q, plCentre q))
            , accessOverlap p q ]
          ]
      | (i, p) <- zip [0 :: Int ..] qs, (j, q) <- zip [0 ..] qs, i < j
      , let a = ctId (plControl p), let b = ctId (plControl q) ]

    accessOverlap p q =
      or [ shapesOverlap (ap, plCentre p) (plFrontBody q, plCentre q) | Just ap <- [plFrontAccess p] ]
      || or [ shapesOverlap (aq, plCentre q) (plFrontBody p, plCentre p) | Just aq <- [plFrontAccess q] ]
      || or [ shapesOverlap (ap, plCentre p) (aq, plCentre q) | Just ap <- [plFrontAccess p], Just aq <- [plFrontAccess q] ]

    policy = concat
      [ [ Finding "hp-policy" Warning [] ("width " <> tshow (sxHP s) <> " HP is outside the 4 to 20 HP module policy")
        | sxHP s < 4 || sxHP s > 20 ]
      , [ Finding "hp-formula" Warning [] ("width " <> tshow (sxHP s) <> " HP is not in Doepfer's table; the panel width is the formula HP x 5.08 - 0.3")
        | sxHP s `notElem` map fst eurorackPanelWidths ]
      ]

    notes = concat
      [ [ Finding "provisional-grid" Note [] ("grid profile " <> T.pack (show prof) <> " is a candidate pitch, not an approved one; this sketch is provisional")
        | let prof = grProfile (sxGrid s), maybe True ((== "candidate") . gpStatus) (lookupProfile prof) ]
      , [ Finding "unverified-front" Note ids
            (hwId hw <> ": nut, knob or cable envelope is an estimate awaiting the mockup (" <> tshow (length ids) <> " control" <> (if length ids == 1 then "" else "s") <> ")")
        | hw <- catalogue, hwFrontEvidence hw == Unverified
        , let ids = [ ctId (plControl p) | p <- ps, hwId (plHardware p) == hwId hw ], not (null ids) ]
      , [ Finding "no-footprint" Note ids
            (hwId hw <> ": no footprint exists yet, so a design cannot place it until lib/footprints gains one")
        | hw <- catalogue, Nothing <- [hwFootprint hw]
        , let ids = [ ctId (plControl p) | p <- ps, hwId (plHardware p) == hwId hw ], not (null ids) ]
      , [ Finding "proposed-hardware" Note ids
            (hwId hw <> ": proposed in the hardware standard, not yet designed in or measured")
        | hw <- catalogue, hwStatus hw == Proposed
        , let ids = nub [ ctId (plControl p) | p <- ps, hwId (plHardware p) == hwId hw ], not (null ids) ]
      ]

    cellText (c, r) = "(" <> tshow c <> ", " <> tshow r <> ")"

eps :: Double
eps = 1e-6

mm :: Double -> Text
mm d = T.pack (trim (show (fromIntegral (round (d * 100) :: Integer) / 100 :: Double))) <> " mm"
  where trim t | ".0" `T.isSuffixOf` T.pack t = take (length t - 2) t
               | otherwise = t

tshow :: Show a => a -> Text
tshow = T.pack . show

-- | Two envelopes overlap when they share interior; touching does not count.
shapesOverlap :: (Shape, (Double, Double)) -> (Shape, (Double, Double)) -> Bool
shapesOverlap (Circle d1, (x1, y1)) (Circle d2, (x2, y2)) =
  sqrt ((x1 - x2) ^ (2 :: Int) + (y1 - y2) ^ (2 :: Int)) < (d1 + d2) / 2 - eps
shapesOverlap (Rect w1 h1, (x1, y1)) (Rect w2 h2, (x2, y2)) =
  boxesOverlap (Box (x1 - w1 / 2) (y1 - h1 / 2) (x1 + w1 / 2) (y1 + h1 / 2))
               (Box (x2 - w2 / 2) (y2 - h2 / 2) (x2 + w2 / 2) (y2 + h2 / 2))
shapesOverlap (Circle d, c) (r@(Rect _ _), rc) = circleRect d c r rc
shapesOverlap (r@(Rect _ _), rc) (Circle d, c) = circleRect d c r rc

circleRect :: Double -> (Double, Double) -> Shape -> (Double, Double) -> Bool
circleRect d (cx, cy) (Rect w h) (rx, ry) =
  let nx = max (rx - w / 2) (min cx (rx + w / 2))
      ny = max (ry - h / 2) (min cy (ry + h / 2))
  in sqrt ((cx - nx) ^ (2 :: Int) + (cy - ny) ^ (2 :: Int)) < d / 2 - eps
circleRect _ _ _ _ = False

boxesOverlap :: Box -> Box -> Bool
boxesOverlap (Box ax1 ay1 ax2 ay2) (Box bx1 by1 bx2 by2) =
  ax1 < bx2 - eps && bx1 < ax2 - eps && ay1 < by2 - eps && by1 < ay2 - eps
