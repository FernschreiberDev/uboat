"""Procedural, seamlessly tiling PBR textures for Keroman and Lorient.

Each material gets a colour map (sRGB), a DirectX normal map and an ORM mask (R ambient occlusion,
G roughness, B metallic), 1024 px. Patterns follow period references: Keroman's walls show the
horizontal boards of their formwork with tie-rod holes and rust runs; roofs are rough concrete with
lichen; quays are granite setts; doors are riveted steel plates in weathered grey; the town is
Breton granite rubble masonry under slate.
"""
from __future__ import annotations

import numpy as np
from PIL import Image

SIZE = 1024


def rng(seed):
    return np.random.default_rng(seed)


def fnoise(shape, beta, seed, lowcut=0):
    """Periodic 1/f^beta noise in [0, 1]: tiles seamlessly."""
    r = rng(seed)
    white = r.standard_normal(shape)
    F = np.fft.fft2(white)
    fy = np.fft.fftfreq(shape[0])[:, None] * shape[0]
    fx = np.fft.fftfreq(shape[1])[None, :] * shape[1]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1
    filt = 1 / f ** beta
    if lowcut:
        filt *= (f >= lowcut)
    out = np.real(np.fft.ifft2(F * filt))
    out -= out.min()
    return out / max(out.max(), 1e-9)


def blur_periodic(a, sigma):
    fy = np.fft.fftfreq(a.shape[0])[:, None]
    fx = np.fft.fftfreq(a.shape[1])[None, :]
    g = np.exp(-2 * (np.pi * sigma) ** 2 * (fx * fx + fy * fy))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g))


def normal_dx(height, strength):
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) / 2
    dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) / 2
    n = np.stack([-dx * strength, -dy * strength, np.ones_like(height)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n


def to_img(a):
    return Image.fromarray(np.clip(a * 255 + 0.5, 0, 255).astype(np.uint8))


def save(out, name, color, height, strength, rough, metal=0.0, ao=None):
    out.mkdir(parents=True, exist_ok=True)
    ao = np.clip(0.55 + 0.45 * (height - height.min()) / max(np.ptp(height), 1e-9), 0, 1) if ao is None else ao
    orm = np.stack([ao, rough, np.broadcast_to(np.asarray(metal, float), rough.shape)], -1)
    to_img(np.clip(color, 0, 1)).save(out / f"T_{name}_D.jpg", quality=93)
    to_img(normal_dx(height, strength) * 0.5 + 0.5).save(out / f"T_{name}_N.jpg", quality=95)
    to_img(orm).save(out / f"T_{name}_ORM.jpg", quality=93)


def srgb(rgb):
    return np.array(rgb, float) / 255


def hash01(a, b, seed=0):
    """Well-mixed per-cell random value in [0, 1) from integer cell coordinates."""
    k = (a.astype(np.int64) * 374761393 + b.astype(np.int64) * 668265263 + seed * 2246822519) & 0xFFFFFFFF
    k = ((k ^ (k >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((k ^ (k >> 16)) & 0xFFFFFF) / float(0x1000000)


def grid(n=SIZE):
    y, x = np.mgrid[0:n, 0:n]
    return x / n, y / n


# --------------------------------------------------------------- materials
def concrete(out, tile_m=4.0):
    """Board-formed wall concrete: 16 cm boards, tie holes every 80 cm, rain streaks, rust runs."""
    x, y = grid()
    boards = tile_m / 0.16                             # boards per tile (25)
    by = y * boards
    board_id = np.floor(by)
    frac = by - board_id
    r = rng(1)
    # Staggered butt joints of the boards.
    # One butt joint per board and per tile width, at a random place (boards about 4 m long).
    off = r.uniform(0, 1, int(boards) + 1)[board_id.astype(int) % (int(boards) + 1)]
    d = np.abs(((x - off) + 0.5) % 1 - 0.5) * tile_m
    butt = np.clip(1 - d / 0.006, 0, 1)
    seam = np.clip(1 - np.minimum(frac, 1 - frac) * 22, 0, 1)
    grain = fnoise((SIZE, SIZE), 0.6, 2)
    # Wood grain printed by the boards: stretched along them (image x).
    wood = fnoise((SIZE, SIZE // 16), 1.0, 3)
    wood = np.array(Image.fromarray((wood * 255).astype(np.uint8)).resize((SIZE, SIZE), Image.BILINEAR)) / 255.0
    board_tone = r.uniform(-0.06, 0.06, int(boards) + 1)[board_id.astype(int) % (int(boards) + 1)]
    macro = fnoise((SIZE, SIZE), 2.2, 4)
    height = 0.35 * wood + 0.25 * grain - 0.9 * seam - 0.5 * butt + 0.3 * (board_tone + 0.06)
    # Tie-rod holes, plugged with mortar, 80 cm grid.
    tie = np.zeros_like(x)
    for cx in np.arange(0.4, tile_m, 0.8) / tile_m:
        for cy in np.arange(0.4, tile_m, 0.8) / tile_m:
            d = np.hypot(((x - cx + 0.5) % 1 - 0.5) * tile_m, ((y - cy + 0.5) % 1 - 0.5) * tile_m)
            tie = np.maximum(tie, np.clip(1 - d / 0.035, 0, 1))
    height -= 0.8 * tie
    # Rust runs below some tie holes and rain streaks: vertical, fading downward (image y down).
    rust = np.zeros_like(x)
    for cx in np.arange(0.4, tile_m, 0.8) / tile_m:
        for cy in np.arange(0.4, tile_m, 0.8) / tile_m:
            if r.random() < 0.35:
                dx = np.abs(((x - cx + 0.5) % 1 - 0.5) * tile_m)
                dy = ((y - cy) % 1) * tile_m
                length = r.uniform(0.3, 1.4)
                rust = np.maximum(rust, np.clip(1 - dx / (0.02 + 0.03 * dy), 0, 1) * np.clip(1 - dy / length, 0, 1) * (dy > 0))
    streak_cols = fnoise((1, SIZE), 0.8, 5)
    streaks = np.repeat(streak_cols, SIZE, 0)
    streaks = np.clip((streaks - 0.6) * 2, 0, 1) * (0.4 + 0.6 * fnoise((SIZE, SIZE), 1.6, 6))
    base = srgb((146, 144, 137))
    col = base[None, None, :] * (0.86 + 0.18 * macro[..., None] + 0.6 * board_tone[..., None] + 0.08 * grain[..., None])
    col *= (1 - 0.22 * streaks[..., None])
    col = col * (1 - 0.5 * seam[..., None] - 0.3 * butt[..., None])
    col = col * (1 - 0.4 * tie[..., None])
    col = col * (1 - rust[..., None] * 0.7) + srgb((120, 62, 28))[None, None] * rust[..., None] * 0.7
    rough = np.clip(0.86 + 0.08 * grain - 0.1 * rust, 0, 1)
    save(out, "KeromanConcrete", col, height, 5.0, rough)


def roof(out):
    """Rough roof concrete with grit, lichen and water stains; low contrast so 12 m tiles do not show."""
    grit = fnoise((SIZE, SIZE), 0.3, 11)
    macro = fnoise((SIZE, SIZE), 1.2, 12)
    lichen = np.clip((fnoise((SIZE, SIZE), 0.9, 13) - 0.62) * 4, 0, 1) * (fnoise((SIZE, SIZE), 0.5, 14) > 0.5)
    stains = np.clip((fnoise((SIZE, SIZE), 1.3, 15) - 0.6) * 2, 0, 1)
    height = 0.7 * grit + 0.3 * macro
    col = srgb((134, 133, 127))[None, None] * (0.92 + 0.1 * macro[..., None] + 0.15 * (grit[..., None] - 0.5))
    col *= 1 - 0.15 * stains[..., None]
    col = col * (1 - 0.45 * lichen[..., None]) + srgb((110, 114, 78))[None, None] * 0.45 * lichen[..., None]
    rough = np.clip(0.9 + 0.05 * grit - 0.1 * stains, 0, 1)
    save(out, "KeromanRoof", col, height, 4.0, rough)


def setts(out, tile_m=3.0):
    """Granite setts in running courses, 22 x 14 cm, with sand joints."""
    x, y = grid()
    rows = tile_m / 0.14
    ry = y * rows
    row = np.floor(ry)
    shift = (row % 2) * 0.5
    cols = tile_m / 0.22
    rx = x * cols + shift + rng(21).uniform(0, 0.3, int(rows) + 1)[row.astype(int) % (int(rows) + 1)]
    col_id = np.floor(rx)
    fx, fy = rx - col_id, ry - row
    edge = np.minimum(np.minimum(fx, 1 - fx) * 0.22, np.minimum(fy, 1 - fy) * 0.14)   # metres
    stone = np.clip(edge / 0.012, 0, 1)
    dome = np.sqrt(np.clip(edge / 0.07, 0, 1))
    tone = (hash01(col_id, row, 3) - 0.5) * 0.2
    speck = fnoise((SIZE, SIZE), 0.1, 22)
    height = dome * stone * 0.8 + 0.1 * speck
    granite = srgb((128, 128, 126))[None, None] * (0.95 + tone[..., None] + 0.25 * (speck[..., None] - 0.5))
    joint = srgb((92, 86, 74))[None, None]
    col = granite * stone[..., None] + joint * (1 - stone[..., None])
    col *= 0.9 + 0.2 * fnoise((SIZE, SIZE), 2.0, 23)[..., None]
    rough = np.clip(0.72 + 0.2 * (1 - stone) + 0.05 * speck, 0, 1)
    save(out, "KeromanQuay", col, height, 6.0, rough)


def steel(out, tile_m=2.0):
    """Riveted plates painted grey, chipped to rust, with runs."""
    x, y = grid()
    plate_w, plate_h = 1.0 / tile_m, 0.5 / tile_m          # 1 m x 0.5 m plates
    px, py = (x / plate_w) % 1, (y / plate_h) % 1
    seam = np.clip(1 - np.minimum(np.minimum(px, 1 - px) * 1.0 / 0.004, np.minimum(py, 1 - py) * 0.5 / 0.004), 0, 1)
    d_edge_x = np.minimum(px, 1 - px) * 1.0
    d_edge_y = np.minimum(py, 1 - py) * 0.5
    along_x = ((x * tile_m / 0.08) % 1 - 0.5) * 0.08
    along_y = ((y * tile_m / 0.08) % 1 - 0.5) * 0.08
    rivet = np.maximum(np.clip(1 - np.hypot(d_edge_y - 0.035, along_x) / 0.012, 0, 1),
                       np.clip(1 - np.hypot(d_edge_x - 0.035, along_y) / 0.012, 0, 1))
    chips = np.clip((fnoise((SIZE, SIZE), 1.1, 31) - 0.66) * 6, 0, 1)
    runs = np.repeat(fnoise((1, SIZE), 0.9, 32), SIZE, 0)
    runs = np.clip((runs - 0.6) * 4, 0, 1) * fnoise((SIZE, SIZE), 1.8, 33)
    macro = fnoise((SIZE, SIZE), 2.0, 34)
    paint = srgb((96, 100, 100))
    rust = srgb((104, 52, 24))
    col = paint[None, None] * (0.85 + 0.2 * macro[..., None])
    col = col * (1 - chips[..., None]) + rust[None, None] * chips[..., None]
    col = col * (1 - 0.5 * runs[..., None]) + rust[None, None] * 0.5 * runs[..., None]
    col *= 1 - 0.4 * seam[..., None]
    height = 0.8 * rivet - 0.4 * seam - 0.2 * chips + 0.05 * macro
    rough = np.clip(0.55 + 0.35 * chips + 0.15 * runs + 0.05 * macro, 0, 1)
    # Painted steel reads as a dielectric; bare metal only shows through the chips, mostly rusted.
    metal = 0.1 * chips
    save(out, "KeromanSteel", col, height, 8.0, rough, metal)


def masonry(out, tile_m=3.0):
    """Breton granite rubble masonry: irregular stones in rough courses, lime mortar."""
    x, y = grid()
    r = rng(41)
    # Jittered Voronoi cells, stretched into courses, periodic.
    n = 180
    pts = np.column_stack([r.uniform(0, 1, n), r.uniform(0, 1, n)])
    best = np.full(x.shape, 9.0)
    second = np.full(x.shape, 9.0)
    ident = np.zeros(x.shape, int)
    for i, (px, py) in enumerate(pts):
        dx = (x - px + 0.5) % 1 - 0.5
        dy = ((y - py + 0.5) % 1 - 0.5) * 1.8                # courses: wider than tall
        d = np.hypot(dx, dy)
        closer = d < best
        second = np.where(closer, best, np.minimum(second, d))
        ident = np.where(closer, i, ident)
        best = np.minimum(best, d)
    gap = second - best
    stone = np.clip((gap - 0.0025) / 0.005, 0, 1)
    dome = np.sqrt(np.clip(gap / 0.05, 0, 1))
    tone = r.uniform(-0.12, 0.12, n)[ident]
    warm = r.uniform(0, 1, n)[ident]
    speck = fnoise((SIZE, SIZE), 0.1, 42)
    granite = (srgb((136, 132, 124)) * (1 - warm[..., None] * 0.3) + srgb((150, 136, 112)) * warm[..., None] * 0.3)
    granite = granite * (0.95 + tone[..., None] + 0.3 * (speck[..., None] - 0.5))
    mortar = srgb((140, 134, 120))[None, None]
    col = granite * stone[..., None] + mortar * (1 - stone[..., None])
    grime = fnoise((SIZE, SIZE), 2.0, 43)
    col *= 0.82 + 0.25 * grime[..., None]
    height = dome * stone + 0.08 * speck
    rough = np.clip(0.8 + 0.12 * (1 - stone) + 0.05 * speck, 0, 1)
    save(out, "LorientMasonry", col, height, 5.0, rough)


def slate(out, tile_m=2.0):
    """Slate roofing: 22 cm courses, staggered 30 cm slates, blue-grey."""
    x, y = grid()
    rows = tile_m / 0.11
    ry = y * rows
    row = np.floor(ry)
    fy = ry - row
    cols = tile_m / 0.3
    rx = x * cols + (row % 2) * 0.5
    cid = np.floor(rx)
    fx = rx - cid
    tone = (hash01(cid, row, 5) - 0.5) * 0.18
    edge_x = np.clip(np.minimum(fx, 1 - fx) * 0.3 / 0.004, 0, 1)
    lap = fy                                     # each course overlaps the one below
    height = 0.6 * lap + 0.3 * edge_x - 0.3 * (fy > 0.97)
    moss = np.clip((fnoise((SIZE, SIZE), 1.6, 51) - 0.7) * 5, 0, 1)
    col = srgb((70, 76, 84))[None, None] * (1 + tone[..., None] + 0.15 * (1 - lap[..., None]))
    col *= (0.6 + 0.4 * edge_x[..., None])
    col = col * (1 - 0.5 * moss[..., None]) + srgb((96, 100, 60))[None, None] * 0.5 * moss[..., None]
    rough = np.clip(0.55 + 0.25 * moss + 0.1 * (1 - edge_x), 0, 1)
    save(out, "LorientSlate", col, height, 4.0, rough)


def foliage(out):
    leaf = fnoise((256, 256), 0.4, 61)
    clump = fnoise((256, 256), 1.8, 62)
    col = srgb((46, 64, 34))[None, None] * (0.7 + 0.5 * clump[..., None] + 0.2 * (leaf[..., None] - 0.5))
    height = 0.6 * clump + 0.4 * leaf
    orm = np.stack([0.6 + 0.4 * clump, np.full(leaf.shape, 0.85), np.zeros(leaf.shape)], -1)
    to_img(col).save(out / "T_LorientTrees_D.jpg", quality=92)
    to_img(normal_dx(height, 6.0) * 0.5 + 0.5).save(out / "T_LorientTrees_N.jpg", quality=95)
    to_img(orm).save(out / "T_LorientTrees_ORM.jpg", quality=92)


def ground_detail(out):
    """Tiling detail for the terrain (R grass, G sand, B mud, A rock), multiplied over the land-cover map."""
    grass = fnoise((SIZE, SIZE), 0.2, 71)
    sand = fnoise((SIZE, SIZE), 0.05, 72)
    mud = np.clip(1 - np.abs(fnoise((SIZE, SIZE), 1.2, 73) - 0.5) * 8, 0, 1) * 0.5 + 0.5 * fnoise((SIZE, SIZE), 0.8, 74)
    rock = fnoise((SIZE, SIZE), 1.0, 75)
    img = np.stack([grass, sand, mud, rock], -1)
    Image.fromarray(np.clip(img * 255, 0, 255).astype(np.uint8), "RGBA").save(out / "T_LorientGroundDetail.png", optimize=True)


def build_all(out):
    concrete(out); roof(out); setts(out); steel(out); masonry(out); slate(out); foliage(out); ground_detail(out)
