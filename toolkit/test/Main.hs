-- | pcbgen regression tests: @cabal test@ from the repository root.
-- Each area contributes its own list; keep fixtures small and name the
-- roadmap finding a test guards.
module Main (main) where

import           Harness       (runTests)
import qualified AnalogTests
import qualified BenchTests
import qualified BlockTests
import qualified SpiceTests
import qualified RouteTests
import qualified SketchTests
import qualified ValidateTests

main :: IO ()
main = runTests (ValidateTests.tests ++ RouteTests.tests ++ AnalogTests.tests
            ++ BenchTests.tests ++ SpiceTests.tests ++ BlockTests.tests
            ++ SketchTests.tests)
