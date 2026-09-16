{-# LANGUAGE OverloadedStrings #-}
-- | Sketch format and panel-model tests (roadmap S1): the sparse fixture
-- round-trips without losing intent, invalid inputs fail clearly, and the
-- geometry agrees with the skeleton and the transforms the generated boards
-- already use.
module SketchTests (tests) where

import           Data.List        (nub, sort)
import           Data.Text        (Text)
import qualified Data.Text        as T
import           System.IO.Unsafe (unsafePerformIO)

import           Attenuverter     (attenuverter, potPanelAt)
import           Block.Eurorack
import           Design
import           Harness
import           Route.Geometry   (rotatePt)
import           Sketch.Catalogue
import           Sketch.Check
import           Sketch.Export
import           Sketch.Fixtures
import           Sketch.Json
import           Sketch.Model

near :: (Double, Double) -> (Double, Double) -> Bool
near (a, b) (c, d) = abs (a - c) < 1e-9 && abs (b - d) < 1e-9

kinds :: Sketch -> [(Text, [Text])]
kinds s = sort [ (fnKind f, sort (fnControls f)) | f <- checkSketch s, fnSeverity f /= Note ]

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
           , (renderNumber 20 == "20" && renderNumber 14.25 == "14.25" && renderNumber (-6.41) == "-6.41" && renderNumber 0.1 == "0.1"
             , "number formatting " ++ show (map renderNumber [20, 14.25, -6.41, 0.1])) ]

  , test "JSON parser is strict" $
      let bad = [ "{\"a\": 1,}", "[1,]", "{a: 1}", "{'a': 1}", "NaN", "Infinity", "1e999", "-", "01", "1.", ".5", "+1"
                , "{\"a\": 1 \"b\": 2}", "\"unterminated", "\"tab\tinside\"", "{\"a\": 1, \"a\": 2}", "[1] 2", "", "  "
                , "\"\\uD800\"", "\"\\x41\"", "tru" ]
          results = [ (t, parseJson t) | t <- bad ]
      in [ "accepted " ++ show t | (t, Right _) <- results ]

  , test "JSON parser accepts what the grammar allows" $
      expectAll
        [ (parseJson " [ ] " == Right (JArray []), "spaces around an empty array")
        , (parseJson "{\"s\": \"\\u00e9\\uD83D\\uDE00\"}" == Right (JObject [("s", JString "\233\x1F600")]), "escapes and a surrogate pair")
        , (parseJson "-0.5e-2" == Right (JNumber (-0.005)), "negative exponent")
        , (parseJson "1E3" == Right (JNumber 1000), "capital exponent") ]

    -- Format ----------------------------------------------------------------
  , test "every fixture round-trips through its JSON text unchanged" $
      concat [ expect (decodeSketchText (encodeSketchText s) == Right s) ("fixture " ++ T.unpack n ++ ": " ++ show (decodeSketchText (encodeSketchText s)))
             | (n, s) <- fixtures ]

  , test "the sparse fixture keeps its empty cells, span, offset, rotation and group" $
      case decodeSketchText (encodeSketchText sparseMixed) of
        Left es -> [ "decode failed: " ++ show es ]
        Right s ->
          let byId i = head [ c | c <- sxControls s, ctId c == i ]
              occupied = nub (concatMap controlCells (sxControls s))
          in expectAll
               [ (ctSpan (byId "freq") == (2, 1), "freq span")
               , (ctOffset (byId "out-led") == (6, -6), "LED offset")
               , (ctRotation (byId "level") == 90, "pot rotation")
               , (ctGroup (byId "in") == Just "ch1", "group membership")
               , ((0, 2) `notElem` occupied && (1, 0) `notElem` occupied, "empty cells stay empty")
               , (length (sxControls s) == 6, "control count") ]

  , test "encoded text uses LF only, because the browser writes the same file" $
      -- The app writes these with an explicit LF handle (Main.writeTextLf);
      -- a CR reaching the Text itself would defeat that.
      concat [ expect (not ("\r" `T.isInfixOf` encodeSketchText s)) ("fixture " ++ T.unpack n ++ " contains a carriage return")
             | (n, s) <- fixtures ]

  , test "every invalid text is refused with a diagnostic" $
      concat [ case decodeSketchText t of
                 Right _ -> [ "accepted: " ++ T.unpack n ]
                 Left es -> expect (not (null es) && all (not . T.null) es) ("empty diagnostic for " ++ T.unpack n)
             | (n, t) <- invalidTexts ]

  , test "diagnostics name the path and report every problem at once" $
      let txt = "{\"format\": \"pcbgen-sketch\", \"version\": 1, \"hp\": 6, \"grid\": {\"origin\": {\"x\": 7.5, \"y\": 20}, \"pitch\": {\"x\": 15, \"y\": 15}},"
             <> " \"controls\": [{\"id\": \"a\", \"hardware\": \"nope\", \"cell\": {\"col\": 0, \"row\": 0}}, {\"id\": \"b\", \"hardware\": \"pot-9mm\", \"cell\": {\"col\": 0, \"row\": 0}, \"rotation\": 30}]}"
      in case decodeSketchText txt of
           Right _ -> [ "accepted" ]
           Left es -> expectAll
             [ (length es == 2, "expected two diagnostics, got " ++ show es)
             , (any ("controls[0].hardware" `T.isInfixOf`) es, "first path missing: " ++ show es)
             , (any ("controls[1].rotation" `T.isInfixOf`) es, "second path missing: " ++ show es) ]

  , test "optional fields default and are omitted when default" $
      let txt = encodeSketchText emptyFour
      in expectAll
           [ (not ("\"groups\"" `T.isInfixOf` txt) && not ("\"notes\"" `T.isInfixOf` txt), "empty groups/notes written")
           , (not ("\"span\"" `T.isInfixOf` encodeSketchText emptyFour), "span written for nothing")
           , (decodeSketchText "{\"format\": \"pcbgen-sketch\", \"version\": 1, \"hp\": 6, \"grid\": {\"origin\": {\"x\": 7.5, \"y\": 20}, \"pitch\": {\"x\": 15, \"y\": 15}}, \"controls\": []}"
                == Right (Sketch "" Provisional 6 (Grid (7.5, 20) (15, 15) "") [] [] []), "minimal sketch") ]

    -- Geometry ------------------------------------------------------------------
  , test "a sketched pot lands where the attenuverter's design put it" $
      let s = skeleton 6
          g = Grid (7.5, 22.0) (7.5, 42.0) ""     -- a grid whose cell (1, 0) is the attenuverter's RV1 shaft
          c = Control "rv1" "pot-9mm" (1, 0) (1, 1) (0, 0) 90 "" Nothing
          hw = maybe (error "hardware missing") id $ lookupHardware "pot-9mm"
          p = placeControl s g c hw
          rv1 = head [ q | q <- modParts attenuverter, partRef q == "RV1" ]
      in expectAll
           [ (near (plCentre p) (potPanelAt 1), "centre " ++ show (plCentre p))
           , (near (plFootprintOrigin p) (partAt rv1), "footprint origin " ++ show (plFootprintOrigin p) ++ " vs design " ++ show (partAt rv1))
           , (partRot rv1 == 90, "the design's rotation changed; update the fixture") ]

  , test "a jack's footprint origin is its centre and its board coordinates follow toBoard" $
      let s = skeleton 6
          g = Grid (7.5, 38.0) (15, 42) ""
          c = Control "j1" "jack-ts" (0, 0) (1, 1) (0, 0) 0 "" Nothing
          hw = maybe (error "hardware missing") id $ lookupHardware "jack-ts"
          p = placeControl s g c hw
      in expectAll
           [ (near (plBoardCentre p) (6.5, 38.0 - eurorackPcbTop), "board centre " ++ show (plBoardCentre p))
           , (near (plFootprintOrigin p) (plBoardCentre p), "jack origin is not its barrel")
           , (boxNear (plCourtyard p) (Box 2.5 36.58 12.5 50.98), "courtyard " ++ show (plCourtyard p)) ]

  , test "boxRotate agrees with rotatePt at every quarter turn" $
      concat
        [ expect (boxNear (boxRotate r b) (fromCorners r b)) ("rotation " ++ show r ++ ": " ++ show (boxRotate r b) ++ " vs " ++ show (fromCorners r b))
        | r <- [0, 90, 180, 270], let b = Box (-8.65) (-6.41) 5.1 6.41 ]

  , test "default grids centre their columns and match the attenuverter's jack columns at 6HP" $
      let p15 = maybe (error "profile missing") id (lookupProfile "candidate-15")
      in expectAll
           [ (columnsFor 6 15 == 2 && defaultGridOrigin 6 p15 == (7.5, 20), "6HP: " ++ show (defaultGridOrigin 6 p15))
           , (columnsFor 8 15 == 2 && near (defaultGridOrigin 8 p15) (12.65, 20), "8HP: " ++ show (defaultGridOrigin 8 p15))
           , (columnsFor 4 15 == 1 && defaultGridOrigin 4 p15 == (10, 20), "4HP: " ++ show (defaultGridOrigin 4 p15))
           , (columnsFor 12 15 == 4, "12HP columns " ++ show (columnsFor 12 15))
           , (rowsFor p15 == 6, "rows " ++ show (rowsFor p15))
           , (all (\hp -> let (ox, _) = defaultGridOrigin hp p15 in ox >= minCentreEdgeDistance - 1e-9) [3 .. 42], "a default column sits too near an edge (1HP and 2HP cannot hold a control)") ]

    -- Checks ------------------------------------------------------------------
  , test "the sparse fixture checks clean: notes only" $
      let fs = checkSketch sparseMixed
      in expectAll
           [ (null [ f | f <- fs, fnSeverity f /= Note ], "unexpected findings: " ++ show [ (fnKind f, fnControls f) | f <- fs, fnSeverity f /= Note ])
           , ("provisional-grid" `elem` map fnKind fs, "no provisional note")
           , (any (\f -> fnKind f == "no-footprint" && fnControls f == ["cycle"]) fs, "the toggle's missing footprint is not noted")
           , (any (\f -> fnKind f == "unverified-front" && "level" `elem` fnControls f) fs, "unverified front envelopes not noted") ]

  , test "the conflicts fixture reports every conflict kind, and only the expected ones" $
      let got = kinds conflicts
          wanted = sort
            [ ("cell-overlap", ["a", "b"]), ("front-overlap", ["a", "b"]), ("back-overlap", ["a", "b"])
            , ("outside-board-zone", ["low"])
            , ("outside-panel", ["far"]), ("outside-board-zone", ["far"])
            , ("offset-too-large", ["shift"])
            , ("access-overlap", ["p1", "p2"])
            , ("rail-keepout", ["top"]), ("outside-board-zone", ["top"]) ]
      in expectAll
           [ (got == wanted, "findings\n  got    " ++ show got ++ "\n  wanted " ++ show wanted) ]

  , test "an LED inside its jack's cell is not a cell conflict, but two jacks are" $
      let base = sparseMixed
          twoJacks = base { sxControls = [ Control "x" "jack-ts" (0, 1) (1, 1) (0, 0) 0 "" Nothing
                                         , Control "y" "jack-ts" (0, 1) (1, 1) (0, 0) 0 "" Nothing ] }
      in expectAll
           [ (null [ f | f <- checkSketch base, fnKind f == "cell-overlap" ], "LED and jack flagged")
           , ([ fnControls f | f <- checkSketch twoJacks, fnKind f == "cell-overlap" ] == [["x", "y"]], "two jacks not flagged") ]

  , test "narrowing the panel makes an outside conflict, never a move" $
      let narrowed = sparseMixed { sxHP = 4 }
          fs = checkSketch narrowed
          outside = sort (nub (concat [ fnControls f | f <- fs, fnKind f `elem` ["outside-panel", "outside-board-zone"] ]))
      in expectAll
           [ (sxControls narrowed == sxControls sparseMixed, "controls changed")
           , ("out" `elem` outside && "cycle" `elem` outside, "the right-hand column is not reported outside: " ++ show outside) ]

  , test "the touching case is not an overlap" $
      expectAll
        [ (not (boxesOverlap (Box 0 0 1 1) (Box 1 0 2 1)), "touching boxes overlap")
        , (boxesOverlap (Box 0 0 1 1) (Box 0.5 0.5 2 2), "overlapping boxes do not overlap")
        , (not (shapesOverlap (Circle 8, (0, 0)) (Circle 8, (8, 0))), "touching circles overlap")
        , (shapesOverlap (Circle 8, (0, 0)) (Rect 4 4, (5, 0)), "circle into rect not detected")
        , (not (shapesOverlap (Circle 8, (0, 0)) (Rect 4 4, (6, 0))), "circle touching rect flagged") ]

    -- Catalogue and export -----------------------------------------------------
  , test "the catalogue is well-formed" $
      let ids = map hwId catalogue
      in expectAll
           [ (ids == nub ids && all validIdentifier ids, "ids " ++ show ids)
           , (all (\h -> let Box x1 y1 x2 y2 = hwCourtyard h in x1 < x2 && y1 < y2) catalogue, "a courtyard is inside out")
           , (all (\h -> hwHoleDiameter h > 0 && not (null (hwRotations h)) && 0 `elem` hwRotations h) catalogue, "hole or rotations")
           , (all (\h -> hwStatus h /= InUse || hwFootprint h /= Nothing) catalogue, "an in-use part without a footprint")
           , (map gpId gridProfiles == nub (map gpId gridProfiles), "duplicate profile") ]

  , test "the exported scripts are JSON wrapped in a UMD shell" $
      let bodyOf js = T.unlines (takeWhile (not . ("if (typeof module" `T.isInfixOf`)) (dropWhile (not . ("var data" `T.isInfixOf`)) (T.lines js)))
          extract js = T.strip (T.dropEnd 1 (T.strip (T.drop 1 (T.dropWhile (/= '=') (bodyOf js)))))
      in expectAll
           [ (either (const False) (const True) (parseJson (extract catalogueJs)), "catalogue.js body is not JSON")
           , (either (const False) (const True) (parseJson (extract vectorsJs)), "vectors.js body is not JSON")
           , (all (\(n, _) -> ("\"name\": \"" <> n <> "\"") `T.isInfixOf` vectorsJs) fixtures, "a fixture is missing from the vectors") ]

  , test "the bundle inlines local assets and prefixes the storage hook" $
      let html = T.unlines [ "<!DOCTYPE html>", "<html><head>", "<meta charset=\"utf-8\">", "<link rel=\"stylesheet\" href=\"style.css\">"
                           , "<script src=\"catalogue.js\"></script>", "</head><body>", "<script src=\"https://example/x.js\"></script>", "</body></html>" ]
          out = unsafePerformIO (bundle html (\rel -> pure ("/* " <> rel <> " */")))
          ls = T.lines out
      in expectAll
           [ (take 3 ls == ["<!DOCTYPE html>", "<html><head>", "<script src=\"/sharedLocalStorage.js\"></script>"], "hook not first: " ++ show (take 3 ls))
           , ("<style>" `elem` ls && "/* style.css */" `elem` ls, "stylesheet not inlined")
           , ("<script>" `elem` ls && "/* catalogue.js */" `elem` ls, "script not inlined")
           , ("<script src=\"https://example/x.js\"></script>" `elem` ls, "remote script touched") ]
  ]
  where
    boxNear (Box a b c d) (Box e f g h) = all (< 1e-9) [abs (a - e), abs (b - f), abs (c - g), abs (d - h)]
    fromCorners r (Box x1 y1 x2 y2) =
      let ps = [ rotatePt (fromIntegral r) (x, y) | x <- [x1, x2], y <- [y1, y2] ]
          xs = map fst ps
          ys = map snd ps
      in Box (minimum xs) (minimum ys) (maximum xs) (maximum ys)
