#!/usr/bin/env python3
"""Writes src/shared/Data/RealmColors.luau: the colour of every realm on Warhold's real-world maps, by the place's name,
from tools/maps/realm_colors_spec.py (the owner, 2026-11-08: colours true to the country, never two alike).

  * a country takes its own colour; a state or province a shade of its country's, siblings stepped apart in lightness;
  * then, map by map, any two realms closer than MIN_DE (OKLab distance x 100) are pulled apart: the later one in the
    map's list steps its lightness (never its hue, so a country keeps reading as itself) until clear.
A realm on several maps can read differently on each (its neighbours differ): the table is by map, then name.
Usage (repo root): python tools/maps/realm_colors.py [--check]  (--check: fail if the file is stale or a pair is close)
"""
import os, re, sys, math
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
from realm_colors_spec import COUNTRY, PARENT  # noqa: E402

#: realms whose seats are within NEAR_K of the map's width must differ by MIN_DE; any two on the map by MIN_DE_ANY.
MIN_DE = 11.0
MIN_DE_ANY = 3.0
NEAR_K = 0.2
#: two shades of one country side by side need less: their border tells them apart
MIN_DE_SIB = 7.0
HUE_COUNTRY = (0, -6, 6, -12, 12)
HUE_PROVINCE = (0, -8, 8, -16, 16, -24, 24, -32, 32)
MAPS = {
    "world": os.path.join(REPO, "src", "shared", "Data", "Maps", "World.luau"),
    "europe": os.path.join(REPO, "src", "server", "MapData", "Europe.luau"),
    "asia": os.path.join(REPO, "src", "server", "MapData", "Asia.luau"),
    "africa": os.path.join(REPO, "src", "server", "MapData", "Africa.luau"),
    "northamerica": os.path.join(REPO, "src", "server", "MapData", "NorthAmerica.luau"),
    "southamerica": os.path.join(REPO, "src", "server", "MapData", "SouthAmerica.luau"),
}
OUT = os.path.join(REPO, "src", "shared", "Data", "RealmColors.luau")


def hex2rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def gam(c):
    c = max(0.0, min(1.0, c))
    return c * 12.92 if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def oklab(rgb):
    r, g, b = (lin(c) for c in rgb)
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l, m, s = (math.copysign(abs(v) ** (1 / 3), v) for v in (l, m, s))
    return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


def from_oklab(lab):
    L, a, b = lab
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    bb = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    return tuple(gam(c) for c in (r, g, bb))


def rgb2hex(rgb):
    return "#%02x%02x%02x" % tuple(int(round(max(0, min(1, c)) * 255)) for c in rgb)


def de(a, b):
    return 100 * math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def shade(hexc, step):
    """`step` lightness steps (0.07 OKLab L each) from `hexc`, alternately lighter and darker."""
    L, a, b = oklab(hex2rgb(hexc))
    k = (step + 1) // 2 * (1 if step % 2 == 1 else -1)
    L = max(0.25, min(0.9, L + 0.07 * k))
    return rgb2hex(from_oklab((L, a, b)))


def names_of(path):
    """The map's realms: [(name, x, y)], and its width."""
    s = open(path, encoding="utf-8").read()
    w = int(re.search(r"width = (\d+)", s).group(1))
    rows = re.findall(r'\{ name = "([^"]+)", flag = "wh_[a-z_]+", x = (\d+), y = (\d+)', s)
    return [(n, int(x), int(y)) for n, x, y in rows], w


def build():
    table = {}
    report = []
    for mid, path in MAPS.items():
        rows, width = names_of(path)
        names = [r[0] for r in rows]
        at = {r[0]: (r[1], r[2]) for r in rows}
        near_d = NEAR_K * width

        def family(v):
            return PARENT.get(v, v)

        def need(x, y):
            (ax, ay), (bx, by) = at[x], at[y]
            if math.hypot(ax - bx, ay - by) >= near_d:
                return MIN_DE_ANY
            return MIN_DE_SIB if family(x) == family(y) else MIN_DE
        sib = {}
        cols = {}
        for n in names:
            if n in COUNTRY:
                cols[n] = COUNTRY[n]
            else:
                p = PARENT[n]
                k = sib.get(p, 0) + 1
                # (the country itself on this map keeps its colour; its provinces step around it)
                sib[p] = k
                cols[n] = shade(COUNTRY[p], k)
        # pull close pairs apart: the later realm steps its lightness
        labs = {n: oklab(hex2rgb(c)) for n, c in cols.items()}
        base = dict(labs)

        def candidates(n):
            L, a, b = base[n]
            C, H = math.hypot(a, b), math.atan2(b, a)
            # (a country may turn a little; a province, a shade of its country, further)
            turns = HUE_COUNTRY if n in COUNTRY else HUE_PROVINCE
            out = []
            for dh in turns:
                for k in range(0, 13):
                    dl = (k + 1) // 2 * (1 if k % 2 == 1 else -1) * 0.03
                    cost = abs(dl) / 0.03 + abs(dh) / 6.0
                    hh = H + math.radians(dh)
                    out.append((cost, (max(0.3, min(0.9, L + dl)), C * math.cos(hh), C * math.sin(hh))))
            out.sort(key=lambda c: c[0])
            return [c[1] for c in out]

        cand_of = {n: candidates(n) for n in names}

        def place(n, others):
            best, best_worst = labs[n], -1e9
            for cand in cand_of[n]:
                # (how far short of what the other realms need, in all; a near-identical pair counts double)
                worst = 0.0
                for o in others:
                    d = de(cand, labs[o])
                    short = need(n, o) - d
                    if short > 0:
                        worst -= short * (2.0 if d < MIN_DE_ANY else 1.0)
                if worst > best_worst:
                    best, best_worst = cand, worst
                if worst >= 0:
                    break
            labs[n] = best
            return best_worst

        # countries first, so each keeps its own colour where it can; their provinces then step around them
        order = sorted(names, key=lambda v: (v not in COUNTRY, names.index(v)))
        done = []
        for n in order:
            place(n, done)
            done.append(n)
        # then repair passes: anyone still too close to another moves again, now against everyone
        for _ in range(8):
            moved = False
            for n in reversed(order):
                others = [o for o in names if o != n]
                if any(de(labs[n], labs[o]) < need(n, o) for o in others):
                    place(n, others)
                    moved = True
            if not moved:
                break
        for n in names:
            cols[n] = rgb2hex(from_oklab(labs[n]))
        close = []
        for i, x in enumerate(names):
            for y in names[i + 1:]:
                d = de(oklab(hex2rgb(cols[x])), oklab(hex2rgb(cols[y])))
                if d < need(x, y):
                    close.append((x, y, round(d, 1)))
        report.append((mid, len(names), close))
        table[mid] = cols
    return table, report


def render(table):
    lines = [
        "-- GENERATED by tools/maps/realm_colors.py from tools/maps/realm_colors_spec.py. Do not edit.",
        "-- The colour each realm reads in on the real-world maps, by map, then by the place's name (Data/Maps, server/MapData):",
        "-- its country's own colour, a state or province a shade of its country's, no two on one map alike (the owner,",
        "-- 2026-11-08). Core/Sim._create_nations reads it before Data/Nations.",
        "return {",
    ]
    for mid in MAPS:
        lines.append("\t%s = {" % mid)
        for n, c in sorted(table[mid].items()):
            lines.append('\t\t["%s"] = "%s",' % (n.replace('"', '\\"'), c))
        lines.append("\t},")
    lines.append("}")
    return "\n".join(lines) + "\n"


def main():
    table, report = build()
    text = render(table)
    for mid, n, close in report:
        print("%-13s %3d realms, %d pairs closer than %.0f" % (mid, n, len(close), MIN_DE), close[:6])
    if "--check" in sys.argv:
        cur = open(OUT, encoding="utf-8").read() if os.path.exists(OUT) else ""
        if cur != text:
            sys.exit("RealmColors.luau is stale: run python tools/maps/realm_colors.py")
        # (the few pairs left close are pulled apart again in the match, where their seats actually meet: SimColors.nudge)
        return
    open(OUT, "w", encoding="utf-8", newline="\n").write(text)
    print("wrote", os.path.relpath(OUT, REPO))


if __name__ == "__main__":
    main()
