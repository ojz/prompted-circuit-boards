{-# LANGUAGE OverloadedStrings #-}
-- | Emit a KiCad 10 board (.kicad_pcb) from a 'Module'.
--
-- Footprints are the official library definitions embedded verbatim, with
-- placement, nets and text values applied the way KiCad itself writes them.
-- Zones are emitted unfilled; @kicad-cli pcb drc --refill-zones --save-board@
-- fills them headlessly afterwards.
module Emit.Pcb
  ( emitPcb
  , routeProblemFor
  , routeConfigFor
  , placedFootprints
  , routeProblemOf
  , routingErrors
  ) where

import           Control.Exception (evaluate)
import           Control.Monad   (unless)
import qualified Data.Map.Strict as M
import           Data.Maybe      (fromMaybe, isJust, isNothing)
import           Data.Text       (Text)
import qualified Data.Text       as T
import           Numeric         (showFFloat)
import           System.CPUTime  (getCPUTime)

import           Design
import           Emit.Schematic  (SchInfo (..), SymInfo (..), emitSchematic)
import           Kicad.Library
import           Kicad.SExpr
import           Kicad.Uuid
import           Route.Analog
import           Route.Check
import           Route.Extract
import           Route.Geometry  (Layer (..), Outline (..))
import           Route.Router

type Pt = (Double, Double)

-- | Board net name of a design net name (signal nets get KiCad's slash).
resolveNetOf :: Module -> Text -> Text
resolveNetOf m t = fromMaybe ("/" <> t) (M.lookup t netByName)
  where netByName = M.fromList [ (netName n, pcbNetName n) | n <- modNets m ]

-- | Every footprint placed, netted and flipped as it will appear on the board.
placedFootprints :: LibCache -> Module -> SchInfo -> IO [SExpr]
placedFootprints lc m info = do
  let name = modName m
      u s = uuidFor (name <> "/pcb/" <> s)
      pinNet = M.fromList [ ((r, p), pcbNetName n) | n <- modNets m, (r, p) <- netPins n ]
  mapM (\p -> do
          raw <- loadFootprint lc (libNick (partFootprint p)) (libItem (partFootprint p))
          let si = M.lookup (partRef p) (siSymbols info)
          pure (placeFootprint u pinNet (name <> ".kicad_sch") p raw si))
       (modParts m)

-- | The routing problem in board coordinates and board net names: outline,
-- every pad, keep-outs and the hand-drawn traces with their own widths.
routeProblemOf :: Module -> [SExpr] -> RouteProblem
routeProblemOf m fps =
  let bd = modBoard m
      layerOf t = if t == "B.Cu" then B else F
  in RouteProblem
       { rpOutline = Outline (bdWidth bd) (bdHeight bd) (bdCornerRadius bd)
       , rpPads = concatMap padsOfFootprint fps
       , rpKeepouts = concatMap keepoutsOfFootprint fps
       , rpPreRouted = [ (resolveNetOf m (trNet t), layerOf (trLayer t), trWidth t, trPath t) | t <- bdTraces bd ] }

-- | Build the module's routing problem from scratch (schematic pass included,
-- so pad nets are exactly what the board emitter uses). For tests and tools
-- that want to run 'autoroute' outside generation.
routeProblemFor :: LibCache -> Module -> IO RouteProblem
routeProblemFor lc m = do
  (_, info) <- emitSchematic lc m
  fps <- placedFootprints lc m info
  pure (routeProblemOf m fps)

-- | Router settings of an autorouted board: its 'AutoRoute' block plus the
-- board's design rules.
routeConfigFor :: Module -> Maybe RouteConfig
routeConfigFor m = do
  ar <- bdAutoRoute (modBoard m)
  let rules = bdRules (modBoard m)
  pure (defaultRouteConfig (map (resolveNetOf m) (arNets ar)))
         { rcPitch = arPitch ar, rcWidth = arWidth ar
         , rcClearance = drClearance rules, rcEdgeClearance = drEdgeClearance rules
         , rcViaDiameter = arViaDiameter ar, rcViaDrill = arViaDrill ar
         , rcCoupling = couplingSpecFor m }

-- | The board's crosstalk limit, in the router's net names and in SI units,
-- or Nothing when the design does not state one.
--
-- Only nets that are actually being routed are passed on. A quiet net the
-- router does not lay copper for -- hand-drawn, or simply not listed -- is
-- something the router cannot move, so charging it for coupling would price a
-- choice it does not have.
couplingSpecFor :: Module -> Maybe CouplingSpec
couplingSpecFor m = do
  ar <- bdAutoRoute (modBoard m)
  let an = bdAnalog (modBoard m)
      routed = map (resolveNetOf m) (arNets ar)
      keep n = resolveNetOf m n `elem` routed
      quiet = [ (resolveNetOf m n, r) | (n, Quiet r) <- anRoles an, keep n, r > 0 ]
      noisy = [ (resolveNetOf m n, v, tr) | (n, Noisy v tr) <- anRoles an, keep n
              , v > 0, tr > 0 ]
  if anInjectMv an <= 0 || null quiet || null noisy
    then Nothing
    else Just CouplingSpec
      { csQuiet = quiet
      , csNoisy = noisy
      , csLimitV = anInjectMv an / 1000
      , csNodeF = anNodePf an * 1e-12
        -- Decided on the design's names, where the groups are written, and
        -- resolved afterwards; inverting the router's names would be a
        -- lookup that can fail for no good reason.
      , csIgnore = [ (resolveNetOf m qd, resolveNetOf m zd)
                   | (qd, Quiet _) <- anRoles an
                   , (zd, Noisy _ _) <- anRoles an
                   , sameCircuit an qd zd ]
      }

-- | Everything that makes a routing result unusable: a net the router gave
-- up on, copper still contested between nets, a via inside or against a pad
-- (re-checked here on the final geometry, independently of the router),
-- or a net whose copper is not one island. Empty means the board may be
-- written.
routingErrors :: (Text -> Text) -> RouteConfig -> RouteProblem -> RouteResult -> [Text]
routingErrors nameOf cfg prob res =
  [ "could not complete nets: " <> T.intercalate ", " (map nameOf (rrFailed res)) | not (null (rrFailed res)) ]
  ++ [ T.pack (show (rrConflicts res)) <> " contested cells remain" | rrConflicts res > 0 ]
  ++ [ "via/pad violation: " <> describeViaPad v { vpNet = nameOf (vpNet v), vpPadNet = fmap nameOf (vpPadNet v) } | v <- viaPad ]
  ++ [ "net not connected: " <> nameOf n | n <- rrDisconnected res ]
  where
    viaPad = viaPadViolations (rcClearance cfg) (rpPads prob) [ v | rn <- rrNets res, v <- rnVias rn ]

-- | The board text and, when the design is autorouted, the score report.
-- Fails (so pcbgen exits non-zero and writes nothing) when the router's
-- result has any of the 'routingErrors'.
emitPcb :: LibCache -> Module -> SchInfo -> IO (Text, Maybe Text)
emitPcb lc m info = do
  let name = modName m
      u s = uuidFor (name <> "/pcb/" <> s)
      bd = modBoard m
      resolveNet = resolveNetOf m

  fps <- placedFootprints lc m info

  setup <- either (\e -> fail ("internal setup block: " ++ e)) pure (parseSExprs setupBlock)

  -- Autorouting works in board net names ("/MULT_A"); map back to design names
  -- so the emitted traces go through the same path as hand-drawn ones.
  let designName = M.fromList [ (pcbNetName n, netName n) | n <- modNets m ]
      layerName F = "F.Cu"
      layerName B = "B.Cu"
  (autoTraces, autoVias, report) <- case routeConfigFor m of
    Nothing -> pure ([], [], Nothing)
    Just cfg -> do
      let prob = routeProblemOf m fps
          res = autoroute cfg prob
      t0 <- getCPUTime
      _ <- evaluate (rrIterations res)
      t1 <- getCPUTime
      mapM_ (putStrLn . ("autoroute: " ++) . T.unpack) (rrLog res)
      putStrLn ("autoroute: " ++ showFFloat (Just 1) (fromIntegral (t1 - t0) / 1e12 :: Double) " s CPU")
      let toDesign n = fromMaybe n (M.lookup n designName)
          -- The router works in its own net names; the design's analog intent
          -- is written in the design's, so rename the copper before checking
          -- it against the intent.
          dTraces = [ t { rtNet = toDesign (rtNet t) } | rn <- rrNets res, t <- rnTraces rn ]
          dVias = [ v { rvNet = toDesign (rvNet v) } | rn <- rrNets res, v <- rnVias rn ]
          rep = routeReport toDesign res <> analogSection (bdAnalog bd) dTraces dVias
          traces = [ Trace (toDesign (rtNet t)) (layerName (rtLayer t)) (rtWidth t) (rtPath t)
                   | rn <- rrNets res, t <- rnTraces rn ]
          vias = [ (rvNet v, rvAt v, rvDiameter v, rvDrill v) | rn <- rrNets res, v <- rnVias rn ]
          errors = map T.unpack (routingErrors toDesign cfg prob res)
      putStrLn (T.unpack rep)
      unless (null errors) $
        fail (unlines (("autoroute failed for " ++ T.unpack name ++ ":") : map ("  " ++) errors))
      pure (traces, vias, Just rep)

  let outline = boardOutline u bd
      segments = concat [ segmentsFor u resolveNet i t | (i, t) <- zip [0 :: Int ..] (bdTraces bd ++ autoTraces) ]
      viaItems = [ viaFor u i v | (i, v) <- zip [0 :: Int ..] autoVias ]
      zones = [ zoneFor u resolveNet z | z <- bdZones bd ]
      texts = [ textFor u i t | (i, t) <- zip [0 :: Int ..] (bdTexts bd) ]

  let pcb = List $
        [ Atom "kicad_pcb"
        , list "version" [sym "20260206"]
        , list "generator" [Str "pcbgen"]
        , list "generator_version" [Str "10.0"]
        , list "general" [list "thickness" [num 1.6], list "legacy_teardrops" [sym "no"]]
        , list "paper" [Str "A4"]
        , list "title_block" [list "title" [Str (modTitle m)]]
        ] ++ setup ++ fps ++ outline ++ segments ++ viaItems ++ zones ++ texts ++
        [ list "embedded_fonts" [sym "no"] ]
  pure (render pcb, report)

-- | The analog-intent section of the route report, omitted entirely when a
-- design declares no intent. These are findings rather than errors: unlike a
-- routing fault they do not stop the project being written, because they are
-- statements about how well the board serves the circuit and not about
-- whether it can be built.
analogSection :: Analog -> [RTrace] -> [RVia] -> Text
analogSection an traces vias
  | not declared = ""
  | otherwise = T.unlines $
      ["", "## Analog intent", ""]
      ++ (if null findings then ["No findings."]
          else [ "- " <> describeAnalog f | f <- findings ])
      ++ coupling
  where
    declared = not (null (anRoles an)) || not (null (anMaxLength an))
            || not (null (anMatched an))
    findings = analogFindings an traces vias
    preds = couplingPredictions an traces vias
    -- The margins, not only the failures: a limit that passes with room to
    -- spare and one that passes by a hair are different facts about the
    -- board, and only one of them survives the next layout change.
    coupling
      | null preds = []
      | otherwise =
          [ "", "Coupling predicted from the copper, limit "
                <> T.pack (showFFloat (Just 2) (anInjectMv an) " mV") <> ":", ""
          , "| quiet net | noisy net | coupled pF | injected mV |"
          , "|---|---|--:|--:|" ]
          ++ [ T.concat [ "| ", q, " | ", z, " | "
                        , T.pack (showFFloat (Just 4) cm ""), " | "
                        , T.pack (showFFloat (Just 3) mv ""), " |" ]
             | (q, z, cm, mv) <- preds ]

-- Footprints -----------------------------------------------------------------

placeFootprint :: (Text -> Text) -> M.Map (Text, Text) Text -> Text -> Part -> SExpr -> Maybe SymInfo -> SExpr
placeFootprint u pinNet sheetFile p raw si =
  let ref = partRef p
      (x, y) = partAt p
      rot = partRot p
      side = partSide p
      layerName = if side == Back then "B.Cu" else "F.Cu"
      fpId = libNick (partFootprint p) <> ":" <> libItem (partFootprint p)
      (List (hd : Str fpName : kids0)) = raw
      -- library properties and children, before placement transforms
      kids1 = filter (\c -> headSym c `notElem` [Just "layer", Just "uuid", Just "at", Just "path", Just "sheetname", Just "sheetfile"]) kids0
      desc = maybe "" symDescription si
      pinNames = maybe [] symPinNames si
      uKey k = u (ref <> "/" <> k)

      setProps = ensureProps $
        [ ("Reference", partRef p, not (partRefOnSilk p), "F.SilkS")
        , ("Value", partValue p, False, "F.Fab")
        , ("Footprint", fpId, True, "F.Fab")
        , ("Datasheet", fromMaybe "" (lookup "Datasheet" (partFields p)), True, "F.Fab")
        , ("Description", desc, True, "F.Fab")
        ] ++ [ (k, v, True, "F.Fab") | (k, v) <- partFields p, k /= "Datasheet" ]

      kids2 = markAssembly (setProps kids1)
      kids3 = map (netPad pinNet ref pinNames) kids2
      -- Placement attributes follow the part's declared assembly class, never
      -- the presence of a sourcing field. Anything not factory-placed stays
      -- out of the position file, so KiKit leaves it out of the assembly BOM
      -- as well; DNP and mechanical items leave the BOM too. KiCad's
      -- library-mismatch check ignores these per-instance flags.
      extraAttrs = case partAssembly p of
        Factory    -> []
        Hand       -> ["exclude_from_pos_files"]
        DNP        -> ["exclude_from_pos_files", "exclude_from_bom", "dnp"]
        Mechanical -> ["exclude_from_pos_files", "exclude_from_bom"]
      markAssembly kids
        | null extraAttrs = kids
        | any ((== Just "attr") . headSym) kids = map addAttrs kids
        | otherwise = kids ++ [list "attr" (sym "through_hole" : map sym extraAttrs)]
      addAttrs (List (Atom "attr" : flags)) =
        List (Atom "attr" : flags ++ [ sym a | a <- extraAttrs, Atom a `notElem` flags ])
      addAttrs e = e
      -- Flip first, then rotate: KiCad stores a back-side pad's angle as the
      -- footprint rotation minus the library angle, so the mirror must be
      -- applied to the library angle alone.
      kids4 = if side == Back then map flipChild kids3 else kids3
      kids5 = map (rotateChild rot) kids4
      kids5' = map (absolutizeZone rot (x, y)) kids5
      kids6 = zipWith (addUuid uKey) [0 :: Int ..] kids5'
      atE = list "at" ([num x, num y] ++ [ num rot | rot /= 0 ])
      pathE = list "path" [Str ("/" <> maybe "" symUuid si)]
      sheetE = [list "sheetname" [Str "/"], list "sheetfile" [Str (sheetFile)]]
  in List (hd : Str fpName : list "layer" [Str layerName] : list "uuid" [Str (uKey "fp")] : atE : pathE : sheetE ++ kids6)

-- | Set the standard property values, creating any the library lacks.
ensureProps :: [(Text, Text, Bool, Text)] -> [SExpr] -> [SExpr]
ensureProps specs kids =
  let existing = [ n | c <- kids, Just n <- [propName c] ]
      updated = map upd kids
      missing = [ mk n v hidden layer | (n, v, hidden, layer) <- specs, n `notElem` existing ]
      -- Put new properties right after the last existing property for tidiness.
      lastProp = length updated - length (takeWhile (\c -> headSym c /= Just "property") (reverse updated))
      (before, after) = splitAt lastProp updated
  in before ++ missing ++ after
  where
    upd c@(List (Atom "property" : Str n : _ : rest)) =
      case [ (v, h) | (n', v, h, _) <- specs, n' == n ] of
        ((v, h) : _) -> List (Atom "property" : Str n : Str v : setHidden h rest)
        []           -> c
    upd c = c

    setHidden h rest =
      let noHide = filter (\c -> headSym c /= Just "hide") rest
      in if h then insertAfterAt (list "hide" [sym "yes"]) noHide else noHide

    insertAfterAt e xs = case break (\c -> headSym c == Just "layer") xs of
      (a, l : b) -> a ++ [l, e] ++ b
      (a, [])    -> a ++ [e]

    mk n v hidden layer = List $
      [ Atom "property", Str n, Str v, list "at" [num 0, num 0, num 0], list "layer" [Str layer] ]
      ++ [ list "hide" [sym "yes"] | hidden ]
      ++ [ list "effects" [list "font" [list "size" [num 1, num 1], list "thickness" [num 0.15]]] ]

propName :: SExpr -> Maybe Text
propName (List (Atom "property" : Str n : _)) = Just n
propName _                                    = Nothing

-- | Attach the net to a pad. Pads in no net get KiCad's unconnected name so
-- the schematic parity check is satisfied.
netPad :: M.Map (Text, Text) Text -> Text -> [(Text, Text)] -> SExpr -> SExpr
-- Unnumbered pads (mounting lugs, pegs) belong to no net at all; giving them
-- a shared "unconnected" name would make KiCad demand a connection between them.
netPad _ _ _ e@(List (Atom "pad" : Str "" : _)) = e
netPad pinNet ref pinNames (List (Atom "pad" : Str padNum : rest)) =
  let net = case M.lookup (ref, padNum) pinNet of
        Just n  -> n
        Nothing ->
          let nm = fromMaybe "" (lookup padNum pinNames)
          in if T.null nm || nm == "~"
               then "unconnected-(" <> ref <> "-Pad" <> padNum <> ")"
               else "unconnected-(" <> ref <> "-" <> nm <> "-Pad" <> padNum <> ")"
      rest' = filter (\c -> headSym c /= Just "net") rest
  in List (Atom "pad" : Str padNum : rest' ++ [list "net" [Str net]])
netPad _ _ _ e = e

-- | Footprint children are stored in the footprint's local frame, but pad and
-- text angles are absolute, so the footprint rotation is added to them.
rotateChild :: Double -> SExpr -> SExpr
rotateChild 0 e = e
rotateChild rot e = case e of
  List (Atom h : rest) | h `elem` ["pad", "property", "fp_text"] ->
    List (Atom h : map bumpAt rest)
  _ -> e
  where
    bumpAt (List [Atom "at", ax, ay])     = list "at" [ax, ay, num rot]
    bumpAt (List [Atom "at", ax, ay, aa]) = list "at" [ax, ay, num (readNum aa + rot)]
    bumpAt c                              = c

-- | Mirror a footprint child to the back side the way KiCad's flip does:
-- layers swap front/back, local y is negated, angles are negated, text is
-- marked mirrored. 3D models are left alone.
flipChild :: SExpr -> SExpr
flipChild e@(List (Atom "model" : _)) = e
flipChild e = go True e
  where
    go top (List (Atom h : rest))
      | h == "layer"  = List (Atom h : map swapLayer rest)
      | h == "layers" = List (Atom h : map swapLayer rest)
      | h `elem` ["start", "end", "mid", "center", "xy"] = negY (List (Atom h : rest))
      | h == "at"     = negAt (List (Atom h : rest))
      | h == "effects" = List (Atom h : map (go False) (addMirror rest))
      | otherwise     = List (Atom h : map (go False) rest)
      where _ = top
    go _ x = x

    swapLayer (Str l) = Str (swapName l)
    swapLayer x       = x
    swapName l
      | Just r <- T.stripPrefix "F." l = "B." <> r
      | Just r <- T.stripPrefix "B." l = "F." <> r
      | otherwise = l

    negY (List [Atom h, ax, ay]) = list h [ax, num (negate (readNum ay))]
    negY x = x

    negAt (List [Atom "at", ax, ay])     = list "at" [ax, num (negate (readNum ay))]
    negAt (List [Atom "at", ax, ay, aa]) = list "at" [ax, num (negate (readNum ay)), num (negate (readNum aa))]
    negAt x = x

    addMirror rest = case break (\c -> headSym c == Just "justify") rest of
      (a, List (Atom "justify" : js) : b) -> a ++ [List (Atom "justify" : js ++ [sym "mirror"])] ++ b
      _ -> rest ++ [list "justify" [sym "mirror"]]

-- | Unlike every other footprint child, a zone inside a footprint (keepouts
-- under connector bodies, for instance) is stored in absolute board
-- coordinates. Rotate the library polygon by the footprint rotation and
-- translate it to the footprint position.
absolutizeZone :: Double -> Pt -> SExpr -> SExpr
absolutizeZone rot (x0, y0) (List (Atom "zone" : rest)) = List (Atom "zone" : map go rest)
  where
    go (List (Atom h : xs)) | h `elem` ["polygon", "filled_polygon"] = List (Atom h : map go xs)
    go (List (Atom "pts" : xs)) = List (Atom "pts" : map xy xs)
    go c = c
    xy (List [Atom "xy", ax, ay]) =
      let (rx, ry) = rotBoard rot (readNum ax, readNum ay)
      in list "xy" [num (x0 + rx), num (y0 + ry)]
    xy c = c
absolutizeZone _ _ e = e

-- | KiCad board rotation: positive angles turn counter-clockwise on screen,
-- where y points down.
rotBoard :: Double -> Pt -> Pt
rotBoard 0 p = p
rotBoard a (x, y) =
  let r = a * pi / 180
  in (x * cos r + y * sin r, -x * sin r + y * cos r)

-- | Give every child that KiCad expects to carry a uuid one, deterministically.
addUuid :: (Text -> Text) -> Int -> SExpr -> SExpr
addUuid u i e@(List (Atom h : rest))
  | h `elem` needs && isNothing (findChild "uuid" e) =
      List (Atom h : rest ++ [list "uuid" [Str (u (h <> "/" <> T.pack (show i)))]])
  where
    needs = ["pad", "property", "fp_line", "fp_arc", "fp_circle", "fp_rect", "fp_poly", "fp_text", "zone"]
addUuid _ _ e = e

readNum :: SExpr -> Double
readNum e = case atomText e of
  Just t -> case reads (T.unpack (fixup t)) of
    [(d, "")] -> d
    _         -> 0
  Nothing -> 0
  where
    fixup t
      | Just r <- T.stripPrefix "-." t = "-0." <> r
      | Just r <- T.stripPrefix "." t  = "0." <> r
      | otherwise                      = t

-- Board items ----------------------------------------------------------------

boardOutline :: (Text -> Text) -> Board -> [SExpr]
boardOutline u bd =
  let w = bdWidth bd; h = bdHeight bd; r = bdCornerRadius bd
      k = r - r / sqrt 2
      stroke = list "stroke" [list "width" [num 0.05], list "type" [sym "default"]]
      edge = list "layer" [Str "Edge.Cuts"]
      line i (x1, y1) (x2, y2) = List [Atom "gr_line", list "start" [num x1, num y1], list "end" [num x2, num y2], stroke, edge, list "uuid" [Str (u ("edge/line/" <> T.pack (show (i :: Int))))]]
      arc i (x1, y1) (mx, my) (x2, y2) = List [Atom "gr_arc", list "start" [num x1, num y1], list "mid" [num mx, num my], list "end" [num x2, num y2], stroke, edge, list "uuid" [Str (u ("edge/arc/" <> T.pack (show (i :: Int))))]]
  in if r <= 0
       then [ line 0 (0, 0) (w, 0), line 1 (w, 0) (w, h), line 2 (w, h) (0, h), line 3 (0, h) (0, 0) ]
       else [ line 0 (r, 0) (w - r, 0)
            , line 1 (w, r) (w, h - r)
            , line 2 (w - r, h) (r, h)
            , line 3 (0, h - r) (0, r)
            , arc 0 (0, r) (k, k) (r, 0)
            , arc 1 (w - r, 0) (w - k, k) (w, r)
            , arc 2 (w, h - r) (w - k, h - k) (w - r, h)
            , arc 3 (r, h) (k, h - k) (0, h - r)
            ]

segmentsFor :: (Text -> Text) -> (Text -> Text) -> Int -> Trace -> [SExpr]
segmentsFor u resolveNet i t =
  [ List [ Atom "segment"
         , list "start" [num x1, num y1], list "end" [num x2, num y2]
         , list "width" [num (trWidth t)]
         , list "layer" [Str (trLayer t)]
         , list "net" [Str (resolveNet (trNet t))]
         , list "uuid" [Str (u ("seg/" <> T.pack (show i) <> "/" <> T.pack (show j)))] ]
  | (j, ((x1, y1), (x2, y2))) <- zip [0 :: Int ..] (zip (trPath t) (drop 1 (trPath t))) ]

viaFor :: (Text -> Text) -> Int -> (Text, (Double, Double), Double, Double) -> SExpr
viaFor u i (net, (x, y), d, drill) =
  List [ Atom "via"
       , list "at" [num x, num y]
       , list "size" [num d]
       , list "drill" [num drill]
       , list "layers" [Str "F.Cu", Str "B.Cu"]
       , list "net" [Str net]
       , list "uuid" [Str (u ("via/" <> T.pack (show i)))] ]

zoneFor :: (Text -> Text) -> (Text -> Text) -> Zone -> SExpr
zoneFor u resolveNet z =
  List [ Atom "zone"
       , list "net" [Str (resolveNet (znNet z))]
       , list "layer" [Str (znLayer z)]
       , list "uuid" [Str (u ("zone/" <> znName z))]
       , list "name" [Str (znName z)]
       , list "hatch" [sym "edge", num 0.5]
       , list "connect_pads" (padConnectAtom (znConnect z) ++ [list "clearance" [num (znClearance z)]])
       , list "min_thickness" [num (znMinWidth z)]
       , list "filled_areas_thickness" [sym "no"]
       , list "fill" [sym "yes", list "thermal_gap" [num 0.5], list "thermal_bridge_width" [num 0.5]]
       , list "polygon" [list "pts" [ list "xy" [num x, num y] | (x, y) <- znPoly z ]]
       ]

textFor :: (Text -> Text) -> Int -> BoardText -> SExpr
textFor u i t =
  let (x, y) = btAt t
      back = "B." `T.isPrefixOf` btLayer t
  in List $
       [ Atom "gr_text", Str (btText t)
       , list "at" [num x, num y, num (btRot t)]
       , list "layer" [Str (btLayer t)]
       , list "uuid" [Str (u ("text/" <> T.pack (show i)))]
       , list "effects" ([list "font" [list "size" [num (btSize t), num (btSize t)], list "thickness" [num (max 0.1 (btSize t * 0.15))]]]
                         ++ [ list "justify" [sym "mirror"] | back ]) ]

_unused :: ()
_unused = const () (isJust (Nothing :: Maybe ()))

-- | Layer stack and plot settings as KiCad 10 writes them for a fresh
-- two-layer board.
setupBlock :: Text
setupBlock = T.unlines
  [ "(layers"
  , "  (0 \"F.Cu\" signal) (2 \"B.Cu\" signal)"
  , "  (9 \"F.Adhes\" user \"F.Adhesive\") (11 \"B.Adhes\" user \"B.Adhesive\")"
  , "  (13 \"F.Paste\" user) (15 \"B.Paste\" user)"
  , "  (5 \"F.SilkS\" user \"F.Silkscreen\") (7 \"B.SilkS\" user \"B.Silkscreen\")"
  , "  (1 \"F.Mask\" user) (3 \"B.Mask\" user)"
  , "  (17 \"Dwgs.User\" user \"User.Drawings\") (19 \"Cmts.User\" user \"User.Comments\")"
  , "  (25 \"Edge.Cuts\" user) (27 \"Margin\" user)"
  , "  (31 \"F.CrtYd\" user \"F.Courtyard\") (29 \"B.CrtYd\" user \"B.Courtyard\")"
  , "  (35 \"F.Fab\" user) (33 \"B.Fab\" user))"
  , "(setup"
  , "  (pad_to_mask_clearance 0.05)"
  , "  (allow_soldermask_bridges_in_footprints no)"
  , "  (tenting (front yes) (back yes))"
  , "  (covering (front no) (back no))"
  , "  (plugging (front no) (back no))"
  , "  (capping no) (filling no)"
  , "  (pcbplotparams"
  , "    (layerselection 0x00000000_00000000_55555555_5755f5ff)"
  , "    (plot_on_all_layers_selection 0x00000000_00000000_00000000_00000000)"
  , "    (disableapertmacros no) (usegerberextensions no) (usegerberattributes yes)"
  , "    (usegerberadvancedattributes yes) (creategerberjobfile yes)"
  , "    (dashed_line_dash_ratio 12) (dashed_line_gap_ratio 3) (svgprecision 4)"
  , "    (plotframeref no) (mode 1) (useauxorigin no)"
  , "    (pdf_front_fp_property_popups yes) (pdf_back_fp_property_popups yes)"
  , "    (pdf_metadata yes) (pdf_single_document no)"
  , "    (dxfpolygonmode yes) (dxfimperialunits yes) (dxfusepcbnewfont yes)"
  , "    (psnegative no) (psa4output no) (plot_black_and_white yes)"
  , "    (sketchpadsonfab no) (plotpadnumbers no) (hidednponfab no) (sketchdnponfab yes)"
  , "    (crossoutdnponfab yes) (subtractmaskfromsilk no) (outputformat 1) (mirror no)"
  , "    (drillshape 1) (scaleselection 1) (outputdirectory \"\")))"
  ]

-- | KiCad writes the pad-connection mode as a bare atom before the clearance:
-- absent means thermal reliefs, @yes@ a solid fill, @no@ no pad bond at all.
padConnectAtom :: PadConnect -> [SExpr]
padConnectAtom ThermalRelief = []
padConnectAtom SolidFill     = [sym "yes"]
padConnectAtom PadsUnbonded  = [sym "no"]
