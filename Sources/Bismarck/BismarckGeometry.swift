import AppKit
import SceneKit
import simd

// Mesh building for the Bismarck model. Everything lives in the Bismarck namespace so that these
// files can join the game's sources later without clashing with the U-boat helpers.

extension Bismarck {
    typealias V3 = SIMD3<Double>

    /// Triangle mesh with one element per material slot.
    struct Mesh {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        var elements: [[UInt32]]

        init(slots: Int = 1) { elements = Array(repeating: [], count: slots) }

        @discardableResult
        mutating func vertex(_ p: V3, _ n: V3 = V3(0, 1, 0), _ uv: SIMD2<Double> = .zero) -> UInt32 {
            positions.append(SIMD3<Float>(p)); normals.append(SIMD3<Float>(simd_normalize(n))); uvs.append(SIMD2<Float>(uv))
            return UInt32(positions.count - 1)
        }
        mutating func triangle(_ slot: Int, _ a: UInt32, _ b: UInt32, _ c: UInt32) { elements[slot] += [a, b, c] }
        /// Quad a-b-c-d, counter-clockwise seen from outside.
        mutating func quad(_ slot: Int, _ a: UInt32, _ b: UInt32, _ c: UInt32, _ d: UInt32) {
            elements[slot] += [a, b, c, a, c, d]
        }
        /// Flat-shaded polygon (convex or not), counter-clockwise seen from outside.
        mutating func polygon(_ slot: Int, _ points: [V3], uv: (V3) -> SIMD2<Double> = { _ in .zero }) {
            guard points.count >= 3 else { return }
            var n = V3.zero
            for i in points.indices { n += simd_cross(points[i], points[(i + 1) % points.count]) }
            guard simd_length(n) > 1e-12 else { return }
            n = simd_normalize(n)
            let ids = points.map { vertex($0, n, uv($0)) }
            for tri in Bismarck.triangulate(points, normal: n) { triangle(slot, ids[tri.0], ids[tri.1], ids[tri.2]) }
        }
        /// Replace the normals by area-weighted averages over shared vertices (smooth shading).
        mutating func smoothNormals() {
            var acc = [SIMD3<Float>](repeating: .zero, count: positions.count)
            for element in elements {
                for t in stride(from: 0, to: element.count, by: 3) {
                    let a = Int(element[t]), b = Int(element[t + 1]), c = Int(element[t + 2])
                    let n = simd_cross(positions[b] - positions[a], positions[c] - positions[a])
                    acc[a] += n; acc[b] += n; acc[c] += n
                }
            }
            for i in acc.indices where simd_length(acc[i]) > 1e-12 { normals[i] = simd_normalize(acc[i]) }
        }
        mutating func append(_ other: Mesh, transform: simd_double4x4 = matrix_identity_double4x4) {
            let base = UInt32(positions.count)
            let normalMatrix = simd_transpose(simd_inverse(transform))
            for i in other.positions.indices {
                let p = transform * SIMD4<Double>(SIMD3<Double>(other.positions[i]), 1)
                let n = normalMatrix * SIMD4<Double>(SIMD3<Double>(other.normals[i]), 0)
                positions.append(SIMD3<Float>(Float(p.x), Float(p.y), Float(p.z)))
                normals.append(SIMD3<Float>(simd_normalize(SIMD3<Double>(n.x, n.y, n.z))))
                uvs.append(other.uvs[i])
            }
            for (slot, element) in other.elements.enumerated() {
                while elements.count <= slot { elements.append([]) }
                elements[slot] += element.map { $0 + base }
            }
        }
        func geometry(_ materials: [SCNMaterial]) -> SCNGeometry {
            let sources = [
                SCNGeometrySource(vertices: positions.map { SCNVector3($0.x, $0.y, $0.z) }),
                SCNGeometrySource(normals: normals.map { SCNVector3($0.x, $0.y, $0.z) }),
                SCNGeometrySource(textureCoordinates: uvs.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }),
            ]
            var used: [SCNGeometryElement] = [], mats: [SCNMaterial] = []
            for (slot, element) in elements.enumerated() where !element.isEmpty {
                used.append(SCNGeometryElement(indices: element, primitiveType: .triangles))
                mats.append(materials[slot % materials.count])
            }
            let g = SCNGeometry(sources: sources, elements: used)
            g.materials = mats
            return g
        }
    }

    /// Ear clipping of a planar polygon; returns index triples, same winding as the input.
    static func triangulate(_ points: [V3], normal: V3) -> [(Int, Int, Int)] {
        var index = Array(points.indices), result: [(Int, Int, Int)] = []
        func convex(_ a: V3, _ b: V3, _ c: V3) -> Bool { simd_dot(simd_cross(b - a, c - b), normal) > 1e-12 }
        func inside(_ p: V3, _ a: V3, _ b: V3, _ c: V3) -> Bool {
            simd_dot(simd_cross(b - a, p - a), normal) >= 0 && simd_dot(simd_cross(c - b, p - b), normal) >= 0
                && simd_dot(simd_cross(a - c, p - c), normal) >= 0
        }
        var guardCount = 0
        while index.count > 3 && guardCount < 10000 {
            guardCount += 1
            var clipped = false
            for k in index.indices {
                let i0 = index[(k + index.count - 1) % index.count], i1 = index[k], i2 = index[(k + 1) % index.count]
                let a = points[i0], b = points[i1], c = points[i2]
                guard convex(a, b, c) else { continue }
                if index.contains(where: { $0 != i0 && $0 != i1 && $0 != i2 && inside(points[$0], a, b, c) }) { continue }
                result.append((i0, i1, i2)); index.remove(at: k); clipped = true; break
            }
            if !clipped { break }
        }
        if index.count == 3 { result.append((index[0], index[1], index[2])) }
        return result
    }

    // MARK: - Shapes

    /// Prism from a plan outline (x, z), counter-clockwise seen from above, between heights y0 and y1.
    /// `inset` shrinks the top outline towards its centroid (sloped walls).
    static func prism(_ outline: [SIMD2<Double>], y0: Double, y1: Double, inset: Double = 0, slot: Int = 0,
                      top: Bool = true, bottom: Bool = false) -> Mesh {
        var m = Mesh(slots: slot + 1)
        let c = outline.reduce(SIMD2<Double>.zero, +) / Double(outline.count)
        let upper = outline.map { p -> SIMD2<Double> in
            let d = p - c, l = simd_length(d)
            return l > 1e-9 ? p - d / l * inset : p
        }
        for i in outline.indices {
            let j = (i + 1) % outline.count
            let a = V3(outline[i].x, y0, outline[i].y), b = V3(outline[j].x, y0, outline[j].y)
            let d = V3(upper[i].x, y1, upper[i].y), e = V3(upper[j].x, y1, upper[j].y)
            m.polygon(slot, [a, b, e, d])
        }
        if top { m.polygon(slot, upper.map { V3($0.x, y1, $0.y) }) }
        if bottom { m.polygon(slot, outline.reversed().map { V3($0.x, y0, $0.y) }) }
        return m
    }

    /// Outline moved outwards by a distance (mitred corners); counter-clockwise outline seen from above.
    static func offset(_ outline: [SIMD2<Double>], _ d: Double) -> [SIMD2<Double>] {
        let n = outline.count
        return (0..<n).map { i in
            let a = outline[(i + n - 1) % n], b = outline[i], c = outline[(i + 1) % n]
            // outward normals of the two edges, in (x, z) with the outline counter-clockwise seen from above
            func normal(_ p: SIMD2<Double>, _ q: SIMD2<Double>) -> SIMD2<Double> {
                let t = simd_normalize(q - p)
                return SIMD2(-t.y, t.x)
            }
            let n1 = normal(a, b), n2 = normal(b, c)
            let m = simd_normalize(n1 + n2), cosHalf = max(0.35, simd_dot(m, n1))
            return b + m * (d / cosHalf)
        }
    }

    /// Deckhouse: walls with world-scale texture coordinates (slot 0, `tile` metres per texture repeat), roof
    /// (slot 1) and an overhanging plate along the roof edge (slot 2).
    static func house(_ outline: [SIMD2<Double>], y0: Double, y1: Double, tile: SIMD2<Double>, lip: Double = 0.14) -> Mesh {
        var m = Mesh(slots: 3)
        var run = 0.0
        for i in outline.indices {
            let a = outline[i], b = outline[(i + 1) % outline.count]
            let length = simd_length(b - a)
            let pa = V3(a.x, y0, a.y), pb = V3(b.x, y0, b.y), qb = V3(b.x, y1, b.y), qa = V3(a.x, y1, a.y)
            let u0 = run / tile.x, u1 = (run + length) / tile.x, v0 = 1.0, v1 = 1 - (y1 - y0) / tile.y
            m.polygon(0, [pa, pb, qb, qa]) { p in
                let t = simd_length(SIMD2(p.x, p.z) - a) / max(length, 1e-9)
                return SIMD2(u0 + (u1 - u0) * t, p.y <= y0 + 1e-6 ? v0 : v1)
            }
            run += length
        }
        m.polygon(1, outline.map { V3($0.x, y1, $0.y) })
        if lip > 0 {
            let outer = offset(outline, lip)
            let plate = prism(outer, y0: y1 - 0.14, y1: y1 + 0.02, slot: 2, bottom: true)
            m.append(plate)
        }
        return m
    }

    /// Solid built from cross-sections (x, y) placed at increasing z; all sections share their point count
    /// and run counter-clockwise seen from +z. Ends are capped.
    static func loftZ(_ sections: [(z: Double, points: [SIMD2<Double>])], slot: Int = 0, smooth: Bool = false) -> Mesh {
        var m = Mesh(slots: slot + 1)
        let n = sections[0].points.count
        if smooth {
            var rings: [[UInt32]] = []
            for s in sections { rings.append(s.points.map { m.vertex(V3($0.x, $0.y, s.z)) }) }
            for r in 0..<(sections.count - 1) { for i in 0..<n {
                let j = (i + 1) % n
                m.quad(slot, rings[r][i], rings[r][j], rings[r + 1][j], rings[r + 1][i])
            } }
            m.smoothNormals()
        } else {
            for r in 0..<(sections.count - 1) { for i in 0..<n {
                let j = (i + 1) % n
                let a = sections[r].points[i], b = sections[r].points[j]
                let c = sections[r + 1].points[j], d = sections[r + 1].points[i]
                m.polygon(slot, [V3(a.x, a.y, sections[r].z), V3(b.x, b.y, sections[r].z),
                                 V3(c.x, c.y, sections[r + 1].z), V3(d.x, d.y, sections[r + 1].z)])
            } }
        }
        let first = sections[0], last = sections[sections.count - 1]
        m.polygon(slot, first.points.reversed().map { V3($0.x, $0.y, first.z) })
        m.polygon(slot, last.points.map { V3($0.x, $0.y, last.z) })
        return m
    }

    /// Surface of revolution around y from a profile (radius, y) running bottom to top.
    static func lathe(_ profile: [SIMD2<Double>], segments: Int = 32, slot: Int = 0, scaleX: Double = 1, scaleZ: Double = 1) -> Mesh {
        var m = Mesh(slots: slot + 1)
        var rings: [[UInt32]] = []
        for p in profile {
            rings.append((0...segments).map { k in
                let a = Double(k) / Double(segments) * 2 * .pi
                return m.vertex(V3(p.x * sin(a) * scaleX, p.y, p.x * cos(a) * scaleZ), V3(sin(a), 0, cos(a)))
            })
        }
        for r in 0..<(profile.count - 1) { for k in 0..<segments {
            m.quad(slot, rings[r][k], rings[r][k + 1], rings[r + 1][k + 1], rings[r + 1][k])
        } }
        m.smoothNormals()
        return m
    }

    /// Rounded-rectangle outline (half sizes a along x, b along z, corner radius r) centred on the origin.
    static func roundedRect(_ a: Double, _ b: Double, _ r: Double, segments: Int = 4) -> [SIMD2<Double>] {
        let r = min(r, a, b)
        var pts: [SIMD2<Double>] = []
        let corners = [SIMD2(a - r, b - r), SIMD2(-(a - r), b - r), SIMD2(-(a - r), -(b - r)), SIMD2(a - r, -(b - r))]
        for (i, c) in corners.enumerated() {
            for k in 0...segments {
                let t = Double.pi / 2 * (Double(i) + Double(k) / Double(segments))
                pts.append(c + SIMD2(cos(t), sin(t)) * r)
            }
        }
        // counter-clockwise seen from above means increasing angle from +x towards -z in (x, z)
        return pts.map { SIMD2($0.x, -$0.y) }
    }

    /// Ellipse outline in (x, z), counter-clockwise seen from above.
    static func ellipse(_ a: Double, _ b: Double, segments: Int = 24) -> [SIMD2<Double>] {
        (0..<segments).map { k in
            let t = Double(k) / Double(segments) * 2 * .pi
            return SIMD2(a * cos(t), -b * sin(t))
        }
    }

    // MARK: - Nodes

    static func node(_ mesh: Mesh, _ materials: [SCNMaterial], name: String? = nil) -> SCNNode {
        let n = SCNNode(geometry: mesh.geometry(materials))
        n.name = name
        return n
    }

    @discardableResult
    static func add(_ parent: SCNNode, _ geometry: SCNGeometry, _ material: SCNMaterial, _ p: V3, name: String? = nil) -> SCNNode {
        geometry.materials = [material]
        let n = SCNNode(geometry: geometry)
        n.simdPosition = SIMD3<Float>(p)
        n.name = name
        parent.addChildNode(n)
        return n
    }

    /// Cylinder (or cone when the radii differ) between two points.
    @discardableResult
    static func rod(_ parent: SCNNode, _ a: V3, _ b: V3, _ r0: Double, _ r1: Double? = nil, _ material: SCNMaterial,
                    segments: Int = 12) -> SCNNode {
        let length = simd_length(b - a)
        let g: SCNGeometry
        if let r1, abs(r1 - r0) > 1e-6 {
            let cone = SCNCone(topRadius: CGFloat(r1), bottomRadius: CGFloat(r0), height: CGFloat(length))
            cone.radialSegmentCount = segments
            g = cone
        } else {
            let c = SCNCylinder(radius: CGFloat(r0), height: CGFloat(length))
            c.radialSegmentCount = segments
            g = c
        }
        let n = add(parent, g, material, (a + b) / 2)
        let axis = simd_normalize(b - a), up = V3(0, 1, 0)
        let cross = simd_cross(up, axis)
        if simd_length(cross) > 1e-9 {
            n.simdOrientation = simd_quatf(angle: Float(acos(max(-1, min(1, simd_dot(up, axis))))), axis: SIMD3<Float>(simd_normalize(cross)))
        } else if axis.y < 0 {
            n.simdOrientation = simd_quatf(angle: .pi, axis: SIMD3<Float>(1, 0, 0))
        }
        return n
    }

    @discardableResult
    static func box(_ parent: SCNNode, _ size: V3, _ center: V3, _ material: SCNMaterial, chamfer: Double = 0) -> SCNNode {
        add(parent, SCNBox(width: CGFloat(size.x), height: CGFloat(size.y), length: CGFloat(size.z), chamferRadius: CGFloat(chamfer)),
            material, center)
    }
}
