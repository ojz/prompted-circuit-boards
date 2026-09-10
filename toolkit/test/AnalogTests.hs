{-# LANGUAGE OverloadedStrings #-}
-- | Tests for the analog-intent checks (@Route.Analog@).
--
-- Two kinds here, and the distinction matters. The physics tests pin the
-- model to results derived independently: the capacitive-divider and
-- slope-limited limits of the coupling formula, which @nodebudget.py verify@
-- confirms against ngspice, and the solved capacitance table. The geometry
-- tests pin the line integral that turns copper into a capacitance.
--
-- The last test is a regression on a real board: the attenuverter's two
-- channels are physically separate today and its cross-channel coupling is
-- zero, so a future layout change that runs one channel's output beside the
-- other's wiper will fail here rather than in someone's headphones.
module AnalogTests (tests) where

import qualified Data.Text     as T

import           Attenuverter  (attenuverter)
import           Design
import           Emit.Pcb      (routeConfigFor, routeProblemFor)
import           Harness
import           Kicad.Library (newLibCache)
import           Route.Analog
import           Route.Geometry
import           Route.Router  (RouteResult (..), RoutedNet (..), autoroute)

tests :: [Test]
tests =
  [ tableIsMonotone
  , dividerLimit
  , slopeLimit
  , parallelRunIntegral
  , couplingIsLinearInParallelRun
  , couplingFallsWithGap
  , crossingCopperIsNotCharged
  , approachCouplesLessThanRunning
  , findsAMismatchedPair
  , findsAnOverLengthNet
  , attenuverterChannelsStaySeparate
  ]

-- | Coupling must fall with the gap, and the interpolation must not wander
-- off the solved points it interpolates between.
tableIsMonotone :: Test
tableIsMonotone = test "mutual capacitance falls with the gap" $ expectAll $
  [ (mutualPfPerMm a > mutualPfPerMm b
    , "coupling should fall from " ++ show a ++ " to " ++ show b ++ " mm")
  | (a, b) <- zip gaps (drop 1 gaps) ]
  ++
  [ (abs (mutualPfPerMm 0.2 - 0.03156) < 1e-9, "0.2 mm should be the solved value")
  , (abs (mutualPfPerMm 2.0 - 0.00395) < 1e-9, "2.0 mm should be the solved value")
    -- Held, not extrapolated, outside the solved range.
  , (mutualPfPerMm 0.05 == mutualPfPerMm 0.2, "below the table should hold the first entry")
  , (mutualPfPerMm 20 == mutualPfPerMm 2.0, "above the table should hold the last entry")
    -- An interpolated point has to sit between its neighbours.
  , (mutualPfPerMm 0.4 < mutualPfPerMm 0.3 && mutualPfPerMm 0.4 > mutualPfPerMm 0.5
    , "0.4 mm should interpolate between 0.3 and 0.5")
  ]
  where gaps = [0.2, 0.3, 0.5, 1.0, 2.0]

-- | An edge much faster than the node's time constant is a pure capacitive
-- divider: the resistor has no time to do anything.
dividerLimit :: Test
dividerLimit = test "a fast edge gives the capacitive divider" $
  let r = 1e6; cm = 0.24e-12; ct = 0.91e-12
      tr = 1e-11                      -- tr / tau is about 1e-5 here
      want = 5 * cm / (cm + ct)
      got = injectedVolts 5 tr r cm ct
  in expect (abs (got - want) / want < 0.01)
       ("fast-edge injection should be the divider " ++ show want ++ ", got " ++ show got)

-- | An edge much slower than the time constant is slope-limited: the node
-- tracks the current the ramp pushes through the coupling.
slopeLimit :: Test
slopeLimit = test "a slow edge gives the slope-limited result" $
  let r = 1e6; cm = 0.24e-12; ct = 0.91e-12
      tr = 1e-3                       -- tr / tau is about 900 here
      want = 10 * r * cm / tr
      got = injectedVolts 10 tr r cm ct
  in expect (abs (got - want) / want < 0.01)
       ("slow-edge injection should be " ++ show want ++ ", got " ++ show got)

-- | Two traces running alongside each other for a known length must integrate
-- to the length times the solved per-millimetre coupling.
parallelRunIntegral :: Test
parallelRunIntegral =
  test "a 10 mm parallel run at 0.5 mm integrates to the table value" $
    let quiet = [(F, (0, 0), (10, 0))]
        noisy = [(F, (0, 0.5), (10, 0.5))]
        got = coupledPf 0.05 quiet noisy
        want = 10 * mutualPfPerMm 0.5
    in expect (abs (got - want) / want < 0.02)
         ("expected about " ++ show want ++ " pF, got " ++ show got)

-- | The load-bearing property: coupling is linear in how far the two nets run
-- alongside each other. That is the claim the whole objective rests on, so it
-- is worth asserting exactly rather than approximately.
couplingIsLinearInParallelRun :: Test
couplingIsLinearInParallelRun =
  test "coupling doubles when the parallel run doubles" $
    let quiet n = [(F, (0, 0), (n, 0))]
        noisy n = [(F, (0, 0.5), (n, 0.5))]
        c10 = coupledPf 0.05 (quiet 10) (noisy 10)
        c20 = coupledPf 0.05 (quiet 20) (noisy 20)
    in expect (abs (c20 / c10 - 2) < 0.02)
         ("20 mm should couple twice 10 mm, got " ++ show (c20 / c10)
          ++ " (" ++ show c10 ++ " and " ++ show c20 ++ " pF)")

-- | And it falls with the gap, which is the weaker lever of the two: tripling
-- the gap from 0.5 to 1.5 mm buys about a factor of three, while tripling the
-- parallel run buys exactly three. Both are true; only one of them is
-- something a router can spend freely.
couplingFallsWithGap :: Test
couplingFallsWithGap = test "coupling falls with the gap" $
  let quiet = [(F, (0, 0), (10, 0))]
        -- Same length, three different separations.
      at g = coupledPf 0.05 quiet [(F, (0, g), (10, g))]
  in expectAll
       [ (at 0.5 > at 1.5, "0.5 mm should couple more than 1.5 mm")
       , (at 1.5 > at 2.5, "1.5 mm should couple more than 2.5 mm")
       , (at 0.5 / at 1.5 < 10
         , "the gap is a weak lever: 0.5 against 1.5 mm should be well under"
           ++ " ten times, got " ++ show (at 0.5 / at 1.5)) ]

-- | Copper heading across the quiet net rather than along it is charged
-- nothing, because the solved density describes parallel conductors. Two nets
-- cannot cross on the same layer without shorting, so this is really about
-- the arms of an approach.
crossingCopperIsNotCharged :: Test
crossingCopperIsNotCharged = test "copper running across is not charged" $
  let quiet = [(F, (0, 0), (10, 0))]
      across = [(F, (5, 0.5), (5, 6))]
      alongside = [(F, (0, 0.5), (10, 0.5))]
      cross = coupledPf 0.05 quiet across
      par = coupledPf 0.05 quiet alongside
  in expectAll
       [ (cross < 1e-9, "perpendicular copper should couple nothing, got " ++ show cross)
       , (par > 0.1, "the parallel case should still couple, got " ++ show par) ]

-- | A brief approach and a sustained parallel run reach the same minimum gap
-- and couple very differently, which is the distinction the objective needs
-- the model to make. The factor is measured, not assumed: the model
-- over-estimates the approach (it charges the wide part of it as though the
-- other net ran parallel there), so this asserts a lower bound on the ratio
-- rather than a value.
approachCouplesLessThanRunning :: Test
approachCouplesLessThanRunning =
  test "a brief approach couples several times less than running alongside" $
    let quiet = [(F, (0, 0), (10, 0))]
        alongside = [(F, (0, 0.5), (10, 0.5))]
        -- A V: down to 0.5 mm at the middle, away again at about 42 degrees.
        approach = [(F, (0, 5), (5, 0.5)), (F, (5, 0.5), (10, 5))]
        par = coupledPf 0.05 quiet alongside
        app = coupledPf 0.05 quiet approach
    in expectAll
         [ (app > 0, "an approach should couple something, got " ++ show app)
         , (app * 3 < par
           , "an approach should couple at least three times less than a 10 mm"
             ++ " parallel run: approach " ++ show app ++ ", parallel " ++ show par) ]

-- | Two nets meant to match, routed to different lengths, must be reported
-- with both lengths so the reader can see which one moved.
findsAMismatchedPair :: Test
findsAMismatchedPair = test "a matched group over tolerance is reported" $
  let an = noAnalog { anMatched = [("pair", ["A", "B"], 1.0)] }
      traces = [ RTrace "A" F 0.3 [(0, 0), (10, 0)]
               , RTrace "B" F 0.3 [(0, 5), (30, 5)] ]
      found = analogFindings an traces []
  in case found of
       [Mismatched g lens tol] -> expectAll
         [ (g == "pair", "the group should be named")
         , (tol == 1.0, "the tolerance should be carried")
         , (lookup "A" lens == Just 10 && lookup "B" lens == Just 30
           , "both lengths should be reported, got " ++ show lens) ]
       _ -> ["expected exactly one mismatch finding, got " ++ show found]

-- | A length budget counts vias as barrels, so a net can be over budget on
-- layer changes alone.
findsAnOverLengthNet :: Test
findsAnOverLengthNet = test "a length budget counts vias as copper" $
  let an = noAnalog { anMaxLength = [("A", 12)] }
      traces = [RTrace "A" F 0.3 [(0, 0), (10, 0)]]
      vias = [RVia "A" (5, 0) 0.6 0.3, RVia "A" (7, 0) 0.6 0.3]
      -- 10 mm of trace is inside the budget; two 1.6 mm barrels put it over.
      withoutVias = analogFindings an traces []
      withVias = analogFindings an traces vias
  in expectAll
       [ (null withoutVias, "10 mm against a 12 mm budget should pass, got "
                            ++ show withoutVias)
       , (length withVias == 1, "10 mm plus two vias should fail, got " ++ show withVias)
       , (abs (netLength "A" traces vias - 13.2) < 1e-9
         , "length should be 13.2 mm, got " ++ show (netLength "A" traces vias)) ]

-- | Regression on the real board. The attenuverter declares -80 dB of
-- channel crosstalk (2.2 mV on a 22 V swing) and today's routing achieves
-- zero cross-channel coupling because the channels are physically apart.
--
-- Same-channel pairs are deliberately not asserted on: an output coupling to
-- its own wiper is a little extra feedback, not crosstalk, and it is reported
-- for information only.
attenuverterChannelsStaySeparate :: Test
attenuverterChannelsStaySeparate =
  testIO "the attenuverter's channels do not couple into each other" $ do
    lc <- newLibCache
    prob <- routeProblemFor lc attenuverter
    case routeConfigFor attenuverter of
      Nothing -> pure ["the attenuverter should be autorouted"]
      Just cfg -> do
        let res = autoroute cfg prob
            -- The router names nets its own way; the intent is written in the
            -- design's names, and on this board the router's name is the
            -- design's with a slash in front.
            strip n = maybe n id (T.stripPrefix "/" n)
            traces = [ t { rtNet = strip (rtNet t) } | rn <- rrNets res, t <- rnTraces rn ]
            vias = [ v { rvNet = strip (rvNet v) } | rn <- rrNets res, v <- rnVias rn ]
            an = bdAnalog (modBoard attenuverter)
            preds = couplingPredictions an traces vias
            crossChannel =
              [ (q, z, mv)
              | (q, z, _, mv) <- preds
              , (q, z) `elem` [ ("WIPER1", "OA2"), ("WIPER1", "OUT2")
                              , ("WIPER2", "OA1"), ("WIPER2", "OUT1") ] ]
        pure $ expectAll $
          [ (anInjectMv an > 0, "the board should declare an injection limit")
          , (not (null preds), "the coupling check should predict something at all")
          , (length crossChannel == 4
            , "all four cross-channel pairs should be predicted, got "
              ++ show (map (\(q, z, _) -> (q, z)) crossChannel)) ]
          ++ [ (mv <= anInjectMv an
               , T.unpack z ++ " injects " ++ show mv ++ " mV into " ++ T.unpack q
                 ++ ", limit " ++ show (anInjectMv an)
                 ++ "; the channels may no longer be routed apart")
             | (q, z, mv) <- crossChannel ]
