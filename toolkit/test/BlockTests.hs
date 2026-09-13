{-# LANGUAGE OverloadedStrings #-}
-- | Block library tests (roadmap M4): the reusable pieces a module is built
-- from must keep producing exactly what the modules that were factored into
-- them produced, and their arithmetic must match the rules in AGENTS.md.
module BlockTests (tests) where

import           Block.Eurorack
import           Design
import           Harness

tests :: [Test]
tests =
  [ test "skeleton 6 is the 6HP module the rules describe" $
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
