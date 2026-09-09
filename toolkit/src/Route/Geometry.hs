-- | Copper geometry the router needs: pad shapes with exact distance
-- functions, board outline, keep-out polygons. Everything in millimetres,
-- board coordinates (origin top-left, y down).
module Route.Geometry
  ( Pt
  , Layer (..)
  , Shape (..)
  , PadGeom (..)
  , Keepout (..)
  , Outline (..)
  , RTrace (..)
  , RVia (..)
  , distToShape
  , shapeRadius
  , shapeInRadius
  , segPointDist
  , segSegDist
  , minSegShapeDist
  , distOutsideOutline
  , pointInPolygon
  , distToPolygonEdge
  , rotatePt
  , addPt
  , subPt
  , dist
  ) where

import           Data.Text (Text)

type Pt = (Double, Double)

data Layer = F | B
  deriving (Eq, Ord, Show, Enum, Bounded)

-- | Pad copper shape, centred at the origin, rotated by the pad's absolute
-- angle (degrees, KiCad sense).
data Shape
  = Circle Double                      -- ^ radius
  | Rect Double Double Double          -- ^ width, height, angle
  | RoundRect Double Double Double Double  -- ^ width, height, corner radius, angle
  deriving (Show)

data PadGeom = PadGeom
  { pgRef    :: Text
  , pgNumber :: Text
  , pgNet    :: Maybe Text     -- ^ Nothing for plated-nothing holes: a hard obstacle
  , pgAt     :: Pt
  , pgShape  :: Shape
  , pgLayers :: [Layer]
  } deriving (Show)

-- | A region no trace may enter on the given layers.
data Keepout = Keepout
  { koLayers :: [Layer]
  , koPoly   :: [Pt]
  } deriving (Show)

-- | Rectangular board with rounded corners, origin at the top-left corner.
data Outline = Outline
  { olWidth  :: Double
  , olHeight :: Double
  , olRadius :: Double
  } deriving (Show)

-- | A copper polyline on one layer, board coordinates.
data RTrace = RTrace { rtNet :: Text, rtLayer :: Layer, rtWidth :: Double, rtPath :: [Pt] }
  deriving (Show)

-- | A through via: a copper disc on both layers.
data RVia = RVia { rvNet :: Text, rvAt :: Pt, rvDiameter :: Double, rvDrill :: Double }
  deriving (Show)

addPt, subPt :: Pt -> Pt -> Pt
addPt (a, b) (c, d) = (a + c, b + d)
subPt (a, b) (c, d) = (a - c, b - d)

dist :: Pt -> Pt -> Double
dist (a, b) (c, d) = sqrt ((a - c) * (a - c) + (b - d) * (b - d))

-- | Rotate by KiCad's board angle (degrees, counter-clockwise on a y-down
-- screen).
rotatePt :: Double -> Pt -> Pt
rotatePt 0 p = p
rotatePt a (x, y) =
  let r = a * pi / 180
  in (x * cos r + y * sin r, -x * sin r + y * cos r)

-- | Signed distance from a point to the shape boundary: negative inside.
distToShape :: Shape -> Pt -> Pt -> Double
distToShape sh centre p =
  let q = subPt p centre
  in case sh of
       Circle r -> dist q (0, 0) - r
       Rect w h a -> roundRectDist w h 0 (rotatePt (-a) q)
       RoundRect w h r a -> roundRectDist w h r (rotatePt (-a) q)

-- Signed distance to an axis-aligned rounded rectangle centred at the origin.
roundRectDist :: Double -> Double -> Double -> Pt -> Double
roundRectDist w h r (x, y) =
  let hx = w / 2 - r
      hy = h / 2 - r
      dx = abs x - hx
      dy = abs y - hy
      outside = sqrt (max dx 0 ^ (2 :: Int) + max dy 0 ^ (2 :: Int))
      inside = min (max dx dy) 0
  in outside + inside - r

-- | Radius of the smallest circle around the shape, for bounding boxes and
-- heuristics.
shapeRadius :: Shape -> Double
shapeRadius (Circle r)          = r
shapeRadius (Rect w h _)        = sqrt (w * w + h * h) / 2
shapeRadius (RoundRect w h _ _) = sqrt (w * w + h * h) / 2

-- | Radius of the largest circle inside the shape.
shapeInRadius :: Shape -> Double
shapeInRadius (Circle r)          = r
shapeInRadius (Rect w h _)        = min w h / 2
shapeInRadius (RoundRect w h _ _) = min w h / 2

-- | Distance from a point to a segment.
segPointDist :: Pt -> Pt -> Pt -> Double
segPointDist (x1, y1) (x2, y2) (px, py) =
  let dx = x2 - x1; dy = y2 - y1
      l2 = dx * dx + dy * dy
      t = if l2 == 0 then 0 else max 0 (min 1 (((px - x1) * dx + (py - y1) * dy) / l2))
  in dist (px, py) (x1 + t * dx, y1 + t * dy)

-- | Distance between two segments (zero when they cross).
segSegDist :: (Pt, Pt) -> (Pt, Pt) -> Double
segSegDist (p1, p2) (q1, q2)
  | intersects = 0
  | otherwise = minimum [ segPointDist p1 p2 q1, segPointDist p1 p2 q2
                        , segPointDist q1 q2 p1, segPointDist q1 q2 p2 ]
  where
    cross (ax, ay) (bx, by) = ax * by - ay * bx
    d1 = cross (subPt q2 q1) (subPt p1 q1)
    d2 = cross (subPt q2 q1) (subPt p2 q1)
    d3 = cross (subPt p2 p1) (subPt q1 p1)
    d4 = cross (subPt p2 p1) (subPt q2 p1)
    intersects = ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0))
              && ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))

-- | Minimum signed distance from a pad shape to a segment (negative when the
-- segment enters the shape). The signed distance to a convex shape is convex
-- along a line, so a ternary search over the segment finds it.
minSegShapeDist :: Shape -> Pt -> Pt -> Pt -> Double
minSegShapeDist sh centre p1 p2 = go (0 :: Int) 0 1
  where
    at t = let (x1, y1) = p1; (x2, y2) = p2 in (x1 + (x2 - x1) * t, y1 + (y2 - y1) * t)
    f t = distToShape sh centre (at t)
    go n lo hi
      | n >= 80 = min (f lo) (f hi)
      | otherwise =
          let m1 = lo + (hi - lo) / 3
              m2 = hi - (hi - lo) / 3
          in if f m1 < f m2 then go (n + 1) lo m2 else go (n + 1) m1 hi

-- | Signed distance to the outline edge: negative inside the board.
distOutsideOutline :: Outline -> Pt -> Double
distOutsideOutline (Outline w h r) (x, y) =
  roundRectDist w h r (x - w / 2, y - h / 2)

pointInPolygon :: [Pt] -> Pt -> Bool
pointInPolygon poly (px, py) = odd (length crossings)
  where
    edges = zip poly (drop 1 poly ++ take 1 poly)
    crossings = [ () | ((x1, y1), (x2, y2)) <- edges
                     , (y1 > py) /= (y2 > py)
                     , let xi = x1 + (py - y1) * (x2 - x1) / (y2 - y1)
                     , px < xi ]

distToPolygonEdge :: [Pt] -> Pt -> Double
distToPolygonEdge poly p = minimum [ segPointDist a b p | (a, b) <- edges ]
  where
    edges = zip poly (drop 1 poly ++ take 1 poly)
