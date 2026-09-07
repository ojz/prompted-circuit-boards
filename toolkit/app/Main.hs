{-# LANGUAGE OverloadedStrings #-}
-- | pcbgen: write a KiCad project for a named design.
--
--   pcbgen <design> [--out DIR]
--
-- With no --out, files go to modules/<design>/ relative to the working
-- directory. Existing generated files are overwritten; SPEC.md and anything
-- else in the directory are left alone.
module Main (main) where

import           Control.Monad      (forM_, when)
import qualified Data.Text          as T
import qualified Data.Text.IO       as TIO
import           System.Directory   (createDirectoryIfMissing)
import           System.Environment (getArgs)
import           System.Exit        (exitFailure)
import           System.FilePath    ((</>), (<.>))
import           System.IO          (hPutStrLn, stderr)

import           Design
import           Designs.Mult       (mult)
import           Emit.Pcb
import           Emit.Project
import           Emit.Schematic
import           Kicad.Library

designs :: [(String, Module)]
designs = [ ("mult", mult) ]

main :: IO ()
main = do
  args <- getArgs
  case args of
    [name]              -> run name ("modules" </> name)
    [name, "--out", d]  -> run name d
    _ -> do
      hPutStrLn stderr "usage: pcbgen <design> [--out DIR]"
      hPutStrLn stderr ("designs: " ++ unwords (map fst designs))
      exitFailure

run :: String -> FilePath -> IO ()
run name outDir = do
  m <- maybe (hPutStrLn stderr ("unknown design: " ++ name) >> exitFailure) pure (lookup name designs)
  lc <- newLibCache
  share <- findKicadShare
  putStrLn ("KiCad libraries: " ++ share)
  (schTxt, info) <- emitSchematic lc m
  pcbTxt <- emitPcb lc m info
  createDirectoryIfMissing True outDir
  let stem = T.unpack (modName m)
      files =
        [ (outDir </> stem <.> "kicad_sch", schTxt)
        , (outDir </> stem <.> "kicad_pcb", pcbTxt)
        , (outDir </> stem <.> "kicad_pro", emitProject m (siSheetUuid info))
        , (outDir </> stem <.> "kicad_dru", emitDru m)
        ]
  forM_ files $ \(path, txt) -> do
    TIO.writeFile path txt
    putStrLn ("wrote " ++ path)
  when (null (modParts m)) $ hPutStrLn stderr "warning: design has no parts"
