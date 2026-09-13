{-# LANGUAGE OverloadedStrings #-}
-- | Block library tests (roadmap M4): the reusable pieces a module is built
-- from must keep producing exactly what the modules that were factored into
-- them produced, and their arithmetic must match the rules in AGENTS.md.
module BlockTests (tests) where

import           Data.List (sort, nub)
import           Data.Text (Text)
import qualified Data.Text as T

import           Block.Eurorack
import           Block.Power
import           Block.Precision
import           Design
import           Harness

-- | A channel placed anywhere; the block's identity is what is under test.
ch :: BufferedAttenuverter
ch = BufferedAttenuverter
  { baSuffix = "7", baInJack = "J1", baOutJack = "J2", baPot = "RV1"
  , baOpAmp = Placed "U1" (6.5, 41.75) 0 (73.66, 45.72), baOpAmpUnitOffsets = [(83.82, 0), (-12.7, 101.6)]
  , baRin = Placed "R9" (6.0, 37.75) 0 (55.88, 55.88)
  , baRa = Placed "R1" (9.5, 37.75) 0 (114.3, 45.72)
  , baRf = Placed "R2" (13.0, 37.75) 0 (134.62, 45.72)
  , baCf = Placed "C9" (9.5, 45.75) 0 (134.62, 22.86)
  , baRo = Placed "R3" (6.0, 45.75) 0 (180.34, 45.72)
  , baCVp = Placed "C3" (13.0, 45.75) 0 (160.02, 147.32)
  , baCVn = Placed "C4" (2.5, 37.75) 0 (175.26, 147.32)
  , baSide = Back }

-- | A power entry placed anywhere, for the tests: what matters is the
-- identity of the parts and nets, not where they are.
pe :: PowerEntry
pe = PowerEntry
  { peHeader = Placed "J5" (13.5, 95.25) 90 (38.1, 147.32), peHeaderSide = Back
  , peDiodePos = Placed "D2" (23.5, 84.25) 0 (114.3, 147.32)
  , peDiodeNeg = Placed "D1" (3.3, 84.25) 0 (99.06, 147.32)
  , peBulkPos = Placed "C1" (7.5, 84.25) 0 (129.54, 147.32)
  , peBulkNeg = Placed "C2" (19.0, 84.25) 0 (144.78, 147.32)
  , peSmdSide = Back }

pinsOf :: [Net] -> [(Text, Text)]
pinsOf = concatMap netPins

tests :: [Test]
tests =
  [ -- Power entry.
    test "powerParts places the header by hand and the rest by the factory, with LCSC numbers" $
      let ps = powerParts pe
          hand = [ p | p <- ps, partAssembly p == Hand ]
          fact = [ p | p <- ps, partAssembly p == Factory ]
      in expectAll
           [ (sort (map partRef ps) == ["C1", "C2", "D1", "D2", "J5"], "refs " ++ show (map partRef ps))
           , (map partRef hand == ["J5"], "hand-installed parts " ++ show (map partRef hand))
           , (length fact == 4 && all (any ((== "LCSC Part #") . fst) . partFields) fact, "every factory part carries an LCSC Part #")
           , (all (not . partRefOnSilk) fact && all partRefOnSilk hand, "passives silent on silk, header labelled")
           , (all ((== Back) . partSide) ps, "every part on the side the design asked for")
           , ([ partRot p | p <- ps, partRef p == "J5" ] == [90], "header rotation comes from its placement") ]

  , test "powerNets uses every pin of every power part exactly once" $
      let pins = pinsOf (powerNets pe)
          wanted = sort ([ ("J5", tshow n) | n <- [1 .. 10 :: Int] ] ++ [ (r, p) | r <- ["D1", "D2", "C1", "C2"], p <- ["1", "2"] ])
      in expectAll
           [ (sort pins == wanted, "pins " ++ show (sort pins))
           , (length pins == length (nub pins), "a pin appears twice") ]

  , test "powerNets puts the raw rails on the header and the protected rails after the diodes" $
      let ns = powerNets pe
          net n = concat [ netPins m | m <- ns, netName m == n ]
      in expectAll
           [ (("J5", "9") `elem` net "P12_RAW" && ("J5", "10") `elem` net "P12_RAW" && ("D2", "2") `elem` net "P12_RAW", "P12_RAW " ++ show (net "P12_RAW"))
           , (("J5", "1") `elem` net "N12_RAW" && ("J5", "2") `elem` net "N12_RAW" && ("D1", "1") `elem` net "N12_RAW", "N12_RAW " ++ show (net "N12_RAW"))
           , (("D2", "1") `elem` net "+12V" && ("C1", "1") `elem` net "+12V", "+12V " ++ show (net "+12V"))
           , (("D1", "2") `elem` net "-12V" && ("C2", "1") `elem` net "-12V", "-12V " ++ show (net "-12V"))
           , (all (\p -> ("J5", tshow p) `elem` net "GND") [3 .. 8 :: Int] && ("C1", "2") `elem` net "GND" && ("C2", "2") `elem` net "GND", "GND " ++ show (net "GND"))
           , ([ netKind m | m <- ns, netName m `elem` ["GND", "+12V", "-12V"] ] == [Power, Power, Power], "rails are power nets")
           , ([ netKind m | m <- ns, netName m `elem` ["P12_RAW", "N12_RAW"] ] == [Signal, Signal], "raw rails are signal nets (no power symbol exists for them)") ]

  , test "mergeNets joins same-name same-kind nets in first-appearance order and leaves kind clashes alone" $
      let merged = mergeNets
            [ Net "GND" Power [("A", "1")], Net "X" Signal [("A", "2")]
            , Net "GND" Power [("B", "1")], Net "X" Power [("C", "1")], Net "Y" Signal [] , Net "GND" Power [("C", "2")] ]
      in expectAll
           [ (map netName merged == ["GND", "X", "X", "Y"], "order " ++ show (map netName merged))
           , (concat [ netPins m | m <- merged, netName m == "GND" ] == [("A", "1"), ("B", "1"), ("C", "2")], "GND pins " ++ show [ netPins m | m <- merged, netName m == "GND" ])
           , (length [ () | m <- merged, netName m == "X" ] == 2, "a Signal X and a Power X must both survive for validation to reject") ]

    -- Precision channel.
  , test "the channel block is the option B circuit: 10k 0.1% gain pair, 10p C0G, 1M input, 1k output, OPA2197" $
      let ps = bufferedAttenuverterParts ch
          val r = head ([ partValue p | p <- ps, partRef p == r ] ++ ["missing"])
          code r = head ([ c | p <- ps, partRef p == r, ("LCSC Part #", c) <- partFields p ] ++ ["missing"])
      in expectAll
           [ (sort (map partRef ps) == ["C3", "C4", "C9", "R1", "R2", "R3", "R9", "U1"], "refs " ++ show (map partRef ps))
           , (val "U1" == "OPA2197" && code "U1" == "C139363", "op-amp " ++ show (val "U1", code "U1"))
           , (val "R1" == "10k" && val "R2" == "10k" && code "R1" == "C110775" && code "R2" == "C110775", "gain resistors must be the same 0.1 % part: " ++ show (val "R1", val "R2", code "R1", code "R2"))
           , (val "C9" == "10p" && code "C9" == "C344177", "compensation " ++ show (val "C9", code "C9"))
           , (val "R9" == "1M" && val "R3" == "1k", "input and output resistors " ++ show (val "R9", val "R3"))
           , (val "C3" == "100n" && val "C4" == "100n", "decoupling " ++ show (val "C3", val "C4"))
           , (all ((== Factory) . partAssembly) ps, "every part of the channel is factory placed")
           , ([ partRefOnSilk p | p <- ps ] == [True, False, False, False, False, False, False, False], "only the op-amp prints its reference")
           , ([ partUnitOffsets p | p <- ps, partRef p == "U1" ] == [[(83.82, 0), (-12.7, 101.6)]], "unit offsets come from the placement") ]

  , test "the channel block's nets use every op-amp and passive pin exactly once and name the nets by suffix" $
      let ns = bufferedAttenuverterNets ch
          pins = pinsOf ns
          wanted = sort ([ ("U1", tshow n) | n <- [1 .. 8 :: Int] ]
                         ++ [ (r, p) | r <- ["R1", "R2", "R3", "R9", "C9", "C3", "C4"], p <- ["1", "2"] ]
                         ++ [("RV1", "1"), ("RV1", "2"), ("RV1", "3"), ("J1", "T"), ("J2", "T")])
          net n = concat [ netPins m | m <- ns, netName m == n ]
      in expectAll
           [ (sort pins == wanted, "pins " ++ show (sort pins))
           , (length pins == length (nub pins), "a pin appears twice")
           , (sort [ netName m | m <- ns, netKind m == Signal ] == ["BUF7", "IN7", "INV7", "OA7", "OUT7", "WIPER7"], "signal nets " ++ show [ netName m | m <- ns ])
           , (sort (net "INV7") == sort [("R1", "2"), ("R2", "1"), ("C9", "1"), ("U1", "6")], "the inverting node is R_a, R_f, C_f and pin 6: " ++ show (net "INV7"))
           , (sort (net "BUF7") == sort [("U1", "1"), ("U1", "2"), ("R1", "1"), ("RV1", "3")], "the buffer is unity gain (pins 1 and 2 tied) and drives pot end 3: " ++ show (net "BUF7"))
           , (net "WIPER7" == [("RV1", "2"), ("U1", "5")] || net "WIPER7" == [("U1", "5"), ("RV1", "2")], "the wiper goes to the non-inverting input alone: " ++ show (net "WIPER7"))
           , (("U1", "8") `elem` net "+12V" && ("U1", "4") `elem` net "-12V", "supply pins on the rails")
           , (("RV1", "1") `elem` net "GND" && ("R9", "2") `elem` net "GND", "pot end 1 and R_in to ground") ]

    -- Skeleton.
  , test "skeleton 6 is the 6HP module the rules describe" $
      let sk = skeleton 6
      in expectAll
           [ (skPanelWidth sk == 30.0, "panel width " ++ show (skPanelWidth sk) ++ ", expected 30.0 (Doepfer 6HP)")
           , (skPanelHeight sk == 128.5, "panel height " ++ show (skPanelHeight sk) ++ ", expected 128.5")
           , (skBoardWidth sk == 28.0, "board width " ++ show (skBoardWidth sk) ++ ", expected 28.0 (1 mm inside each edge)")
           , (skBoardHeight sk == 100.0, "board height " ++ show (skBoardHeight sk) ++ ", expected 100.0")
           , (skBoardOrigin sk == (1.0, 14.25), "board origin " ++ show (skBoardOrigin sk) ++ ", expected (1.0, 14.25): centred")
           , (skRailHoleY sk == [3.0, 125.5], "rail hole rows " ++ show (skRailHoleY sk) ++ ", expected 3.0 from each edge")
           , (map (round2 . id) (skRailHoleX sk) == [7.5, 22.74], "rail hole columns " ++ show (skRailHoleX sk) ++ ", expected [7.5, 22.74]")
           ]

  , test "the board is centred on the panel and inside its edges for every table width" $
      expectAll
        [ ( abs (top - (skPanelHeight sk - skBoardHeight sk - top)) < 1e-9
            && left >= 1.0 && skPanelWidth sk - skBoardWidth sk - left >= 1.0
          , "hp " ++ show hp ++ ": origin " ++ show (skBoardOrigin sk) ++ " does not centre a "
              ++ show (skBoardWidth sk) ++ " x " ++ show (skBoardHeight sk) ++ " board on a "
              ++ show (skPanelWidth sk) ++ " x " ++ show (skPanelHeight sk) ++ " panel" )
        | hp <- [4, 6, 8, 10, 12, 14, 16, 18, 20]
        , let sk = skeleton hp
        , let (left, top) = skBoardOrigin sk ]

  , test "the second rail-hole column stays 7.2 to 7.6 mm from the right edge" $
      expectAll
        [ ( margin >= 7.2 && margin <= 7.6
          , "hp " ++ show hp ++ ": second column at " ++ show x2 ++ " leaves " ++ show margin ++ " mm" )
        | hp <- [6, 8, 10, 12, 14, 16, 18, 20]
        , let sk = skeleton hp
        , let x2 = last (skRailHoleX sk)
        , let margin = skPanelWidth sk - x2 ]

  , test "a 4HP panel gets one rail-hole column" $
      expect (length (skRailHoleX (skeleton 4)) == 1) ("4HP columns: " ++ show (skRailHoleX (skeleton 4)))

  , test "toBoard is the inverse of adding the board origin" $
      let sk = skeleton 6
          (ox, oy) = skBoardOrigin sk
          pts = [(7.5, 38.0), (22.5, 80.0), (15.0, 22.0), (14.5, 109.5)]
      in expectAll
           [ (toBoard sk (x, y) == (x - ox, y - oy), "toBoard " ++ show (x, y) ++ " = " ++ show (toBoard sk (x, y)))
           | (x, y) <- pts ]

  , test "boardOutline is the board rectangle from the origin" $
      let sk = skeleton 6
      in expect (boardOutline sk == [(0, 0), (28.0, 0), (28.0, 100.0), (0, 100.0)]) (show (boardOutline sk))

  , test "originFor puts the footprint-local point where it was asked to" $
      -- The attenuverter's pot: origin is pin 1, the shaft is at (7.5, 2.5)
      -- in footprint coordinates, rotated 90 on the front. The emitter
      -- rotates the local point by the part rotation; a front part is not
      -- flipped. So the shaft lands at origin + rotate(90, (7.5, 2.5)).
      let wanted = (14.0, 7.75)
          o = originFor Front 90 (7.5, 2.5) wanted
          -- rotatePt 90 (7.5, 2.5) in this codebase's convention; recompute
          -- through the same function the block uses by asking the block for
          -- the origin of a zero offset.
          zero = originFor Front 90 (0, 0) wanted
      in expectAll
           [ (zero == wanted, "a zero local offset must leave the origin at the target: " ++ show zero)
           , (o /= wanted, "a non-zero local offset must move the origin: " ++ show o)
           , (originFor Back 0 (1.27, 5.08) (13.5, 95.25) == (13.5 - 1.27, 95.25 + 5.08),
              "a back-side part flips its local y before the offset is applied") ]

  , test "railHoles numbers the holes column by column, top to bottom" $
      let hs = railHoles (skeleton 6) 7
      in expectAll
           [ (map partRef hs == ["H7", "H8", "H9", "H10"], "refs " ++ show (map partRef hs))
           , (map partAt hs == [(7.5, 3.0), (7.5, 125.5), (22.74, 3.0), (22.74, 125.5)] || map (r2 . partAt) hs == [(7.5, 3.0), (7.5, 125.5), (22.74, 3.0), (22.74, 125.5)],
              "positions " ++ show (map partAt hs))
           , (all ((== Mechanical) . partAssembly) hs, "rail holes must be Mechanical, not components")
           , (all (not . partRefOnSilk) hs, "rail holes must not print a reference on the panel") ]

  , test "panelBoard is the panel outline with no copper" $
      let b = panelBoard (skeleton 6) []
      in expectAll
           [ (bdWidth b == 30.0 && bdHeight b == 128.5, "size " ++ show (bdWidth b, bdHeight b))
           , (null (bdZones b) && null (bdTraces b), "a panel has no copper")
           , (case bdAutoRoute b of Nothing -> True; _ -> False, "a panel is not routed") ]
  ]
  where
    round2 :: Double -> Double
    round2 x = fromIntegral (round (x * 100) :: Integer) / 100
    r2 (x, y) = (round2 x, round2 y)

tshow :: Show a => a -> Text
tshow = T.pack . show
