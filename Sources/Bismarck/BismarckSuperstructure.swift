import AppKit
import SceneKit
import simd

extension Bismarck {
    /// Deckhouses, towers, funnel, masts, boats, catapult and cranes, laid out from the plan of 24 May 1941
    /// (frames and offsets) with heights read on its profile. Superstructure decks: 18.0, 20.6, 23.2 and
    /// 25.8 m above the keel.
    static func superstructure(_ paint: Paint) -> SCNNode {
        let s = SCNNode()
        s.name = "superstructure"
        s.addChildNode(afterSuperstructure(paint))
        s.addChildNode(funnel(paint))
        s.addChildNode(forwardSuperstructure(paint))
        return s
    }

    /// Plan outline from a half-breadth profile given aft to fore, counter-clockwise seen from above.
    static func outline(_ profile: [(Double, Double)]) -> [SIMD2<Double>] {
        let right = profile.reversed().map { SIMD2($0.1, $0.0 - midFrame) }
        let left = profile.map { SIMD2(-$0.1, $0.0 - midFrame) }
        return right + left
    }

    /// Deckhouse between two heights above the keel: plated walls with portholes, roof and edge plate; or a
    /// plain steel platform.
    @discardableResult
    static func deckhouse(_ parent: SCNNode, _ profile: [(Double, Double)], _ h0: Double, _ h1: Double, _ paint: Paint,
                          platform: Bool = false, name: String? = nil) -> SCNNode {
        houses.append(House(name: name ?? "", outline: outline(profile), h0: h0, h1: h1, platform: platform))
        let n: SCNNode
        if platform {
            n = node(prism(outline(profile), y0: h0 - draught, y1: h1 - draught, bottom: true), [paint.dark], name: name)
        } else {
            n = node(house(outline(profile), y0: h0 - draught, y1: h1 - draught, tile: SIMD2(7.2, 2.6)),
                     [paint.wall, paint.roof, paint.light], name: name)
        }
        parent.addChildNode(n)
        return n
    }

    /// Solid between closed rings of points (bottom to top), capped at the top.
    static func stack(_ rings: [[V3]], slot: Int = 0, capTop: Bool = true) -> Mesh {
        var m = Mesh(slots: slot + 1)
        let n = rings[0].count
        var ids: [[UInt32]] = []
        for r in rings { ids.append(r.map { m.vertex($0) }) }
        for r in 0..<(rings.count - 1) { for i in 0..<n {
            let j = (i + 1) % n
            m.quad(slot, ids[r][i], ids[r][j], ids[r + 1][j], ids[r + 1][i])
        } }
        m.smoothNormals()
        if capTop { m.polygon(slot, rings[rings.count - 1]) }
        return m
    }

    /// Horizontal ellipse ring (counter-clockwise from above) centred on a frame, at a height above the keel.
    static func ring(_ frame: Double, _ h: Double, _ halfX: Double, _ halfZ: Double, segments: Int = 28,
                     slope: Double = 0, offset: Double = 0) -> [V3] {
        ellipse(halfX, halfZ, segments: segments).map { q in
            V3(q.x + offset, h - draught + slope * q.y, q.y + frame - midFrame)
        }
    }

    // MARK: - Aft

    static func afterSuperstructure(_ paint: Paint) -> SCNNode {
        let a = SCNNode()
        a.name = "afterSuperstructure"
        deckhouse(a, [(72.7, 6.8), (73.6, 8.2), (80.0, 10.5), (86.0, 11.8), (109.8, 11.8)], 14.9, 18.0, paint, name: "aftL1")
        deckhouse(a, [(75.0, 5.5), (76.5, 7.5), (98.0, 7.5)], 18.0, 20.6, paint, name: "aftL2")
        deckhouse(a, [(77.9, 4.2), (80.9, 4.6)], 20.6, 22.6, paint, name: "aftL3")
        deckhouse(a, [(87.4, 4.4), (98.2, 5.2)], 20.6, 23.0, paint, name: "aftBoatDeckBase")
        // aft command post (frames 80.9–87.4) with its 10.5 m rangefinder hood, FuMO 23 radar and pole mast
        deckhouse(a, [(80.9, 3.0), (81.8, 3.6), (86.6, 3.6), (87.4, 3.0)], 22.6, 25.4, paint, name: "aftCommandPost")
        deckhouse(a, [(87.4, 3.0), (88.5, 3.0)], 22.6, 24.5, paint, name: "aftCommandPostWing")
        rangefinderDome(a, paint, frame: 84.8, base: 25.4, radius: 2.4, height: 3.0, arms: 5.25, radar: true, facing: -1)
        rod(a, p(85.4, 28.2), p(85.4, 35.8), 0.2, 0.08, paint.light)
        // searchlight towers on the centreline (frames 75.0 and 95.6)
        searchlightTower(a, paint, frame: 75.0, base: 20.6, top: 22.4, lobes: false)
        searchlightTower(a, paint, frame: 95.9, base: 23.0, top: 27.2, lobes: true)
        // aircraft hangar under the boat deck, mainmast rising from its roof
        deckhouse(a, [(98.2, 5.9), (107.4, 5.9)], 18.0, 23.3, paint, name: "hangar")
        for side in [-1.0, 1.0] { box(a, V3(0.08, 3.6, 6.4), p(102.8, 20.2, side * 5.93), paint.dark) }
        mast(a, paint, frame: 102.2, from: 23.3, to: 50.1, nest: (39.4, 41.3), yard: 45.6)
        // war ensign at the gaff peak, as flown at sea
        a.addChildNode(ensign(paint))
        // boats on the boat deck
        for side in [-1.0, 1.0] {
            boat(a, paint, from: 95.8, to: 107.8, offset: side * 7.5, keel: 23.3, beam: 2.7)
            boat(a, paint, from: 99.6, to: 109.5, offset: side * 3.9, keel: 24.3, beam: 2.3)
        }
        // athwartships double catapult between hangar and funnel
        let catapult = SCNNode()
        catapult.name = "catapult"
        a.addChildNode(catapult)
        // lattice girder 35 m long: two top and two bottom chords, verticals and diagonals, launching rails
        var truss = Mesh(slots: 2)
        let length = 35.0, halfLength = length / 2, bays = 22
        let chords: [(Double, Double)] = [(16.6, -0.7), (16.6, 0.7), (17.6, -0.55), (17.6, 0.55)]
        for (h, dz) in chords { truss.beam(0, p(112.2 + dz, h, -halfLength), p(112.2 + dz, h, halfLength), width: 0.16) }
        for k in 0...bays {
            let x = -halfLength + length * Double(k) / Double(bays)
            for dz in [-0.62, 0.62] {
                truss.beam(0, p(112.2 + dz, 16.6, x), p(112.2 + dz, 17.6, x), width: 0.09)
                if k < bays {
                    let x1 = -halfLength + length * Double(k + 1) / Double(bays)
                    truss.beam(0, p(112.2 + dz, 16.6, k % 2 == 0 ? x : x1), p(112.2 + dz, 17.6, k % 2 == 0 ? x1 : x), width: 0.07)
                }
            }
            truss.beam(0, p(112.2 - 0.6, 17.6, x), p(112.2 + 0.6, 17.6, x), width: 0.07)
        }
        for dz in [-0.35, 0.35] { truss.beam(1, p(112.2 + dz, 17.7, -halfLength), p(112.2 + dz, 17.7, halfLength), width: 0.12, height: 0.1) }
        truss.box(1, p(112.2, 17.95, 3.0), V3(2.2, 0.35, 1.6))
        for x in [-8.0, 0.0, 8.0] { truss.cylinder(0, p(112.2, 14.95, x), p(112.2, 16.6, x), 0.6, 0.45, segments: 16) }
        catapult.addChildNode(node(truss, [paint.light, paint.dark], name: "catapultGirder"))
        return a
    }

    static func searchlightTower(_ parent: SCNNode, _ paint: Paint, frame: Double, base: Double, top: Double, lobes: Bool) {
        obstacles.append((SIMD2(0, frame - midFrame), SIMD2(1.7, 1.7), base, top))
        let t = SCNCylinder(radius: 1.7, height: CGFloat(top - base)); t.radialSegmentCount = 24
        add(parent, t, paint.light, p(frame, (base + top) / 2))
        let deck = SCNCylinder(radius: 2.0, height: 0.25); deck.radialSegmentCount = 28
        add(parent, deck, paint.dark, p(frame, top + 0.12))
        if lobes { for side in [-1.0, 1.0] {
            let lobe = SCNCylinder(radius: 1.7, height: 0.25); lobe.radialSegmentCount = 20
            add(parent, lobe, paint.dark, p(frame, top - 0.1, side * 4.5))
            rod(parent, p(frame, base, side * 4.5), p(frame, top - 0.2, side * 4.5), 0.25, nil, paint.light)
            // open SL-8 anti-aircraft director (4 m rangefinder on a stabilised pedestal)
            var d = Mesh(slots: 2)
            let c = p(frame, top, side * 4.5)
            d.cylinder(0, c, c + V3(0, 0.9, 0), 0.45, 0.35, segments: 14)
            d.box(0, c + V3(0, 1.2, 0), V3(1.1, 0.6, 1.0))
            d.cylinder(0, c + V3(-2.0, 1.35, 0), c + V3(2.0, 1.35, 0), 0.16, segments: 12)
            for x in [-2.05, 2.05] { d.box(0, c + V3(x, 1.35, 0), V3(0.28, 0.4, 0.4)) }
            d.box(1, c + V3(0, 1.25, 0.51), V3(0.5, 0.2, 0.03))
            parent.addChildNode(node(d, [paint.light, paint.black], name: "sl8Open"))
        } }
        let rail = SCNTube(innerRadius: 1.93, outerRadius: 2.0, height: 1.0); rail.radialSegmentCount = 32
        add(parent, rail, paint.light, p(frame, top + 0.75))
        searchlight(parent, paint, p(frame, top + 0.25), facing: 0)
    }

    /// 150 cm searchlight on its pedestal, with a shutter-grey barrel.
    static func searchlight(_ parent: SCNNode, _ paint: Paint, _ at: V3, facing: Double) {
        let s = SCNNode()
        s.simdPosition = SIMD3<Float>(at)
        s.simdOrientation = simd_quatf(angle: Float(facing), axis: SIMD3<Float>(0, 1, 0))
        parent.addChildNode(s)
        rod(s, V3(0, 0, 0), V3(0, 0.9, 0), 0.25, nil, paint.dark)
        rod(s, V3(0, 1.35, -0.7), V3(0, 1.35, 0.6), 0.85, 0.85, paint.light, segments: 20)
        rod(s, V3(0, 1.35, 0.6), V3(0, 1.35, 0.66), 0.78, nil, paint.glass, segments: 20)
    }

    /// Rotating rangefinder hood: drum, domed top, arms of the stereoscopic base, optional FuMO 23 mattress.
    static func rangefinderDome(_ parent: SCNNode, _ paint: Paint, frame: Double, base: Double, radius: Double, height: Double,
                                arms: Double, radar: Bool, facing: Double) {
        obstacles.append((SIMD2(0, frame - midFrame), SIMD2(radius + 0.4, radius + 0.4), base, base + height))
        let d = SCNNode()
        d.simdPosition = SIMD3<Float>(p(frame, base))
        if facing < 0 { d.simdOrientation = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0)) }
        parent.addChildNode(d)
        let drum = SCNCylinder(radius: CGFloat(radius), height: CGFloat(height * 0.7)); drum.radialSegmentCount = 32
        add(d, drum, paint.light, V3(0, height * 0.35, 0))
        let cap = SCNSphere(radius: CGFloat(radius)); cap.segmentCount = 32
        add(d, cap, paint.light, V3(0, height * 0.7, 0)).scale = SCNVector3(1, Float(height * 0.3 / radius), 1)
        rod(d, V3(-arms, height * 0.42, 0), V3(arms, height * 0.42, 0), 0.42, nil, paint.light, segments: 16)
        for x in [-arms, arms] { box(d, V3(0.6, 1.0, 1.1), V3(x, height * 0.42, 0), paint.light, chamfer: 0.15) }
        if radar {
            // FuMO 23: 2 × 4 m mattress antenna on the front of the hood
            box(d, V3(4.0, 2.0, 0.25), V3(0, height * 0.55, radius + 0.35), paint.dark)
            for x in stride(from: -1.8, through: 1.8, by: 0.45) {
                box(d, V3(0.05, 1.9, 0.3), V3(x, height * 0.55, radius + 0.45), paint.light)
            }
        }
    }

    static func mast(_ parent: SCNNode, _ paint: Paint, frame: Double, from: Double, to: Double, nest: (Double, Double)?, yard: Double) {
        rod(parent, p(frame, from), p(frame, to), 0.45, 0.14, paint.light, segments: 16)
        if let nest { box(parent, V3(1.9, nest.1 - nest.0, 1.7), p(frame, (nest.0 + nest.1) / 2), paint.light, chamfer: 0.1) }
        rod(parent, p(frame, yard, -3.6), p(frame, yard, 3.6), 0.09, nil, paint.light)
        rod(parent, p(frame, to - 0.8), p(frame - 3.2, to - 0.3), 0.07, nil, paint.light)
        rod(parent, p(frame, to - 0.2), p(frame + 2.2, to - 9.5), 0.03, nil, paint.rope)
    }

    /// Ship's boat on its cradles: grey hull with a varnished capping. Motor boats (beam 2.5 m and more) have a
    /// cabin with windows and a canvas roof, a windscreen and an exhaust; the others a canvas cover.
    static func boat(_ parent: SCNNode, _ paint: Paint, from: Double, to: Double, offset: Double, keel: Double, beam: Double) {
        let length = to - from, depth = beam * 0.55
        let stations = (0...12).map { Double($0) / 12 }
        func half(_ u: Double) -> Double {
            let fore = u > 0.7 ? 1 - pow((u - 0.7) / 0.3, 1.6) : 1.0
            let aft = u < 0.12 ? 0.82 + 0.18 * u / 0.12 : 1.0
            return max(0.02, beam / 2 * fore * aft)
        }
        let sections = stations.map { u -> (z: Double, points: [SIMD2<Double>]) in
            let fore = u > 0.7 ? 1 - pow((u - 0.7) / 0.3, 1.6) : 1.0
            let w = half(u)
            let pts = (0...8).map { k -> SIMD2<Double> in
                let t = Double.pi * Double(k) / 8
                return SIMD2(w * cos(t) * -1, -depth * sin(t) * (0.6 + 0.4 * fore))
            }
            let z = from + u * length - midFrame
            return (z, pts.map { SIMD2($0.x + offset, $0.y + keel + depth - draught) })
        }
        parent.addChildNode(node(loftZ(sections, smooth: true), [paint.boatHull], name: "boat"))
        var m = Mesh(slots: 4)   // 0 varnished wood, 1 grey, 2 canvas, 3 dark
        let top = keel + depth - draught
        // varnished capping along the gunwales and a planked deck
        for side in [-1.0, 1.0] {
            var previous: V3? = nil
            for u in stride(from: 0.0, through: 1.0, by: 1.0 / 12) {
                let q = V3(offset + side * (half(u) - 0.05), top + 0.04, from + u * length - midFrame)
                if let a = previous { m.beam(0, a, q, width: 0.12, height: 0.08) }
                previous = q
            }
        }
        m.box(0, V3(offset, top + 0.01, from + length * 0.47 - midFrame), V3(beam * 0.84, 0.04, length * 0.84))
        let mid = from + length * 0.45
        if beam >= 2.5 {
            // cabin: grey walls with a window row, canvas roof, windscreen ahead of the helm, exhaust
            let cabinLength = length * 0.36, cabinWidth = beam * 0.62
            let c = V3(offset, top + 0.55, mid - midFrame)
            m.box(1, c, V3(cabinWidth, 1.1, cabinLength))
            for side in [-1.0, 1.0] {
                var z = -cabinLength / 2 + 0.45
                while z < cabinLength / 2 - 0.3 {
                    m.box(3, c + V3(side * (cabinWidth / 2 + 0.01), 0.18, z), V3(0.03, 0.34, 0.5))
                    z += 0.75
                }
            }
            m.box(2, c + V3(0, 0.62, 0), V3(cabinWidth + 0.12, 0.14, cabinLength + 0.2))
            m.box(1, V3(offset, top + 0.45, mid + length * 0.26 - midFrame), V3(cabinWidth * 0.9, 0.9, 0.08))
            m.box(3, V3(offset, top + 0.62, mid + length * 0.26 + 0.05 - midFrame), V3(cabinWidth * 0.8, 0.35, 0.03))
            m.cylinder(3, V3(offset - beam * 0.2, top, mid - length * 0.3 - midFrame),
                       V3(offset - beam * 0.2, top + 1.2, mid - length * 0.3 - midFrame), 0.1, segments: 10)
        } else {
            // canvas cover over the open boat, on a ridge
            m.box(2, V3(offset, top + 0.3, mid - midFrame), V3(beam * 0.78, 0.5, length * 0.72))
            m.box(2, V3(offset, top + 0.6, mid - midFrame), V3(0.3, 0.12, length * 0.72))
        }
        parent.addChildNode(node(m, [paint.boat, paint.light, paint.canvas, paint.black], name: "boatFittings"))
        for f in [from + length * 0.25, from + length * 0.75] {
            box(parent, V3(beam * 0.9, 0.5, 0.3), p(f, keel - 0.2, offset), paint.dark)
        }
    }

    // MARK: - Funnel

    static func funnel(_ paint: Paint) -> SCNNode {
        let f = SCNNode()
        f.name = "funnel"
        let centre = 121.7
        // cap: top curved, highest 2.5 m forward of the middle, rounded down at both ends (rear 31.8 m, front 30.9 m)
        func top(_ z: Double) -> Double {
            z > 2.5 ? 34.7 - 3.8 * pow((z - 2.5) / 3.9, 2) : 34.7 - 3.0 * pow((2.5 - z) / 9.1, 2)
        }
        func curved(_ inset: Double, _ drop: Double, _ halfX: Double, _ halfZ: Double) -> [V3] {
            ellipse(halfX, halfZ, segments: 32).map { q in V3(q.x, top(q.y * (6.4 / halfZ)) - drop - inset - draught, q.y + centre - midFrame) }
        }
        // oval casing from the superstructure deck up to the cap, which flares slightly under a sooty rim
        let casing = [(19.7, 3.5, 6.6), (24.0, 3.4, 6.5), (28.0, 3.3, 6.4)].map { h, x, z in ring(centre, h, x, z, segments: 32) }
            + [curved(0, 1.5, 3.17, 6.27)]
        f.addChildNode(node(stack(casing, capTop: false), [paint.light], name: "funnelCasing"))
        f.addChildNode(node(stack([curved(0, 1.5, 3.17, 6.27), curved(0, 0.9, 3.2, 6.3), curved(0, 0.2, 3.28, 6.38)], capTop: false),
                            [paint.funnelCap], name: "funnelCapBand"))
        f.addChildNode(node(stack([curved(0, 0.2, 3.28, 6.38), curved(0, 0, 3.3, 6.4)], capTop: false), [paint.dark], name: "funnelRim"))
        // hood closing over the uptakes, rounded down at the front, with an oval exhaust opening on its highest
        // part (2.2 × 3.8 m half axes, centre 1.4 m aft of the funnel's) under a grating
        func hood(_ t: Double, sink: Double = 0) -> [V3] {
            ellipse(1, 1, segments: 32).map { q in
                let x = q.x * (3.3 - 1.1 * t), z = q.y * (6.4 - 2.6 * t) - 1.4 * t
                return V3(x, top(z) + 0.12 * t - sink - draught, z + centre - midFrame)
            }
        }
        // the cap is painted a lighter grey than the casing (plan)
        f.addChildNode(node(stack([0.0, 0.3, 0.65, 1.0].map { hood($0) }, capTop: false), [paint.funnelCap], name: "funnelHood"))
        f.addChildNode(node(stack([hood(1), hood(1, sink: 0.4)], capTop: true), [paint.black], name: "funnelMouth"))
        for z in stride(from: -4.4, through: 1.6, by: 1.0) {
            let w = 2.2 * (1 - pow((z + 1.4) / 3.8, 2)).squareRoot()
            box(f, V3(2 * w, 0.06, 0.08), V3(0, top(z) + 0.02 - draught, z + centre - midFrame), paint.dark)
        }
        // steam pipes for the sirens up the front of the casing, sirens on the cap
        var pipes = Mesh(slots: 1)
        for x in [-0.9, 0.9] {
            pipes.cylinder(0, V3(x, 19.7 - draught, centre + 6.62 - midFrame), V3(x, 30.2 - draught, centre + 6.2 - midFrame), 0.12, segments: 10)
            pipes.cylinder(0, V3(x, 30.2 - draught, centre + 6.2 - midFrame), V3(x, 31.1 - draught, centre + 5.2 - midFrame), 0.12, segments: 10)
            pipes.cylinder(0, V3(x, 31.1 - draught, centre + 5.2 - midFrame), V3(x, 31.1 - draught, centre + 5.9 - midFrame), 0.2, 0.3, segments: 12)
        }
        for k in 0..<10 {
            let a = Double(k) / 10 * 2 * Double.pi
            let q = SIMD2(4.1 * cos(a), 5.6 * sin(a) + centre - midFrame)
            pipes.beam(0, V3(q.x * 0.84, 24.8 - draught, q.y * 0.84 + (centre - midFrame) * 0.16), V3(q.x, 26.9 - draught, q.y), width: 0.14)
        }
        f.addChildNode(node(pipes, [paint.light], name: "funnelPipes"))
        // two small cranes under the searchlight platform, jibs stowed
        var cranes = Mesh(slots: 1)
        for side in [-1.0, 1.0] {
            let foot = V3(side * 4.7, 19.7 - draught, 117.6 - midFrame)
            cranes.cylinder(0, foot, foot + V3(0, 5.2, 0), 0.32, 0.26, segments: 12)
            cranes.box(0, foot + V3(0, 4.2, 0), V3(0.8, 0.9, 0.9))
            cranes.beam(0, foot + V3(0, 4.3, 0.3), foot + V3(side * 0.3, 6.6, 4.6), width: 0.28, height: 0.36)
            cranes.cylinder(0, foot + V3(side * 0.3, 6.5, 4.6), foot + V3(side * 0.3, 3.4, 4.6), 0.025, segments: 6)
        }
        f.addChildNode(node(cranes, [paint.light], name: "funnelCranes"))
        // searchlight platform around the funnel, four 150 cm searchlights
        houses.append(House(name: "funnelPlatform", outline: ellipse(5.6, 6.8, segments: 40).map { SIMD2($0.x, $0.y + centre - midFrame) },
                            h0: 26.9, h1: 27.2, platform: true))
        obstacles.append((SIMD2(0, centre - midFrame), SIMD2(3.5, 6.6), 19.7, 34.7))
        let platform = node(prism(ellipse(5.6, 6.8, segments: 40), y0: 26.9 - draught, y1: 27.2 - draught, bottom: true), [paint.dark])
        platform.simdPosition = SIMD3<Float>(0, 0, Float(centre - midFrame))
        f.addChildNode(platform)
        for (fr, side) in [(119.4, -1.0), (119.4, 1.0), (124.4, -1.0), (124.4, 1.0)] {
            searchlight(f, paint, p(fr, 27.2, side * 4.9), facing: fr < 122 ? .pi : 0)
        }
        return f
    }

    // MARK: - Forward

    static func forwardSuperstructure(_ paint: Paint) -> SCNNode {
        let s = SCNNode()
        s.name = "forwardSuperstructure"
        // base deckhouse carrying the forward 10.5 cm mounts; narrow abreast the forward 15 cm turrets,
        // which stand on the upper deck (plan profile: 19.3–19.7 m)
        deckhouse(s, [(115.5, 11.8), (130.0, 12.3), (144.5, 12.3), (147.0, 7.4), (162.0, 7.2), (166.1, 5.8), (167.3, 4.6)],
                  14.9, 19.7, paint, name: "fwdL1")
        // upper tiers: 24.0 m forward, 25.6 m aft of frame 153.7, then 26.8 and 27.6 m (plan profile)
        deckhouse(s, [(126.5, 7.6), (163.6, 7.0), (165.6, 5.2)], 19.7, 24.0, paint, name: "fwdL2")
        deckhouse(s, [(128.5, 6.6), (153.7, 6.2)], 24.0, 25.6, paint, name: "fwdL3")
        deckhouse(s, [(147.5, 4.6), (159.1, 4.2)], 24.0, 26.8, paint, name: "fwdL4")
        deckhouse(s, [(150.4, 3.0), (156.6, 2.8)], 26.8, 28.2, paint, name: "fwdL5")
        // SL-8 stabilised directors beside the tower (dark spherical hoods, 3.8 m)
        for side in [-1.0, 1.0] {
            let deck = SCNCylinder(radius: 2.6, height: 0.3); deck.radialSegmentCount = 28
            add(s, deck, paint.dark, p(138.8, 25.05, side * 6.6))
            rod(s, p(138.8, 25.2, side * 6.6), p(138.8, 26.0, side * 6.6), 0.9, nil, paint.light)
            let dome = SCNSphere(radius: 1.9); dome.segmentCount = 32
            add(s, dome, paint.dark, p(138.8, 27.15, side * 6.6))
            rod(s, p(138.8, 27.3, side * 6.6 - 2.1), p(138.8, 27.3, side * 6.6 + 2.1), 0.22, nil, paint.dark)
        }
        // navigating bridge (top 29.2 m) and the armoured forward command post (frames 147.4–151.0) with its
        // rangefinder hood and FuMO 23 radar (31.25 m)
        deckhouse(s, [(137.5, 5.6), (147.0, 5.6), (148.2, 4.6)], 25.6, 29.2, paint, name: "bridge")
        let post = node(stack([ring(149.5, 25.0, 2.6, 2.2, segments: 24), ring(149.5, 29.2, 2.6, 2.2, segments: 24)]), [paint.light],
                        name: "forwardCommandPost")
        s.addChildNode(post)
        box(s, V3(3.6, 2.2, 4.6), p(149.7, 30.3), paint.light, chamfer: 0.35)
        rod(s, p(149.2, 30.4, -5.25), p(149.2, 30.4, 5.25), 0.4, nil, paint.light, segments: 16)
        for side in [-1.0, 1.0] { box(s, V3(0.6, 1.0, 1.1), p(149.2, 30.4, side * 5.25), paint.light, chamfer: 0.15) }
        box(s, V3(3.6, 1.9, 0.25), p(152.15, 30.4), paint.dark)
        for x in stride(from: -1.6, through: 1.6, by: 0.4) { box(s, V3(0.05, 1.8, 0.3), p(152.25, 30.4, x), paint.light) }
        // tower mast: oval armoured tower with the searchlight platform, admiral's bridge and the foretop
        let tower = [ring(138.0, 29.0, 2.4, 3.1), ring(138.0, 34.0, 2.3, 3.0), ring(138.0, 38.3, 2.1, 2.7)]
        s.addChildNode(node(stack(tower), [paint.light], name: "tower"))
        houses.append(House(name: "searchlightDeck", outline: ellipse(7.2, 4.4, segments: 36).map { SIMD2($0.x, $0.y + 136.6 - midFrame) },
                            h0: 27.3, h1: 27.55, platform: true))
        obstacles.append((SIMD2(0, 138.0 - midFrame), SIMD2(2.4, 3.1), 29.0, 38.3))
        obstacles.append((SIMD2(0, 149.5 - midFrame), SIMD2(2.6, 2.2), 25.0, 31.4))
        let searchDeck = node(prism(ellipse(7.2, 4.4, segments: 36), y0: 27.3 - draught, y1: 27.55 - draught, bottom: true), [paint.dark])
        searchDeck.simdPosition = SIMD3<Float>(0, 0, Float(136.6 - midFrame))
        s.addChildNode(searchDeck)
        // the foremast's 150 cm searchlight, abaft the tower on its platform
        searchlight(s, paint, p(133.0, 27.55), facing: .pi)
        deckhouse(s, [(134.4, 3.2), (135.4, 3.7), (141.4, 3.7), (142.4, 3.1)], 30.8, 33.3, paint, name: "admiralBridge")
        // 3 m night rangefinders on pedestals either side of the admiral's bridge
        for side in [-1.0, 1.0] {
            var r = Mesh(slots: 2)
            let c = p(139.6, 33.3, side * 3.0)
            r.cylinder(0, c, c + V3(0, 0.8, 0), 0.22, segments: 10)
            r.box(0, c + V3(0, 1.0, 0), V3(0.6, 0.4, 0.6))
            r.cylinder(0, c + V3(-1.5, 1.05, 0), c + V3(1.5, 1.05, 0), 0.13, segments: 10)
            for x in [-1.5, 1.5] { r.box(0, c + V3(x, 1.05, 0), V3(0.24, 0.32, 0.34)) }
            r.box(1, c + V3(0, 1.05, 0.31), V3(0.3, 0.14, 0.02))
            s.addChildNode(node(r, [paint.light, paint.black], name: "nightRangefinder"))
        }
        deckhouse(s, [(134.0, 3.8), (141.5, 4.4)], 35.4, 35.7, paint, platform: true, name: "towerPlatform")
        // forward platform of the foretop (frames 141–146.5) with a searchlight reaching 39 m
        deckhouse(s, [(141.0, 3.4), (146.5, 2.6), (147.9, 2.2)], 34.9, 35.3, paint, platform: true, name: "foretopForward")
        deckhouse(s, [(145.8, 1.6), (146.5, 1.5)], 35.3, 37.5, paint, name: "foretopDirectorFront")
        deckhouse(s, [(143.2, 1.6), (145.8, 1.4)], 35.3, 38.4, paint, name: "foretopDirector")
        let sight = SCNCylinder(radius: 0.9, height: 0.8); sight.radialSegmentCount = 20
        add(s, sight, paint.light, p(144.5, 38.8))
        deckhouse(s, [(131.5, 3.5), (132.5, 4.2), (141.7, 4.2), (142.7, 3.4)], 38.3, 39.9, paint, name: "foretop")
        rod(s, p(137.7, 39.9), p(137.7, 40.4), 1.2, nil, paint.light)
        rangefinderDome(s, paint, frame: 137.7, base: 40.3, radius: 1.75, height: 3.2, arms: 5.25, radar: true, facing: 1)
        deckhouse(s, [(129.8, 2.2), (131.6, 2.6)], 36.6, 37.7, paint, name: "foretopAft")
        // foremast pole behind the foretop
        rod(s, p(131.3, 38.3), p(131.3, 48.2), 0.26, 0.1, paint.light)
        rod(s, p(131.3, 46.0, -3.0), p(131.3, 46.0, 3.0), 0.07, nil, paint.light)
        // cranes beside the funnel, jibs stowed forward at about 40°
        for side in [-1.0, 1.0] {
            let base = p(119.3, 19.7, side * 9.4)
            var crane = Mesh(slots: 3)
            crane.cylinder(0, base, base + V3(0, 2.2, 0), 1.2, 1.0, segments: 20)
            crane.box(0, base + V3(0, 3.5, -0.4), V3(2.4, 2.6, 3.0))
            crane.box(0, base + V3(0, 4.85, -0.4), V3(2.6, 0.1, 3.2))
            for k in 0..<3 { crane.box(1, base + V3(side * 1.21, 3.9, -1.3 + Double(k) * 0.8), V3(0.03, 0.55, 0.6)) }
            crane.box(1, base + V3(0, 3.9, 1.11), V3(1.6, 0.6, 0.03))
            // tapering box-girder jib and its hoist rope with the hook block
            let foot = base + V3(0, 3.2, 0.8), head = p(134.5, 32.8, side * 9.4)
            let (u, v, w) = Mesh.frame(along: head - foot)
            let span = simd_length(head - foot)
            for k in 0..<6 {
                let a = foot + w * (span * Double(k) / 6), b = foot + w * (span * Double(k + 1) / 6)
                let s0 = 1.0 - 0.55 * Double(k) / 6, s1 = 1.0 - 0.55 * Double(k + 1) / 6
                crane.frameBox(0, (a + b) / 2, u * (0.5 * (s0 + s1) / 2), v * (0.75 * (s0 + s1) / 2), w * (span / 12 + 0.01))
            }
            crane.cylinder(2, head - V3(0, 0.4, 0), head - V3(0, 6.5, 0), 0.03, segments: 6)
            crane.box(1, head - V3(0, 6.8, 0), V3(0.4, 0.6, 0.3))
            s.addChildNode(node(crane, [paint.light, paint.black, paint.rope], name: "crane"))
        }
        // motor pinnaces and cutters on the superstructure deck abreast the funnel
        for side in [-1.0, 1.0] {
            boat(s, paint, from: 124.6, to: 134.0, offset: side * 8.6, keel: 20.2, beam: 3.0)
            boat(s, paint, from: 125.3, to: 132.7, offset: side * 6.3, keel: 20.2, beam: 2.0)
        }
        return s
    }
}
