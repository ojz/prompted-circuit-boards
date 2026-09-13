{-# LANGUAGE OverloadedStrings #-}
-- | Eurorack power entry and protection, the block every powered module
-- starts with (AGENTS.md: 2x5 shrouded IDC header, series Schottky on
-- +/-12 V, 10 uF + 100 nF per rail).
--
-- What is here: the header, the two series diodes and the two bulk
-- capacitors, with the five nets they define. What is deliberately not: the
-- 100 nF per rail. That capacitor belongs beside the supply pin of the part
-- it decouples, so each consumer places its own ('Block.Precision' does).
--
-- The block fixes the electrical identity of every part -- value, symbol,
-- footprint, LCSC number, who installs it -- and leaves the design to say
-- where each one goes. A design that needs a different header (a 2x8 for
-- +5 V) or a different diode writes a different block; it does not
-- parameterise this one into a configuration language.
--
-- Nets: the header's pins 1-2 are -12 V and 9-10 are +12 V on the raw side
-- of the diodes (@N12_RAW@, @P12_RAW@); pins 3-8 are GND. The protected
-- rails are the power nets @+12V@ and @-12V@, which the design extends with
-- its own consumers through 'Design.mergeNets'.
module Block.Power
  ( PowerEntry (..)
  , powerParts
  , powerNets
  , powerRefs
    -- * Library identities
  , idcHeaderSym, idcHeaderFp
  , schottkySym, sod123
  , capSym, c0805
  ) where

import           Data.Text (Text)
import qualified Data.Text as T

import           Design

data PowerEntry = PowerEntry
  { peHeader     :: Placed   -- ^ 2x5 shrouded IDC, through-hole, hand soldered
  , peHeaderSide :: Side
  , peDiodePos   :: Placed   -- ^ series Schottky in +12 V
  , peDiodeNeg   :: Placed   -- ^ series Schottky in -12 V
  , peBulkPos    :: Placed   -- ^ 10 uF on the protected +12 V
  , peBulkNeg    :: Placed   -- ^ 10 uF on the protected -12 V
  , peSmdSide    :: Side     -- ^ the assembly side, where the diodes and capacitors go
  } deriving (Show)

idcHeaderSym, idcHeaderFp, schottkySym, sod123, capSym, c0805 :: LibId
idcHeaderSym = LibId "Connector_Generic" "Conn_02x05_Odd_Even"
idcHeaderFp  = LibId "Connector_IDC" "IDC-Header_2x05_P2.54mm_Vertical"
schottkySym  = LibId "Device" "D_Schottky"
sod123       = LibId "Diode_SMD" "D_SOD-123"
capSym       = LibId "Device" "C"
c0805        = LibId "Capacitor_SMD" "C_0805_2012Metric"

-- | The parts, in schematic reading order: the header, then the +12 V
-- diode and its bulk capacitor, then the -12 V pair.
--
-- LCSC numbers were verified on jlcpcb.com on 2026-09-08 (SPEC.md of the
-- attenuverter has the table): B5819W SOD-123 C8598, 10 uF 25 V X5R 0805
-- C15850. Passives and diodes carry no silkscreen reference, since JLCPCB
-- places them from the BOM and position file; the header keeps its
-- reference because a hand places it and its orientation matters.
powerParts :: PowerEntry -> [Part]
powerParts pe =
  [ (place (peHeader pe) (part r "POWER" idcHeaderSym idcHeaderFp))
      { partSide = peHeaderSide pe, partAssembly = Hand }
  , smd (peDiodePos pe) "B5819W" schottkySym sod123 "C8598"
  , smd (peBulkPos pe)  "10u"    capSym      c0805  "C15850"
  , smd (peDiodeNeg pe) "B5819W" schottkySym sod123 "C8598"
  , smd (peBulkNeg pe)  "10u"    capSym      c0805  "C15850"
  ]
  where
    r = plRef (peHeader pe)
    place pl mk = (mk (plAt pl) (plSchAt pl)) { partRot = plRot pl }
    smd pl val sy fp code =
      (place pl (part (plRef pl) val sy fp))
        { partSide = peSmdSide pe
        , partFields = [("LCSC Part #", code)]
        , partRefOnSilk = False
        , partAssembly = Factory }

-- | The block's nets. @GND@, @+12V@ and @-12V@ carry only the block's own
-- pins here; the design merges its consumers in with 'mergeNets'.
powerNets :: PowerEntry -> [Net]
powerNets pe =
  [ Net "GND"     Power  ([ (hdr, T.pack (show p)) | p <- [3 .. 8 :: Int] ] ++ [(cPos, "2"), (cNeg, "2")])
  , Net "+12V"    Power  [(dPos, "1"), (cPos, "1")]
  , Net "-12V"    Power  [(dNeg, "2"), (cNeg, "1")]
  , Net "P12_RAW" Signal [(hdr, "9"), (hdr, "10"), (dPos, "2")]
  , Net "N12_RAW" Signal [(hdr, "1"), (hdr, "2"), (dNeg, "1")]
  ]
  where
    hdr  = plRef (peHeader pe)
    dPos = plRef (peDiodePos pe)
    dNeg = plRef (peDiodeNeg pe)
    cPos = plRef (peBulkPos pe)
    cNeg = plRef (peBulkNeg pe)

-- | Every reference the block uses, for a design that wants to check it is
-- not reusing one.
powerRefs :: PowerEntry -> [Text]
powerRefs pe = map plRef [peHeader pe, peDiodePos pe, peDiodeNeg pe, peBulkPos pe, peBulkNeg pe]
