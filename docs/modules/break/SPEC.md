---
status: "bench tool, built 2026-09-22; not a candidate module and not part of the hardware composition"
owner: "the agent; the user owns whether it is useful enough to keep"
read_when: "loading a sample into it, changing it, or deciding what may be committed alongside it"
update_when: "its behaviour changes, or the licensing position on bundled audio changes"
retire_when: "V0 ends, or a better test source replaces it"
---

# Break

A drum loop to test the other modules with. It plays a WAV you point it at, and
synthesises a break of its own when no file is loaded so it is never silent.

The user asked for it on 2026-09-22, in a note written straight into the tree:

> amen break module
>
> useful for testing effects modules.
>
> just has a single output, that continually outputs the amen break sample.

It does that with nothing patched. **It also has more than that note asked
for** -- a clock and reset input, tempo, speed and level knobs, and a second
output carrying an envelope follower. Those are there to drive the modules under
test from the same source, but they are additions to the request, not part of
it, and cutting back to one output and one knob would lose nothing essential.

**This is a bench instrument, not a candidate module.** It must not be counted
in [V0](../../ROADMAP.md#v0-playable-digital-modules-and-function-balance-current)'s
function balance, and no hardware version of it is proposed. It exists to feed
the modules being evaluated, the way a signal generator does.

## Why no sample is committed

The obvious test source is the Amen break -- the drum bar from The Winstons'
*Amen, Brother* (1969). That recording is still under copyright, and Wikipedia's
clip of it is non-free content used under fair use, so it cannot go in this
repository.

The user supplied a licensed alternative on 2026-09-22, the **KAN Amen Break
Tribute** pack, and it is legitimately licensed for their use: royalty-free, in
commercial and non-commercial work. Its licence nonetheless keeps it out of the
repository, in its own words:

> No sample or preset from this pack may be used in isolation in any public
> release. This means you cannot release, sell, or distribute any individual
> sample, preset or file from this pack.

> Sharing download links or any files in this pack with anyone who has not
> purchased this pack from KAN Samples without written consent is prohibited.

Committing one of its WAVs to a public repository is exactly that. So the module
**loads from disk instead**, which costs nothing and works with any file the
user is entitled to use. Verified against that pack: its files are 44.1 kHz
16-bit, and `KAB1_174_AmenBreak_Cut_01.wav` is 1.379 s, which is exactly one bar
at 174 BPM -- the module's default tempo, so it locks without hunting.

The built-in break is written by ear as a plausible breakbeat. **It is not a
transcription of the Amen break and is not claimed to be one.**

## Panel

Two columns by the standing [five rows](../../../AGENTS.md#rules): **8 HP**.
Three cells are deliberately empty.

| | col 1 | col 2 |
|---|---|---|
| row 1 | CLOCK IN | RESET IN |
| row 2 | TEMPO | LEVEL |
| row 3 | *reserved* | *reserved* |
| row 4 | SPEED | *reserved* |
| row 5 | MIX OUT | ENV OUT |

Control centres come from the shared grid in `rack/src/PanelGrid.hpp`, so its
rows line up with Quad Amp's and Drive Filter's.

## Behaviour

| Control | What it does |
|---|---|
| CLOCK IN | One sixteenth-note step per rising edge. The internal clock at TEMPO runs the steps when this is empty. |
| RESET IN | Back to before the first step, and a loaded sample back to its start. |
| TEMPO | 40 to 240 BPM, default 174. Drives the internal clock only. |
| LEVEL | 0 to 10 V, unity at 10 -- the same convention as the other modules. |
| SPEED | 0.25x to 4x. A loaded sample's playback rate, or the synthesised voices' pitch. |
| MIX OUT | The break. |
| ENV OUT | An envelope follower on the mix, 0 to 10 V. A modulation source to patch into whatever is being tested. |

With a sample loaded it plays as a loop, and is restarted at the top of every
four bars so it stays locked to the clock. A one-bar or four-bar loop at the
matching tempo is seamless; any other length will re-sync audibly, which is the
intended behaviour rather than a defect.

The file is chosen from the right-click menu, and **the patch stores its path,
not its audio** -- so a saved patch stays small and the sample stays the user's
own file. Reopening a patch on a machine without that file leaves the module on
its built-in break and reports why in the menu.

## What it does and does not do

**Does:** read RIFF/WAVE, PCM 8/16/24/32-bit and 32-bit float, any channel count,
downmixed to mono because these modules are mono as the hardware would be.
Rejects malformed files with a diagnostic rather than crashing; the tests feed
it truncated, corrupt and overlong-chunk input on purpose.

**Does not:** resample properly (playback is linear interpolation, fine for a
test source and not claimed to be more), play stereo, or model anything about
hardware. It approves no circuit, part or limit.
