{-# LANGUAGE OverloadedStrings #-}
-- | The Eurorack module skeleton: everything a 3U module's design needs
-- before a single component is chosen. Panel size from the HP count, the
-- 100 mm PCB centred behind it, the mapping from panel coordinates (where
-- controls are specified) to board coordinates (where footprints go), rail
-- holes, and the front-panel project that mirrors the module's controls as
-- holes.
--
-- Every module and every panel project uses this rather than repeating the
-- arithmetic, so a change to the form factor (the 2026-09-13 move from 108
-- to 100 mm, for instance) is one edit. The numbers it encodes are the
-- rules in AGENTS.md: Doepfer's panel table and 128.5 mm height, rail holes
-- Ø3.2 at 3.0 mm from the top and bottom edges with the first column 7.5 mm
-- from the left edge and further columns on the 5.08 mm grid, a PCB 100 mm
-- tall centred on the panel and 1 mm inside each side edge.
--
-- Coordinates: /panel/ coordinates have their origin at the panel's top-left
-- corner, y downward, looking at the panel from the front. /Board/
-- coordinates have their origin at the PCB's top-left corner, the same
-- orientation, which is KiCad's board view of the front layer.
module Block.Eurorack
  ( -- * Geometry
    Skeleton (..)
  , skeleton
  , toBoard
  , boardOutline
  , originFor
  , thonkiconnPitch
    -- * Library identities of the panel-mounted parts
  , thonkiconnSym, thonkiconnFp
  , alphaPotSym, alphaPotFp
    -- * The front-panel project
  , holeSym, jackHoleFp, potHoleFp, railHoleFp
  , hole
  , railHoles
  , panelBoard
  ) where

import           Data.Text      (Text)
import qualified Data.Text      as T

import           Design
import           Route.Geometry (rotatePt)

-- | The fixed geometry of one module, derived from its width alone.
data Skeleton = Skeleton
  { skHP          :: Int
  , skPanelWidth  :: Double            -- ^ Doepfer's table ('eurorackPanelWidth')
  , skPanelHeight :: Double            -- ^ 128.5
  , skBoardWidth  :: Double            -- ^ panel width less 1 mm each side
  , skBoardHeight :: Double            -- ^ 'eurorackPcbHeight'
  , skBoardOrigin :: (Double, Double)  -- ^ panel coordinates of the PCB's top-left corner
  , skRailHoleX   :: [Double]          -- ^ rail-hole columns, panel x
  , skRailHoleY   :: [Double]          -- ^ rail-hole rows, panel y
  } deriving (Show)

-- | The skeleton for a module of the given width in HP.
--
-- Rail-hole columns: the first is 7.5 mm from the left edge; the second is
-- @(hp - 3)@ grid steps of 5.08 mm further right, which lands 7.3 to 7.5 mm
-- from the right edge for every width in Doepfer's table from 6HP up (6HP:
-- 22.74 mm on a 30.0 mm panel; 8HP: 32.9 on 40.3). A panel of 4HP or less
-- gets a single column, since the second would sit 5 mm from the first.
-- Only 6HP has been generated so far; the wider cases follow the same rule
-- but have not been checked against a rail.
skeleton :: Int -> Skeleton
skeleton hp = Skeleton
  { skHP = hp
  , skPanelWidth = w
  , skPanelHeight = eurorackPanelHeight
  , skBoardWidth = w - 2.0
  , skBoardHeight = eurorackPcbHeight
  , skBoardOrigin = (1.0, eurorackPcbTop)
  , skRailHoleX = 7.5 : [ 7.5 + fromIntegral (hp - 3) * 5.08 | hp > 4 ]
  , skRailHoleY = [3.0, eurorackPanelHeight - 3.0]
  }
  where w = eurorackPanelWidth hp

-- | Panel coordinates to board coordinates.
toBoard :: Skeleton -> (Double, Double) -> (Double, Double)
toBoard sk (x, y) = let (ox, oy) = skBoardOrigin sk in (x - ox, y - oy)

-- | The PCB outline as a polygon in board coordinates, for zones.
boardOutline :: Skeleton -> [(Double, Double)]
boardOutline sk = [(0, 0), (w, 0), (w, h), (0, h)]
  where w = skBoardWidth sk
        h = skBoardHeight sk

-- | Footprint origin that puts a footprint-local point at a wanted board
-- position, for the side and rotation the part will get. Mirrors what the
-- PCB emitter does: flip (negate local y) first, then rotate. This is how a
-- pot whose footprint origin is pin 1 gets its shaft on the panel grid.
originFor :: Side -> Double -> (Double, Double) -> (Double, Double) -> (Double, Double)
originFor side rot (lx, ly) (bx, by) =
  let ly' = if side == Back then negate ly else ly
      (dx, dy) = rotatePt rot (lx, ly')
  in (bx - dx, by - dy)

-- | Minimum vertical pitch for Thonkiconns stacked in a column with the
-- official footprint: 13.6 mm puts one jack's tip pad against the next
-- jack's sleeve pad at the 0.2 mm clearance, so 13.7 is used.
thonkiconnPitch :: Double
thonkiconnPitch = 13.7

-- Panel-mounted parts --------------------------------------------------------

-- | Thonkiconn (QingPu WQP-PJ398SM), the official footprint. Footprint
-- origin is the barrel; the body extends +y on the board.
thonkiconnSym, thonkiconnFp :: LibId
thonkiconnSym = LibId "Connector_Audio" "AudioJack2_SwitchT"
thonkiconnFp  = LibId "Connector_Audio" "Jack_3.5mm_QingPu_WQP-PJ398SM_Vertical_CircularHoles"

-- | Alpha 9 mm vertical pot (RD901F-40-00D), the official footprint. Its
-- origin is pin 1 and the shaft is at (7.5, 2.5) in footprint coordinates,
-- which is what 'originFor' is for.
alphaPotSym, alphaPotFp :: LibId
alphaPotSym = LibId "Device" "R_Potentiometer"
alphaPotFp  = LibId "Potentiometer_THT" "Potentiometer_Alpha_RD901F-40-00D_Single_Vertical"

-- The front-panel project ----------------------------------------------------

holeSym :: LibId
holeSym = LibId "Mechanical" "MountingHole"

-- | Thonkiconn barrel is M6 (6.4 mm clearance); the Alpha 9 mm pot bushing is
-- M7, for which the repository library carries a 7.2 mm hole; rail screws
-- are M3 in a 3.2 mm hole.
jackHoleFp, potHoleFp, railHoleFp :: LibId
jackHoleFp = LibId "MountingHole" "MountingHole_6.4mm_M6"
potHoleFp  = LibId "pcbgen" "Hole_7.2mm"
railHoleFp = LibId "MountingHole" "MountingHole_3.2mm_M3"

-- | A hole is not a component: nothing is installed, it leaves the BOM, and
-- no reference is printed on the panel face.
hole :: Text -> Text -> LibId -> (Double, Double) -> (Double, Double) -> Part
hole ref val fp at schAt =
  (part ref val holeSym fp at schAt) { partRefOnSilk = False, partAssembly = Mechanical }

-- | The rail mounting holes, numbered from the given first reference number,
-- column by column and top to bottom, parked on the right of the schematic.
railHoles :: Skeleton -> Int -> [Part]
railHoles sk firstRef =
  [ hole ("H" <> T.pack (show n)) "Rail" railHoleFp (x, y) (127.0 + 25.4 * fromIntegral i, 38.1 + 12.7 * fromIntegral j)
  | (n, (i, x, j, y)) <- zip [firstRef ..]
      [ (i, x, j, y) | (i, x) <- zip [0 :: Int ..] (skRailHoleX sk), (j, y) <- zip [0 :: Int ..] (skRailHoleY sk) ]
  ]

-- | A panel is a PCB the size of the panel with no copper: outline, holes
-- and the legend on the front silkscreen.
panelBoard :: Skeleton -> [BoardText] -> Board
panelBoard sk legend = Board
  { bdWidth = skPanelWidth sk
  , bdHeight = skPanelHeight sk
  , bdCornerRadius = 1.0
  , bdRules = defaultRules
  , bdTraces = []
  , bdAutoRoute = Nothing
  , bdZones = []
  , bdTexts = legend
  , bdCustomRules = ""
  , bdAnalog = noAnalog
  }
