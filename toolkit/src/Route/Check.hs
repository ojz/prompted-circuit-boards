-- | Geometry checks on routed copper that do not trust the router's own
-- bookkeeping: via-in-pad detection and per-net connectivity over the real
-- shapes. Everything works on board coordinates in millimetres.
module Route.Check
  ( ViaPadViolation (..)
  , viaPadViolations
  , describeViaPad
  , Copper (..)
  , copperLayers
  , copperGap
  , copperComponents
  , isConnected
  , netCopper
  ) where

import qualified Data.IntMap.Strict as IM
import qualified Data.IntSet        as IS
import           Data.Text          (Text)
import qualified Data.Text          as T
import           Numeric            (showFFloat)

import           Route.Geometry

-- Via in pad --------------------------------------------------------------------

-- | A via whose copper disc plus clearance reaches into a pad's copper.
data ViaPadViolation = ViaPadViolation
  { vpNet       :: Text
  , vpAt        :: Pt
  , vpPadRef    :: Text
  , vpPadNumber :: Text
  , vpPadNet    :: Maybe Text
  , vpLayers    :: [Layer]      -- ^ layers the pad occupies
  , vpGap       :: Double       -- ^ pad edge to via edge; negative when the copper overlaps
  } deriving (Show)

-- | Every (via, pad) pair whose copper comes closer than the clearance on a
-- layer the pad occupies. A via is a through-hole, so it is present on both
-- layers; own-net pads count too, because an ordinary assembly process does
-- not allow a drill inside an SMD solder land and a same-net via touching a
-- pad is what KiCad's DRC silently accepts.
viaPadViolations :: Double -> [PadGeom] -> [RVia] -> [ViaPadViolation]
viaPadViolations clearance pads vias =
  [ ViaPadViolation (rvNet v) (rvAt v) (pgRef p) (pgNumber p) (pgNet p) (pgLayers p) gap
  | v <- vias
  , p <- pads
  , not (null (pgLayers p))
  , let gap = distToShape (pgShape p) (pgAt p) (rvAt v) - rvDiameter v / 2
  , gap < clearance - 1e-9
  ]

describeViaPad :: ViaPadViolation -> Text
describeViaPad v = T.pack $ concat
  [ "via of ", T.unpack (vpNet v), " at (", f2 (fst (vpAt v)), ", ", f2 (snd (vpAt v)), ") "
  , if vpGap v < 0 then "inside" else "against", " pad "
  , T.unpack (vpPadRef v), ".", T.unpack (vpPadNumber v)
  , maybe "" (\n -> " (" ++ T.unpack n ++ ")") (vpPadNet v)
  , ", gap ", f2 (vpGap v), " mm" ]
  where f2 x = showFFloat (Just 2) x ""

-- Connectivity ------------------------------------------------------------------

-- | One piece of copper. Segments carry their own width; a via is a disc on
-- both layers.
data Copper
  = CPad PadGeom
  | CSeg Layer Double Pt Pt     -- ^ layer, width, ends
  | CVia Pt Double              -- ^ centre, diameter
  deriving (Show)

copperLayers :: Copper -> [Layer]
copperLayers (CPad p)       = pgLayers p
copperLayers (CSeg l _ _ _) = [l]
copperLayers (CVia _ _)     = [F, B]

-- | Gap between the copper of two items, ignoring layers: zero or negative
-- when they touch. Pad-to-pad uses the inscribed radii, so two pads count
-- as touching only when they really overlap; a false disconnect is the
-- worse error here, and pads of one net are normally joined by traces.
copperGap :: Copper -> Copper -> Double
copperGap a b = case (a, b) of
  (CPad p, CPad q) ->
    minimum [ dist (pgAt p) (pgAt q) - shapeInRadius (pgShape p) - shapeInRadius (pgShape q)
            , distToShape (pgShape p) (pgAt p) (pgAt q)
            , distToShape (pgShape q) (pgAt q) (pgAt p) ]
  (CPad p, CSeg _ w s e) -> minSegShapeDist (pgShape p) (pgAt p) s e - w / 2
  (CPad p, CVia c d) -> distToShape (pgShape p) (pgAt p) c - d / 2
  (CSeg _ w1 s1 e1, CSeg _ w2 s2 e2) -> segSegDist (s1, e1) (s2, e2) - (w1 + w2) / 2
  (CSeg _ w s e, CVia c d) -> segPointDist s e c - w / 2 - d / 2
  (CVia c1 d1, CVia c2 d2) -> dist c1 c2 - (d1 + d2) / 2
  _ -> copperGap b a

touches :: Copper -> Copper -> Bool
touches a b = any (`elem` copperLayers b) (copperLayers a) && copperGap a b <= 1e-6

-- | Connected components of a copper set, as index lists into the input.
copperComponents :: [Copper] -> [[Int]]
copperComponents items =
  let ixs = zip [0 ..] items
      adj = IM.fromListWith (++)
              (concat [ [(i, [j]), (j, [i])] | (i, a) <- ixs, (j, b) <- ixs, i < j, touches a b ])
      go seen [] acc = (seen, acc)
      go seen (c : cs) acc
        | IS.member c seen = go seen cs acc
        | otherwise = go (IS.insert c seen) (IM.findWithDefault [] c adj ++ cs) (c : acc)
      collect _ [] = []
      collect seen (i : rest)
        | IS.member i seen = collect seen rest
        | otherwise = let (seen', comp) = go seen [i] [] in comp : collect seen' rest
  in collect IS.empty (map fst ixs)

-- | A net is connected when all its copper forms a single component.
isConnected :: [Copper] -> Bool
isConnected items = length (copperComponents items) <= 1

-- | All copper belonging to one net.
netCopper :: Text -> [PadGeom] -> [RTrace] -> [RVia] -> [Copper]
netCopper net pads traces vias =
  [ CPad p | p <- pads, pgNet p == Just net ]
  ++ [ CSeg (rtLayer t) (rtWidth t) a b | t <- traces, rtNet t == net, (a, b) <- zip (rtPath t) (drop 1 (rtPath t)) ]
  ++ [ CVia (rvAt v) (rvDiameter v) | v <- vias, rvNet v == net ]
