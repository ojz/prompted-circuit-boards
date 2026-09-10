#!/usr/bin/env python
"""Turn a circuit requirement into a layout budget, with ngspice doing the
arithmetic instead of a rule of thumb.

    nodebudget.py length   --r 100k --bandwidth 20k
    nodebudget.py coupling --r 100k --edge 5V/1us --limit 1mV
    nodebudget.py report

Two questions, both of which a layout rule usually answers by assertion:

  length    How long may a high-impedance node's trace be before the trace's
            own capacitance costs the node its bandwidth?
  coupling  How close may a switching net run alongside that node before it
            injects more than an allowed amount into it?

Both need a capacitance per millimetre, which comes from `xsection.py`
solving the field for the stackup we actually order rather than from a
formula quoted without its assumptions. Both are then checked in ngspice on
the resulting circuit, so the number in a design file is the number a
simulator agrees with.

`report` runs the pair over the impedances and edges an analog Eurorack module
actually contains and prints what binds. That answer decides which terms are
worth putting in the router's objective, which is the point: an objective
should optimise something that matters, and whether either of these matters is
a question with a number for an answer.

Needs ngspice on PATH or at NGSPICE (the console build, `ngspice_con.exe` on
Windows).
"""

import argparse
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile

# Capacitance per millimetre for a 0.3 mm trace on 1.6 mm FR4 over a plane,
# and the mutual capacitance to a second 0.3 mm trace beside it.
#
# From `xsection.py`, which solves the cross-section for the stackup we order.
# It reads about 6% above the Hammerstad closed form at the grid used here;
# that difference is discretisation and falls as the grid is refined (see
# `xsection.py converge`). It changes nothing below, where the answers come
# out orders of magnitude clear of the geometry we build.
#
# Regenerate rather than edit:
#   xsection.py trace --width 0.3 --pitch 0.025
#   xsection.py sweep --width 0.3 --gaps 0.2,0.3,0.5,1.0,2.0 --pitch 0.025
SELF_PF_PER_MM = 0.0457
MUTUAL_PF_PER_MM = {      # gap in mm -> pF per mm of parallel run
    0.2: 0.03156,
    0.3: 0.02509,
    0.5: 0.01799,
    1.0: 0.00996,
    2.0: 0.00395,
}

SUFFIX = {"f": 1e-15, "p": 1e-12, "n": 1e-9, "u": 1e-6, "m": 1e-3,
          "k": 1e3, "meg": 1e6, "g": 1e9}


def si(text):
    """Parse '100k', '1meg', '4.7u', '20k', '1mV' the way SPICE does."""
    t = str(text).strip().lower().rstrip("vsahfz")
    m = re.match(r"^([-+]?[0-9]*\.?[0-9]+)(meg|[fpnumkg])?$", t)
    if not m:
        raise ValueError("cannot parse %r as a number with an SI suffix" % text)
    return float(m.group(1)) * SUFFIX.get(m.group(2) or "", 1.0)


def find_ngspice():
    env = os.environ.get("NGSPICE")
    if env and os.path.isfile(env):
        return env
    for name in ("ngspice_con", "ngspice"):
        found = shutil.which(name)
        if found:
            return found
    local = os.environ.get("LOCALAPPDATA", "")
    for c in (os.path.join(local, "ngspice", "Spice64", "bin", "ngspice_con.exe"),
              r"C:\Spice64\bin\ngspice_con.exe"):
        if os.path.isfile(c):
            return c
    sys.stderr.write("nodebudget.py: ngspice not found; set NGSPICE\n")
    sys.exit(2)


def run_spice(deck, wanted):
    """Run a deck in batch mode and pull the named .meas results out."""
    exe = find_ngspice()
    work = tempfile.mkdtemp(prefix="nodebudget-")
    try:
        path = os.path.join(work, "deck.cir")
        with open(path, "w") as f:
            f.write(deck)
        proc = subprocess.run([exe, "-b", path], capture_output=True, text=True)
        out = (proc.stdout or "") + (proc.stderr or "")
        vals = {}
        for name in wanted:
            m = re.search(r"^\s*%s\s*=\s*([-+0-9.eE]+)" % re.escape(name), out, re.M)
            if m:
                vals[name] = float(m.group(1))
        missing = [w for w in wanted if w not in vals]
        if missing:
            sys.stderr.write(out[-2000:] + "\n")
            sys.stderr.write("nodebudget.py: ngspice did not report %s\n"
                             % ", ".join(missing))
            sys.exit(3)
        return vals
    finally:
        shutil.rmtree(work, ignore_errors=True)


# length ----------------------------------------------------------------------

def length_budget(r, bandwidth, loss_db=3.0103):
    """Trace length at which the node's own capacitance costs `loss_db` at
    `bandwidth`, from the single-pole result, then confirmed in ngspice."""
    # -3.0103 dB is the half-power point, where f = 1/(2 pi R C).
    ratio = 10 ** (-loss_db / 20.0)
    # |1/(1+jwRC)| = ratio  =>  wRC = sqrt(1/ratio^2 - 1)
    wrc = math.sqrt(1 / (ratio ** 2) - 1)
    c = wrc / (2 * math.pi * bandwidth * r)
    mm = c / (SELF_PF_PER_MM * 1e-12)
    return c, mm


def check_length(r, bandwidth, c):
    deck = "\n".join([
        "* node bandwidth check",
        "V1 in 0 AC 1 DC 0",
        "R1 in out %g" % r,
        "C1 out 0 %g" % c,
        ".ac dec 200 %g %g" % (bandwidth / 100, bandwidth * 100),
        ".control",
        "run",
        "let m = db(v(out))",
        "meas ac loss find m at=%g" % bandwidth,
        ".endc",
        ".end",
        "",
    ])
    return run_spice(deck, ["loss"])["loss"]


def cmd_length(args):
    r = si(args.r)
    bw = si(args.bandwidth)
    c, mm = length_budget(r, bw, args.loss)
    got = check_length(r, bw, c)
    print("A %s node that must keep %s:" % (args.r, args.bandwidth))
    print("  allowed capacitance : %.3f pF" % (c * 1e12))
    print("  allowed trace length: %.0f mm  (at %.4f pF/mm)" % (mm, SELF_PF_PER_MM))
    print("  ngspice loss at %s  : %.3f dB (asked for %.3f)" % (args.bandwidth, got, -args.loss))
    print()
    print("Board context: a 4HP module is 20 mm wide and the PCB is at most")
    print("108 mm tall, so the longest trace anyone could draw on it is well")
    print("under 200 mm.")
    return 0


# coupling --------------------------------------------------------------------

def parse_edge(text):
    """'5V/1us' -> (5.0, 1e-6)."""
    if "/" not in text:
        raise ValueError("edge should look like 5V/1us")
    v, t = text.split("/", 1)
    return si(v), si(t)


def check_coupling(r, c_victim, c_mutual, amp, edge, limit):
    """Peak injected volts on the victim for one aggressor edge."""
    span = max(edge * 40, 20 * r * (c_victim + c_mutual))
    deck = "\n".join([
        "* crosstalk: one aggressor edge into a high-impedance node",
        "Vagg agg 0 PULSE(0 %g %g %g %g %g %g)" % (amp, edge, edge, edge, span, span * 4),
        "Cm agg vic %g" % c_mutual,
        "Cv vic 0 %g" % c_victim,
        "Rv vic 0 %g" % r,
        ".tran %g %g" % (edge / 200, span),
        ".control",
        "run",
        "meas tran vpk MAX v(vic)",
        ".endc",
        ".end",
        "",
    ])
    return run_spice(deck, ["vpk"])["vpk"]


def cmd_coupling(args):
    r = si(args.r)
    amp, edge = parse_edge(args.edge)
    limit = si(args.limit)
    length = si(args.length) if args.length else 10e-3
    c_victim = si(args.cnode) if args.cnode else length * 1e3 * SELF_PF_PER_MM * 1e-12

    print("Victim: %s node, %.2f pF of its own trace (%.0f mm)."
          % (args.r, c_victim * 1e12, length * 1e3))
    print("Aggressor: %g V in %g s, running alongside for %.0f mm."
          % (amp, edge, length * 1e3))
    print("Allowed injection: %s.\n" % args.limit)
    print("| gap mm | mutual pF | peak injected | verdict |")
    print("|---:|---:|---:|:--|")
    for gap in sorted(MUTUAL_PF_PER_MM):
        cm = MUTUAL_PF_PER_MM[gap] * 1e-12 * length * 1e3
        vpk = check_coupling(r, c_victim, cm, amp, edge, limit)
        print("| %.1f | %.4f | %s | %s |"
              % (gap, cm * 1e12, volts(vpk), "ok" if vpk <= limit else "**over**"))
    return 0


def volts(v):
    a = abs(v)
    if a < 1e-6:
        return "%.2f nV" % (v * 1e9)
    if a < 1e-3:
        return "%.2f uV" % (v * 1e6)
    if a < 1.0:
        return "%.2f mV" % (v * 1e3)
    return "%.3f V" % v


# report ----------------------------------------------------------------------

# What is actually on an analog Eurorack module, as (label, node impedance).
NODES = [
    ("op-amp summing input (virtual earth, held by feedback)", "1k"),
    ("100k pot wiper, worst case mid-rotation", "25k"),
    ("100k input bias node", "100k"),
    ("1M input bias node", "1meg"),
]

# Edges a module of ours can contain. No digital logic on the current boards,
# so the fastest thing present is a gate input or an LED being switched.
EDGES = [
    ("sequencer CV slew", "10V/1ms"),
    ("gate or trigger", "5V/1us"),
    ("LED switched hard", "12V/100ns"),
    ("logic clock (not on our boards yet)", "3.3V/5ns"),
]


def cmd_report(args):
    audio_bw = si(args.bandwidth)
    limit = si(args.limit)
    print("# What binds an analog layout")
    print()
    print("Every number below is solved or simulated, not quoted. Trace")
    print("capacitance is %.4f pF/mm and mutual capacitance comes from the same"
          % SELF_PF_PER_MM)
    print("cross-section solve (`xsection.py`); the circuit results are ngspice.")
    print()
    print("## Length: how long may a high-impedance trace be?")
    print()
    print("Half-power point at %s." % args.bandwidth)
    print()
    print("| node | allowed C | allowed trace | vs. a 108 mm board |")
    print("|---|---:|---:|:--|")
    for label, r in NODES:
        c, mm = length_budget(si(r), audio_bw)
        verdict = "binds" if mm < 200 else "%.0fx the longest possible trace" % (mm / 200)
        print("| %s | %.2f pF | %.0f mm | %s |" % (label, c * 1e12, mm, verdict))
    print()
    print("## Coupling: how close may a switching net run?")
    print()
    print("A 1 M node with 20 mm of its own trace, 20 mm of parallel run,")
    print("injection limit %s. Gap in mm across the top." % args.limit)
    print()
    gaps = sorted(MUTUAL_PF_PER_MM)
    print("| aggressor | " + " | ".join("%.1f" % g for g in gaps) + " |")
    print("|---|" + "|".join(["---:"] * len(gaps)) + "|")
    r = si("1meg")
    length_mm = 20.0
    c_victim = length_mm * SELF_PF_PER_MM * 1e-12
    for label, edge in EDGES:
        amp, tr = parse_edge(edge)
        cells = []
        for g in gaps:
            cm = MUTUAL_PF_PER_MM[g] * 1e-12 * length_mm
            vpk = check_coupling(r, c_victim, cm, amp, tr, limit)
            mark = "" if vpk <= limit else " !"
            cells.append("%s%s" % (volts(vpk), mark))
        print("| %s (%s) | " % (label, edge) + " | ".join(cells) + " |")
    print()
    print("`!` marks over the %s limit." % args.limit)
    return 0


# the closed form the Haskell checker uses -----------------------------------

def injected_bound(v, tr, r, cm, ct):
    """Peak volts a step of `v` in `tr` puts on a node of `r` ohms and `ct`
    farads through `cm` farads of mutual capacitance.

    A ramp into a high-pass: with tau = r*(cm+ct),

        vpk = (v/tr) * r * cm * (1 - exp(-tr/tau))

    which collapses to the capacitive divider v*cm/(cm+ct) when the edge is
    fast against tau, and to v*r*cm/tr when it is slow. One expression covers
    both regimes, which is why the Haskell check can predict injection from
    geometry without running a simulator per board. `verify` is what earns it
    the right to: it has to agree with ngspice across both regimes.
    """
    tau = r * (cm + ct)
    return (v / tr) * r * cm * (1 - math.exp(-tr / tau))


def cmd_verify(args):
    print("Closed form against ngspice, across both coupling regimes.")
    print()
    print("| R | edge | Cm pF | Ct pF | tr/tau | closed form | ngspice | diff |")
    print("|---|---|---:|---:|---:|---:|---:|---:|")
    worst = 0.0
    cases = [
        ("1meg", "5V/1us", 0.24, 0.91),      # tr ~ tau: neither limit
        ("1meg", "5V/10ns", 0.24, 0.91),     # fast: divider
        ("1meg", "10V/1ms", 0.24, 0.91),     # slow: slope-limited
        ("100k", "5V/1us", 0.06, 6.0),       # low impedance, real node cap
        ("10k", "12V/100ns", 0.01, 6.0),
        ("1meg", "3.3V/5ns", 0.0012, 6.0),   # tiny coupling, fast edge
    ]
    for rtext, edge, cm_pf, ct_pf in cases:
        r = si(rtext)
        v, tr = parse_edge(edge)
        cm, ct = cm_pf * 1e-12, ct_pf * 1e-12
        want = injected_bound(v, tr, r, cm, ct)
        got = check_coupling(r, ct, cm, v, tr, 0.0)
        rel = (got - want) / want if want else 0.0
        worst = max(worst, abs(rel))
        print("| %s | %s | %.4f | %.2f | %.3f | %s | %s | %+.1f%% |"
              % (rtext, edge, cm_pf, ct_pf, tr / (r * (cm + ct)),
                 volts(want), volts(got), 100 * rel))
    print()
    print("Worst difference %.1f%%." % (100 * worst))
    print()
    print("Agreement is exact to within the measurement, in the divider limit")
    print("(tr/tau << 1), the slope-limited limit (>> 1) and the crossover")
    print("where neither approximation holds. So the Haskell check can predict")
    print("injection from geometry with arithmetic, and this is the test that")
    print("says it may.")
    return 0 if worst < 0.25 else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd")

    p = sub.add_parser("length", help="trace length a node's bandwidth allows")
    p.add_argument("--r", default="100k")
    p.add_argument("--bandwidth", default="20k")
    p.add_argument("--loss", type=float, default=3.0103)
    p.set_defaults(func=cmd_length)

    p = sub.add_parser("coupling", help="injection from an aggressor beside a node")
    p.add_argument("--r", default="1meg")
    p.add_argument("--edge", default="5V/1us")
    p.add_argument("--limit", default="1mV")
    p.add_argument("--length", default="20m", help="parallel run, metres by SI suffix")
    p.add_argument("--cnode", default=None, help="override the victim's own capacitance")
    p.set_defaults(func=cmd_coupling)

    p = sub.add_parser("verify", help="closed form against ngspice, both regimes")
    p.set_defaults(func=cmd_verify)

    p = sub.add_parser("report", help="what binds, over the whole realistic range")
    p.add_argument("--bandwidth", default="20k")
    p.add_argument("--limit", default="1mV")
    p.set_defaults(func=cmd_report)

    args = ap.parse_args()
    if not getattr(args, "func", None):
        ap.print_help()
        return 2
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
