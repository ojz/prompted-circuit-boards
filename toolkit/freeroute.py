#!/usr/bin/env python
"""Route a KiCad board with Freerouting, headlessly.

    freeroute.py <unrouted.kicad_pcb> <routed.kicad_pcb> [--passes N] [--jar PATH]

KiCad's own Specctra exporter and importer do the format work (pcbnew.
ExportSpecctraDSN / ImportSpecctraSES), so nothing here parses DSN or SES.
Run it with KiCad's bundled Python, which is the only interpreter that has
pcbnew:

    "%LOCALAPPDATA%/Programs/KiCad/10.0/bin/python.exe" toolkit/freeroute.py ...

Freerouting is a comparison baseline for pcbgen's own router, not part of
generation: nothing in modules/ is ever produced this way. The board it writes
is scored by the benchmark and thrown away.

Exit codes: 0 routed, 2 a tool is missing, 3 Freerouting failed or produced
nothing, 4 the import produced no copper.
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile

JAR_CANDIDATES = [
    os.path.join(os.environ.get("LOCALAPPDATA", ""), "freerouting", "freerouting-2.4.1.jar"),
    os.path.join(os.environ.get("LOCALAPPDATA", ""), "freerouting", "freerouting.jar"),
]


def find_jar(explicit):
    if explicit:
        if not os.path.isfile(explicit):
            fail(2, "no jar at %s" % explicit)
        return explicit
    env = os.environ.get("FREEROUTING_JAR")
    if env:
        if not os.path.isfile(env):
            fail(2, "FREEROUTING_JAR points at nothing: %s" % env)
        return env
    for c in JAR_CANDIDATES:
        if os.path.isfile(c):
            return c
    fail(2, "freerouting jar not found; set FREEROUTING_JAR")


def fail(code, msg):
    sys.stderr.write("freeroute.py: %s\n" % msg)
    sys.exit(code)


def count_copper(board):
    """Tracks and vias on a board, so we can tell 'routed' from 'did nothing'."""
    import pcbnew
    tracks = vias = 0
    for t in board.GetTracks():
        if isinstance(t, pcbnew.PCB_VIA):
            vias += 1
        else:
            tracks += 1
    return tracks, vias


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("board")
    ap.add_argument("out")
    ap.add_argument("--passes", type=int, default=10)
    ap.add_argument("--jar", default=None)
    ap.add_argument("--threads", type=int, default=1)
    args = ap.parse_args()

    try:
        import pcbnew
    except ImportError:
        fail(2, "no pcbnew; run this with KiCad's bundled python")

    if not os.path.isfile(args.board):
        fail(2, "no such board: %s" % args.board)
    jar = find_jar(args.jar)
    java = shutil.which("java")
    if not java:
        fail(2, "java not on PATH")

    work = tempfile.mkdtemp(prefix="freeroute-")
    dsn = os.path.join(work, "board.dsn")
    ses = os.path.join(work, "board.ses")
    try:
        board = pcbnew.LoadBoard(args.board)
        before = count_copper(board)
        if not pcbnew.ExportSpecctraDSN(board, dsn):
            fail(3, "Specctra DSN export failed")
        if not os.path.isfile(dsn) or os.path.getsize(dsn) == 0:
            fail(3, "DSN export wrote nothing")

        cmd = [java, "-jar", jar, "-de", dsn, "-do", ses,
               "-mp", str(args.passes), "-mt", str(args.threads)]
        sys.stderr.write("freeroute.py: %s\n" % " ".join(cmd))
        proc = subprocess.run(cmd, capture_output=True, text=True)
        # Freerouting is chatty on stdout and reports real problems there too,
        # so keep the tail either way; it is the only diagnostic when it fails.
        tail = (proc.stdout or "")[-2000:] + (proc.stderr or "")[-2000:]
        if not os.path.isfile(ses) or os.path.getsize(ses) == 0:
            sys.stderr.write(tail + "\n")
            fail(3, "Freerouting produced no session file (exit %d)" % proc.returncode)

        # Import onto a freshly loaded board: the exporter may have annotated
        # the in-memory one.
        routed = pcbnew.LoadBoard(args.board)
        if not pcbnew.ImportSpecctraSES(routed, ses):
            fail(3, "Specctra SES import failed")
        tracks, vias = count_copper(routed)
        if tracks <= before[0]:
            sys.stderr.write(tail + "\n")
            fail(4, "import added no copper (%d tracks before, %d after)" % (before[0], tracks))
        routed.Save(args.out)
        print("freeroute.py: %d tracks, %d vias -> %s" % (tracks, vias, args.out))
        return 0
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
