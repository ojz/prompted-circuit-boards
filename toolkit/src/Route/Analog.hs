{-# LANGUAGE OverloadedStrings #-}
-- | Measuring a routed board against its declared electrical intent.
--
-- The router's own score is copper length and via count, which is what every
-- autorouter has optimised since the 1960s and which nobody is billed for:
-- JLCPCB charges by board area, not by the millimetre. What an analog module
-- actually cares about is different, and the difference is not a matter of
-- opinion -- @toolkit\/nodebudget.py@ derives it from a field solve of the
-- stackup plus ngspice, and the answer for boards this size is blunt:
--
--   * Trace capacitance rolling off a high-impedance node does not bind. A
--     100k node may carry 1.7 metres of copper before it loses 3 dB at
--     20 kHz, and the longest trace that fits on a 4HP board is about 110 mm.
--     A length budget is therefore documentation, not an objective.
--
--   * Coupling from a switching net binds enormously. A 5 V gate edge
--     running 20 mm alongside a 1M node injects hundreds of millivolts, and
--     widening the gap from 0.2 mm to 2 mm barely helps. What controls it is
--     how far the two run alongside each other, which is exactly what a
--     router chooses.
--
-- So the design declares an electrical limit in millivolts and this module
-- predicts the injection from the copper, rather than the design declaring a
-- spacing in millimetres that nobody can justify.
module Route.Analog
  ( AnalogFinding (..)
  , analogFindings
  , describeAnalog
  , netLength
  , roleOf
  , sameCircuit
  , couplingPredictions
  ) where

import           Data.List   (sortOn)
import           Data.Maybe  (fromMaybe)
import           Data.Text   (Text)
import qualified Data.Text   as T
import           Numeric     (showFFloat)

import           Design         (Analog (..), NetRole (..))
import           Route.Coupling
import           Route.Geometry

-- | One way a board misses its declared intent.
--
-- Findings, not violations: these are design intent rather than
-- manufacturability, so a board carrying them is still fabricable and still
-- passes DRC. They belong in the report and in the router's objective; they
-- are not grounds for refusing to emit a project.
data AnalogFinding
  = OverLength Text Double Double
    -- ^ net, copper mm, budget mm
  | Injected Text Text Double Double Double
    -- ^ quiet net, noisy net, coupled pF, predicted mV, limit mV
  | Mismatched Text [(Text, Double)] Double
    -- ^ group, each net's copper mm, tolerance mm
  deriving (Eq, Show)

-- Geometry -------------------------------------------------------------------

-- | Copper length of one net, millimetres, vias counted as barrels.
--
-- A via is 1.6 mm of copper through the board and it sits on the signal path,
-- so a length budget that ignored it would be wrong by one board thickness
-- per layer change.
netLength :: Text -> [RTrace] -> [RVia] -> Double
netLength net traces vias =
  sum [ dist a b
      | t <- traces, rtNet t == net
      , (a, b) <- zip (rtPath t) (drop 1 (rtPath t)) ]
  + 1.6 * fromIntegral (length [ () | v <- vias, rvNet v == net ])

-- | Whether two nets are declared parts of one signal path, in which case
-- coupling between them is the circuit working rather than crosstalk.
sameCircuit :: Analog -> Text -> Text -> Bool
sameCircuit an a b = any (\g -> a `elem` g && b `elem` g) (anSameCircuit an)

-- | A net's declared role; anything undeclared is 'Ordinary'.
roleOf :: Analog -> Text -> NetRole
roleOf an n = fromMaybe Ordinary (lookup n (anRoles an))

-- Findings -------------------------------------------------------------------

-- | Every way the copper misses the design's declared intent, worst first
-- within each kind.
analogFindings :: Analog -> [RTrace] -> [RVia] -> [AnalogFinding]
analogFindings an traces vias = overLength ++ injectedFindings ++ mismatched
  where
    len n = netLength n traces vias

    overLength =
      map snd (sortOn fst
        [ (b - l, OverLength n l b)
        | (n, b) <- anMaxLength an, b > 0
        , let l = len n, l > b ])

    injectedFindings =
      [ Injected q z cm mv (anInjectMv an)
      | anInjectMv an > 0
      , (q, z, cm, mv) <- couplingPredictions an traces vias
      , mv > anInjectMv an ]

    mismatched =
      [ Mismatched name lens tol
      | (name, nets, tol) <- anMatched an, tol >= 0, length nets > 1
      , let lens = [ (n, len n) | n <- nets ]
            ls = map snd lens
      , maximum ls - minimum ls > tol ]


-- | Predicted injection for every quiet/noisy pair on the board, worst
-- first: @(quiet net, noisy net, coupled pF, predicted mV)@.
--
-- Reported whether or not it exceeds the limit. A check that only speaks up
-- when it fails cannot be told apart from a check that is not running, and
-- the margin is the interesting number: it says how much routing freedom the
-- next revision has before the spec is at risk.
couplingPredictions :: Analog -> [RTrace] -> [RVia] -> [(Text, Text, Double, Double)]
couplingPredictions an traces vias =
  sortOn (\(_, _, _, mv) -> negate mv)
    [ (q, z, cm, mv)
    | (q, r) <- [ (n, rr) | (n, Quiet rr) <- anRoles an ]
    , (z, v, tr) <- [ (n, vv, t) | (n, Noisy vv t) <- anRoles an ]
    , not (sameCircuit an q z)
    , let cm = coupledPf 0.1 (segmentsOf q) (segmentsOf z)
          ct = anNodePf an + netLength q traces vias * selfPfPerMm
          mv = 1000 * injectedVolts v tr r (cm * 1e-12) (ct * 1e-12)
    ]
  where
    segmentsOf n =
      [ (rtLayer t, a, b)
      | t <- traces, rtNet t == n, (a, b) <- zip (rtPath t) (drop 1 (rtPath t)) ]

describeAnalog :: AnalogFinding -> Text
describeAnalog f = case f of
  OverLength n l b ->
    "net " <> n <> " is " <> mm l <> " of copper, budget " <> mm b
    <> " (over by " <> mm (l - b) <> ")"
  Injected q z cm mv limit ->
    "noisy net " <> z <> " couples " <> pf cm <> " into quiet net " <> q
    <> ", predicting " <> mv2 mv <> " on it; limit " <> mv2 limit
  Mismatched name lens tol ->
    "matched group " <> name <> " spans " <> mm (maximum ls - minimum ls)
    <> " (tolerance " <> mm tol <> "): "
    <> T.intercalate ", " [ n <> " " <> mm l | (n, l) <- lens ]
    where ls = map snd lens

mm :: Double -> Text
mm x = T.pack (showFFloat (Just 2) x " mm")

pf :: Double -> Text
pf x = T.pack (showFFloat (Just 4) x " pF")

mv2 :: Double -> Text
mv2 x = T.pack (showFFloat (Just 2) x " mV")
