{-# LANGUAGE OverloadedStrings #-}
-- | pcbgen: write a KiCad project for a named design.
--
--   pcbgen <design> [--out DIR]
--
-- With no --out, KiCad files go to the design's configured directory and
-- reports to docs/modules/<design>/. Custom bundles put reports in DIR/docs.
-- Existing generated files are overwritten; other files are left alone.
module Main (main) where

import           Control.Exception  (IOException, try)
import           Control.Monad      (forM_, unless, when)
import           Data.Maybe         (fromMaybe)
import           Text.Read          (readMaybe)
import           Data.Text          (Text)
import qualified Data.Text          as T
import qualified Data.Text.IO       as TIO
import           System.Directory   (createDirectoryIfMissing)
import           System.Environment (getArgs)
import           System.Exit        (ExitCode (..), exitFailure, exitWith)
import           System.FilePath    ((</>), (<.>), takeDirectory)
import           System.IO          (IOMode (WriteMode), hPutStrLn, hSetEncoding, hSetNewlineMode,
                                     noNewlineTranslation, stderr, utf8, withFile)

import           Design
import           Attenuverter      (attenuverter)
import           AttenuverterPanel (attenuverterPanel)
import           Mult       (mult)
import           MultPanel  (multPanel)
import           RouteTest  (routeTest)
import           BenchFixtures (benchFixtures)
import           Bench
import           Emit.Pcb
import           Emit.Project
import           Emit.Spice
import           Emit.Schematic
import           Kicad.Library
import           Route.Router       (RouteConfig (..), RouteResult (..), RoutedNet (..), autoroute)
import           Sketch.Check       (Finding (..), Severity (..), checkSketch)
import           Sketch.Export
import           Sketch.Model       (decodeSketchText, sxHP, sxName, sxControls)
import           Validate

designs :: [(String, Module)]
designs =
  [ ("attenuverter", attenuverter)
  , ("attenuverter-panel", attenuverterPanel)
  , ("mult", mult)
  , ("mult-panel", multPanel)
  , ("route-test", routeTest)
  ]

-- | Boards the routing benchmark scores. Wider than 'designs': it includes the
-- synthetic fixtures, which are never emitted as projects (one of them is
-- deliberately unroutable, so generation would and should refuse it).
benchBoards :: [(String, Module)]
benchBoards =
  [ ("attenuverter", attenuverter)
  , ("mult", mult)
  , ("route-test", routeTest)
  ] ++ benchFixtures

-- | Routers under test. Freerouting is the parity baseline: it needs KiCad's
-- bundled Python (for the Specctra round trip) and Java, and reports itself as
-- producing nothing when either is missing, so a workstation without them
-- still gets a report.
strategies :: [Strategy]
strategies = [gridRouter, freeroutingRouter]

-- | The via-cost ladder for @sweep-via@: the same router with a layer change
-- priced from 10 to 320 cells (2 mm to 64 mm of trace). This is an experiment,
-- not a baseline, so it prints and writes nothing: the result belongs in the
-- default, and docs/BENCH.md then records it.
defaultLadder :: [Double]
defaultLadder = [10, 20, 40, 80, 160, 320]

-- | One rung of the ladder, optionally with the negotiation budget raised too.
-- Both knobs matter together: a cost that leaves contested cells has either
-- steered the search into a bad basin or merely run out of rounds, and only
-- moving the budget separates those two.
viaStrategy :: Maybe Int -> Maybe Int -> Double -> Strategy
viaStrategy iters starts c = gridRouterWith name tweak
  where
    name = T.pack ("grid-via-" ++ show (round c :: Int)
                   ++ maybe "" (("-i" ++) . show) iters
                   ++ maybe "" (("-s" ++) . show) starts)
    tweak cfg = cfg { rcViaCost = c
                    , rcMaxIterations = fromMaybe (rcMaxIterations cfg) iters
                    , rcStarts = fromMaybe (rcStarts cfg) starts }

main :: IO ()
main = do
  args <- getArgs
  case args of
    ["all"]             -> mapM_ (\(n, _) -> run n Nothing) designs
    ("bench" : rest)    -> bench rest
    ("sweep-via" : rest) -> sweepVia rest
    ["log", b]         -> routeLog b
    ["spice", d]       -> spiceFor d
    ["sketcher"]       -> sketcherAssets
    ("sketch" : files) | not (null files) -> checkSketches files
    [name]              -> run name Nothing
    [name, "--out", d]  -> run name (Just d)
    _ -> do
      hPutStrLn stderr "usage: pcbgen <design>|all [--out DIR]"
      hPutStrLn stderr "       pcbgen bench [board ...]      score routers, write docs/BENCH.md"
      hPutStrLn stderr "       pcbgen sweep-via [--iters N] [--starts N] [--costs N,N] [board ...]"
      hPutStrLn stderr "       pcbgen log <board>            route one board and print the router's log"
      hPutStrLn stderr "       pcbgen spice <design>         write the SPICE netlist for simulation"
      hPutStrLn stderr "       pcbgen sketcher               write sketcher/catalogue.js, vectors.js, fixtures and the fast-ui bundle"
      hPutStrLn stderr "       pcbgen sketch <file.json>...  validate sketches and print their findings"
      hPutStrLn stderr ("designs: " ++ unwords (map fst designs))
      exitFailure

-- | YAML frontmatter for a generated document. Lifecycle information is
-- metadata, so it lives before the first @---@ rather than in the prose.
-- Values are emitted as double-quoted scalars because they routinely contain
-- colons, commas and backticks, and a regeneration command carries its own
-- quotes when @--out@ names a directory with a space in it.
frontMatter :: [(Text, Text)] -> Text
frontMatter fields = T.unlines (["---"] ++ map line fields ++ ["---", ""])
  where
    line (k, v) = k <> ": \"" <> T.concatMap esc v <> "\""
    esc '\\' = "\\\\"
    esc '"'  = "\\\""
    esc c    = T.singleton c

run :: String -> Maybe FilePath -> IO ()
run name mOut = do
  m <- maybe (hPutStrLn stderr ("unknown design: " ++ name) >> exitFailure) pure (lookup name designs)
  let outDir = fromMaybe (modOutDir m) mOut
      docDir = maybe ("docs" </> "modules" </> name) (</> "docs") mOut
      regenerate = "cabal run pcbgen -- " <> T.pack name
        <> maybe "" (\dir -> " --out \"" <> T.pack dir <> "\"") mOut
  lc <- newLibCache
  share <- findKicadShare
  putStrLn ("KiCad libraries: " ++ share)
  -- Validate before emitting: an incomplete or contradictory design writes
  -- nothing, so a stale project can never look like a fresh one.
  diags <- validateModule lc m
  unless (null diags) $ do
    hPutStrLn stderr ("design " ++ name ++ " is invalid (" ++ show (length diags) ++ " diagnostics); nothing written")
    mapM_ (TIO.hPutStrLn stderr . ("  " <>) . formatDiagnostic) diags
    exitFailure
  (schTxt, info) <- emitSchematic lc m
  (pcbTxt, report) <- emitPcb lc m info
  createDirectoryIfMissing True outDir
  let stem = T.unpack (modName m)
      files =
        [ (outDir </> stem <.> "kicad_sch", schTxt)
        , (outDir </> stem <.> "kicad_pcb", pcbTxt)
        , (outDir </> stem <.> "kicad_pro", emitProject m (siSheetUuid info))
        , (outDir </> stem <.> "kicad_dru", emitDru m)
        ]
        ++ [ (docDir </> "route-report.md", frontMatter
             [ ("status", "generated")
             , ("owner", "pcbgen")
             , ("read_when", "comparing this design's routing or predicted analog margins")
             , ("update_when", "regenerate with `" <> regenerate <> "`; do not hand-edit results")
             , ("retire_when", "the corresponding design is removed; Git retains superseded results")
             ] <> T.unlines
             [ "# Routing report: " <> modName m
             , ""
             ] <> reportText)
           | Just reportText <- [report] ]
        -- Footprints from the repository's own library need a project
        -- library table so KiCad's library-mismatch check can find them.
        ++ [ (outDir </> "fp-lib-table", fpLibTable) | any ((== "pcbgen") . libNick . partFootprint) (modParts m) ]
  forM_ files $ \(path, txt) -> do
    createDirectoryIfMissing True (takeDirectory path)
    TIO.writeFile path txt
    putStrLn ("wrote " ++ path)
  when (null (modParts m)) $ hPutStrLn stderr "warning: design has no parts"

-- | Project footprint library table pointing at lib/footprints. KiCad expands
-- PCBGEN_LIB from the environment; check.sh and fab.sh export it.
fpLibTable :: Text
fpLibTable = T.unlines
  [ "(fp_lib_table"
  , "  (version 7)"
  , "  (lib (name \"pcbgen\")(type \"KiCad\")(uri \"${PCBGEN_LIB}/pcbgen.pretty\")(options \"\")(descr \"prompted-circuit-boards footprints\"))"
  , ")"
  ]

-- | Score every strategy against the benchmark boards and write docs/BENCH.md.
-- Named boards restrict the run; no names means all of them.
bench :: [String] -> IO ()
bench names = do
  boards <- selectBoards names
  lc <- newLibCache
  _ <- findKicadShare
  scores <- runBench lc strategies boards
  let rep = frontMatter
        [ ("status", "generated")
        , ("owner", "pcbgen benchmark harness")
        , ("read_when", "comparing routing strategies; interpret scores with docs/ROADMAP.md's benchmark caveats")
        , ("update_when", "regenerate with `cabal run pcbgen -- bench` after a routing or fixture change; do not hand-edit scores")
        , ("retire_when", "replaced by a validated benchmark; Git retains the previous results")
        ] <> T.unlines
        [ "# Routing benchmark"
        , ""
        ] <> benchReport scores
  TIO.putStr rep
  createDirectoryIfMissing True "docs"
  TIO.writeFile ("docs" </> "BENCH.md") rep
  putStrLn "wrote docs/BENCH.md"

-- | Score the via-cost ladder and print it. Deliberately does not touch
-- docs/BENCH.md: a sweep answers a question once, and the answer is a changed
-- default rather than a permanent set of rows.
--
-- @--costs 15,20,25@ replaces the ladder, which is how a cliff found by the
-- coarse ladder gets pinned down.
sweepVia :: [String] -> IO ()
sweepVia args0 = do
  (iters, args1) <- case args0 of
    ("--iters" : spec : rest) -> case readMaybe spec of
      Just n  -> pure (Just (n :: Int), rest)
      Nothing -> do
        hPutStrLn stderr ("not a number: " ++ spec)
        exitFailure
    _ -> pure (Nothing, args0)
  (starts, args) <- case args1 of
    ("--starts" : spec : rest) -> case readMaybe spec of
      Just n  -> pure (Just (n :: Int), rest)
      Nothing -> do
        hPutStrLn stderr ("not a number: " ++ spec)
        exitFailure
    _ -> pure (Nothing, args1)
  (ladder, names) <- case args of
    ("--costs" : spec : rest) -> case traverse readMaybe (splitOn ',' spec) of
      Just cs | not (null cs) -> pure (map (viaStrategy iters starts) cs, rest)
      _ -> do
        hPutStrLn stderr ("not a comma-separated list of numbers: " ++ spec)
        exitFailure
    _ -> pure (map (viaStrategy iters starts) defaultLadder, args)
  boards <- selectBoards names
  lc <- newLibCache
  _ <- findKicadShare
  scores <- runBench lc ladder boards
  TIO.putStr (benchReport scores)

splitOn :: Char -> String -> [String]
splitOn c str = case break (== c) str of
  (before, [])       -> [before]
  (before, _ : rest) -> before : splitOn c rest

-- | Write a design's SPICE netlist, for the hand-written experiments in
-- modules/<name>/sim/ to include. Refuses on any part it cannot model,
-- because a part quietly missing from a netlist is a circuit that simulates
-- beautifully and is not the one on the board.
spiceFor :: String -> IO ()
spiceFor name = do
  m <- maybe (hPutStrLn stderr ("unknown design: " ++ name) >> exitFailure) pure
         (lookup name designs)
  let problems = spiceProblems m
  unless (null problems) $ do
    hPutStrLn stderr ("cannot build a netlist for " ++ name ++ ":")
    mapM_ (\sp -> TIO.hPutStrLn stderr ("  " <> spRef sp <> ": " <> spMessage sp)) problems
    exitFailure
  let dir = "modules" </> name </> "sim"
      path = dir </> name <.> "cir"
  createDirectoryIfMissing True dir
  TIO.writeFile path (emitSpice m)
  putStrLn ("wrote " ++ path)

-- | Route one benchmark board and print what the router did, iteration by
-- iteration. The report says what came out; this says how, which is what a
-- routing change has to be debugged against.
routeLog :: String -> IO ()
routeLog name = do
  boards <- selectBoards [name]
  lc <- newLibCache
  _ <- findKicadShare
  forM_ boards $ \(label, m) -> case routeConfigFor m of
    Nothing -> hPutStrLn stderr (label ++ " has no autoroute block")
    Just cfg -> do
      prob <- routeProblemFor lc m
      let res = autoroute cfg prob
      putStrLn ("coupling spec: " ++ show (rcCoupling cfg))
      mapM_ (TIO.putStrLn . ("  " <>)) (rrLog res)
      putStrLn ("vias " ++ show (length (concatMap rnVias (rrNets res)))
                ++ ", cost " ++ show (rrCost res)
                ++ ", failed " ++ show (rrFailed res))

-- | Named benchmark boards, or all of them when none are named. An unknown
-- name is an error rather than an empty run, so a typo cannot look like a pass.
selectBoards :: [String] -> IO [(String, Module)]
selectBoards names = do
  let unknown = [ n | n <- names, n `notElem` map fst benchBoards ]
  unless (null unknown) $ do
    hPutStrLn stderr ("unknown board(s): " ++ unwords unknown)
    hPutStrLn stderr ("boards: " ++ unwords (map fst benchBoards))
    exitFailure
  pure (if null names then benchBoards
        else [ b | b <- benchBoards, fst b `elem` names ])

-- | The sketcher's generated inputs (docs/ROADMAP.md, S1/S2): the hardware
-- catalogue and form-factor numbers, the test vectors, the reference fixture
-- files, and a single-file bundle of the page for the fast-ui exchange
-- channel. The page itself (sketcher/index.html and its assets) is written by
-- hand and only inlined here.
sketcherAssets :: IO ()
sketcherAssets = do
  let files = [ ("sketcher" </> "catalogue.js", catalogueJs)
              , ("sketcher" </> "vectors.js", vectorsJs) ] ++ fixtureFiles
  forM_ files $ \(path, txt) -> do
    createDirectoryIfMissing True (takeDirectory path)
    writeTextLf path txt
    putStrLn ("wrote " ++ path)
  indexHtml <- TIO.readFile ("sketcher" </> "index.html")
  html <- bundle indexHtml (\rel -> TIO.readFile ("sketcher" </> T.unpack rel))
  let out = "build" </> "sketcher" </> "index.html"
  createDirectoryIfMissing True (takeDirectory out)
  writeTextLf out html
  putStrLn ("wrote " ++ out ++ " (fast-ui bundle)")

-- | Write UTF-8 with LF line endings whatever the platform. A sketch is
-- exchanged with a browser, which ends its lines with LF, and between two
-- workstations; if the generator wrote CRLF on Windows then the same sketch
-- would be a different file depending on who saved it, and every exchange
-- would look like a whole-file diff. 'TIO.writeFile' uses the native newline
-- mode, so the handle is opened explicitly here.
writeTextLf :: FilePath -> Text -> IO ()
writeTextLf path txt =
  withFile path WriteMode $ \h -> do
    hSetEncoding h utf8
    hSetNewlineMode h noNewlineTranslation
    TIO.hPutStr h txt

-- | Validate sketch files and print their findings. Exit 1 if any file is
-- not a sketch, 2 if every file is a sketch but one has a conflict, 0 when
-- every sketch is clean apart from warnings and notes.
checkSketches :: [FilePath] -> IO ()
checkSketches files = do
  results <- mapM checkOne files
  when (any (== Left ()) results) exitFailure
  when (any (== Right True) results) (exitWith (ExitFailure 2))
  where
    checkOne path = do
      -- An unreadable file is a diagnostic like any other, not a crash: this
      -- runs over a list, and one missing name must not lose the rest.
      r <- try (TIO.readFile path) :: IO (Either IOException Text)
      case r of
        Left e -> do
          hPutStrLn stderr (path ++ ": cannot be read (" ++ show e ++ ")")
          pure (Left ())
        Right txt -> report path txt
    report path txt =
      case decodeSketchText txt of
        Left errs -> do
          hPutStrLn stderr (path ++ ": not a valid sketch (" ++ show (length errs) ++ " problems)")
          mapM_ (TIO.hPutStrLn stderr . ("  " <>)) errs
          pure (Left ())
        Right s -> do
          let fs = checkSketch s
              conflicts = [ f | f <- fs, fnSeverity f == Conflict ]
          putStrLn (path ++ ": " ++ T.unpack (sxName s) ++ ", " ++ show (sxHP s) ++ "HP, "
                    ++ show (length (sxControls s)) ++ " controls, " ++ show (length conflicts) ++ " conflicts")
          forM_ fs $ \f -> TIO.putStrLn ("  " <> sev (fnSeverity f) <> " " <> fnKind f <> ": " <> fnMessage f)
          pure (Right (not (null conflicts)))
    sev Conflict = "CONFLICT"
    sev Warning  = "warning "
    sev Note     = "note    "
