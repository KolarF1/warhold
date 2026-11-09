#!/usr/bin/env python3
"""Depth Phase 1 (docs/DEPTH_PLAN.md): the provinces of the six real-world maps, the ground every later system hangs on.

Source (public domain): Natural Earth 1:10m states and provinces (admin-1) for the borders, and 1:10m populated places
for each province's capital and its development. Each map's own projection (make_maps.Proj) draws the borders onto its
tiles; land no border covers (a coast the map draws wider) joins the nearest province. Then the sizes are evened out
against the map's TARGET count:
  - a province under MIN_K x the mean is merged into the neighbour of its own country it shares most border with (a
    microstate or an island alone stays as it is: a merge never crosses a country);
  - one over MAX_K x the mean is cut into pieces about the mean's size (k-means on its tiles), each named after the
    largest town in it, else the old name and its side ("Yakutia North").
Each province gets: its name and country, a capital tile (its largest town, else the middle of its land), terrain (most
of its tiles: plains, hills, mountains; the World map's frozen rows: frozen), development 1-10 (the towns' people for
its size, ranked across the map) and building slots (2-4: development; one fewer on mountains or ice).

Deliberate assumptions (the owner asked for accuracy, assumptions allowed when stated): borders are today's admin-1
regions for every start date, 867-1241 included (historic provinces would need a historic atlas we don't have in the
public domain); development is today's town population ranked within the map, not a medieval census; forest and desert
are not told apart yet (no land-cover source in the pipeline).

The invented maps (Data/MapList "invented") get provinces too: seeds spread over their land (farthest-point, then
relaxed), each land tile to its nearest seed, pieces cut off by water rejoin a neighbour or stand alone when large
enough; names come from a syllable generator seeded by the map.

Writes the game's modules src/shared/Data/Provinces/<Module>.luau (grid = base64(zstd(u16 little-endian per tile,
0 = sea or impassable)), list = { name, country, capital tile, terrain 1 plains / 2 hills / 3 mountains / 4 frozen,
dev, slots }), plus build/provinces/<map>.json and a preview build/provinces/<map>.png (provinces in soft colours,
borders dark, capitals white).
Usage (repo root): python tools/maps/make_provinces.py [--map europe] [--check]   (--check: exit 1 on a failed rule)
"""
import argparse
import base64
import json
import math
import os
import re
import sys

import numpy as np
import zstandard
from scipy.spatial import cKDTree
from PIL import Image, ImageDraw
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
from make_periods import load_make_maps  # noqa: E402

SRC = os.path.join(REPO, "build", "worldsrc")
OUT = os.path.join(REPO, "build", "provinces")
#: provinces each map aims at (a match's nations are 50-330: two to ten provinces each)
TARGET = {"world": 700, "europe": 650, "asia": 700, "africa": 600, "northamerica": 550, "southamerica": 450}
#: the invented maps: provinces each
INVENTED_TARGET = 520
MODULES = os.path.join(REPO, "src", "shared", "Data", "Provinces")
TERRAIN_CODE = {"plains": 1, "hills": 2, "mountains": 3, "frozen": 4}
SYL_A = ["al", "bar", "cor", "dun", "el", "fen", "gal", "hal", "is", "kar", "lor", "mar", "nor", "or", "pel", "quar",
         "ros", "sal", "tor", "ul", "val", "wen", "yr", "zan", "ash", "bel", "cal", "dra", "ev", "gor"]
SYL_B = ["a", "e", "i", "o", "u", "ae", "ia", "or", "en", "an", "ar", "el"]
SYL_C = ["dor", "mere", "wick", "holm", "vale", "mark", "ford", "garth", "moor", "reach", "fell", "stead", "crest",
         "march", "shire", "wold", "haven", "gate", "rest", "fall"]
MIN_K = 0.35
MAX_K = 2.4
#: the World map's frozen rows begin at this share of its height (Rules.FROZEN_FROM)
FROZEN_FROM = 0.86
#: the frozen waste is barely fought over: its provinces are this many times the mean
FROZEN_K = 8.0
#: an island (or any piece) under this share of the mean with no neighbour of its country joins the nearest one that is
ISLAND_K = 0.12
#: a terrain wins a province with this share of its tiles
TERRAIN_SHARE = 0.4


def grids(path):
    s = open(path, encoding="utf-8").read()
    w = int(re.search(r"width = (\d+)", s).group(1))
    h = int(re.search(r"height = (\d+)", s).group(1))
    t = re.search(r'terrain = "([^"]+)"', s).group(1)
    g = np.frombuffer(zstandard.ZstdDecompressor().decompress(base64.b64decode(t)), dtype=np.uint8).reshape(h, w)
    land = (g & 0x80) != 0
    contest = land & ((g & 0x1F) != 31)
    return contest, (g & 0x1F).astype(np.int32), w, h


def rings(geom):
    if geom["type"] == "Polygon":
        return [geom["coordinates"]]
    if geom["type"] == "MultiPolygon":
        return geom["coordinates"]
    return []


def window(spec, proj):
    lon0 = spec["lon0"]
    lon1 = lon0 + proj.w / proj.px
    lat_top = spec["lat_top"]
    lat_bot = lat_top - proj.h / proj.py
    return lon0, lon1, lat_bot, lat_top


def rasterize(spec, proj, feats, w, h):
    """Each tile's admin-1 index + 1 (0: none), drawn in the map's projection."""
    img = Image.new("I", (w, h), 0)
    dr = ImageDraw.Draw(img)
    lon0, lon1, lat_bot, lat_top = window(spec, proj)
    world = spec.get("world", False)
    for i, ft in enumerate(feats):
        for poly in rings(ft["geometry"]):
            ring = np.asarray(poly[0], dtype=np.float64)
            if not world:
                if ring[:, 0].max() < lon0 - 1 or ring[:, 0].min() > lon1 + 1 or ring[:, 1].max() < lat_bot - 1 or ring[:, 1].min() > lat_top + 1:
                    continue
            x, y = proj.project(ring[:, 0], ring[:, 1])
            shifts = [0.0]
            if world:
                # (x is unwrapped: west of lon0 is negative; a ring is drawn once more a map's width over)
                if x.min() < 0:
                    shifts.append(float(proj.w))
                if x.max() >= proj.w:
                    shifts.append(-float(proj.w))
            for sx in shifts:
                pts = list(zip((x + sx).tolist(), y.tolist()))
                if len(pts) >= 3:
                    dr.polygon(pts, fill=i + 1)
            # holes (a lake region, an enclave) are left to the drawing order: enclaves are their own features
    return np.asarray(img, dtype=np.int64)


def borders(lab):
    """Shared border lengths between labels: { (a, b): n } with a < b, 4-neighbours, labels > 0."""
    out = {}
    for a, b in ((lab[:, :-1], lab[:, 1:]), (lab[:-1, :], lab[1:, :])):
        m = (a != b) & (a > 0) & (b > 0)
        p = np.stack([np.minimum(a[m], b[m]), np.maximum(a[m], b[m])], axis=1)
        if len(p) == 0:
            continue
        keys, counts = np.unique(p, axis=0, return_counts=True)
        for (u, v), c in zip(keys.tolist(), counts.tolist()):
            out[(u, v)] = out.get((u, v), 0) + c
    return out


def build(spec, mm, feats, places, frozen_rows):
    path = os.path.join(REPO, "src", "shared", "Data", "Maps", "World.luau") if spec["id"] == "world" else os.path.join(
        REPO, "src", "server", "MapData", spec["module"] + ".luau")
    proj = mm["Proj"](spec)
    contest, mag, w, h = grids(path)
    lab = rasterize(spec, proj, feats, w, h)
    lab[~contest] = 0
    # land no border covers: the nearest province
    miss = contest & (lab == 0)
    if miss.any():
        _, (iy, ix) = ndimage.distance_transform_edt(lab == 0, return_indices=True)
        lab[miss] = lab[iy[miss], ix[miss]]
    land_n = int(contest.sum())
    mean = land_n / TARGET[spec["id"]]
    # provinces as label ids (the admin-1 index + 1); merges through a union-find
    parent = {}

    def find(a):
        while parent.get(a, a) != a:
            parent[a] = parent.get(parent[a], parent[a])
            a = parent[a]
        return a

    ids, counts = np.unique(lab[lab > 0], return_counts=True)
    size = dict(zip(ids.tolist(), counts.tolist()))
    country = {i: feats[i - 1]["properties"].get("adm0_a3") for i in size}
    names = {i: feats[i - 1]["properties"].get("name_en") or feats[i - 1]["properties"].get("name") or "?" for i in size}
    # each label's middle (for an island's nearest province of its country)
    flat = lab.ravel()
    yy0, xx0 = np.divmod(np.arange(flat.size), w)
    sel = flat > 0
    cnt = np.bincount(flat[sel], minlength=len(feats) + 1).astype(np.float64)
    cx = np.bincount(flat[sel], weights=xx0[sel], minlength=len(feats) + 1) / np.maximum(cnt, 1)
    cy = np.bincount(flat[sel], weights=yy0[sel], minlength=len(feats) + 1) / np.maximum(cnt, 1)
    border = borders(lab)
    nb = {}
    for (u, v), c in border.items():
        nb.setdefault(u, {})[v] = c
        nb.setdefault(v, {})[u] = c
    # merge the small ones, smallest first, each into its own country's neighbour it borders most (ties: the smaller)
    while True:
        roots = sorted((size[r], r) for r in size if find(r) == r and size[r] < MIN_K * mean)
        done = False
        for s, r in roots:
            cands = {}
            for v, c in nb.get(r, {}).items():
                rv = find(v)
                if rv != r and country.get(rv) == country.get(r):
                    cands[rv] = cands.get(rv, 0) + c
            if not cands and s < ISLAND_K * mean:
                # (an island: the nearest province of its own country, across the water)
                same = [q for q in size if q != r and find(q) == q and country.get(q) == country.get(r)]
                if same:
                    near = min(same, key=lambda q: (cx[q] - cx[r]) ** 2 + (cy[q] - cy[r]) ** 2)
                    cands = {near: 0}
            if not cands:
                continue
            best = max(cands, key=lambda k: (cands[k], -size[k]))
            # (the larger keeps its name: the merged one is part of it)
            keep, gone = (best, r) if size[best] >= s else (r, best)
            parent[gone] = keep
            size[keep] += size[gone]
            del size[gone]
            for v, c in nb.pop(gone, {}).items():
                if v == keep:
                    continue
                nb.setdefault(keep, {})[v] = nb.get(keep, {}).get(v, 0) + c
                nb.setdefault(v, {})[keep] = nb[keep][v]
                nb[v].pop(gone, None)
            nb.get(keep, {}).pop(gone, None)
            done = True
            break
        if not done:
            break
    # relabel by roots
    lut = np.zeros(len(feats) + 1, dtype=np.int64)
    for i in ids.tolist():
        lut[i] = find(i)
    lab = lut[lab]
    # provinces 1..n
    roots = sorted(set(lab[lab > 0].tolist()))
    provs = []
    out = np.zeros_like(lab)
    ys, xs = np.nonzero(lab)
    order = np.argsort(lab[ys, xs], kind="stable")
    ys, xs = ys[order], xs[order]
    labs = lab[ys, xs]
    starts = np.searchsorted(labs, roots)
    ends = np.searchsorted(labs, roots, side="right")
    # towns on the map, in tiles
    px, py = proj.project(places["lon"], places["lat"])
    px = np.asarray(px, dtype=np.float64)
    if spec.get("world"):
        px = np.where(px < 0, px + proj.w, px)
    tx = np.floor(px).astype(np.int64)
    ty = np.floor(np.asarray(py, dtype=np.float64)).astype(np.int64)
    on = (tx >= 0) & (tx < w) & (ty >= 0) & (ty < h)
    town_lab = np.zeros(len(tx), dtype=np.int64)
    town_lab[on] = lab[ty[on], tx[on]]
    for r, a, b in zip(roots, starts, ends):
        py_, px_ = ys[a:b], xs[a:b]
        n = b - a
        unit = mean
        if frozen_rows is not None and float((py_ >= frozen_rows).mean()) >= 0.5:
            unit = mean * FROZEN_K
        k = max(1, int(round(n / unit))) if n > MAX_K * unit else 1
        if k == 1:
            parts = [(py_, px_, None)]
        else:
            # k-means on the tiles (a fixed sample of starts: deterministic), the pieces about the mean's size
            pts = np.stack([px_, py_], axis=1).astype(np.float64)
            rng = np.random.default_rng(r)
            cent = pts[rng.choice(n, k, replace=False)]
            for _ in range(12):
                d = ((pts[:, None, :] - cent[None, :, :]) ** 2).sum(axis=2)
                asg = d.argmin(axis=1)
                for j in range(k):
                    sel = asg == j
                    if sel.any():
                        cent[j] = pts[sel].mean(axis=0)
            parts = [(py_[asg == j], px_[asg == j], cent[j]) for j in range(k) if (asg == j).any()]
        mid_all = (float(px_.mean()), float(py_.mean()))
        for j, (qy, qx, c) in enumerate(parts):
            pid = len(provs) + 1
            out[qy, qx] = pid
            provs.append({"root": int(r), "piece": j if len(parts) > 1 else None, "n": int(len(qy)),
                          "mid": (float(qx.mean()), float(qy.mean())), "of": mid_all,
                          "name0": names[r], "country": country[r]})
    # towns per final province
    town_p = np.zeros(len(tx), dtype=np.int64)
    town_p[on] = out[ty[on], tx[on]]
    pops = places["pop"]
    tnames = places["name"]
    best_town = {}
    pop_sum = np.zeros(len(provs) + 1)
    for i in np.nonzero(town_p)[0].tolist():
        p = int(town_p[i])
        pop_sum[p] += pops[i]
        if p not in best_town or pops[i] > pops[best_town[p]]:
            best_town[p] = i
    # names: a piece takes its largest town's name, else its side of the old province
    used = {}
    for i, pr in enumerate(provs, start=1):
        name = pr["name0"]
        if pr["piece"] is not None:
            t = best_town.get(i)
            if t is not None and tnames[t] and tnames[t] != name:
                name = tnames[t]
            else:
                dx, dy = pr["mid"][0] - pr["of"][0], pr["mid"][1] - pr["of"][1]
                side = ("East" if dx > 0 else "West") if abs(dx) > abs(dy) else ("South" if dy > 0 else "North")
                name = "%s %s" % (pr["name0"], side)
        used[name] = used.get(name, 0) + 1
        if used[name] > 1:
            name = "%s %d" % (name, used[name])
        pr["name"] = name
    # capital, terrain, development, slots
    W = w
    score = np.zeros(len(provs))
    yy, xx = np.nonzero(out)
    pv = out[yy, xx]
    order = np.argsort(pv, kind="stable")
    yy, xx, pv = yy[order], xx[order], pv[order]
    st = np.searchsorted(pv, np.arange(1, len(provs) + 1))
    en = np.searchsorted(pv, np.arange(1, len(provs) + 1), side="right")
    for i, pr in enumerate(provs, start=1):
        qy, qx = yy[st[i - 1]:en[i - 1]], xx[st[i - 1]:en[i - 1]]
        t = best_town.get(i)
        if t is not None:
            cap = (int(tx[t]), int(ty[t]))
        else:
            # the tile of its land nearest its middle
            mx, my = qx.mean(), qy.mean()
            j = int(np.argmin((qx - mx) ** 2 + (qy - my) ** 2))
            cap = (int(qx[j]), int(qy[j]))
        pr["capital"] = cap[1] * W + cap[0]
        pr["capital_xy"] = cap
        m = mag[qy, qx]
        mount = float((m >= 20).mean())
        high = float((m >= 10).mean())
        if frozen_rows is not None and float((qy >= frozen_rows).mean()) >= 0.5:
            terr = "frozen"
        elif mount >= TERRAIN_SHARE:
            terr = "mountains"
        elif high >= TERRAIN_SHARE:
            terr = "hills"
        else:
            terr = "plains"
        pr["terrain"] = terr
        score[i - 1] = math.log10(1.0 + pop_sum[i] / max(pr["n"], 1) * 100.0)
    # development: rank of the towns' people for the size, 1-10 (a province with no town: 1, or 2 on plains)
    ranked = np.argsort(np.argsort(score))
    for i, pr in enumerate(provs, start=1):
        if pop_sum[i] <= 0:
            dev = 2 if pr["terrain"] == "plains" else 1
        else:
            dev = 1 + int(9 * ranked[i - 1] / max(len(provs) - 1, 1))
        if pr["terrain"] == "frozen":
            dev = 1
        pr["dev"] = int(min(max(dev, 1), 10))
        slots = 2 + (1 if pr["dev"] >= 4 else 0) + (1 if pr["dev"] >= 7 else 0)
        if pr["terrain"] in ("mountains", "frozen"):
            slots -= 1
        pr["slots"] = max(slots, 1)
        pr["pop"] = int(pop_sum[i])
    return out, provs, contest, w, h, mean


def check(spec_id, out, provs, contest, mean):
    """The rules a province map keeps; returns the broken ones."""
    bad = []
    if int((contest & (out == 0)).sum()) > 0:
        bad.append("%d land tiles in no province" % int((contest & (out == 0)).sum()))
    if int(((~contest) & (out > 0)).sum()) > 0:
        bad.append("sea in a province")
    names = [p["name"] for p in provs]
    if len(set(names)) != len(names):
        bad.append("a name twice")
    for i, p in enumerate(provs, start=1):
        x, y = p["capital_xy"]
        if out[y, x] != i:
            bad.append("%s's capital is outside it" % p["name"])
        if p["n"] > MAX_K * mean * 1.6 and p["terrain"] != "frozen":
            bad.append("%s is %d tiles (mean %d)" % (p["name"], p["n"], mean))
    t = TARGET[spec_id]
    if not (0.6 * t <= len(provs) <= 1.6 * t):
        bad.append("%d provinces, target %d" % (len(provs), t))
    return bad


def preview(path, out, provs, contest, w, h):
    rng = np.random.default_rng(7)
    pal = np.zeros((len(provs) + 1, 3), dtype=np.uint8)
    pal[0] = (18, 24, 34)
    for i in range(1, len(provs) + 1):
        hue = rng.random()
        r, g, b = [int(255 * (0.55 + 0.35 * max(0.0, min(1.0, abs((hue * 6 + k) % 6 - 3) - 1)))) for k in (0, 4, 2)]
        pal[i] = (r, g, b)
    img = pal[out]
    edge = np.zeros(out.shape, dtype=bool)
    edge[:, 1:] |= out[:, 1:] != out[:, :-1]
    edge[1:, :] |= out[1:, :] != out[:-1, :]
    img[edge & contest] = (40, 40, 48)
    for p in provs:
        x, y = p["capital_xy"]
        img[max(y - 1, 0):y + 2, max(x - 1, 0):x + 2] = (255, 255, 255)
    Image.fromarray(img).save(path)


def invented_names(n, seed):
    rng = np.random.default_rng(seed)
    out, seen = [], set()
    while len(out) < n:
        name = (SYL_A[rng.integers(len(SYL_A))] + SYL_B[rng.integers(len(SYL_B))] + SYL_C[rng.integers(len(SYL_C))])
        name = name[0].upper() + name[1:]
        if name not in seen:
            seen.add(name)
            out.append(name)
    return out


def build_invented(mid, module):
    contest, mag, w, h = grids(os.path.join(REPO, "src", "server", "MapData", module + ".luau"))
    ys, xs = np.nonzero(contest)
    pts = np.stack([xs, ys], axis=1).astype(np.float64)
    land_n = len(pts)
    mean = land_n / INVENTED_TARGET
    seed = sum(ord(c) for c in mid)
    rng = np.random.default_rng(seed)
    # seeds: farthest-point over a sample, then two relaxations
    sample = pts[rng.choice(land_n, min(land_n, 60000), replace=False)]
    seeds = [sample[0]]
    d = np.hypot(*(sample - seeds[0]).T)
    for _ in range(INVENTED_TARGET - 1):
        j = int(np.argmax(d))
        seeds.append(sample[j])
        d = np.minimum(d, np.hypot(*(sample - sample[j]).T))
    seeds = np.array(seeds)
    for _ in range(2):
        _, a = cKDTree(seeds).query(sample)
        for k in range(len(seeds)):
            sel = a == k
            if sel.any():
                seeds[k] = sample[sel].mean(axis=0)
    _, asg = cKDTree(seeds).query(pts)
    lab = np.zeros((h, w), dtype=np.int64)
    lab[ys, xs] = asg + 1
    # each label's connected parts are provinces of their own; then small parts join the neighbour they border most
    out = np.zeros_like(lab)
    struct4 = np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]])
    comp, nc = ndimage.label(lab > 0, structure=struct4)
    # (a part = a label within one landmass piece: label x 1e6 + piece id, then renumbered)
    key = lab * 1000000 + 0
    nxt = 0
    for k in range(1, len(seeds) + 1):
        m = lab == k
        if not m.any():
            continue
        c2, n2 = ndimage.label(m, structure=struct4)
        for c in range(1, n2 + 1):
            nxt += 1
            out[c2 == c] = nxt
    ids, counts = np.unique(out[out > 0], return_counts=True)
    size = dict(zip(ids.tolist(), counts.tolist()))
    flat = out.ravel()
    yy0, xx0 = np.divmod(np.arange(flat.size), w)
    sel = flat > 0
    cnt = np.bincount(flat[sel], minlength=nxt + 1).astype(np.float64)
    cx = np.bincount(flat[sel], weights=xx0[sel], minlength=nxt + 1) / np.maximum(cnt, 1)
    cy = np.bincount(flat[sel], weights=yy0[sel], minlength=nxt + 1) / np.maximum(cnt, 1)
    parent = {}

    def find(a):
        while parent.get(a, a) != a:
            a = parent[a]
        return a

    border = borders(out)
    nb = {}
    for (u, v), c in border.items():
        nb.setdefault(u, {})[v] = c
        nb.setdefault(v, {})[u] = c
    for r in sorted(size, key=lambda q: size[q]):
        if size.get(r, 0) >= MIN_K * mean or find(r) != r:
            continue
        cands = {}
        for v, c in nb.get(r, {}).items():
            rv = find(v)
            if rv != r:
                cands[rv] = cands.get(rv, 0) + c
        if cands:
            best = max(cands, key=lambda q: cands[q])
        elif size[r] < 0.05 * mean:
            others = [q for q in size if q != r and find(q) == q and size[q] >= MIN_K * mean]
            if not others:
                continue
            best = min(others, key=lambda q: (cx[q] - cx[r]) ** 2 + (cy[q] - cy[r]) ** 2)
        else:
            continue
        parent[r] = best
        size[best] += size.pop(r)
        for v, c in nb.pop(r, {}).items():
            if v != best:
                nb.setdefault(best, {})[v] = nb.get(best, {}).get(v, 0) + c
    lut = np.zeros(nxt + 1, dtype=np.int64)
    roots = sorted(size)
    newid = {r: i for i, r in enumerate(roots, start=1)}
    for i in range(1, nxt + 1):
        lut[i] = newid[find(i)]
    out = lut[out]
    names = invented_names(len(roots), seed)
    provs = []
    yy, xx = np.nonzero(out)
    pv = out[yy, xx]
    order = np.argsort(pv, kind="stable")
    yy, xx, pv = yy[order], xx[order], pv[order]
    st = np.searchsorted(pv, np.arange(1, len(roots) + 1))
    en = np.searchsorted(pv, np.arange(1, len(roots) + 1), side="right")
    # coastal land is richer: a province's share of tiles near water raises its development
    near_sea = ndimage.binary_dilation(~contest, iterations=6) & contest
    for i in range(1, len(roots) + 1):
        qy, qx = yy[st[i - 1]:en[i - 1]], xx[st[i - 1]:en[i - 1]]
        mx, my = qx.mean(), qy.mean()
        j = int(np.argmin((qx - mx) ** 2 + (qy - my) ** 2))
        m = mag[qy, qx]
        mount, high = float((m >= 20).mean()), float((m >= 10).mean())
        terr = "mountains" if mount >= TERRAIN_SHARE else ("hills" if high >= TERRAIN_SHARE else "plains")
        coast = float(near_sea[qy, qx].mean())
        dev = 1 + int(round(3 * coast + (2 if terr == "plains" else 1 if terr == "hills" else 0) + 4 * rng.random()))
        dev = int(min(max(dev, 1), 10))
        slots = 2 + (1 if dev >= 4 else 0) + (1 if dev >= 7 else 0) - (1 if terr == "mountains" else 0)
        provs.append({"name": names[i - 1], "country": "", "capital": int(qy[j]) * w + int(qx[j]),
                      "capital_xy": (int(qx[j]), int(qy[j])), "terrain": terr, "dev": dev, "slots": max(slots, 1),
                      "n": int(len(qy)), "pop": 0})
    return out, provs, contest, w, h, mean


def write_module(module, out, provs, w, h):
    os.makedirs(MODULES, exist_ok=True)
    raw = out.astype("<u2").tobytes()
    blob = base64.b64encode(zstandard.ZstdCompressor(level=19).compress(raw)).decode("ascii")

    def esc(t):
        return t.replace("\\", "\\\\").replace('"', '\\"')
    rows = ",\n".join('\t\t{ "%s", "%s", %d, %d, %d, %d }' % (esc(p["name"]), p["country"] or "", p["capital"],
                                                           TERRAIN_CODE[p["terrain"]], p["dev"], p["slots"]) for p in provs)
    text = ("-- GENERATED by tools/maps/make_provinces.py: do not edit by hand. The map's provinces (docs/DEPTH_DESIGN.md):\n"
            "-- grid = base64(zstd(u16 little-endian per tile, 0 = no province)); list = { name, country, capital tile,\n"
            "-- terrain (1 plains, 2 hills, 3 mountains, 4 frozen), development 1-10, building slots }.\n"
            "return {\n\tw = %d,\n\th = %d,\n\tgrid = \"%s\",\n\tlist = {\n%s,\n\t},\n}\n" % (w, h, blob, rows))
    with open(os.path.join(MODULES, module + ".luau"), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    return len(text)


def check_invented(out, provs, contest):
    bad = []
    if int((contest & (out == 0)).sum()) > 0:
        bad.append("%d land tiles in no province" % int((contest & (out == 0)).sum()))
    for i, p in enumerate(provs, start=1):
        x, y = p["capital_xy"]
        if out[y, x] != i:
            bad.append("%s's capital is outside it" % p["name"])
    return bad


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--map")
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    mm = load_make_maps()
    with open(os.path.join(SRC, "ne_10m_admin_1_states_provinces.geojson"), encoding="utf-8") as f:
        feats = json.load(f)["features"]
    with open(os.path.join(SRC, "ne_10m_populated_places_simple.geojson"), encoding="utf-8") as f:
        pl = json.load(f)["features"]
    places = {
        "lon": np.array([p["properties"]["longitude"] for p in pl]),
        "lat": np.array([p["properties"]["latitude"] for p in pl]),
        "pop": np.array([max(p["properties"].get("pop_max") or 0, 0) for p in pl], dtype=np.float64),
        "name": [p["properties"].get("nameascii") or p["properties"].get("name") for p in pl],
    }
    os.makedirs(OUT, exist_ok=True)
    failed = False
    for spec in mm["MAPS"]:
        if a.map and spec["id"] != a.map:
            continue
        frozen = None
        proj = mm["Proj"](spec)
        if spec["id"] == "world":
            frozen = int(math.floor(proj.h * FROZEN_FROM))
        out, provs, contest, w, h, mean = build(spec, mm, feats, places, frozen)
        bad = check(spec["id"], out, provs, contest, mean)
        sizes = sorted(p["n"] for p in provs)
        terr = {}
        for p in provs:
            terr[p["terrain"]] = terr.get(p["terrain"], 0) + 1
        print("%-13s %4d provinces (target %d), tiles %d / %d / %d (min / median / max, mean %d), terrain %s, countries %d" % (
            spec["id"], len(provs), TARGET[spec["id"]], sizes[0], sizes[len(sizes) // 2], sizes[-1], mean,
            " ".join("%s %d" % kv for kv in sorted(terr.items())), len({p["country"] for p in provs})))
        for b in bad[:12]:
            print("   FAIL " + b)
        failed = failed or bool(bad)
        preview(os.path.join(OUT, spec["id"] + ".png"), out, provs, contest, w, h)
        with open(os.path.join(OUT, spec["id"] + ".json"), "w", encoding="utf-8") as f:
            json.dump({"w": w, "h": h, "provinces": [{k: p[k] for k in ("name", "country", "capital", "terrain", "dev", "slots", "n", "pop")} for p in provs]}, f, ensure_ascii=False)
        np.save(os.path.join(OUT, spec["id"] + ".npy"), out.astype(np.uint16))
        size = write_module(spec["module"], out, provs, w, h)
        print("   module %s.luau %d KB" % (spec["module"], size // 1024))
    # the invented maps
    ml = open(os.path.join(REPO, "src", "shared", "Data", "MapList.luau"), encoding="utf-8").read()
    for mid, module in re.findall(r'id = "([a-z]+)", name = "[^"]+", module = "([A-Za-z]+)"[^\n]*"invented"', ml):
        if a.map and mid != a.map:
            continue
        out, provs, contest, w, h, mean = build_invented(mid, module)
        bad = check_invented(out, provs, contest)
        sizes = sorted(p["n"] for p in provs)
        print("%-13s %4d provinces (invented), tiles %d / %d / %d" % (mid, len(provs), sizes[0], sizes[len(sizes) // 2], sizes[-1]))
        for b in bad[:12]:
            print("   FAIL " + b)
        failed = failed or bool(bad)
        preview(os.path.join(OUT, mid + ".png"), out, provs, contest, w, h)
        size = write_module(module, out, provs, w, h)
        print("   module %s.luau %d KB" % (module, size // 1024))
    if a.check and failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
