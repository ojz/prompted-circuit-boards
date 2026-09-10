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
import           BenchFixtures     (pinch, reversal)
import           Harness
import           Kicad.Library     (newLibCache)
import           Mult              (mult)

tests :: [Test]
tests =
  [ scoresARealBoard
  , survivesABrokenRouter
  , reportsAnUnroutableBoard
  , congestedFixtureSettles
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
