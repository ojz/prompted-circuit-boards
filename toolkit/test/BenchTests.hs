{-# LANGUAGE OverloadedStrings #-}
-- | Tests for the routing benchmark harness (roadmap rung 0).
--
-- These check the harness, not the router's quality: that it measures the
-- right things, that it survives a router that explodes, and that a board it
-- cannot route is reported rather than hidden.
module BenchTests (tests) where

import           Control.Exception (throwIO, ErrorCall (..))
import           Data.List         (isInfixOf)
import qualified Data.Text         as T

import           Bench
import           BenchFixtures     (pinch, pinchWide, reversal)
import           Harness
import           Kicad.Library     (newLibCache)
import           Mult              (mult)

tests :: [Test]
tests =
  [ scoresARealBoard
  , survivesABrokenRouter
  , reportsAnUnroutableBoard
  , routesAPracticalCorridor
  , congestedFixtureSettles
  , negotiationConvergesAtEveryViaCost
  , reportNamesTheFault
  ]

-- | The measurements have to mean something: a board that routes is legal,
-- has copper, and cannot be shorter than the spanning tree over its pads.
scoresARealBoard :: Test
scoresARealBoard = testIO "benchmark measures the mult correctly" $ do
  lc <- newLibCache
  s <- scoreBoard lc gridRouter ("mult", mult)
  pure $ expectAll
    [ (scRouted s, "should have routed")
    , (scFailedNets s == 0, "unexpected failed nets: " ++ show (scFailedNets s))
    , (scContested s == 0, "unexpected contested cells: " ++ show (scContested s))
    , (scViaPad s == 0, "unexpected vias in pads: " ++ show (scViaPad s))
    , (scDisconnected s == 0, "unexpected disconnected nets: " ++ show (scDisconnected s))
    , (scNets s == 2, "mult routes 2 nets, got " ++ show (scNets s))
    , (scSegments s > 0, "should have segments")
    , (scLength s >= scIdeal s, "copper cannot be shorter than the ideal tree: "
        ++ show (scLength s) ++ " < " ++ show (scIdeal s))
    , (scIdeal s > 0, "the ideal tree should be positive")
    ]

-- | One router blowing up must not take the run down with it: the harness
-- scores it as not-routed and carries the reason.
survivesABrokenRouter :: Test
survivesABrokenRouter = testIO "a router that throws is scored, not propagated" $ do
  lc <- newLibCache
  let broken = Strategy "broken" (\_ _ -> throwIO (ErrorCall "router exploded"))
  s <- scoreBoard lc broken ("mult", mult)
  pure $ expectAll
    [ (not (scRouted s), "should be scored as not routed")
    , ("exploded" `isInfixOf` T.unpack (scNote s)
      , "the note should carry the reason, got: " ++ show (scNote s))
    ]

-- | 'pinch' has one legal path about 0.04 mm wide, which the 0.2 mm grid
-- cannot see. It is expected to fail, and the harness must say so plainly
-- instead of reporting an empty success.
--
-- This encodes today's limitation on purpose. A router that routes it is an
-- improvement, and this test should then be changed to demand success.
reportsAnUnroutableBoard :: Test
reportsAnUnroutableBoard = testIO "the sub-grid corridor is reported as a fault" $ do
  lc <- newLibCache
  s <- scoreBoard lc gridRouter ("pinch", pinch)
  pure $ expectAll
    [ (scRouted s, "the router should return a result, not throw")
    , (scFailedNets s == 1, "expected exactly 1 unrouted net, got " ++ show (scFailedNets s))
    , (scSegments s == 0, "a failed net should lay no copper")
    ]

-- | The other half of the bracket. A 0.25 mm corridor is tight but ordinary,
-- and our router finds it (Freerouting, as of 2.4.1, does not). If this ever
-- regresses, the grid's edge margin or its cell alignment got worse.
routesAPracticalCorridor :: Test
routesAPracticalCorridor = testIO "a 0.25 mm corridor is routed" $ do
  lc <- newLibCache
  s <- scoreBoard lc gridRouter ("pinch-wide", pinchWide)
  pure $ expectAll
    [ (scRouted s, "should have routed")
    , (scFailedNets s == 0, "unrouted nets: " ++ show (scFailedNets s))
    , (scDisconnected s == 0, "net not one island: " ++ show (scBadNets s))
    , (scSegments s > 0, "should have laid copper")
    ]

-- | The congested fixture is what raised the negotiation budget from 40 to
-- 200 rounds. It must stay solvable, or the change regressed.
congestedFixtureSettles :: Test
congestedFixtureSettles = testIO "the 20-net reversal settles with no conflicts" $ do
  lc <- newLibCache
  s <- scoreBoard lc gridRouter ("reversal", reversal)
  pure $ expectAll
    [ (scRouted s, "should have routed")
    , (scFailedNets s == 0, "unrouted nets: " ++ show (scFailedNets s))
    , (scContested s == 0, "contested cells left: " ++ show (scContested s)
        ++ " (the negotiation budget may be too low again)")
    , (scViaPad s == 0, "vias in pads: " ++ show (scViaPad s))
    , (scDisconnected s == 0, "nets in pieces: " ++ show (scDisconnected s))
    , (scNets s == 20, "expected 20 nets, got " ++ show (scNets s))
    ]

-- | Negotiated congestion has to converge whatever a via costs.
--
-- The via cost changes which solution the router lands on, and that is its
-- job; it must not change whether the router lands on one at all. It used to:
-- present congestion grew as 1.4^round while history congestion accumulated a
-- flat 1 per round, so by round 200 history was 27 orders of magnitude below
-- the present term, the negotiation had no memory, and two nets would trade
-- places forever. 'reversal' then stalled with contested cells at via costs
-- 15 and 30 while succeeding at 25 and 40, and ten times the budget did not
-- help. History is now charged in the same currency as present congestion.
--
-- These two costs are the ones that stalled. Legality is the assertion; via
-- count and copper length are deliberately not, since those are the trade the
-- cost is supposed to make.
negotiationConvergesAtEveryViaCost :: Test
negotiationConvergesAtEveryViaCost =
  testIO "the congested fixture converges at via costs 15 and 30" $ do
    lc <- newLibCache
    scores <- mapM (\c -> scoreBoard lc (gridRouterVia c) ("reversal", reversal)) [15, 30]
    pure $ expectAll
      [ (scContested s == 0, T.unpack (scStrategy s) ++ " left "
          ++ show (scContested s) ++ " contested cells (history congestion may"
          ++ " have been swamped by present congestion again)")
      | s <- scores ]

-- | A fault has to be visible in the report, not only in the data.
reportNamesTheFault :: Test
reportNamesTheFault = testIO "the report lists a failing board under Faults" $ do
  lc <- newLibCache
  scores <- runBench lc [gridRouter] [("pinch", pinch), ("mult", mult)]
  let rep = T.unpack (benchReport scores)
  pure $ expectAll
    [ ("Faults:" `isInfixOf` rep, "the report should have a Faults section")
    , ("pinch" `isInfixOf` rep, "the failing board should be named")
    , ("nets unrouted" `isInfixOf` rep, "the reason should be given, got:\n" ++ rep)
    ]
