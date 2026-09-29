"""Offline check of the Lorient map against the game's navigation safety rules.

    python3 Tests/lorient-navigation.py          # needs numpy, trimesh, rtree

1. The per-map constants compiled into Voyage.cpp (FVoyageMission::ForMap) match
   Import/Lorient/layout.json.
2. AVoyagePawn::SafeAt, as it runs in harbour mode, is replayed with ray casts on the generated
   collision meshes (terrain, concrete, roofs, quays, steel, masonry; the moored VIICs as boxes):
   the start in K3 pen 4 is safe, the route out of the pen, down the channel past Port-Louis and to
   the diving area stays safe, the dive at the third objective is possible, and the land points the
   smoke test expects to be blocked are blocked.
Unreal is not needed; this does not replace a run in the engine (physics, waves, buoyancy).
"""
from __future__ import annotations

import json
import math
import re
import sys
from pathlib import Path

import numpy as np
import trimesh

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "Import" / "Lorient"
CPP = ROOT / "Source" / "NordatlantikDemo" / "Voyage.cpp"
COLLIDES = ["LorientTerrain", "KeromanConcrete", "KeromanRoof", "KeromanQuay", "KeromanSteel", "LorientMasonry"]
failures = []


def check(ok, what):
    print(("ok   " if ok else "FAIL ") + what)
    if not ok:
        failures.append(what)


# ----------------------------------------------------------- constants
layout = json.loads((SRC / "layout.json").read_text())
cpp = CPP.read_text()
body = cpp[cpp.index("FVoyageMission FVoyageMission::ForMap"):cpp.index("FString AVoyagePawn::Slot")]


def vec(name):
    m = re.search(re.escape(name) + r"=FVector\(([^)]*)\)", body)
    return [float(x.strip().rstrip("f")) for x in m.group(1).split(",")]


def close(a, b, tol=1.0):
    return all(abs(x - y) <= tol for x, y in zip(a, b))


check(close(vec("M.Start"), layout["player"]["location"]), "C++ start = layout player location")
check(abs(float(re.search(r"M\.StartYaw=([-\d.]+)", body).group(1)) - layout["player"]["yaw"]) < 0.01, "C++ start yaw")
for i, gl in enumerate(layout["goals"]):
    check(close(vec(f"M.Goals[{i}]"), gl["location"]), f"C++ goal {i + 1} = layout ({gl['name']})")
c = re.search(r"M\.Center=FVector2D\(([^)]*)\);M\.Radius=(\d+)", body)
check(close([float(x) for x in c.group(1).split(",")], layout["play_area"]["center"][:2]) and
      int(c.group(2)) == layout["play_area"]["radius_cm"], "C++ play area = layout")
test_start, test_blocked = vec("M.TestStart"), vec("M.TestBlocked")

# ----------------------------------------------------------- meshes
def load_obj(path):
    verts, faces = [], []
    with path.open() as f:
        for line in f:
            if line.startswith("v "):
                verts.append(line.split()[1:4])
            elif line.startswith("f "):
                faces.append([int(p.split("/")[0]) - 1 for p in line.split()[1:4]])
    v = np.array(verts, float)
    # OBJ (x, y, z) = (-north, up, -east) metres -> Unreal cm (X east, Y south, Z up).
    ue = np.column_stack([-v[:, 2], v[:, 0], v[:, 1]]) * 100
    return ue, np.array(faces)


parts = []
for name in COLLIDES:
    parts.append(trimesh.Trimesh(*load_obj(SRC / f"{name}.obj"), process=False))
for p in layout["viic_props"]:
    box = trimesh.creation.box(extents=(6700, 620, 800))
    yaw = math.radians(p["yaw"])
    x, y, z = p["location"]
    box.apply_transform(trimesh.transformations.rotation_matrix(yaw, (0, 0, 1)))
    box.apply_translation((x, y, z - 302 + 400))           # keel at location z - 3.02 m
    parts.append(box)
scene = trimesh.util.concatenate(parts)
ray = trimesh.ray.ray_triangle.RayMeshIntersector(scene)
print(f"collision scene: {len(scene.faces)} triangles")


def first_hit(a, b):
    """Closest hit on segments a->b (arrays), or None per segment."""
    a, b = np.atleast_2d(a).astype(float), np.atleast_2d(b).astype(float)
    d = b - a
    length = np.linalg.norm(d, axis=1)
    locs, idx, _ = ray.intersects_location(a, d / length[:, None], multiple_hits=False)
    out = [None] * len(a)
    for loc, i in zip(locs, idx):
        if np.linalg.norm(loc - a[i]) <= length[i]:
            out[i] = loc
    return out


def safe_at(P, yaw_deg):
    """AVoyagePawn::SafeAt in harbour mode."""
    P = np.asarray(P, float)
    center = np.array(layout["play_area"]["center"][:2], float)
    if np.linalg.norm(P[:2] - center) > layout["play_area"]["radius_cm"] or P[2] < -22500:
        return False, "boundary"
    f = np.array([math.cos(math.radians(yaw_deg)), math.sin(math.radians(yaw_deg)), 0])
    r = np.array([-f[1], f[0], 0])
    offsets = [np.zeros(3), f * 3500, -f * 3500, r * 450, -r * 450]
    side_a = [P + (0, 0, 250)] * 4
    side_b = [P + o + (0, 0, 250) for o in offsets[1:]]
    for hit, o in zip(first_hit(side_a, side_b), offsets[1:]):
        if hit is not None:
            return False, "side %s" % np.round(hit / 100, 1)
    tops = [(P + o) * (1, 1, 0) + (0, 0, P[2] + 900) for o in offsets]
    bottoms = [(P + o) * (1, 1, 0) + (0, 0, -25000) for o in offsets]
    for hit in first_hit(tops, bottoms):
        if hit is not None and hit[2] > P[2] - 350:
            return False, "ground %.1f m" % (hit[2] / 100)
    return True, ""


# ----------------------------------------------------------- scenarios
start = np.array(layout["player"]["location"], float)
yaw0 = layout["player"]["yaw"]
ok, why = safe_at(start, yaw0)
check(ok, "start in K3 pen 4 is navigable " + why)

def enu(e, n):
    return np.array([e * 100, -n * 100, -190.0])

goals = [np.array(g["location"], float) for g in layout["goals"]]
out_dir = np.array([math.cos(math.radians(yaw0)), math.sin(math.radians(yaw0)), 0])
route = [start, start + out_dir * 12000, goals[0] * (1, 1, 0) + (0, 0, -190), enu(260, -500), enu(220, -1300),
         goals[1] * (1, 1, 0) + (0, 0, -190), enu(-60, -3000), enu(-350, -4200), goals[2] * (1, 1, 0) + (0, 0, -190)]
bad = []
samples = 0
for a, b in zip(route[:-1], route[1:]):
    d = b - a
    L = np.linalg.norm(d[:2])
    yaw = math.degrees(math.atan2(d[1], d[0]))
    for t in np.arange(0, L, 600):
        P = a + d * (t / L)
        samples += 1
        ok, why = safe_at(P, yaw)
        if not ok:
            bad.append((np.round(P / 100, 1).tolist(), why))
check(not bad, f"route pen -> goal 1 -> Port-Louis -> diving area safe at {samples} points" + (f": {bad[:6]}" if bad else ""))
dive = goals[2] + (0, 0, -190)
check(safe_at(dive, 0)[0], "dive to 20 m at the third objective " + safe_at(dive, 0)[1])
ts = np.array(test_start)
check(safe_at(ts, yaw0)[0], "smoke-test start in open water")
check(safe_at(ts + (0, 0, -1500), yaw0)[0], "smoke-test dive to 15 m")
check(not safe_at(np.array(test_blocked), 0)[0], "citadel of Port-Louis is blocked")
# The walls of the pen stop a boat drifting sideways into them.
side = start + np.array([-out_dir[1], out_dir[0], 0]) * 700
check(not safe_at(side, yaw0)[0], "pen walls block a 7 m sideways drift")
print("\n%d failure(s)" % len(failures))
sys.exit(1 if failures else 0)
