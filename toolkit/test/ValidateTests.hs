{-# LANGUAGE OverloadedStrings #-}
-- | Design validation tests (roadmap M1). The attenuverter is the fixture:
-- each negative test mutates one thing in its nets or parts and asserts
-- that the diagnostic names exactly that thing (code and subject), not just
-- that validation failed. The four wiring faults from the review table are
-- the first four negative cases.
module ValidateTests (tests) where

import           Data.Text         (Text)
import qualified Data.Text         as T
import           System.IO.Unsafe  (unsafePerformIO)

import           Attenuverter      (attenuverter)
import           AttenuverterPanel (attenuverterPanel)
import           Design
import           Harness
import           Kicad.Library     (LibCache, newLibCache)
import           Mult              (mult)
import           MultPanel         (multPanel)
import           RouteTest         (routeTest)
import           Validate

-- | One library cache for the whole suite, so the multi-megabyte symbol
-- libraries are parsed once rather than once per test. Forced lazily inside
-- the first test's 'try', so a missing KiCad install fails that test with
-- the locator's message instead of crashing the runner.
{-# NOINLINE libCache #-}
libCache :: LibCache
libCache = unsafePerformIO newLibCache

tests :: [Test]
tests =
  [ -- Existing designs, as committed.
    valid "attenuverter validates as-is (J2.TN, J4.TN explicit no-connects)" attenuverter
  , valid "mult validates as-is (jack TN pins explicit no-connects)" mult
  , valid "attenuverter panel validates as-is" attenuverterPanel
  , valid "mult panel validates as-is" multPanel
  , valid "route-test validates as-is" routeTest

    -- Review table: the four wiring faults ERC used to accept.
  , rejected "U1.8 removed from +12V is an unassigned pin"
      (onNets (editNet "+12V" (dropPin ("U1", "8"))) attenuverter)
      [ ("unassigned-pin", "U1.8", ["U1 pin 8", "V+"]) ]
  , rejected "U1.8 mistyped as U1.88 names the bad pin and the real pins"
      (onNets (editNet "+12V" (addPin ("U1", "88") . dropPin ("U1", "8"))) attenuverter)
      [ ("unknown-pin", "U1.88", ["U1 pin 88", "Amplifier_Operational:OPA2197xD", "pins: 1, 2, 3, 5, 6, 7, 4, 8", "+12V"])
      , ("unassigned-pin", "U1.8", ["U1 pin 8"]) ]
  , rejected "U1.8 on both rails is a pin on multiple nets"
      (onNets (editNet "-12V" (addPin ("U1", "8"))) attenuverter)
      [ ("pin-on-multiple-nets", "U1.8", ["+12V", "-12V"]) ]
  , rejected "D2.1 removed from +12V is an unassigned pin"
      (onNets (editNet "+12V" (dropPin ("D2", "1"))) attenuverter)
      [ ("unassigned-pin", "D2.1", ["D2 pin 1"]) ]

    -- Names.
  , rejected "a duplicated reference is rejected"
      (onParts (\ps -> ps ++ [ p | p <- ps, partRef p == "R1" ]) attenuverter)
      [ ("duplicate-reference", "R1", ["2 parts"]) ]
  , rejected "a duplicated net name is rejected"
      (onNets (++ [Net "OUT1" Signal []]) attenuverter)
      [ ("duplicate-net", "OUT1", []) ]
  , rejected "a net naming a reference that is not a part is rejected"
      (onNets (editNet "OUT1" (addPin ("R99", "1"))) attenuverter)
      [ ("unknown-reference", "R99", ["OUT1", "R99"]) ]
  , rejected "a power net without a power symbol is reported, not crashed on"
      (onNets (editNet "+12V" (\n -> n { netName = "+12V_BOGUS" })) attenuverter)
      [ ("unknown-power-symbol", "+12V_BOGUS", ["power:+12V_BOGUS"]) ]

    -- Assembly intent must be explicit both ways.
  , rejected "a Factory part without an LCSC Part # is rejected"
      (onParts (editPart "R1" (\p -> p { partFields = [] })) attenuverter)
      [ ("factory-without-lcsc", "R1", ["R1", "LCSC"]) ]
  , rejected "a Hand part carrying an LCSC Part # is rejected"
      (onParts (editPart "J1" (\p -> p { partFields = [("LCSC Part #", "C1234")] })) attenuverter)
      [ ("lcsc-on-non-factory", "J1", ["J1", "Hand", "C1234"]) ]

    -- No-connects.
  , rejected "dropping J2.TN from partNoConnect makes it an unassigned pin"
      (onParts (editPart "J2" (\p -> p { partNoConnect = [] })) attenuverter)
      [ ("unassigned-pin", "J2.TN", ["J2 pin TN"]) ]
  , rejected "a pin both no-connect and on a net is rejected"
      (onParts (editPart "J1" (\p -> p { partNoConnect = ["TN"] })) attenuverter)
      [ ("no-connect-on-net", "J1.TN", ["J1 pin TN", "OFFSET"]) ]
  , rejected "a no-connect entry that is not a real pin is rejected"
      (onParts (editPart "J2" (\p -> p { partNoConnect = ["TN", "ZZ"] })) attenuverter)
      [ ("no-connect-unknown-pin", "J2.ZZ", ["ZZ", "Connector_Audio:AudioJack2_SwitchT", "pins: S, T, TN"]) ]
  , rejected "mult: a jack losing its TN no-connect is an unassigned pin"
      (onParts (editPart "J7" (\p -> p { partNoConnect = [] })) mult)
      [ ("unassigned-pin", "J7.TN", ["J7 pin TN"]) ]

    -- Numbers and net references, no library needed.
  , structural "zero board width is rejected"
      (onBoard (\b -> b { bdWidth = 0 }) attenuverter)
      [ ("bad-dimension", "bdWidth") ]
  , structural "negative corner radius is rejected"
      (onBoard (\b -> b { bdCornerRadius = -1 }) attenuverter)
      [ ("bad-dimension", "bdCornerRadius") ]
  , structural "a zero design rule is rejected"
      (onBoard (\b -> b { bdRules = (bdRules b) { drClearance = 0 } }) attenuverter)
      [ ("bad-rule", "drClearance") ]
  , structural "a via drill not smaller than its diameter is rejected"
      (onBoard (\b -> b { bdRules = (bdRules b) { drViaDrill = 0.6 } }) attenuverter)
      [ ("bad-rule", "drViaDrill") ]
  , structural "autoroute with a zero pitch is rejected"
      (onBoard (\b -> b { bdAutoRoute = fmap (\ar -> ar { arPitch = 0 }) (bdAutoRoute b) }) attenuverter)
      [ ("bad-autoroute", "arPitch") ]
  , structural "autoroute naming a net that does not exist is rejected"
      (onBoard (\b -> b { bdAutoRoute = fmap (\ar -> ar { arNets = "NOPE" : arNets ar }) (bdAutoRoute b) }) attenuverter)
      [ ("unknown-net", "NOPE") ]
  , structural "a zone on a net that does not exist is rejected"
      (onBoard (\b -> b { bdZones = Zone "GROUND" "F.Cu" "bad" [(0, 0), (1, 0), (1, 1)] 0.3 0.25 ThermalRelief : bdZones b }) attenuverter)
      [ ("unknown-net", "GROUND") ]
  , structural "a trace on a net that does not exist is rejected"
      (onBoard (\b -> b { bdTraces = Trace "NOPE" "F.Cu" 0.3 [(0, 0), (1, 1)] : bdTraces b }) attenuverter)
      [ ("unknown-net", "NOPE") ]
    -- The mult's GND pads are held together by its pours alone. Unbonding
    -- such a pour strands every pad on the net, and KiCad only says so after
    -- a full DRC run, so validation says it first.
  , structural "an unbonded pour on a net nothing routes is rejected"
      (onBoard (\b -> b { bdZones = [ z { znConnect = PadsUnbonded } | z <- bdZones b ] }) mult)
      [ ("unbonded-pour-unrouted-net", "GND_front")
      , ("unbonded-pour-unrouted-net", "GND_back") ]
  , test "an unbonded pour is fine when the net is routed as copper"
      [ "unexpected: " ++ T.unpack (formatDiagnostic d)
      | d <- validateStructure attenuverter
      , diagCode d == "unbonded-pour-unrouted-net" ]
  , test "the structural checks accept the attenuverter"
      [ "unexpected: " ++ T.unpack (formatDiagnostic d) | d <- validateStructure attenuverter ]
  ]

-- Assertions -------------------------------------------------------------------

-- | Validation returns no diagnostics.
valid :: String -> Module -> Test
valid name m = testIO name $ do
  ds <- validateModule libCache m
  pure [ "unexpected diagnostic: " ++ T.unpack (formatDiagnostic d) | d <- ds ]

-- | Validation returns, for each wanted (code, subject, fragments), a
-- diagnostic with that code about that subject whose message contains every
-- fragment.
rejected :: String -> Module -> [(Text, Text, [Text])] -> Test
rejected name m wanted = testIO name $ do
  ds <- validateModule libCache m
  pure (expect (not (null ds)) "design was accepted" ++ concatMap (want ds) wanted)
  where
    want ds (code, subj, frags) =
      case [ d | d <- ds, diagCode d == code, diagSubject d == subj ] of
        [] -> [ "no " ++ T.unpack code ++ " diagnostic about " ++ T.unpack subj ++ "; got:" ++ listing ds ]
        (d : _) -> [ "message lacks " ++ show f ++ ": " ++ T.unpack (formatDiagnostic d)
                   | f <- frags, not (f `T.isInfixOf` diagMessage d) ]
    listing ds = concatMap (\d -> "\n        " ++ T.unpack (formatDiagnostic d)) ds

-- | The pure checks alone report (code, subject).
structural :: String -> Module -> [(Text, Text)] -> Test
structural name m wanted =
  test name $ concat
    [ expect (any (\d -> diagCode d == code && diagSubject d == subj) ds)
        ("no " ++ T.unpack code ++ " diagnostic about " ++ T.unpack subj ++ "; got: " ++ show (map formatDiagnostic ds))
    | (code, subj) <- wanted ]
  where ds = validateStructure m

-- Mutations ----------------------------------------------------------------------

onNets :: ([Net] -> [Net]) -> Module -> Module
onNets f m = m { modNets = f (modNets m) }

onParts :: ([Part] -> [Part]) -> Module -> Module
onParts f m = m { modParts = f (modParts m) }

onBoard :: (Board -> Board) -> Module -> Module
onBoard f m = m { modBoard = f (modBoard m) }

editNet :: Text -> (Net -> Net) -> [Net] -> [Net]
editNet name f = map (\n -> if netName n == name then f n else n)

editPart :: Text -> (Part -> Part) -> [Part] -> [Part]
editPart ref f = map (\p -> if partRef p == ref then f p else p)

dropPin :: (Text, Text) -> Net -> Net
dropPin pin n = n { netPins = filter (/= pin) (netPins n) }

addPin :: (Text, Text) -> Net -> Net
addPin pin n = n { netPins = netPins n ++ [pin] }
