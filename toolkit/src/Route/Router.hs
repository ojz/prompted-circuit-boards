{-# LANGUAGE BangPatterns, FlexibleContexts, OverloadedStrings, ScopedTypeVariables #-}
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
  , routeReport
  , mstLength
  , preRoutedBlocked
  ) where

import           Control.Monad      (forM_, unless, when)
import           Control.Monad.ST   (ST, runST)
import           Data.Array.ST      (STUArray, newArray, readArray, writeArray, getBounds)
import           Data.Array.Unboxed
import qualified Data.IntMap.Strict as IM
import           Data.STRef         (STRef, newSTRef, readSTRef, writeSTRef)
import qualified Data.IntSet        as IS
import           Data.List          (foldl', minimumBy, sortOn)
import           Numeric            (showFFloat)
import qualified Data.Map.Strict    as M
import           Data.Maybe         (fromMaybe, mapMaybe)
import           Data.Ord           (comparing)
import qualified Data.Set           as S
import           Data.Text          (Text)
import qualified Data.Text          as T

import           Route.Check
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
  -- 40 cells, about 8 mm of trace, and still a guess. Swept from 10 to 320
  -- over every benchmark board (`pcbgen sweep-via`). No value is undominated
  -- everywhere: 40 gives the fewest vias on route-test and is beaten on both
  -- axes by 25 and 30 on the attenuverter and the reversal fixture, while 20
  -- wins route-test and then spends 51 vias on reversal where 25 spends 9.
  -- That spread is too wide to tune against five boards without fitting
  -- noise, and nothing yet prices a via against a millimetre of copper, so
  -- this waits for an objective rather than a better guess.
  , rcViaDiameter = 0.6, rcViaDrill = 0.3, rcViaCost = 40
  -- The loop exits as soon as nothing is contested, so a board that settles
  -- early (every real module so far, in 1 to 25 rounds) pays nothing for a
  -- generous budget. 600 rather than 200 because the sweep found via costs
  -- where 200 rounds stop one cell short, and since history congestion was
  -- put in the same currency as present congestion the budget is what
  -- convergence actually depends on.
  , rcNets = nets, rcMaxIterations = 600 }

data RouteProblem = RouteProblem
  { rpOutline  :: Outline
  , rpPads     :: [PadGeom]     -- ^ every pad on the board, routed nets or not
  , rpKeepouts :: [Keepout]
  , rpPreRouted :: [(Text, Layer, Double, [Pt])]  -- ^ hand-drawn traces: (net, layer, width, path)
  }

data RoutedNet = RoutedNet
  { rnNet    :: Text
  , rnTraces :: [RTrace]
  , rnVias   :: [RVia]
  , rnIdeal  :: Double     -- ^ Euclidean minimum spanning tree of the pad centres, mm
  } deriving (Show)

data RouteResult = RouteResult
  { rrNets       :: [RoutedNet]
  , rrFailed     :: [Text]      -- ^ nets with a terminal that could not be reached
  , rrConflicts  :: Int         -- ^ contested cells left after the last iteration
  , rrViaPad     :: [ViaPadViolation]
    -- ^ vias inside or against any pad (checked on the final geometry, not the grid)
  , rrDisconnected :: [Text]
    -- ^ routed nets whose pads, traces (hand-drawn included) and vias do not form one copper island
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
  , gViaNear :: !(UArray Int Int)  -- ^ same, inflated for a via's larger radius
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
      blank = listArray (0, size - 1) (replicate size 0) :: UArray Int Int
      g0 = Grid w h pitch blank blank blank
      halfW = rcWidth cfg / 2
      infl = halfW + rcClearance cfg
      viaInfl = rcViaDiameter cfg / 2 + rcClearance cfg + 0.75 * pitch

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
      -- A via is a through-hole: it must clear pads on both layers, with its
      -- own, larger radius. Hard obstacles block vias too.
      viaWrites = concat
        [ [ (cellIdx g0 l x y, nid)
          | l <- [0 .. nLayers - 1], (x, y) <- cellsAround g0 (pgAt p) (shapeRadius (pgShape p) + viaInfl + pitch)
          , distToShape (pgShape p) (pgAt p) (cellCentre g0 x y) <= viaInfl ]
        | p <- rpPads prob, let nid = maybe (-1) netId (pgNet p), nid /= 0 ]
      viaArr = accumArray merge 0 (0, size - 1) viaWrites :: UArray Int Int
  in g0 { gOwner = ownerArr, gNear = nearArr, gViaNear = viaArr }

-- Occupancy of routed copper --------------------------------------------------

-- | cell -> net -> stamp count. A stamp covers the trace plus the clearance
-- another trace centre must keep from it.
type Occ = IM.IntMap (IM.IntMap Int)

-- | The width is that of the copper being stamped; the halo keeps another
-- net's trace centre (of the configured width) clear of it.
stampCells :: Grid -> RouteConfig -> Double -> [(Int, Int, Int)] -> [(Int, Int, Int)] -> [Int]
stampCells g cfg width pathCells viaCells =
  let rTrace = width / 2 + rcWidth cfg / 2 + rcClearance cfg + rcPitch cfg   -- centre-to-centre minimum plus one cell of slack for smoothing
      rVia = rcViaDiameter cfg / 2 + rcWidth cfg / 2 + rcClearance cfg + rcPitch cfg
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
  , sPen    :: !(UArray Int Double)  -- ^ per-cell congestion penalty for this net and iteration
  }

traversable :: Search -> Int -> Bool
traversable s c =
  let o = gOwner (sGrid s) ! c
      n = gNear (sGrid s) ! c
  in (o == 0 || o == sNet s) && (n == 0 || n == sNet s)

-- | Flatten the negotiated-congestion state into one array per route call:
-- present-sharing penalty for every other net's copper here, plus the
-- accumulated history of past conflicts. The search then does one array
-- read per cell instead of two map lookups.
penaltyArray :: Grid -> Occ -> IM.IntMap Double -> Int -> Double -> UArray Int Double
penaltyArray g occ hist nid pres =
  let size = nLayers * gW g * gH g
      occW = [ (c, pres * fromIntegral k) | (c, m) <- IM.toList occ, let k = IM.size (IM.delete nid m), k > 0 ]
  in accumArray (+) 0 (0, size - 1) (occW ++ IM.toList hist)

-- Binary min-heap on (key, cell) in unboxed mutable arrays, growing by
-- doubling. Stale entries are tolerated: A* skips a popped cell that is
-- already closed.
data Heap s = Heap
  { hKeys :: STRef s (STUArray s Int Double)
  , hVals :: STRef s (STUArray s Int Int)
  , hSize :: STRef s Int
  }

newHeap :: Int -> ST s (Heap s)
newHeap cap = do
  ks <- newArray (0, cap - 1) 0
  vs <- newArray (0, cap - 1) 0
  Heap <$> newSTRef ks <*> newSTRef vs <*> newSTRef 0

heapPush :: Heap s -> Double -> Int -> ST s ()
heapPush h key val = do
  n <- readSTRef (hSize h)
  ks0 <- readSTRef (hKeys h)
  (_, hi) <- getBounds ks0
  when (n > hi) $ do
    vs0 <- readSTRef (hVals h)
    let cap' = 2 * (hi + 1)
    ks' <- newArray (0, cap' - 1) 0
    vs' <- newArray (0, cap' - 1) 0
    forM_ [0 .. hi] $ \i -> do
      readArray ks0 i >>= writeArray ks' i
      readArray vs0 i >>= writeArray vs' i
    writeSTRef (hKeys h) ks'
    writeSTRef (hVals h) vs'
  ks <- readSTRef (hKeys h)
  vs <- readSTRef (hVals h)
  writeSTRef (hSize h) (n + 1)
  let up i
        | i == 0 = writeArray ks i key >> writeArray vs i val
        | otherwise = do
            let p = (i - 1) `div` 2
            pk <- readArray ks p
            if pk <= key
              then writeArray ks i key >> writeArray vs i val
              else do
                readArray vs p >>= writeArray vs i
                writeArray ks i pk
                up p
  up n

heapPop :: Heap s -> ST s (Maybe (Double, Int))
heapPop h = do
  n <- readSTRef (hSize h)
  if n == 0 then return Nothing else do
    ks <- readSTRef (hKeys h)
    vs <- readSTRef (hVals h)
    topK <- readArray ks 0
    topV <- readArray vs 0
    let n' = n - 1
    writeSTRef (hSize h) n'
    when (n' > 0) $ do
      lastK <- readArray ks n'
      lastV <- readArray vs n'
      let down i = do
            let l = 2 * i + 1; r = l + 1
            if l >= n' then writeArray ks i lastK >> writeArray vs i lastV else do
              lk <- readArray ks l
              (ck, ci) <- if r < n'
                            then do rk <- readArray ks r
                                    return (if rk < lk then (rk, r) else (lk, l))
                            else return (lk, l)
              if ck < lastK
                then do writeArray ks i ck
                        readArray vs ci >>= writeArray vs i
                        down ci
                else writeArray ks i lastK >> writeArray vs i lastV
      down 0
    return (Just (topK, topV))

-- | Route from any source cell to any target cell. Returns the cell path,
-- source first. Mutable arrays throughout: this is the inner loop of the
-- whole router.
astar :: Search -> IS.IntSet -> IS.IntSet -> Pt -> Double -> Maybe [Int]
astar s sources targets targetCentre targetRadius = runST $ do
  let g = sGrid s
      w = gW g
      h = gH g
      size = nLayers * w * h
      pitch = gPitch g
      nid = sNet s
      owner = gOwner g
      near = gNear g
      viaNear = gViaNear g
      pen = sPen s
      viaCost = rcViaCost (sCfg s)
      layerStride = w * h
      -- Octile distance: exact for an eight-direction grid, so A* expands
      -- far fewer cells than with the Euclidean estimate. The target is a
      -- disc of cells; shrinking by its radius (times the worst-case
      -- octile/Euclidean ratio, 1.09) keeps the estimate admissible.
      (tx, ty) = targetCentre
      tr = 1.09 * targetRadius / pitch
      s2 = sqrt 2 :: Double
      heurXY x y = let (cx, cy) = cellCentre g x y
                       dx = abs (cx - tx) / pitch
                       dy = abs (cy - ty) / pitch
                   in max 0 (max dx dy + (s2 - 1) * min dx dy - tr)
      free c = let o = owner ! c; n = near ! c in (o == 0 || o == nid) && (n == 0 || n == nid)
      -- A via may only go where both layers are clear of every pad, its own
      -- net's included: a drill in an SMD solder land is not assemblable, and
      -- a via touching a through-hole pad is not the copper the design asked
      -- for either. gViaNear is inflated by via radius + clearance.
      viaOk c = viaNear ! c == 0 && owner ! c == 0
      dirs = [(1,0,1),(-1,0,1),(0,1,1),(0,-1,1),(1,1,s2),(1,-1,s2),(-1,1,s2),(-1,-1,s2)] :: [(Int, Int, Double)]
  gScore <- newArray (0, size - 1) (1 / 0) :: ST s (STUArray s Int Double)
  parent <- newArray (0, size - 1) (-1) :: ST s (STUArray s Int Int)
  closed <- newArray (0, size - 1) False :: ST s (STUArray s Int Bool)
  heap <- newHeap 4096
  forM_ (IS.toList sources) $ \c -> do
    let (_, x, y) = cellCoords g c
    writeArray gScore c 0
    heapPush heap (heurXY x y) c
  let relax c gc nc nx ny stepCost = when (free nc) $ do
        cl <- readArray closed nc
        unless cl $ do
          let tentative = gc + stepCost * (1 + pen ! nc)
          old <- readArray gScore nc
          when (tentative < old) $ do
            writeArray gScore nc tentative
            writeArray parent nc c
            heapPush heap (tentative + heurXY nx ny) nc
      walk c acc = do
        p <- readArray parent c
        if p < 0 then return (c : acc) else walk p (c : acc)
      loop = do
        mb <- heapPop heap
        case mb of
          Nothing -> return Nothing
          Just (_, c) -> do
            cl <- readArray closed c
            if cl then loop
            else if IS.member c targets then Just <$> walk c []
            else do
              writeArray closed c True
              gc <- readArray gScore c
              let (l, x, y) = cellCoords g c
              forM_ dirs $ \(dx, dy, len) -> do
                let nx = x + dx
                    ny = y + dy
                when (nx >= 0 && ny >= 0 && nx < w && ny < h) $
                  relax c gc (c + dy * w + dx) nx ny len
              let other = if l == 0 then c + layerStride else c - layerStride
              when (viaOk c && viaOk other) $ relax c gc other x y viaCost
              loop
  loop

-- Per-net routing -------------------------------------------------------------

data Terminal = Terminal
  { tCells  :: IS.IntSet
  , tCentre :: Pt
  , tRadius :: Double            -- ^ every cell centre lies within this of tCentre (A* heuristic)
  , tPads   :: [(IS.IntSet, Pt)] -- ^ pad cells and centre of each pad in this terminal, for snapping
  }

-- | Cells of one pad. Pads too small to own a cell centre get their centre
-- cell.
padCells :: Grid -> Int -> PadGeom -> IS.IntSet
padCells g nid p =
  let owned = IS.fromList [ cellIdx g (layerIx l) x y
                          | l <- pgLayers p, (x, y) <- cellsAround g (pgAt p) (shapeRadius (pgShape p) + gPitch g)
                          , gOwner g ! cellIdx g (layerIx l) x y == nid
                          , distToShape (pgShape p) (pgAt p) (cellCentre g x y) <= 0 ]
      (cx, cy) = pgAt p
      centreCell = IS.fromList [ cellIdx g (layerIx l) (clampX (floor (cx / gPitch g))) (clampY (floor (cy / gPitch g))) | l <- pgLayers p ]
  in if IS.null owned then centreCell else owned
  where
    clampX v = max 0 (min (gW g - 1) v)
    clampY v = max 0 (min (gH g - 1) v)

-- | The terminals of one net: every copper island the design already has.
-- A pad on its own is one terminal; pads joined by hand-drawn traces form one
-- terminal together with those traces; a hand-drawn trace touching no pad is
-- a terminal of its own and must be picked up too. Islands are found on the
-- real geometry ('copperComponents'), not on the grid.
terminalsFor :: Grid -> M.Map Text Int -> Text -> [PadGeom] -> [(Text, Layer, Double, [Pt])] -> [Terminal]
terminalsFor g netIds net allPads preRouted =
  let nid = fromMaybe 0 (M.lookup net netIds)
      pads = [ p | p <- allPads, pgNet p == Just net ]
      traces = [ (l, w, path) | (n, l, w, path) <- preRouted, n == net, length path >= 2 ]
      items = map CPad pads
           ++ [ CSeg l w a b | (l, w, path) <- traces, (a, b) <- zip path (drop 1 path) ]
      nPads = length pads
      -- segment index -> its trace index
      segTrace = concat [ replicate (length path - 1) ti | (ti, (_, _, path)) <- zip [0 :: Int ..] traces ]
      traceCells (l, _, path) = IS.fromList
        [ cellIdx g (layerIx l) x y | (p1, p2) <- zip path (drop 1 path), (x, y) <- rasterSegment g p1 p2 ]
      terminal comp =
        let padIxs = [ i | i <- comp, i < nPads ]
            traceIxs = S.toList (S.fromList [ segTrace !! (i - nPads) | i <- comp, i >= nPads ])
            padParts = [ (padCells g nid p, pgAt p) | i <- padIxs, let p = pads !! i ]
            cells = IS.unions (map fst padParts ++ [ traceCells (traces !! ti) | ti <- traceIxs ])
        in case (padIxs, traceIxs) of
             ([i], []) -> let p = pads !! i in Terminal cells (pgAt p) (shapeRadius (pgShape p)) padParts
             _ ->
               let pts = [ cellCentre g x y | c <- IS.toList cells, let (_, x, y) = cellCoords g c ]
                   xs = map fst pts; ys = map snd pts
                   centre = ((minimum xs + maximum xs) / 2, (minimum ys + maximum ys) / 2)
                   radius = maximum (0 : [ dist centre q | q <- pts ]) + gPitch g
               in Terminal cells centre radius padParts
  in if null items then [] else map terminal (copperComponents items)

-- | Connect all terminals of a net into one tree. Returns the cells of every
-- path segment (each path source-first), or the index of the terminal that
-- could not be reached.
routeNet :: Search -> [Terminal] -> Either Int [[Int]]
routeNet _ [] = Right []
routeNet s (t0 : rest) = go (tCells t0) rest []
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
      terms = M.fromList [ (n, terminalsFor grid netIds n (rpPads prob) (rpPreRouted prob)) | n <- toRoute ]
      padCentres n = [ pgAt p | p <- rpPads prob, pgNet p == Just n ]

      -- Hand-drawn traces count as existing copper of their net, each with
      -- its own width.
      occ0 = preRoutedOcc cfg prob grid netIds

      -- Short nets first: they have the fewest alternatives.
      order = sortOn (\n -> negate (length (terms M.! n))) toRoute

      initial = M.fromList [ (n, NetState [] [] [] False) | n <- toRoute ]

      loop iter occ hist states logAcc
        | iter > rcMaxIterations cfg = finish iter occ states (T.pack ("stopped after " ++ show (iter - 1) ++ " iterations") : logAcc)
        | otherwise =
            -- Present congestion: what sharing a cell costs *this* round. It
            -- grows so that early rounds let nets find their natural region
            -- and later ones force a decision. Capped because 1.4^2100
            -- overflows a Double to infinity, which would poison every cost.
            let pres = 0.5 * 1.4 ^^ min 500 (iter - 1)
                -- Rip up and reroute only the nets that are in conflict (or
                -- failed); settled nets keep their copper. Iteration one
                -- routes everything.
                redo = [ n | n <- order, iter == 1 || nsFailed (states M.! n) || netContested occ n (states M.! n) ]
                (occ', states') = foldl' (routeOne pres hist) (occ, states) redo
                contested = contestedCells occ' states'
                -- History congestion, charged in the same currency as present
                -- congestion. Charging a flat 1 per round instead (as this did
                -- until it was measured) leaves history 27 orders of magnitude
                -- below the present term by round 200, so the negotiation has
                -- no memory and two nets simply trade places forever: the
                -- reversal fixture stalled with contested cells at via costs
                -- 15 and 30 and did not improve with ten times the budget.
                -- McMurchie & Ebeling's convergence argument needs a cell that
                -- has been fought over to stay expensive after it falls free.
                hist' = foldl' (\h c -> IM.insertWith (+) c pres h) hist contested
                msg = T.pack ("iteration " ++ show iter ++ ": rerouted " ++ show (length redo) ++ ", "
                              ++ show (length contested) ++ " contested cells")
            in if null contested
                 then finish iter occ' states' (msg : logAcc)
                 else loop (iter + 1) occ' hist' states' (msg : logAcc)

      routeOne pres hist (occ, states) n =
        let nid = netIds M.! n
            st = states M.! n
            occNo = removeStamps nid (nsStamps st) occ
            search = Search grid cfg nid (penaltyArray grid occNo hist nid pres)
        in case routeNet search (terms M.! n) of
             Left _ -> (occNo, M.insert n (NetState [] [] [] True) states)
             Right paths ->
               let cells = [ cellCoords grid c | p <- paths, c <- p ]
                   vias = viasOf grid paths
                   stamps = stampCells grid cfg (rcWidth cfg) cells vias
               in (addStamps nid stamps occNo, M.insert n (NetState paths stamps vias False) states)

      -- A conflict is a trace centre (or via) of one net lying inside the
      -- clearance halo another net has stamped. Halos overlapping each other
      -- is normal for two legally spaced traces.
      copperCells st = concat (nsPaths st) ++ [ cellIdx grid l x y | (_, x, y) <- nsVias st, l <- [0 .. nLayers - 1] ]
      netContested occ n st = any (\c -> otherNetsAt occ (netIds M.! n) c > 0) (copperCells st)
      contestedCells occ states =
        [ c
        | (n, st) <- M.toList states, not (nsFailed st)
        , let nid = netIds M.! n
        , c <- copperCells st
        , otherNetsAt occ nid c > 0 ]

      finish iter occ states logAcc =
        let contested = length (contestedCells occ states)
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
                  search = Search grid cfg nid (listArray (0, -1) [])
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
            routed = [ toRouted grid cfg (lineOk (netIds M.! n)) n (terms M.! n) (padCentres n) (nsPaths st)
                     | (n, st) <- M.toList states, not (nsFailed st) ]
            -- Final geometry checks, independent of the grid bookkeeping:
            -- vias against every pad, and one copper island per net over
            -- pads, hand-drawn traces (their own widths), routed traces
            -- and vias.
            preTraces = [ RTrace n l w path | (n, l, w, path) <- rpPreRouted prob ]
            disconnected = [ rnNet rn | rn <- routed
                           , not (isConnected (netCopper (rnNet rn) (rpPads prob) (preTraces ++ rnTraces rn) (rnVias rn))) ]
        in RouteResult
             { rrNets = routed
             , rrFailed = [ n | (n, st) <- M.toList states, nsFailed st ] ++ missing
             , rrConflicts = contested
             , rrViaPad = viaPadViolations (rcClearance cfg) (rpPads prob) (concatMap rnVias routed)
             , rrDisconnected = disconnected
             , rrIterations = iter
             , rrLog = reverse logAcc
             }
  in loop 1 occ0 IM.empty initial []

-- | Occupancy stamped by the hand-drawn traces, each with its own width.
preRoutedOcc :: RouteConfig -> RouteProblem -> Grid -> M.Map Text Int -> Occ
preRoutedOcc cfg prob grid netIds =
  foldl' (\o (n, l, w, path) ->
            let nid = netIds M.! n
                cells = [ (layerIx l, x, y) | (p1, p2) <- zip path (drop 1 path), (x, y) <- rasterSegment grid p1 p2 ]
            in addStamps nid (stampCells grid cfg w cells []) o)
         IM.empty
         [ t | t@(n, _, _, _) <- rpPreRouted prob, M.member n netIds ]

-- | Would a trace centre of the configured width at this point contest the
-- hand-drawn copper of some net? Exposes the pre-routed stamping (and so the
-- manual trace widths) to tests without running the router.
preRoutedBlocked :: RouteConfig -> RouteProblem -> Layer -> Pt -> Bool
preRoutedBlocked cfg prob l (x, y) =
  let allNets = S.toList (S.fromList (mapMaybe pgNet (rpPads prob) ++ [ n | (n, _, _, _) <- rpPreRouted prob ]))
      netIds = M.fromList (zip allNets [1 ..])
      grid = buildGrid cfg prob netIds
      occ = preRoutedOcc cfg prob grid netIds
      cx = floor (x / gPitch grid); cy = floor (y / gPitch grid)
  in cx >= 0 && cy >= 0 && cx < gW grid && cy < gH grid
     && otherNetsAt occ 0 (cellIdx grid (layerIx l) cx cy) > 0

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
toRouted :: Grid -> RouteConfig -> (Int -> Pt -> Pt -> Bool) -> Text -> [Terminal] -> [Pt] -> [[Int]] -> RoutedNet
toRouted g cfg lineOk net terms padPts paths =
  RoutedNet net (concatMap tracesOf paths)
            [ RVia net (cellCentre g x y) (rcViaDiameter cfg) (rcViaDrill cfg) | (_, x, y) <- viasOf g paths ]
            (mstLength padPts)
  where
    padCentreOf c = case [ centre | t <- terms, (cells, centre) <- tPads t, IS.member c cells ] of
      (p : _) -> Just p
      []      -> Nothing

    -- Cells where a later path of this net branches off an earlier one. They
    -- must survive pulling and simplification as vertices, or the branch
    -- would start in mid-air next to the straightened parent trace.
    junctions = IS.fromList [ head p | p <- paths, not (null p) ]

    tracesOf path =
      let runs = splitLayers [ (c, cellCoords g c) | c <- path ]
      in concat
           [ let tagged = [ (cellCentre g x y, IS.member c junctions) | (c, (_, x, y)) <- run ]
                 pts' = pullKeep l tagged
                 startSnap = [ p | isFirst, Just p <- [padCentreOf (head path)], p /= head pts' ]
                 endSnap = [ p | isLast, Just p <- [padCentreOf (last path)], p /= last pts' ]
                 full = startSnap ++ pts' ++ endSnap
             in [ RTrace net (ixLayer l) (rcWidth cfg) full | length full >= 2 ]
           | (i, run@((_, (l, _, _)) : _)) <- zip [0 :: Int ..] runs
           , let isFirst = i == 0, let isLast = i == length runs - 1 ]

    splitLayers [] = []
    splitLayers (c@(_, (l, _, _)) : cs) =
      let (same, rest) = span (\(_, (l', _, _)) -> l' == l) cs
      in (c : same) : splitLayers rest

    -- Straighten each stretch between kept vertices on its own.
    pullKeep l tagged = joinPieces [ pull l (simplify (map fst piece)) | piece <- splitKeep tagged ]
    splitKeep [] = []
    splitKeep (x : xs) =
      let (body, rest) = break snd xs
      in case rest of
           []       -> [x : body]
           (k : ks) -> (x : body ++ [k]) : splitKeep (k : ks)
    joinPieces []       = []
    joinPieces [p]      = p
    joinPieces (p : ps) = p ++ drop 1 (joinPieces ps)

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

-- Score report ----------------------------------------------------------------

-- | Length of the Euclidean minimum spanning tree over a point set (Prim).
-- The shortest any routing of the net could possibly be, so a natural
-- yardstick for detours.
mstLength :: [Pt] -> Double
mstLength [] = 0
mstLength (p0 : ps) = go [p0] ps 0
  where
    go _ [] acc = acc
    go tree rest acc =
      let (d, q) = minimum [ (dist t r, r) | r <- rest, t <- tree ]
      in go (q : tree) (filter (/= q) rest) (acc + d)

-- | Markdown table with one row per routed net plus totals. The name mapper
-- turns board net names back into design names.
routeReport :: (Text -> Text) -> RouteResult -> Text
routeReport nameOf res = T.unlines $
  [ "| Net | Layers | Segments | Vias | Length mm | Ideal mm | Detour |"
  , "|---|---|--:|--:|--:|--:|--:|" ]
  ++ [ row (nameOf (rnNet rn)) (layersOf rn) (segs rn) (length (rnVias rn)) (len rn) (rnIdeal rn) | rn <- nets ]
  ++ [ row "**total**" "" (sum (map segs nets)) (sum (map (length . rnVias) nets)) (sum (map len nets)) (sum (map rnIdeal nets)) ]
  ++ [ ""
     , T.pack ("Iterations: " ++ show (rrIterations res) ++ ". Contested cells left: " ++ show (rrConflicts res) ++ ".")
     ]
  ++ [ "Failed nets: " <> T.intercalate ", " (map nameOf (rrFailed res)) | not (null (rrFailed res)) ]
  ++ [ T.pack ("Via/pad violations: " ++ show (length (rrViaPad res)) ++ ".") ]
  ++ [ "  " <> describeViaPad v | v <- rrViaPad res ]
  ++ [ "Disconnected nets: " <> (if null (rrDisconnected res) then "none" else T.intercalate ", " (map nameOf (rrDisconnected res))) <> "." ]
  where
    nets = sortOn rnNet (rrNets res)
    segs rn = sum [ length (rtPath t) - 1 | t <- rnTraces rn ]
    len rn = sum [ dist a b | t <- rnTraces rn, (a, b) <- zip (rtPath t) (drop 1 (rtPath t)) ]
    layersOf rn = T.intercalate "+" [ l | (l, ly) <- [("F", F), ("B", B)], any ((== ly) . rtLayer) (rnTraces rn) ]
    f2 x = T.pack (showFFloat (Just 2) x "")
    ratio a b = if b <= 0 then "-" else f2 (a / b)
    row n ls sg vs l ideal = T.concat
      [ "| ", n, " | ", ls, " | ", T.pack (show sg), " | ", T.pack (show vs), " | ", f2 l, " | ", f2 ideal, " | ", ratio l ideal, " |" ]
