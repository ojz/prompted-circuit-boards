{-# LANGUAGE OverloadedStrings #-}
-- | The routing benchmark: score any router against a fixed set of boards.
--
-- Roadmap rung 0. Nothing else in the research programme is measurable without
-- this, so it comes first and it stays boring.
--
-- Two deliberate choices, agreed 2026-09-10:
--
-- * A router is a 'Strategy', a record of functions rather than a class. One
--   value per router, so they go in a list and the harness loops over them.
--   The route action is in 'IO' because a strategy may shell out to an
--   external tool (Freerouting is the first planned one).
--
-- * A score is a vector, never one weighted number. Copper length, vias,
--   detour, violations and time trade off against each other, and collapsing
--   them into a single figure of merit is an invitation to optimise the
--   weighting instead of the board. The report prints every column and the
--   reader does the trading.
--
-- What the harness deliberately does not do: declare a winner.
module Bench
  ( Strategy (..)
  , gridRouter
  , gridRouterN
  , Score (..)
  , scoreBoard
  , runBench
  , benchReport
  ) where

import           Control.Exception (SomeException, evaluate, try)
import           Data.List         (sortOn)
import           Data.Text         (Text)
import qualified Data.Text         as T
import           Numeric           (showFFloat)
import           System.CPUTime    (getCPUTime)

import           Design
import           Emit.Pcb          (routeConfigFor, routeProblemFor)
import           Kicad.Library     (LibCache)
import           Route.Check
import           Route.Router

-- | A router the benchmark can drive.
data Strategy = Strategy
  { stratName  :: Text
  , stratRoute :: RouteConfig -> RouteProblem -> IO RouteResult
  }

-- | pcbgen's own grid router: A* per net with negotiated congestion.
gridRouter :: Strategy
gridRouter = Strategy "grid-astar" (\cfg prob -> evaluate (autoroute cfg prob))

-- | The same router with a different negotiation budget. The default is 40
-- rounds; a board that leaves contested cells has exhausted them, and this
-- says whether the negotiation was converging slowly or not converging.
gridRouterN :: Int -> Strategy
gridRouterN n =
  Strategy (T.pack ("grid-astar-" ++ show n))
           (\cfg prob -> evaluate (autoroute cfg { rcMaxIterations = n } prob))

-- | One board routed by one strategy. Every field is reported; none is
-- combined with any other.
data Score = Score
  { scBoard        :: Text
  , scStrategy     :: Text
  , scRouted       :: Bool     -- ^ the strategy returned a result at all
  , scFailedNets   :: Int      -- ^ nets it gave up on
  , scContested    :: Int      -- ^ cells two nets still share
  , scViaPad       :: Int      -- ^ vias in or against a pad (checked on geometry)
  , scDisconnected :: Int      -- ^ nets whose copper is not one island
  , scNets         :: Int
  , scSegments     :: Int
  , scVias         :: Int
  , scLength       :: Double   -- ^ mm of copper
  , scIdeal        :: Double   -- ^ mm of the minimum spanning tree over the pads
  , scSeconds      :: Double   -- ^ CPU seconds
  , scNote         :: Text     -- ^ why it produced nothing, when it did not
  } deriving (Show)

-- | A board is only legal when the router finished, nothing is contested, no
-- via touches a pad and every net is one island. Four separate conditions,
-- because a router that fails one of them has not "nearly" succeeded.
scLegal :: Score -> Bool
scLegal s = scRouted s
         && scFailedNets s == 0
         && scContested s == 0
         && scViaPad s == 0
         && scDisconnected s == 0

-- | Route one board with one strategy and measure it. A strategy that throws
-- scores as not-routed with the exception as its note, so one broken router
-- cannot abort the run.
scoreBoard :: LibCache -> Strategy -> (String, Module) -> IO Score
scoreBoard lc strat (label, m) = do
  let blank = Score
        { scBoard = T.pack label, scStrategy = stratName strat
        , scRouted = False, scFailedNets = 0, scContested = 0
        , scViaPad = 0, scDisconnected = 0, scNets = 0
        , scSegments = 0, scVias = 0, scLength = 0, scIdeal = 0
        , scSeconds = 0, scNote = "" }
  case routeConfigFor m of
    Nothing -> pure blank { scNote = "no autoroute block" }
    Just cfg -> do
      prob <- routeProblemFor lc m
      t0 <- getCPUTime
      outcome <- try (stratRoute strat cfg prob >>= \r -> evaluate (rrIterations r) >> pure r)
      t1 <- getCPUTime
      let secs = fromIntegral (t1 - t0) / 1e12 :: Double
      case outcome :: Either SomeException RouteResult of
        Left e -> pure blank { scSeconds = secs, scNote = T.pack (takeWhile (/= '\n') (show e)) }
        Right res -> do
          let vias = [ v | rn <- rrNets res, v <- rnVias rn ]
              traces = [ t | rn <- rrNets res, t <- rnTraces rn ]
              preTraces = [ RTrace n l w path | (n, l, w, path) <- rpPreRouted prob ]
              vios = viaPadViolations (rcClearance cfg) (rpPads prob) vias
              disc = [ rnNet rn | rn <- rrNets res
                     , not (isConnected (netCopper (rnNet rn) (rpPads prob)
                                                   (preTraces ++ rnTraces rn) (rnVias rn))) ]
          pure blank
            { scRouted = True
            , scFailedNets = length (rrFailed res)
            , scContested = rrConflicts res
            , scViaPad = length vios
            , scDisconnected = length disc
            , scNets = length (rrNets res)
            , scSegments = sum [ length (rtPath t) - 1 | t <- traces ]
            , scVias = length vias
            , scLength = sum [ dist a b | t <- traces, (a, b) <- zip (rtPath t) (drop 1 (rtPath t)) ]
            , scIdeal = sum (map rnIdeal (rrNets res))
            , scSeconds = secs
            }
  where
    dist (x1, y1) (x2, y2) = sqrt ((x2 - x1) ^ (2 :: Int) + (y2 - y1) ^ (2 :: Int))

-- | Every strategy against every board.
runBench :: LibCache -> [Strategy] -> [(String, Module)] -> IO [Score]
runBench lc strats boards =
  sequence [ scoreBoard lc s b | b <- boards, s <- strats ]

-- Report -----------------------------------------------------------------------

f2 :: Double -> Text
f2 x = T.pack (showFFloat (Just 2) x "")

-- | Markdown, one row per board and strategy. Committed next to the code so a
-- change in routing quality shows up in a diff.
benchReport :: [Score] -> Text
benchReport scores = T.unlines $
  [ "| Board | Router | Legal | Nets | Segments | Vias | Copper mm | Ideal mm | Detour | CPU s |"
  , "|---|---|:-:|--:|--:|--:|--:|--:|--:|--:|" ]
  ++ map row (sortOn scBoard scores)
  ++ [ "" ]
  ++ faults
  ++ [ ""
     , T.pack ("Boards: " ++ show (length scores) ++ ". Legal: "
               ++ show (length (filter scLegal scores)) ++ ".")
     , ""
     , "Detour is copper length over the minimum spanning tree of the pad centres:"
     , "the shortest any routing of those nets could be. 1.00 is not reachable on a"
     , "real board. Legal means the router finished, nothing is contested, no via"
     , "touches a pad and every net is a single copper island."
     ]
  where
    row s = T.concat
      [ "| ", scBoard s, " | ", scStrategy s, " | ", if scLegal s then "yes" else "**no**"
      , " | ", T.pack (show (scNets s)), " | ", T.pack (show (scSegments s))
      , " | ", T.pack (show (scVias s)), " | ", f2 (scLength s), " | ", f2 (scIdeal s)
      , " | ", if scIdeal s > 0 then f2 (scLength s / scIdeal s) else "-"
      , " | ", f2 (scSeconds s), " |" ]

    faults =
      let bad = [ s | s <- sortOn scBoard scores, not (scLegal s) ]
      in if null bad then [ "No faults." ] else
           "Faults:" : concatMap describe bad

    describe s =
      [ "- " <> scBoard s <> " / " <> scStrategy s <> ": " <> T.intercalate ", " reasons ]
      where
        reasons = concat
          [ [ "did not run (" <> scNote s <> ")" | not (scRouted s) ]
          , [ T.pack (show (scFailedNets s)) <> " nets unrouted" | scFailedNets s > 0 ]
          , [ T.pack (show (scContested s)) <> " contested cells" | scContested s > 0 ]
          , [ T.pack (show (scViaPad s)) <> " vias in pads" | scViaPad s > 0 ]
          , [ T.pack (show (scDisconnected s)) <> " nets in pieces" | scDisconnected s > 0 ]
          ]
