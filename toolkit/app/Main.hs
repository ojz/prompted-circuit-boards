{-# LANGUAGE OverloadedStrings #-}
-- | pcbgen: write a KiCad project for a named design.
--
--   pcbgen <design> [--out DIR]
--
-- With no --out, files go to modules/<design>/ relative to the working
-- directory. Existing generated files are overwritten; SPEC.md and anything
-- else in the directory are left alone.
module Main (main) where

import           Control.Monad      (forM_, unless, when)
import           Data.Maybe         (fromMaybe)
import           Data.Text          (Text)
import qualified Data.Text          as T
import qualified Data.Text.IO       as TIO
import           System.Directory   (createDirectoryIfMissing)
import           System.Environment (getArgs)
import           System.Exit        (exitFailure)
import           System.FilePath    ((</>), (<.>))
import           System.IO          (hPutStrLn, stderr)

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
import           Emit.Schematic
import           Kicad.Library
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

-- | Routers under test. One entry per strategy; add Freerouting here.
strategies :: [Strategy]
strategies = [gridRouter]

main :: IO ()
main = do
  args <- getArgs
  case args of
    ["all"]             -> mapM_ (\(n, _) -> run n Nothing) designs
    ("bench" : rest)    -> bench rest
    [name]              -> run name Nothing
    [name, "--out", d]  -> run name (Just d)
    _ -> do
      hPutStrLn stderr "usage: pcbgen <design>|all [--out DIR]"
      hPutStrLn stderr "       pcbgen bench [board ...]      score routers, write BENCH.md"
      hPutStrLn stderr ("designs: " ++ unwords (map fst designs))
      exitFailure

run :: String -> Maybe FilePath -> IO ()
run name mOut = do
  m <- maybe (hPutStrLn stderr ("unknown design: " ++ name) >> exitFailure) pure (lookup name designs)
  let outDir = fromMaybe (modOutDir m) mOut
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
        -- Routing score next to the board so quality is diffable across commits.
        ++ [ (outDir </> "route-report.md", "# Routing report: " <> modName m <> "\n\n" <> r) | Just r <- [report] ]
        -- Footprints from the repository's own library need a project
        -- library table so KiCad's library-mismatch check can find them.
        ++ [ (outDir </> "fp-lib-table", fpLibTable) | any ((== "pcbgen") . libNick . partFootprint) (modParts m) ]
  forM_ files $ \(path, txt) -> do
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

-- | Score every strategy against the benchmark boards and write BENCH.md.
-- Named boards restrict the run; no names means all of them.
bench :: [String] -> IO ()
bench names = do
  let boards = if null names then benchBoards
               else [ b | b <- benchBoards, fst b `elem` names ]
      unknown = [ n | n <- names, n `notElem` map fst benchBoards ]
  unless (null unknown) $ do
    hPutStrLn stderr ("unknown board(s): " ++ unwords unknown)
    hPutStrLn stderr ("boards: " ++ unwords (map fst benchBoards))
    exitFailure
  lc <- newLibCache
  _ <- findKicadShare
  scores <- runBench lc strategies boards
  let rep = benchReport scores
  TIO.putStr rep
  TIO.writeFile "BENCH.md" (T.unlines ["# Routing benchmark", ""] <> rep)
  putStrLn "wrote BENCH.md"
