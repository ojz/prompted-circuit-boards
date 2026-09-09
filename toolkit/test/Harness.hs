-- | Minimal test harness: no external dependency, so a fresh checkout with
-- only the packages pcbgen already needs can run @cabal test@.
module Harness
  ( Test
  , test
  , testIO
  , expect
  , expectAll
  , runTests
  ) where

import           Control.Exception (SomeException, evaluate, try)
import           Control.Monad     (forM)
import           System.Exit       (exitFailure, exitSuccess)
import           System.IO         (hFlush, stdout)

-- | A named check that yields a list of failure messages (empty = pass).
data Test = Test String (IO [String])

-- | Pure check.
test :: String -> [String] -> Test
test name failures = Test name (pure failures)

-- | Check that needs IO (library loading, file access).
testIO :: String -> IO [String] -> Test
testIO = Test

-- | One condition with the message to report when it is false.
expect :: Bool -> String -> [String]
expect ok msg = [ msg | not ok ]

expectAll :: [(Bool, String)] -> [String]
expectAll = concatMap (uncurry expect)

runTests :: [Test] -> IO ()
runTests tests = do
  results <- forM tests $ \(Test name act) -> do
    r <- try (act >>= evaluate . forceList) :: IO (Either SomeException [String])
    let failures = either (\e -> ["exception: " ++ show e]) id r
    putStrLn ((if null failures then "PASS  " else "FAIL  ") ++ name)
    mapM_ (putStrLn . ("      " ++)) failures
    hFlush stdout
    pure (null failures)
  let n = length results
      bad = length (filter not results)
  putStrLn ""
  putStrLn (show (n - bad) ++ "/" ++ show n ++ " tests passed")
  if bad == 0 then exitSuccess else exitFailure
  where
    forceList xs = length (concat xs) `seq` xs
