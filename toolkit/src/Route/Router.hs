{-# LANGUAGE BangPatterns #-}
-- | Grid autorouter: A* per net over a two-layer occupancy grid, with
-- negotiated congestion (PathFinder-style) to resolve conflicts between nets.
--
-- Cells are square, pitch @rcPitch@. A trace runs along cell centres in eight
-- directions; a via is a step between layers at the same cell. Pads are hard
-- terrain for every other net. Routed copper of other nets is *soft*: it
-- costs more each iteration it stays contested, so nets with alternatives
-- move away and nets without alternatives keep their ground.
module Route.Router
  ( RouteConfig (..)
  , defaultRouteConfig
  , RouteProblem (..)
  , RoutedNet (..)
  , RouteResult (..)
  , RTrace (..)
  , RVia (..)
  , autoroute
  ) where

import           Data.Array.Unboxed
import qualified Data.IntMap.Strict as IM
import qualified Data.IntSet        as IS
import           Data.List          (foldl', minimumBy, sortOn)
import qualified Data.Map.Strict    as M
import           Data.Maybe         (fromMaybe, mapMaybe)
import           Data.Ord           (comparing)
import qualified Data.Set           as S
import           Data.Text          (Text)
import qualified Data.Text          as T

import           Route.Geometry

data RouteConfig = RouteConfig
  { rcPitch         :: Double   -- ^ grid cell size, mm
  , rcWidth         :: Double   -- ^ trace width, mm
  , rcClearance     :: Double   -- ^ copper-to-copper clearance, mm
  , rcEdgeClearance :: Double   -- ^ copper-to-board-edge clearance, mm
  , rcViaDiameter   :: Double
  , rcViaDrill      :: Double
  , rcViaCost       :: Double   -- ^ in units of one cell step
  , rcNets          :: [Text]   -- ^ design net names to route
  , rcMaxIterations :: Int
  } deriving (Show)

defaultRouteConfig :: [Text] -> RouteConfig
defaultRouteConfig nets = RouteConfig
  { rcPitch = 0.2, rcWidth = 0.3, rcClearance = 0.2, rcEdgeClearance = 0.5
  , rcViaDiameter = 0.6, rcViaDrill = 0.3, rcViaCost = 40
  , rcNets = nets, rcMaxIterations = 40 }

data RouteProblem = RouteProblem
  { rpOutline  :: Outline
  , rpPads     :: [PadGeom]     -- ^ every pad on the board, routed nets or not
  , rpKeepouts :: [Keepout]
  , rpPreRouted :: [(Text, Layer, Double, [Pt])]  -- ^ hand-drawn traces: (net, layer, width, path)
  }

data RTrace = RTrace { rtNet :: Text, rtLayer :: Layer, rtWidth :: Double, rtPath :: [Pt] }
  deriving (Show)

data RVia = RVia { rvNet :: Text, rvAt :: Pt, rvDiameter :: Double, rvDrill :: Double }
  deriving (Show)

data RoutedNet = RoutedNet
  { rnNet    :: Text
  , rnTraces :: [RTrace]
  , rnVias   :: [RVia]
  } deriving (Show)

data RouteResult = RouteResult
  { rrNets       :: [RoutedNet]
  , rrFailed     :: [Text]      -- ^ nets with a terminal that could not be reached
  , rrConflicts  :: Int         -- ^ contested cells left after the last iteration
  , rrIterations :: Int
  , rrLog        :: [Text]
  }

-- Grid ------------------------------------------------------------------------

data Grid = Grid
  { gW      :: !Int
  , gH      :: !Int
  , gPitch  :: !Double
  , gOwner  :: !(UArray Int Int)   -- ^ 0 free, n>0 pad copper of net n, -1 hard obstacle
  , gNear   :: !(UArray Int Int)   -- ^ 0 none, n>0 within clearance of net n only, -1 of several
  }

nLayers :: Int
nLayers = 2

layerIx :: Layer -> Int
layerIx F = 0
layerIx B = 1

ixLayer :: Int -> Layer
ixLayer 0 = F
ixLayer _ = B

cellIdx :: Grid -> Int -> Int -> Int -> Int
cellIdx g l x y = (l * gH g + y) * gW g + x

cellCoords :: Grid -> Int -> (Int, Int, Int)
cellCoords g i =
  let (ly, x) = i `divMod` gW g
      (l, y) = ly `divMod` gH g
  in (l, x, y)

cellCentre :: Grid -> Int -> Int -> Pt
cellCentre g x y = ((fromIntegral x + 0.5) * gPitch g, (fromIntegral y + 0.5) * gPitch g)

-- | Cells whose centre lies within the bounding box of a disc.
cellsAround :: Grid -> Pt -> Double -> [(Int, Int)]
cellsAround g (cx, cy) r =
  [ (x, y)
  | x <- [max 0 (floor ((cx - r) / gPitch g)) .. min (gW g - 1) (ceiling ((cx + r) / gPitch g))]
  , y <- [max 0 (floor ((cy - r) / gPitch g)) .. min (gH g - 1) (ceiling ((cy + r) / gPitch g))]
  ]

buildGrid :: RouteConfig -> RouteProblem -> M.Map Text Int -> Grid
buildGrid cfg prob netIds =
  let pitch = rcPitch cfg
      ol = rpOutline prob
      w = ceiling (olWidth ol / pitch)
      h = ceiling (olHeight ol / pitch)
      size = nLayers * w * h
      g0 = Grid w h pitch (listArray (0, size - 1) (replicate size 0)) (listArray (0, size - 1) (replicate size 0))
      halfW = rcWidth cfg / 2
      infl = halfW + rcClearance cfg

      netId n = fromMaybe 0 (M.lookup n netIds)

      -- Owner writes: later writes win, so hard obstacles go last.
      padOwner = concat
        [ [ (cellIdx g0 (layerIx l) x y, nid)
          | l <- pgLayers p, (x, y) <- cellsAround g0 (pgAt p) (shapeRadius (pgShape p) + pitch)
          , distToShape (pgShape p) (pgAt p) (cellCentre g0 x y) <= 0 ]
        | p <- rpPads prob, let nid = maybe (-1) netId (pgNet p), nid /= 0 ]
      hardPads = concat
        [ [ (cellIdx g0 (layerIx l) x y, -1)
          | l <- pgLayers p, (x, y) <- cellsAround g0 (pgAt p) (shapeRadius (pgShape p) + infl + pitch)
          , distToShape (pgShape p) (pgAt p) (cellCentre g0 x y) <= infl ]
        | p <- rpPads prob, pgNet p == Nothing ]
      edge = [ (cellIdx g0 l x y, -1)
             | l <- [0 .. nLayers - 1], x <- [0 .. w - 1], y <- [0 .. h - 1]
             , distOutsideOutline ol (cellCentre g0 x y) > negate (rcEdgeClearance cfg + halfW + 0.75 * pitch) ]
      keep = concat
        [ [ (cellIdx g0 (layerIx l) x y, -1)
          | l <- koLayers k, x <- [0 .. w - 1], y <- [0 .. h - 1]
          , let c = cellCentre g0 x y
          , pointInPolygon (koPoly k) c || distToPolygonEdge (koPoly k) c <= halfW ]
        | k <- rpKeepouts prob ]
      ownerArr = accumArray (\_ new -> new) 0 (0, size - 1) (padOwner ++ edge ++ keep ++ hardPads) :: UArray Int Int

      -- Clearance halo around pads: which net may still pass here.
      nearWrites = concat
        [ [ (cellIdx g0 (layerIx l) x y, nid)
          | l <- pgLayers p, (x, y) <- cellsAround g0 (pgAt p) (shapeRadius (pgShape p) + infl + pitch)
          , let d = distToShape (pgShape p) (pgAt p) (cellCentre g0 x y)
          , d > 0 && d <= infl ]
        | p <- rpPads prob, Just n <- [pgNet p], let nid = netId n, nid /= 0 ]
      merge old new
        | old == 0 = new
        | old == new = old
        | otherwise = -1
      nearArr = accumArray merge 0 (0, size - 1) nearWrites :: UArray Int Int
  in g0 { gOwner = ownerArr, gNear = nearArr }

-- Occupancy of routed copper --------------------------------------------------

-- | cell -> net -> stamp count. A stamp covers the trace plus the clearance
-- another trace centre must keep from it.
type Occ = IM.IntMap (IM.IntMap Int)

stampCells :: Grid -> RouteConfig -> [(Int, Int, Int)] -> [(Int, Int, Int)] -> [Int]
stampCells g cfg pathCells viaCells =
  let rTrace = rcWidth cfg + rcClearance cfg + rcPitch cfg      -- centre-to-centre minimum plus one cell of slack for smoothing
      rVia = rcViaDiameter cfg / 2 + rcWidth cfg / 2 + rcClearance cfg
      disc l (cx, cy) r = [ cellIdx g l x y | (x, y) <- cellsAround g (cellCentre g cx cy) r
                          , dist (cellCentre g x y) (cellCentre g cx cy) <= r ]
  in concat [ disc l (x, y) rTrace | (l, x, y) <- pathCells ]
     ++ concat [ disc l (x, y) rVia | (_, x, y) <- viaCells, l <- [0 .. nLayers - 1] ]

addStamps :: Int -> [Int] -> Occ -> Occ
addStamps nid cells occ = foldl' (\o c -> IM.insertWith (IM.unionWith (+)) c (IM.singleton nid 1) o) occ cells

removeStamps :: Int -> [Int] -> Occ -> Occ
removeStamps nid cells occ = foldl' step occ cells
  where
    step o c = IM.update (\m -> let m' = IM.update (\k -> if k <= 1 then Nothing else Just (k - 1)) nid m
                                in if IM.null m' then Nothing else Just m') c o

otherNetsAt :: Occ -> Int -> Int -> Int
otherNetsAt occ nid c = case IM.lookup c occ of
  Nothing -> 0
  Just m  -> IM.size (IM.delete nid m)

-- A* -------------------------------------------------------------------------

data Search = Search
  { sGrid   :: Grid
  , sCfg    :: RouteConfig
  , sNet    :: !Int
  , sOcc    :: Occ
  , sHist   :: IM.IntMap Double
  , sPres   :: !Double          -- ^ present-sharing penalty factor for this iteration
  }

traversable :: Search -> Int -> Bool
traversable s c =
  let o = gOwner (sGrid s) ! c
      n = gNear (sGrid s) ! c
  in (o == 0 || o == sNet s) && (n == 0 || n == sNet s)

cellPenalty :: Search -> Int -> Double
cellPenalty s c =
  let others = otherNetsAt (sOcc s) (sNet s) c
      h = fromMaybe 0 (IM.lookup c (sHist s))
  in sPres s * fromIntegral others + h

-- | Route from any source cell to any target cell. Returns the cell path,
-- source first.
astar :: Search -> IS.IntSet -> IS.IntSet -> Pt -> Double -> Maybe [Int]
astar s sources targets targetCentre targetRadius = go open0 g0 IM.empty IS.empty
  where
    g = sGrid s
    cfg = sCfg s
    pitch = gPitch g
    heur c = let (_, x, y) = cellCoords g c
                 d = dist (cellCentre g x y) targetCentre
             in max 0 (d - targetRadius) / pitch
    g0 = IM.fromList [ (c, 0) | c <- IS.toList sources ]
    open0 = S.fromList [ (heur c, c) | c <- IS.toList sources ]

    go open gScore parent closed
      | S.null open = Nothing
      | otherwise =
          let ((_, c), open') = S.deleteFindMin open
          in if IS.member c targets
               then Just (reverse (walk c parent))
               else if IS.member c closed
                 then go open' gScore parent closed
                 else
                   let gc = fromMaybe 0 (IM.lookup c gScore)
                       closed' = IS.insert c closed
                       (open'', gScore', parent') = foldl' (relax c gc) (open', gScore, parent)
                                                     (neighbours c)
                   in go open'' gScore' parent' closed'

    walk c parent = case IM.lookup c parent of
      Nothing -> [c]
      Just p  -> c : walk p parent

    relax c gc (open, gScore, parent) (nc, stepCost)
      | not (traversable s nc) = (open, gScore, parent)
      | otherwise =
          let tentative = gc + stepCost * (1 + cellPenalty s nc)
          in case IM.lookup nc gScore of
               Just old | old <= tentative -> (open, gScore, parent)
               _ -> ( S.insert (tentative + heur nc, nc) open
                    , IM.insert nc tentative gScore
                    , IM.insert nc c parent )

    neighbours c =
      let (l, x, y) = cellCoords g c
          inLayer = [ (cellIdx g l nx ny, len)
                    | (dx, dy, len) <- [(1,0,1),(-1,0,1),(0,1,1),(0,-1,1),(1,1,s2),(1,-1,s2),(-1,1,s2),(-1,-1,s2)]
                    , let nx = x + dx, let ny = y + dy
                    , nx >= 0, ny >= 0, nx < gW g, ny < gH g ]
          via = [ (cellIdx g l' x y, rcViaCost cfg) | l' <- [0 .. nLayers - 1], l' /= l ]
      in inLayer ++ via
    s2 = sqrt 2

-- Per-net routing -------------------------------------------------------------

data Terminal = Terminal
  { tCells  :: IS.IntSet
  , tCentre :: Pt
  , tRadius :: Double
  }

-- | Pad cells of one net, grouped per pad. Pads too small to own a cell
-- centre get their centre cell.
terminalsFor :: Grid -> M.Map Text Int -> Text -> [PadGeom] -> [Terminal]
terminalsFor g netIds net pads =
  [ Terminal cells (pgAt p) (shapeRadius (pgShape p))
  | p <- pads, pgNet p == Just net
  , let nid = fromMaybe 0 (M.lookup net netIds)
  , let owned = IS.fromList [ cellIdx g (layerIx l) x y
                            | l <- pgLayers p, (x, y) <- cellsAround g (pgAt p) (shapeRadius (pgShape p) + gPitch g)
                            , gOwner g ! cellIdx g (layerIx l) x y == nid
                            , distToShape (pgShape p) (pgAt p) (cellCentre g x y) <= 0 ]
  , let (cx, cy) = pgAt p
        centreCell = IS.fromList [ cellIdx g (layerIx l) (clampX (floor (cx / gPitch g))) (clampY (floor (cy / gPitch g))) | l <- pgLayers p ]
  , let cells = if IS.null owned then centreCell else owned
  ]
  where
    clampX v = max 0 (min (gW g - 1) v)
    clampY v = max 0 (min (gH g - 1) v)

-- | Connect all terminals of a net into one tree. Returns the cells of every
-- path segment (each path source-first), or the index of the terminal that
-- could not be reached.
routeNet :: Search -> [Terminal] -> IS.IntSet -> Either Int [[Int]]
routeNet _ [] _ = Right []
routeNet s (t0 : rest) preCells = go (IS.union (tCells t0) preCells) rest []
  where
    go _ [] acc = Right (reverse acc)
    go tree remaining acc =
      let treePts = [ cellCentre (sGrid s) x y | c <- take 400 (IS.toList tree), let (_, x, y) = cellCoords (sGrid s) c ]
          nearestIx = fst (minimumBy (comparing snd)
                        [ (i, minimum (1e9 : [ dist p (tCentre t) | p <- treePts ])) | (i, t) <- zip [0 :: Int ..] remaining ])
          target = remaining !! nearestIx
          remaining' = [ t | (i, t) <- zip [0 ..] remaining, i /= nearestIx ]
      in case astar s tree (tCells target) (tCentre target) (tRadius target) of
           Nothing   -> Left nearestIx
           Just path -> go (IS.union tree (IS.fromList path) `IS.union` tCells target) remaining' (path : acc)

-- Negotiation loop ------------------------------------------------------------

data NetState = NetState
  { nsPaths  :: [[Int]]
  , nsStamps :: [Int]
  , nsVias   :: [(Int, Int, Int)]
  , nsFailed :: Bool
  }

autoroute :: RouteConfig -> RouteProblem -> RouteResult
autoroute cfg prob =
  let allNets = S.toList (S.fromList (mapMaybe pgNet (rpPads prob)))
      netIds = M.fromList (zip allNets [1 ..])
      grid = buildGrid cfg prob netIds
      toRoute = [ n | n <- rcNets cfg, M.member n netIds ]
      missing = [ n | n <- rcNets cfg, not (M.member n netIds) ]
      terms = M.fromList [ (n, terminalsFor grid netIds n (rpPads prob)) | n <- toRoute ]

      -- Hand-drawn traces count as existing copper of their net.
      preCellsOf n = IS.fromList
        [ cellIdx grid (layerIx l) x y
        | (pn, l, _, path) <- rpPreRouted prob, pn == n
        , (p1, p2) <- zip path (drop 1 path)
        , (x, y) <- rasterSegment grid p1 p2 ]
      occ0 = foldl' (\o (n, l, _, path) ->
                       let nid = netIds M.! n
                           cells = [ (layerIx l, x, y) | (p1, p2) <- zip path (drop 1 path), (x, y) <- rasterSegment grid p1 p2 ]
                       in addStamps nid (stampCells grid cfg cells []) o)
                    IM.empty
                    [ t | t@(n, _, _, _) <- rpPreRouted prob, M.member n netIds ]

      -- Short nets first: they have the fewest alternatives.
      order = sortOn (\n -> negate (length (terms M.! n))) toRoute

      initial = M.fromList [ (n, NetState [] [] [] False) | n <- toRoute ]

      loop iter occ hist states logAcc
        | iter > rcMaxIterations cfg = finish iter occ states (T.pack ("stopped after " ++ show (iter - 1) ++ " iterations") : logAcc)
        | otherwise =
            let pres = 0.5 * fromIntegral iter
                (occ', states') = foldl' (routeOne iter pres hist) (occ, states) order
                contested = [ c | (c, m) <- IM.toList occ', IM.size m > 1 ]
                hist' = foldl' (\h c -> IM.insertWith (+) c 1 h) hist contested
                msg = T.pack ("iteration " ++ show iter ++ ": " ++ show (length contested) ++ " contested cells")
            in if null contested
                 then finish iter occ' states' (msg : logAcc)
                 else loop (iter + 1) occ' hist' states' (msg : logAcc)

      routeOne _iter pres hist (occ, states) n =
        let nid = netIds M.! n
            st = states M.! n
            occNo = removeStamps nid (nsStamps st) occ
            search = Search grid cfg nid occNo hist pres
        in case routeNet search (terms M.! n) (preCellsOf n) of
             Left _ -> (occNo, M.insert n (NetState [] [] [] True) states)
             Right paths ->
               let cells = [ cellCoords grid c | p <- paths, c <- p ]
                   vias = viasOf grid paths
                   stamps = stampCells grid cfg cells vias
               in (addStamps nid stamps occNo, M.insert n (NetState paths stamps vias False) states)

      finish iter occ states logAcc =
        let contested = length [ () | (_, m) <- IM.toList occ, IM.size m > 1 ]
            -- A straight run between two points is acceptable when every
            -- sample along it is free terrain for this net and untouched by
            -- other nets' copper.
            -- Grid cells are checked for other nets' copper and static
            -- obstacles; pads get an exact distance test because a sample
            -- point can sit up to half a cell diagonal closer than its cell
            -- centre, which is enough to graze the clearance limit.
            infl = rcWidth cfg / 2 + rcClearance cfg + 0.01
            lineOk nid l p q =
              let n = max 1 (ceiling (dist p q / (rcPitch cfg / 3))) :: Int
                  search = Search grid cfg nid occ IM.empty 0
                  netName = head ([ nm | (nm, i) <- M.toList netIds, i == nid ] ++ [T.empty])
                  foreignPads = [ pd | pd <- rpPads prob, pgNet pd /= Just netName, ixLayer l `elem` pgLayers pd ]
                  ok pt@(x, y) =
                    let cx = floor (x / rcPitch cfg); cy = floor (y / rcPitch cfg)
                    in cx >= 0 && cy >= 0 && cx < gW grid && cy < gH grid
                       && let c = cellIdx grid l cx cy
                          in traversable search c && otherNetsAt occ nid c == 0
                       && all (\pd -> distToShape (pgShape pd) (pgAt pd) pt > infl) foreignPads
              in all ok [ (fst p + (fst q - fst p) * t, snd p + (snd q - snd p) * t)
                        | i <- [0 .. n], let t = fromIntegral i / fromIntegral n ]
        in RouteResult
             { rrNets = [ toRouted grid cfg (lineOk (netIds M.! n)) n (terms M.! n) (nsPaths st)
                        | (n, st) <- M.toList states, not (nsFailed st) ]
             , rrFailed = [ n | (n, st) <- M.toList states, nsFailed st ] ++ missing
             , rrConflicts = contested
             , rrIterations = iter
             , rrLog = reverse logAcc
             }
  in loop 1 occ0 IM.empty initial []

-- | Cells a straight hand-drawn segment passes through (Bresenham-ish
-- sampling at half a cell).
rasterSegment :: Grid -> Pt -> Pt -> [(Int, Int)]
rasterSegment g p1 p2 =
  let n = max 1 (ceiling (dist p1 p2 / (gPitch g / 2))) :: Int
      pts = [ (fst p1 + (fst p2 - fst p1) * t, snd p1 + (snd p2 - snd p1) * t) | i <- [0 .. n], let t = fromIntegral i / fromIntegral n ]
      toCell (x, y) = (max 0 (min (gW g - 1) (floor (x / gPitch g))), max 0 (min (gH g - 1) (floor (y / gPitch g))))
  in IS.toList (IS.fromList (map (\c -> let (x, y) = toCell c in y * gW g + x) pts))
     >>= \i -> [ (i `mod` gW g, i `div` gW g) ]

viasOf :: Grid -> [[Int]] -> [(Int, Int, Int)]
viasOf g paths =
  [ (l1, x1, y1)
  | p <- paths, (a, b) <- zip p (drop 1 p)
  , let (l1, x1, y1) = cellCoords g a, let (l2, _, _) = cellCoords g b
  , l1 /= l2 ]

-- | Turn cell paths into straight traces and vias, snapping the ends onto
-- pad centres so the copper lands where KiCad expects it.
toRouted :: Grid -> RouteConfig -> (Int -> Pt -> Pt -> Bool) -> Text -> [Terminal] -> [[Int]] -> RoutedNet
toRouted g cfg lineOk net terms paths =
  RoutedNet net (concatMap tracesOf paths) [ RVia net (cellCentre g x y) (rcViaDiameter cfg) (rcViaDrill cfg) | (_, x, y) <- viasOf g paths ]
  where
    padCentreOf c = case [ tCentre t | t <- terms, IS.member c (tCells t) ] of
      (p : _) -> Just p
      []      -> Nothing

    tracesOf path =
      let cells = map (cellCoords g) path
          runs = splitLayers cells
      in concat
           [ let pts = map (\(_, x, y) -> cellCentre g x y) run
                 pts' = pull l (simplify pts)
                 startSnap = [ p | isFirst, Just p <- [padCentreOf (head path)], p /= head pts' ]
                 endSnap = [ p | isLast, Just p <- [padCentreOf (last path)], p /= last pts' ]
                 full = startSnap ++ pts' ++ endSnap
             in [ RTrace net (ixLayer l) (rcWidth cfg) full | length full >= 2 ]
           | (i, run@((l, _, _) : _)) <- zip [0 :: Int ..] runs
           , let isFirst = i == 0, let isLast = i == length runs - 1 ]

    splitLayers [] = []
    splitLayers (c@(l, _, _) : cs) =
      let (same, rest) = span (\(l', _, _) -> l' == l) cs
      in (c : same) : splitLayers rest

    -- String pulling: from each point, jump to the farthest later point the
    -- trace can reach in a straight line. Turns grid staircases into the
    -- any-angle runs a person would draw.
    pull _ [] = []
    pull _ [p] = [p]
    pull l (p : rest) =
      let candidates = reverse (zip [1 :: Int ..] rest)
          (_, q) = head ([ c | c@(_, q') <- candidates, lineOk l p q' ] ++ [head (zip [1 ..] rest)])
          remaining = dropWhile (/= q) rest
      in p : pull l remaining

    -- Merge collinear steps into single segments.
    simplify (a : b : c : rest)
      | collinear a b c = simplify (a : c : rest)
      | otherwise       = a : simplify (b : c : rest)
    simplify xs = xs
    collinear (x1, y1) (x2, y2) (x3, y3) =
      abs ((x2 - x1) * (y3 - y1) - (y2 - y1) * (x3 - x1)) < 1e-9
