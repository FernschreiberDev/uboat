import AppKit
import SceneKit
import simd

extension Bismarck {
    /// Hull lines. Outlines are pixel readings of the 1/1000 plan (profile keel at y = 689, 11.84 px/m
    /// vertically and across; lengthwise 11.694 px/m with the aft perpendicular at x = 89.8, which puts the
    /// four turrets on their official frames, and 12.43 px/m forward of Anton so that the stem lands at the
    /// official overall length). Below the waterline the sections are superellipses whose fullness and the
    /// waterline taper were fitted to the official coefficients: block 0.549, waterplane 0.666, midship 0.970
    /// at the 9.33 m standard draught.
    enum Lines {
        static func frame(_ x: Double) -> Double { x > 2341.5 ? 192.55 + (x - 2341.5) / 12.43 : (x - 89.8) / 11.694 }
        static func height(_ y: Double) -> Double { (689 - y) / 11.84 }

        static let sheer: [(Double, Double)] = [
            (44, 496), (72, 497), (120, 499), (200, 501), (300, 504), (400, 505), (500, 507), (600, 509), (700, 509.5),
            (800, 511), (900, 511), (1000, 512), (1700, 512), (1800, 511), (1900, 510), (2000, 509), (2100, 507),
            (2200, 505), (2300, 503), (2400, 501), (2500, 499), (2560, 497), (2600, 496), (2650, 494), (2700, 492),
            (2750, 489), (2800, 487), (2850, 485), (2900, 481), (2950, 477), (3000, 470), (3013, 468),
        ].map { (frame($0.0), height($0.1)) }
        /// Half-breadth of the upper deck (metres) by plan pixel.
        static let deck: [(Double, Double)] = [
            (44, 0.0), (48, 1.31), (64, 2.58), (80, 3.34), (96, 3.93), (128, 4.86), (160, 5.79), (192, 6.55), (224, 7.22),
            (256, 7.90), (288, 8.57), (320, 9.16), (336, 9.50), (400, 10.43), (448, 11.19), (496, 11.61), (544, 12.20),
            (592, 12.80), (640, 13.39), (688, 13.98), (752, 14.65), (800, 15.16), (848, 15.58), (912, 16.09), (976, 16.51),
            (1040, 16.93), (1104, 17.27), (1168, 17.61), (1232, 17.78), (1296, 17.86), (1392, 17.99), (1472, 17.99),
            (1552, 17.95), (1616, 17.86), (1680, 17.70), (1744, 17.44), (1808, 17.10), (1872, 16.68), (1936, 16.26),
            (2000, 15.84), (2064, 15.25), (2128, 14.65), (2192, 13.98), (2256, 13.30), (2320, 12.54), (2384, 11.70),
            (2448, 10.94), (2512, 10.18), (2576, 9.42), (2640, 8.40), (2704, 7.14), (2768, 5.87), (2832, 4.52),
            (2864, 3.93), (2912, 2.83), (2944, 2.15), (2976, 1.39), (3008, 0.89), (3013, 0.0),
        ].map { (frame($0.0), $0.1) }
        /// Cruiser stern (profile, keel upwards) and stem (forefoot upwards).
        static let stern: [(Double, Double)] = [
            (160, 612), (145, 608), (124, 600), (106, 592), (84, 580), (65, 560), (53, 540), (47, 520), (44, 500), (44, 496),
        ].map { (frame($0.0), height($0.1)) }
        static let stem: [(Double, Double)] = [
            (2914, 688), (2918, 680), (2919, 660), (2922, 640), (2927, 620), (2933, 600), (2941, 580), (2950, 560),
            (2961, 540), (2974, 520), (2991, 500), (3010, 480), (3013, 468),
        ].map { (frame($0.0), height($0.1)) }
        static let keelAft = 30.0, keelFore = frame(2914)

        // Fitted parameters (see the hydrostatic test).
        static let waterline = 10.0
        static let taperAft = 45.0, powerAft = 1.5, taperFore = 60.0, powerFore = 1.5
        static let nMid = 7.0, nEnd = 1.2, fullAft = (70.0, 95.0), fullFore = (130.0, 210.0)
        static let flare = 1.35

        static func interp(_ table: [(Double, Double)], _ x: Double) -> Double {
            if x <= table[0].0 { return table[0].1 }
            for i in 1..<table.count where x <= table[i].0 {
                let (a, va) = table[i - 1], (b, vb) = table[i]
                return b - a < 1e-9 ? vb : va + (vb - va) * (x - a) / (b - a)
            }
            return table[table.count - 1].1
        }
        static func smooth(_ u: Double) -> Double { let t = min(1, max(0, u)); return t * t * (3 - 2 * t) }

        /// Height of the hull bottom on the centreline: keel, stern cut-up, stem.
        static func bottom(_ f: Double) -> Double {
            if f >= keelFore { return f >= stem.last!.0 ? stem.last!.1 : interp(stem.map { ($0.0, $0.1) }, f) }
            let sternLow = stern[0]
            if f <= sternLow.0 {
                // stern profile, read from its lowest point upwards (frames decrease)
                let pts = stern.reversed().map { ($0.0, $0.1) }
                return interp(pts, f)
            }
            // cut-up: the keel rises from frame 30 to 6 m at frame 17, then runs almost flat over the
            // screws and rudders to the stern
            if f < 17 { return 6.0 + (sternLow.1 - 6.0) * (17 - f) / (17 - sternLow.0) }
            if f < keelAft { return 6.0 * smooth((keelAft - f) / 13) }
            return 0
        }
        static func deckHeight(_ f: Double) -> Double { interp(sheer, f) }
        static func deckHalf(_ f: Double) -> Double { interp(deck, f) }

        /// Frames where the loaded waterline leaves the stern and the stem.
        static let waterlineEnds: (Double, Double) = {
            var aft = sternFrame, fore = stemFrame
            var f = sternFrame
            while f < keelAft { if bottom(f) <= waterline { aft = f; break }; f += 0.01 }
            f = stemFrame
            while f > keelFore { if bottom(f) <= waterline { fore = f; break }; f -= 0.01 }
            return (aft, fore)
        }()

        static func waterlineHalf(_ f: Double) -> Double {
            let (a, b) = waterlineEnds
            let ca = 1 - pow(1 - min(1, max(0, (f - a) / taperAft)), powerAft)
            let cf = 1 - pow(1 - min(1, max(0, (b - f) / taperFore)), powerFore)
            return deckHalf(f) * ca * cf
        }
        /// Superellipse exponent of the underwater section: full amidships, V-shaped at the ends.
        static func fullness(_ f: Double) -> Double {
            let w = min(smooth((f - fullAft.0) / (fullAft.1 - fullAft.0)), smooth((fullFore.1 - f) / (fullFore.1 - fullFore.0)))
            return nEnd + (nMid - nEnd) * w
        }

        static let underwaterPoints = 28, flarePoints = 10

        /// Section outline from the keel on the centreline to the deck edge: (half-breadth, height above keel).
        static func section(_ f: Double) -> [SIMD2<Double>] {
            let hb = bottom(f), hd = deckHeight(f), bd = deckHalf(f)
            let count = underwaterPoints + flarePoints
            var pts: [SIMD2<Double>] = []
            if hb < waterline && hd > waterline {
                let bw = waterlineHalf(f), n = fullness(f)
                for k in 0..<underwaterPoints {
                    // θ from the keel (π/2) to the waterline (0), denser near the bilge
                    let s = Double(k) / Double(underwaterPoints - 1)
                    let theta = Double.pi / 2 * (1 - s)
                    let c = pow(max(0, cos(theta)), 2 / n), sn = pow(max(0, sin(theta)), 2 / n)
                    pts.append(SIMD2(bw * c, waterline - (waterline - hb) * sn))
                }
                for k in 1...flarePoints {
                    let t = Double(k) / Double(flarePoints)
                    pts.append(SIMD2(bw + (bd - bw) * pow(t, flare), waterline + (hd - waterline) * t))
                }
            } else {
                // overhang above the waterline: round U from the centreline to the deck edge
                for k in 0..<count {
                    let phi = Double.pi / 2 * (1 - Double(k) / Double(count - 1))
                    pts.append(SIMD2(bd * cos(phi), hd - (hd - hb) * sin(phi)))
                }
            }
            return pts
        }

        /// Lengthwise stations: close together at the ends.
        static let stations: [Double] = {
            var s: [Double] = []
            var f = sternFrame
            while f < stemFrame {
                s.append(f)
                f += (f < 25 || f > 225) ? 0.5 : 1.0
            }
            s.append(stemFrame)
            for k in [keelAft, keelFore, waterlineEnds.0, waterlineEnds.1] where !s.contains(where: { abs($0 - k) < 0.05 }) { s.append(k) }
            return s.sorted()
        }()

        /// Displaced volume, waterplane area and midship section area at a draught (for the tests).
        struct Hydrostatics {
            /// Displaced volume (m³), waterplane area (m²), largest immersed section (m²).
            var volume = 0.0, waterplane = 0.0, midship = 0.0
            /// Centre of buoyancy (frame, height above the keel), centre of the waterplane (frame).
            var lcb = 0.0, kb = 0.0, lcf = 0.0
            /// Second moments of the waterplane about the centreline and about its centre (m⁴).
            var inertiaT = 0.0, inertiaL = 0.0
            /// Waterline ends (frames).
            var aft = Double.infinity, fore = -Double.infinity
        }

        static func hydrostatics(draught t: Double) -> Hydrostatics {
            var r = Hydrostatics()
            var momentX = 0.0, momentZ = 0.0, areaX = 0.0, areaXX = 0.0
            var f = sternFrame
            let df = 0.25
            while f <= stemFrame {
                let pts = section(f)
                var a = 0.0, az = 0.0
                for i in 1..<pts.count {
                    let p0 = pts[i - 1], p1 = pts[i]
                    let h0 = min(p0.y, t), h1 = min(p1.y, t)
                    if h1 > h0 {
                        let strip = (p0.x + p1.x) * (h1 - h0)   // both sides
                        a += strip; az += strip * (h0 + h1) / 2
                    }
                }
                // waterplane half-breadth: interpolate along the outline
                var bw = 0.0
                for i in 1..<pts.count where (pts[i - 1].y - t) * (pts[i].y - t) <= 0 && pts[i].y != pts[i - 1].y {
                    let u = (t - pts[i - 1].y) / (pts[i].y - pts[i - 1].y)
                    bw = max(bw, pts[i - 1].x + (pts[i].x - pts[i - 1].x) * u)
                }
                r.volume += a * df; momentX += a * f * df; momentZ += az * df
                r.waterplane += 2 * bw * df; areaX += 2 * bw * f * df; areaXX += 2 * bw * f * f * df
                r.inertiaT += 2 * pow(bw, 3) / 3 * df
                r.midship = max(r.midship, a)
                if bw > 0.01 { r.aft = min(r.aft, f); r.fore = max(r.fore, f) }
                f += df
            }
            r.lcb = momentX / r.volume; r.kb = momentZ / r.volume
            r.lcf = areaX / r.waterplane
            r.inertiaL = areaXX - r.waterplane * r.lcf * r.lcf
            return r
        }
    }

    // MARK: - Hull and deck

    static func hull(_ paint: Paint) -> SCNNode {
        let node = SCNNode()
        node.name = "hull"
        let span = stemFrame - sternFrame
        func uv(_ f: Double, _ h: Double) -> SIMD2<Double> { SIMD2((f - sternFrame) / span, 1 - h / 20) }

        var shell = Mesh(slots: 1)
        let stations = Lines.stations
        let sections = stations.map { Lines.section($0) }
        for side in [1.0, -1.0] {
            var rings: [[UInt32]] = []
            for (f, pts) in zip(stations, sections) {
                rings.append(pts.map { shell.vertex(p(f, $0.y, side * $0.x), V3(side, 0, 0), uv(f, $0.y)) })
            }
            for r in 0..<(rings.count - 1) { for k in 0..<(rings[r].count - 1) {
                let a = rings[r][k], b = rings[r][k + 1], c = rings[r + 1][k + 1], d = rings[r + 1][k]
                if side > 0 { shell.quad(0, a, b, c, d) } else { shell.quad(0, a, d, c, b) }
            } }
        }
        shell.smoothNormals()
        node.addChildNode(Bismarck.node(shell, [paint.hull], name: "shell"))

        // Upper deck with a 0.3 m camber, teak and steel from the deck texture.
        var deck = Mesh(slots: 1)
        let across = 24
        var rows: [[UInt32]] = []
        for f in stations {
            let bd = Lines.deckHalf(f), hd = Lines.deckHeight(f), camber = 0.3 * min(1, bd / 18)
            rows.append((0...across).map { k in
                let s = -bd + 2 * bd * Double(k) / Double(across)
                let h = hd + camber * (1 - (bd > 0 ? (s / bd) * (s / bd) : 1))
                return deck.vertex(p(f, h, s), V3(0, 1, 0), SIMD2((f - sternFrame) / span, 0.5 - s / 36))
            })
        }
        for r in 0..<(rows.count - 1) { for k in 0..<across {
            deck.quad(0, rows[r][k], rows[r + 1][k], rows[r + 1][k + 1], rows[r][k + 1])
        } }
        deck.smoothNormals()
        node.addChildNode(Bismarck.node(deck, [paint.deck], name: "deck"))

        node.addChildNode(bilgeKeels(paint))
        node.addChildNode(sternGear(paint))
        node.addChildNode(groundTackle(paint))
        node.addChildNode(rails(paint))
        return node
    }

    /// Turn of the bilge: the superellipse point at 45°, with the outward normal of the section there.
    static func bilgePoint(_ f: Double) -> (SIMD2<Double>, SIMD2<Double>) {
        let hb = Lines.bottom(f), bw = Lines.waterlineHalf(f), n = Lines.fullness(f), t = Lines.waterline
        func point(_ theta: Double) -> SIMD2<Double> {
            SIMD2(bw * pow(cos(theta), 2 / n), t - (t - hb) * pow(sin(theta), 2 / n))
        }
        let q = point(.pi / 4), d = simd_normalize(point(.pi / 4 - 0.01) - point(.pi / 4 + 0.01))
        return (q, SIMD2(d.y, -d.x))
    }

    static func bilgeKeels(_ paint: Paint) -> SCNNode {
        var m = Mesh(slots: 1)
        let frames = stride(from: 84.0, through: 158.0, by: 2.0).map { $0 }
        for side in [1.0, -1.0] {
            for face in [1.0, -1.0] {
                var inner: [UInt32] = [], outer: [UInt32] = []
                for f in frames {
                    let (q, n) = bilgePoint(f)
                    let depth = 0.9 * min(1, min(f - 83, 159 - f) / 6)
                    let a = q, b = q + n * depth
                    let uvA = SIMD2((f - sternFrame) / (stemFrame - sternFrame), 1 - a.y / 20)
                    inner.append(m.vertex(p(f, a.y, side * a.x), V3(0, 0, 1), uvA))
                    outer.append(m.vertex(p(f, b.y, side * b.x), V3(0, 0, 1), uvA))
                }
                for i in 0..<(frames.count - 1) {
                    if face * side > 0 { m.quad(0, inner[i], outer[i], outer[i + 1], inner[i + 1]) }
                    else { m.quad(0, inner[i], inner[i + 1], outer[i + 1], outer[i]) }
                }
            }
        }
        m.smoothNormals()
        return node(m, [paint.hull], name: "bilgeKeels")
    }

    /// Three screws (4.7 m, the centre one furthest aft), their shafts and brackets, and the twin rudders.
    static func sternGear(_ paint: Paint) -> SCNNode {
        let gear = SCNNode()
        gear.name = "sternGear"
        // centre screw aft of the skeg, wing screws further forward on exposed shafts (plan: frames 15.4 and 23.1)
        let screws: [(frame: Double, height: Double, offset: Double, turn: Double)] = [
            (15.4, 2.9, 0, 1), (23.1, 2.45, -7.0, -1), (23.1, 2.45, 7.0, 1),
        ]
        for s in screws {
            let hub = p(s.frame, s.height, s.offset)
            let screw = SCNNode()
            screw.simdPosition = SIMD3<Float>(hub)
            gear.addChildNode(screw)
            let cap = SCNSphere(radius: 0.45); cap.segmentCount = 16
            add(screw, cap, paint.bronze, V3(0, 0, -0.3)).scale = SCNVector3(1, 1, 1.6)
            for k in 0..<3 {
                let blade = SCNNode()
                blade.simdOrientation = simd_quatf(angle: Float(Double(k) * 2 * .pi / 3), axis: SIMD3<Float>(0, 0, 1))
                screw.addChildNode(blade)
                let shape = SCNSphere(radius: 1); shape.segmentCount = 18
                let b = add(blade, shape, paint.bronze, V3(0, 1.25, 0))
                b.scale = SCNVector3(0.62, 1.12, 0.07)
                b.simdOrientation = simd_quatf(angle: Float(0.45 * s.turn), axis: SIMD3<Float>(0, 1, 0))
            }
            if s.offset == 0 {
                // centre shaft inside a skeg that fairs into the keel at frame 30
                let axis = [p(16.0, 2.9, 0), p(30.5, 1.1, 0)]
                rod(gear, axis[0], axis[1], 0.55, 1.05, paint.bottom)
                let skeg: [SIMD2<Double>] = [SIMD2(0.35, 30.5 - midFrame), SIMD2(0.35, 16.0 - midFrame),
                                             SIMD2(-0.35, 16.0 - midFrame), SIMD2(-0.35, 30.5 - midFrame)]
                let plate = prism(skeg, y0: 1.6 - draught, y1: 6.2 - draught)
                gear.addChildNode(node(plate, [paint.bottom], name: "skeg"))
            } else {
                // exposed wing shaft on two A-brackets, faired into a bossing where it leaves the hull
                let entry = p(52, 2.9, s.offset * 0.9)
                rod(gear, hub + V3(0, 0, 0.4), entry, 0.3, nil, paint.gun)
                rod(gear, p(44, 2.8, s.offset * 0.93), p(56, 3.0, s.offset * 0.86), 0.45, 1.2, paint.bottom)
                for f in [s.frame + 2.4, s.frame + 14.0] {
                    let t = (f - s.frame) / (52 - s.frame)
                    let c = hub + (entry - hub) * t
                    for dx in [-1.6, 1.6] {
                        let top = p(f, max(Lines.bottom(f), 0) + 3.4, s.offset * 0.55 + dx * 0.6)
                        rod(gear, c, top, 0.14, nil, paint.gun)
                    }
                    let boss = SCNCylinder(radius: 0.5, height: 1.2); boss.radialSegmentCount = 14
                    let b = add(gear, boss, paint.gun, c); b.eulerAngles.x = .pi / 2
                }
            }
        }
        // Twin rudders abreast behind the centre screw; balanced blades 4.2 m chord, 4.6 m tall.
        let foil: [SIMD2<Double>] = (0..<14).map { k in
            let t = Double(k) / 13 * 2 * .pi
            let z = 2.75 * cos(t), x = 0.38 * sin(t) * (1 + 0.35 * (z / 2.75))
            return SIMD2(x, z)
        }
        for side in [-1.0, 1.0] {
            let rudder = SCNNode()
            let top = Lines.bottom(11.3) + 0.2
            rudder.simdPosition = SIMD3<Float>(p(11.3, 0, side * 3.0))
            gear.addChildNode(rudder)
            rudder.addChildNode(node(prism(foil, y0: 1.8, y1: top, bottom: true), [paint.bottom], name: "rudder"))
            rod(rudder, V3(0, top - 0.1, 0.4), V3(0, top + 1.2, 0.4), 0.28, nil, paint.bottom)
        }
        return gear
    }

    /// Anchors in their hawse pipes, chains, capstans, bollards and the small V breakwater at the stem.
    static func groundTackle(_ paint: Paint) -> SCNNode {
        let t = SCNNode()
        t.name = "groundTackle"
        let hawse = 233.6
        for side in [-1.0, 1.0] {
            // hawse pipe outlet on the side, anchor stowed against the hull
            let b = Lines.deckHalf(hawse), h = Lines.deckHeight(hawse) - 2.2
            let outlet = SCNCylinder(radius: 0.55, height: 0.3); outlet.radialSegmentCount = 18
            let o = add(t, outlet, paint.black, p(hawse, h, side * (b - 0.35)))
            o.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
            let anchor = SCNNode()
            anchor.simdPosition = SIMD3<Float>(p(hawse - 0.2, h - 1.6, side * (b - 0.1)))
            anchor.eulerAngles = SCNVector3(0, 0, Float(side * 0.12))
            t.addChildNode(anchor)
            box(anchor, V3(0.28, 2.8, 0.3), V3(0, 0.3, 0), paint.dark, chamfer: 0.06)
            box(anchor, V3(0.4, 0.5, 2.3), V3(0, -1.2, 0), paint.dark, chamfer: 0.1)
            for dz in [-1.0, 1.0] { box(anchor, V3(0.35, 1.2, 0.5), V3(0, -0.8, dz * 1.0), paint.dark, chamfer: 0.08) }
            // chain from the capstan to the deck pipe
            let deckY = { (f: Double) in Lines.deckHeight(f) + 0.3 * min(1, Lines.deckHalf(f) / 18) * 0.97 }
            var chain = Mesh(slots: 1)
            let f0 = 212.6, f1 = hawse - 0.8
            var f = f0
            while f < f1 {
                let a = p(f, deckY(f) + 0.12, side * 2.75), c = p(f + 0.5, deckY(f + 0.5) + 0.12, side * 2.75)
                chain.append(prism(roundedRect(0.18, 0.25, 0.1, segments: 2), y0: 0, y1: 0.16),
                             transform: simd_double4x4(translation: (a + c) / 2 - V3(0, 0.08, 0)))
                f += 0.5
            }
            t.addChildNode(node(chain, [paint.rope], name: "chain"))
            let capstan = SCNCylinder(radius: 0.75, height: 0.9); capstan.radialSegmentCount = 20
            add(t, capstan, paint.dark, p(212.6, deckY(212.6) + 0.45, side * 2.8))
            let pipe = SCNCylinder(radius: 0.45, height: 0.35); pipe.radialSegmentCount = 16
            add(t, pipe, paint.dark, p(hawse - 0.6, deckY(hawse - 0.6) + 0.17, side * 2.75))
        }
        // bollards (pairs) near the deck edges
        let bollards: [(Double, Double)] = [(23.0, 10.1), (40.0, 12.3), (214.9, 6.6), (217.3, 8.4), (196.0, 11.0), (8.0, 5.8)]
        for (f, s) in bollards { for side in [-1.0, 1.0] { for dz in [-0.45, 0.45] {
            let c = SCNCylinder(radius: 0.22, height: 0.7); c.radialSegmentCount = 12
            add(t, c, paint.dark, p(f + dz, Lines.deckHeight(f) + 0.35, side * (s - 0.9)))
        } } }
        // low V breakwater plate ahead of the hawse pipes
        let tip = 237.6, back = 234.6
        for side in [-1.0, 1.0] {
            let a = p(back, Lines.deckHeight(back), side * 3.6), b = p(tip, Lines.deckHeight(tip), 0)
            let len = simd_length(b - a)
            let plate = SCNBox(width: 0.08, height: 0.9, length: CGFloat(len), chamferRadius: 0)
            let n = add(t, plate, paint.light, (a + b) / 2 + V3(0, 0.45, 0))
            n.simdOrientation = simd_quatf(angle: Float(atan2(b.x - a.x, b.z - a.z)), axis: SIMD3<Float>(0, 1, 0))
        }
        return t
    }

    /// Deck-edge guard rails: stanchions every 2 m and two wires.
    static func rails(_ paint: Paint) -> SCNNode {
        var m = Mesh(slots: 1)
        func bar(_ a: V3, _ b: V3, _ r: Double) {
            let d = b - a, len = simd_length(d)
            guard len > 1e-6 else { return }
            var piece = prism([SIMD2(-r, -r), SIMD2(r, -r), SIMD2(r, r), SIMD2(-r, r)].map { SIMD2($0.x, -$0.y) }, y0: 0, y1: len)
            piece.smoothNormals()
            let up = V3(0, 1, 0), axis = d / len
            let cross = simd_cross(up, axis)
            var rot = matrix_identity_double4x4
            if simd_length(cross) > 1e-9 {
                rot = simd_double4x4(simd_quatd(angle: acos(max(-1, min(1, simd_dot(up, axis)))), axis: simd_normalize(cross)))
            }
            m.append(piece, transform: simd_double4x4(translation: a) * rot)
        }
        for side in [-1.0, 1.0] {
            var f = sternFrame + 1.0
            var previous: (V3, V3, V3)? = nil
            while f < stemFrame - 2.5 {
                let b = Lines.deckHalf(f) - 0.25, h = Lines.deckHeight(f)
                let foot = p(f, h, side * b), mid = foot + V3(0, 0.6, 0), top = foot + V3(0, 1.1, 0)
                bar(foot, top, 0.025)
                if let (_, pm, pt) = previous { bar(pm, mid, 0.012); bar(pt, top, 0.012) }
                previous = (foot, mid, top)
                f += 2.0
            }
        }
        return node(m, [paint.rope], name: "rails")
    }

    // MARK: - Textures

    /// Hull side paint on a (frame, height above keel) map: red bottom, black boot-topping, grey sides, the
    /// white false bow wave, the belt line and the portholes at the ends.
    /// Side scuttles of the hull, plan pixels (profile of 24 May 1941).
    static let scuttles: [(Double, Double)] = [
        (83, 516), (95, 516), (110, 516), (130, 517), (146, 517), (162, 518), (187, 519), (215, 520), (254, 521),
        (288, 522), (318, 522), (351, 522), (381, 522), (418, 522),
        (99, 549), (122, 549), (137, 549), (158, 550), (182, 551), (199, 551), (217, 552), (243, 552), (264, 552),
        (289, 552), (306, 552), (324, 552), (354, 553), (389, 553), (421, 553),
        (2542, 516), (2576, 516), (2606, 514), (2645, 513), (2683, 511), (2717, 509), (2753, 508), (2786, 506),
        (2531, 553), (2560, 553), (2579, 553), (2605, 553), (2646, 552), (2686, 552), (2717, 551), (2747, 551), (2781, 551)]
    /// Rungs welded to the hull at the stern, plan x.
    static let hullRungs: [Double] = [122, 155, 201, 377]

    static func hullTexture(_ livery: Livery = .denmarkStrait) -> NSImage {
        let w = 8192, h = 640, span = stemFrame - sternFrame
        func x(_ f: Double) -> CGFloat { CGFloat((f - sternFrame) / span * Double(w)) }
        func y(_ height: Double) -> CGFloat { CGFloat(height / 20 * Double(h)) }
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        func fill(_ rgb: UInt32) {
            ctx.setFillColor(red: CGFloat((rgb >> 16) & 255) / 255, green: CGFloat((rgb >> 8) & 255) / 255, blue: CGFloat(rgb & 255) / 255, alpha: 1)
        }
        fill(0x8C9199); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        // boot-topping: 7.94 m to 10.55 m, stopping at 9.12 m forward of frame 205.7 as on the plan
        let bootTopAft = 10.55, bootTopFore = 9.12, bootLow = 7.94, change = Lines.frame(2505)
        fill(0x2E2F32)
        ctx.fill(CGRect(x: 0, y: y(bootLow), width: x(change), height: y(bootTopAft) - y(bootLow)))
        ctx.fill(CGRect(x: x(change), y: y(bootLow), width: CGFloat(w) - x(change), height: y(bootTopFore) - y(bootLow)))
        fill(0x5B2A19); ctx.fill(CGRect(x: 0, y: 0, width: CGFloat(w), height: y(bootLow)))
        // Positions below are plan pixels (profile of 24 May 1941), turned into frames and heights.
        func point(_ q: (Double, Double)) -> CGPoint { CGPoint(x: x(Lines.frame(q.0)), y: y(Lines.height(q.1))) }
        func shape(_ pts: [(Double, Double)], _ rgb: UInt32, alpha: CGFloat = 1) {
            ctx.setFillColor(red: CGFloat((rgb >> 16) & 255) / 255, green: CGFloat((rgb >> 8) & 255) / 255, blue: CGFloat(rgb & 255) / 255, alpha: alpha)
            ctx.beginPath()
            for (i, q) in pts.enumerated() { if i == 0 { ctx.move(to: point(q)) } else { ctx.addLine(to: point(q)) } }
            ctx.closePath(); ctx.fillPath()
        }
        // Korsfjord, 21 May: bow and stern darker grey (plan of 21 May: limits at frames 19.9–21.0 and 213.6–220.1)
        if livery == .korsfjord {
            shape([(40, 480), (322, 480), (322, 510), (335, 576), (40, 576)], 0x5F636A)
            shape([(2690, 480), (2684, 498), (2603, 576), (3000, 576), (3000, 480)], 0x5F636A)
        }
        // Baltic stripes: black and white on 21 May, painted over in the Grimstadfjord on 21–22 May (a darker
        // and a lighter grey band in each pair on 24 May)
        let darker: UInt32 = livery == .korsfjord ? 0x2A2B2D : 0x858A91, lighter: UInt32 = livery == .korsfjord ? 0xE4E4E1 : 0x969BA3
        shape([(1044, 515), (1091, 515), (1060, 566), (1012, 566)], darker)
        shape([(1092, 515), (1137, 515), (1105, 566), (1061, 566)], lighter)
        shape([(1288, 515), (1342, 515), (1312, 545), (1331, 566), (1277, 566), (1261, 545)], darker)
        shape([(1343, 515), (1411, 515), (1382, 545), (1400, 566), (1332, 566), (1313, 545)], lighter)
        shape([(1875, 515), (1946, 515), (1914, 566), (1842, 566)], lighter)
        shape([(1947, 515), (2010, 515), (1981, 566), (1915, 566)], darker)
        // false bow wave, white, down over the boot-topping
        shape([(2497, 580), (2500, 568), (2510, 566), (2520, 563), (2530, 557), (2540, 549), (2550, 545), (2560, 543), (2570, 542),
               (2580, 541), (2590, 542), (2600, 544), (2610, 553), (2613, 562), (2613, 580)], 0xE8E8E4)
        // false stern wave, light grey, just above the boot-topping
        shape([(328, 549), (437, 550), (464, 555), (484, 560), (505, 566), (332, 566)], livery == .korsfjord ? 0xE4E4E1 : 0xA6AAB0)
        // top of the main armour belt (12.4 m above the keel) between the citadel bulkheads, a slight joggle
        fill(0x72777F)
        var f = Lines.frame(460)
        while f < Lines.frame(2500) {
            let rise = max(0, (f - 150) / 55) * 0.17
            ctx.fill(CGRect(x: x(f), y: y(12.42 + rise), width: x(f + 1) - x(f) + 1, height: 2))
            ctx.fill(CGRect(x: x(f), y: y(12.58 + rise), width: x(f + 1) - x(f) + 1, height: 2))
            f += 1
        }
        // side scuttles with their brows, as on the plan
        for q in scuttles {
            let c = point(q), r: CGFloat = 5.5
            fill(0x2A2C30); ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
            fill(0x747981); ctx.fill(CGRect(x: c.x - 1.6 * r, y: c.y + 2.0 * r, width: 3.2 * r, height: 2.5))
            // faint rust tear under each scuttle
            ctx.setFillColor(red: 0.45, green: 0.33, blue: 0.25, alpha: 0.18)
            ctx.fill(CGRect(x: c.x - 1.5, y: c.y - 3.2 * r, width: 3, height: 2.2 * r))
        }
        // rungs welded to the hull at the stern
        fill(0x70757E)
        for px in hullRungs {
            var py = 504.0
            while py < 556 { let c = point((px, py)); ctx.fill(CGRect(x: c.x - 6, y: c.y, width: 12, height: 2)); py += 4 }
        }
        // rust streaks from the hawse pipes and grime along the boot-topping
        for hawse in [233.6] {
            let top = Lines.deckHeight(hawse) - 2.2
            for k in 0..<7 {
                let dx = CGFloat(k - 3) * 3.2
                ctx.setFillColor(red: 0.42, green: 0.26, blue: 0.16, alpha: 0.28 - 0.03 * CGFloat(abs(k - 3)))
                ctx.fill(CGRect(x: x(hawse) + dx, y: y(bootTopFore), width: 2.4, height: y(top) - y(bootTopFore)))
            }
        }
        ctx.setFillColor(red: 0.23, green: 0.24, blue: 0.25, alpha: 0.35)
        ctx.fill(CGRect(x: 0, y: y(bootTopAft), width: x(change), height: 6))
        ctx.fill(CGRect(x: x(change), y: y(bootTopFore), width: CGFloat(w) - x(change), height: 6))
        // scupper stains every 12 m, below the deck edge
        var sf = 8.0
        while sf < 236 {
            let top = Lines.deckHeight(sf) - 0.3
            ctx.setFillColor(red: 0.4, green: 0.34, blue: 0.3, alpha: 0.16)
            ctx.fill(CGRect(x: x(sf), y: y(top - 2.6), width: 3, height: y(top) - y(top - 2.6)))
            sf += 12
        }
        // faint vertical plate butts
        fill(0x858A92)
        f = 0.0
        while f < 244 { ctx.fill(CGRect(x: x(f), y: y(bootTopAft), width: 1, height: y(15) - y(bootTopAft))); f += 6.0 }
        let image = ctx.makeImage()!
        return NSImage(cgImage: image, size: NSSize(width: w, height: h))
    }

    /// Upper deck: teak planking 0.12 m wide with staggered butts, steel plating at the stern and around the
    /// anchor gear, and a steel waterway along the edges.
    static func deckTexture(_ livery: Livery = .denmarkStrait) -> NSImage {
        let w = 8192, h = 1152, span = stemFrame - sternFrame
        func x(_ f: Double) -> CGFloat { CGFloat((f - sternFrame) / span * Double(w)) }
        func y(_ s: Double) -> CGFloat { CGFloat((s + 18) / 36 * Double(h)) }
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        func fill(_ rgb: UInt32) {
            ctx.setFillColor(red: CGFloat((rgb >> 16) & 255) / 255, green: CGFloat((rgb >> 8) & 255) / 255, blue: CGFloat(rgb & 255) / 255, alpha: 1)
        }
        fill(0xB0A084); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        // plank seams every 0.12 m and butts every ~6 m, staggered over four planks
        fill(0x8A7A62)
        var s = -18.0, row = 0
        while s < 18 {
            ctx.fill(CGRect(x: 0, y: y(s), width: CGFloat(w), height: 1))
            var f = sternFrame + Double(row % 4) * 1.5
            while f < stemFrame { ctx.fill(CGRect(x: x(f), y: y(s), width: 1, height: y(s + 0.12) - y(s))); f += 6.0 }
            s += 0.12; row += 1
        }
        // each plank length a slightly different shade of weathered teak
        var plankRow = 0
        var ps = -18.0
        while ps < 18 {
            var f = sternFrame + Double(plankRow % 4) * 1.5 - 6
            var k = 0
            while f < stemFrame {
                let v = Bismarck.hash(plankRow, k, 3) - 0.5
                ctx.setFillColor(red: 0.5 + 0.5 * CGFloat(v), green: 0.45 + 0.45 * CGFloat(v), blue: 0.35 + 0.3 * CGFloat(v), alpha: 0.10 + 0.06 * CGFloat(abs(v)))
                ctx.fill(CGRect(x: x(f) + 1, y: y(ps) + 1, width: x(f + 6) - x(f) - 1, height: y(ps + 0.12) - y(ps) - 1))
                f += 6; k += 1
            }
            ps += 0.12; plankRow += 1
        }
        // steel plating in arcs inboard of the 15 cm turrets, under the blast of their guns (plan)
        ctx.setStrokeColor(red: 0.43, green: 0.44, blue: 0.48, alpha: 1)
        ctx.setLineWidth(y(1.0) - y(0))
        for (tf, ts) in [(99.6, 14.4), (131.2, 15.2), (150.6, 10.0)] { for side in [-1.0, 1.0] {
            ctx.beginPath()
            for k in 0...36 {
                let a = Double.pi * Double(k) / 36
                let q = CGPoint(x: x(tf + 5.6 * cos(a)), y: y(side * (ts - 5.6 * sin(a))))
                if k == 0 { ctx.move(to: q) } else { ctx.addLine(to: q) }
            }
            ctx.strokePath()
        } }
        // steel areas
        fill(0x6D717A)
        ctx.fill(CGRect(x: x(Lines.frame(145)), y: 0, width: x(Lines.frame(306)) - x(Lines.frame(145)), height: CGFloat(h)))
        ctx.fill(CGRect(x: x(Lines.frame(2658)), y: 0, width: x(Lines.frame(2805)) - x(Lines.frame(2658)), height: CGFloat(h)))
        ctx.fill(CGRect(x: x(Lines.frame(2985)), y: 0, width: CGFloat(w) - x(Lines.frame(2985)), height: CGFloat(h)))
        // Korsfjord, 21 May: air-recognition panels on the quarterdeck and the forecastle (painted grey on 22 May)
        if livery == .korsfjord {
            drawAirRecognition(ctx, x: x, y: y, from: sternFrame - 1, to: 17.2, centre: 10.96)
            drawAirRecognition(ctx, x: x, y: y, from: 218.3, to: stemFrame + 1, centre: 223.9)
        }
        // waterways: 0.4 m of steel inside each deck edge
        var f = sternFrame
        while f < stemFrame {
            let b = Lines.deckHalf(f)
            ctx.fill(CGRect(x: x(f), y: y(b - 0.4), width: x(f + 0.5) - x(f) + 1, height: y(b + 0.2) - y(b - 0.4)))
            ctx.fill(CGRect(x: x(f), y: y(-b - 0.2), width: x(f + 0.5) - x(f) + 1, height: y(-b + 0.4) - y(-b - 0.2)))
            f += 0.5
        }
        let image = ctx.makeImage()!
        return NSImage(cgImage: image, size: NSSize(width: w, height: h))
    }
}

extension simd_double4x4 {
    init(translation t: SIMD3<Double>) {
        self = matrix_identity_double4x4
        columns.3 = SIMD4<Double>(t.x, t.y, t.z, 1)
    }
}
