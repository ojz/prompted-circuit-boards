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
  , selfPfPerMm
  , mutualPfPerMm
  , coupledPf
  , injectedVolts
  , couplingPredictions
  ) where

import           Data.List   (sortOn)
import           Data.Maybe  (fromMaybe)
import           Data.Text   (Text)
import qualified Data.Text   as T
import           Numeric     (showFFloat)

import           Design      (Analog (..), NetRole (..))
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

-- Capacitance of the stackup -------------------------------------------------

-- | Capacitance to the ground plane of a 0.3 mm trace on 1.6 mm FR4,
-- picofarads per millimetre.
--
-- From @toolkit\/xsection.py@, which solves the cross-section rather than
-- quoting a formula, and which agrees with the Hammerstad closed form once
-- its grid error is extrapolated away. The residual disagreement is a few
-- percent and changes nothing here: every budget this feeds comes out orders
-- of magnitude clear of the geometry we build.
selfPfPerMm :: Double
selfPfPerMm = 0.0457

-- | Mutual capacitance between two 0.3 mm traces on the same layer,
-- picofarads per millimetre of parallel run, against their gap in mm.
--
-- The table is solved (@xsection.py sweep@); values between entries are
-- interpolated on log-log axes, where the solved points are close to a
-- straight line. Outside the table the nearest end is held, so a very tight
-- or very wide gap is treated as the closest solved case rather than
-- extrapolated into fiction.
mutualPfPerMm :: Double -> Double
mutualPfPerMm gap
  | gap <= fst (head table) = snd (head table)
  | gap >= fst (last table) = snd (last table)
  | otherwise = go table
  where
    go ((g0, c0) : rest@((g1, c1) : _))
      | gap <= g1 =
          let t = log (gap / g0) / log (g1 / g0)
          in exp (log c0 + t * (log c1 - log c0))
      | otherwise = go rest
    go _ = snd (last table)
    table = solvedMutual

-- | The solved gap-to-coupling table: gap in mm, mutual capacitance in
-- picofarads per millimetre of parallel run. Replace it by re-running
--
-- > xsection.py sweep --width 0.3 --gaps 0.2,0.3,0.5,1.0,2.0 --pitch 0.025
--
-- and pasting the column, not by editing the numbers.
--
-- Worth looking at the first row: at the minimum spacing our rules allow,
-- two traces are coupled to each other about as strongly as either is to the
-- ground plane underneath (0.0316 against 0.0310 pF/mm from the same solve).
-- Adjacent copper at 0.2 mm is a half-and-half divider, which is why a gap is
-- such a weak lever and why the check below is about how far two nets run
-- together rather than how far apart they are.
solvedMutual :: [(Double, Double)]
solvedMutual =
  [ (0.2, 0.03156)
  , (0.3, 0.02509)
  , (0.5, 0.01799)
  , (1.0, 0.00996)
  , (2.0, 0.00395)
  ]

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

-- | A net's declared role; anything undeclared is 'Ordinary'.
roleOf :: Analog -> Text -> NetRole
roleOf an n = fromMaybe Ordinary (lookup n (anRoles an))

-- | Mutual capacitance between two nets' copper, picofarads.
--
-- A line integral of the coupling density along one net: walk its copper in
-- small steps, and at each step charge the per-millimetre coupling for the
-- distance to the nearest same-layer copper of the other net. That handles a
-- long parallel run and a single perpendicular crossing with the same
-- arithmetic and no case analysis about angles -- a crossing simply has two
-- or three close samples where a parallel run has a hundred.
--
-- Same layer only. On a two-layer 1.6 mm board, copper on the far side is
-- separated by more substrate than any in-plane gap on a board this size, and
-- treating a crossing on the other layer as coupling would make the check
-- unsatisfiable. Two nets cannot cross on the same layer anyway without being
-- shorted, so the only same-layer configurations are running alongside and
-- approaching, which is what this has to get right.
--
-- Where it is exact and where it is not. A sustained parallel run reduces to
-- length times the solved density, which is the case that dominates and the
-- case the solve describes. A short or skewed neighbour is over-estimated,
-- because every sample is charged as though the other net ran parallel
-- through that point for far longer than it does: a 2 mm neighbour comes out
-- about twice the coupling it should have. That is the safe direction for a
-- budget, and correcting it needs the neighbour's extent, not just its
-- distance. So this ranks routings and catches gross violations; it does not
-- predict crosstalk to a decibel.
coupledPf :: Double -> [(Layer, Pt, Pt)] -> [(Layer, Pt, Pt)] -> Double
coupledPf step quiet noisy =
  sum [ dl * mutualPfPerMm d * align u v
      | (l, a, b) <- quiet
      , let u = direction a b
      , (p, dl) <- samples a b
      , Just (d, v) <- [nearest l p]
      , d < cutoff ]
  where
    -- Beyond this the coupling density has fallen to an eighth of its peak
    -- and the remaining contribution is small against anything closer. It is
    -- not smaller because a long parallel run at 2 mm is a real 0.06 pF and
    -- must not be discarded.
    cutoff = 3.0
    -- Each sample carries the length it actually represents, not the nominal
    -- step. Routed paths are full of segments shorter than one step, and
    -- charging each of those a whole step would inflate the coupling.
    samples a b =
      let len = dist a b
          n = max 1 (ceiling (len / step)) :: Int
          dl = len / fromIntegral n
      in [ ( ( fst a + (fst b - fst a) * t, snd a + (snd b - snd a) * t ), dl )
         | i <- [0 .. n - 1], let t = (fromIntegral i + 0.5) / fromIntegral n ]
    -- Nearest same-layer copper of the other net, and which way it runs.
    nearest l p = case [ (segPointDist c d p, direction c d) | (m, c, d) <- noisy, m == l ] of
      [] -> Nothing
      xs -> Just (foldr1 (\x y -> if fst x <= fst y then x else y) xs)
    direction a b =
      let d = dist a b
      in if d <= 0 then (0, 0) else ((fst b - fst a) / d, (snd b - snd a) / d)
    -- The solved density is the coupling between two *parallel* conductors,
    -- so it is charged in proportion to how parallel the two actually are
    -- here. Alongside is charged in full, skew is discounted, and copper
    -- heading straight across is charged nothing.
    align (ux, uy) (vx, vy) = abs (ux * vx + uy * vy)

-- | Peak volts a switching edge puts on a high-impedance node through a
-- mutual capacitance.
--
-- A ramp into a high-pass. With @tau = r * (cm + ct)@,
--
-- > vpk = (v / tr) * r * cm * (1 - exp (-tr / tau))
--
-- which becomes the capacitive divider @v * cm \/ (cm + ct)@ when the edge is
-- fast against tau and @v * r * cm \/ tr@ when it is slow. One expression
-- covers both, which is why a board can be checked with arithmetic instead of
-- a simulator run: @nodebudget.py verify@ is what earns that, agreeing with
-- ngspice to 0.2% in both limits and at the crossover between them.
--
-- Capacitances in farads, resistance in ohms, times in seconds.
injectedVolts :: Double -> Double -> Double -> Double -> Double -> Double
injectedVolts v tr r cm ct
  | tr <= 0 || r <= 0 || cm <= 0 = 0
  | otherwise = (v / tr) * r * cm * (1 - exp (negate tr / tau))
  where tau = r * (cm + ct)

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
