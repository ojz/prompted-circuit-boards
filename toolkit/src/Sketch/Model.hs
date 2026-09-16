{-# LANGUAGE OverloadedStrings #-}
-- | The sketch interchange format (docs/ROADMAP.md, S1): a panel idea as
-- inert data. Width in HP, a provisional grid, and controls that occupy
-- cells and carry a hardware identity, a label and a functional group. It
-- describes where things stand on a panel; it names no circuit, net or part
-- number, and a sketch is never "manufacturing-ready": its status is either
-- provisional or reviewed.
--
-- Decoding is strict. Every diagnostic names the JSON path it concerns, and
-- a sketch with any diagnostic is not a sketch at all, so a browser or the
-- generator can never half-load one. Encoding is deterministic, and
-- @decode . encode@ is the identity the round-trip test guards.
module Sketch.Model
  ( Sketch (..)
  , Grid (..)
  , Control (..)
  , Group (..)
  , Status (..)
  , formatName
  , formatVersion
  , decodeSketch
  , decodeSketchText
  , encodeSketch
  , encodeSketchText
  , validIdentifier
  , controlCells
  ) where

import           Data.Char (isAlphaNum)
import           Data.List (nub, sort, (\\))
import           Data.Text (Text)
import qualified Data.Text as T

import           Sketch.Catalogue
import           Sketch.Json

data Status = Provisional | Reviewed
  deriving (Eq, Show)

data Sketch = Sketch
  { sxName     :: Text
  , sxStatus   :: Status
  , sxHP       :: Int
  , sxGrid     :: Grid
  , sxControls :: [Control]
  , sxGroups   :: [Group]
  , sxNotes    :: [Text]
  } deriving (Eq, Show)

-- | Where control centres are. Panel millimetres from the top-left corner,
-- viewed from the front, y downward (docs/MECHANICAL.md).
data Grid = Grid
  { grOrigin  :: (Double, Double)   -- ^ centre of cell (0, 0)
  , grPitch   :: (Double, Double)
  , grProfile :: Text               -- ^ a 'GridProfile' id, recorded for later re-laying
  } deriving (Eq, Show)

-- | A control occupies @span@ cells from @cell@ towards +col and +row; its
-- centre is the centre of that block plus @offset@, which is how an LED sits
-- diagonally off its jack inside the same cell.
data Control = Control
  { ctId       :: Text
  , ctHardware :: Text
  , ctCell     :: (Int, Int)        -- ^ (col, row)
  , ctSpan     :: (Int, Int)        -- ^ (cols, rows), each at least 1
  , ctOffset   :: (Double, Double)  -- ^ mm from the block centre
  , ctRotation :: Int               -- ^ degrees, one of the hardware's allowed values
  , ctLabel    :: Text
  , ctGroup    :: Maybe Text
  } deriving (Eq, Show)

data Group = Group
  { gpKey   :: Text
  , gpLabel :: Text
  } deriving (Eq, Show)

formatName :: Text
formatName = "pcbgen-sketch"

formatVersion :: Int
formatVersion = 1

-- | Identifiers are what a later design will map to parts, so they are kept
-- to the characters a Haskell string, a file name and a CSS id all accept.
validIdentifier :: Text -> Bool
validIdentifier t = not (T.null t) && T.length t <= 40 && T.all ok t
  where ok c = isAlphaNum c || c == '-' || c == '_'

-- | The cells a control reserves.
controlCells :: Control -> [(Int, Int)]
controlCells c =
  let (col, row) = ctCell c
      (cols, rows) = ctSpan c
  in [ (col + i, row + j) | i <- [0 .. cols - 1], j <- [0 .. rows - 1] ]

-- Decoding ---------------------------------------------------------------------

decodeSketchText :: Text -> Either [Text] Sketch
decodeSketchText txt = either (Left . pure) decodeSketch (parseJson txt)

-- | Every problem found, not just the first, so a hand-edited file can be
-- fixed in one pass.
decodeSketch :: JValue -> Either [Text] Sketch
decodeSketch v = do
  o <- case v of
         JObject _ -> Right v
         _         -> Left ["the sketch must be a JSON object"]
  let known = ["format", "version", "name", "status", "hp", "grid", "controls", "groups", "notes"]
      unknown = [ "unknown field " <> k | JObject kvs <- [o], (k, _) <- kvs, k `notElem` known ]
  _ <- collect
    [ field "format" o $ \x -> case x of
        JString s | s == formatName -> Right ()
        JString s -> Left ("format: expected " <> T.pack (show formatName) <> ", got " <> T.pack (show s))
        _ -> Left "format: expected a string"
    , field "version" o $ \x -> case x of
        JNumber n | n == fromIntegral formatVersion -> Right ()
        JNumber n -> Left ("version: only version " <> tshow formatVersion <> " is understood, got " <> renderNumber n)
        _ -> Left "version: expected a number"
    ]
  name <- one (optText "name" o "")
  status <- one $ case o .:? "status" of
    Nothing -> Right Provisional
    Just (JString "provisional") -> Right Provisional
    Just (JString "reviewed") -> Right Reviewed
    Just (JString s) -> Left ("status: expected provisional or reviewed, got " <> T.pack (show s))
    Just _ -> Left "status: expected a string"
  hp <- one $ do
    x <- o .: "hp"
    n <- int "hp" x
    if n < 1 || n > 84 then Left ("hp: " <> tshow n <> " is not a panel width (1 to 84)") else Right n
  grid <- either (Left . pure) decodeGrid (o .: "grid")
  controlsV <- one $ case o .:? "controls" of
    Nothing -> Left "missing field controls"
    Just (JArray xs) -> Right xs
    Just _ -> Left "controls: expected an array"
  groupsV <- one $ case o .:? "groups" of
    Nothing -> Right []
    Just (JArray xs) -> Right xs
    Just _ -> Left "groups: expected an array"
  notes <- one $ case o .:? "notes" of
    Nothing -> Right []
    Just (JArray xs) -> mapM (\x -> case x of JString s -> Right s; _ -> Left "notes: every note must be a string") xs
    Just _ -> Left "notes: expected an array of strings"
  controls <- collect [ decodeControl ("controls[" <> tshow i <> "]") x | (i, x) <- zip [0 :: Int ..] controlsV ]
  groups <- collect [ decodeGroup ("groups[" <> tshow i <> "]") x | (i, x) <- zip [0 :: Int ..] groupsV ]
  let ids = map ctId controls
      dupIds = nub (ids \\ nub ids)
      gkeys = map gpKey groups
      dupGroups = nub (gkeys \\ nub gkeys)
      danglingGroups = nub [ g | Just g <- map ctGroup controls, g `notElem` gkeys ]
      semantic = unknown
        ++ [ "controls: duplicate id " <> T.pack (show d) | d <- dupIds ]
        ++ [ "groups: duplicate id " <> T.pack (show d) | d <- dupGroups ]
        ++ [ "controls: group " <> T.pack (show g) <> " is not declared in groups" | g <- danglingGroups ]
  if null semantic
    then Right Sketch { sxName = name, sxStatus = status, sxHP = hp, sxGrid = grid
                      , sxControls = controls, sxGroups = groups, sxNotes = notes }
    else Left semantic
  where
    one :: Either Text a -> Either [Text] a
    one = either (Left . pure) Right
    field k o f = case o .:? k of
      Nothing -> Left ("missing field " <> k)
      Just x -> f x

-- | Run every decoder, keeping all failures.
collect :: [Either Text a] -> Either [Text] [a]
collect rs = case [ e | Left e <- rs ] of
  [] -> Right [ a | Right a <- rs ]
  es -> Left es

decodeGrid :: JValue -> Either [Text] Grid
decodeGrid v = do
  o <- case v of
         JObject kvs -> if all ((`elem` ["origin", "pitch", "profile"]) . fst) kvs then Right v
                        else Left [ "grid: unknown field " <> k | (k, _) <- kvs, k `notElem` ["origin", "pitch", "profile"] ]
         _ -> Left ["grid: expected an object"]
  origin <- either (Left . pure) Right (o .: "origin" >>= point "grid.origin")
  pitch <- either (Left . pure) Right $ do
    p@(px, py) <- o .: "pitch" >>= point "grid.pitch"
    if px <= 0 || py <= 0 then Left "grid.pitch: both pitches must be positive" else Right p
  profile <- either (Left . pure) Right $ do
    s <- optText "profile" o ""
    if T.null s || maybe False (const True) (lookupProfile s)
      then Right s
      else Left ("grid.profile: unknown profile " <> T.pack (show s))
  Right (Grid origin pitch profile)

decodeControl :: Text -> JValue -> Either Text Control
decodeControl path v = do
  o <- case v of
         JObject kvs -> case [ k | (k, _) <- kvs, k `notElem` known ] of
                          [] -> Right v
                          (k : _) -> Left (path <> ": unknown field " <> k)
         _ -> Left (path <> ": expected an object")
  cid <- (o .: "id") `orAt` path >>= text (path <> ".id")
  if validIdentifier cid then Right () else Left (path <> ".id: " <> T.pack (show cid) <> " is not an identifier (letters, digits, - and _; at most 40)")
  hwKey <- (o .: "hardware") `orAt` path >>= text (path <> ".hardware")
  hw <- maybe (Left (path <> ".hardware: unknown hardware " <> T.pack (show hwKey))) Right (lookupHardware hwKey)
  cell <- (o .: "cell") `orAt` path >>= cellOf (path <> ".cell")
  span' <- case o .:? "span" of
    Nothing -> Right (1, 1)
    Just s -> do
      (cols, rows) <- spanOf (path <> ".span") s
      if cols < 1 || rows < 1 then Left (path <> ".span: cols and rows must be at least 1") else Right (cols, rows)
  offset <- case o .:? "offset" of
    Nothing -> Right (0, 0)
    Just p -> point (path <> ".offset") p
  rotation <- case o .:? "rotation" of
    Nothing -> Right 0
    Just r -> do
      n <- int (path <> ".rotation") r
      if n `elem` hwRotations hw then Right n
        else Left (path <> ".rotation: " <> tshow n <> " is not one of " <> T.intercalate ", " (map tshow (hwRotations hw)) <> " for " <> hwKey)
  label <- optText "label" o ""
  group <- case o .:? "group" of
    Nothing -> Right Nothing
    Just JNull -> Right Nothing
    Just (JString g) | validIdentifier g -> Right (Just g)
                     | otherwise -> Left (path <> ".group: not an identifier")
    Just _ -> Left (path <> ".group: expected a string")
  Right Control { ctId = cid, ctHardware = hwKey, ctCell = cell, ctSpan = span', ctOffset = offset
                , ctRotation = rotation, ctLabel = label, ctGroup = group }
  where
    known = ["id", "hardware", "cell", "span", "offset", "rotation", "label", "group"]
    orAt r p = either (\e -> Left (p <> ": " <> e)) Right r

decodeGroup :: Text -> JValue -> Either Text Group
decodeGroup path v = do
  o <- case v of
         JObject kvs -> case [ k | (k, _) <- kvs, k `notElem` ["id", "label"] ] of
                          [] -> Right v
                          (k : _) -> Left (path <> ": unknown field " <> k)
         _ -> Left (path <> ": expected an object")
  gid <- either (\e -> Left (path <> ": " <> e)) Right (o .: "id") >>= text (path <> ".id")
  if validIdentifier gid then Right () else Left (path <> ".id: not an identifier")
  label <- optText "label" o ""
  Right (Group gid label)

-- Field helpers ----------------------------------------------------------------

text :: Text -> JValue -> Either Text Text
text _ (JString s) = Right s
text path _ = Left (path <> ": expected a string")

optText :: Text -> JValue -> Text -> Either Text Text
optText k o def = case o .:? k of
  Nothing -> Right def
  Just (JString s) -> Right s
  Just _ -> Left (k <> ": expected a string")

int :: Text -> JValue -> Either Text Int
int path (JNumber n)
  | n == fromIntegral (round n :: Int) && abs n < 1e9 = Right (round n)
  | otherwise = Left (path <> ": expected an integer, got " <> renderNumber n)
int path _ = Left (path <> ": expected an integer")

number :: Text -> JValue -> Either Text Double
number _ (JNumber n) = Right n   -- the parser already refused non-finite values
number path _ = Left (path <> ": expected a number")

point :: Text -> JValue -> Either Text (Double, Double)
point path v@(JObject kvs)
  | sort (map fst kvs) /= ["x", "y"] = Left (path <> ": expected exactly the fields x and y")
  | otherwise = do
      x <- (v .: "x") >>= number (path <> ".x")
      y <- (v .: "y") >>= number (path <> ".y")
      Right (x, y)
point path _ = Left (path <> ": expected an object with x and y")

cellOf :: Text -> JValue -> Either Text (Int, Int)
cellOf path v@(JObject kvs)
  | sort (map fst kvs) /= ["col", "row"] = Left (path <> ": expected exactly the fields col and row")
  | otherwise = do
      c <- (v .: "col") >>= int (path <> ".col")
      r <- (v .: "row") >>= int (path <> ".row")
      Right (c, r)
cellOf path _ = Left (path <> ": expected an object with col and row")

spanOf :: Text -> JValue -> Either Text (Int, Int)
spanOf path v@(JObject kvs)
  | sort (map fst kvs) /= ["cols", "rows"] = Left (path <> ": expected exactly the fields cols and rows")
  | otherwise = do
      c <- (v .: "cols") >>= int (path <> ".cols")
      r <- (v .: "rows") >>= int (path <> ".rows")
      Right (c, r)
spanOf path _ = Left (path <> ": expected an object with cols and rows")

tshow :: Show a => a -> Text
tshow = T.pack . show

-- Encoding ---------------------------------------------------------------------

encodeSketchText :: Sketch -> Text
encodeSketchText s = renderJson (encodeSketch s) <> "\n"

-- | Optional fields are written only when they differ from their default, so
-- a sketch the browser saves and one the generator writes look the same.
encodeSketch :: Sketch -> JValue
encodeSketch s = JObject $
  [ ("format", JString formatName)
  , ("version", JNumber (fromIntegral formatVersion))
  , ("name", JString (sxName s))
  , ("status", JString (case sxStatus s of Provisional -> "provisional"; Reviewed -> "reviewed"))
  , ("hp", JNumber (fromIntegral (sxHP s)))
  , ("grid", encodeGrid (sxGrid s))
  , ("controls", JArray (map encodeControl (sxControls s)))
  ] ++ [ ("groups", JArray [ JObject [("id", JString (gpKey g)), ("label", JString (gpLabel g))] | g <- sxGroups s ]) | not (null (sxGroups s)) ]
    ++ [ ("notes", JArray (map JString (sxNotes s))) | not (null (sxNotes s)) ]

encodeGrid :: Grid -> JValue
encodeGrid g = JObject $
  [ ("origin", pointJ (grOrigin g))
  , ("pitch", pointJ (grPitch g))
  ] ++ [ ("profile", JString (grProfile g)) | not (T.null (grProfile g)) ]

encodeControl :: Control -> JValue
encodeControl c = JObject $
  [ ("id", JString (ctId c))
  , ("hardware", JString (ctHardware c))
  , ("cell", JObject [("col", intJ (fst (ctCell c))), ("row", intJ (snd (ctCell c)))])
  ] ++ [ ("span", JObject [("cols", intJ (fst (ctSpan c))), ("rows", intJ (snd (ctSpan c)))]) | ctSpan c /= (1, 1) ]
    ++ [ ("offset", pointJ (ctOffset c)) | ctOffset c /= (0, 0) ]
    ++ [ ("rotation", intJ (ctRotation c)) | ctRotation c /= 0 ]
    ++ [ ("label", JString (ctLabel c)) | not (T.null (ctLabel c)) ]
    ++ [ ("group", JString g) | Just g <- [ctGroup c] ]

pointJ :: (Double, Double) -> JValue
pointJ (x, y) = JObject [("x", JNumber x), ("y", JNumber y)]

intJ :: Int -> JValue
intJ = JNumber . fromIntegral
