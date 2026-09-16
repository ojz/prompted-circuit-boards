{-# LANGUAGE OverloadedStrings #-}
-- | The sketch format: a grid of cells, and what is in them.
--
-- @
-- { "format": "module-sketch", "version": 2, "name": "Mixer",
--   "columns": 4, "rows": 6,
--   "cells": [ { "col": 0, "row": 0, "kind": "knob", "label": "LEVEL" } ] }
-- @
--
-- That is the whole format. A cell holds one component or nothing, so the
-- overlaps and clearances an earlier version checked for cannot be expressed
-- in the first place. What remains is structural: the grid is within the
-- limits 'Sketch.Catalogue' derives, every cell is on it, and no two cells
-- are the same one.
--
-- It says nothing about millimetres, part numbers, nets or circuits. It is a
-- panel idea.
module Sketch.Model
  ( Sketch (..)
  , Cell (..)
  , formatName
  , formatVersion
  , decodeSketch
  , decodeSketchText
  , encodeSketch
  , encodeSketchText
  , cellAt
  , impliedWidth
  ) where

import           Data.List (sort, sortOn)
import           Data.Text (Text)
import qualified Data.Text as T

import           Sketch.Catalogue
import           Sketch.Json

data Sketch = Sketch
  { sxName    :: Text
  , sxColumns :: Int
  , sxRows    :: Int
  , sxCells   :: [Cell]
  } deriving (Eq, Show)

data Cell = Cell
  { clCol   :: Int
  , clRow   :: Int
  , clKind  :: Kind
  , clLabel :: Text
  } deriving (Eq, Show)

formatName :: Text
formatName = "module-sketch"

formatVersion :: Int
formatVersion = 2

cellAt :: Sketch -> Int -> Int -> Maybe Cell
cellAt s c r = case [ x | x <- sxCells s, clCol x == c, clRow x == r ] of
  (x : _) -> Just x
  []      -> Nothing

-- | The narrowest panel that holds this many columns, which is the only
-- thing a sketch says about physical size.
impliedWidth :: Sketch -> Maybe Int
impliedWidth = smallestWidthFor . sxColumns

-- Decoding ---------------------------------------------------------------------

decodeSketchText :: Text -> Either [Text] Sketch
decodeSketchText txt = either (Left . pure) decodeSketch (parseJson txt)

-- | Every problem at once, each naming where it is.
decodeSketch :: JValue -> Either [Text] Sketch
decodeSketch v = do
  kvs <- case v of
           JObject kvs -> Right kvs
           _           -> Left ["the sketch must be a JSON object"]
  let known = ["format", "version", "name", "columns", "rows", "cells"]
      unknown = [ "unknown field " <> k | (k, _) <- kvs, k `notElem` known ]
      header = concat
        [ case lookup "format" kvs of
            Just (JString s) | s == formatName -> []
            Just (JString s) -> ["format: expected " <> tshow formatName <> ", got " <> tshow s]
            Just _ -> ["format: expected a string"]
            Nothing -> ["missing field format"]
        , case lookup "version" kvs of
            Just (JNumber n) | n == fromIntegral formatVersion -> []
            Just (JNumber n) -> ["version: only version " <> tshow formatVersion <> " is understood, got " <> renderNumber n]
            Just _ -> ["version: expected a number"]
            Nothing -> ["missing field version"]
        ]
  case unknown ++ header of
    (e : es) -> Left (e : es)
    []       -> pure ()

  let nameE = case lookup "name" kvs of
        Nothing -> Right ""
        Just (JString s) -> Right s
        Just _ -> Left "name: expected a string"
      colsE = dimension "columns" (lookup "columns" kvs) maxColumns
      rowsE = dimension "rows" (lookup "rows" kvs) maxRows
  (name, cols, rows) <- three nameE colsE rowsE

  cellsV <- case lookup "cells" kvs of
    Nothing -> Left ["missing field cells"]
    Just (JArray xs) -> Right xs
    Just _ -> Left ["cells: expected an array"]
  cells <- collect [ decodeCell ("cells[" <> tshow i <> "]") cols rows x | (i, x) <- zip [0 :: Int ..] cellsV ]

  let occupied = [ (clCol c, clRow c) | c <- cells ]
      dups = [ p | (p, q) <- zip (sort occupied) (drop 1 (sort occupied)), p == q ]
      clashes = [ "cells: " <> tshow c <> ", " <> tshow r <> " holds more than one component"
                | (c, r) <- take 1 dups ]
  if null clashes
    then Right (Sketch name cols rows cells)
    else Left clashes
  where
    three a b c = case (a, b, c) of
      (Right x, Right y, Right z) -> Right (x, y, z)
      _ -> Left ([ e | Left e <- [a] ] ++ [ e | Left e <- [b] ] ++ [ e | Left e <- [c] ])

-- | A grid dimension: a whole number from 1 to the derived maximum.
dimension :: Text -> Maybe JValue -> Int -> Either Text Int
dimension field Nothing _ = Left ("missing field " <> field)
dimension field (Just (JNumber n)) limit
  | n /= fromIntegral (round n :: Int) = Left (field <> ": expected a whole number, got " <> renderNumber n)
  | k < 1 = Left (field <> ": must be at least 1")
  | k > limit = Left (field <> ": at most " <> tshow limit <> " fit a Eurorack module, asked for " <> tshow k)
  | otherwise = Right k
  where k = round n :: Int
dimension field (Just _) _ = Left (field <> ": expected a number")

decodeCell :: Text -> Int -> Int -> JValue -> Either Text Cell
decodeCell path cols rows v = do
  kvs <- case v of
           JObject kvs -> Right kvs
           _           -> Left (path <> ": expected an object")
  case [ k | (k, _) <- kvs, k `notElem` ["col", "row", "kind", "label"] ] of
    (k : _) -> Left (path <> ": unknown field " <> k)
    []      -> pure ()
  col <- coord (path <> ".col") (lookup "col" kvs) cols
  row <- coord (path <> ".row") (lookup "row" kvs) rows
  kind <- case lookup "kind" kvs of
    Nothing -> Left (path <> ": missing field kind")
    Just (JString s) -> maybe (Left (path <> ".kind: unknown kind " <> tshow s
                                     <> "; expected one of " <> T.intercalate ", " (map kindId kinds)))
                              Right (lookupKind s)
    Just _ -> Left (path <> ".kind: expected a string")
  label <- case lookup "label" kvs of
    Nothing -> Right ""
    Just (JString s) | T.length s <= 24 -> Right s
                     | otherwise -> Left (path <> ".label: at most 24 characters")
    Just _ -> Left (path <> ".label: expected a string")
  Right (Cell col row kind label)

coord :: Text -> Maybe JValue -> Int -> Either Text Int
coord path Nothing _ = Left (path <> ": missing")
coord path (Just (JNumber n)) limit
  | n /= fromIntegral (round n :: Int) = Left (path <> ": expected a whole number, got " <> renderNumber n)
  | k < 0 || k >= limit = Left (path <> ": " <> tshow k <> " is off a grid of " <> tshow limit)
  | otherwise = Right k
  where k = round n :: Int
coord path (Just _) _ = Left (path <> ": expected a number")

collect :: [Either Text a] -> Either [Text] [a]
collect rs = case [ e | Left e <- rs ] of
  [] -> Right [ a | Right a <- rs ]
  es -> Left es

tshow :: Show a => a -> Text
tshow = T.pack . show

-- Encoding ---------------------------------------------------------------------

encodeSketchText :: Sketch -> Text
encodeSketchText s = renderJson (encodeSketch s) <> "\n"

-- | Cells are written in reading order so two sketches of the same panel are
-- the same file however they were drawn.
encodeSketch :: Sketch -> JValue
encodeSketch s = JObject
  [ ("format", JString formatName)
  , ("version", JNumber (fromIntegral formatVersion))
  , ("name", JString (sxName s))
  , ("columns", JNumber (fromIntegral (sxColumns s)))
  , ("rows", JNumber (fromIntegral (sxRows s)))
  , ("cells", JArray [ encodeCell c | c <- reading (sxCells s) ])
  ]
  where reading = sortOn (\c -> (clRow c, clCol c))

encodeCell :: Cell -> JValue
encodeCell c = JObject $
  [ ("col", JNumber (fromIntegral (clCol c)))
  , ("row", JNumber (fromIntegral (clRow c)))
  , ("kind", JString (kindId (clKind c)))
  ] ++ [ ("label", JString (clLabel c)) | not (T.null (clLabel c)) ]
