{-# LANGUAGE OverloadedStrings #-}
-- | Read symbols and footprints from the official KiCad libraries so they can
-- be embedded verbatim. KiCad's own files carry a copy of every symbol and
-- footprint they use, so embedding the library copy is exactly what the GUI
-- does, and the "footprint does not match library" DRC check passes.
module Kicad.Library
  ( LibCache
  , newLibCache
  , findKicadShare
  , loadSymbol
  , loadFootprint
  , PinDef (..)
  , symbolPins
  , symbolUnits
  , symbolPinsOfUnit
  , symbolPropertyAt
  , symbolPropertyValue
  , isPowerSymbol
  ) where

import           Control.Monad      (filterM)
import           Data.IORef
import           Data.List          (find)
import qualified Data.Map.Strict    as M
import           Data.Maybe         (fromMaybe, mapMaybe)
import           Data.Text          (Text)
import qualified Data.Text          as T
import qualified Data.Text.IO       as TIO
import           System.Directory   (doesDirectoryExist, doesFileExist)
import           System.Environment (lookupEnv)
import           System.FilePath    ((</>), (<.>))

import           Kicad.SExpr

data LibCache = LibCache
  { lcShare :: FilePath
  , lcLocal :: FilePath                   -- repo footprint libraries (lib/footprints)
  , lcSyms  :: IORef (M.Map Text SExpr)   -- parsed .kicad_sym files by nickname
  }

newLibCache :: IO LibCache
newLibCache = do
  share <- findKicadShare
  local <- findLocalFootprints
  LibCache share local <$> newIORef M.empty

-- | The repository's own footprint libraries, @lib/footprints/<nick>.pretty@.
-- @PCBGEN_LIB@ overrides; the default assumes pcbgen runs from the repo root.
-- KiCad finds the same directory through the per-module @fp-lib-table@.
findLocalFootprints :: IO FilePath
findLocalFootprints = fromMaybe ("lib" </> "footprints") <$> lookupEnv "PCBGEN_LIB"

-- | Locate KiCad's @share/kicad@ directory. @PCBGEN_KICAD_SHARE@ overrides;
-- otherwise the per-user and machine-wide Windows install paths are tried.
findKicadShare :: IO FilePath
findKicadShare = do
  override <- lookupEnv "PCBGEN_KICAD_SHARE"
  local <- lookupEnv "LOCALAPPDATA"
  let candidates =
        maybe [] pure override
        ++ maybe [] (\l -> [l </> "Programs" </> "KiCad" </> "10.0" </> "share" </> "kicad"]) local
        ++ [ "C:\\Program Files\\KiCad\\10.0\\share\\kicad"
           , "/usr/share/kicad"
           ]
  found <- filterM (\d -> doesDirectoryExist (d </> "symbols")) candidates
  case found of
    (d : _) -> pure d
    []      -> fail ("KiCad share directory not found; tried: " ++ show candidates)

-- Symbols ------------------------------------------------------------------

symbolLib :: LibCache -> Text -> IO SExpr
symbolLib lc nick = do
  cache <- readIORef (lcSyms lc)
  case M.lookup nick cache of
    Just e  -> pure e
    Nothing -> do
      let path = lcShare lc </> "symbols" </> T.unpack nick <.> "kicad_sym"
      ok <- doesFileExist path
      if not ok then fail ("symbol library not found: " ++ path) else do
        txt <- TIO.readFile path
        e <- either (\err -> fail (path ++ ": " ++ err)) pure (parseSExpr txt)
        modifyIORef' (lcSyms lc) (M.insert nick e)
        pure e

-- | Load @Nick:Name@ and return the symbol definition renamed to the
-- qualified form KiCad uses inside a schematic's @lib_symbols@ block.
-- Derived symbols (@extends@) are flattened onto their base.
loadSymbol :: LibCache -> Text -> Text -> IO SExpr
loadSymbol lc nick name = do
  lib <- symbolLib lc nick
  raw <- resolve lib name (0 :: Int)
  pure (rename raw)
  where
    rename (List (Atom "symbol" : Str _ : rest)) = List (Atom "symbol" : Str (nick <> ":" <> name) : rest)
    rename e = e

    resolve lib n depth
      | depth > 5 = fail ("symbol extends chain too deep: " ++ T.unpack n)
      | otherwise = do
          s <- maybe (fail ("symbol not found: " ++ T.unpack nick ++ ":" ++ T.unpack n)) pure
                 (find (isNamed n) (children lib))
          case findChild "extends" s >>= (atomText <=< headArg) of
            Nothing   -> pure s
            Just base -> do
              b <- resolve lib base (depth + 1)
              pure (merge b s)

    isNamed n (List (Atom "symbol" : Str m : _)) = m == n
    isNamed _ _                                  = False

    headArg (List (_ : a : _)) = Just a
    headArg _                  = Nothing

    -- Derived symbol: base body and units, derived properties win.
    merge base derived =
      let dProps = [ p | p <- children derived, headSym p == Just "property" ]
          dNames = mapMaybe propName dProps
          -- 'children' includes the base's own name string; drop it along
          -- with the extends link and any property the derived one redefines.
          keep c@(List (Atom _ : _)) = case headSym c of
            Just "property" -> maybe True (`notElem` dNames) (propName c)
            Just "extends"  -> False
            _               -> True
          keep _ = False
          baseKept = filter keep (children base)
          -- sub-symbols are named after the base; rename to the derived name
          fixUnit (List (Atom "symbol" : Str u : r))
            | Just suffix <- T.stripPrefix (symName base) u
            = List (Atom "symbol" : Str (symName derived <> suffix) : r)
          fixUnit c = c
          isProp c = headSym c == Just "property"
          isSub c = headSym c == Just "symbol"
          isFonts c = headSym c == Just "embedded_fonts"
          -- Same order KiCad writes: pin settings and flags, properties,
          -- unit bodies, embedded_fonts. KiCad refuses to load a schematic
          -- whose lib symbol has properties ahead of pin_names.
          settings = [ c | c <- baseKept, not (isProp c), not (isSub c), not (isFonts c) ]
          props = dProps ++ filter isProp baseKept
          units = map fixUnit (filter isSub baseKept)
          fonts = filter isFonts baseKept
      in List (Atom "symbol" : Str (symName derived) : settings ++ props ++ units ++ fonts)

    symName (List (Atom "symbol" : Str n : _)) = n
    symName _                                  = ""

    propName (List (Atom "property" : Str n : _)) = Just n
    propName _                                    = Nothing

    (<=<) f g x = g x >>= f

data PinDef = PinDef
  { pinNumber :: Text
  , pinName   :: Text
  , pinX      :: Double   -- ^ library coordinates, y up
  , pinY      :: Double
  , pinAngle  :: Double   -- ^ direction from the connection point toward the body
  , pinLength :: Double
  , pinType   :: Text
  } deriving (Show)

-- | Unit numbers of a symbol, ascending; @[1]@ for a single-unit symbol.
-- Sub-symbols are named @Name_unit_style@; unit 0 is shared by all units.
symbolUnits :: SExpr -> [Int]
symbolUnits s =
  case [ un | u <- children s, headSym u == Just "symbol", let (un, st) = unitStyle u, un > 0, st <= 1 ] of
    [] -> [1]
    us -> uniqSorted us
  where
    uniqSorted = foldr (\x acc -> if x `elem` acc then acc else x : acc) [] . sortInts
    sortInts xs = [ x | x <- [minimum xs .. maximum xs], x `elem` xs ]

-- | Every pin of one unit, including the pins of the shared unit 0. Only the
-- primary body style is used (style 2 is the De Morgan alternate).
symbolPinsOfUnit :: Int -> SExpr -> [PinDef]
symbolPinsOfUnit k s =
  [ p
  | u <- children s
  , headSym u == Just "symbol"
  , let (un, st) = unitStyle u
  , un `elem` [0, k], st <= 1
  , c <- children u
  , headSym c == Just "pin"
  , Just p <- [pinDef c]
  ]

-- | Every pin of a symbol across all its units.
symbolPins :: SExpr -> [PinDef]
symbolPins s =
  [ p
  | u <- children s
  , headSym u == Just "symbol"
  , let (_, st) = unitStyle u
  , st <= 1
  , c <- children u
  , headSym c == Just "pin"
  , Just p <- [pinDef c]
  ]

unitStyle :: SExpr -> (Int, Int)
unitStyle (List (Atom "symbol" : Str n : _)) =
  case reverse (T.splitOn "_" n) of
    (style : unit : _) -> (readInt unit, readInt style)
    _                  -> (1, 1)
  where
    readInt t = case reads (T.unpack t) of
      [(v, "")] -> v
      _         -> 1 :: Int
unitStyle _ = (1, 1)

pinDef :: SExpr -> Maybe PinDef
pinDef (List (Atom "pin" : Atom ty : _style : rest)) =
      let e = List (Atom "pin" : rest)
          at = findChild "at" e
          (x, y, a) = case at of
            Just (List (_ : ax : ay : aa : _)) -> (numOf ax, numOf ay, numOf aa)
            Just (List (_ : ax : ay : _))      -> (numOf ax, numOf ay, 0)
            _                                  -> (0, 0, 0)
          numOf = readD . fromMaybe "0" . atomText
          len = case findChild "length" e of
            Just (List (_ : l : _)) -> numOf l
            _                       -> 0
          nm  = maybe "" strArg (findChild "name" e)
          num = maybe "" strArg (findChild "number" e)
      in Just (PinDef num nm x y a len ty)
  where
    strArg (List (_ : Str t : _)) = t
    strArg _                      = ""
pinDef _ = Nothing

readD :: Text -> Double
readD t = case reads (fixup (T.unpack t)) of
  [(d, "")] -> d
  _         -> 0
  where
    fixup ('-' : '.' : r) = "-0." ++ r
    fixup ('.' : r)       = "0." ++ r
    fixup s               = s

-- | Position and rotation of a named property, in library coordinates.
symbolPropertyAt :: Text -> SExpr -> Maybe (Double, Double, Double)
symbolPropertyAt name s = do
  p <- find (\c -> headSym c == Just "property" && arg1 c == Just name) (children s)
  List (_ : ax : ay : rest) <- findChild "at" p
  let a = case rest of
            (aa : _) -> readD (fromMaybe "0" (atomText aa))
            _        -> 0
  pure (readD (fromMaybe "0" (atomText ax)), readD (fromMaybe "0" (atomText ay)), a)
  where
    arg1 (List (_ : Str t : _)) = Just t
    arg1 _                      = Nothing

symbolPropertyValue :: Text -> SExpr -> Maybe Text
symbolPropertyValue name s = do
  List (_ : _ : Str v : _) <- find (\c -> headSym c == Just "property" && arg1 c == Just name) (children s)
  pure v
  where
    arg1 (List (_ : Str t : _)) = Just t
    arg1 _                      = Nothing

isPowerSymbol :: SExpr -> Bool
isPowerSymbol s = any (\c -> headSym c == Just "power") (children s)

-- Footprints -----------------------------------------------------------------

-- | Load @Nick:Name@ as the raw library footprint (head renamed to the
-- qualified id, version/generator dropped).
loadFootprint :: LibCache -> Text -> Text -> IO SExpr
loadFootprint lc nick name = do
  let official = lcShare lc </> "footprints" </> (T.unpack nick <.> "pretty") </> (T.unpack name <.> "kicad_mod")
      local = lcLocal lc </> (T.unpack nick <.> "pretty") </> (T.unpack name <.> "kicad_mod")
  isLocal <- doesFileExist local
  let path = if isLocal then local else official
  ok <- doesFileExist path
  if not ok then fail ("footprint not found: " ++ path) else do
    txt <- TIO.readFile path
    fp <- either (\err -> fail (path ++ ": " ++ err)) pure (parseSExpr txt)
    case fp of
      List (Atom "footprint" : Str _ : rest) ->
        pure (List (Atom "footprint" : Str (nick <> ":" <> name)
                    : filter (\c -> headSym c `notElem` map Just ["version", "generator", "generator_version"]) rest))
      _ -> fail (path ++ ": not a footprint")
