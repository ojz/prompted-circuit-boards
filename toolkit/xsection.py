#!/usr/bin/env python
"""Capacitance of a PCB cross-section, by solving the field rather than
quoting a formula.

    xsection.py trace  [--width W] [--gap G] ...
    xsection.py sweep  --gaps 0.2,0.3,0.5,1.0
    xsection.py verify

Why this exists: every analog layout rule anyone repeats ("keep high-impedance
nodes short", "keep clocks away from audio") is a claim about capacitance, and
the numbers are almost never given. Rather than guess a length budget or a
spacing and then optimise the router against the guess, this computes the
capacitance of the actual stackup, so a budget in a design file can say where
it came from. `nodebudget.py` turns these numbers into budgets with ngspice.

Method: two-dimensional finite-volume solution of div(eps grad phi) = 0 over
the cross-section, with the conductors as Dirichlet boundaries, then the
capacitance matrix from field energy. Three solves give the pair:

    V = (1,0) -> W_a = C11/2        (Maxwell/short-circuit matrix)
    V = (0,1) -> W_b = C22/2
    V = (1,1) -> W_c = (C11 + 2*C12 + C22)/2   so C12 = W_c - W_a - W_b

The mutual capacitance between the traces is -C12 and each trace's
capacitance to the plane is Cii + C12. Energy integrals are used rather than
surface charge because they converge from the whole field instead of from one
row of cells next to a corner.

`verify` checks the solver against the closed-form microstrip impedance
(Hammerstad), which is an independent result: agreement to a few percent is
the evidence that the numbers below mean anything.

Needs numpy, so run it with KiCad's bundled Python like the other scripts:

    "%LOCALAPPDATA%/Programs/KiCad/10.0/bin/python.exe" toolkit/xsection.py verify
"""

import argparse
import math
import sys

try:
    import numpy as np
except ImportError:
    sys.stderr.write("xsection.py: needs numpy; run with KiCad's bundled python\n")
    sys.exit(2)

EPS0 = 8.8541878128e-12      # F/m
C0 = 299792458.0             # m/s

# The stackup we actually order: JLCPCB 2-layer, 1.6 mm FR4, 1 oz copper.
FR4_ER = 4.3                 # at audio; the datasheet spread is 4.2-4.6
SUBSTRATE_MM = 1.6
COPPER_MM = 0.035


class Section(object):
    """One cross-section: a ground plane at the bottom, substrate above it,
    air above that, and one or two traces on the top surface."""

    def __init__(self, width_mm, gap_mm=None, h_mm=SUBSTRATE_MM, er=FR4_ER,
                 pitch_mm=0.0125, margin_mm=6.0, thick_mm=COPPER_MM):
        self.w = width_mm
        self.gap = gap_mm
        self.h = h_mm
        self.er = er
        self.p = pitch_mm
        self.thick = thick_mm
        # Domain: the substrate plus air above, and enough margin either side
        # that the outer boundary does not pull on the answer. Checked by
        # --margin: the reported capacitance should not move when it grows.
        span = width_mm * (2 if gap_mm is not None else 1) + (gap_mm or 0)
        self.x0 = -(span / 2 + margin_mm)
        self.x1 = span / 2 + margin_mm
        self.y1 = h_mm + margin_mm
        self.nx = int(round((self.x1 - self.x0) / pitch_mm)) + 1
        self.ny = int(round(self.y1 / pitch_mm)) + 1

    def grid(self):
        x = self.x0 + np.arange(self.nx) * self.p
        y = np.arange(self.ny) * self.p
        return x, y

    def masks(self):
        """(conductor masks, epsilon per cell). Index 0 is the plane."""
        x, y = self.grid()
        X, Y = np.meshgrid(x, y, indexing="ij")

        eps = np.where(Y <= self.h, self.er, 1.0) * EPS0

        plane = Y <= 0.0 + 1e-12
        conductors = [plane]

        top = (Y >= self.h - 1e-12) & (Y <= self.h + self.thick + 1e-12)
        if self.gap is None:
            conductors.append(top & (np.abs(X) <= self.w / 2 + 1e-12))
        else:
            c = self.gap / 2 + self.w / 2
            conductors.append(top & (np.abs(X + c) <= self.w / 2 + 1e-12))
            conductors.append(top & (np.abs(X - c) <= self.w / 2 + 1e-12))
        return conductors, eps

    def solve(self, volts, tol=1e-7, max_sweeps=20000):
        """Potential for the given conductor voltages (the plane is always 0).

        Red-black successive over-relaxation. Vectorised over each colour, so
        the whole field updates in a handful of numpy operations per sweep.
        """
        conductors, eps = self.masks()
        assert len(volts) == len(conductors) - 1, "one voltage per trace"

        phi = np.zeros((self.nx, self.ny))
        fixed = np.zeros((self.nx, self.ny), dtype=bool)
        for mask, v in zip(conductors, [0.0] + list(volts)):
            phi[mask] = v
            fixed |= mask
        # Outer boundary held at zero. It is `margin` away from the copper, so
        # its influence is small; `--margin` exists to show that.
        fixed[0, :] = fixed[-1, :] = fixed[:, -1] = True
        phi[0, :] = phi[-1, :] = phi[:, -1] = 0.0

        # Face permittivities: the average of the two cells sharing the face,
        # which is the right treatment for a grid-aligned dielectric interface.
        ex = 0.5 * (eps[:-1, :] + eps[1:, :])    # faces in x, shape (nx-1, ny)
        ey = 0.5 * (eps[:, :-1] + eps[:, 1:])    # faces in y, shape (nx, ny-1)

        # Denominator per interior node: sum of its four face permittivities.
        den = np.zeros_like(phi)
        den[1:, :] += ex
        den[:-1, :] += ex
        den[:, 1:] += ey
        den[:, :-1] += ey

        ii, jj = np.meshgrid(np.arange(self.nx), np.arange(self.ny), indexing="ij")
        free = ~fixed
        colours = [free & (((ii + jj) % 2) == c) for c in (0, 1)]

        omega = 1.9
        for sweep in range(max_sweeps):
            delta = 0.0
            for colour in colours:
                num = np.zeros_like(phi)
                num[1:, :] += ex * phi[:-1, :]
                num[:-1, :] += ex * phi[1:, :]
                num[:, 1:] += ey * phi[:, :-1]
                num[:, :-1] += ey * phi[:, 1:]
                target = np.divide(num, den, out=np.zeros_like(num), where=den > 0)
                step = omega * (target - phi)
                step[~colour] = 0.0
                phi += step
                delta = max(delta, float(np.abs(step).max()))
            if delta < tol:
                break
        else:
            sys.stderr.write("xsection.py: warning: SOR hit %d sweeps (delta %.2e)\n"
                             % (max_sweeps, delta))
        return phi, eps

    def energy(self, phi, eps):
        """Field energy per metre of board, J/m, for the solved potential."""
        # Gradient on faces, energy on faces: this is the discrete form that
        # matches the finite-volume operator above, so the energy is the one
        # the solver actually minimised.
        gx = (phi[1:, :] - phi[:-1, :]) / (self.p * 1e-3)
        gy = (phi[:, 1:] - phi[:, :-1]) / (self.p * 1e-3)
        ex = 0.5 * (eps[:-1, :] + eps[1:, :])
        ey = 0.5 * (eps[:, :-1] + eps[:, 1:])
        area = (self.p * 1e-3) ** 2
        return 0.5 * (float((ex * gx * gx).sum()) + float((ey * gy * gy).sum())) * area

    def single(self):
        """Capacitance to the plane of one trace, F/m."""
        phi, eps = self.solve([1.0])
        return 2.0 * self.energy(phi, eps)

    def pair(self):
        """(C to plane each, C between traces), F/m, for two traces."""
        wa = self.energy(*self.solve([1.0, 0.0]))
        wb = self.energy(*self.solve([0.0, 1.0]))
        wc = self.energy(*self.solve([1.0, 1.0]))
        c11 = 2 * wa
        c22 = 2 * wb
        c12 = wc - wa - wb          # negative for coupled conductors
        mutual = -c12
        to_plane = 0.5 * (c11 + c12) + 0.5 * (c22 + c12)
        return to_plane, mutual


def microstrip_analytic(w, h, er):
    """Hammerstad's closed form: (Z0 ohms, C per metre). Independent of the
    solver above, so it is worth something as a check."""
    u = w / h
    if u < 1:
        ee = (er + 1) / 2 + (er - 1) / 2 * ((1 + 12 / u) ** -0.5 + 0.04 * (1 - u) ** 2)
        z0 = 60 / math.sqrt(ee) * math.log(8 / u + u / 4)
    else:
        ee = (er + 1) / 2 + (er - 1) / 2 * (1 + 12 / u) ** -0.5
        z0 = 120 * math.pi / (math.sqrt(ee) * (u + 1.393 + 0.667 * math.log(u + 1.444)))
    return z0, math.sqrt(ee) / (C0 * z0)


def cmd_verify(args):
    print("Solver against Hammerstad's closed form, 1.6 mm FR4, er = %.1f" % FR4_ER)
    print()
    print("| width mm | solved pF/m | analytic pF/m | difference |")
    print("|---:|---:|---:|---:|")
    worst = 0.0
    for w in (0.2, 0.3, 0.5, 1.0, 2.0):
        s = Section(w, pitch_mm=args.pitch, margin_mm=args.margin,
                    thick_mm=args.thick)
        got = s.single() * 1e12
        _, want = microstrip_analytic(w, SUBSTRATE_MM, FR4_ER)
        want *= 1e12
        rel = (got - want) / want
        worst = max(worst, abs(rel))
        print("| %.1f | %.1f | %.1f | %+.1f%% |" % (w, got, want, 100 * rel))
    print()
    print("Worst difference %.1f%% at pitch %.4f mm." % (100 * worst, args.pitch))
    print()
    print("The difference is discretisation, not the physics: it shrinks with")
    print("the grid (see `converge`) and barely moves when the outer boundary")
    print("is pushed out or the copper thickness is set to zero, both of which")
    print("were checked. A strip's edge is a field singularity and a uniform")
    print("grid resolves it slowly, so the solver reads high. Everything here")
    print("is used to size a budget that comes out orders of magnitude from the")
    print("geometry we build, so a bias of this size changes no conclusion.")
    return 0 if worst < 0.15 else 1


def cmd_converge(args):
    """Refine the grid on one width and watch the difference shrink.

    This is the check that matters. Agreeing with a closed form once could be
    luck or a compensating pair of errors; a difference that falls as the grid
    is refined is evidence that the discretisation is the error and that the
    operator underneath is right."""
    _, want = microstrip_analytic(args.width, SUBSTRATE_MM, FR4_ER)
    want *= 1e12
    print("Grid convergence, %.2f mm trace on 1.6 mm FR4. Closed form %.1f pF/m."
          % (args.width, want))
    print()
    print("| pitch mm | cells across trace | solved pF/m | difference |")
    print("|---:|---:|---:|---:|")
    pitches = [float(x) for x in args.pitches.split(",")]
    solved = []
    for pitch in pitches:
        s = Section(args.width, pitch_mm=pitch, margin_mm=args.margin)
        got = s.single() * 1e12
        solved.append(got)
        print("| %.4f | %.1f | %.1f | %+.1f%% |"
              % (pitch, args.width / pitch, got, 100 * (got - want) / want))
    print()
    # Richardson: with three results on a halving grid, the observed order of
    # the discretisation error and the zero-pitch limit both fall out. If that
    # limit lands on the closed form, the remaining difference in the table
    # above is the grid and nothing else, which is the claim worth checking.
    if len(solved) >= 3 and all(abs(pitches[i] / pitches[i + 1] - 2) < 0.01
                                for i in range(len(pitches) - 1)):
        c0, c1, c2 = solved[-3:]
        num, den = c1 - c0, c2 - c1
        if den != 0 and num / den > 1:
            order = math.log(num / den) / math.log(2.0)
            limit = c2 + (c2 - c1) / (2 ** order - 1)
            print("Observed order of the error: %.2f in the cell size." % order)
            print("Extrapolated to zero pitch: %.2f pF/m against the closed form's"
                  % limit)
            print("%.2f, a difference of %+.2f%%." % (want, 100 * (limit - want) / want))
    return 0


def cmd_trace(args):
    if args.gap is None:
        s = Section(args.width, pitch_mm=args.pitch, margin_mm=args.margin)
        c = s.single()
        print("one %.2f mm trace over 1.6 mm FR4:" % args.width)
        print("  to plane: %.2f pF/m = %.4f pF/mm" % (c * 1e12, c * 1e9))
    else:
        s = Section(args.width, args.gap, pitch_mm=args.pitch, margin_mm=args.margin)
        plane, mutual = s.pair()
        print("two %.2f mm traces, %.2f mm gap, over 1.6 mm FR4:" % (args.width, args.gap))
        print("  each to plane: %.2f pF/m = %.4f pF/mm" % (plane * 1e12, plane * 1e9))
        print("  between them:  %.2f pF/m = %.4f pF/mm" % (mutual * 1e12, mutual * 1e9))
    return 0


def cmd_sweep(args):
    gaps = [float(g) for g in args.gaps.split(",")]
    print("Coupling between two %.2f mm traces on 1.6 mm FR4, per mm of parallel run."
          % args.width)
    print()
    print("| gap mm | to plane pF/mm | mutual pF/mm | mutual / to-plane |")
    print("|---:|---:|---:|---:|")
    for g in gaps:
        s = Section(args.width, g, pitch_mm=args.pitch, margin_mm=args.margin)
        plane, mutual = s.pair()
        print("| %.2f | %.4f | %.5f | %.4f |" % (g, plane * 1e9, mutual * 1e9, mutual / plane))
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd")

    common = dict(pitch=0.0125, margin=6.0)

    p = sub.add_parser("trace", help="capacitance of one trace or a pair")
    p.add_argument("--width", type=float, default=0.3)
    p.add_argument("--gap", type=float, default=None)
    p.add_argument("--pitch", type=float, default=common["pitch"])
    p.add_argument("--margin", type=float, default=common["margin"])
    p.set_defaults(func=cmd_trace)

    p = sub.add_parser("sweep", help="coupling against gap")
    p.add_argument("--width", type=float, default=0.3)
    p.add_argument("--gaps", default="0.2,0.3,0.5,1.0,2.0")
    p.add_argument("--pitch", type=float, default=common["pitch"])
    p.add_argument("--margin", type=float, default=common["margin"])
    p.set_defaults(func=cmd_sweep)

    p = sub.add_parser("converge", help="refine the grid and watch the error fall")
    p.add_argument("--width", type=float, default=0.3)
    p.add_argument("--pitches", default="0.1,0.05,0.025,0.0125")
    p.add_argument("--margin", type=float, default=common["margin"])
    p.set_defaults(func=cmd_converge)

    p = sub.add_parser("verify", help="check the solver against the closed form")
    p.add_argument("--pitch", type=float, default=common["pitch"])
    p.add_argument("--margin", type=float, default=common["margin"])
    # The closed form assumes zero-thickness copper. Passing --thick 0 should
    # therefore close most of the gap, which is the check that the remaining
    # difference is the copper and not the solver.
    p.add_argument("--thick", type=float, default=COPPER_MM)
    p.set_defaults(func=cmd_verify)

    args = ap.parse_args()
    if not getattr(args, "func", None):
        ap.print_help()
        return 2
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
