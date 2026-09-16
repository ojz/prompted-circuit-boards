{-# LANGUAGE OverloadedStrings #-}
-- | A small JSON value type with a strict parser and a deterministic printer.
--
-- The sketch interchange format (docs/ROADMAP.md, S1) is JSON so that a
-- browser can read and write it natively. pcbgen has no JSON dependency and
-- the test harness deliberately needs nothing beyond the packages the
-- generator already uses, so the hundred lines a strict RFC 8259 reader and
-- writer take are written here rather than pulled from Hackage.
--
-- Strictness is the point: the parser rejects everything the grammar does
-- (trailing commas, comments, single quotes, bare words, control characters
-- in strings, a leading @+@ or a lone @.@ in numbers) and additionally
-- rejects any number that does not fit a finite 'Double', since a sketch
-- coordinate of @1e999@ must fail clearly rather than become infinity.
module Sketch.Json
  ( JValue (..)
  , parseJson
  , renderJson
  , renderNumber
    -- * Field access with diagnostics
  , (.:)
  , (.:?)
  , lookupKey
  ) where

import           Data.Char  (chr, isDigit, isHexDigit, ord)
import           Data.List  (foldl')
import           Data.Text  (Text)
import qualified Data.Text  as T
import           Numeric    (showFFloat, showHex)

-- | Objects keep their key order so that a printed sketch is stable and a
-- diff between two saves shows what changed.
data JValue
  = JNull
  | JBool Bool
  | JNumber Double
  | JString Text
  | JArray [JValue]
  | JObject [(Text, JValue)]
  deriving (Eq, Show)

-- Parsing --------------------------------------------------------------------

-- | Parse a complete JSON text. Leading and trailing whitespace is allowed,
-- anything else after the value is an error. Errors carry a character offset.
parseJson :: Text -> Either Text JValue
parseJson input =
  case value (skipWs 0) of
    Left e -> Left e
    Right (v, i) ->
      let j = skipWs i
      in if j >= T.length input then Right v
         else Left (errAt j "unexpected text after the JSON value")
  where
    len = T.length input
    at i = T.index input i
    errAt i msg = T.pack ("JSON error at offset " ++ show i ++ ": ") <> msg

    skipWs i
      | i < len && at i `elem` (" \t\r\n" :: String) = skipWs (i + 1)
      | otherwise = i

    value i
      | i >= len = Left (errAt i "unexpected end of text")
      | otherwise = case at i of
          '{' -> object (skipWs (i + 1)) []
          '[' -> array (skipWs (i + 1)) []
          '"' -> fmap (\(s, j) -> (JString s, j)) (string (i + 1) [])
          't' -> literal i "true" (JBool True)
          'f' -> literal i "false" (JBool False)
          'n' -> literal i "null" JNull
          c | c == '-' || isDigit c -> number i
            | otherwise -> Left (errAt i ("unexpected character " <> T.pack (show c)))

    literal i word v
      | T.isPrefixOf word (T.drop i input) = Right (v, i + T.length word)
      | otherwise = Left (errAt i ("expected " <> word))

    -- @i@ is at the first member or the closing brace; after a comma the
    -- accumulator is non-empty, so a brace there is a trailing comma.
    object i acc
      | i >= len = Left (errAt i "unterminated object")
      | at i == '}' = if null acc then Right (JObject [], i + 1)
                      else Left (errAt i "trailing comma in object")
      | at i /= '"' = Left (errAt i "expected a string key")
      | otherwise = do
          (k, j) <- string (i + 1) []
          if any ((== k) . fst) acc then Left (errAt i ("duplicate key " <> T.pack (show k))) else do
            let j' = skipWs j
            if j' >= len || at j' /= ':' then Left (errAt j' "expected ':' after object key") else do
              (v, k2) <- value (skipWs (j' + 1))
              let k3 = skipWs k2
              if k3 >= len then Left (errAt k3 "unterminated object") else
                case at k3 of
                  ',' -> object (skipWs (k3 + 1)) ((k, v) : acc)
                  '}' -> Right (JObject (reverse ((k, v) : acc)), k3 + 1)
                  _   -> Left (errAt k3 "expected ',' or '}' in object")

    array i acc
      | i >= len = Left (errAt i "unterminated array")
      | at i == ']' = if null acc then Right (JArray [], i + 1)
                      else Left (errAt i "trailing comma in array")
      | otherwise = do
          (v, j) <- value i
          let j' = skipWs j
          if j' >= len then Left (errAt j' "unterminated array") else
            case at j' of
              ',' -> arrayMore (skipWs (j' + 1)) (v : acc)
              ']' -> Right (JArray (reverse (v : acc)), j' + 1)
              _   -> Left (errAt j' "expected ',' or ']' in array")
    arrayMore i acc
      | i < len && at i == ']' = Left (errAt i "trailing comma in array")
      | otherwise = array i acc

    string i acc
      | i >= len = Left (errAt i "unterminated string")
      | otherwise = case at i of
          '"'  -> Right (T.pack (reverse acc), i + 1)
          '\\' -> escape (i + 1) acc
          c | ord c < 0x20 -> Left (errAt i "control character in string")
            | otherwise -> string (i + 1) (c : acc)
    escape i acc
      | i >= len = Left (errAt i "unterminated escape")
      | otherwise = case at i of
          '"'  -> string (i + 1) ('"' : acc)
          '\\' -> string (i + 1) ('\\' : acc)
          '/'  -> string (i + 1) ('/' : acc)
          'b'  -> string (i + 1) ('\b' : acc)
          'f'  -> string (i + 1) ('\f' : acc)
          'n'  -> string (i + 1) ('\n' : acc)
          'r'  -> string (i + 1) ('\r' : acc)
          't'  -> string (i + 1) ('\t' : acc)
          'u'  -> do
            hi <- hex4 (i + 1)
            if hi >= 0xD800 && hi <= 0xDBFF
              then -- a high surrogate must be followed by an escaped low one
                if i + 6 < len && at (i + 5) == '\\' && at (i + 6) == 'u'
                  then do
                    lo <- hex4 (i + 7)
                    if lo >= 0xDC00 && lo <= 0xDFFF
                      then string (i + 11) (chr (0x10000 + (hi - 0xD800) * 0x400 + (lo - 0xDC00)) : acc)
                      else Left (errAt (i + 7) "invalid low surrogate")
                  else Left (errAt i "unpaired high surrogate")
              else if hi >= 0xDC00 && hi <= 0xDFFF
                then Left (errAt i "unpaired low surrogate")
                else string (i + 5) (chr hi : acc)
          c -> Left (errAt i ("invalid escape \\" <> T.singleton c))
    hex4 i
      | i + 4 > len = Left (errAt i "truncated \\u escape")
      | all isHexDigit digits = Right (foldl' (\a d -> a * 16 + hexVal d) 0 digits)
      | otherwise = Left (errAt i "invalid \\u escape")
      where digits = [ at (i + k) | k <- [0 .. 3] ]
    hexVal d | isDigit d = ord d - ord '0'
             | d >= 'a' && d <= 'f' = ord d - ord 'a' + 10
             | otherwise = ord d - ord 'A' + 10

    -- number: -? (0 | [1-9][0-9]*) (. [0-9]+)? ([eE] [+-]? [0-9]+)?
    number i = do
      let i1 = if at i == '-' then i + 1 else i
      i2 <- intPart i1
      i3 <- fracPart i2
      i4 <- expPart i3
      let d = readNumber (T.unpack (T.take (i4 - i) (T.drop i input)))
      if isNaN d || isInfinite d
        then Left (errAt i "number is not a finite double")
        else Right (JNumber d, i4)
    intPart i
      | i >= len || not (isDigit (at i)) = Left (errAt i "expected a digit")
      | at i == '0' = Right (i + 1)
      | otherwise = Right (digits (i + 1))
    fracPart i
      | i < len && at i == '.' =
          if i + 1 < len && isDigit (at (i + 1)) then Right (digits (i + 1))
          else Left (errAt (i + 1) "expected a digit after '.'")
      | otherwise = Right i
    expPart i
      | i < len && (at i == 'e' || at i == 'E') =
          let j = if i + 1 < len && (at (i + 1) == '+' || at (i + 1) == '-') then i + 2 else i + 1
          in if j < len && isDigit (at j) then Right (digits j)
             else Left (errAt j "expected a digit in exponent")
      | otherwise = Right i
    digits i | i < len && isDigit (at i) = digits (i + 1)
             | otherwise = i

-- | Convert a syntactically valid JSON number to a Double. Haskell's 'read'
-- wants a digit on both sides of the point and no leading '-', so the text
-- is massaged first; huge exponents give infinity, which the caller rejects.
readNumber :: String -> Double
readNumber s0 =
  let (neg, s1) = case s0 of ('-' : r) -> (True, r); r -> (False, r)
      (mant, ex) = break (`elem` ("eE" :: String)) s1
      mant' = if '.' `elem` mant then mant else mant ++ ".0"
      ex' = case ex of
              [] -> ""
              (_ : '+' : r) -> 'e' : r
              (_ : r) -> 'e' : r
      v = read (mant' ++ ex') :: Double
  in if neg then negate v else v

-- Printing -------------------------------------------------------------------

-- | Pretty-print with two-space indentation; the same text every time for
-- the same value. Numbers that are whole print without a fraction, as
-- JavaScript's @JSON.stringify@ prints them, so the two sides agree byte for
-- byte on the fixtures.
renderJson :: JValue -> Text
renderJson = go 0
  where
    go :: Int -> JValue -> Text
    go _ JNull = "null"
    go _ (JBool b) = if b then "true" else "false"
    go _ (JNumber d) = renderNumber d
    go _ (JString s) = renderString s
    go _ (JArray []) = "[]"
    go n (JArray xs) =
      "[\n" <> T.intercalate ",\n" [ indent (n + 1) <> go (n + 1) x | x <- xs ] <> "\n" <> indent n <> "]"
    go _ (JObject []) = "{}"
    go n (JObject kvs) =
      "{\n" <> T.intercalate ",\n" [ indent (n + 1) <> renderString k <> ": " <> go (n + 1) v | (k, v) <- kvs ] <> "\n" <> indent n <> "}"
    indent n = T.replicate (2 * n) " "

-- | JSON's shortest round-tripping decimal is what JavaScript prints; Haskell's
-- 'show' already gives the shortest digits that read back to the same
-- Double, so this reformats that into plain decimal notation.
renderNumber :: Double -> Text
renderNumber d
  | isNaN d || isInfinite d = error "renderNumber: non-finite"
  | d == fromIntegral (round d :: Integer) && abs d < 1e15 = T.pack (show (round d :: Integer))
  | abs d >= 1e-4 && abs d < 1e15 = T.pack (trimZeros (showFFloat Nothing d ""))
  | otherwise = T.pack (show d)
  where
    trimZeros s
      | '.' `elem` s = let t = reverse (dropWhile (== '0') (reverse s))
                       in if last t == '.' then init t else t
      | otherwise = s

renderString :: Text -> Text
renderString s = "\"" <> T.concatMap esc s <> "\""
  where
    esc '"' = "\\\""
    esc '\\' = "\\\\"
    esc '\n' = "\\n"
    esc '\r' = "\\r"
    esc '\t' = "\\t"
    esc '\b' = "\\b"
    esc '\f' = "\\f"
    esc c | ord c < 0x20 = T.pack ("\\u" ++ pad4 (showHex (ord c) ""))
          | otherwise = T.singleton c
    pad4 h = replicate (4 - length h) '0' ++ h

-- Field access ---------------------------------------------------------------

lookupKey :: Text -> JValue -> Maybe JValue
lookupKey k (JObject kvs) = lookup k kvs
lookupKey _ _ = Nothing

-- | A required field: a missing one is a diagnostic naming the path.
(.:) :: JValue -> Text -> Either Text JValue
o .: k = maybe (Left ("missing field " <> k)) Right (lookupKey k o)

-- | An optional field.
(.:?) :: JValue -> Text -> Maybe JValue
o .:? k = lookupKey k o
