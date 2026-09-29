"""Buildings and harbour works of Keroman and the roadstead, one Mesh per material.

Heights in metres above mean sea level. Site boxes use geography.S (u towards the roadstead out of
the K3 pens, v along the quay).
"""
from __future__ import annotations

import math
import random

import numpy as np
from shapely import Polygon, Point
from shapely.ops import unary_union

import geography as g
from geography import S, site_rect, site_ring
from meshkit import Mesh, rect
from terrain import polygon_mask

Q = g.QUAY


class Kit:
    def __init__(self):
        self.concrete = Mesh("KeromanConcrete", tile=4.0)    # board-formed bunker walls
        self.roof = Mesh("KeromanRoof", tile=12.0)            # roof tops, Fangrost
        self.quay = Mesh("KeromanQuay", tile=3.0)            # quays, aprons, slipways
        self.steel = Mesh("KeromanSteel", tile=2.0)          # doors, carriages, rails, cranes
        self.masonry = Mesh("LorientMasonry", tile=3.0)      # granite walls, citadel, houses
        self.slate = Mesh("LorientSlate", tile=2.0)          # slate roofs
        self.trees = Mesh("LorientTrees", tile=4.0)
        self.red = Mesh("BuoyRed", tile=1.0)
        self.green = Mesh("BuoyGreen", tile=1.0)
        self.props = []          # static VIIC placements for Unreal
        self.labels = []         # named points for the preview and the docs

    def meshes(self):
        return [self.concrete, self.roof, self.quay, self.steel, self.masonry, self.slate, self.trees, self.red, self.green]


def sbox(mesh, u0, u1, v0, v1, z0, z1, top=True, bottom=False):
    mesh.prism(site_rect(min(u0, u1), max(u0, u1), min(v0, v1), max(v0, v1)), z0, z1, top=top, bottom=bottom)


def paved(kit, ring, z0, z1):
    """Solid with concrete sides and a paved (setts) top."""
    kit.concrete.prism(ring, z0, z1, top=False)
    kit.quay.polygon(ring, z1, True)


def slab(kit, u0, u1, v0, v1, z0, z1):
    """Roof slab: concrete edges and soffit, weathered roof material on top."""
    ring = site_rect(u0, u1, v0, v1)
    kit.concrete.prism(ring, z0, z1, top=False, bottom=True)
    kit.roof.polygon(ring, z1, True)


def viic(kit, label, u, v, z_keel=None, bearing=None, afloat=True):
    e, n = S(u, v)
    kit.props.append(dict(label=label, e=e, n=n, keel=z_keel, afloat=afloat,
                          bearing=g.SITE_BEARING + 90 if bearing is None else bearing))


def cradle(kit, u_center, v, z0, z1, length=60.0):
    """Row of steel saddles and two longitudinal girders carrying a boat's keel."""
    sbox(kit.steel, u_center - length / 2, u_center + length / 2, v - 2.6, v - 1.6, z0, z0 + 0.8)
    sbox(kit.steel, u_center - length / 2, u_center + length / 2, v + 1.6, v + 2.6, z0, z0 + 0.8)
    for k in range(7):
        uu = u_center - length / 2 + 4 + k * (length - 8) / 6
        sbox(kit.steel, uu - 0.7, uu + 0.7, v - 3.2, v + 3.2, z0 + 0.8, z1)


def rails(kit, u0, u1, v0, v1, along_u, z, count, gauge=1.435):
    """Pairs of rails on a floor."""
    if along_u:
        centres = np.linspace(v0, v1, count + 2)[1:-1]
        for c in centres:
            for off in (-gauge / 2, gauge / 2):
                sbox(kit.steel, u0, u1, c + off - 0.04, c + off + 0.04, z, z + 0.15)
    else:
        centres = np.linspace(u0, u1, count + 2)[1:-1]
        for c in centres:
            for off in (-gauge / 2, gauge / 2):
                sbox(kit.steel, c + off - 0.04, c + off + 0.04, v0, v1, z, z + 0.15)


# ------------------------------------------------------------------ Keroman III
def keroman3(kit):
    k = g.K3
    top = Q + k["height"]                 # 24.5 m
    ceiling = top - k["roof"]             # 17.1 m
    grid_base = ceiling + 4.2             # slab 4.2 m, Fangrost beams above
    pens = g.k3_pens()
    front = 4.0                           # walls and roof project 4 m over the water
    edges = [k["v0"]] + [p for pen in pens for p in pen] + [k["v1"]]
    for v0, v1 in zip(edges[0::2], edges[1::2]):      # the eight walls
        sbox(kit.concrete, k["u0"], front, v0, v1, g.PEN_FLOOR - 0.5, ceiling)
    sbox(kit.concrete, k["u0"], k["u0"] + k["rear"], k["v0"], k["v1"], Q - 0.2, ceiling)
    slab(kit, k["u0"], front, k["v0"], k["v1"], ceiling, grid_base)
    # Bomb-catching grid: beams along the pens with open gaps between them.
    v = k["v0"] + 0.8
    while v + 1.6 <= k["v1"] - 0.8:
        kit.roof.prism(site_rect(k["u0"] + 0.8, front - 0.8, v, v + 1.6), grid_base, top)
        v += 3.5
    for u in (k["u0"] + 0.8, front - 2.4):        # edge beams across the ends
        kit.roof.prism(site_rect(u, u + 1.6, k["v0"] + 0.8, k["v1"] - 0.8), grid_base, top)
    # Lintel over the pen entrances.
    sbox(kit.concrete, front - 5.0, front, k["v0"], k["v1"], 13.0, ceiling, top=False, bottom=True)
    for i, (p0, p1) in enumerate(pens):
        # Working quays along both sides of each basin.
        for a, b in ((p0, p0 + k["quay"]), (p1 - k["quay"], p1)):
            paved(kit, site_rect(k["u0"] + k["rear"], -1.0, a, b), g.PEN_FLOOR - 0.5, Q)
        rails(kit, k["u0"] + k["rear"], -1.5, p0, p0 + k["quay"], True, Q, 1, gauge=1.0)
        if i >= 5:
            # The two northern pens are dry docks, shown flooded behind their caisson gates.
            sbox(kit.steel, 0.5, 2.5, p0 + k["quay"] - 0.3, p1 - k["quay"] + 0.3, g.PEN_FLOOR, Q + 0.3)
            viic(kit, f"VIIC en forme de radoub K3/{i + 1}", -60, (p0 + p1) / 2)
        elif i != g.PLAYER_PEN:
            viic(kit, f"VIIC a quai K3/{i + 1}", -40 - 30 * (i % 2), (p0 + p1) / 2)
    # North-east and south-west extensions (workshops, reservoirs, casemates).
    sbox(kit.concrete, k["u0"], -60, k["v1"], k["v1"] + 20, Q - 0.2, Q + 12, top=False)
    kit.roof.polygon(site_rect(k["u0"], -60, k["v1"], k["v1"] + 20), Q + 12)
    sbox(kit.concrete, k["u0"], -80, k["v0"] - 20, k["v0"], Q - 0.2, Q + 10, top=False)
    kit.roof.polygon(site_rect(k["u0"], -80, k["v0"] - 20, k["v0"]), Q + 10)
    for u, v in ((-110, -55), (-110, 55), (-30, 0)):
        flak_tower(kit, u, v, top)
    kit.labels.append(("Keroman III", S(-69, 0), top))


def flak_tower(kit, u, v, base):
    """Concrete tower with a 2 cm quadruple mount's gun tub."""
    sbox(kit.concrete, u - 4, u + 4, v - 4, v + 4, base, base + 4.5)
    e, n = S(u, v)
    kit.concrete.ring_wall((e, n), 3.6, 3.0, base + 4.5, base + 5.7, 16)
    kit.steel.cylinder((e, n), 0.7, base + 4.5, base + 6.0, 8)
    for a in range(4):
        ang = math.radians(a * 90 + 20)
        kit.steel.beam((e + 0.3 * math.cos(ang), n + 0.3 * math.sin(ang), base + 6.0),
                       (e + 2.4 * math.cos(ang), n + 2.4 * math.sin(ang), base + 6.9), 0.12)


# ----------------------------------------------------------- Keroman I and II
def dry_block(kit, b, opens_towards_minus_u, name, boats):
    top = Q + b["height"]
    ceiling = top - b["roof"]
    u_open = b["u0"] if opens_towards_minus_u else b["u1"]
    u_rear0, u_rear1 = (b["u1"] - b["rear"], b["u1"]) if opens_towards_minus_u else (b["u0"], b["u0"] + b["rear"])
    bay = g.bays(b)
    edges = [b["v0"]] + [p for pr in bay for p in pr] + [b["v1"]]
    for v0, v1 in zip(edges[0::2], edges[1::2]):
        sbox(kit.concrete, b["u0"], b["u1"], v0, v1, Q - 0.2, ceiling)
    sbox(kit.concrete, u_rear0, u_rear1, b["v0"], b["v1"], Q - 0.2, ceiling)
    slab(kit, b["u0"], b["u1"], b["v0"], b["v1"], ceiling, top)
    sign = -1 if opens_towards_minus_u else 1
    lintel = (u_open, u_open - sign * 2.5)
    sbox(kit.concrete, min(lintel), max(lintel), b["v0"], b["v1"], Q + 12.0, ceiling, top=False, bottom=True)
    for i, (p0, p1) in enumerate(bay):
        width = p1 - p0
        rails(kit, min(u_open, u_rear0 if sign < 0 else u_rear1), max(u_open, u_rear0 if sign < 0 else u_rear1),
              p0, p1, True, Q + 0.12, 2, gauge=4.0)
        du = -sign * 1.2                       # door plane 1.2 m inside the opening
        uu = u_open + du
        if i in boats:
            # Open: both leaves folded back against the walls.
            for side in (p0 + 0.5, p1 - 1.3):
                sbox(kit.steel, min(uu, uu - sign * width / 2), max(uu, uu - sign * width / 2), side, side + 0.8, Q, Q + 12)
            ucen = u_open - sign * 40
            cradle(kit, ucen, (p0 + p1) / 2, Q + 0.2, Q + 1.9)
            viic(kit, f"VIIC en carenage {name}/{i + 1}", ucen, (p0 + p1) / 2, z_keel=Q + 1.9, afloat=False,
                 bearing=g.SITE_BEARING + (90 if sign > 0 else 270))
        else:
            sbox(kit.steel, uu - 0.4, uu + 0.4, p0 + 0.3, p1 - 0.3, Q, Q + 12)
            # Stiffeners on the leaves.
            for z in (Q + 3, Q + 6, Q + 9):
                sbox(kit.steel, uu + sign * 0.4, uu + sign * 0.7, p0 + 0.6, p1 - 0.6, z, z + 0.4)
    for u, v in ((b["u0"] + 20, b["v0"] + 20), (b["u1"] - 20, b["v1"] - 20)):
        flak_tower(kit, u, v, top)
    kit.labels.append((name, S((b["u0"] + b["u1"]) / 2, (b["v0"] + b["v1"]) / 2), top))


def slipway_and_traverser(kit):
    t, s = g.TRAVERSER, g.SLIPWAY
    floor = Q - t["depth"]
    ring = site_rect(t["u0"], t["u1"], t["v0"], t["v1"])
    kit.quay.polygon(ring, floor)
    # Pit walls, open on the east side where the slipway arrives.
    w = s["width"] / 2
    for (u0, v0), (u1, v1) in [((t["u0"], t["v0"]), (t["u1"], t["v0"])), ((t["u1"], t["v1"]), (t["u0"], t["v1"])),
                               ((t["u0"], t["v1"]), (t["u0"], t["v0"])), ((t["u1"], t["v0"]), (t["u1"], s["v"] - w)),
                               ((t["u1"], s["v"] + w), (t["u1"], t["v1"]))]:
        a, b = S(u0, v0), S(u1, v1)
        kit.quay.quad((*a, floor), (*a, Q + 0.12), (*b, Q + 0.12), (*b, floor))
    rails(kit, t["u0"], t["u1"], t["v0"], t["v1"], False, floor, 4, gauge=2.5)
    # Transfer carriage (Schiebebuehne) carrying a boat on its cradle.
    cv = t["carriage_v"]
    sbox(kit.steel, t["u0"] + 2, t["u1"] - 2, cv - 8, cv + 8, floor + 0.2, Q + 0.05)
    cradle(kit, (t["u0"] + t["u1"]) / 2, cv, Q + 0.05, Q + 1.8)
    viic(kit, "VIIC sur le transbordeur", (t["u0"] + t["u1"]) / 2, cv, z_keel=Q + 1.8, afloat=False)
    # Slipway: inclined concrete track from the carriage pit into the roadstead.
    w = s["width"] / 2
    z_top, z_foot = floor, g.SLIP_BOTTOM
    def z_at(u):
        return z_top + (z_foot - z_top) * (u - s["u_top"]) / (s["u_foot"] - s["u_top"])
    a, b = S(s["u_top"], s["v"] - w), S(s["u_top"], s["v"] + w)
    c, d = S(s["u_foot"], s["v"] + w), S(s["u_foot"], s["v"] - w)
    corners_top = [(*a, z_top), (*d, z_foot), (*c, z_foot), (*b, z_top)]
    kit.quay.quad(*corners_top)
    for p, q, zp, zq in ((a, d, z_top, z_foot), (c, b, z_foot, z_top)):
        kit.quay.quad((*p, zp - 2), (*q, zq - 2), (*q, zq), (*p, zp))
    for off in (-5.5, -2.0, 2.0, 5.5):
        p = S(s["u_top"], s["v"] + off); q = S(s["u_foot"], s["v"] + off)
        kit.steel.beam((*p, z_top + 0.1), (*q, z_foot + 0.1), 0.18)
    # Empty slipway cradle waiting at the head of the ramp.
    u = s["u_top"] + 20
    zc = z_at(u)
    sbox(kit.steel, u - 32, u + 32, s["v"] - 3.5, s["v"] + 3.5, zc - 1.2, zc + 0.9)
    # Winch house at the head of the slip.
    sbox(kit.concrete, s["u_top"] - 12, s["u_top"] - 2, s["v"] - 30, s["v"] - 18, Q, Q + 7, top=False)
    kit.roof.polygon(site_rect(s["u_top"] - 12, s["u_top"] - 2, s["v"] - 30, s["v"] - 18), Q + 7)
    kit.labels.append(("Slipway et transbordeur", S(-120, 200), Q + 3))


# ---------------------------------------------------- fishing port, Dombunkers
def pointed_profile(half_span, rise, spring, steps=14):
    xc = (rise * rise - half_span * half_span) / (2 * half_span)
    R = xc + half_span
    apex = math.atan2(rise, -xc)
    left = [(xc + R * math.cos(t), spring + R * math.sin(t)) for t in np.linspace(math.pi, apex, steps)]
    right = [(-x, z) for x, z in reversed(left[:-1])]
    return left + right


def dombunker(kit, name, u0, v0, axis_deg, length, with_boat):
    d = g.DOM
    ang = math.radians(axis_deg)
    du, dv = math.cos(ang), math.sin(ang)
    start = S(u0, v0)
    end_uv = (u0 + du * length, v0 + dv * length)
    e_axis = np.array(S(u0 + du, v0 + dv)) - np.array(start)
    bearing = math.degrees(math.atan2(e_axis[0], e_axis[1]))
    half_out, half_in = d["span"] / 2 + d["shell"], d["span"] / 2
    spring = Q + 3.0
    outer = pointed_profile(half_out, d["height"] - 3.0, spring)
    inner = pointed_profile(half_in, d["height"] - 3.0 - d["shell"], spring)
    shell = [(-half_out, Q - 0.2)] + outer + [(half_out, Q - 0.2), (half_in, Q - 0.2)] + inner[::-1] + [(-half_in, Q - 0.2)]
    kit.concrete.extrude_profile(shell, start, bearing, length)
    inner_closed = [(-half_in, Q - 0.2)] + inner + [(half_in, Q - 0.2)]
    far = np.array(start) + e_axis * (length - 3.0)
    kit.concrete.extrude_profile(inner_closed, far, bearing, 3.0)          # rear wall
    near = np.array(start) + e_axis * 1.5
    if with_boat:
        # Doors folded open; a boat on its cradle inside.
        cu, cv = u0 + du * 42, v0 + dv * 42
        cradle_line(kit, cu, cv, du, dv)
        viic(kit, f"VIIC sous le Dombunker {name}", cu, cv, z_keel=Q + 1.7, afloat=False, bearing=bearing)
    else:
        kit.steel.extrude_profile(inner_closed[:-1] + [(half_in, Q - 0.2)], near, bearing, 0.6)
    kit.labels.append((f"Dombunker {name}", S(*end_uv), Q + d["height"]))


def cradle_line(kit, u, v, du, dv, length=58.0):
    for k in range(7):
        t = -length / 2 + k * length / 6
        e, n = S(u + du * t, v + dv * t)
        axis = np.array(S(du, dv))
        kit.steel.box((e, n), 1.4, 6.4, Q, Q + 1.7, heading=math.degrees(math.atan2(axis[0], axis[1])))


def fishing_port(kit):
    tt, fb = g.TURNTABLE, g.FISHING_BASIN
    e, n = S(tt["u"], tt["v"])
    floor = Q - 1.5
    a = np.linspace(0, 2 * math.pi, 48, endpoint=False)
    pit = np.column_stack([e + tt["radius"] * np.cos(a), n + tt["radius"] * np.sin(a)])
    kit.quay.polygon(pit, floor)
    kit.quay.walls(pit, floor, Q + 0.12, outward=False)
    # Turntable (plaque tournante) with its track across.
    kit.steel.cylinder((e, n), tt["radius"] - 1.0, floor + 0.2, Q + 0.02, 40)
    kit.steel.cylinder((e, n), 2.5, Q + 0.02, Q + 0.6, 12)
    for off in (-2.2, 2.2):
        p = S(tt["u"] - tt["radius"] + 1.5, tt["v"] + off); q = S(tt["u"] + tt["radius"] - 1.5, tt["v"] + off)
        kit.steel.beam((*p, Q + 0.1), (*q, Q + 0.1), 0.18)
    # Slip from the turntable down into the fishing port basin.
    v0, v1 = tt["v"] + tt["radius"], fb["v0"] + 80
    a1, b1 = S(tt["u"] - 8, v0), S(tt["u"] + 8, v0)
    c1, d1 = S(tt["u"] + 8, v1), S(tt["u"] - 8, v1)
    kit.quay.quad((*a1, floor), (*b1, floor), (*c1, fb["floor"] - 1), (*d1, fb["floor"] - 1))
    for dom in g.DOMBUNKERS:
        dombunker(kit, *dom, with_boat=dom[0] == "T5")
    kit.labels.append(("Port de peche et plaque tournante", S(tt["u"], tt["v"]), Q))


# ---------------------------------------------------------------- base yard
def gable(kit, center, length, width, wall_h, heading, pitch=40.0, ruined=False, rng=None, ground=0.0):
    """House or shed with a pitched slate roof; ruins keep jagged walls and no roof."""
    ring = rect(center, length, width, heading)
    if ruined:
        rng = rng or random
        # Four walls 0.6 m thick with broken tops; some collapse to rubble height.
        for i in range(4):
            p, q = ring[i], ring[(i + 1) % 4]
            h = wall_h * rng.uniform(0.3, 1.0) if rng.random() > 0.2 else rng.uniform(0.4, 1.2)
            bearing = math.degrees(math.atan2(*(q - p)))
            kit.masonry.box((p + q) / 2, np.linalg.norm(q - p), 0.6, ground, ground + h, bearing)
        return
    kit.masonry.prism(ring, ground, ground + wall_h, top=False)
    ridge_h = width / 2 * math.tan(math.radians(pitch))
    f = np.array([math.sin(math.radians(heading)), math.cos(math.radians(heading))])
    c = np.asarray(center, float)
    r0, r1 = c - f * length / 2, c + f * length / 2
    z0, z1 = ground + wall_h, ground + wall_h + ridge_h
    A, B, C, D = [(*p, z0) for p in ring]
    R0, R1 = (*r0, z1), (*r1, z1)
    # ring order from meshkit.rect: back-left, back-right, front-right, front-left along the axis.
    kit.slate.quad(B, C, R1, R0)
    kit.slate.quad(D, A, R0, R1)
    kit.masonry.add([[A, B, R0]])
    kit.masonry.add([[C, D, R1]])
    # Eaves: close the roof underside so the slopes read from below.
    kit.slate.polygon(ring, z0, up=False)


def base_yard(kit, rng):
    # Workshops, stores and barracks (Baracken) behind the blocks.
    for i in range(3):
        c = S(-500, 440 + i * 50); gable(kit, c, 80, 18, 8, g.SITE_BEARING + 90, 30, ground=Q + 0.1)
    for i in range(4):
        c = S(-505, 70 + i * 32); gable(kit, c, 60, 12, 4, g.SITE_BEARING + 90, 35, ground=Q + 0.1)
    # Standard-gauge sidings serving the blocks and the workshops.
    rails(kit, -420, -419, -120, 690, True, Q + 0.12, 1)
    for v in (660, 300):
        rails(kit, -540, -300, v - 1, v + 1, True, Q + 0.12, 1)
    # Power station bunker between the traverser and the fishing port.
    sbox(kit.concrete, -200, -160, 310, 350, Q - 0.2, Q + 11, top=False)
    kit.roof.polygon(site_rect(-200, -160, 310, 350), Q + 11)
    # Quay furniture: bollards, portal cranes.
    for v in np.arange(-100, 690, 18):
        if 105 < v < 145 or 430 < v < 570:
            continue
        e, n = S(-1.2, v)
        kit.steel.cylinder((e, n), 0.35, Q, Q + 0.8, 8)
    for v in (330, 390):
        portal_crane(kit, -12, v)
    # K4 building site: foundations and two tower cranes.
    k4 = g.K4_SITE
    for i, v in enumerate(np.arange(k4["v0"] + 10, k4["v1"] - 5, 22)):
        h = rng.uniform(2.5, 9.0)
        sbox(kit.concrete, k4["u0"] + 10, k4["u1"] - 10, v, v + 3.2, Q - 0.2, Q + h)
    for u, v in ((k4["u0"] + 40, k4["v1"] - 10), (k4["u1"] - 30, k4["v0"] + 15)):
        tower_crane(kit, u, v, rng.uniform(0, 360))
    kit.labels.append(("Chantier K4", S((k4["u0"] + k4["u1"]) / 2, (k4["v0"] + k4["v1"]) / 2), Q))


def portal_crane(kit, u, v):
    for du in (-4.0, 4.0):
        for dv in (-4.0, 4.0):
            p = S(u + du, v + dv)
            kit.steel.beam((*p, Q), (*p, Q + 14), 0.6)
    for dv in (-4.0, 4.0):
        kit.steel.beam((*S(u - 4, v + dv), Q + 14), (*S(u + 4, v + dv), Q + 14), 0.7)
    sbox(kit.steel, u - 5, u + 5, v - 5, v + 5, Q + 14, Q + 18)
    kit.steel.beam((*S(u, v), Q + 18), (*S(u + 26, v), Q + 24), 0.8)
    kit.steel.beam((*S(u - 6, v), Q + 18), (*S(u - 6, v), Q + 23), 0.5)


def tower_crane(kit, u, v, jib_deg):
    e, n = S(u, v)
    h = 34.0
    for a in (0, 90, 180, 270):
        ang = math.radians(a + 45)
        p = (e + 1.1 * math.cos(ang), n + 1.1 * math.sin(ang))
        kit.steel.beam((*p, Q), (*p, Q + h), 0.25)
    for z in np.arange(Q + 2, Q + h, 3.0):
        for a in (0, 90, 180, 270):
            a0, a1 = math.radians(a + 45), math.radians(a + 135)
            kit.steel.beam((e + 1.1 * math.cos(a0), n + 1.1 * math.sin(a0), z),
                           (e + 1.1 * math.cos(a1), n + 1.1 * math.sin(a1), z + 3.0), 0.12)
    j = math.radians(jib_deg)
    kit.steel.beam((e - 12 * math.cos(j), n - 12 * math.sin(j), Q + h + 0.8), (e + 40 * math.cos(j), n + 40 * math.sin(j), Q + h + 0.8), 1.2)
    kit.concrete.box((e - 10 * math.cos(j), n - 10 * math.sin(j)), 4, 3, Q + h - 1.5, Q + h + 0.2, heading=jib_deg)


# ------------------------------------------------------------ Port-Louis
def star_fort(center, half_e, half_n, bastion, heading):
    c = np.asarray(center, float)
    th = math.radians(heading)
    rot = np.array([[math.cos(th), -math.sin(th)], [math.sin(th), math.cos(th)]])
    corners = [np.array(p) for p in ((-half_e, -half_n), (half_e, -half_n), (half_e, half_n), (-half_e, half_n))]
    pts = []
    for i, C in enumerate(corners):
        P, N = corners[i - 1], corners[(i + 1) % 4]
        ep, en = (P - C) / np.linalg.norm(P - C), (N - C) / np.linalg.norm(N - C)
        out_p, out_n = -en, -ep            # outward normals of the two curtains
        s = bastion
        p1 = C + ep * s
        f1 = p1 + out_p * s * 0.55
        sal = C - (ep + en) / np.linalg.norm(ep + en) * s * 1.6
        f2 = C + en * s + out_n * s * 0.55
        p2 = C + en * s
        pts += [p1, f1, sal, f2, p2]
    return np.array([c + rot @ p for p in pts])


def port_louis(kit, height_at):
    cd = g.CITADEL
    trace = star_fort(cd["center"], cd["half_e"], cd["half_n"], cd["bastion"], cd["heading"])
    poly = Polygon(trace).buffer(0)
    inner = poly.buffer(-13, join_style=2)
    base = 1.5
    top = 17.0
    ring = np.array(poly.exterior.coords)[:-1]
    hole = np.array(inner.exterior.coords)[:-1]
    # Battered scarp: the outer face leans back 1.5 m.
    scarp = np.array(poly.buffer(-1.5, join_style=2).exterior.coords)[:-1]
    kit.masonry.prism(ring, base, top - 3.0, top=False, holes=[])
    kit.masonry.polygon(ring, top - 3.0, True, holes=[np.array(poly.buffer(-1.5, join_style=2).exterior.coords)[:-1]])
    kit.masonry.prism(scarp, top - 3.0, top, holes=[hole])
    parapet_in = np.array(poly.buffer(-3.5, join_style=2).exterior.coords)[:-1]
    kit.masonry.prism(scarp, top, top + 1.4, holes=[parapet_in])
    # Parade ground and buildings inside.
    kit.quay.polygon(hole, 8.0)
    kit.masonry.walls(hole, 8.0, top, outward=False)
    c = np.asarray(cd["center"])
    th = cd["heading"] + 90
    for off, L, W in (((-45, 15), 70, 12), ((40, 20), 60, 12), ((0, -35), 90, 11)):
        o = np.array(off, float)
        rot = math.radians(-cd["heading"])
        pos = c + np.array([o[0] * math.cos(rot) - o[1] * math.sin(rot), o[0] * math.sin(rot) + o[1] * math.cos(rot)])
        gable(kit, pos, L, W, 8, th if off[1] != -35 else th, 42, ground=8.0)
    gable(kit, c + np.array([5, 40]), 22, 10, 9, cd["heading"], 50, ground=8.0)      # chapel
    # Ravelin on the landward (east) side.
    rav = np.array([c + [cd["half_e"] + 25, -30], c + [cd["half_e"] + 70, 0], c + [cd["half_e"] + 25, 30]])
    kit.masonry.prism(rav, base, 12)
    kit.labels.append(("Citadelle de Port-Louis", tuple(c), top))


# ------------------------------------------------------------- Kernevel, Saint-Michel
def kernevel(kit, height_at):
    for i, (e, n) in enumerate(g.KERNEVEL["villas"]):
        h, _ = height_at(np.array([e]), np.array([n]))
        gable(kit, (e, n), 18, 12, 9, 30 + 20 * i, 48, ground=float(h[0]) - 0.3)
    p = g.KERNEVEL["point"]
    kit.masonry.ring_wall(p, 32, 28, 3.0, 8.0, 18)
    kit.labels.append(("Kernevel (PC de Doenitz)", g.KERNEVEL["villas"][0], 12))


def saint_michel(kit, rng, height_at):
    c = g.ILE_SAINT_MICHEL["center"]
    h, _ = height_at(np.array([c[0]]), np.array([c[1]]))
    gable(kit, (c[0] + 10, c[1] + 5), 30, 10, 7, 80, 45, ground=float(h[0]))
    gable(kit, (c[0] - 20, c[1] - 10), 14, 7, 9, 170, 50, ground=float(h[0]))
    kit.labels.append(("Ile Saint-Michel", c, 10))


# ---------------------------------------------------------------- towns, trees
def towns(kit, rng, height_at, field):
    deck = Polygon(g.BASE_DECK).buffer(25)
    citadel = Point(g.CITADEL["center"]).buffer(240)
    exclude = unary_union([deck, citadel])
    count = 0
    for name, poly, bearing, ruined_frac, scale, density in g.TOWNS:
        P = Polygon(poly)
        minx, miny, maxx, maxy = P.bounds
        th = math.radians(bearing)
        f = np.array([math.sin(th), math.cos(th)])
        r = np.array([f[1], -f[0]])
        c0 = np.array([(minx + maxx) / 2, (miny + maxy) / 2])
        span = max(maxx - minx, maxy - miny)
        block_l, block_w, street = 72.0, 48.0, 10.0
        cand = []
        for i in np.arange(-span, span, block_l + street):
            for j in np.arange(-span, span, block_w + street):
                corner = c0 + f * i + r * j
                # Houses along the four sides of the block.
                for side in range(4):
                    if side in (0, 2):
                        length, along, normal = block_l, f, r
                        base_pt = corner + (r * 0 if side == 0 else r * block_w)
                        facing = 1 if side == 0 else -1
                    else:
                        length, along, normal = block_w, r, f
                        base_pt = corner + (f * 0 if side == 3 else f * block_l)
                        facing = 1 if side == 3 else -1
                    x = 1.0
                    while x < length - 6:
                        w = rng.uniform(6.5, 11.0) * scale
                        dpt = rng.uniform(8.0, 11.0) * scale
                        cpos = base_pt + along * (x + w / 2) + normal * facing * (dpt / 2)
                        hdg = math.degrees(math.atan2(along[0], along[1]))
                        cand.append((cpos, w, dpt, hdg))
                        x += w
        pts = np.array([cc[0] for cc in cand])
        if not len(pts):
            continue
        inside = polygon_mask(poly, pts[:, 0], pts[:, 1])
        h, s = height_at(pts[:, 0], pts[:, 1])
        for (cpos, w, dpt, hdg), ok, hh, ss in zip(cand, inside, h, s):
            if not ok or ss < 12 or hh < 1.0 or exclude.contains(Point(cpos)):
                continue
            if rng.random() > density:     # gardens, yards and gaps
                continue
            ruined = rng.random() < ruined_frac
            storeys = rng.choice([2, 2, 3, 3, 4]) if name in ("Lorient", "Port-Louis") else rng.choice([1, 2, 2, 3])
            # Ridge parallel to the street, as in Breton towns.
            gable(kit, cpos, w, dpt, 3.0 * storeys + 0.6, hdg, rng.uniform(38, 50), ruined, rng, ground=float(hh) - 0.3)
            count += 1
    return count


def trees(kit, rng, height_at, count=7000):
    ex = g.EXTENT
    deck = Polygon(g.BASE_DECK).buffer(30)
    towns_u = unary_union([Polygon(t[1]) for t in g.TOWNS]).buffer(-10)
    e = rng_array(rng, count * 4, ex["e0"], ex["e1"])
    n = rng_array(rng, count * 4, ex["n0"], ex["n1"])
    wood = g.fbm(e, n, 260, 3, seed=21)
    h, s = height_at(e, n)
    hedgerow = (np.abs(((e + 37 * np.sin(n / 190)) % 110) - 55) > 50) | (np.abs(((n + 29 * np.sin(e / 230)) % 80) - 40) > 35)
    keep = (s > 15) & (h > 1.5) & ((wood > 0.62) | (hedgerow & (wood > 0.45)))
    sm = g.ILE_SAINT_MICHEL["center"]
    keep |= (np.hypot(e - sm[0], n - sm[1]) < 70) & (s > 6)
    placed = 0
    for x, y, z in zip(e[keep], n[keep], h[keep]):
        if placed >= count:
            break
        pt = Point(x, y)
        if deck.contains(pt) or towns_u.contains(pt):
            continue
        tall = rng.uniform(7, 16)
        rad = tall * rng.uniform(0.3, 0.45)
        kit.trees.cone((x, y), rad, z + tall * 0.25, z + tall, 7)
        kit.trees.cone((x, y), rad * 0.8, z, z + tall * 0.55, 6)
        placed += 1
    return placed


def rng_array(rng, k, a, b):
    return np.array([rng.uniform(a, b) for _ in range(k)])


def buoys(kit):
    for (e, n), colour in g.BUOYS:
        m = kit.red if colour == "red" else kit.green
        m.cylinder((e, n), 1.1, -2.0, 1.2, 10)
        m.cylinder((e, n), 0.25, 1.2, 4.5, 6)
        if colour == "red":
            m.cylinder((e, n), 0.7, 4.5, 5.6, 8)       # can topmark
        else:
            m.cone((e, n), 0.8, 4.5, 5.8, 8)            # cone topmark


def quays(kit, height_at):
    """Paved platform of the base and quay walls wherever it drops to water or into a pit."""
    deck = Polygon(g.BASE_DECK)
    cuts = [Polygon(c) for c in g.water_cuts()] + [Polygon(p) for p, _ in g.dry_cuts()]
    deck = deck.difference(unary_union(cuts)).buffer(0)
    parts = list(deck.geoms) if hasattr(deck, "geoms") else [deck]
    top = Q + 0.12
    for part in parts:
        rings = [np.array(part.exterior.coords)[:-1]] + [np.array(r.coords)[:-1] for r in part.interiors]
        kit.quay.polygon(rings[0], top, True, holes=rings[1:])
        for k, ring in enumerate(rings):
            ring = ring if (k == 0) == (signed(ring) > 0) else ring[::-1]    # walk with the paving on the left
            for a, b in zip(ring, np.roll(ring, -1, axis=0)):
                d = b - a
                L = np.linalg.norm(d)
                if L < 0.05:
                    continue
                out = np.array([d[1], -d[0]]) / L
                probe = (a + b) / 2 + out * 2.0
                h, _ = height_at(np.array([probe[0]]), np.array([probe[1]]))
                if h[0] > Q - 0.4:
                    continue
                z0 = min(g.PEN_FLOOR - 0.5, float(h[0]) - 0.5)
                kit.concrete.quad((*a, z0), (*b, z0), (*b, top), (*a, top))
                # Granite coping stone along the edge.
                kit.quay.quad((*a, top), (*b, top), (*(b - out * 0.8), top + 0.25), (*(a - out * 0.8), top + 0.25))


def signed(ring):
    r = np.asarray(ring)
    return 0.5 * np.sum(r[:, 0] * np.roll(r[:, 1], -1) - np.roll(r[:, 0], -1) * r[:, 1])


def build(height_at, field, seed=1943):
    rng = random.Random(seed)
    kit = Kit()
    quays(kit, height_at)
    keroman3(kit)
    dry_block(kit, g.K2, True, "Keroman II", boats={1, 4, 6})
    dry_block(kit, g.K1, False, "Keroman I", boats={0, 3})
    slipway_and_traverser(kit)
    fishing_port(kit)
    base_yard(kit, rng)
    port_louis(kit, height_at)
    kernevel(kit, height_at)
    saint_michel(kit, rng, height_at)
    houses = towns(kit, rng, height_at, field)
    placed = trees(kit, rng, height_at)
    buoys(kit)
    return kit, dict(houses=houses, trees=placed)
