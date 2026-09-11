{-# LANGUAGE OverloadedStrings #-}
-- | The routing benchmark: score any router against a fixed set of boards.
--
-- Roadmap rung 0. Nothing else in the research programme is measurable without
-- this, so it comes first and it stays boring.
--
-- Three deliberate choices:
--
-- * A 'Strategy' takes a design and returns copper. That is the widest useful
--   interface: our own router works from the in-memory routing problem, while
--   an external tool needs a board file on disk and a subprocess, and both fit
--   behind it.
--
-- * The harness verifies the copper itself. Whatever a strategy hands back is
--   put through the same geometry checks as our own router's output: vias
--   against every pad, and one copper island per net. An external tool's
--   claim to have routed a board is not evidence that it did.
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
  , Routed (..)
  , noRouting
  , gridRouter
  , gridRouterN
  , gridRouterVia
  , gridRouterWith
  , freeroutingRouter
  , findKicadPython
  , Score (..)
  , scLegal
  , scoreBoard
  , runBench
  , benchReport
  ) where

import           Control.Exception (SomeException, evaluate, try)
import           Data.List         (sortOn)
import           Data.Maybe        (fromMaybe)
import           Data.Text         (Text)
import qualified Data.Text         as T
import qualified Data.Text.IO      as TIO
import           Numeric           (showFFloat)
import           System.CPUTime    (getCPUTime)
import           System.Directory  (createDirectoryIfMissing, doesFileExist, removeDirectoryRecursive)
import           System.Environment (lookupEnv)
import           System.Exit       (ExitCode (..))
import           System.FilePath   ((</>))
import           System.Process    (readProcessWithExitCode)

import           Design
import           Route.Analog      (couplingPredictions)
import           Emit.Pcb          (emitPcb, routeConfigFor, routeProblemFor)
import           Emit.Project      (emitProject)
import           Emit.Schematic    (SchInfo (..), emitSchematic)
import           Kicad.Library     (LibCache)
import           Kicad.SExpr       (parseSExprs)
import           Route.Check
import           Route.Extract     (copperOfBoard)
import           Route.Geometry
import           Route.Router

-- | What a router produced. 'cuFailed' and 'cuContested' are a router's own
-- report of giving up; the harness checks the copper regardless.
data Routed = Routed
  { cuTraces    :: [RTrace]
  , cuVias      :: [RVia]
  , cuFailed    :: [Text]   -- ^ nets the router says it could not route
  , cuContested :: Int      -- ^ overlaps the router says it left behind
  , cuNote      :: Text
  }

noRouting :: Text -> Routed
noRouting = Routed [] [] [] 0

-- | A router the benchmark can drive: a design in, copper out.
data Strategy = Strategy
  { stratName :: Text
  , stratRun  :: LibCache -> Module -> IO Routed
  }

-- Strategies -------------------------------------------------------------------

-- | pcbgen's own grid router: A* per net with negotiated congestion.
gridRouter :: Strategy
gridRouter = gridRouterWith "grid-astar" id

-- | The same router with one setting changed. Every knob in 'RouteConfig' is
-- a number somebody guessed once; the way to settle one is to put several
-- values in the same report and read the columns.
gridRouterWith :: Text -> (RouteConfig -> RouteConfig) -> Strategy
gridRouterWith name tweak = Strategy name (runGrid tweak)

-- | A different negotiation budget. The default is 200 rounds; a board that
-- leaves contested cells has exhausted them, and this says whether the
-- negotiation was converging slowly or not converging.
gridRouterN :: Int -> Strategy
gridRouterN n = gridRouterWith (T.pack ("grid-astar-" ++ show n))
                               (\cfg -> cfg { rcMaxIterations = n })

-- | A different price for a layer change, in cells (the default is 40, about
-- 8 mm of trace). Freerouting spends a quarter of our vias on the same board,
-- which is the evidence that this number wants measuring rather than guessing.
gridRouterVia :: Double -> Strategy
gridRouterVia c = gridRouterWith (T.pack ("grid-via-" ++ show (round c :: Int)))
                                 (\cfg -> cfg { rcViaCost = c })

runGrid :: (RouteConfig -> RouteConfig) -> LibCache -> Module -> IO Routed
runGrid tweak lc m = case routeConfigFor m of
  Nothing -> pure (noRouting "no autoroute block")
  Just cfg0 -> do
    let cfg = tweak cfg0
    prob <- routeProblemFor lc m
    res <- evaluate (autoroute cfg prob)
    _ <- evaluate (rrIterations res)
    pure Routed
      { cuTraces = [ t | rn <- rrNets res, t <- rnTraces rn ]
      , cuVias = [ v | rn <- rrNets res, v <- rnVias rn ]
      , cuFailed = rrFailed res
      , cuContested = rrConflicts res
      , cuNote = ""
      }

-- | Freerouting, the mature open-source topological router, as a parity
-- baseline. It cannot run from our in-memory model, so this writes the design
-- out as an unrouted KiCad board and hands it to @toolkit\/freeroute.py@,
-- which does the Specctra round trip through KiCad's own exporter and
-- importer. The copper comes back off the routed board file.
--
-- Nothing in @modules\/@ is ever produced this way: it exists to answer "how
-- good is our router" and its output is thrown away.
freeroutingRouter :: Strategy
freeroutingRouter = Strategy "freerouting" run
  where
    run lc m = do
      mpy <- findKicadPython
      case mpy of
        Nothing -> pure (noRouting "KiCad's python not found; set KICAD_PYTHON")
        Just kicadPython -> go kicadPython lc m

    go kicadPython lc m = do
      let work = "modules/_bench/.work" </> T.unpack (modName m)
          unrouted = work </> "unrouted.kicad_pcb"
          routed = work </> "routed.kicad_pcb"
          -- Same design with the autorouter switched off, so the board we
          -- hand over has pads, outline and pours but no copper.
          bare = m { modBoard = (modBoard m) { bdAutoRoute = Nothing } }
      createDirectoryIfMissing True work
      (sch, info) <- emitSchematic lc bare
      (pcb, _) <- emitPcb lc bare info
      TIO.writeFile unrouted pcb
      -- The project file carries the net class, which is where an external
      -- router reads its track width from, and the schematic is what KiCad's
      -- exporter uses to name nets.
      TIO.writeFile (work </> T.unpack (modName m) ++ ".kicad_sch") sch
      TIO.writeFile (work </> T.unpack (modName m) ++ ".kicad_pro")
                    (emitProject bare (siSheetUuid info))
      (code, out, err) <- readProcessWithExitCode kicadPython
                            ["toolkit/freeroute.py", unrouted, routed] ""
      ok <- doesFileExist routed
      if code /= ExitSuccess || not ok
        then pure (noRouting (diagnosis (T.pack err) (T.pack out)))
        else do
          txt <- TIO.readFile routed
          case parseSExprs txt of
            Right (board : _) -> do
              let (ts, vs) = copperOfBoard board
              pure (Routed ts vs [] 0 "")
            _ -> pure (noRouting "could not parse the routed board")

    -- freeroute.py states its own reason on stderr as "freeroute.py: ...";
    -- everything else is Freerouting's own chatter, so prefer that line and
    -- fall back to whatever the last non-empty line was.
    diagnosis err out =
      let lns = [ T.strip l | l <- T.lines err ++ T.lines out, not (T.null (T.strip l)) ]
          own = [ l | l <- lns, "freeroute.py: " `T.isPrefixOf` l
                            , not ("freeroute.py: C:" `T.isPrefixOf` l) ]
      in case (own, reverse lns) of
           (o : _, _)  -> T.drop 14 o
           ([], l : _) -> l
           _           -> "freerouting failed with no output"

-- | KiCad's bundled interpreter, the only one carrying pcbnew. The install
-- location differs per workstation, so honour KICAD_PYTHON first and then try
-- the per-user and machine-wide defaults.
findKicadPython :: IO (Maybe FilePath)
findKicadPython = do
  override <- lookupEnv "KICAD_PYTHON"
  local <- lookupEnv "LOCALAPPDATA"
  let candidates = maybe [] pure override
        ++ [ l ++ "/Programs/KiCad/10.0/bin/python.exe" | Just l <- [local] ]
        ++ [ "C:/Program Files/KiCad/10.0/bin/python.exe" ]
  firstExisting candidates
  where
    firstExisting [] = pure Nothing
    firstExisting (c : cs) = do
      ok <- doesFileExist c
      if ok then pure (Just c) else firstExisting cs

-- Scoring ----------------------------------------------------------------------

-- | One board routed by one strategy. Every field is reported; none is
-- combined with any other.
data Score = Score
  { scBoard        :: Text
  , scStrategy     :: Text
  , scRouted       :: Bool     -- ^ the strategy produced copper at all
  , scFailedNets   :: Int      -- ^ nets it reported giving up on
  , scContested    :: Int      -- ^ overlaps it reported leaving
  , scViaPad       :: Int      -- ^ vias in or against a pad (our check, not its word)
  , scDisconnected :: Int      -- ^ nets whose copper is not one island (our check)
  , scBadNets      :: [Text]   -- ^ which ones, so a fault names itself
  , scNets         :: Int      -- ^ nets the design asked to be routed
  , scSegments     :: Int
  , scVias         :: Int
  , scLength       :: Double   -- ^ mm of copper
  , scIdeal        :: Double   -- ^ mm of the minimum spanning trees over the pads
  , scSeconds      :: Double   -- ^ CPU seconds of this process (a subprocess shows ~0)
  , scInjectMv     :: Double   -- ^ worst predicted crosstalk on a quiet net, mV (our check)
  , scInjectLimit  :: Double   -- ^ what the design allows, mV; 0 when it states nothing
  , scNote         :: Text
  } deriving (Show)

-- | A board is only legal when every net asked for is present, nothing is
-- contested, no via touches a pad and every net is one island. Separate
-- conditions, because a router that fails one has not "nearly" succeeded.
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
        , scViaPad = 0, scDisconnected = 0, scBadNets = [], scNets = 0
        , scSegments = 0, scVias = 0, scLength = 0, scIdeal = 0
        , scSeconds = 0, scInjectMv = 0, scInjectLimit = anInjectMv an, scNote = "" }
      an = bdAnalog (modBoard m)
  case routeConfigFor m of
    Nothing -> pure blank { scNote = "no autoroute block" }
    Just cfg -> do
      -- The problem is built here, not by the strategy, so the pads and the
      -- ideal length are the same for every router.
      prob <- routeProblemFor lc m
      let wanted = rcNets cfg
          padsOf n = [ pgAt p | p <- rpPads prob, pgNet p == Just n ]
          ideal = sum [ mstLength (padsOf n) | n <- wanted ]
      t0 <- getCPUTime
      outcome <- try (stratRun strat lc m)
      t1 <- getCPUTime
      let secs = fromIntegral (t1 - t0) / 1e12 :: Double
      case outcome :: Either SomeException Routed of
        Left e -> pure blank { scSeconds = secs, scIdeal = ideal
                             , scNote = firstLine (T.pack (show e)) }
        -- A strategy that returned at all is scored on its copper, even when
        -- there is none: "ran and gave up on one net" and "never ran" are
        -- different facts, and flattening them hides which happened.
        Right cu -> do
          let preTraces = [ RTrace n l w path | (n, l, w, path) <- rpPreRouted prob ]
              allTraces = preTraces ++ cuTraces cu
              vios = viaPadViolations (rcClearance cfg) (rpPads prob) (cuVias cu)
              -- Our own connectivity check on whatever copper came back. A net
              -- the router never mentioned counts as disconnected if its pads
              -- are not joined.
              disc = [ n | n <- wanted
                     , not (isConnected (netCopper n (rpPads prob) allTraces (cuVias cu))) ]
          pure blank
            { scRouted = True
            , scFailedNets = length (cuFailed cu)
            , scContested = cuContested cu
            , scViaPad = length vios
            , scDisconnected = length disc
            , scBadNets = cuFailed cu ++ disc
            , scNets = length wanted
            , scSegments = sum [ length (rtPath t) - 1 | t <- cuTraces cu ]
            , scVias = length (cuVias cu)
            , scLength = sum [ dist a b | t <- cuTraces cu, (a, b) <- zip (rtPath t) (drop 1 (rtPath t)) ]
            , scIdeal = ideal
            , scSeconds = secs
              -- Measured on the copper that came back, by the same check that
              -- writes route-report.md, and with the design's own intent. A
              -- router's claim to have respected a crosstalk limit is not
              -- evidence that it did, exactly as with the geometry checks.
            , scInjectMv = maximum (0 : [ mv | (_, _, _, mv) <- predictions cu ])
            , scNote = cuNote cu
            }
  where
    -- The router names nets with a leading slash where the design does not,
    -- and the intent is written in the design's names.
    predictions cu =
      let strip n = fromMaybe n (T.stripPrefix "/" n)
      in couplingPredictions (bdAnalog (modBoard m))
           [ t { rtNet = strip (rtNet t) } | t <- cuTraces cu ]
           [ v { rvNet = strip (rvNet v) } | v <- cuVias cu ]
    firstLine t = case filter (not . T.null) (T.lines t) of
      (l : _) -> T.strip l
      []      -> "failed with no output"

-- | Every strategy against every board. The scratch directory external
-- strategies write into is removed afterwards.
runBench :: LibCache -> [Strategy] -> [(String, Module)] -> IO [Score]
runBench lc strats boards = do
  scores <- sequence [ scoreBoard lc s b | b <- boards, s <- strats ]
  ok <- try (removeDirectoryRecursive "modules/_bench/.work")
  _ <- evaluate (either (const ()) id (ok :: Either SomeException ()))
  pure scores

-- Report -----------------------------------------------------------------------

f2 :: Double -> Text
f2 x = T.pack (showFFloat (Just 2) x "")

-- | Markdown, one row per board and strategy. Committed so a change in
-- routing quality shows up in a diff.
benchReport :: [Score] -> Text
benchReport scores = T.unlines $
  [ "| Board | Router | Legal | Spec | Nets | Segments | Vias | Copper mm | Ideal mm | Detour |"
  , "|---|---|:-:|:-:|--:|--:|--:|--:|--:|--:|" ]
  ++ map row (sortOn (\s -> (scBoard s, scStrategy s)) scores)
  ++ [ "" ]
  ++ faults
  ++ [ ""
     , T.pack ("Rows: " ++ show (length scores) ++ ". Legal: "
               ++ show (length (filter scLegal scores)) ++ ".")
     , ""
     , "Detour is copper length over the sum of the minimum spanning trees of each"
    , "net's pad centres. This is a reference length, not a lower bound: branched"
    , "copper and pad geometry can reduce it. A detour below 1.00 alone does not"
    , "prove missing connections; use the connectivity findings. Legal combines"
    , "our connectivity and via/pad checks with router-reported failures and"
    , "contested cells; it is not full independent KiCad DRC. Spec is a modelled"
    , "coupling check, not measured circuit performance. Time is omitted because"
    , "the recorded process CPU time excludes external-router execution."
    , ""
    , "Vias and copper length are diagnostics, not quality scores. JLCPCB charges"
    , "for neither at this board size, and a via is worth about half a millimetre"
    , "of trace electrically at audio; see docs/JLCPCB.md. Prefer Legal and Spec."
    , "Freerouting rows are not deterministic: the same board and jar can score"
    , "differently between runs (the attenuverter's coupling moved 2.22 to 2.31 mV"
    , "with no change on our side), so a moved freerouting row is not evidence of"
    , "a change in our router; grid-astar rows are deterministic and are the diff."
    , "See docs/ROADMAP.md for comparison limitations and planned benchmark work."
     ]
  where
    row s = T.concat
      [ "| ", scBoard s, " | ", scStrategy s, " | ", if scLegal s then "yes" else "**no**"
      , " | ", spec s
      , " | ", T.pack (show (scNets s)), " | ", T.pack (show (scSegments s))
      , " | ", T.pack (show (scVias s)), " | ", f2 (scLength s), " | ", f2 (scIdeal s)
      , " | ", if scIdeal s > 0 && scLength s > 0 then f2 (scLength s / scIdeal s) else "-"
      , " |" ]

    -- Crosstalk against the limit the design set, or "-" when it set none.
    spec s
      | scInjectLimit s <= 0 = "-"
      | not (scRouted s) = "-"
      | scInjectMv s <= scInjectLimit s = T.concat ["ok ", f2 (scInjectMv s), " mV"]
      | otherwise = T.concat ["**", f2 (scInjectMv s), " mV**"]

    faults =
      let bad = [ s | s <- sortOn scBoard scores, not (scLegal s) ]
      in if null bad then [ "No faults." ] else "Faults:" : concatMap describe bad

    describe s =
      [ "- " <> scBoard s <> " / " <> scStrategy s <> ": " <> T.intercalate ", " reasons ]
      where
        reasons = concat
          [ [ "threw (" <> scNote s <> ")" | not (scRouted s) ]
          , [ "produced no copper" | scRouted s, scSegments s == 0, scVias s == 0 ]
          , [ "note: " <> scNote s | scRouted s, not (T.null (scNote s)) ]
          , [ T.pack (show (scFailedNets s)) <> " nets unrouted" | scFailedNets s > 0 ]
          , [ T.pack (show (scContested s)) <> " contested cells" | scContested s > 0 ]
          , [ T.pack (show (scViaPad s)) <> " vias in pads" | scViaPad s > 0 ]
          , [ "crosstalk " <> f2 (scInjectMv s) <> " mV over a limit of "
              <> f2 (scInjectLimit s) <> " mV"
            | scInjectLimit s > 0, scRouted s, scInjectMv s > scInjectLimit s ]
          , [ T.pack (show (scDisconnected s)) <> " nets not one island ("
              <> T.intercalate ", " (take 4 (scBadNets s))
              <> (if length (scBadNets s) > 4 then ", ..." else "") <> ")"
            | scDisconnected s > 0 ]
          ]
