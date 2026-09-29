import AppKit
import SceneKit
import simd

extension Bismarck {
    /// Fittings laid out once the structure stands: guard rails on every superstructure deck and platform,
    /// doors, ventilation louvres and ladders on the deckhouse walls, bridge windows and vision slits, deck
    /// fittings, life rafts, flagstaffs and the wireless aerials.
    static func outfit(_ paint: Paint) -> SCNNode {
        let o = SCNNode()
        o.name = "outfit"
        o.addChildNode(superstructureRails(paint))
        o.addChildNode(wallFittings(paint))
        o.addChildNode(windows(paint))
        o.addChildNode(deckFittings(paint))
        o.addChildNode(lifeRafts(paint))
        o.addChildNode(paravanesAndSternAnchor(paint))
        o.addChildNode(aerials(paint))
        return o
    }

    /// Deterministic value in [0, 1) for laying out fittings.
    static func hash(_ a: Int, _ b: Int, _ c: Int) -> Double {
        var h = UInt64(truncatingIfNeeded: (a &* 73_856_093) ^ (b &* 19_349_663) ^ (c &* 83_492_791))
        h ^= h >> 33; h &*= 0xff51_afd7_ed55_8ccd; h ^= h >> 33; h &*= 0xc4ce_b9fe_1a85_ec53; h ^= h >> 33
        return Double(h % 10_000) / 10_000
    }

    static func area(_ outline: [SIMD2<Double>]) -> Double {
        var s = 0.0
        for i in outline.indices { let a = outline[i], b = outline[(i + 1) % outline.count]; s += a.x * b.y - b.x * a.y }
        return abs(s) / 2
    }

    /// Upper-deck height (camber included) at a frame and an offset from the centreline.
    static func deckY(_ f: Double, _ s: Double) -> Double {
        let bd = Lines.deckHalf(f), camber = 0.3 * min(1, bd / 18)
        return Lines.deckHeight(f) + camber * (1 - (bd > 0 ? min(1, (s / bd) * (s / bd)) : 1))
    }

    /// Half-breadth of the hull at a height above the keel (from the section outline).
    static func halfBreadth(_ f: Double, at h: Double) -> Double {
        let pts = Lines.section(f)
        var best = 0.0
        for i in 1..<pts.count where (pts[i - 1].y - h) * (pts[i].y - h) <= 0 && pts[i].y != pts[i - 1].y {
            let u = (h - pts[i - 1].y) / (pts[i].y - pts[i - 1].y)
            best = max(best, pts[i - 1].x + (pts[i].x - pts[i - 1].x) * u)
        }
        return best
    }

    // MARK: - Rails

    /// Guard rails along the edge of every deckhouse roof and platform, left out where another deckhouse,
    /// the funnel, a tower or a dome stands on that deck.
    static func superstructureRails(_ paint: Paint) -> SCNNode {
        var m = Mesh(slots: 1)
        let grown = houses.map { offset($0.outline, 0.45) }
        let tiny: Set<String> = ["foretopDirectorFront", "foretopDirector", "aftCommandPostWing"]
        for (index, house) in houses.enumerated() where !tiny.contains(house.name) && area(house.outline) > 10 {
            let h = house.h1
            let path = offset(house.outline, -0.12).map { V3($0.x, h - draught, $0.y) }
            m.railing(0, path, closed: true, height: 1.0, spacing: 1.6) { p in
                let q = SIMD2(p.x, p.z)
                for (i, other) in houses.enumerated() where i != index && other.h0 - 0.3 <= h && h <= other.h1 - 0.1 {
                    if inside(q, grown[i]) { return true }
                }
                for o in obstacles where o.h0 - 0.3 <= h && h <= o.h1 {
                    if simd_length((q - o.center) / (o.radii + 0.45)) < 1 { return true }
                }
                return false
            }
        }
        // SL-8 director platforms beside the tower
        for side in [-1.0, 1.0] {
            let c = SIMD2(side * 6.6, 138.8 - midFrame)
            let path = ellipse(2.5, 2.5, segments: 16).map { V3($0.x + c.x, 25.2 - draught, $0.y + c.y) }
            m.railing(0, path, closed: true, height: 1.0, spacing: 1.2) { p in abs(p.x) < 6.2 }
        }
        return node(m, [paint.light], name: "superstructureRails")
    }

    // MARK: - Walls

    /// Watertight doors, ventilation louvres and one ladder per deckhouse, spread along the walls.
    static func wallFittings(_ paint: Paint) -> SCNNode {
        var m = Mesh(slots: 3)   // 0 panels, 1 dark gaps and louvres, 2 ladders
        let plain: Set<String> = ["bridge", "admiralBridge", "foretop", "foretopDirectorFront", "foretopDirector", "foretopAft",
                                  "hangar", "aftCommandPost", "aftCommandPostWing"]
        for (hi, house) in houses.enumerated() where !house.platform {
            let wall = house.h1 - house.h0
            guard wall >= 1.6 else { continue }
            let pts = house.outline, foot = house.h0 - draught
            var ladder = plain.contains(house.name) || wall > 5.5
            for e in pts.indices {
                let a = pts[e], b = pts[(e + 1) % pts.count]
                let length = simd_length(b - a)
                guard length > 2.5 else { continue }
                let t = (b - a) / length, n = SIMD2(-t.y, t.x)
                let yaw = atan2(n.x, n.y), out = V3(n.x, 0, n.y), along = V3(t.x, 0, t.y)
                if !plain.contains(house.name) {
                    var d = 1.6 + 3.0 * hash(hi, e, 0), k = 0
                    while d < length - 1.4 {
                        let q = a + t * d, choice = hash(hi, e, k + 1)
                        if choice < 0.33 && wall >= 2.3 {
                            let c = V3(q.x, foot + 1.0, q.y) + out * 0.03
                            m.box(1, c, V3(0.98, 1.98, 0.04), yaw: yaw)
                            m.box(0, c + out * 0.03, V3(0.86, 1.86, 0.04), yaw: yaw)
                            m.box(1, c + out * 0.06 + along * 0.3, V3(0.05, 0.22, 0.03), yaw: yaw)
                        } else if choice < 0.6 {
                            let h = min(0.9, wall - 1.2), y = foot + min(1.7, wall - 0.5 - h / 2)
                            let c = V3(q.x, y, q.y) + out * 0.03
                            m.box(1, c, V3(1.3, h, 0.05), yaw: yaw)
                            var s = -h / 2 + 0.09
                            while s < h / 2 - 0.04 {
                                m.box(0, c + out * 0.04 + V3(0, s, 0), V3(1.24, 0.045, 0.05), yaw: yaw)
                                s += 0.15
                            }
                        }
                        d += 5.0 + 4.0 * hash(hi, e, k + 7)
                        k += 1
                    }
                }
                if !ladder && length > 4 {
                    let q = a + t * 0.9
                    let base = V3(q.x, foot, q.y) + out * 0.22
                    m.ladder(2, base, base + V3(0, wall + 0.9, 0), outward: out)
                    ladder = true
                }
            }
        }
        // inclined ladders from the upper deck to the first superstructure deck, two a side fore and aft
        for (f0, f1, s, h) in [(95.0, 92.2, 11.8, 18.0), (108.6, 105.8, 11.8, 18.0), (140.0, 137.2, 12.3, 19.7), (160.5, 157.7, 7.2, 19.7)] {
            for side in [-1.0, 1.0] {
                let footS = side * (s + 1.1), headS = side * (s - 0.2)
                let a = p(f0, deckY(f0, footS), footS), b = p(f1, h, headS)
                m.ladder(2, a, b, outward: V3(side, 0, 0), width: 0.7, pitch: 0.25)
            }
        }
        return node(m, [paint.light, paint.black, paint.light], name: "wallFittings")
    }

    /// Window rows on the navigating and admiral's bridges, vision slits round the armoured command post.
    static func windows(_ paint: Paint) -> SCNNode {
        var m = Mesh(slots: 2)   // 0 glass, 1 frames
        for (name, y) in [("bridge", 28.25), ("admiralBridge", 32.45)] {
            guard let house = houses.first(where: { $0.name == name }) else { continue }
            let pts = house.outline
            for e in pts.indices {
                let a = pts[e], b = pts[(e + 1) % pts.count]
                let length = simd_length(b - a)
                let t = (b - a) / length, n = SIMD2(-t.y, t.x)
                guard n.y > -0.3, length > 0.9 else { continue }   // not on the after walls
                let yaw = atan2(n.x, n.y), out = V3(n.x, 0, n.y)
                let count = max(1, Int((length - 0.4) / 1.05))
                let pitch = length / Double(count)
                for k in 0..<count {
                    let q = a + t * (pitch * (Double(k) + 0.5))
                    // the forward command post stands in front of the middle of the bridge front
                    if name == "bridge" && abs(q.x) < 2.8 && q.y > 146.5 - midFrame { continue }
                    let c = V3(q.x, y - draught, q.y)
                    m.box(1, c + out * 0.03, V3(0.86, 0.72, 0.04), yaw: yaw)
                    m.box(0, c + out * 0.05, V3(0.72, 0.58, 0.04), yaw: yaw)
                }
            }
            // sun visor over the window row
            for e in pts.indices {
                let a = pts[e], b = pts[(e + 1) % pts.count], length = simd_length(b - a)
                let t = (b - a) / length, n = SIMD2(-t.y, t.x)
                guard n.y > -0.3, length > 0.9 else { continue }
                let mid = (a + b) / 2
                m.box(1, V3(mid.x, y + 0.5 - draught, mid.y) + V3(n.x, 0, n.y) * 0.25, V3(length, 0.05, 0.5), yaw: atan2(n.x, n.y))
            }
        }
        // vision slits of the armoured forward command post (conning tower), front half
        for k in -6...6 {
            let angle = Double(k) * 0.24
            let q = SIMD2(2.62 * sin(angle), 149.5 - midFrame + 2.22 * cos(angle))
            m.box(0, V3(q.x, 28.6 - draught, q.y), V3(0.5, 0.1, 0.06), yaw: angle)
        }
        return node(m, [paint.glass, paint.black], name: "windows")
    }

    // MARK: - Decks

    /// Bollards, fairleads, mushroom ventilators and hatch coamings on the forecastle and quarterdeck, and
    /// ready-use lockers beside the light guns.
    static func deckFittings(_ paint: Paint) -> SCNNode {
        var m = Mesh(slots: 2)   // 0 dark steel, 1 light grey
        // bollard pairs and fairleads along both sides
        for f in [3.0, 14.0, 30.0, 52.0, 70.0, 112.0, 150.0, 176.0, 186.0, 203.0, 222.0, 229.0] {
            for side in [-1.0, 1.0] {
                let s = side * (Lines.deckHalf(f) - 1.3)
                let y = deckY(f, s) - draught
                m.box(0, V3(s, y + 0.05, f - midFrame), V3(0.8, 0.1, 1.7))
                for dz in [-0.5, 0.5] {
                    m.cylinder(0, V3(s, y, f - midFrame + dz), V3(s, y + 0.62, f - midFrame + dz), 0.2, segments: 12)
                    m.cylinder(0, V3(s, y + 0.62, f - midFrame + dz), V3(s, y + 0.7, f - midFrame + dz), 0.27, segments: 12)
                }
                let edge = side * (Lines.deckHalf(f + 2.5) - 0.35)
                let ye = deckY(f + 2.5, edge) - draught
                m.box(0, V3(edge, ye + 0.25, f + 2.5 - midFrame), V3(0.35, 0.5, 1.1))
            }
        }
        // mushroom ventilators
        let vents: [(Double, Double)] = [(200.0, 4.5), (205.0, 7.0), (209.0, 3.5), (219.0, 5.0), (225.0, 2.5), (184.0, 8.5),
                                         (36.0, 5.0), (31.0, 8.0), (24.0, 4.0), (18.0, 7.5), (12.0, 3.0), (56.0, 9.0), (41.0, 10.0)]
        for (f, s0) in vents { for side in [-1.0, 1.0] {
            let s = side * s0, y = deckY(f, s) - draught
            m.cylinder(1, V3(s, y, f - midFrame), V3(s, y + 0.75, f - midFrame), 0.2, segments: 12)
            m.cylinder(1, V3(s, y + 0.75, f - midFrame), V3(s, y + 0.95, f - midFrame), 0.42, 0.3, segments: 16)
        } }
        // hatch coamings
        let hatches: [(Double, Double, Double, Double)] = [(214.0, 0, 1.6, 2.2), (226.0, 0, 1.3, 1.8), (205.0, 5.5, 1.2, 1.6),
                                                           (25.0, 0, 1.6, 2.4), (15.0, 4.5, 1.2, 1.6), (58.0, 6.0, 1.2, 1.6)]
        for (f, s0, w, l) in hatches { for side in (s0 == 0 ? [1.0] : [-1.0, 1.0]) {
            let s = side * s0, y = deckY(f, s) - draught
            m.box(1, V3(s, y + 0.2, f - midFrame), V3(w, 0.4, l))
            m.box(0, V3(s, y + 0.42, f - midFrame), V3(w - 0.2, 0.05, l - 0.2))
        } }
        // ready-use ammunition lockers by the 3.7 cm twins and 2 cm guns
        for (f, s0, h) in [(73.6, 5.6, 18.0), (85.3, 5.0, 20.6), (95.6, 3.1, 23.0), (142.2, 3.0, 29.2), (78.4, 5.6, 18.0), (118.0, 6.8, 27.2)] {
            for side in [-1.0, 1.0] {
                m.box(1, p(f - 1.4, h + 0.45, side * s0), V3(0.7, 0.9, 1.2))
                m.box(0, p(f - 1.4, h + 0.92, side * s0), V3(0.75, 0.05, 1.25))
            }
        }
        return node(m, [paint.dark, paint.light], name: "deckFittings")
    }

    /// External degaussing (MES) cable along both sides, 1.2 m under the deck edge.
    static func degaussingCable(_ paint: Paint) -> SCNNode {
        var m = Mesh(slots: 1)
        for side in [-1.0, 1.0] {
            var previous: V3? = nil
            var f = 4.0
            while f <= 236.0 {
                let h = Lines.deckHeight(f) - 1.2
                let q = p(f, h, side * (halfBreadth(f, at: h) + 0.06))
                if let a = previous { m.beam(0, a, q, width: 0.16, height: 0.2) }
                previous = q
                f += f < 30 || f > 200 ? 1.0 : 3.0
            }
        }
        return node(m, [paint.hull], name: "degaussingCable")
    }

    /// Carley floats hung on the deckhouse sides, in pairs.
    static func lifeRafts(_ paint: Paint) -> SCNNode {
        var m = Mesh(slots: 2)   // 0 float, 1 grating
        func raft(_ center: V3, along: V3, out: V3) {
            let a = 1.05, b = 0.48, r = 0.14
            let segments = 20
            var rings: [[UInt32]] = []
            for i in 0..<segments {
                let t = 2 * Double.pi * Double(i) / Double(segments)
                let radial = simd_normalize(along * (cos(t) / a) + V3(0, sin(t) / b, 0))
                let c = center + along * (a * cos(t)) + V3(0, b * sin(t), 0)
                var ring: [UInt32] = []
                for k in 0..<6 {
                    let phi = 2 * Double.pi * Double(k) / 6
                    let n = radial * cos(phi) + out * sin(phi)
                    ring.append(m.vertex(c + n * r, n))
                }
                rings.append(ring)
            }
            // wind the tube outwards whichever side of the ship the float hangs on
            let flip = simd_dot(simd_cross(along, V3(0, 1, 0)), out) < 0
            for i in 0..<segments {
                let j = (i + 1) % segments
                for k in 0..<6 {
                    let l = (k + 1) % 6
                    if flip { m.quad(0, rings[i][k], rings[i][l], rings[j][l], rings[j][k]) }
                    else { m.quad(0, rings[i][k], rings[j][k], rings[j][l], rings[i][l]) }
                }
            }
            let yaw = atan2(out.x, out.z)
            m.box(1, center - out * 0.02, V3(2 * a - 0.2, 2 * b - 0.2, 0.05), yaw: yaw)
        }
        // sixteen floats in all
        let spots: [(Double, Double, Double)] = [(79.0, 7.5, 18.0), (82.5, 7.5, 18.0), (88.5, 7.5, 18.0), (92.0, 7.5, 18.0), (95.5, 7.5, 18.0),
                                                 (151.0, 7.1, 19.7), (154.5, 7.1, 19.7), (158.0, 7.0, 19.7)]
        for (f, s, deck) in spots { for side in [-1.0, 1.0] {
            raft(p(f, deck + 1.35, side * (s + 0.2)), along: V3(0, 0, 1), out: V3(side, 0, 0))
        } }
        return node(m, [paint.canvas, paint.dark], name: "lifeRafts")
    }

    /// Six minesweeping paravanes on their cradles on the forecastle, and the stern anchor on the port quarter
    /// with its chain to a capstan on the quarterdeck.
    static func paravanesAndSternAnchor(_ paint: Paint) -> SCNNode {
        var m = Mesh(slots: 3)   // 0 grey body, 1 dark steel, 2 chain
        for (f, side) in [(215.5, -1.0), (219.0, -1.0), (222.5, -1.0), (215.5, 1.0), (219.0, 1.0), (222.5, 1.0)] {
            let s = side * (Lines.deckHalf(f) - 2.6), y = deckY(f, s) - draught + 0.55
            let c = V3(s, y, f - midFrame)
            m.cylinder(0, c + V3(0, 0, -1.3), c + V3(0, 0, 0.9), 0.24, 0.26, segments: 12)
            m.cylinder(0, c + V3(0, 0, 0.9), c + V3(0, 0, 1.35), 0.26, 0.06, segments: 12)
            m.box(0, c + V3(0, 0, -1.1), V3(1.5, 0.05, 0.5))
            m.box(0, c + V3(0, 0, -1.1), V3(0.05, 0.9, 0.5))
            for dz in [-0.6, 0.6] { m.box(1, c + V3(0, -0.4, dz), V3(0.7, 0.3, 0.12)) }
        }
        // stern anchor: hawse on the port side 2 m under the deck edge, anchor against the hull, chain to its capstan
        let hawse = 6.0, side = -1.0
        let h = Lines.deckHeight(hawse) - 2.0
        let b = halfBreadth(hawse, at: h)
        m.cylinder(1, V3(side * (b - 0.1), h - draught, hawse - midFrame), V3(side * (b + 0.12), h - draught, hawse - midFrame), 0.42, segments: 16)
        let a = V3(side * (b + 0.12), h - 1.4 - draught, hawse - 0.2 - midFrame)
        m.box(1, a + V3(0, 0.4, 0), V3(0.26, 2.4, 0.28))
        m.box(1, a + V3(0, -0.9, 0), V3(0.36, 0.45, 2.0))
        for dz in [-0.85, 0.85] { m.box(1, a + V3(0, -0.6, dz), V3(0.32, 1.0, 0.45)) }
        let capstan = V3(-2.6, deckY(14.0, -2.6) - draught, 14.0 - midFrame)
        m.cylinder(1, capstan, capstan + V3(0, 0.85, 0), 0.7, 0.6, segments: 18)
        var f = hawse + 0.8
        var previous = V3(side * (b - 0.6), deckY(hawse + 0.8, side * (b - 0.6)) - draught + 0.1, hawse + 0.8 - midFrame)
        while f < 13.4 {
            f += 0.5
            let t = (f - hawse) / (14.0 - hawse)
            let sx = side * (b - 0.6) + (capstan.x - side * (b - 0.6)) * t
            let q = V3(sx, deckY(f, sx) - draught + 0.1, f - midFrame)
            m.beam(2, previous, q, width: 0.2, height: 0.12)
            previous = q
        }
        return node(m, [paint.dark, paint.gun, paint.rope], name: "paravanesAndSternAnchor")
    }

    // MARK: - Masts and aerials

    /// Wireless aerials between the masts, shrouds and stays, jack and ensign staffs.
    static func aerials(_ paint: Paint) -> SCNNode {
        var m = Mesh(slots: 2)   // 0 wire, 1 staffs
        func wire(_ a: V3, _ b: V3) { m.beam(0, a, b, width: 0.035) }
        for side in [-1.0, 1.0] {
            // main aerials: foremast yard to mainmast yard, and on down to the aft command post pole
            wire(p(131.3, 46.0, side * 2.9), p(102.2, 45.6, side * 3.5))
            wire(p(102.2, 45.6, side * 3.5), p(85.4, 35.4, side * 0.3))
            // down-leads to the admiral's bridge and the hangar roof
            wire(p(126.0, 45.9, side * 3.0), p(134.8, 33.4, side * 2.8))
            wire(p(106.0, 45.6, side * 3.4), p(104.0, 23.4, side * 4.8))
            // mainmast shrouds and foremast stays
            wire(p(102.2, 39.4, side * 0.4), p(99.0, 23.4, side * 5.6))
            wire(p(102.2, 39.4, side * 0.4), p(106.0, 23.4, side * 5.6))
            wire(p(131.3, 44.0, side * 0.2), p(131.9, 39.95, side * 3.4))
        }
        wire(p(131.3, 48.2), p(102.2, 50.1))
        wire(p(99.0, 49.8), p(85.4, 35.8))
        // jack staff at the stem, ensign staff at the stern
        let stem = 244.6, stern = -2.6
        m.cylinder(1, p(stem, deckY(stem, 0)), p(stem, deckY(stem, 0) + 5.5), 0.09, 0.05, segments: 10)
        m.cylinder(1, p(stern, deckY(stern, 0)), p(stern, deckY(stern, 0) + 6.5), 0.1, 0.05, segments: 10)
        return node(m, [paint.rope, paint.light], name: "aerials")
    }
}
