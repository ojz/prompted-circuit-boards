-- | pcbgen regression tests: @cabal test@ from the repository root.
-- Each area contributes its own list; keep fixtures small and name the
-- roadmap finding a test guards.
module Main (main) where

import           Harness       (runTests)
import qualified BenchTests
import qualified RouteTests
import qualified ValidateTests

main :: IO ()
main = runTests (ValidateTests.tests ++ RouteTests.tests ++ BenchTests.tests)
