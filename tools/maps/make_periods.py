#!/usr/bin/env python3
"""Writes src/shared/Data/Periods.luau: Warhold's start dates (tools/maps/periods_spec.py) placed on the real-world maps.

For each period and each map: every realm whose seat (lon, lat) falls inside the map is projected with the map's own
projection (make_maps.py's Proj; one up to EDGE tiles past the edge is moved onto it), moved to the nearest contestable land tile within SNAP tiles (a coastal capital can sit a
tile into the sea at this scale), and kept unless an earlier realm's seat is within the map's gap (a smaller realm beside a
greater one on a small-scale map); colours are kept apart as tools/maps/realm_colors.py does (only realms near each other
need to differ much). A map gets a period only with at least MIN_REALMS realms on it, so a continent the period's list
barely touches stays today's.
Usage (repo root): python tools/maps/make_periods.py [--check]
"""
import base64, math, os, re, sys
import numpy as np
import zstandard
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
from periods_spec import PERIODS  # noqa: E402
import realm_colors as RC  # noqa: E402

OUT = os.path.join(REPO, "src", "shared", "Data", "Periods.luau")
MIN_REALMS = 15
SNAP = 25
#: a seat up to this many tiles past the map's edge still counts (moved onto the edge)
EDGE = 20
#: seats closer than this share of the map's own nation gap are one too many (the later realm goes)
GAP_K = 0.45


def load_make_maps():
    src = open(os.path.join(HERE, "make_maps.py"), encoding="utf-8").read()
    head = src.split("def etopo_name")[0]
    ns = {"__file__": os.path.join(HERE, "make_maps.py"), "__name__": "make_maps_head"}
    exec(head, ns)
    return ns


def terrain(path):
    s = open(path, encoding="utf-8").read()
    w = int(re.search(r"width = (\d+)", s).group(1))
    h = int(re.search(r"height = (\d+)", s).group(1))
    t = re.search(r'terrain = "([^"]+)"', s).group(1)
    g = np.frombuffer(zstandard.ZstdDecompressor().decompress(base64.b64decode(t)), dtype=np.uint8).reshape(h, w)
    land = (g & 0x80) != 0
    # (magnitude 31 with no other bits is impassable: not a seat)
    contest = land & ((g & 0x1F) != 31)
    return contest, w, h


def place(spec, proj, contest, w, h, realms):
    # nearest contestable tile for every tile (index of the nearest True)
    _, (iy, ix) = ndimage.distance_transform_edt(~contest, return_indices=True)
    gap = spec.get("min_gap", 30) * GAP_K
    out = []
    for name, lon, lat, col, trait in realms:
        x, y = proj.project(lon, lat)
        x, y = float(x), float(y)
        if spec.get("world") and x < 0:
            x += proj.w
        if not (-EDGE <= x < w + EDGE and -EDGE <= y < h + EDGE):
            continue
        # (a seat just past the map's edge stands on the nearest land inside it: its realm reaches in)
        xi, yi = min(max(int(x), 0), w - 1), min(max(int(y), 0), h - 1)
        sx, sy = int(ix[yi, xi]), int(iy[yi, xi])
        if math.hypot(sx - xi, sy - yi) > SNAP:
            continue
        if any(math.hypot(sx - o["x"], sy - o["y"]) < gap for o in out):
            continue
        out.append({"name": name, "x": sx, "y": sy, "color": col, "trait": trait})
    return out


def separate(rows, width):
    """realm_colors.py's rule on a period's realms: near realms differ by MIN_DE, any two by MIN_DE_ANY."""
    labs = {r["name"]: RC.oklab(RC.hex2rgb(r["color"])) for r in rows}
    at = {r["name"]: (r["x"], r["y"]) for r in rows}
    near_d = RC.NEAR_K * width

    def need(a, b):
        (ax, ay), (bx, by) = at[a], at[b]
        return RC.MIN_DE if math.hypot(ax - bx, ay - by) < near_d else RC.MIN_DE_ANY

    names = [r["name"] for r in rows]
    for _ in range(6):
        moved = False
        for n in reversed(names):
            others = [o for o in names if o != n]
            if not any(RC.de(labs[n], labs[o]) < need(n, o) for o in others):
                continue
            L, a, b = labs[n]
            C, H = math.hypot(a, b), math.atan2(b, a)
            best, best_s = labs[n], -1e9
            for dh in (0, -8, 8, -16, 16):
                for k in range(0, 11):
                    dl = (k + 1) // 2 * (1 if k % 2 == 1 else -1) * 0.03
                    hh = H + math.radians(dh)
                    cand = (max(0.3, min(0.9, L + dl)), C * math.cos(hh), C * math.sin(hh))
                    sc = -sum(max(0.0, need(n, o) - RC.de(cand, labs[o])) for o in others)
                    if sc > best_s:
                        best, best_s = cand, sc
                    if sc >= 0:
                        break
                if best_s >= 0:
                    break
            labs[n] = best
            moved = True
        if not moved:
            break
    for r in rows:
        r["color"] = RC.rgb2hex(RC.from_oklab(labs[r["name"]]))


def lua_str(v):
    return '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'


def build():
    mm = load_make_maps()
    paths = {"world": os.path.join(REPO, "src", "shared", "Data", "Maps", "World.luau")}
    for m in ("Europe", "Asia", "Africa", "NorthAmerica", "SouthAmerica"):
        paths[m.lower()] = os.path.join(REPO, "src", "server", "MapData", m + ".luau")
    seats = {}
    report = []
    for spec in mm["MAPS"]:
        proj = mm["Proj"](spec)
        contest, w, h = terrain(paths[spec["id"]])
        for per in PERIODS:
            rows = place(spec, proj, contest, w, h, per["realms"])
            report.append((per["key"], spec["id"], len(rows)))
            if len(rows) >= MIN_REALMS:
                separate(rows, w)
                seats.setdefault(per["key"], {})[spec["id"]] = rows
    return seats, report


def render(seats):
    L = [
        "-- GENERATED by tools/maps/make_periods.py from tools/maps/periods_spec.py. Do not edit.",
        "-- Warhold's start dates (the owner, 2026-11-08: key moments as the great medieval strategy games bookmark them; four",
        "-- to start, more after launch). LIST: each period's key, year, name and line, in time order. SEATS[period][map]: the",
        "-- realms of that date on that real-world map, { name, x, y (tiles), color, trait (Data/Traits key) }, in place of",
        "-- the map's own nations (Core/Sim._create_nations). A map with no row for a period does not offer it.",
        "local Periods = {}",
        "",
        "Periods.LIST = {",
    ]
    for p in PERIODS:
        L.append("\t{ key = %s, year = %d, name = %s, blurb = %s }," % (lua_str(p["key"]), p["year"], lua_str(p["name"]), lua_str(p["blurb"])))
    L += ["}", "", "Periods.SEATS = {"]
    for p in PERIODS:
        maps = seats.get(p["key"], {})
        L.append("\t[%s] = {" % lua_str(p["key"]))
        for mid in sorted(maps):
            L.append("\t\t%s = {" % mid)
            for r in maps[mid]:
                tr = "nil" if r["trait"] is None else lua_str(r["trait"])
                L.append("\t\t\t{ name = %s, x = %d, y = %d, color = %s, trait = %s }," % (lua_str(r["name"]), r["x"], r["y"], lua_str(r["color"]), tr))
            L.append("\t\t},")
        L.append("\t},")
    L += [
        "}",
        "",
        "--- The period row of `key`, or nil.",
        "function Periods.get(key: string?): { [string]: any }?",
        "\tfor _, p in Periods.LIST do",
        "\t\tif p.key == key then",
        "\t\t\treturn p",
        "\t\tend",
        "\tend",
        "\treturn nil",
        "end",
        "",
        "--- The realms of period `key` on map `map_id` (its base id, before any \"@\"), or nil when that map does not offer it.",
        "function Periods.seats(key: string?, map_id: string?): { { [string]: any } }?",
        "\tif key == nil or map_id == nil then",
        "\t\treturn nil",
        "\tend",
        "\tlocal by = (Periods.SEATS :: any)[key]",
        "\treturn if by ~= nil then by[(string.match(map_id, \"^([^@]*)\"))] else nil",
        "end",
        "",
        "--- The periods map `map_id` offers (keys, in time order).",
        "function Periods.offered(map_id: string?): { string }",
        "\tlocal out = {}",
        "\tfor _, p in Periods.LIST do",
        "\t\tif Periods.seats(p.key, map_id) ~= nil then",
        "\t\t\ttable.insert(out, p.key)",
        "\t\tend",
        "\tend",
        "\treturn out",
        "end",
        "",
        "return Periods",
        "",
    ]
    return "\n".join(L)


def main():
    seats, report = build()
    for key, mid, n in report:
        print("%-5s %-13s %3d realms%s" % (key, mid, n, "" if n >= MIN_REALMS else "  (not offered)"))
    text = render(seats)
    if "--check" in sys.argv:
        cur = open(OUT, encoding="utf-8").read() if os.path.exists(OUT) else ""
        if cur != text:
            sys.exit("Periods.luau is stale: run python tools/maps/make_periods.py")
        return
    open(OUT, "w", encoding="utf-8", newline="\n").write(text)
    print("wrote", os.path.relpath(OUT, REPO))


if __name__ == "__main__":
    main()
