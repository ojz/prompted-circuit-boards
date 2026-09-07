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
  , lcSyms  :: IORef (M.Map Text SExpr)   -- parsed .kicad_sym files by nickname
  }

newLibCache :: IO LibCache
newLibCache = do
  share <- findKicadShare
  LibCache share <$> newIORef M.empty

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
          keep c = case headSym c of
            Just "property" -> maybe True (`notElem` dNames) (propName c)
            Just "extends"  -> False
            _               -> True
          baseKept = filter keep (children base)
          -- sub-symbols are named after the base; rename to the derived name
          fixUnit (List (Atom "symbol" : Str u : r))
            | Just suffix <- T.stripPrefix (symName base) u
            = List (Atom "symbol" : Str (symName derived <> suffix) : r)
          fixUnit c = c
      in List (Atom "symbol" : Str (symName derived) : dProps ++ map fixUnit baseKept)

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

-- | Every pin of unit 1 (plus the shared unit 0) of a symbol.
symbolPins :: SExpr -> [PinDef]
symbolPins s =
  [ p
  | u <- children s
  , headSym u == Just "symbol"
  , unitOf u `elem` [0, 1]
  , c <- children u
  , headSym c == Just "pin"
  , Just p <- [pinDef c]
  ]
  where
    unitOf (List (Atom "symbol" : Str n : _)) =
      case reverse (T.splitOn "_" n) of
        (_style : unit : _) -> readInt unit
        _                   -> 1 :: Int
    unitOf _ = 1
    readInt t = case reads (T.unpack t) of
      [(n, "")] -> n
      _         -> 1

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
    pinDef _ = Nothing

    strArg (List (_ : Str t : _)) = t
    strArg _                      = ""

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
  let path = lcShare lc </> "footprints" </> (T.unpack nick <.> "pretty") </> (T.unpack name <.> "kicad_mod")
  ok <- doesFileExist path
  if not ok then fail ("footprint not found: " ++ path) else do
    txt <- TIO.readFile path
    fp <- either (\err -> fail (path ++ ": " ++ err)) pure (parseSExpr txt)
    case fp of
      List (Atom "footprint" : Str _ : rest) ->
        pure (List (Atom "footprint" : Str (nick <> ":" <> name)
                    : filter (\c -> headSym c `notElem` map Just ["version", "generator", "generator_version"]) rest))
      _ -> fail (path ++ ": not a footprint")
