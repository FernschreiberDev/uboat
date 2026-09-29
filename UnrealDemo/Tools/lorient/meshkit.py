"""Small mesh toolkit for the Lorient generator.

Geometry is built in a local ENU frame, in metres: e towards the east, n towards the north, z up
from mean sea level. Triangles are counter-clockwise seen from outside.

OBJ files follow the convention of the other imports of this project (VIIC.obj, Bismarck.obj):
right-handed, Y up, imported by Unreal with roll 90 / yaw 90 at 100 cm per unit. That import sends
OBJ -z to Unreal +X and OBJ +x to Unreal +Y. Writing (x, y, z) = (-n, z, -e) therefore lands east on
Unreal +X, south on +Y (north on -Y, as in AtlanticVoyage) and up on +Z, without mirroring: the
change of axes is a proper rotation, so windings are kept.
"""
from __future__ import annotations

import math
from pathlib import Path

import mapbox_earcut as earcut
import numpy as np


class Mesh:
    """Triangle soup with flat or supplied normals and metre-based box-projected UVs."""

    def __init__(self, name: str, tile: float = 4.0):
        self.name = name
        self.tile = tile            # texture repeat, metres
        self.tris: list[np.ndarray] = []      # (k, 3, 3)
        self.uvs: list[np.ndarray | None] = []
        self.normals: list[np.ndarray | None] = []

    # ----------------------------------------------------------------- primitives
    def add(self, tris, uvs=None, normals=None):
        tris = np.asarray(tris, dtype=np.float64).reshape(-1, 3, 3)
        if len(tris) == 0:
            return
        self.tris.append(tris)
        self.uvs.append(None if uvs is None else np.asarray(uvs, dtype=np.float64).reshape(-1, 3, 2))
        self.normals.append(None if normals is None else np.asarray(normals, dtype=np.float64).reshape(-1, 3, 3))

    def quad(self, a, b, c, d):
        """Quad a-b-c-d, counter-clockwise from outside."""
        self.add([[a, b, c], [a, c, d]])

    def polygon(self, ring, z, up=True, holes=()):
        """Flat polygon (with holes) at height z, facing up or down."""
        rings = [np.asarray(ring, dtype=np.float64)[:, :2]] + [np.asarray(h, dtype=np.float64)[:, :2] for h in holes]
        rings = [r[:-1] if len(r) > 1 and np.allclose(r[0], r[-1]) else r for r in rings]
        rings = [orient(r, ccw=(i == 0)) for i, r in enumerate(rings)]
        verts = np.concatenate(rings)
        ends = np.cumsum([len(r) for r in rings]).astype(np.uint32)
        idx = earcut.triangulate_float64(verts, ends).reshape(-1, 3)
        if len(idx) == 0:
            return
        pts = np.column_stack([verts, np.full(len(verts), float(z))])
        tri = pts[idx]
        # Earcut returns clockwise triangles for a counter-clockwise outer ring in a y-up plane;
        # enforce the requested facing explicitly.
        area = cross2(tri[:, 1, :2] - tri[:, 0, :2], tri[:, 2, :2] - tri[:, 0, :2])
        flip = (area < 0) if up else (area > 0)
        tri[flip] = tri[flip][:, ::-1]
        self.add(tri)

    def walls(self, ring, z0, z1, outward=True):
        """Vertical ribbon along a closed ring; outward faces the outside of a CCW ring."""
        r = orient(np.asarray(ring, dtype=np.float64)[:, :2], ccw=True)
        if not outward:
            r = r[::-1]
        z0 = np.broadcast_to(np.asarray(z0, dtype=np.float64), (len(r),))
        z1 = np.broadcast_to(np.asarray(z1, dtype=np.float64), (len(r),))
        for i in range(len(r)):
            j = (i + 1) % len(r)
            a, b = r[i], r[j]
            self.quad((a[0], a[1], z0[i]), (b[0], b[1], z0[j]), (b[0], b[1], z1[j]), (a[0], a[1], z1[i]))

    def prism(self, ring, z0, z1, top=True, bottom=False, holes=()):
        self.walls(ring, z0, z1)
        for h in holes:
            self.walls(h, z0, z1, outward=False)
        if top:
            self.polygon(ring, z1, True, holes)
        if bottom:
            self.polygon(ring, z0, False, holes)

    def box(self, center, length, width, z0, z1, heading=0.0, top=True, bottom=False):
        """Box of given length along the bearing heading (degrees from north), width across."""
        self.prism(rect(center, length, width, heading), z0, z1, top=top, bottom=bottom)

    def cylinder(self, center, radius, z0, z1, segments=16, top=True):
        a = np.linspace(0, 2 * math.pi, segments, endpoint=False)
        ring = np.column_stack([center[0] + radius * np.cos(a), center[1] + radius * np.sin(a)])
        self.prism(ring, z0, z1, top=top)

    def cone(self, center, radius, z0, z1, segments=8):
        a = np.linspace(0, 2 * math.pi, segments + 1)
        apex = (center[0], center[1], z1)
        for i in range(segments):
            p = (center[0] + radius * math.cos(a[i]), center[1] + radius * math.sin(a[i]), z0)
            q = (center[0] + radius * math.cos(a[i + 1]), center[1] + radius * math.sin(a[i + 1]), z0)
            self.add([[p, q, apex]])

    def ring_wall(self, center, r_out, r_in, z0, z1, segments=20):
        a = np.linspace(0, 2 * math.pi, segments, endpoint=False)
        outer = np.column_stack([center[0] + r_out * np.cos(a), center[1] + r_out * np.sin(a)])
        inner = np.column_stack([center[0] + r_in * np.cos(a), center[1] + r_in * np.sin(a)])
        self.prism(outer, z0, z1, holes=[inner])

    def beam(self, p, q, size, z0=None, z1=None):
        """Horizontal square beam between two 3D points (for rails, lattice members)."""
        p, q = np.asarray(p, float), np.asarray(q, float)
        d = q - p
        length = np.linalg.norm(d)
        if length < 1e-6:
            return
        d /= length
        up = np.array([0, 0, 1.0]) if abs(d[2]) < 0.9 else np.array([1.0, 0, 0])
        s = np.cross(d, up); s /= np.linalg.norm(s)
        t = np.cross(s, d)
        h = size / 2
        corners = [(-h, -h), (h, -h), (h, h), (-h, h)]
        ps = [p + s * a + t * b for a, b in corners]
        qs = [q + s * a + t * b for a, b in corners]
        for i in range(4):
            j = (i + 1) % 4
            self.quad(ps[i], qs[i], qs[j], ps[j])
        self.quad(ps[0], ps[1], ps[2], ps[3])
        self.quad(qs[3], qs[2], qs[1], qs[0])

    def extrude_profile(self, profile, origin, heading, length, cap_start=True, cap_end=True):
        """Extrude a closed 2D profile (across, up) along a bearing, e.g. a vault section."""
        prof = orient(np.asarray(profile, dtype=np.float64), ccw=True)
        f = np.array([math.sin(math.radians(heading)), math.cos(math.radians(heading))])
        r = np.array([f[1], -f[0]])   # to the right of the axis
        def point(p, s):
            xy = np.asarray(origin, float) + r * p[0] + f * s
            return (xy[0], xy[1], p[1])
        for i in range(len(prof)):
            j = (i + 1) % len(prof)
            a, b = prof[i], prof[j]
            # Seen from outside, walking along a CCW (across, up) profile with the axis going away.
            self.quad(point(a, 0), point(a, length), point(b, length), point(b, 0))
        if cap_start or cap_end:
            idx = earcut.triangulate_float64(prof, np.array([len(prof)], dtype=np.uint32)).reshape(-1, 3)
            for t in idx:
                if cap_start:
                    tri = [point(prof[k], 0) for k in t]
                    self.add([orient_tri(tri, -np.array([f[0], f[1], 0]))])
                if cap_end:
                    tri = [point(prof[k], length) for k in t]
                    self.add([orient_tri(tri, np.array([f[0], f[1], 0]))])

    def extend(self, other: "Mesh"):
        self.tris += other.tris; self.uvs += other.uvs; self.normals += other.normals

    # ----------------------------------------------------------------- output
    def triangle_count(self):
        return sum(len(t) for t in self.tris)

    def arrays(self):
        tris = np.concatenate(self.tris)
        uvs, normals = [], []
        for t, uv, nm in zip(self.tris, self.uvs, self.normals):
            face = np.cross(t[:, 1] - t[:, 0], t[:, 2] - t[:, 0])
            length = np.linalg.norm(face, axis=1, keepdims=True)
            face = face / np.maximum(length, 1e-12)
            normals.append(np.repeat(face[:, None, :], 3, axis=1) if nm is None else nm)
            uvs.append(box_uv(t, face, self.tile) if uv is None else uv)
        tris_n = np.concatenate(normals)
        keep = np.linalg.norm(np.cross(tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0]), axis=1) > 1e-9
        return tris[keep], np.concatenate(uvs)[keep], tris_n[keep]

    def bounds(self):
        tris = np.concatenate(self.tris).reshape(-1, 3)
        return tris.min(0), tris.max(0)

    def write_obj(self, path: Path, comment: str = ""):
        tris, uvs, normals = self.arrays()
        pos = tris.reshape(-1, 3)
        # ENU (e, n, z) -> OBJ (x, y, z) = (-n, z, -e); see the module docstring.
        obj = np.column_stack([-pos[:, 1], pos[:, 2], -pos[:, 0]])
        nrm = normals.reshape(-1, 3)
        nobj = np.column_stack([-nrm[:, 1], nrm[:, 2], -nrm[:, 0]])
        uv = uvs.reshape(-1, 2)
        pv, pi = np.unique(np.round(obj, 3), axis=0, return_inverse=True)
        tv, ti = np.unique(np.round(uv, 4), axis=0, return_inverse=True)
        nv, ni = np.unique(np.round(nobj, 3), axis=0, return_inverse=True)
        pi, ti, ni = pi.reshape(-1) + 1, ti.reshape(-1) + 1, ni.reshape(-1) + 1
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("w") as f:
            f.write(f"# {comment}\n# metres; Y up; OBJ (x, y, z) = (-north, up, -east); import roll 90 yaw 90\n")
            f.write(f"o {self.name}\n")
            f.write("".join(f"v {a:.3f} {b:.3f} {c:.3f}\n" for a, b, c in pv))
            # OBJ texture v points up (image rows run from the top at v = 1): v grows with height.
            f.write("".join(f"vt {a:.4f} {b:.4f}\n" for a, b in tv))
            f.write("".join(f"vn {a:.3f} {b:.3f} {c:.3f}\n" for a, b, c in nv))
            k = np.column_stack([pi, ti, ni]).reshape(-1, 3, 3)
            f.write("".join("f {}/{}/{} {}/{}/{} {}/{}/{}\n".format(*t.reshape(-1)) for t in k))
        return len(tris), len(pv)


# --------------------------------------------------------------------- helpers
def cross2(a, b):
    return a[..., 0] * b[..., 1] - a[..., 1] * b[..., 0]


def signed_area(ring):
    r = np.asarray(ring, float)
    return 0.5 * np.sum(r[:, 0] * np.roll(r[:, 1], -1) - np.roll(r[:, 0], -1) * r[:, 1])


def orient(ring, ccw=True):
    r = np.asarray(ring, dtype=np.float64)
    if (signed_area(r) > 0) != ccw:
        r = r[::-1].copy()
    return r


def orient_tri(tri, outward):
    tri = [np.asarray(p, float) for p in tri]
    n = np.cross(tri[1] - tri[0], tri[2] - tri[0])
    return tri if np.dot(n, outward) >= 0 else tri[::-1]


def rect(center, length, width, heading=0.0):
    """Rectangle corners; length along the bearing heading (degrees clockwise from north)."""
    f = np.array([math.sin(math.radians(heading)), math.cos(math.radians(heading))])
    r = np.array([f[1], -f[0]])
    c = np.asarray(center, float)
    hl, hw = length / 2, width / 2
    return np.array([c - f * hl - r * hw, c - f * hl + r * hw, c + f * hl + r * hw, c + f * hl - r * hw])


def box_uv(tris, normals, tile):
    """Planar projection on the dominant axis, in metres / tile. Walls: u horizontal, v = height."""
    ax = np.argmax(np.abs(normals), axis=1)
    out = np.empty(tris.shape[:2] + (2,))
    for axis in range(3):
        m = ax == axis
        if not m.any():
            continue
        t = tris[m]
        if axis == 2:      # horizontal faces: plan coordinates
            out[m] = t[:, :, [0, 1]]
        elif axis == 0:    # faces towards east/west
            out[m] = np.stack([t[:, :, 1], t[:, :, 2]], axis=-1)
        else:              # faces towards north/south
            out[m] = np.stack([t[:, :, 0], t[:, :, 2]], axis=-1)
    return out / tile
