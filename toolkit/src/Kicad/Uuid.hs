{-# LANGUAGE OverloadedStrings #-}
-- | Deterministic UUIDs. KiCad wants a UUID on nearly every object; deriving
-- them from a stable seed (design name + object path) keeps regenerated files
-- byte-identical, which keeps git diffs meaningful.
module Kicad.Uuid (uuidFor) where

import           Data.Bits       (shiftR, xor, (.&.), (.|.))
import           Data.Char       (ord)
import           Data.Text       (Text)
import qualified Data.Text       as T
import           Data.Word       (Word64)
import           Numeric         (showHex)

-- | Version-5-shaped UUID (name-based) from an arbitrary seed. Not RFC 4122
-- SHA-1, but the layout is valid and collisions are irrelevant at this scale.
uuidFor :: Text -> Text
uuidFor seed =
  let hi = fnv1a 0xcbf29ce484222325 (T.unpack seed)
      lo = fnv1a 0x84222325cbf29ce4 (T.unpack (T.reverse seed <> "|" <> seed))
      hi' = (hi .&. 0xffffffffffff0fff) .|. 0x0000000000005000   -- version 5
      lo' = (lo .&. 0x3fffffffffffffff) .|. 0x8000000000000000   -- variant 10x
      h = T.pack . pad 16 . flip showHex ""
      a = h hi'
      b = h lo'
  in T.intercalate "-"
       [ T.take 8 a
       , T.take 4 (T.drop 8 a)
       , T.take 4 (T.drop 12 a)
       , T.take 4 b
       , T.drop 4 b
       ]
  where
    pad n s = replicate (n - length s) '0' ++ s

fnv1a :: Word64 -> String -> Word64
fnv1a = foldl step
  where
    step h c =
      let h1 = h `xor` fromIntegral (ord c .&. 0xff)
          h2 = h1 * 0x100000001b3
      in h2 `xor` (h2 `shiftR` 29)
