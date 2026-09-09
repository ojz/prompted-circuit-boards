{-# LANGUAGE OverloadedStrings #-}
-- | Design validation: reject a 'Module' whose intent is incomplete or
-- contradictory before any KiCad file is written.
--
-- The emitters are permissive by construction: a pin that is on no net gets
-- a no-connect flag, a mistyped pin number is simply never wired, and ERC
-- then passes on a schematic that does not say what the designer meant.
-- This module makes those cases fail instead. It checks the design against
-- the real library symbols (every pin across all units), so a diagnostic
-- can name the reference, the pin and the pins that do exist.
--
-- An empty result means the design is valid. Nothing here judges whether
-- the circuit is any good; it only checks that the description is complete
-- and self-consistent.
module Validate
  ( Diagnostic (..)
  , formatDiagnostic
  , validateModule
  , validateStructure
  ) where

import           Control.Exception (SomeException, displayException, try)
import           Control.Monad     (forM)
import           Data.List         (nub, sort)
import qualified Data.Map.Strict   as M
import           Data.Maybe        (mapMaybe)
import           Data.Text         (Text)
import qualified Data.Text         as T

import           Design
import           Kicad.Library
import           Kicad.SExpr       (SExpr)

-- | One reason a design is invalid.
data Diagnostic = Diagnostic
  { diagCode    :: Text   -- ^ stable kind, e.g. @unassigned-pin@
  , diagSubject :: Text   -- ^ what it is about: @U1@, @U1.8@, @+12V@, @bdWidth@
  , diagMessage :: Text   -- ^ human-readable explanation
  } deriving (Eq, Show)

formatDiagnostic :: Diagnostic -> Text
formatDiagnostic d = "[" <> diagCode d <> "] " <> diagSubject d <> ": " <> diagMessage d

-- | What is known about each part's symbol: its pins, or why it failed to load.
type SymbolPins = M.Map Text (Either Text [PinDef])

-- | Validate a design against the KiCad libraries. Symbol lookups that fail
-- become diagnostics rather than exceptions.
validateModule :: LibCache -> Module -> IO [Diagnostic]
validateModule lc m = do
  let parts = modParts m
  loaded <- forM (firstByRef parts) $ \p -> do
    r <- tryLoad (loadSymbol lc (libNick (partSymbol p)) (libItem (partSymbol p)))
    pure (partRef p, fmap symbolPins r)
  let syms = M.fromList loaded
      symbolDiags =
        [ Diagnostic "symbol-not-found" (partRef p) (libText (partSymbol p) <> " could not be loaded: " <> err)
        | p <- firstByRef parts, Just (Left err) <- [M.lookup (partRef p) syms] ]
  powerDiags <- fmap concat $ forM [ n | n <- modNets m, netKind n == Power ] $ \n -> do
    r <- tryLoad (loadSymbol lc "power" (netName n))
    pure $ case r of
      Left err -> [ Diagnostic "unknown-power-symbol" (netName n)
                      ("power net " <> netName n <> " has no symbol power:" <> netName n <> " (" <> err <> ")") ]
      Right s | not (isPowerSymbol s) ->
                  [ Diagnostic "unknown-power-symbol" (netName n)
                      ("power:" <> netName n <> " exists but is not a power symbol") ]
      Right _ -> []
  pure (validateStructure m ++ symbolDiags ++ validatePins m syms ++ powerDiags)
  where
    tryLoad :: IO SExpr -> IO (Either Text SExpr)
    tryLoad act = do
      r <- try act
      pure (either (\e -> Left (T.pack (displayException (e :: SomeException)))) Right r)

-- | The checks that need no library: names, assembly intent, numbers.
validateStructure :: Module -> [Diagnostic]
validateStructure m =
  concat
    [ [ Diagnostic "duplicate-reference" r ("reference " <> r <> " is used by " <> tshow k <> " parts")
      | (r, k) <- counts (map partRef (modParts m)), k > 1 ]
    , [ Diagnostic "empty-reference" (partValue p) ("a part (value " <> partValue p <> ") has an empty reference")
      | p <- modParts m, T.null (T.strip (partRef p)) ]
    , [ Diagnostic "duplicate-net" n ("net " <> n <> " is declared " <> tshow k <> " times")
      | (n, k) <- counts (map netName (modNets m)), k > 1 ]
    , [ Diagnostic "empty-net-name" "" "a net has an empty name" | n <- modNets m, T.null (T.strip (netName n)) ]
    , concatMap assemblyDiags (modParts m)
    , boardDiags (modBoard m) (map netName (modNets m))
    ]

-- | Assembly class and sourcing field must agree, in both directions, so a
-- missing LCSC number can never silently turn a factory part into a
-- hand-soldered one and a stray number cannot hide a part that was meant to
-- be placed.
assemblyDiags :: Part -> [Diagnostic]
assemblyDiags p =
  case (partAssembly p, lcsc) of
    (Factory, Nothing) ->
      [ Diagnostic "factory-without-lcsc" (partRef p)
          (partRef p <> " is Factory assembled but has no LCSC Part # field") ]
    (asm, Just code) | asm /= Factory ->
      [ Diagnostic "lcsc-on-non-factory" (partRef p)
          (partRef p <> " is " <> tshow asm <> " but carries LCSC Part # " <> code
           <> "; make it Factory or drop the field") ]
    _ -> []
  where
    lcsc = case lookup "LCSC Part #" (partFields p) of
      Just c | not (T.null (T.strip c)) -> Just c
      _                                 -> Nothing

boardDiags :: Board -> [Text] -> [Diagnostic]
boardDiags b netNames =
  concat
    [ positive "bad-dimension" "bdWidth" (bdWidth b)
    , positive "bad-dimension" "bdHeight" (bdHeight b)
    , nonNegative "bad-dimension" "bdCornerRadius" (bdCornerRadius b)
    , positive "bad-rule" "drClearance" (drClearance r)
    , positive "bad-rule" "drTrackWidth" (drTrackWidth r)
    , positive "bad-rule" "drViaDiameter" (drViaDiameter r)
    , positive "bad-rule" "drViaDrill" (drViaDrill r)
    , positive "bad-rule" "drHoleToHole" (drHoleToHole r)
    , positive "bad-rule" "drEdgeClearance" (drEdgeClearance r)
    , [ Diagnostic "bad-rule" "drViaDrill" ("drViaDrill " <> tshow (drViaDrill r) <> " must be smaller than drViaDiameter " <> tshow (drViaDiameter r))
      | drViaDrill r > 0, drViaDiameter r > 0, drViaDrill r >= drViaDiameter r ]
    , case bdAutoRoute b of
        Nothing -> []
        Just ar -> concat
          [ positive "bad-autoroute" "arPitch" (arPitch ar)
          , positive "bad-autoroute" "arWidth" (arWidth ar)
          , positive "bad-autoroute" "arViaDiameter" (arViaDiameter ar)
          , positive "bad-autoroute" "arViaDrill" (arViaDrill ar)
          , [ Diagnostic "bad-autoroute" "arViaDrill" ("arViaDrill " <> tshow (arViaDrill ar) <> " must be smaller than arViaDiameter " <> tshow (arViaDiameter ar))
            | arViaDrill ar > 0, arViaDiameter ar > 0, arViaDrill ar >= arViaDiameter ar ]
          , [ Diagnostic "unknown-net" n ("autoroute lists net " <> n <> ", which is not in modNets") | n <- arNets ar, n `notElem` netNames ]
          , [ Diagnostic "duplicate-net" n ("autoroute lists net " <> n <> " " <> tshow k <> " times") | (n, k) <- counts (arNets ar), k > 1 ]
          ]
    , concat
        [ [ Diagnostic "unknown-net" (trNet t) ("trace on " <> trLayer t <> " refers to net " <> trNet t <> ", which is not in modNets") | trNet t `notElem` netNames ]
          ++ [ Diagnostic "bad-trace" (trNet t) ("trace on " <> trLayer t <> " for net " <> trNet t <> " has fewer than two points") | length (trPath t) < 2 ]
          ++ positive "bad-trace" (trNet t <> " trWidth") (trWidth t)
        | t <- bdTraces b ]
    , concat
        [ [ Diagnostic "unknown-net" (znNet z) ("zone " <> znName z <> " refers to net " <> znNet z <> ", which is not in modNets") | znNet z `notElem` netNames ]
          ++ [ Diagnostic "bad-zone" (znName z) ("zone " <> znName z <> " has fewer than three corners") | length (znPoly z) < 3 ]
          -- A pour that does not bond to its pads is only safe when the net
          -- is routed as copper as well; otherwise it is the pour that was
          -- holding the net together and unbonding it strands every pad.
          ++ [ Diagnostic "unbonded-pour-unrouted-net" (znName z)
                 ("zone " <> znName z <> " does not bond to pads (PadsUnbonded) but net "
                  <> znNet z <> " is not autorouted, so nothing else connects it")
             | znConnect z == PadsUnbonded, znNet z `notElem` routedNets ]
        | z <- bdZones b ]
    ]
  where
    r = bdRules b
    -- Nets the router will lay copper for; hand-drawn traces count too.
    routedNets = maybe [] arNets (bdAutoRoute b) ++ map trNet (bdTraces b)
    positive code name v = [ Diagnostic code name (name <> " must be > 0, is " <> tshow v) | not (v > 0) ]
    nonNegative code name v = [ Diagnostic code name (name <> " must be >= 0, is " <> tshow v) | not (v >= 0) ]

-- | Every (reference, pin) a net names must exist; every pin a symbol has
-- must be on exactly one net or declared a no-connect, never both.
validatePins :: Module -> SymbolPins -> [Diagnostic]
validatePins m syms =
  concat [ referenceDiags, multiNetDiags, noConnectDiags, unassignedDiags ]
  where
    parts = firstByRef (modParts m)
    partByRef = M.fromList [ (partRef p, p) | p <- parts ]
    -- Only parts whose symbol loaded take part in pin checks; the failed
    -- load already produced its own diagnostic.
    pinsOf ref = case M.lookup ref syms of
      Just (Right ds) -> Just ds
      _               -> Nothing
    pinNumbersOf ref = fmap (nub . map pinNumber) (pinsOf ref)
    assignments = [ (r, p, netName n) | n <- modNets m, (r, p) <- netPins n ]
    -- (ref, pin) -> nets that list it, in declaration order
    byPin = M.fromListWith (flip (++)) [ ((r, p), [n]) | (r, p, n) <- assignments ]

    referenceDiags = concat
      [ case M.lookup r partByRef of
          Nothing -> [ Diagnostic "unknown-reference" r
                         ("net " <> n <> " lists pin " <> p <> " of " <> r <> ", which is not a part of this design") ]
          Just prt -> case pinNumbersOf r of
            Just nums | p `notElem` nums ->
              [ Diagnostic "unknown-pin" (r <> "." <> p)
                  (r <> " pin " <> p <> " does not exist on symbol " <> libText (partSymbol prt)
                   <> " (pins: " <> T.intercalate ", " nums <> "); listed in net " <> n) ]
            _ -> []
      | (r, p, n) <- nub assignments ]

    multiNetDiags = concat
      [ [ Diagnostic "pin-on-multiple-nets" (r <> "." <> p)
            (r <> " pin " <> p <> " is on more than one net: " <> T.intercalate ", " distinct)
        | length distinct > 1 ]
        ++ [ Diagnostic "duplicate-pin-in-net" (r <> "." <> p)
               (r <> " pin " <> p <> " is listed " <> tshow k <> " times in net " <> n)
           | (n, k) <- counts ns, k > 1 ]
      | ((r, p), ns) <- M.toList byPin, let distinct = nub ns ]

    noConnectDiags = concat
      [ case pinNumbersOf (partRef prt) of
          Just nums | nc `notElem` nums ->
            [ Diagnostic "no-connect-unknown-pin" (partRef prt <> "." <> nc)
                (partRef prt <> " declares no-connect pin " <> nc <> ", which does not exist on symbol "
                 <> libText (partSymbol prt) <> " (pins: " <> T.intercalate ", " nums <> ")") ]
          _ -> []
        ++ [ Diagnostic "no-connect-on-net" (partRef prt <> "." <> nc)
               (partRef prt <> " pin " <> nc <> " is declared no-connect but is on net "
                <> T.intercalate ", " (nub ns) <> "; drop one of the two")
           | Just ns <- [M.lookup (partRef prt, nc) byPin] ]
      | prt <- parts, nc <- nub (partNoConnect prt) ]
      ++ [ Diagnostic "duplicate-no-connect" (partRef prt <> "." <> nc)
             (partRef prt <> " declares no-connect pin " <> nc <> " " <> tshow k <> " times")
         | prt <- parts, (nc, k) <- counts (partNoConnect prt), k > 1 ]

    -- Pins the symbol itself marks as no-connect (pin type no_connect) need
    -- no declaration: the library already says they are not to be wired.
    unassignedDiags =
      [ Diagnostic "unassigned-pin" (partRef prt <> "." <> pinNumber d)
          (partRef prt <> " pin " <> pinNumber d <> nameText d <> " is neither on a net nor in partNoConnect")
      | prt <- parts
      , Just ds <- [pinsOf (partRef prt)]
      , d <- dedupeBy pinNumber ds
      , not (T.null (pinNumber d))
      , pinType d /= "no_connect"
      , not (M.member (partRef prt, pinNumber d) byPin)
      , pinNumber d `notElem` partNoConnect prt ]
    nameText d
      | T.null (pinName d) || pinName d == "~" = ""
      | otherwise = " (" <> pinName d <> ")"

-- Helpers ----------------------------------------------------------------------

-- | Parts in declaration order, keeping the first of any duplicated reference
-- so pin checks do not repeat what 'duplicate-reference' already says.
firstByRef :: [Part] -> [Part]
firstByRef = go []
  where
    go _ [] = []
    go seen (p : ps)
      | partRef p `elem` seen = go seen ps
      | otherwise             = p : go (partRef p : seen) ps

dedupeBy :: Eq b => (a -> b) -> [a] -> [a]
dedupeBy f = go []
  where
    go _ [] = []
    go seen (x : xs)
      | f x `elem` seen = go seen xs
      | otherwise       = x : go (f x : seen) xs

-- | Occurrence count of each distinct value, in first-seen order.
counts :: Ord a => [a] -> [(a, Int)]
counts xs = mapMaybe (\x -> lookup x tally >>= \k -> Just (x, k)) (nub xs)
  where
    tally = [ (head g, length g) | g <- groupSorted (sort xs) ]
    groupSorted [] = []
    groupSorted (y : ys) = let (same, rest) = span (== y) ys in (y : same) : groupSorted rest

libText :: LibId -> Text
libText l = libNick l <> ":" <> libItem l

tshow :: Show a => a -> Text
tshow = T.pack . show
