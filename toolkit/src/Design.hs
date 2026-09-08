{-# LANGUAGE OverloadedStrings #-}
-- | The design model: what a module *is*, independent of KiCad's file format.
-- Coordinates are millimetres. Board coordinates have their origin at the
-- PCB's top-left corner, y downward, matching KiCad's board view.
module Design
  ( LibId (..)
  , Side (..)
  , Part (..)
  , part
  , NetKind (..)
  , Net (..)
  , Trace (..)
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
  ) where

import           Data.Text (Text)

data LibId = LibId { libNick :: Text, libItem :: Text }
  deriving (Eq, Ord, Show)

data Side = Front | Back
  deriving (Eq, Show)

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
  } deriving (Show)

-- | A front-side, unrotated part with no extra fields.
part :: Text -> Text -> LibId -> LibId -> (Double, Double) -> (Double, Double) -> Part
part ref val sy fp at schAt = Part ref val sy fp at 0 Front [] schAt 0 True

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

data Zone = Zone
  { znNet       :: Text
  , znLayer     :: Text
  , znName      :: Text
  , znPoly      :: [(Double, Double)]
  , znClearance :: Double
  , znMinWidth  :: Double
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
