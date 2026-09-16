{-# LANGUAGE OverloadedStrings #-}
-- | Sketch format tests. The format is a grid and the components in its
-- cells, so most of what there is to check is that it refuses nonsense and
-- that the grid limits are the ones the hardware actually allows.
module SketchTests (tests) where

import           Data.List        (nub)
import           Data.Text        (Text)
import qualified Data.Text        as T
import           System.IO.Unsafe (unsafePerformIO)

import           Design           (eurorackPanelWidths, eurorackPcbHeight)
import           Harness
import           Sketch.Catalogue
import           Sketch.Export
import           Sketch.Fixtures
import           Sketch.Json
import           Sketch.Model

tests :: [Test]
tests =
  [ -- JSON -------------------------------------------------------------------
    test "JSON round-trips a nested value and prints deterministically" $
      let v = JObject [ ("a", JArray [JNumber 1, JNumber 2.5, JNumber (-0.001), JString "q\"\\\n\1\x1F600"])
                      , ("b", JObject []), ("c", JArray []), ("d", JNull), ("e", JBool True) ]
          txt = renderJson v
      in expectAll
           [ (parseJson txt == Right v, "round trip: " ++ show (parseJson txt))
           , (fmap renderJson (parseJson txt) == Right txt, "second print differs")
           , (map renderNumber [20, 14.25, -6.41, 0.1] == ["20", "14.25", "-6.41", "0.1"]
             , "number formatting " ++ show (map renderNumber [20, 14.25, -6.41, 0.1])) ]

  , test "JSON parser is strict" $
      let bad = [ "{\"a\": 1,}", "[1,]", "{a: 1}", "{'a': 1}", "NaN", "Infinity", "1e999", "-", "01", "1.", ".5", "+1"
                , "{\"a\": 1 \"b\": 2}", "\"unterminated", "\"tab\tinside\"", "{\"a\": 1, \"a\": 2}", "[1] 2", "", "  "
                , "\"\\uD800\"", "\"\\x41\"", "tru" ]
      in [ "accepted " ++ show t | t <- bad, Right _ <- [parseJson t] ]

    -- Format ----------------------------------------------------------------
  , test "every fixture round-trips through its JSON text unchanged" $
      concat [ expect (decodeSketchText (encodeSketchText s) == Right s)
                      ("fixture " ++ T.unpack n ++ ": " ++ show (decodeSketchText (encodeSketchText s)))
             | (n, s) <- fixtures ]

  , test "the mixer fixture keeps its cells, labels and gaps" $
      case decodeSketchText (encodeSketchText mixerSketch) of
        Left es -> [ "decode failed: " ++ show es ]
        Right s -> expectAll
          [ (sxColumns s == 3 && sxRows s == 6, "grid " ++ show (sxColumns s, sxRows s))
          , (length (sxCells s) == 11, "cells " ++ show (length (sxCells s)))
          , (fmap clKind (cellAt s 0 0) == Just Knob, "knob at 0,0")
          , (fmap clLabel (cellAt s 1 5) == Just "OUT", "output label")
          , (cellAt s 2 0 == Nothing && cellAt s 0 4 == Nothing, "an empty cell is not empty")
          , (impliedWidth s == Just 10, "three columns should need 10 HP, got " ++ show (impliedWidth s)) ]

  , test "cells are written in reading order, whatever order they were made in" $
      let scrambled = mixerSketch { sxCells = reverse (sxCells mixerSketch) }
      in expectAll
           [ (encodeSketchText scrambled == encodeSketchText mixerSketch
             , "the same panel drawn in another order is a different file") ]

  , test "every invalid text is refused with a diagnostic" $
      concat [ case decodeSketchText t of
                 Right _ -> [ "accepted: " ++ T.unpack n ]
                 Left es -> expect (not (null es) && all (not . T.null) es) ("empty diagnostic for " ++ T.unpack n)
             | (n, t) <- invalidTexts ]

  , test "diagnostics name the path and report every problem at once" $
      let txt = "{\"format\": \"module-sketch\", \"version\": 2, \"columns\": 2, \"rows\": 2, \"cells\": ["
             <> "{\"col\": 0, \"row\": 0, \"kind\": \"banana\"}, {\"col\": 9, \"row\": 0, \"kind\": \"knob\"}]}"
      in case decodeSketchText txt of
           Right _ -> [ "accepted" ]
           Left es -> expectAll
             [ (length es == 2, "expected two diagnostics, got " ++ show es)
             , (any ("cells[0].kind" `T.isInfixOf`) es, "first path missing: " ++ show es)
             , (any ("cells[1].col" `T.isInfixOf`) es, "second path missing: " ++ show es) ]

  , test "a label is optional and omitted when empty" $
      let s = Sketch "" 1 1 [Cell 0 0 Knob ""]
      in expectAll
           [ (not ("label" `T.isInfixOf` encodeSketchText s), "an empty label was written")
           , (decodeSketchText (encodeSketchText s) == Right s, "round trip") ]

    -- The limits ---------------------------------------------------------------
  , test "the grid limits are what the hardware allows, not a guess" $
      expectAll
        [ (maxRows == 6, "rows " ++ show maxRows)
        , (maxColumns == 6, "columns " ++ show maxColumns)
        , (glRowPitchAt gridLimits maxRows >= jackStackMinimum
          , "the largest grid spaces rows " ++ show (glRowPitchAt gridLimits maxRows) ++ " mm, under the jack minimum")
        , (glRowPitchAt gridLimits (maxRows + 1) < jackStackMinimum
          , "one more row would still fit, so the limit is too tight")
        , (glBand gridLimits > 0 && glBand gridLimits < eurorackPcbHeight
          , "the vertical band " ++ show (glBand gridLimits) ++ " is not inside the board") ]

  , test "every column count maps to a panel in the module policy" $
      let widths = [ (n, smallestWidthFor n) | n <- [1 .. maxColumns] ]
      in expectAll
           [ (all (\(_, hp) -> maybe False (\h -> h >= 4 && h <= 20) hp) widths
             , "widths " ++ show widths)
           , (widths == [(1, Just 4), (2, Just 8), (3, Just 10), (4, Just 14), (5, Just 16), (6, Just 20)]
             , "widths " ++ show widths)
           , (smallestWidthFor (maxColumns + 1) == Nothing, "a grid past the limit claimed a width") ]

  , test "a sketch cannot be built past the limits" $
      let over field n = "{\"format\": \"module-sketch\", \"version\": 2, \"" <> field <> "\": " <> T.pack (show (n :: Int))
                       <> ", \"" <> (if field == "columns" then "rows" else "columns") <> "\": 1, \"cells\": []}"
      in expectAll
           [ (isLeft (decodeSketchText (over "columns" (maxColumns + 1))), "too many columns accepted")
           , (isLeft (decodeSketchText (over "rows" (maxRows + 1))), "too many rows accepted")
           , (isRight (decodeSketchText (over "columns" maxColumns)), "the largest legal grid was refused")
           , (isRight (decodeSketchText (over "rows" maxRows)), "the tallest legal grid was refused") ]

  , test "the kinds are distinct and every one survives a round trip" $
      let ids = map kindId kinds
          s = Sketch "" (length kinds) 1 [ Cell i 0 k "" | (i, k) <- zip [0 ..] kinds ]
      in expectAll
           [ (ids == nub ids && all (not . T.null) ids, "ids " ++ show ids)
           , (length kinds <= maxColumns, "more kinds than columns, so this fixture cannot be built")
           , (decodeSketchText (encodeSketchText s) == Right s, "round trip " ++ show (decodeSketchText (encodeSketchText s)))
           , (all (\k -> lookupKind (kindId k) == Just k) kinds, "a kind does not survive its own id") ]

  , test "no kind's envelope exceeds the two that set the limits" $
      -- The button's envelope is a placeholder until a momentary part is
      -- chosen. This holds that a placeholder, or any kind added later,
      -- cannot silently change how big the grid is: the knob still sets the
      -- top and the sides, and the jack still sets the bottom.
      expectAll
        [ (all (\k -> envAbove (envelopeOf k) <= envAbove (envelopeOf Knob)) kinds
          , "a kind reaches higher above its centre than the knob")
        , (all (\k -> envBelow (envelopeOf k) <= envBelow (envelopeOf Jack)) kinds
          , "a kind reaches deeper below its centre than the jack")
        , (all (\k -> envSide (envelopeOf k) <= envSide (envelopeOf Knob)) kinds
          , "a kind is wider than the knob") ]

  , test "every kind carries a note, and the two that need it say so" $
      expectAll
        [ (all (\k -> T.length (kindNote k) > 10) kinds, "a kind has no note")
        , ("power cycle" `T.isInfixOf` kindNote Switch, "the switch note does not mention surviving a power cycle")
        , ("momentary" `T.isInfixOf` kindNote Button, "the button note does not say it is momentary")
        , (kindNote Button `T.isInfixOf` catalogueJs, "the notes do not reach the browser") ]

  , test "the envelopes behind the limits come from real parts" $
      expectAll
        [ (all (\k -> let e = envelopeOf k in envAbove e > 0 && envBelow e > 0 && envSide e > 0) kinds
          , "an envelope is zero or negative")
        , (all (\k -> not (T.null (envSource (envelopeOf k)))) kinds, "an envelope has no source")
        , ("placeholder" `T.isInfixOf` envSource (envelopeOf Button)
          , "the button's envelope is a stand-in and must say so until a part is chosen")
        , (envBelow (envelopeOf Jack) > envBelow (envelopeOf Knob)
          , "the jack should be the deepest part; it is what limits the rows") ]

    -- Export ---------------------------------------------------------------------
  , test "the exported scripts are JSON in a UMD shell" $
      let bodyOf js = T.unlines (takeWhile (not . ("if (typeof module" `T.isInfixOf`))
                                           (dropWhile (not . ("var data" `T.isInfixOf`)) (T.lines js)))
          extract js = T.strip (T.dropEnd 1 (T.strip (T.drop 1 (T.dropWhile (/= '=') (bodyOf js)))))
      in expectAll
           [ (isRight (parseJson (extract catalogueJs)), "catalogue.js body is not JSON")
           , (isRight (parseJson (extract vectorsJs)), "vectors.js body is not JSON")
           , (all (\(n, _) -> ("\"name\": \"" <> n <> "\"") `T.isInfixOf` vectorsJs) fixtures, "a fixture is missing from the vectors")
           , (all (\(n, _) -> ("\"name\": \"" <> n <> "\"") `T.isInfixOf` vectorsJs) invalidTexts, "a rejection case is missing") ]

  , test "the limits explanation states the numbers it depends on" $
      expectAll
        [ (T.pack (show maxRows) `T.isInfixOf` limitsReport, "the row limit is not in the explanation")
        , (T.pack (show maxColumns) `T.isInfixOf` limitsReport, "the column limit is not in the explanation")
        , ("13.6 mm" `T.isInfixOf` limitsReport, "the jack minimum is not in the explanation")
        , (T.length limitsReport > 80, "the explanation is too short to check") ]

  , test "encoded text uses LF only, because the browser writes the same file" $
      concat [ expect (not ("\r" `T.isInfixOf` encodeSketchText s))
                      ("fixture " ++ T.unpack n ++ " contains a carriage return")
             | (n, s) <- fixtures ]

  , test "the bundle inlines local assets and prefixes the storage hook" $
      let html = T.unlines [ "<!DOCTYPE html>", "<html><head>", "<meta charset=\"utf-8\">"
                           , "<link rel=\"stylesheet\" href=\"style.css\">"
                           , "<script src=\"catalogue.js\"></script>", "</head><body>"
                           , "<script src=\"https://example/x.js\"></script>", "</body></html>" ]
          out = unsafePerformIO (bundle html (\rel -> pure ("/* " <> rel <> " */")))
          ls = T.lines out
      in expectAll
           [ (take 3 ls == ["<!DOCTYPE html>", "<html><head>", "<script src=\"/sharedLocalStorage.js\"></script>"]
             , "hook not first: " ++ show (take 3 ls))
           , ("<style>" `elem` ls && "/* style.css */" `elem` ls, "stylesheet not inlined")
           , ("<script>" `elem` ls && "/* catalogue.js */" `elem` ls, "script not inlined")
           , ("<script src=\"https://example/x.js\"></script>" `elem` ls, "remote script touched") ]

  , test "the panel width table still has the entries the limits rest on" $
      expectAll
        [ (lookup 20 eurorackPanelWidths == Just 101.3, "20 HP")
        , (lookup 4 eurorackPanelWidths == Just 20.0, "4 HP") ]
  ]
  where
    isLeft :: Either a b -> Bool
    isLeft (Left _) = True
    isLeft _ = False
    isRight :: Either a b -> Bool
    isRight (Right _) = True
    isRight _ = False
