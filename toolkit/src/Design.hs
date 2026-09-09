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
  , NetKind (..)
  , Net (..)
  , Trace (..)
  , PadConnect (..)
  , Zone (..)
  , BoardText (..)
  , DesignRules (..)
  , defaultRules
  , AutoRoute (..)
  , autoRoute
  , Board (..)
  , Module (..)
  , pcbNetName
  , eurorackPanelWidth
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

-- | Power nets become KiCad power symbols and global nets; signal nets become
-- local net labels, which KiCad names with a leading slash on the board.
data NetKind = Power | Signal
  deriving (Eq, Show)

data Net = Net
  { netName :: Text
  , netKind :: NetKind
  , netPins :: [(Text, Text)]   -- ^ (reference, pad/pin number)
  } deriving (Show)

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
eurorackPanelWidth hp = case hp of
  1  -> 5.00
  2  -> 9.80
  4  -> 20.00
  6  -> 30.00
  8  -> 40.30
  10 -> 50.50
  12 -> 60.60
  14 -> 70.80
  16 -> 80.90
  18 -> 91.30
  20 -> 101.30
  22 -> 111.40
  28 -> 141.90
  42 -> 213.00
  _  -> fromIntegral hp * 5.08 - 0.3

-- | Doepfer 3U front panel height.
eurorackPanelHeight :: Double
eurorackPanelHeight = 128.5

-- | Tallest PCB that clears the mounting rails on every 3U case. Doepfer
-- lists 110 mm as the usable height behind the panel; 108 mm also clears
-- the deeper rail profiles, so it is the repo default. Centred on the panel.
eurorackPcbHeight :: Double
eurorackPcbHeight = 108.0

-- | Where the PCB's top edge sits below the panel's top edge when centred.
eurorackPcbTop :: Double
eurorackPcbTop = (eurorackPanelHeight - eurorackPcbHeight) / 2   -- 10.25
