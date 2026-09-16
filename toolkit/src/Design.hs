{-# LANGUAGE OverloadedStrings #-}
-- | The design model: what a module *is*, independent of KiCad's file format.
-- Coordinates are millimetres. Board coordinates have their origin at the
-- PCB's top-left corner, y downward, matching KiCad's board view.
module Design
  ( LibId (..)
  , Side (..)
  , Assembly (..)
  , Part (..)
  , part
  , Placed (..)
  , NetKind (..)
  , Net (..)
  , mergeNets
  , Trace (..)
  , PadConnect (..)
  , Zone (..)
  , BoardText (..)
  , DesignRules (..)
  , defaultRules
  , AutoRoute (..)
  , autoRoute
  , NetRole (..)
  , Analog (..)
  , noAnalog
  , Board (..)
  , Module (..)
  , pcbNetName
  , eurorackPanelWidth
  , eurorackPanelWidths
  , eurorackPanelHeight
  , eurorackPcbHeight
  , eurorackPcbTop
  ) where

import           Data.Text (Text)

data LibId = LibId { libNick :: Text, libItem :: Text }
  deriving (Eq, Ord, Show)

data Side = Front | Back
  deriving (Eq, Show)

-- | Who installs a part, and whether it is installed at all. Declared per
-- part rather than inferred from a sourcing field, so a missing supplier
-- number cannot silently turn a factory part into a hand-soldered one
-- (validation rejects a 'Factory' part without an LCSC Part #).
data Assembly
  = Factory      -- ^ placed by the board house from BOM and CPL; needs an LCSC Part #
  | Hand         -- ^ soldered by hand after delivery (jacks, pots, headers)
  | DNP          -- ^ footprint on the board, nothing installed
  | Mechanical   -- ^ holes and other items that are not components at all
  deriving (Eq, Ord, Show)

data Part = Part
  { partRef       :: Text
  , partValue     :: Text
  , partSymbol    :: LibId
  , partFootprint :: LibId
  , partAt        :: (Double, Double)   -- ^ board position of the footprint origin
  , partRot       :: Double             -- ^ board rotation, degrees CCW as KiCad displays it
  , partSide      :: Side
  , partFields    :: [(Text, Text)]     -- ^ extra symbol/footprint fields, e.g. LCSC Part #
  , partSchAt     :: (Double, Double)   -- ^ schematic position
  , partSchRot    :: Double
  , partRefOnSilk :: Bool               -- ^ print the reference on the board silkscreen
  , partUnitOffsets :: [(Double, Double)]
    -- ^ schematic offset of units 2, 3, ... from 'partSchAt' for multi-unit
    -- symbols (dual op-amps); units without an entry stack 25.4 mm apart below.
  , partNoConnect :: [Text]
    -- ^ pin numbers deliberately left unconnected. Every other pin must be on
    -- a net; validation rejects a pin that is neither.
  , partAssembly  :: Assembly
  } deriving (Show)

-- | A front-side, unrotated, hand-installed part with no extra fields and
-- no deliberately unconnected pins.
part :: Text -> Text -> LibId -> LibId -> (Double, Double) -> (Double, Double) -> Part
part ref val sy fp at schAt = Part ref val sy fp at 0 Front [] schAt 0 True [] [] Hand

-- | Where a part of a reusable block goes. A block ("Block.Power",
-- "Block.Precision") fixes what each of its parts is; the design that uses
-- the block supplies one of these per part to say where it sits.
data Placed = Placed
  { plRef   :: Text               -- ^ reference designator
  , plAt    :: (Double, Double)   -- ^ footprint origin, board coordinates
  , plRot   :: Double             -- ^ board rotation, degrees
  , plSchAt :: (Double, Double)   -- ^ schematic position
  } deriving (Show)

-- | Power nets become KiCad power symbols and global nets; signal nets become
-- local net labels, which KiCad names with a leading slash on the board.
data NetKind = Power | Signal
  deriving (Eq, Show)

data Net = Net
  { netName :: Text
  , netKind :: NetKind
  , netPins :: [(Text, Text)]   -- ^ (reference, pad/pin number)
  } deriving (Show)

-- | Merge nets that share a name and kind into one, keeping the order in
-- which names first appear and concatenating pins in order. This is how a
-- design combines the @GND@, @+12V@ and @-12V@ fragments that each block
-- contributes with its own. Two nets of the same name but different kinds
-- are left alone, so validation still reports them as a duplicate.
mergeNets :: [Net] -> [Net]
mergeNets = foldl add []
  where
    add acc n
      | any (same n) acc = map (\m -> if same n m then m { netPins = netPins m ++ netPins n } else m) acc
      | otherwise        = acc ++ [n]
    same n m = netName m == netName n && netKind m == netKind n

pcbNetName :: Net -> Text
pcbNetName n = case netKind n of
  Power  -> netName n
  Signal -> "/" <> netName n

data Trace = Trace
  { trNet   :: Text                 -- ^ design net name (without slash)
  , trLayer :: Text                 -- ^ "F.Cu" or "B.Cu"
  , trWidth :: Double
  , trPath  :: [(Double, Double)]   -- ^ polyline, at least two points
  } deriving (Show)

-- | How a copper pour bonds to the pads of its own net.
--
-- 'ThermalRelief' is KiCad's default and gives each pad spokes through a gap;
-- KiCad's DRC then demands two spokes per pad, which a pour cannot always
-- give a pad that routed copper crowds. 'PadsUnbonded' leaves the pads alone:
-- correct when every net is routed as copper anyway and the pour is redundant
-- shielding on top, which is this repository's house style. The pour still
-- merges with the traces of its net, and DRC still reports any pad left
-- unconnected, so the guarantee does not rest on the pour.
data PadConnect = ThermalRelief | SolidFill | PadsUnbonded
  deriving (Eq, Show)

data Zone = Zone
  { znNet       :: Text
  , znLayer     :: Text
  , znName      :: Text
  , znPoly      :: [(Double, Double)]
  , znClearance :: Double
  , znMinWidth  :: Double
  , znConnect   :: PadConnect
  } deriving (Show)

data BoardText = BoardText
  { btText  :: Text
  , btLayer :: Text
  , btAt    :: (Double, Double)
  , btRot   :: Double
  , btSize  :: Double
  } deriving (Show)

data DesignRules = DesignRules
  { drClearance     :: Double
  , drTrackWidth    :: Double
  , drViaDiameter   :: Double
  , drViaDrill      :: Double
  , drHoleToHole    :: Double
  , drEdgeClearance :: Double
  } deriving (Show)

-- | JLCPCB 2-layer capability with margin.
defaultRules :: DesignRules
defaultRules = DesignRules
  { drClearance = 0.2, drTrackWidth = 0.2, drViaDiameter = 0.6, drViaDrill = 0.3
  , drHoleToHole = 0.5, drEdgeClearance = 0.5 }

-- | Which nets the grid router should connect, and with what copper.
-- Hand-drawn 'bdTraces' stay and count as existing copper of their net.
data AutoRoute = AutoRoute
  { arNets        :: [Text]     -- ^ design net names
  , arPitch       :: Double     -- ^ grid cell, mm
  , arWidth       :: Double     -- ^ trace width, mm
  , arViaDiameter :: Double
  , arViaDrill    :: Double
  } deriving (Show)

autoRoute :: [Text] -> AutoRoute
autoRoute nets = AutoRoute nets 0.2 0.3 0.6 0.3

-- Analog intent ---------------------------------------------------------------

-- | What a net is, electrically, as far as the layout has to care.
--
-- Each role carries the number that makes it matter. A 'Quiet' node is
-- high-impedance -- a pot wiper, an input bias node, a VCA control pin --
-- and its impedance is what decides how much a neighbour can inject into
-- it. A 'Noisy' net carries a switching edge, and the edge's height and rise
-- time are what decide how much it injects. Everything else is 'Ordinary'
-- and is routed on length and vias alone.
--
-- Nothing here is a rule of thumb: @toolkit\/nodebudget.py@ derives the
-- consequences of these numbers from a field solve of the stackup plus
-- ngspice, and 'Route.Analog' predicts them for a routed board.
data NetRole
  = Ordinary
  | Quiet Double          -- ^ node impedance, ohms
  | Noisy Double Double   -- ^ worst edge carried: volts, rise time in seconds
  deriving (Eq, Show)

-- | Electrical intent, over and above "connect these pads". This is the part
-- of a design a netlist cannot express, and that a router therefore cannot
-- honour unless it is told.
--
-- Every field is optional and 'noAnalog' changes nothing, so a design that
-- declares no intent behaves exactly as it did before.
data Analog = Analog
  { anRoles     :: [(Text, NetRole)]
    -- ^ Net name to role. A net not listed is 'Ordinary'.
  , anMaxLength :: [(Text, Double)]
    -- ^ Millimetres of copper a net may not exceed.
    --
    --   Derive these, do not guess them: @nodebudget.py length@ turns a node
    --   impedance and a bandwidth into the length at which the trace's own
    --   capacitance costs that bandwidth. Be warned that on a board this
    --   small the answer is usually that nothing binds -- a 100k node may
    --   carry 1.7 metres of trace at 20 kHz -- so a budget here is mostly
    --   documentation. The coupling limit below is the one that bites.
  , anMatched   :: [(Text, [Text], Double)]
    -- ^ @(group, nets whose copper lengths should match, tolerance in mm)@.
    --
    --   Two channels of the same circuit that route differently behave
    --   differently. Nothing in a netlist says the channels are meant to be
    --   the same circuit, so this does.
  , anInjectMv  :: Double
    -- ^ Millivolts a 'Noisy' net may put on a 'Quiet' one. Zero disables the
    --   check.
    --
    --   This replaced a minimum-spacing rule, because spacing turned out to
    --   be a weak lever and the measurement said so: against a 5 V gate edge
    --   beside a 1M node, widening the gap from 0.2 mm to 2 mm only takes
    --   the injection from 700 mV to 111 mV. What actually controls it is how
    --   far the two run alongside each other, so the design states the
    --   electrical limit and the check predicts the injection from the
    --   copper.
  , anSameCircuit :: [[Text]]
    -- ^ Groups of nets that are one signal path. Coupling between two nets in
    --   the same group is not crosstalk: an op-amp's output sitting near its
    --   own inverting input is its feedback network, and a router asked to
    --   separate them would be spending copper to undo the circuit.
    --
    --   Without this the check has no notion of a channel and reports every
    --   quiet/noisy pair on the board, which on a dual module means the only
    --   non-zero numbers are the ones that do not matter.
  , anNodePf    :: Double
    -- ^ Picofarads a 'Quiet' node carries besides its own trace: op-amp
    --   input capacitance, a filter cap, pad capacitance. It appears in the
    --   denominator of the coupling divider, so leaving it at zero is the
    --   pessimistic choice.
  } deriving (Show)

-- | Declare nothing. What every design starts with.
noAnalog :: Analog
noAnalog = Analog [] [] [] 0 [] 0

data Board = Board
  { bdWidth        :: Double
  , bdHeight       :: Double
  , bdCornerRadius :: Double
  , bdRules        :: DesignRules
  , bdTraces       :: [Trace]
  , bdAutoRoute    :: Maybe AutoRoute
  , bdZones        :: [Zone]
  , bdTexts        :: [BoardText]
  , bdCustomRules  :: Text          -- ^ body of the .kicad_dru file (may be empty)
  , bdAnalog       :: Analog        -- ^ electrical intent the checks and the router honour
  } deriving (Show)

data Module = Module
  { modName   :: Text       -- ^ file stem
  , modOutDir :: FilePath   -- ^ where the generated project lives, relative to the repo root
  , modTitle  :: Text
  , modHP    :: Int
  , modParts :: [Part]
  , modNets  :: [Net]
  , modBoard :: Board
  , modNotes :: [Text]     -- ^ free text placed on the schematic sheet
  } deriving (Show)

-- | Doepfer A-100 front panel width for a given HP count. Doepfer's table
-- (a100m_e.htm) rounds the nominal @HP × 5.08 − 0.3@ to these values; the
-- formula is used for sizes the table does not list.
eurorackPanelWidth :: Int -> Double
eurorackPanelWidth hp =
  maybe (fromIntegral hp * 5.08 - 0.3) id (lookup hp eurorackPanelWidths)

-- | The widths Doepfer's table lists explicitly, in order. Which widths are
-- tabulated is a separate fact from what a given width measures, and it
-- cannot be recovered from 'eurorackPanelWidth', so it lives here once: the
-- sketch checks warn about a width off this table and the browser is given
-- the same list rather than a second copy of these numbers.
eurorackPanelWidths :: [(Int, Double)]
eurorackPanelWidths =
  [ (1, 5.00), (2, 9.80), (4, 20.00), (6, 30.00), (8, 40.30), (10, 50.50)
  , (12, 60.60), (14, 70.80), (16, 80.90), (18, 91.30), (20, 101.30)
  , (22, 111.40), (28, 141.90), (42, 213.00) ]

-- | Doepfer 3U front panel height.
eurorackPanelHeight :: Double
eurorackPanelHeight = 128.5

-- | PCB height behind a 3U panel. Doepfer lists 110 mm as usable and 108 mm
-- clears the deeper rail profiles, but JLCPCB's cheapest tier ends at
-- 100 x 100 mm (docs/JLCPCB.md), and a 100 mm board still leaves 14.25 mm
-- to each rail. Fixed at 100 mm on 2026-09-11 (docs/ROADMAP.md, form factor)
-- and applied to every module on 2026-09-13. Centred on the panel.
eurorackPcbHeight :: Double
eurorackPcbHeight = 100.0

-- | Where the PCB's top edge sits below the panel's top edge when centred.
eurorackPcbTop :: Double
eurorackPcbTop = (eurorackPanelHeight - eurorackPcbHeight) / 2   -- 14.25
