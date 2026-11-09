"""game-icons.net SVGs -> our glyph outlines (CC BY 3.0: credited in NOTICE.md and the licence screen).

  python tools/art/gi_import.py                 tools/art/gi_icons.json -> tools/art/gi_paths.luau and gi_units.json ->
                                                tools/art/gi_units.luau (the map's ship and missile sprites), and copies each
                                                source SVG to tools/art/game-icons/<author>/<file>.svg
  python tools/art/gi_import.py --preview OUT.luau author/file.svg|name ...   candidates, keyed by their path (no copy)

Each icon's white path is flattened to polygons (curves sampled) and fitted, aspect kept, into the 64-unit design grid
inside a margin (MARGIN units, or the json entry's "margin"); tools/art/icons.luau draws them as { "path", ... }.
The game-icons checkout: GI_DIR, default ~/tools/ext/game-icons."""
import json, os, re, shutil, sys
from svgelements import SVG, Path, Shape, Close, Move, Line, CubicBezier, QuadraticBezier, Arc

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GI = os.environ.get("GI_DIR", os.path.expanduser("~/tools/ext/game-icons"))
MARGIN = 2.0
STEPS = {CubicBezier: 10, QuadraticBezier: 8, Arc: 12}


def contours(svg_path):
    svg = SVG.parse(svg_path)
    out = []
    for el in svg.elements():
        if not isinstance(el, Shape):
            continue
        fill = str(el.fill).lower() if el.fill is not None else ""
        if fill in ("#000000", "#000", "black", "none", "") and "fff" not in fill:
            continue  # the black ground square
        p = Path(el)
        p.reify()
        cur = []
        for seg in p:
            if isinstance(seg, Move):
                if len(cur) >= 6:
                    out.append(cur)
                cur = [seg.end.x, seg.end.y]
            elif isinstance(seg, Close):
                if len(cur) >= 6:
                    out.append(cur)
                cur = []
            elif isinstance(seg, Line):
                cur += [seg.end.x, seg.end.y]
            else:
                n = STEPS.get(type(seg), 10)
                for k in range(1, n + 1):
                    q = seg.point(k / n)
                    cur += [q.x, q.y]
        if len(cur) >= 6:
            out.append(cur)
    return out


def shape(cs, e):
    """The entry's own edits on the 512 grid, before fitting: `drop_below` drops every contour lying wholly below that
    y (a ship's waves), `flip` mirrors it left to right, `turn` turns it that many degrees clockwise about the middle (a
    sprite's nose to the right)."""
    import math
    out = cs
    if "drop_below" in e:
        out = [c for c in out if min(c[1::2]) < e["drop_below"]]
    if e.get("flip"):
        out = [[(512 - v) if i % 2 == 0 else v for i, v in enumerate(c)] for c in out]
    if e.get("turn"):
        a = math.radians(e["turn"])
        ca, sa = math.cos(a), math.sin(a)
        res = []
        for c in out:
            pts = []
            for i in range(0, len(c), 2):
                dx, dy = c[i] - 256, c[i + 1] - 256
                pts += [256 + dx * ca - dy * sa, 256 + dx * sa + dy * ca]
            res.append(pts)
        out = res
    return out


def fit(cs, margin):
    xs = [v for c in cs for v in c[0::2]]
    ys = [v for c in cs for v in c[1::2]]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    span = 64 - 2 * margin
    k = span / max(x1 - x0, y1 - y0)
    ox = margin + (span - (x1 - x0) * k) / 2 - x0 * k
    oy = margin + (span - (y1 - y0) * k) / 2 - y0 * k
    res = []
    for c in cs:
        pts = []
        for i in range(0, len(c), 2):
            pts += [round(c[i] * k + ox, 2), round(c[i + 1] * k + oy, 2)]
        # drop repeated points
        clean = pts[:2]
        for i in range(2, len(pts), 2):
            if abs(pts[i] - clean[-2]) + abs(pts[i + 1] - clean[-1]) > 0.02:
                clean += pts[i:i + 2]
        if len(clean) >= 6:
            res.append(clean)
    return res


def lua(entries, header):
    lines = [header, "return {"]
    for key, cs in entries:
        lines.append(f'\t["{key}"] = {{')
        for c in cs:
            lines.append("\t\t{ " + ", ".join(f"{v:g}" for v in c) + " },")
        lines.append("\t},")
    lines.append("}")
    return "\n".join(lines) + "\n"


def main():
    args = sys.argv[1:]
    if args and args[0] == "--preview":
        out, files = args[1], []
        import glob
        for a in args[2:]:
            if os.path.exists(os.path.join(GI, a)):
                files.append(a)
            else:  # a bare name: every author's icon of that name
                for f in sorted(glob.glob(os.path.join(GI, "*", a.removesuffix(".svg") + ".svg"))):
                    files.append(os.path.relpath(f, GI).replace(os.sep, "/"))
        edits = json.loads(os.environ["GI_EDIT"]) if os.environ.get("GI_EDIT") else {}
        entries = [(f, fit(shape(contours(os.path.join(GI, f)), edits), MARGIN)) for f in files]
        open(out, "w", newline="\n").write(lua(entries, "-- preview: game-icons.net candidates"))
        print(len(entries), "candidates ->", out)
        return
    for json_name, out_name, what in (("gi_icons.json", "gi_paths.luau", "Glyph"), ("gi_units.json", "gi_units.luau", "Map sprite")):
        spec = json.load(open(os.path.join(ROOT, "tools/art", json_name), encoding="utf-8"))
        entries = []
        for name in sorted(spec):
            e = spec[name] if isinstance(spec[name], dict) else {"src": spec[name]}
            dst = os.path.join(ROOT, "tools/art/game-icons", e["src"])
            if os.path.isdir(GI):
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                shutil.copyfile(os.path.join(GI, e["src"]), dst)
            entries.append((name, fit(shape(contours(dst), e), e.get("margin", MARGIN))))
        head = (f"-- GENERATED by tools/art/gi_import.py from tools/art/{json_name}: do not edit by hand.\n"
                f"-- {what} outlines from game-icons.net (CC BY 3.0, authors in NOTICE.md), fitted to the 64-unit grid.")
        open(os.path.join(ROOT, "tools/art", out_name), "w", newline="\n").write(lua(entries, head))
        print(len(entries), "->", "tools/art/" + out_name)


if __name__ == "__main__":
    main()
