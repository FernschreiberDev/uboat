"""Terrain and seabed of the Lorient roadstead, with a land-cover colour map.

Heights come from signed distance to the coastline (rasterised polygons of geography.py), shaped by
the dredged channel, the base's quays and basins, and value noise for the hills.
"""
from __future__ import annotations

import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

import geography as g
from meshkit import Mesh


class Field:
    """Rasterised land mask and signed distance to the shore over a rectangle."""

    def __init__(self, e0, e1, n0, n1, res, land_polys, water_polys):
        self.e0, self.e1, self.n0, self.n1, self.res = e0, e1, n0, n1, res
        self.w = int(round((e1 - e0) / res)) + 1
        self.h = int(round((n1 - n0) / res)) + 1
        img = Image.new("L", (self.w, self.h), 0)
        d = ImageDraw.Draw(img)
        for p in land_polys:
            d.polygon([self.px(e, n) for e, n in p], fill=255)
        for p in water_polys:
            d.polygon([self.px(e, n) for e, n in p], fill=0)
        self.land = np.asarray(img)[::-1] > 127          # row 0 = south
        inside = ndimage.distance_transform_edt(self.land) * res
        outside = ndimage.distance_transform_edt(~self.land) * res
        self.sdist = np.where(self.land, inside - res / 2, -(outside - res / 2))

    def px(self, e, n):
        # PIL rows go down from the north edge.
        return ((e - self.e0) / self.res, (self.n1 - n) / self.res)

    def sample(self, grid, e, n):
        x = (np.asarray(e) - self.e0) / self.res
        y = (np.asarray(n) - self.n0) / self.res
        return ndimage.map_coordinates(grid, [y, x], order=1, mode="nearest")


def polygon_mask(poly, e, n):
    """Points inside a polygon (even-odd), vectorised."""
    poly = np.asarray(poly, float)
    inside = np.zeros(np.shape(e), bool)
    x, y = np.asarray(e, float), np.asarray(n, float)
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        cond = ((yi > y) != (yj > y)) & (x < (xj - xi) * (y - yi) / (yj - yi + 1e-12) + xi)
        inside ^= cond
        j = i
    return inside


def rect_distance(poly, e, n):
    """Distance outside a convex polygon (0 inside)."""
    from shapely import Polygon, points, distance
    return distance(Polygon(poly), points(np.stack([e, n], -1)))


def land_polygons():
    sm = g.ILE_SAINT_MICHEL
    a = np.linspace(0, 2 * math.pi, 40, endpoint=False)
    wob = 1 + 0.12 * np.sin(3 * a) + 0.07 * np.cos(5 * a)
    island = np.column_stack([sm["center"][0] + sm["rx"] * wob * np.cos(a), sm["center"][1] + sm["ry"] * wob * np.sin(a)])
    return [g._west_bank(), g._east_bank(), island], [g.PETITE_MER] + g.water_cuts()


def heights(field: Field, e, n):
    """Terrain height (m) at arrays of points."""
    s = field.sample(field.sdist, e, n)
    # ---- land
    hills = 32 * (g.fbm(e, n, 1600, 4, seed=3) - 0.35)
    # Low dunes of Gavres and the Larmor shore, blended over 500 m.
    low = np.maximum(1 - g.smooth(rect_distance([(700, -2500), (4200, -2500), (4200, -6600), (700, -6600)], e, n) / 500),
                     1 - g.smooth(rect_distance([(-4200, -2000), (-900, -2000), (-900, -3200), (-4200, -3200)], e, n) / 500))
    hills = hills * (1 - low) + (0.25 * hills + 3) * low
    rise = 0.6 + 5.5 * (1 - np.exp(-np.maximum(s, 0) / 70))
    h_land = rise + np.maximum(hills, -rise + 0.8) * (1 - np.exp(-np.maximum(s, 0) / 380))
    # Citadel rock: steep granite edge.
    c = np.hypot(e - g.CITADEL["center"][0], n - g.CITADEL["center"][1])
    rock = np.clip((260 - c) / 80, 0, 1)
    h_land = np.where(rock > 0, np.maximum(h_land, 6.5 * rock * np.clip(s / 6, 0, 1)), h_land)
    # Base platform, blended into the surrounding ground.
    deck_d = rect_distance(g.BASE_DECK, e, n)
    h_land = np.where(deck_d <= 0, g.QUAY, h_land + (g.QUAY - h_land) * (1 - g.smooth(deck_d / 90)))
    for poly, floor in g.dry_cuts():
        h_land = np.where(polygon_mask(poly, e, n), floor, h_land)
    # ---- water
    depth = -0.6 + np.maximum(-s, 0) * 0.035
    depth = np.minimum(depth, 5.0 + 1.5 * g.value_noise(e, n, 700, 5))
    sea = np.clip((-2300 - n) * 0.0075, 0, 30) * g.smooth(-s / 350)
    depth = np.maximum(depth, 4 + sea)
    depth = np.where(-s < 30, np.minimum(depth, -0.6 + np.maximum(-s, 0) * 0.2), depth)
    petite = polygon_mask(g.PETITE_MER, e, n)
    depth = np.where(petite, np.minimum(depth, 1.2), depth)
    depth = np.maximum(depth, g.channel_depth(e, n))
    # Dredged approaches along the base's quays and inside its basins.
    east = g.site_ring([(0, -110), (160, -110), (160, 700), (0, 700)])
    appr = rect_distance(east, e, n)
    depth = np.where(appr < 60, np.maximum(depth, -g.PEN_FLOOR * (1 - g.smooth(appr / 60))), depth)
    for i, cut in enumerate(g.water_cuts()):
        m = polygon_mask(cut, e, n)
        floor = -g.FISHING_BASIN["floor"] if i >= 2 else -g.PEN_FLOOR
        depth = np.where(m, np.maximum(depth, floor), depth)
    h_water = -depth
    return np.where(s >= 0, h_land, h_water), s


def build():
    """Return (terrain mesh, field, height sampler)."""
    land, water = land_polygons()
    ex, fn = g.EXTENT, g.FINE
    coarse_field = Field(ex["e0"] - 200, ex["e1"] + 200, ex["n0"] - 200, ex["n1"] + 200, 4.0, land, water)
    fine_field = Field(fn["e0"] - 40, fn["e1"] + 40, fn["n0"] - 40, fn["n1"] + 40, 1.0, land, water)

    def height_at(e, n):
        e, n = np.asarray(e, float), np.asarray(n, float)
        inside = (e > fn["e0"]) & (e < fn["e1"]) & (n > fn["n0"]) & (n < fn["n1"])
        out = np.empty(np.shape(e))
        sd = np.empty(np.shape(e))
        if inside.any():
            out[inside], sd[inside] = heights(fine_field, e[inside], n[inside])
        if (~inside).any():
            out[~inside], sd[~inside] = heights(coarse_field, e[~inside], n[~inside])
        return out, sd

    mesh = Mesh("LorientTerrain")
    span_e, span_n = ex["e1"] - ex["e0"], ex["n1"] - ex["n0"]

    def grid(e0, e1, n0, n1, step, skip=None, border_from=None):
        es = np.arange(e0, e1 + step / 2, step)
        ns = np.arange(n0, n1 + step / 2, step)
        E, N = np.meshgrid(es, ns)
        H, _ = height_at(E, N)
        if border_from is not None:
            # Fine border vertices follow the coarse edges exactly: no cracks at the seam.
            ce, cn, ch = border_from
            for sl in [(0, slice(None)), (-1, slice(None)), (slice(None), 0), (slice(None), -1)]:
                H[sl] = interp_coarse(ce, cn, ch, E[sl], N[sl])
        # Smooth normals from central differences.
        gy, gx = np.gradient(H, step)
        nrm = np.stack([-gx, -gy, np.ones_like(H)], -1)
        nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
        uv = np.stack([(E - ex["e0"]) / span_e, (N - ex["n0"]) / span_n], -1)
        P = np.stack([E, N, H], -1)
        tris, uvs, nms = [], [], []
        for j in range(len(ns) - 1):
            i = np.arange(len(es) - 1)
            if skip is not None:
                i = i[~skip(es[i], es[i + 1], ns[j], ns[j + 1])]
            a, b, c, d = (j, i), (j, i + 1), (j + 1, i + 1), (j + 1, i)
            for t in [(a, b, c), (a, c, d)]:
                tris.append(np.stack([P[k] for k in t], 1))
                uvs.append(np.stack([uv[k] for k in t], 1))
                nms.append(np.stack([nrm[k] for k in t], 1))
        mesh.add(np.concatenate(tris), np.concatenate(uvs), np.concatenate(nms))
        return es, ns, H

    def skip_fine(ea, eb, na, nb):
        return (ea >= fn["e0"]) & (eb <= fn["e1"]) & (na >= fn["n0"]) & (nb <= fn["n1"])

    ce, cn, ch = grid(ex["e0"], ex["e1"], ex["n0"], ex["n1"], ex["step"], skip=skip_fine)
    grid(fn["e0"], fn["e1"], fn["n0"], fn["n1"], fn["step"], border_from=(ce, cn, ch))
    return mesh, coarse_field, height_at


def interp_coarse(es, ns, H, e, n):
    x = (e - es[0]) / (es[1] - es[0])
    y = (n - ns[0]) / (ns[1] - ns[0])
    return ndimage.map_coordinates(H, [y, x], order=1, mode="nearest")


# ------------------------------------------------------------ land cover map
PALETTE = {
    "deep": (22, 38, 40), "shallow": (70, 82, 70), "mud": (88, 80, 64), "sand": (178, 164, 128),
    "rock": (92, 90, 84), "grass": (74, 92, 46), "field_a": (98, 104, 56), "field_b": (126, 112, 70),
    "field_c": (70, 86, 42), "town": (104, 98, 92), "ruin": (120, 110, 100), "quay": (128, 126, 120),
    "wood": (40, 56, 30),
}


def landcover(height_at, size=(4096, 4096), towns=(), blur=0.8):
    """Colour map over EXTENT (sRGB) and a mask (R fields/grass, G paved, B wet, A rock)."""
    ex = g.EXTENT
    W, H = size
    col = np.zeros((H, W, 3), np.float32)
    mask = np.zeros((H, W, 4), np.float32)
    rows = 256
    for r0 in range(0, H, rows):
        r1 = min(H, r0 + rows)
        ys = np.arange(r0, r1)
        xs = np.arange(W)
        X, Y = np.meshgrid(xs, ys)
        e = ex["e0"] + (X + 0.5) / W * (ex["e1"] - ex["e0"])
        n = ex["n1"] - (Y + 0.5) / H * (ex["n1"] - ex["n0"])   # image row 0 = north
        h, s = height_at(e, n)
        c, m = classify(e, n, h, s, towns)
        col[r0:r1], mask[r0:r1] = c, m
    img = Image.fromarray(np.clip(col, 0, 255).astype(np.uint8))
    if blur:
        img = img.filter(ImageFilter.GaussianBlur(blur))
    return img, Image.fromarray(np.clip(mask * 255, 0, 255).astype(np.uint8), "RGBA")


def hash_cells(a, b):
    k = (a.astype(np.int64) * 374761393 + b.astype(np.int64) * 668265263) & 0xFFFFFFFF
    k = ((k ^ (k >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((k ^ (k >> 16)) & 0xFFFFFF) / float(0x1000000)


def classify(e, n, h, s, towns):
    P = {k: np.array(v, np.float32) for k, v in PALETTE.items()}
    shape = np.shape(e)
    noise = g.fbm(e, n, 90, 3, seed=11)
    col = np.zeros(shape + (3,), np.float32)
    mask = np.zeros(shape + (4,), np.float32)
    water = s < 0
    # Seabed: mud in the roadstead, sand outside, darker with depth.
    depth = np.clip(-h, 0, 40)
    sand_w = g.smooth((-2300 - n) / 900)[..., None]
    bed = P["mud"] * (1 - sand_w) + P["sand"] * 0.8 * sand_w
    bed = bed * (0.85 + 0.3 * noise[..., None])
    t = np.clip(depth / 14, 0, 1)[..., None]
    col = np.where(water[..., None], bed * (1 - t) + P["deep"] * t, col)
    mask[..., 2] = np.where(water, 1, 0)
    # Foreshore: sand or mud up to 25 m inland, rock near the citadel and Gavres points.
    fore = (~water) & (s < 22 + 18 * noise)
    sandy = (n < -1300) | (e > 1300)
    fore_col = np.where(sandy[..., None], P["sand"], P["mud"] * 1.1)
    # Farmland in hedged fields; wood clumps; turf elsewhere.
    # Bocage: irregular fields of 1 to 3 ha, warped by noise, bounded by hedges.
    we = e + 90 * (g.value_noise(e, n, 420, 31) - 0.5) + 25 * (g.value_noise(e, n, 90, 32) - 0.5)
    wn = n + 90 * (g.value_noise(e, n, 420, 33) - 0.5) + 25 * (g.value_noise(e, n, 90, 34) - 0.5)
    fx, fy = np.floor(we / 150), np.floor(wn / 105)
    k = np.floor(hash_cells(fx, fy) * 5)
    kk = k[..., None]
    fields = np.select([kk == 0, kk == 1, kk == 2, kk == 3], [P["field_a"], P["field_b"], P["field_c"], P["grass"]], P["field_a"])
    fields = fields * (0.9 + 0.2 * hash_cells(fx + 101, fy)[..., None])
    hedge = (np.abs((we % 150) - 75) > 72) | (np.abs((wn % 105) - 52.5) > 50)
    fields = np.where(hedge[..., None], P["wood"] * 1.1, fields)
    wood = g.fbm(e, n, 260, 3, seed=21) > 0.64
    land_col = np.where(wood[..., None], P["wood"], fields) * (0.88 + 0.24 * noise[..., None])
    mask[..., 0] = np.where(~water, 1, 0)
    # Towns: grey-brown blocks and streets; ruins are paler in Lorient after the 1943 raids.
    for name, poly, bearing, ruined, scale, density in towns:
        m = (~water) & polygon_mask(poly, e, n)
        if not m.any():
            continue
        c = P["ruin"] if ruined > 0.5 else P["town"]
        # Sparse suburbs keep gardens between the houses.
        a = np.clip(density * 1.3, 0, 1) * (0.75 + 0.25 * noise)
        town = c * (0.85 + 0.3 * noise[..., None])
        land_col = np.where(m[..., None], land_col * (1 - a[..., None]) + town * a[..., None], land_col)
        mask[..., 1] = np.where(m, 0.8 * a, mask[..., 1])
        mask[..., 0] = np.where(m, 1 - 0.8 * a, mask[..., 0])
    deck = polygon_mask(g.BASE_DECK, e, n) & ~water
    land_col = np.where(deck[..., None], P["quay"] * (0.9 + 0.15 * noise[..., None]), land_col)
    mask[..., 1] = np.where(deck, 1, mask[..., 1])
    mask[..., 0] = np.where(deck, 0, mask[..., 0])
    land_col = np.where((fore & ~deck)[..., None], fore_col, land_col)
    rocky = np.hypot(e - g.CITADEL["center"][0], n - g.CITADEL["center"][1]) < 300
    rocky |= (n < -3900) & (e > 900) & (e < 1400)
    rock_m = (~water) & rocky & (s < 30)
    land_col = np.where(rock_m[..., None], P["rock"] * (0.8 + 0.4 * noise[..., None]), land_col)
    mask[..., 3] = np.where(rock_m, 1, 0)
    mask[..., 2] = np.where(fore & ~deck, 0.6, mask[..., 2])
    col = np.where(water[..., None], col, land_col)
    return col, mask
