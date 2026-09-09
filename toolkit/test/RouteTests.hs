{-# LANGUAGE OverloadedStrings #-}
-- | Router and layout-geometry tests (roadmap M2).
--
-- The router's own success flag is not evidence: these tests check the final
-- geometry instead. Each test names the finding it guards.
module RouteTests (tests) where

import           Data.List     (isInfixOf)
import           Data.Text     (Text)
import qualified Data.Text     as T

import           Attenuverter  (attenuverter)
import           Emit.Pcb      (routeConfigFor, routeProblemFor)
import           Harness
import           Kicad.Library (newLibCache)
import           Mult          (mult)
import           Route.Check
import           Route.Geometry
import           Route.Router
import           Design         (Module)

tests :: [Test]
tests =
  [ viaInPadDetected
  , viaClearOfPadAccepted
  , viaInOwnNetPadDetected
  , viaOnOtherLayerPadDetected
  , connectivitySplitDetected
  , connectivityJoinedAccepted
  , preRoutedIslandConnected
  , manualWidthBlocks
  , attenuverterRoutesCleanly
  , multRoutesCleanly
  ]

-- Fixtures ---------------------------------------------------------------------

-- | A 0805 solder land: 1.15 x 1.4 mm, front side only, like the SMD passives
-- the four historical via-in-pad violations sat in.
smdPad :: Text -> Text -> Maybe Text -> Pt -> PadGeom
smdPad ref num net at = PadGeom ref num net at (RoundRect 1.15 1.4 0.2 0) [F]

via :: Text -> Pt -> RVia
via net at = RVia net at 0.6 0.3

clearance :: Double
clearance = 0.2

-- Via in pad -------------------------------------------------------------------

-- | Roadmap finding "SMD pad drills": a 0.3 mm via drill inside a solder
-- land. The pad is a different net here, the clearest possible violation.
viaInPadDetected :: Test
viaInPadDetected = test "via inside an SMD pad is reported" $
  let pads = [smdPad "C1" "2" (Just "GND") (10, 10)]
      vs   = [via "/SIG" (10, 10)]
      vios = viaPadViolations clearance pads vs
  in expectAll
       [ (length vios == 1, "expected exactly one violation, got " ++ show (length vios))
       , (all ((< 0) . vpGap) vios, "gap should be negative (copper overlaps): " ++ show (map vpGap vios))
       , (any (("C1.2" `isInfixOf`) . T.unpack . describeViaPad) vios
         , "description should name C1.2: " ++ show (map describeViaPad vios))
       ]

-- | A via far enough away is legal, so the check cannot simply flag
-- everything.
viaClearOfPadAccepted :: Test
viaClearOfPadAccepted = test "via clear of every pad is accepted" $
  let pads = [smdPad "C1" "2" (Just "GND") (10, 10)]
      -- pad half-width 0.575 + via radius 0.3 + clearance 0.2 = 1.075 mm
      vs   = [via "/SIG" (11.2, 10)]
  in expect (null (viaPadViolations clearance pads vs))
            ("expected no violation: " ++ show (map describeViaPad (viaPadViolations clearance pads vs)))

-- | The historical vias sat in pads of their own net, which is why neither
-- the router nor KiCad's DRC complained. Same net is still unassemblable.
viaInOwnNetPadDetected :: Test
viaInOwnNetPadDetected = test "via inside a pad of its own net is reported" $
  let pads = [smdPad "R3" "2" (Just "/OUT1") (5, 5)]
      vs   = [via "/OUT1" (5, 5)]
  in expect (length (viaPadViolations clearance pads vs) == 1)
            "a same-net via in an SMD land must still be reported"

-- | A via is a through-hole: a pad on the back is just as much in its way.
viaOnOtherLayerPadDetected :: Test
viaOnOtherLayerPadDetected = test "via is checked against pads on both layers" $
  let backPad = (smdPad "R4" "1" (Just "GND") (3, 3)) { pgLayers = [B] }
      vs      = [via "/SIG" (3, 3)]
  in expect (length (viaPadViolations clearance [backPad] vs) == 1)
            "a via must be reported against a back-side pad too"

-- Connectivity -----------------------------------------------------------------

-- | Two pads and a trace that reaches only one of them: the connectivity
-- check must not call that connected (roadmap finding "Pre-route
-- connectivity").
connectivitySplitDetected :: Test
connectivitySplitDetected = test "copper in two islands is reported disconnected" $
  let pads    = [ smdPad "J1" "1" (Just "/N") (2, 5), smdPad "J2" "1" (Just "/N") (18, 5) ]
      traces  = [ RTrace "/N" F 0.3 [(15, 5), (18, 5)] ]
      copper  = netCopper "/N" pads traces []
  in expectAll
       [ (not (isConnected copper), "pad at (2,5) is not joined to anything, must count as a second island")
       , (length (copperComponents copper) == 2
         , "expected 2 components, got " ++ show (length (copperComponents copper)))
       ]

-- | The same net once the trace spans both pads.
connectivityJoinedAccepted :: Test
connectivityJoinedAccepted = test "copper joined by a trace is connected" $
  let pads   = [ smdPad "J1" "1" (Just "/N") (2, 5), smdPad "J2" "1" (Just "/N") (18, 5) ]
      traces = [ RTrace "/N" F 0.3 [(2, 5), (18, 5)] ]
  in expect (isConnected (netCopper "/N" pads traces []))
            "one trace between the two pads must make one island"

-- | The router itself must pick up a pad that a hand-drawn trace does not
-- reach. The old code seeded the search tree with every pre-routed cell, so
-- the net counted as done before that pad was ever connected.
preRoutedIslandConnected :: Test
preRoutedIslandConnected = test "router connects a pad the pre-route misses" $
  let pads = [ smdPad "J1" "1" (Just "/N") (2, 5), smdPad "J2" "1" (Just "/N") (18, 5) ]
      prob = RouteProblem
        { rpOutline = Outline 20 10 0
        , rpPads = pads
        , rpKeepouts = []
        , rpPreRouted = [("/N", F, 0.3, [(15, 5), (18, 5)])] }
      cfg = (defaultRouteConfig ["/N"]) { rcClearance = clearance }
      res = autoroute cfg prob
      preTrace = RTrace "/N" F 0.3 [(15, 5), (18, 5)]
      routedTraces = concatMap rnTraces (rrNets res)
      routedVias = concatMap rnVias (rrNets res)
      copper = netCopper "/N" pads (preTrace : routedTraces) routedVias
  in expectAll
       [ (null (rrFailed res), "net should route, failed: " ++ show (rrFailed res))
       , (null (rrDisconnected res), "router should not report a disconnect: " ++ show (rrDisconnected res))
       , (not (null routedTraces), "router should have added copper to reach the missed pad")
       , (isConnected copper, "pads, pre-route and new copper must form one island")
       ]

-- | A hand-drawn trace blocks according to its own width, not the router's
-- default. A 1.0 mm trace reaches further than a 0.3 mm one.
manualWidthBlocks :: Test
manualWidthBlocks = test "pre-routed copper blocks by its own width" $
  let probOf w = RouteProblem
        { rpOutline = Outline 20 10 0
        , rpPads = [ smdPad "J1" "1" (Just "/A") (2, 2), smdPad "J2" "1" (Just "/B") (18, 8) ]
        , rpKeepouts = []
        , rpPreRouted = [("/A", F, w, [(2, 5), (18, 5)])] }
      cfg = (defaultRouteConfig ["/A", "/B"]) { rcClearance = clearance }
      -- Probe straight down from the trace at y = 5. The exact reach is
      -- quantised by the grid, so assert the property instead of a number:
      -- the wide trace must block strictly more than the narrow one.
      probes = [ (10, 5 + 0.2 * fromIntegral k) | k <- [1 .. 12 :: Int] ]
      blocked w = [ p | p <- probes, preRoutedBlocked cfg (probOf w) F p ]
      thin = blocked 0.3
      wide = blocked 1.0
  in expectAll
       [ (not (null thin), "a 0.3 mm pre-route should block the points closest to it")
       , (all (`elem` wide) thin
         , "everything a 0.3 mm pre-route blocks must also be blocked by a 1.0 mm one")
       , (length wide > length thin
         , "a 1.0 mm pre-route must reach further than a 0.3 mm one; blocked "
           ++ show (length wide) ++ " vs " ++ show (length thin) ++ " probes")
       ]

-- Integration ------------------------------------------------------------------

-- | The real boards, routed by the real router, checked on the final
-- geometry: no via in any pad, no net in pieces, nothing given up on.
routesCleanly :: String -> Module -> Test
routesCleanly label m = testIO (label ++ " routes with no via/pad violation or disconnect") $ do
  lc <- newLibCache
  prob <- routeProblemFor lc m
  case routeConfigFor m of
    Nothing -> pure [label ++ " has no autoroute block"]
    Just cfg -> do
      let res = autoroute cfg prob
          vios = viaPadViolations (rcClearance cfg) (rpPads prob)
                                  [ v | rn <- rrNets res, v <- rnVias rn ]
      pure $ expectAll
        [ (null (rrFailed res), "nets the router gave up on: " ++ show (rrFailed res))
        , (rrConflicts res == 0, "contested cells left: " ++ show (rrConflicts res))
        , (null vios, "via/pad violations: " ++ show (map describeViaPad vios))
        , (null (rrDisconnected res), "disconnected nets: " ++ show (rrDisconnected res))
        ]

attenuverterRoutesCleanly :: Test
attenuverterRoutesCleanly = routesCleanly "attenuverter" attenuverter

multRoutesCleanly :: Test
multRoutesCleanly = routesCleanly "mult" mult
