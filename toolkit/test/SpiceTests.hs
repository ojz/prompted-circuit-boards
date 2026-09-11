{-# LANGUAGE OverloadedStrings #-}
-- | Tests for the SPICE netlist generator.
--
-- Both of the interesting ones guard mistakes that produced a netlist which
-- read perfectly well and described a different circuit than the board. That
-- is the failure mode worth testing for here: a netlist that refuses to build
-- costs a minute, and one that quietly models the wrong circuit costs
-- whatever is concluded from it.
module SpiceTests (tests) where

import           Data.List    (isInfixOf)
import qualified Data.Text    as T

import           Attenuverter (attenuverter)
import           Design
import           Emit.Spice
import           Harness

tests :: [Test]
tests =
  [ railsDoNotMerge
  , collidingNamesAreRefused
  , diodeAnodeComesFirst
  , attenuverterHasNoUnmodelledParts
  , unreadableValueIsRefused
  ]

-- | @+12V@ and @-12V@ both scrubbed to @_12V@, so the netlist put the
-- op-amp's V+ and V- on one node and shorted the supplies. Nothing in the
-- file looked wrong.
railsDoNotMerge :: Test
railsDoNotMerge = test "supply rails do not become the same SPICE node" $
  let m = tiny
        [ Net "+12V" Power [("R1", "1")]
        , Net "-12V" Power [("R1", "2")] ]
      out = T.unpack (emitSpice m)
  in expectAll
       [ (null (spiceProblems m)
         , "two differently named rails should be fine: " ++ show (spiceProblems m))
       , (not ("_12V _12V" `isInfixOf` out)
         , "the two rails should be different nodes:\n" ++ out)
       , (("P12V" `isInfixOf` out) && ("N12V" `isInfixOf` out)
         , "the signs should survive scrubbing:\n" ++ out) ]

-- | And when two names really would collide, it has to refuse rather than
-- emit a shorted circuit.
--
-- (Folded into the test above's fixture: names differing only in a character
-- that scrubs to the same thing.)
collidingNamesAreRefused :: Test
collidingNamesAreRefused = test "colliding node names are refused" $
  let m = tiny
        [ Net "A B" Signal [("R1", "1")]
        , Net "A/B" Signal [("R1", "2")] ]
  in expect (not (null (spiceProblems m)))
       "two nets scrubbing to the same node should be reported, not emitted"

-- | KiCad numbers a diode's cathode 1 and its anode 2; SPICE wants the anode
-- first. Getting it backwards reverses every protection diode on the board
-- and simulates happily.
diodeAnodeComesFirst :: Test
diodeAnodeComesFirst = test "a diode is emitted anode first" $
  let m = (tiny [ Net "K" Signal [("D1", "1")], Net "A" Signal [("D1", "2")] ])
            { modParts = [ part "D1" "B5819W" (LibId "Device" "D_Schottky")
                                  (LibId "Diode_SMD" "D_SOD-123") (0, 0) (0, 0) ] }
      out = T.unpack (emitSpice m)
  in expect ("DD1 A K B5819W" `isInfixOf` out)
       ("expected 'DD1 A K B5819W' (anode, cathode, model):\n" ++ out)

-- | The real board has to be fully modellable, or the netlist is a partial
-- circuit and every number from it is suspect.
attenuverterHasNoUnmodelledParts :: Test
attenuverterHasNoUnmodelledParts =
  test "every electrical part of the attenuverter becomes an element" $
    let problems = spiceProblems attenuverter
        out = T.unpack (emitSpice attenuverter)
    in expectAll
         [ (null problems
           , "unmodelled: " ++ show [ (spRef p, spMessage p) | p <- problems ])
           -- The op-amp's two units, both supplies distinct.
         , ("XU1_1 WIPER1 INV1 P12V N12V OA1 TL072" `isInfixOf` out
           , "unit A should be wired non-inverting, inverting, V+, V-, out:\n" ++ out)
         , ("XU1_7 WIPER2 INV2 P12V N12V OA2 TL072" `isInfixOf` out
           , "unit B should use pins 5, 6, 7:\n" ++ out)
           -- Series protection diodes, pointing into the rails they feed.
         , ("DD2 P12_RAW P12V B5819W" `isInfixOf` out
           , "the +12 V Schottky should conduct from the raw rail:\n" ++ out)
         , ("DD1 N12V N12_RAW B5819W" `isInfixOf` out
           , "the -12 V Schottky should conduct towards the raw rail:\n" ++ out) ]

-- | A value SPICE cannot read is an error, not a default. A resistor
-- silently becoming 1 ohm is how a simulation gets to be confidently wrong.
unreadableValueIsRefused :: Test
unreadableValueIsRefused = test "an unreadable component value is refused" $
  let m = (tiny [ Net "A" Signal [("R1", "1")], Net "B" Signal [("R1", "2")] ])
            { modParts = [ part "R1" "see BOM" (LibId "Device" "R")
                                  (LibId "Resistor_SMD" "R_0805_2012Metric")
                                  (0, 0) (0, 0) ] }
  in expect (not (null (spiceProblems m)))
       "a value with no number in it should be reported"

-- | A one-resistor module to hang nets on.
tiny :: [Net] -> Module
tiny ns = Module
  { modName = "tiny"
  , modOutDir = "modules/_tests/tiny"
  , modTitle = "fixture"
  , modHP = 4
  , modParts = [ part "R1" "1k" (LibId "Device" "R")
                      (LibId "Resistor_SMD" "R_0805_2012Metric") (0, 0) (0, 0) ]
  , modNets = ns
  , modBoard = Board
      { bdWidth = 10, bdHeight = 10, bdCornerRadius = 0
      , bdRules = defaultRules, bdTraces = [], bdAutoRoute = Nothing
      , bdZones = [], bdTexts = [], bdCustomRules = "", bdAnalog = noAnalog }
  , modNotes = []
  }
