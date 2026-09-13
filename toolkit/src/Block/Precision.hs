{-# LANGUAGE OverloadedStrings #-}
-- | The precision CV channel: a unity-gain buffer into a single op-amp
-- attenuverter, the circuit that docs/modules/attenuverter/ERROR-BUDGET.md
-- derived and the eight decks in modules/attenuverter/sim/ assert. It is the
-- block that reappears on every CV input of the five-board system, so it is
-- defined once here and the attenuverter module is its first consumer.
--
-- One OPA2197 per channel. Unit A (pins 1, 2, 3) is the buffer: the jack
-- tip on its non-inverting input, output tied back to the inverting input,
-- @R_in@ 1 M from the tip to ground so an unterminated cable reads zero.
-- Unit B (pins 5, 6, 7) is the attenuverter: @R_a@ from the buffer output to
-- the inverting input, @R_f@ from the output back to it, both 10 k 0.1 %
-- thin film, @C_f@ 10 pF C0G across @R_f@; the pot is a divider across the
-- buffer output and ground with its wiper on the non-inverting input. With
-- @R_a = R_f@, @Vout = (2k - 1) * Vin@ for pot fraction @k@. @R_o@ 1 k in
-- series with the output jack protects against shorts and cables. A 100 nF
-- sits at each supply pin.
--
-- The value of the gain resistors is 10 k and not the customary 100 k
-- because the op-amp's input capacitance shelves the full-clockwise response
-- towards @1 + C_in/C_f@ above the audio band: +4.6 % at 20 kHz with 100 k
-- and 10 pF of stray, 0.05 % with 10 k (the @stability@ deck). Do not
-- change it, or the compensation capacitor, without rerunning the decks.
--
-- The block fixes what every part is and which nets connect them; the
-- design says where each part sits and which jacks and pot it owns. Net
-- names are suffixed so that two channels on one board stay distinct.
module Block.Precision
  ( BufferedAttenuverter (..)
  , bufferedAttenuverterParts
  , bufferedAttenuverterNets
  , bufferedAttenuverterRefs
    -- * Library identities
  , opa2197Sym, soic8
  , resistorSym, r0805
  ) where

import           Data.Text   (Text)

import           Block.Power (c0805, capSym)
import           Design

data BufferedAttenuverter = BufferedAttenuverter
  { baSuffix  :: Text       -- ^ appended to every net name: @"1"@ gives @IN1@, @BUF1@, ...
  , baInJack  :: Text       -- ^ reference of the input jack (its tip pin @T@ is the input)
  , baOutJack :: Text       -- ^ reference of the output jack (tip pin @T@)
  , baPot     :: Text       -- ^ reference of the 100 k pot: pin 1 to ground, 2 wiper, 3 buffer output
  , baOpAmp   :: Placed     -- ^ the OPA2197
  , baOpAmpUnitOffsets :: [(Double, Double)]
    -- ^ schematic offsets of unit B and the power unit from unit A ('partUnitOffsets')
  , baRin     :: Placed     -- ^ 1 M input resistor
  , baRa      :: Placed     -- ^ 10 k 0.1 % from the buffer to the inverting input
  , baRf      :: Placed     -- ^ 10 k 0.1 % feedback
  , baCf      :: Placed     -- ^ 10 pF C0G across @R_f@
  , baRo      :: Placed     -- ^ 1 k output resistor
  , baCVp     :: Placed     -- ^ 100 nF at V+ (pin 8)
  , baCVn     :: Placed     -- ^ 100 nF at V- (pin 4)
  , baSide    :: Side       -- ^ the assembly side, where every part of the block goes
  } deriving (Show)

opa2197Sym, soic8, resistorSym, r0805 :: LibId
opa2197Sym  = LibId "Amplifier_Operational" "OPA2197xD"
soic8       = LibId "Package_SO" "SOIC-8_3.9x4.9mm_P1.27mm"
resistorSym = LibId "Device" "R"
r0805       = LibId "Resistor_SMD" "R_0805_2012Metric"

-- | The block's parts: the op-amp, the signal path from input to output,
-- then the decoupling. Every one is factory placed; the op-amp keeps its
-- silkscreen reference for the orientation check, the passives do not.
--
-- LCSC numbers were verified against LCSC's product data on 2026-09-13
-- (OPA2197IDR C139363, 10 k 0.1 % 25 ppm thin film C110775, 10 pF C0G
-- C344177) and jlcpcb.com on 2026-09-08 (1 k C17513, 1 M C17514, 100 nF
-- C49678); docs/modules/attenuverter/SPEC.md has the table.
bufferedAttenuverterParts :: BufferedAttenuverter -> [Part]
bufferedAttenuverterParts ba =
  [ (smd (baOpAmp ba) "OPA2197" opa2197Sym soic8 "C139363")
      { partRefOnSilk = True, partUnitOffsets = baOpAmpUnitOffsets ba }
  , smd (baRin ba) "1M"   resistorSym r0805 "C17514"
  , smd (baRa ba)  "10k"  resistorSym r0805 "C110775"
  , smd (baRf ba)  "10k"  resistorSym r0805 "C110775"
  , smd (baCf ba)  "10p"  capSym      c0805 "C344177"
  , smd (baRo ba)  "1k"   resistorSym r0805 "C17513"
  , smd (baCVp ba) "100n" capSym      c0805 "C49678"
  , smd (baCVn ba) "100n" capSym      c0805 "C49678"
  ]
  where
    smd pl val sy fp code =
      (part (plRef pl) val sy fp (plAt pl) (plSchAt pl))
        { partRot = plRot pl
        , partSide = baSide ba
        , partFields = [("LCSC Part #", code)]
        , partRefOnSilk = False
        , partAssembly = Factory }

-- | The block's nets. The signal nets are complete; the power nets carry
-- only this block's pins and are merged with the rest of the board's by
-- 'mergeNets'. Pot end 3 carries the buffered input so that clockwise means
-- positive gain.
bufferedAttenuverterNets :: BufferedAttenuverter -> [Net]
bufferedAttenuverterNets ba =
  [ Net "GND"  Power  [(rv, "1"), (rIn, "2"), (cVp, "2"), (cVn, "2")]
  , Net "+12V" Power  [(u, "8"), (cVp, "1")]
  , Net "-12V" Power  [(u, "4"), (cVn, "1")]
  , Net ("IN" <> n)    Signal [(jIn, "T"), (rIn, "1"), (u, "3")]
  , Net ("BUF" <> n)   Signal [(u, "1"), (u, "2"), (rA, "1"), (rv, "3")]
  , Net ("INV" <> n)   Signal [(rA, "2"), (rF, "1"), (cF, "1"), (u, "6")]
  , Net ("WIPER" <> n) Signal [(rv, "2"), (u, "5")]
  , Net ("OA" <> n)    Signal [(u, "7"), (rF, "2"), (cF, "2"), (rO, "1")]
  , Net ("OUT" <> n)   Signal [(rO, "2"), (jOut, "T")]
  ]
  where
    n    = baSuffix ba
    jIn  = baInJack ba
    jOut = baOutJack ba
    rv   = baPot ba
    u    = plRef (baOpAmp ba)
    rIn  = plRef (baRin ba)
    rA   = plRef (baRa ba)
    rF   = plRef (baRf ba)
    cF   = plRef (baCf ba)
    rO   = plRef (baRo ba)
    cVp  = plRef (baCVp ba)
    cVn  = plRef (baCVn ba)

-- | Every reference the block places.
bufferedAttenuverterRefs :: BufferedAttenuverter -> [Text]
bufferedAttenuverterRefs ba =
  map plRef [baOpAmp ba, baRin ba, baRa ba, baRf ba, baCf ba, baRo ba, baCVp ba, baCVn ba]
