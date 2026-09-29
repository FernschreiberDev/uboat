import AppKit
import SceneKit
import simd

// Small parts batched into meshes: boxes, beams, cylinders, railings and ladders. Winding follows the rest of
// the model: faces counter-clockwise by the right-hand rule in model coordinates, seen from outside.

extension Bismarck.Mesh {
    typealias V3 = SIMD3<Double>

    /// Box turned by `yaw` about the vertical (its local z along (sin yaw, 0, cos yaw)).
    mutating func box(_ slot: Int, _ center: V3, _ size: V3, yaw: Double = 0) {
        let u = V3(cos(yaw), 0, -sin(yaw)), v = V3(0, 1, 0), w = V3(sin(yaw), 0, cos(yaw))
        frameBox(slot, center, u * size.x / 2, v * size.y / 2, w * size.z / 2)
    }

    /// Box with half-axes u, v, w forming a right-handed frame.
    mutating func frameBox(_ slot: Int, _ c: V3, _ u: V3, _ v: V3, _ w: V3, bottom: Bool = true) {
        func p(_ i: Double, _ j: Double, _ k: Double) -> V3 { c + u * i + v * j + w * k }
        polygon(slot, [p(1, -1, -1), p(1, 1, -1), p(1, 1, 1), p(1, -1, 1)])
        polygon(slot, [p(-1, -1, -1), p(-1, -1, 1), p(-1, 1, 1), p(-1, 1, -1)])
        polygon(slot, [p(-1, 1, -1), p(-1, 1, 1), p(1, 1, 1), p(1, 1, -1)])
        if bottom { polygon(slot, [p(-1, -1, -1), p(1, -1, -1), p(1, -1, 1), p(-1, -1, 1)]) }
        polygon(slot, [p(-1, -1, 1), p(1, -1, 1), p(1, 1, 1), p(-1, 1, 1)])
        polygon(slot, [p(-1, -1, -1), p(-1, 1, -1), p(1, 1, -1), p(1, -1, -1)])
    }

    /// Right-handed frame (u, v, w) with w along `axis` and v as close to vertical as possible.
    static func frame(along axis: V3) -> (V3, V3, V3) {
        let w = simd_normalize(axis)
        let up = abs(w.y) > 0.95 ? V3(1, 0, 0) : V3(0, 1, 0)
        let v = simd_normalize(up - w * simd_dot(up, w))
        return (simd_cross(v, w), v, w)
    }

    /// Square-section bar from a to b.
    mutating func beam(_ slot: Int, _ a: V3, _ b: V3, width: Double, height: Double? = nil) {
        let length = simd_length(b - a)
        guard length > 1e-6 else { return }
        let (u, v, w) = Self.frame(along: b - a)
        frameBox(slot, (a + b) / 2, u * width / 2, v * (height ?? width) / 2, w * length / 2)
    }

    /// Cylinder (or cone) from a to b with smooth sides and flat ends.
    mutating func cylinder(_ slot: Int, _ a: V3, _ b: V3, _ r0: Double, _ r1: Double? = nil, segments: Int = 12, caps: Bool = true) {
        let length = simd_length(b - a)
        guard length > 1e-6 else { return }
        let (u, v, w) = Self.frame(along: b - a)
        let r1 = r1 ?? r0
        let slope = (r0 - r1) / length
        var bottomRing: [UInt32] = [], topRing: [UInt32] = []
        for i in 0..<segments {
            let t = 2 * Double.pi * Double(i) / Double(segments)
            let radial = u * cos(t) + v * sin(t)
            let n = simd_normalize(radial + w * slope)
            bottomRing.append(vertex(a + radial * r0, n))
            topRing.append(vertex(b + radial * r1, n))
        }
        for i in 0..<segments {
            let j = (i + 1) % segments
            quad(slot, bottomRing[i], bottomRing[j], topRing[j], topRing[i])
        }
        if caps {
            let ring0 = (0..<segments).map { i -> V3 in let t = 2 * Double.pi * Double(i) / Double(segments); return a + (u * cos(t) + v * sin(t)) * r0 }
            let ring1 = (0..<segments).map { i -> V3 in let t = 2 * Double.pi * Double(i) / Double(segments); return b + (u * cos(t) + v * sin(t)) * r1 }
            polygon(slot, ring0.reversed())
            if r1 > 1e-6 { polygon(slot, ring1) }
        }
    }

    /// Guard rail along a path at a given height: stanchions about every `spacing` metres and two rails (knee
    /// and hand height). `skip` removes stanchions (and the rails reaching them) where the deck is taken.
    mutating func railing(_ slot: Int, _ path: [V3], closed: Bool, height: Double = 1.0, spacing: Double = 1.6,
                          skip: (V3) -> Bool = { _ in false }) {
        guard path.count >= 2 else { return }
        var points: [V3] = []
        let count = closed ? path.count : path.count - 1
        for i in 0..<count {
            let a = path[i], b = path[(i + 1) % path.count]
            let n = max(1, Int((simd_length(b - a) / spacing).rounded(.up)))
            for k in 0..<n { points.append(a + (b - a) * Double(k) / Double(n)) }
        }
        if !closed { points.append(path[path.count - 1]) }
        let keep = points.map { !skip($0) }
        for (i, p) in points.enumerated() where keep[i] {
            box(slot, p + V3(0, height / 2, 0), V3(0.045, height, 0.045))
        }
        let pairs = closed ? points.count : points.count - 1
        for i in 0..<pairs {
            let j = (i + 1) % points.count
            guard keep[i] && keep[j] else { continue }
            for h in [height * 0.5, height] {
                beam(slot, points[i] + V3(0, h, 0), points[j] + V3(0, h, 0), width: 0.035)
            }
        }
    }

    /// Vertical or inclined ladder from a (foot) to b (head), `outward` pointing away from the wall it leans on.
    mutating func ladder(_ slot: Int, _ a: V3, _ b: V3, outward: V3, width: Double = 0.45, pitch: Double = 0.3) {
        let run = b - a, length = simd_length(run)
        guard length > 0.3 else { return }
        let side = simd_normalize(simd_cross(run, outward)) * (width / 2)
        for s in [-1.0, 1.0] { beam(slot, a + side * s, b + side * s, width: 0.05) }
        var d = pitch
        while d < length - 0.1 {
            let p = a + run * (d / length)
            beam(slot, p - side, p + side, width: 0.03)
            d += pitch
        }
    }
}

extension Bismarck {
    /// Deckhouse or platform as built, kept for the details laid out afterwards (rails, doors, ladders).
    struct House {
        let name: String
        let outline: [SIMD2<Double>]
        let h0: Double, h1: Double
        let platform: Bool
    }
    /// Filled while the superstructure is built (reset by `make`).
    static var houses: [House] = []
    /// Round obstacles standing on the decks (towers, funnel, domes): centre (x, z), radii, heights above the keel.
    static var obstacles: [(center: SIMD2<Double>, radii: SIMD2<Double>, h0: Double, h1: Double)] = []

    static func inside(_ p: SIMD2<Double>, _ polygon: [SIMD2<Double>]) -> Bool {
        var result = false
        var j = polygon.count - 1
        for i in polygon.indices {
            let a = polygon[i], b = polygon[j]
            if (a.y > p.y) != (b.y > p.y) && p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { result.toggle() }
            j = i
        }
        return result
    }
}
