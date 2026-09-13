{-# LANGUAGE OverloadedStrings #-}
-- | A SPICE netlist for a design, generated from the same 'Module' the board
-- is generated from.
--
-- The point of generating it rather than writing it is that a hand-written
-- deck can quietly describe a different circuit than the one being
-- fabricated, and then every simulation result is about a circuit nobody is
-- building. Here the topology comes from 'modNets' and the component values
-- from 'partValue', so the netlist cannot drift from the board without the
-- design changing first.
--
-- What is *not* generated is the experiment. Which node is driven, what is
-- swept, what counts as a pass: those are hand-written per module in
-- @modules\/<name>\/sim\/@ and @.include@ this file. A generated experiment
-- would only ever assert what the generator already assumed.
--
-- Two knobs are left as SPICE parameters, because they are properties of how
-- a module is being used rather than of the board:
--
--   * @k_<ref>@, a potentiometer's rotation, 0 to 1.
--   * @norm_<ref>@, a switched jack's normalling contact, in ohms: small when
--     nothing is patched, enormous when something is.
--
-- One probe is generated, because a deck cannot add it afterwards: every
-- op-amp unit's output goes through a 0 V source @V<ref>_o<pin>@ before it
-- reaches its net. At DC and in the time domain it is a wire. In an AC deck
-- it is the injection point for a loop-gain measurement (Middlebrook's
-- voltage injection: @alter v<ref>_o<pin> ac = 1@, then the loop gain is
-- @-V(<ref>_o<pin>) / V(<net>)@), which is how the phase margin of a stage is
-- measured on the circuit that is actually being built instead of on a copy
-- of it written into the deck. It is also a current probe for the output.
--
-- Limits worth stating before anyone quotes a number from this. Component
-- values are nominal, with no tolerance unless a deck sweeps them. Parasitics
-- are absent: no pad capacitance, no trace resistance, nothing from
-- "Route.Coupling". Models are only as good as what is in
-- @modules\/_models\/@, and the device models there are named with their
-- provenance for exactly that reason.
module Emit.Spice
  ( emitSpice
  , SpiceProblem (..)
  , spiceProblems
  ) where

import           Data.Char   (isDigit, toLower)
import           Data.Text   (Text)
import qualified Data.Text   as T

import           Design

-- | A part the netlist generator does not know how to model.
data SpiceProblem = SpiceProblem
  { spRef     :: Text
  , spMessage :: Text
  } deriving (Eq, Show)

-- | Everything in a design that cannot be turned into a SPICE element.
--
-- Reported rather than guessed at: a part silently left out of a netlist is
-- a circuit that simulates beautifully and is not the one on the board.
spiceProblems :: Module -> [SpiceProblem]
spiceProblems m =
  [ SpiceProblem (partRef p) msg
  | p <- modParts m
  , Left msg <- [elementFor m p] ]
  ++ nodeCollisions m

-- | Two net names that would become the same SPICE node.
--
-- Not hypothetical: @+12V@ and @-12V@ both scrubbed to @_12V@, so the supply
-- rails were shorted and the op-amp had V+ and V- on one net, in a netlist
-- that read perfectly well. A generated artefact that can quietly mean
-- something else than the design has to be able to refuse.
nodeCollisions :: Module -> [SpiceProblem]
nodeCollisions m =
  [ SpiceProblem (T.intercalate " and " group)
      ("these nets both become SPICE node '" <> node <> "'")
  | node <- distinct (map (spiceNode . netName) (modNets m))
  , let group = [ n | n <- map netName (modNets m), spiceNode n == node ]
  , length group > 1 ]
  where
    distinct = foldr (\x acc -> x : filter (/= x) acc) []

-- | The netlist. Nodes are net names; GND becomes SPICE's node 0.
emitSpice :: Module -> Text
emitSpice m = T.unlines $
  [ "* " <> modTitle m
  , "* Generated from " <> modName m <> " by pcbgen. Do not edit."
  , "*"
  , "* Nodes are the design's net names. GND is node 0."
  , "* Parameters this netlist expects a deck to set:"
  ] ++ paramDoc ++
  [ "*"
  , ".param " <> T.unwords defaults
  ] ++
  concat [ either (const []) id (elementFor m p) | p <- modParts m ]
  where
    paramDoc =
      [ "*   " <> n <> " = " <> d <> "   " <> why | (n, d, why) <- params ] ++
      [ "*   (none)" | null params ]
    defaults = [ n <> "=" <> d | (n, d, _) <- params ]
    params :: [(Text, Text, Text)]
    params = concatMap paramsFor (modParts m)

    paramsFor p = case symbolKind p of
      Pot  -> [ ("k_" <> partRef p, "0.5", "rotation, 0 to 1") ]
      Jack -> [ ("norm_" <> partRef p, "1m", "normalling contact, ohms") ]
      _    -> []

-- | What a symbol means electrically. Driven by the library identity rather
-- than by the reference letter, because a reference is a label and a symbol
-- is a commitment about pins.
data Kind = Res | Cap | Diode | Pot | Jack | OpAmp | VRef | Header | NotElectrical
  deriving (Eq, Show)

symbolKind :: Part -> Kind
symbolKind p = case (libNick sym, libItem sym) of
  ("Device", "R")               -> Res
  ("Device", "C")               -> Cap
  ("Device", "R_Potentiometer") -> Pot
  ("Device", i) | "D" `T.isPrefixOf` i -> Diode
  ("Diode", _)                  -> Diode
  ("Connector_Audio", _)        -> Jack
  ("Amplifier_Operational", _)  -> OpAmp
  ("Reference_Voltage", _)      -> VRef
  ("Connector_Generic", _)      -> Header
  ("Mechanical", _)             -> NotElectrical
  _                             -> NotElectrical
  where sym = partSymbol p

-- | The SPICE lines for one part, or why it cannot be emitted.
elementFor :: Module -> Part -> Either Text [Text]
elementFor m p = case symbolKind p of
  Res -> do
    v <- value
    two $ \a b -> ["R" <> ref <> " " <> a <> " " <> b <> " " <> v]
  Cap -> do
    v <- value
    two $ \a b -> ["C" <> ref <> " " <> a <> " " <> b <> " " <> v]
  Diode -> do
    -- KiCad numbers a diode's cathode 1 and its anode 2 (checked in
    -- Device.kicad_sym, not assumed), and SPICE wants the anode first.
    -- Getting this backwards reverses every protection diode on the board
    -- and the netlist still simulates, which is why it is written down.
    k <- node "1"
    a <- node "2"
    pure ["D" <> ref <> " " <> a <> " " <> k <> " " <> modelName p]
  Pot -> do
    v <- value
    hi <- node "3"
    w  <- node "2"
    lo <- node "1"
    let k = "k_" <> ref
    pure [ "R" <> ref <> "hi " <> hi <> " " <> w <> " {max(1m," <> v <> "*(1-" <> k <> "))}"
         , "R" <> ref <> "lo " <> w <> " " <> lo <> " {max(1m," <> v <> "*" <> k <> ")}" ]
  Jack -> do
    -- A switched jack's normalling contact: a resistor a deck can open.
    -- Unconnected switch pins are declared in partNoConnect and simply have
    -- no net, so there is nothing to bridge.
    t <- node "T"
    case lookupNode m p "TN" of
      Nothing -> pure ["* " <> ref <> ": tip on " <> t <> ", switch pin unused"]
      Just tn -> pure
        [ "R" <> ref <> "n " <> t <> " " <> tn <> " {norm_" <> ref <> "}" ]
  OpAmp -> opAmpLines m p
  VRef -> vrefLines m p
  Header -> pure ["* " <> ref <> ": connector, nodes come from the deck"]
  NotElectrical -> pure ["* " <> ref <> ": not an electrical part"]
  where
    ref = partRef p
    value = spiceValue (partValue p)
    node n = maybe (Left ("pin " <> n <> " is on no net")) Right (lookupNode m p n)
    two f = do
      a <- node "1"
      b <- node "2"
      pure (f a b)

-- | One subcircuit call per op-amp unit, plus the shared supply pins.
--
-- KiCad's dual op-amp symbols number unit A's pins 1 to 3, unit B's 5 to 7,
-- and put the supplies on 4 and 8. A quad would continue the pattern; only
-- what the library says is used, so an unknown pin count is an error rather
-- than an assumption.
opAmpLines :: Module -> Part -> Either Text [Text]
opAmpLines m p = do
  vminus <- node "4"
  vplus <- node "8"
  units <- mapM (unit vplus vminus) presentUnits
  pure (concat units)
  where
    ref = partRef p
    node n = maybe (Left ("pin " <> n <> " is on no net")) Right (lookupNode m p n)
    -- (output, inverting, non-inverting) per unit, in KiCad's numbering.
    unitPins = [(1, 2, 3), (7, 6, 5), (8, 9, 10), (14, 13, 12)] :: [(Int, Int, Int)]
    presentUnits =
      [ (o, i, ni) | (o, i, ni) <- unitPins
      , all (\n -> lookupNode m p (T.pack (show n)) /= Nothing) [o, i, ni] ]
    -- The unit drives a private node; the 0 V probe source connects it to
    -- the net (see the module header). Two lines per unit.
    unit vplus vminus (o, i, ni) = do
      out <- node (T.pack (show o))
      inv <- node (T.pack (show i))
      nin <- node (T.pack (show ni))
      let probe = ref <> "_o" <> T.pack (show o)
      pure [ T.unwords [ "X" <> ref <> "_" <> T.pack (show o)
                       , nin, inv, vplus, vminus, probe, modelName p ]
           , T.unwords [ "V" <> probe, probe, out, "DC 0 AC 0" ] ]

-- | A series voltage reference in KiCad's REF50xx pin order: Vin (2), GND
-- (4), Trim/NR (5), Vout (6). The subcircuit in @modules\/_models\/@ takes
-- those four in that order. The TEMP pin (3) has no electrical role in the
-- models and is ignored whether or not it is on a net; an unused Trim/NR pin
-- gets a private node so the subcircuit's filter input is simply left open.
vrefLines :: Module -> Part -> Either Text [Text]
vrefLines m p = do
  vin  <- node "2"
  gnd  <- node "4"
  vout <- node "6"
  let nr = maybe (ref <> "_NR") id (lookupNode m p "5")
  pure [ T.unwords [ "X" <> ref, vin, gnd, nr, vout, modelName p ] ]
  where
    ref = partRef p
    node n = maybe (Left ("pin " <> n <> " is on no net")) Right (lookupNode m p n)

-- | The node a part's pin sits on, as SPICE should see it.
lookupNode :: Module -> Part -> Text -> Maybe Text
lookupNode m p pin =
  case [ netName n | n <- modNets m, (partRef p, pin) `elem` netPins n ] of
    (n : _) | n == "GND" -> Just "0"
            | otherwise  -> Just (spiceNode n)
    [] -> Nothing

-- | A net name SPICE will accept.
--
-- The signs have to survive. Mapping both @+12V@ and @-12V@ to one scrubbed
-- name shorted the supply rails into a single node, and the netlist read
-- perfectly well with the op-amp's V+ and V- on the same net.
-- 'nodeCollisions' now refuses any design where two nets would still land
-- on one node.
spiceNode :: Text -> Text
spiceNode = T.concatMap scrub
  where
    scrub '+' = "P"
    scrub '-' = "N"
    scrub c | c `elem` badChars = "_"
            | otherwise = T.singleton c
    badChars = "/\\ ()," :: String

-- | The subcircuit or device model a part expects to find in
-- @modules\/_models\/@, named after the part's value.
modelName :: Part -> Text
modelName p = T.map (\c -> if c `elem` ("/\\ " :: String) then '_' else c) (partValue p)

-- | A component value SPICE can read.
--
-- KiCad values are written for humans ("100k", "1.5k", "100n", "10u",
-- "B100K" for a linear-taper pot). SPICE wants a bare number with an
-- optional suffix, and reads "meg" rather than "M". A value it cannot read
-- is an error, not a default: a resistor silently becoming 1 ohm is the kind
-- of thing that makes a simulation confidently wrong.
spiceValue :: Text -> Either Text Text
spiceValue raw
  | T.null digits = Left ("cannot read '" <> raw <> "' as a component value")
  | otherwise = Right (digits <> suffix)
  where
    -- A pot's taper letter is a prefix; strip it before reading the number.
    body = T.dropWhile (`elem` ("ABCW" :: String)) (T.strip raw)
    digits = T.takeWhile (\c -> isDigit c || c == '.') body
    rest = T.map toLower (T.drop (T.length digits) body)
    suffix
      | "meg" `T.isPrefixOf` rest = "meg"
      | Just (c, _) <- T.uncons rest, c `elem` ("pnufkg" :: String) = T.singleton c
      -- KiCad writes a megohm as "1M"; SPICE would read a lower-case m as
      -- milli. Resistances are what carry that suffix in practice, and a
      -- milliohm resistor is not a thing this project puts on a board.
      | Just (c, _) <- T.uncons rest, c == 'm' = "meg"
      | Just (c, _) <- T.uncons rest, c == 'r' = ""
      | otherwise = ""
