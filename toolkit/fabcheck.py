"""Assembly and gerber sanity checks on a KiKit JLCPCB bundle.

    python fabcheck.py <filled-board.kicad_pcb> <fab-dir> --assembly|--no-assembly

Run with KiCad's bundled python (pcbnew is imported). Exit status 0 when every
check passes (warnings allowed), 1 on any failure, 2 on usage or I/O errors.

Checks:
  * gerbers.zip holds Edge.Cuts, both copper layers, both mask layers,
    paste or silk on each side, and at least one drill file
  * with --assembly: bom.csv and pos.csv exist; the designator sets agree;
    every placement is on one side; the set of footprints in the board that
    are not marked exclude_from_pos_files equals the pos.csv set, on the same
    side; every placed footprint carries an LCSC Part # field
  * an empty CPL is a pass when nothing is placeable, and a loud warning
    when the board does carry LCSC Part # fields
  * with --no-assembly: no bom.csv/pos.csv; footprints that are not excluded
    from position files are reported (they will be hand-installed)
"""
import csv
import os
import sys
import zipfile

failures = []
warnings = []


def fail(msg):
    failures.append(msg)
    print("   FAIL: " + msg)


def warn(msg):
    warnings.append(msg)
    print("   WARNING: " + msg)


def ok(msg):
    print("   ok: " + msg)


def read_refs_pos(path):
    """pos.csv -> {designator: layer}."""
    out = {}
    with open(path, newline="", encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))
    for r in rows:
        ref = (r.get("Designator") or "").strip()
        if not ref:
            fail("pos.csv row without Designator: %r" % (r,))
            continue
        if ref in out:
            fail("pos.csv lists %s twice" % ref)
        out[ref] = (r.get("Layer") or "").strip()
    return out


def read_refs_bom(path):
    """bom.csv -> set of designators (the Designator column is comma-joined)."""
    refs = set()
    with open(path, newline="", encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))
    for r in rows:
        for ref in (r.get("Designator") or "").split(","):
            ref = ref.strip()
            if not ref:
                continue
            if ref in refs:
                fail("bom.csv lists %s twice" % ref)
            refs.add(ref)
        if not (r.get("LCSC") or "").strip():
            fail("bom.csv row without LCSC number: %s" % (r.get("Designator"),))
    return refs


def check_gerbers(fabdir):
    zpath = os.path.join(fabdir, "gerbers.zip")
    if not os.path.isfile(zpath):
        fail("gerbers.zip missing")
        return
    with zipfile.ZipFile(zpath) as z:
        infos = [i for i in z.infolist() if not i.is_dir()]
    names = [i.filename for i in infos]
    lower = [n.lower() for n in names]
    for i in infos:
        if i.file_size == 0:
            fail("gerbers.zip: %s is empty" % i.filename)

    def has(*preds):
        return any(all(p(n) for p in preds) for n in lower)

    def ext(e):
        return lambda n: n.endswith(e)

    def contains(s):
        return lambda n: s in n

    required = [
        ("Edge.Cuts", has(ext(".gm1")) or has(contains("edgecuts")) or has(contains("edge_cuts")) or has(ext(".gko"))),
        ("F.Cu", has(ext(".gtl")) or has(contains("cutop")) or has(contains("f_cu"))),
        ("B.Cu", has(ext(".gbl")) or has(contains("cubottom")) or has(contains("b_cu"))),
        ("F.Mask", has(ext(".gts")) or has(contains("masktop")) or has(contains("f_mask"))),
        ("B.Mask", has(ext(".gbs")) or has(contains("maskbottom")) or has(contains("b_mask"))),
        ("F.Paste or F.SilkS", has(ext(".gtp")) or has(ext(".gto")) or has(contains("pastetop")) or has(contains("silktop"))),
        ("B.Paste or B.SilkS", has(ext(".gbp")) or has(ext(".gbo")) or has(contains("pastebottom")) or has(contains("silkbottom"))),
        ("drill file", has(ext(".drl")) or has(ext(".xln"))),
    ]
    missing = [name for name, present in required if not present]
    if missing:
        fail("gerbers.zip lacks: %s (contains %s)" % (", ".join(missing), ", ".join(names)))
    else:
        ok("gerbers.zip has %d files: edge cuts, both copper, both mask, paste/silk, drill" % len(names))


def board_footprints(board_path):
    import pcbnew  # KiCad's bundled python only

    board = pcbnew.LoadBoard(board_path)
    placed = {}   # ref -> side letter, for footprints that belong in the CPL
    excluded = set()
    lcsc = {}     # ref -> LCSC Part # (non-empty)
    for fp in board.GetFootprints():
        ref = fp.GetReference()
        fields = fp.GetFieldsText()
        part = (fields.get("LCSC Part #") or "").strip()
        if part:
            lcsc[ref] = part
        if fp.GetAttributes() & pcbnew.FP_EXCLUDE_FROM_POS_FILES:
            excluded.add(ref)
        else:
            placed[ref] = "B" if fp.GetLayer() == pcbnew.B_Cu else "T"
    return placed, excluded, lcsc


def fmt(refs):
    return ", ".join(sorted(refs)) if refs else "(none)"


def main(argv):
    if len(argv) != 4 or argv[3] not in ("--assembly", "--no-assembly"):
        print(__doc__)
        return 2
    board_path, fabdir, mode = argv[1], argv[2], argv[3]
    assembly = mode == "--assembly"
    if not os.path.isfile(board_path):
        print("fabcheck: board not found: " + board_path)
        return 2
    if not os.path.isdir(fabdir):
        print("fabcheck: fab directory not found: " + fabdir)
        return 2

    print("== Fabrication bundle checks")
    check_gerbers(fabdir)

    placed, excluded, lcsc = board_footprints(board_path)
    print("   board: %d footprints, %d in position files, %d excluded (hand-installed), %d with LCSC Part #"
          % (len(placed) + len(excluded), len(placed), len(excluded), len(lcsc)))

    bom_path = os.path.join(fabdir, "bom.csv")
    pos_path = os.path.join(fabdir, "pos.csv")

    if not assembly:
        for p in (bom_path, pos_path):
            if os.path.exists(p):
                fail("%s present although no assembly was requested" % os.path.basename(p))
        if lcsc:
            fail("board carries LCSC Part # on %s but no assembly was requested" % fmt(lcsc))
        if placed:
            warn("%d footprints are not marked exclude_from_pos_files and have no LCSC Part #; "
                 "they are treated as hand-installed: %s" % (len(placed), fmt(placed)))
        else:
            ok("no assembly requested and no placeable footprints")
        return finish()

    if not os.path.isfile(bom_path):
        fail("bom.csv missing (assembly requested)")
    if not os.path.isfile(pos_path):
        fail("pos.csv missing (assembly requested)")
    if failures:
        return finish()

    bom_refs = read_refs_bom(bom_path)
    pos = read_refs_pos(pos_path)
    pos_refs = set(pos)

    if bom_refs != pos_refs:
        fail("bom.csv and pos.csv designators differ; only in BOM: %s; only in CPL: %s"
             % (fmt(bom_refs - pos_refs), fmt(pos_refs - bom_refs)))
    else:
        ok("bom.csv and pos.csv list the same %d designators" % len(pos_refs))

    sides = set(pos.values())
    if len(sides) > 1:
        fail("pos.csv places parts on more than one side: %s (JLCPCB assembles one side per order)"
             % ", ".join(sorted(sides)))
    elif sides:
        ok("all placements on side %s" % sides.pop())

    board_refs = set(placed)
    if board_refs != pos_refs:
        fail("footprints not excluded from position files differ from pos.csv; only in board: %s; only in CPL: %s"
             % (fmt(board_refs - pos_refs), fmt(pos_refs - board_refs)))
    else:
        ok("every non-excluded footprint is in pos.csv and vice versa (%d)" % len(board_refs))
        wrong = [r for r in sorted(pos_refs) if pos[r][:1].upper() != placed[r]]
        if wrong:
            fail("pos.csv side disagrees with the board for: %s" % fmt(wrong))

    no_part = board_refs - set(lcsc)
    if no_part:
        fail("placed footprints without LCSC Part #: %s" % fmt(no_part))
    hand_with_part = set(lcsc) & excluded
    if hand_with_part:
        warn("LCSC Part # on hand-installed (excluded) footprints, ignored by assembly: %s" % fmt(hand_with_part))

    if not pos_refs:
        if lcsc:
            print("   " + "!" * 70)
            warn("pos.csv is EMPTY although %d footprints carry LCSC Part # (%s); "
                 "JLCPCB will assemble nothing" % (len(lcsc), fmt(lcsc)))
            print("   " + "!" * 70)
        else:
            ok("empty CPL and no placeable footprints: nothing to assemble")

    return finish()


def finish():
    if failures:
        print("   fabcheck: %d failure(s), %d warning(s)" % (len(failures), len(warnings)))
        return 1
    print("   fabcheck: passed, %d warning(s)" % len(warnings))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
