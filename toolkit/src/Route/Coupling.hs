{-# LANGUAGE OverloadedStrings #-}
-- | The physics of copper next to copper: how much capacitance a trace has,
-- how much it shares with a neighbour, and what a switching edge on that
-- neighbour therefore does to it.
--
-- Separate from "Route.Analog" so that the router can use it. Analog intent
-- is a design-level idea and belongs above the router; the capacitance of two
-- pieces of copper is not, and the router needs it to route against.
-- Everything here depends only on geometry.
--
-- The numbers come from a field solve of the stackup we order
-- (@toolkit\/xsection.py@) and the injection formula is checked against
-- ngspice in both its limits (@toolkit\/nodebudget.py verify@). Neither is a
-- rule of thumb and neither should be replaced by one.
module Route.Coupling
  ( selfPfPerMm
  , mutualPfPerMm
  , solvedMutual
  , coupledPf
  , injectedVolts
  ) where

import           Route.Geometry

-- Capacitance of the stackup -------------------------------------------------

-- | Capacitance to the ground plane of a 0.3 mm trace on 1.6 mm FR4,
-- picofarads per millimetre.
--
-- From @toolkit\/xsection.py@, which solves the cross-section rather than
-- quoting a formula. It reads about 6% above the Hammerstad closed form at
-- the grid used, and the difference falls as the grid is refined
-- (@xsection.py converge@: 16% at 0.1 mm cells, 10% at 0.05, 6% at 0.025),
-- so it is discretisation. Extrapolating the sequence to zero cell size still
-- leaves about 3%, which is not accounted for and is not worth accounting
-- for: every budget this feeds comes out orders of magnitude clear of the
-- geometry we build.
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
  , (3.0, 0.00186)
  , (5.0, 0.00045)
  , (8.0, 0.00008)
  ]

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
    -- Beyond this the density is under a twentieth of its peak and a 30 mm
    -- parallel run contributes about 0.03 pF, which no budget here turns on.
    -- It is not tighter because a long run at 2 to 3 mm is real copper: the
    -- table used to stop at 2 mm and hold its last value, which overstated
    -- 3 mm by a factor of two and, worse, left the density flat from 2 mm to
    -- the cutoff, so a router trying to move away found no gradient to
    -- follow until it fell off a cliff.
    cutoff = 4.0
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

