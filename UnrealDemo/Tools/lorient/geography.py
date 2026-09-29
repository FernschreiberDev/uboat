"""Geography of the Lorient roadstead and layout of the Keroman base, late 1943.

Frame: local ENU in metres, origin on the quay in front of Keroman III (about 47.7275 N,
3.3685 W), e east, n north, z above mean sea level.

Sources and accuracy (see Docs/LORIENT.md):
- Block dimensions come from published measurements: K1 119.5 x 85 x 18.5 m, roof 3.5 m, five pens
  plus the covered bay of the slipway; K2 128 x 138 x 18.5 m, seven pens plus K6A; K3 138 x 170 x
  20 m, seven wet pens, roof 6.4 to 7.4 m with its bomb-catching grid (Fangrost); Dombunker 81 x 16 x
  25 m pointed barrel vaults (T5, T6); slipway channel 10.65 m below sea level.
- The coastline, depths and positions of Port-Louis, Kernevel, Ile Saint-Michel and Gavres are
  drawn from the general layout of the roadstead, not from a survey (no map service was reachable
  when this was built). Recalibrating on the OpenStreetMap coastline, IGN elevations and SHOM
  soundings is the next step towards an exact roadstead.
- The arrangement of K1/K2 on either side of the transfer carriage, the slipway between K2 and K3
  and the Dombunkers around the fishing port's turntable follows the functional descriptions; the
  exact spacing between blocks is an estimate.
"""
from __future__ import annotations

import math

import numpy as np

# ---------------------------------------------------------------- site frame
# The base is laid out on a grid turned 10 degrees from north: u points out of the K3 pens towards
# the roadstead (bearing 100 degrees), v along the quay (bearing 10 degrees).
SITE_BEARING = 10.0
_U = np.array([math.sin(math.radians(SITE_BEARING + 90)), math.cos(math.radians(SITE_BEARING + 90))])
_V = np.array([math.sin(math.radians(SITE_BEARING)), math.cos(math.radians(SITE_BEARING))])


def S(u, v):
    """Site (u, v) to ENU (e, n)."""
    return (_U * u + _V * v).tolist()


def site_ring(points):
    return np.array([S(u, v) for u, v in points])


def site_rect(u0, u1, v0, v1):
    return site_ring([(u0, v0), (u1, v0), (u1, v1), (u0, v1)])


# ------------------------------------------------------------------- levels
QUAY = 4.5            # base platform above mean sea level (tidal range about 5 m)
PEN_FLOOR = -9.5      # dredged floor of the K3 pens and base approaches
SLIP_BOTTOM = -10.65  # foot of the slipway, below sea level

# ------------------------------------------------------------------ blocks
# Keroman III: pens open towards +u, into the roadstead.
K3 = dict(u0=-138.0, u1=0.0, v0=-85.0, v1=85.0, height=20.0, roof=7.4,
          pens=7, pen_width=19.5, wall=3.6, outer_wall=5.95, rear=8.0, quay=3.25)
# Keroman II opens towards -u onto the transfer carriage; Keroman I faces it from the west.
K2 = dict(u0=-128.0, u1=0.0, v0=150.0, v1=288.0, height=18.5, roof=3.5, bays=8, wall=3.0, outer_wall=4.0, rear=4.0)
K1 = dict(u0=-293.0, u1=-208.0, v0=170.0, v1=289.5, height=18.5, roof=3.5, bays=6, wall=3.0, outer_wall=4.0, rear=4.0)
TRAVERSER = dict(u0=-205.0, u1=-131.0, v0=105.0, v1=295.0, depth=1.5, carriage_v=219.0)
SLIPWAY = dict(v=125.0, width=16.0, u_top=-131.0, u_foot=70.0, channel=(113.0, 137.0))
FISHING_BASIN = dict(u0=-340.0, u1=-40.0, v0=400.0, v1=600.0, entrance=(440.0, 560.0), floor=-6.0)
TURNTABLE = dict(u=-320.0, v=340.0, radius=36.0)
DOMBUNKERS = [  # (name, start u, start v, bearing of the axis in the site frame (0 = +u), length)
    ("T5", -356.0, 340.0, 180.0, 81.0),
    ("T6", -320.0, 304.0, 270.0, 81.0),
]
DOM = dict(span=16.0, height=25.0, shell=3.0)
K4_SITE = dict(u0=-360.0, u1=-200.0, v0=-120.0, v1=20.0)
BASE_DECK = site_ring([(0, -110), (0, 700), (-560, 700), (-560, -160), (-420, -175), (-200, -170), (-60, -150)])


def water_cuts():
    """Water inside the west bank outline: K3 pens, slipway channel, fishing port, the Ter."""
    k = K3
    sl = SLIPWAY
    fb = FISHING_BASIN
    return [
        site_rect(k["u0"] + k["rear"], 5, k["v0"] + 1, k["v1"] - 1),
        site_rect(-87, 5, sl["channel"][0], sl["channel"][1]),
        site_rect(fb["u0"], fb["u1"], fb["v0"], fb["v1"]),
        site_rect(fb["u1"] - 5, 5, fb["entrance"][0], fb["entrance"][1]),
    ]


def dry_cuts():
    """Dry pits and trenches in the base platform: (polygon, floor height)."""
    t, s, tt = TRAVERSER, SLIPWAY, TURNTABLE
    a = np.linspace(0, 2 * math.pi, 48, endpoint=False)
    c = np.array(S(tt["u"], tt["v"]))
    return [
        (site_rect(t["u0"], t["u1"], t["v0"], t["v1"]), QUAY - t["depth"] - 0.1),
        (site_rect(s["u_top"] - 0.5, -92, s["channel"][0], s["channel"][1]), 0.3),
        (np.column_stack([c[0] + tt["radius"] * np.cos(a), c[1] + tt["radius"] * np.sin(a)]), QUAY - 1.6),
        (site_rect(tt["u"] - 12, tt["u"] + 12, tt["v"] + tt["radius"] - 2, FISHING_BASIN["v0"]), 0.3),
    ]


def k3_pens():
    """(v0, v1) of each K3 pen, south to north."""
    k = K3
    v = k["v0"] + k["outer_wall"]
    out = []
    for i in range(k["pens"]):
        out.append((v, v + k["pen_width"]))
        v += k["pen_width"] + (k["wall"] if i < k["pens"] - 1 else 0)
    assert abs(v + k["outer_wall"] - k["v1"]) < 0.05, v
    return out


def bays(block):
    b = block
    inner = (b["v1"] - b["v0"] - 2 * b["outer_wall"] - (b["bays"] - 1) * b["wall"]) / b["bays"]
    v = b["v0"] + b["outer_wall"]
    out = []
    for _ in range(b["bays"]):
        out.append((v, v + inner))
        v += inner + b["wall"]
    return out


# The player's VIIC: pen 4 of K3 (the middle one), bow towards the entrance.
PLAYER_PEN = 3
PLAYER_U = -40.0


def player_start():
    v0, v1 = k3_pens()[PLAYER_PEN]
    e, n = S(PLAYER_U, (v0 + v1) / 2)
    return e, n, SITE_BEARING + 90   # bearing of the bow


# --------------------------------------------------------------- geography
# Coastline polygons (ENU metres), clockwise or not: orientation is normalised by the users.
# West bank: Lorient, the Keroman peninsula, the Ter, Kernevel and Larmor.
def _west_bank():
    # Basins, pens and the slipway channel are cut out of this outline separately (water_cuts()).
    base_east = [S(0, -110), S(-60, -150), S(-200, -170), S(-420, -175), S(-600, -160)]
    return np.array([
        (-4200, 2700), (330, 2700), (300, 2100), (250, 1500), (180, 1000), tuple(S(0, 900)),
        *map(tuple, base_east),
        (-610, 150), (-590, 700), (-640, 1150), (-720, 1300), (-820, 1180), (-800, 700),
        (-780, 150), (-760, -300), (-640, -620), (-470, -820), (-360, -960), (-390, -1120), (-560, -1260),
        (-760, -1520), (-950, -1880), (-1250, -2250), (-1650, -2480), (-2200, -2650), (-2900, -2780),
        (-3600, -2900), (-4200, -3000),
    ])


# East bank: Pen-Mane, Sainte-Catherine, Locmiquelic, Port-Louis and its citadel, Gavres.
def _east_bank():
    return np.array([
        (1650, 2700), (1500, 2000), (1350, 1500), (1180, 1150), (1250, 980), (1500, 820), (1680, 300),
        (1620, -250), (1480, -700), (1260, -1100), (1020, -1500), (820, -1800), (560, -1960),
        (330, -2050), (270, -2180), (330, -2300), (560, -2360), (820, -2340), (1100, -2420),
        (1400, -2480),   # mouth of the Petite Mer de Gavres
        (1500, -2700), (1320, -3150), (1150, -3620), (980, -4050), (1080, -4200), (1300, -4180),
        (1850, -4520), (2600, -5050), (3400, -5500), (4200, -5900), (4200, 2700),
    ])


PETITE_MER = np.array([(1400, -2480), (2100, -2330), (2900, -2450), (3600, -2950), (3000, -3500),
                       (2200, -3350), (1700, -3150), (1500, -2700)])
ILE_SAINT_MICHEL = dict(center=(1050.0, 280.0), rx=110.0, ry=80.0)
CITADEL = dict(center=(430.0, -2175.0), half_e=120.0, half_n=78.0, bastion=34.0, heading=-8.0)
KERNEVEL = dict(point=(-380.0, -1000.0), villas=[(-455, -935), (-490, -885), (-430, -1060)])

# Navigation channel: dredged axis from the Keroman quay to the open sea (ENU, depth in m).
CHANNEL = [((150, 0), 9.5), ((260, -500), 10.0), ((220, -1300), 11.0), ((140, -2150), 12.5),
           ((-60, -3000), 14.0), ((-350, -4200), 18.0), ((-650, -5600), 25.0), ((-900, -7000), 30.0)]
CHANNEL_HALF_WIDTH = 140.0

# Map extent of the terrain mesh and the fine grid around the base.
EXTENT = dict(e0=-4000.0, e1=4000.0, n0=-6600.0, n1=2600.0, step=25.0)
FINE = dict(e0=-850.0, e1=450.0, n0=-450.0, n1=1000.0, step=5.0)
GROIX = dict(center=(-7400.0, -10300.0), length=8000.0, width=3000.0, bearing=-60.0, cliff=40.0)

# Towns and villages: (name, polygon, street bearing, ruined fraction, house scale, density).
# Lorient was largely destroyed by the raids of January and February 1943.
TOWNS = [
    ("Lorient", [(-560, 950), (160, 950), (300, 2100), (250, 2600), (-600, 2600), (-640, 1250)], 25.0, 0.8, 1.0, 0.75),
    ("Keroman", [(-560, 700), (-200, 800), (-200, 950), (-560, 950)], 10.0, 0.75, 0.9, 0.7),
    ("Merville", [(-3000, 900), (-900, 900), (-900, 2600), (-3000, 2600)], 5.0, 0.35, 0.9, 0.12),
    ("Larmor", [(-1900, -2150), (-1100, -1900), (-900, -1500), (-1500, -1400), (-2200, -1900)], 30.0, 0.05, 0.85, 0.45),
    ("Port-Louis", [(620, -1880), (1000, -1620), (1250, -1950), (1150, -2320), (660, -2300)], 12.0, 0.1, 1.0, 0.85),
    ("Locmiquelic", [(1520, -620), (1800, -500), (1850, 150), (1600, 100)], 0.0, 0.25, 0.85, 0.5),
    ("Sainte-Catherine", [(1400, 900), (1800, 900), (1750, 1500), (1450, 1400)], 20.0, 0.1, 0.85, 0.4),
    ("Gavres", [(1300, -3350), (1550, -3350), (1700, -3900), (1400, -3950)], 40.0, 0.05, 0.8, 0.5),
]

# Channel buoys (e, n, colour): red to port entering, green to starboard.
BUOYS = [((-80, -3000), "red"), ((260, -2900), "green"), ((-10, -2150), "red"), ((300, -1500), "green"),
         ((60, -1300), "red"), ((-400, -4200), "red"), ((-150, -4150), "green")]


def channel_depth(e, n):
    """Depth of the dredged channel at points (arrays), 0 outside."""
    pts = np.stack([e, n], axis=-1)
    best = np.zeros(np.shape(e))
    for (a, da), (b, db) in zip(CHANNEL[:-1], CHANNEL[1:]):
        a, b = np.array(a, float), np.array(b, float)
        ab = b - a
        t = np.clip(((pts - a) @ ab) / (ab @ ab), 0, 1)
        d = np.linalg.norm(pts - (a + t[..., None] * ab), axis=-1)
        depth = da + (db - da) * t
        w = np.clip((CHANNEL_HALF_WIDTH * 1.4 - d) / (CHANNEL_HALF_WIDTH * 0.4), 0, 1)
        best = np.maximum(best, depth * smooth(w))
    return best


def smooth(x):
    x = np.clip(x, 0, 1)
    return x * x * (3 - 2 * x)


def value_noise(e, n, scale, seed=0):
    """Smooth value noise in [0, 1] for arrays of coordinates."""
    x, y = np.asarray(e, float) / scale + seed * 17.13, np.asarray(n, float) / scale + seed * 7.71
    xi, yi = np.floor(x), np.floor(y)
    xf, yf = x - xi, y - yi

    def h(a, b):
        k = (a.astype(np.int64) * 374761393 + b.astype(np.int64) * 668265263 + seed * 1274126177) & 0xFFFFFFFF
        k = ((k ^ (k >> 13)) * 1274126177) & 0xFFFFFFFF
        return (k ^ (k >> 16)) / 4294967295.0

    u, v = xf * xf * (3 - 2 * xf), yf * yf * (3 - 2 * yf)
    return (h(xi, yi) * (1 - u) + h(xi + 1, yi) * u) * (1 - v) + (h(xi, yi + 1) * (1 - u) + h(xi + 1, yi + 1) * u) * v


def fbm(e, n, scale, octaves=4, seed=0):
    total, amp, norm = 0.0, 1.0, 0.0
    for o in range(octaves):
        total = total + amp * value_noise(e, n, scale / (2 ** o), seed + o)
        norm += amp
        amp *= 0.5
    return total / norm
