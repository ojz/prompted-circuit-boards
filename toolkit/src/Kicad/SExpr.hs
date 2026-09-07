{-# LANGUAGE OverloadedStrings #-}
-- | Minimal s-expression model matching KiCad's file format.
--
-- KiCad files are plain s-expressions: bare atoms (symbols and numbers),
-- double-quoted strings, and parenthesised lists. Whitespace is not
-- significant, so we pretty-print in a KiCad-like layout purely for diffs.
module Kicad.SExpr
  ( SExpr (..)
  , parseSExpr
  , parseSExprs
  , render
  , renderCompact
    -- * Construction helpers
  , sym, str, num, list
  , mm
    -- * Querying
  , headSym
  , children
  , findChild
  , findChildren
  , atomText
  ) where

import           Data.Char       (isSpace)
import           Data.Text       (Text)
import qualified Data.Text       as T
import           Numeric         (showFFloat)

data SExpr
  = Atom Text        -- ^ bare symbol or number, written verbatim
  | Str  Text        -- ^ quoted string, escaped on output
  | List [SExpr]
  deriving (Eq, Show)

-- Construction ---------------------------------------------------------------

sym :: Text -> SExpr
sym = Atom

str :: Text -> SExpr
str = Str

-- | A number formatted the way KiCad writes millimetres: up to six decimals,
-- trailing zeros stripped, no exponent.
num :: Double -> SExpr
num = Atom . mm

list :: Text -> [SExpr] -> SExpr
list h xs = List (Atom h : xs)

mm :: Double -> Text
mm x
  | x == 0        = "0"
  | otherwise     = T.pack (strip (showFFloat (Just 6) x ""))
  where
    strip s
      | '.' `elem` s = let s' = reverse (dropWhile (== '0') (reverse s))
                       in if last s' == '.' then init s' else s'
      | otherwise    = s

-- Querying -------------------------------------------------------------------

headSym :: SExpr -> Maybe Text
headSym (List (Atom h : _)) = Just h
headSym _                   = Nothing

children :: SExpr -> [SExpr]
children (List (_ : xs)) = xs
children _               = []

findChild :: Text -> SExpr -> Maybe SExpr
findChild h e = case findChildren h e of
  (x : _) -> Just x
  []      -> Nothing

findChildren :: Text -> SExpr -> [SExpr]
findChildren h e = [ c | c <- children e, headSym c == Just h ]

atomText :: SExpr -> Maybe Text
atomText (Atom t) = Just t
atomText (Str t)  = Just t
atomText _        = Nothing

-- Rendering ------------------------------------------------------------------

-- | KiCad-style layout: a list whose elements are all atoms goes on one
-- line; anything containing a sub-list breaks its children onto indented
-- lines. KiCad itself uses tabs.
render :: SExpr -> Text
render e = T.concat (go 0 e) <> "\n"
  where
    go :: Int -> SExpr -> [Text]
    go _ (Atom t) = [t]
    go _ (Str t)  = [quote t]
    go n (List xs)
      | all isAtom xs = ["(" <> T.intercalate " " (map renderAtom xs) <> ")"]
      | otherwise =
          let (lead, rest) = span isAtom xs
              indent = T.replicate (n + 1) "\t"
              body   = concat [ ["\n", indent] ++ go (n + 1) c | c <- rest ]
          in ["(" <> T.intercalate " " (map renderAtom lead)]
             ++ body ++ ["\n", T.replicate n "\t", ")"]

    isAtom (List _) = False
    isAtom _        = True

renderAtom :: SExpr -> Text
renderAtom (Atom t) = t
renderAtom (Str t)  = quote t
renderAtom l        = renderCompact l

renderCompact :: SExpr -> Text
renderCompact (Atom t)  = t
renderCompact (Str t)   = quote t
renderCompact (List xs) = "(" <> T.intercalate " " (map renderCompact xs) <> ")"

quote :: Text -> Text
quote t = "\"" <> T.concatMap esc t <> "\""
  where
    esc '"'  = "\\\""
    esc '\\' = "\\\\"
    esc '\n' = "\\n"
    esc c    = T.singleton c

-- Parsing --------------------------------------------------------------------

parseSExpr :: Text -> Either String SExpr
parseSExpr t = case parseSExprs t of
  Right [e]  -> Right e
  Right []   -> Left "empty input"
  Right _    -> Left "more than one top-level expression"
  Left err   -> Left err

parseSExprs :: Text -> Either String [SExpr]
parseSExprs = goTop . skipWs
  where
    goTop t
      | T.null t  = Right []
      | otherwise = do
          (e, rest) <- expr t
          es <- goTop (skipWs rest)
          Right (e : es)

    expr :: Text -> Either String (SExpr, Text)
    expr t = case T.uncons t of
      Nothing        -> Left "unexpected end of input"
      Just ('(', r)  -> listBody [] (skipWs r)
      Just (')', _)  -> Left "unexpected ')'"
      Just ('"', r)  -> strBody [] r
      Just _         -> let (a, r) = T.break (\c -> isSpace c || c == '(' || c == ')' || c == '"') t
                        in Right (Atom a, r)

    listBody acc t = case T.uncons t of
      Nothing       -> Left "unterminated list"
      Just (')', r) -> Right (List (reverse acc), r)
      Just _        -> do
        (e, r) <- expr t
        listBody (e : acc) (skipWs r)

    strBody acc t = case T.uncons t of
      Nothing        -> Left "unterminated string"
      Just ('"', r)  -> Right (Str (T.pack (reverse acc)), r)
      Just ('\\', r) -> case T.uncons r of
        Just ('n', r')  -> strBody ('\n' : acc) r'
        Just ('t', r')  -> strBody ('\t' : acc) r'
        Just (c, r')    -> strBody (c : acc) r'
        Nothing         -> Left "dangling escape"
      Just (c, r)    -> strBody (c : acc) r

    skipWs = T.dropWhile isSpace
