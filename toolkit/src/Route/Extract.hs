{-# LANGUAGE OverloadedStrings #-}
-- | Pull router geometry out of placed footprints (the s-expressions the
-- board emitter writes): pads in board coordinates with their nets, and
-- track keep-out zones.
module Route.Extract
  ( padsOfFootprint
  , keepoutsOfFootprint
  ) where

import           Data.Maybe     (fromMaybe, mapMaybe)
import           Data.Text      (Text)
import qualified Data.Text      as T

import           Kicad.SExpr
import           Route.Geometry

readNum :: SExpr -> Double
readNum e = case atomText e of
  Just t -> case reads (T.unpack (fixup t)) of
    [(d, "")] -> d
    _         -> 0
  Nothing -> 0
  where
    fixup t
      | Just r <- T.stripPrefix "-." t = "-0." <> r
      | Just r <- T.stripPrefix "." t  = "0." <> r
      | otherwise                      = t

footprintAt :: SExpr -> (Pt, Double)
footprintAt fp = case findChild "at" fp of
  Just (List [_, ax, ay])     -> ((readNum ax, readNum ay), 0)
  Just (List [_, ax, ay, aa]) -> ((readNum ax, readNum ay), readNum aa)
  _                           -> ((0, 0), 0)

footprintRef :: SExpr -> Text
footprintRef fp = fromMaybe "?" $ case [ v | List (Atom "property" : Str "Reference" : Str v : _) <- children fp ] of
  (v : _) -> Just v
  []      -> Nothing

layersOf :: SExpr -> [Layer]
layersOf pad = case findChild "layers" pad of
  Just (List (_ : ls)) ->
    let names = mapMaybe atomText ls
        has p = any p names
    in if has (== "*.Cu") then [F, B]
       else [ F | has (== "F.Cu") ] ++ [ B | has (== "B.Cu") ]
  _ -> [F, B]

padsOfFootprint :: SExpr -> [PadGeom]
padsOfFootprint fp =
  let (pos, rot) = footprintAt fp
      ref = footprintRef fp
  in mapMaybe (padGeom ref pos rot) (children fp)

padGeom :: Text -> Pt -> Double -> SExpr -> Maybe PadGeom
padGeom ref pos rot pad@(List (Atom "pad" : Str number : Atom ptype : Atom pshape : _)) =
  let (lx, ly, pa) = case findChild "at" pad of
        Just (List [_, ax, ay])     -> (readNum ax, readNum ay, 0)
        Just (List [_, ax, ay, aa]) -> (readNum ax, readNum ay, readNum aa)
        _                           -> (0, 0, 0)
      (sw, sh) = case findChild "size" pad of
        Just (List [_, aw, ah]) -> (readNum aw, readNum ah)
        _                       -> (0, 0)
      drill = case findChild "drill" pad of
        Just (List (_ : d : _)) | Just _ <- atomText d -> readNum d
        _                                              -> 0
      rratio = case findChild "roundrect_rratio" pad of
        Just (List [_, r]) -> readNum r
        _                  -> 0.25
      at = addPt pos (rotatePt rot (lx, ly))
      shape = case pshape of
        "circle"    -> Circle (sw / 2)
        "oval"      -> RoundRect sw sh (min sw sh / 2) pa
        "roundrect" -> RoundRect sw sh (min sw sh * rratio) pa
        _           -> Rect sw sh pa
      net = case findChild "net" pad of
        Just (List [_, Str n]) -> Just n
        _                      -> Nothing
      isNpth = ptype == "np_thru_hole"
      shape' = if isNpth && sw == 0 then Circle (drill / 2) else shape
  in Just PadGeom
       { pgRef = ref, pgNumber = number
       , pgNet = if isNpth then Nothing else net
       , pgAt = at, pgShape = shape', pgLayers = if isNpth then [F, B] else layersOf pad }
padGeom _ _ _ _ = Nothing

-- | Track keep-outs declared inside the footprint (already in board
-- coordinates in the emitted file).
keepoutsOfFootprint :: SExpr -> [Keepout]
keepoutsOfFootprint fp =
  [ Keepout layers poly
  | z@(List (Atom "zone" : _)) <- children fp
  , Just ko <- [findChild "keepout" z]
  , any (\c -> case c of List [Atom "tracks", Atom "not_allowed"] -> True; _ -> False) (children ko)
  , let layers = case findChild "layer" z of
          Just (List [_, Str l]) -> [ F | l == "F.Cu" ] ++ [ B | l == "B.Cu" ]
          _ -> case findChild "layers" z of
                 Just (List (_ : ls)) -> concat [ [F | l == "F.Cu" || l == "*.Cu"] ++ [B | l == "B.Cu" || l == "*.Cu"] | Str l <- ls ]
                 _ -> [F, B]
  , let poly = [ (readNum ax, readNum ay)
               | Just pg <- [findChild "polygon" z], Just (List (_ : xys)) <- [findChild "pts" pg]
               , List [Atom "xy", ax, ay] <- xys ]
  , length poly >= 3
  ]
