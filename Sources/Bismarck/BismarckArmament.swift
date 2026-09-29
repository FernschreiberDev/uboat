import AppKit
import SceneKit
import simd

extension Bismarck {
    /// Guns at rest, trained fore and aft as on the plan of 24 May 1941.
    static func armament(_ paint: Paint) -> SCNNode {
        let guns = SCNNode()
        guns.name = "armament"
        // 38 cm twin turrets: frame, deck and roof heights above the keel (plan), facing, rangefinder.
        let main: [(name: String, frame: Double, deck: Double, roof: Double, forward: Bool, rangefinder: Bool)] = [
            ("Anton", 192.55, 15.75, 20.30, true, false), ("Bruno", 174.35, 15.37, 23.85, true, true),
            ("Caesar", 64.35, 15.03, 23.73, false, true), ("Dora", 46.15, 15.20, 19.93, false, true),
        ]
        for t in main {
            let turret = heavyTurret(paint, deck: t.deck, roof: t.roof, rangefinder: t.rangefinder)
            turret.name = t.name
            turret.simdPosition = SIMD3<Float>(p(t.frame, 0))
            if !t.forward { turret.simdOrientation = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0)) }
            guns.addChildNode(turret)
        }
        // 15 cm twin turrets (plan): frame, offset, deck, forward-facing.
        let secondary: [(Double, Double, Double, Bool)] = [(99.6, 14.4, 15.0, false), (131.2, 15.2, 15.0, true), (150.6, 10.0, 15.2, true)]
        for (f, s, deck, forward) in secondary { for side in [-1.0, 1.0] {
            let t = secondaryTurret(paint, rangefinder: abs(f - 131.2) < 0.1)
            t.simdPosition = SIMD3<Float>(p(f, deck, side * s))
            t.simdOrientation = simd_quatf(angle: forward ? 0 : .pi, axis: SIMD3<Float>(0, 1, 0))
            guns.addChildNode(t)
        } }
        // 10.5 cm twin mounts on the superstructure deck; the after two groups face aft.
        let heavyFlak: [(Double, Double, Bool)] = [(90.8, 9.7, false), (106.6, 10.4, false), (123.6, 11.0, true), (141.1, 10.8, true)]
        for (f, s, forward) in heavyFlak { for side in [-1.0, 1.0] {
            let m = flak105(paint, model37: f < 115)
            m.simdPosition = SIMD3<Float>(p(f, f > 115 ? 19.7 : 18.0, side * s))
            m.simdOrientation = simd_quatf(angle: forward ? 0 : .pi, axis: SIMD3<Float>(0, 1, 0))
            guns.addChildNode(m)
        } }
        // 3.7 cm twins and 2 cm singles (plan positions; heights of the decks they stand on).
        let twins37: [(Double, Double, Double)] = [(73.6, 7.3, 18.0), (85.3, 6.6, 20.6), (95.6, 4.5, 23.0), (142.2, 4.4, 29.2)]
        for (f, s, h) in twins37 { for side in [-1.0, 1.0] {
            let m = flak37(paint)
            m.simdPosition = SIMD3<Float>(p(f, h, side * s))
            m.simdOrientation = simd_quatf(angle: f < 120 ? .pi : 0, axis: SIMD3<Float>(0, 1, 0))
            guns.addChildNode(m)
        } }
        let singles20: [(Double, Double, Double)] = [(48.8, 9.0, Lines.deckHeight(48.8)), (78.4, 7.0, 18.0), (118.0, 8.2, 27.2),
                                                     (144.6, 7.4, 25.6), (160.0, 6.0, 24.0), (156.0, 6.4, 24.0)]
        for (f, s, h) in singles20 { for side in [-1.0, 1.0] {
            let m = flak20(paint)
            m.simdPosition = SIMD3<Float>(p(f, h, side * s))
            m.simdOrientation = simd_quatf(angle: Float(side * 1.2), axis: SIMD3<Float>(0, 1, 0))
            guns.addChildNode(m)
        } }
        // Two quadruple 2 cm mounts on the searchlight platform beside the tower.
        for side in [-1.0, 1.0] {
            let m = vierling(paint)
            m.simdPosition = SIMD3<Float>(p(135.6, 27.5, side * 6.3))
            m.simdOrientation = simd_quatf(angle: Float(side * 0.9), axis: SIMD3<Float>(0, 1, 0))
            guns.addChildNode(m)
        }
        return guns
    }

    /// 38 cm Drh LC/34 twin turret: housing 14.0 × 10.1 × 3.1 m with its upper side, rear and face plates
    /// sloped (lower and upper armour plates), on a barbette of 8.8 m; guns 3.75 m apart, canvas blast bags,
    /// muzzles 19.8 m from the axis. Rangefinder hoods proud of the sides at the rear (Bruno, Caesar, Dora;
    /// Anton's was removed in the winter of 1940–41). Local frame: origin on the rotation axis at keel height
    /// (local y = height above the keel), +z towards the muzzles.
    static func heavyTurret(_ paint: Paint, deck: Double, roof: Double, rangefinder: Bool) -> SCNNode {
        let t = SCNNode()
        let base = roof - 3.1, rear = -7.0, front = 7.0, knuckle = 1.95, inset = 0.55
        func halfWidth(_ z: Double) -> Double {
            if z < -6.4 { let u = (-6.4 - z) / 0.6; return 4.45 + 0.6 * sqrt(max(0, 1 - u * u)) }
            if z > 3.9 { return 5.05 - (z - 3.9) / (front - 3.9) * 1.3 }
            return 5.05
        }
        // roof from z -6.4 to 4.3; upper rear plate down to the knuckle, upper face down to 1.0 m at the front
        func height(_ z: Double) -> Double {
            if z < -6.4 { return knuckle + (3.1 - knuckle) * (z - rear) / 0.6 }
            return z <= 4.3 ? 3.1 : 3.1 - (z - 4.3) / (front - 4.3) * 2.1
        }
        let stations: [Double] = [rear, -6.85, -6.6, -6.4, 3.9, 4.3, front]
        let sections = stations.map { z -> (z: Double, points: [SIMD2<Double>]) in
            let w = halfWidth(z), h = height(z), k = min(knuckle, h - 0.05)
            let c = inset * (h - k) / (3.1 - knuckle)
            return (z, [SIMD2(-w, 0), SIMD2(w, 0), SIMD2(w, k), SIMD2(w - c, h), SIMD2(-w + c, h), SIMD2(-w, k)]
                .map { SIMD2($0.x, $0.y + base) })
        }
        t.addChildNode(node(loftZ(sections), [paint.light], name: "housing"))
        let barbetteHeight = base - deck + 0.2
        let barbette = SCNCylinder(radius: 4.4, height: CGFloat(barbetteHeight)); barbette.radialSegmentCount = 48
        add(t, barbette, paint.light, V3(0, deck + barbetteHeight / 2 - 0.2, -0.6))

        var m = Mesh(slots: 4)   // 0 light, 1 dark, 2 gun metal, 3 canvas
        for x in [-1.875, 1.875] {
            let y = base + 1.25, port = 6.55, muzzle = 19.8
            m.cylinder(3, V3(x, y, port), V3(x, y, 8.6), 0.8, 0.5, segments: 16)
            for k in 0..<3 { let z = 6.9 + Double(k) * 0.55; m.cylinder(3, V3(x, y, z), V3(x, y, z + 0.08), 0.72 - Double(k) * 0.07, segments: 16) }
            m.cylinder(2, V3(x, y, 8.4), V3(x, y, muzzle - 3.4), 0.46, 0.36, segments: 16)
            m.cylinder(2, V3(x, y, muzzle - 3.4), V3(x, y, muzzle - 0.35), 0.33, 0.31, segments: 16)
            m.cylinder(2, V3(x, y, muzzle - 0.35), V3(x, y, muzzle), 0.36, segments: 16)
            m.cylinder(1, V3(x, y, muzzle - 0.02), V3(x, y, muzzle + 0.01), 0.2, segments: 16)
        }
        // periscope hoods of the gun layers (front corners) and the commander (rear)
        for x in [-3.55, 3.55] {
            m.box(0, V3(x, base + 3.35, 2.5), V3(0.95, 0.5, 1.3))
            m.box(1, V3(x, base + 3.4, 3.16), V3(0.6, 0.18, 0.04))
        }
        m.box(0, V3(0, base + 3.4, -4.3), V3(1.1, 0.6, 1.2))
        m.box(1, V3(0, base + 3.45, -3.69), V3(0.7, 0.2, 0.04))
        // roof hatch, mushroom ventilators, lifting eyes
        m.box(0, V3(2.4, base + 3.17, -5.5), V3(1.1, 0.14, 1.3))
        for x in [-1.6, 1.0] {
            m.cylinder(0, V3(x, base + 3.1, -5.2), V3(x, base + 3.55, -5.2), 0.16, segments: 10)
            m.cylinder(0, V3(x, base + 3.55, -5.2), V3(x, base + 3.7, -5.2), 0.34, 0.24, segments: 12)
        }
        for (x, z) in [(-4.2, -3.0), (4.2, -3.0), (-3.4, 3.8), (3.4, 3.8)] { m.box(0, V3(x, base + 3.16, z), V3(0.3, 0.12, 0.3)) }
        // ladder up the rear plate to the roof
        m.ladder(0, V3(-3.4, deck, rear - 0.25), V3(-3.4, base + 4.0, rear - 0.25), outward: V3(0, 0, -1))
        if rangefinder {
            // 10.5 m rangefinder across the rear of the housing: armoured end hoods proud of the upper sides
            for side in [-1.0, 1.0] {
                let x = side * 5.3, y = base + 2.3, z = -5.6
                m.box(0, V3(x, y, z), V3(1.0, 1.3, 1.8))
                m.box(0, V3(x, y + 0.72, z + 0.1), V3(0.8, 0.14, 1.4))
                m.box(1, V3(x + side * 0.12, y + 0.1, z + 0.91), V3(0.5, 0.34, 0.03))
            }
        }
        t.addChildNode(node(m, [paint.light, paint.black, paint.gun, paint.canvas], name: "turretFittings"))
        return t
    }

    /// 15 cm Drh L C/34 twin turret, 6.6 × 4.6 × 2.5 m with sloped upper sides and face; barrels 6.2 m out.
    /// The middle turrets of each side carry a 6.5 m rangefinder across the rear.
    static func secondaryTurret(_ paint: Paint, rangefinder: Bool = false) -> SCNNode {
        let t = SCNNode()
        let base = 0.9, front = 3.3, rear = -3.3
        func w(_ z: Double) -> Double { z > 1.5 ? 2.3 - (z - 1.5) / (front - 1.5) * 0.6 : 2.3 }
        func h(_ z: Double) -> Double { z > 1.2 ? 2.5 - (z - 1.2) / (front - 1.2) * 1.2 : (z < -3.0 ? 1.7 + 0.8 * (z - rear) / 0.3 : 2.5) }
        let sections = [rear, -3.0, 1.2, 1.5, front].map { z -> (z: Double, points: [SIMD2<Double>]) in
            let ww = w(z), hh = h(z), k = min(1.6, hh - 0.05), c = 0.35 * (hh - k) / 0.9
            return (z, [SIMD2(-ww, base), SIMD2(ww, base), SIMD2(ww, base + k), SIMD2(ww - c, base + hh), SIMD2(-ww + c, base + hh), SIMD2(-ww, base + k)])
        }
        t.addChildNode(node(loftZ(sections), [paint.light], name: "turret15"))
        let barbette = SCNCylinder(radius: 2.3, height: CGFloat(base)); barbette.radialSegmentCount = 32
        add(t, barbette, paint.light, V3(0, base / 2, -0.2))
        var m = Mesh(slots: 4)
        for x in [-0.8, 0.8] {
            let y = base + 1.0
            m.cylinder(3, V3(x, y, front - 0.2), V3(x, y, front + 1.1), 0.32, 0.22, segments: 12)
            m.cylinder(2, V3(x, y, front + 0.9), V3(x, y, front + 5.9), 0.17, 0.13, segments: 12)
            m.cylinder(2, V3(x, y, front + 5.9), V3(x, y, front + 6.2), 0.15, segments: 12)
            m.cylinder(1, V3(x, y, front + 6.19), V3(x, y, front + 6.21), 0.09, segments: 12)
        }
        for x in [-1.3, 1.3] { m.box(0, V3(x, base + 2.62, 0.9), V3(0.5, 0.3, 0.8)) }
        m.box(0, V3(0.9, base + 2.56, -2.2), V3(0.8, 0.12, 0.9))
        if rangefinder {
            for side in [-1.0, 1.0] {
                m.box(0, V3(side * 2.45, base + 1.95, -2.2), V3(0.6, 0.8, 1.1))
                m.box(1, V3(side * 2.5, base + 2.0, -1.64), V3(0.34, 0.24, 0.03))
            }
        }
        m.ladder(0, V3(-1.2, 0, rear - 0.2), V3(-1.2, base + 3.3, rear - 0.2), outward: V3(0, 0, -1), width: 0.4)
        t.addChildNode(node(m, [paint.light, paint.black, paint.gun, paint.canvas], name: "turret15Fittings"))
        return t
    }

    /// Open-backed gun shield: vertical plates along a U (radius r round the front, straight sides back to
    /// `back`), from y0 to y1, with a notch for the barrels in the middle of the front below `notch`.
    static func shield(_ m: inout Mesh, slot: Int, radius r: Double, centre: Double, back: Double, y0: Double, y1: Double,
                       notch: (halfWidth: Double, top: Double)?) {
        var path: [SIMD2<Double>] = [SIMD2(-r, back)]
        for k in 0...12 {
            let a = Double.pi * Double(k) / 12
            path.append(SIMD2(-r * cos(a), centre + r * sin(a)))
        }
        path.append(SIMD2(r, back))
        for i in 0..<(path.count - 1) {
            let a = path[i], b = path[i + 1], mid = (a + b) / 2
            let top = notch.map { abs(mid.x) < $0.halfWidth && mid.y > centre ? $0.top : y1 } ?? y1
            let len = simd_length(b - a), d = (b - a) / len
            let n = SIMD2(-d.y, d.x)
            m.frameBox(slot, V3(mid.x, (y0 + top) / 2, mid.y), V3(d.x, 0, d.y) * (len / 2 + 0.02), V3(0, (top - y0) / 2, 0),
                       V3(-n.x, 0, -n.y) * 0.03)
        }
    }

    /// 10.5 cm SK C/33 twin mount on its pedestal: forward mounts are the Dop. L. C/31 (short, rounded
    /// shield, breeches in the open), after mounts the Dop. L. C/37 (taller shield half covering the
    /// breeches). Barrels 68 cm apart, 6.8 m long.
    static func flak105(_ paint: Paint, model37: Bool) -> SCNNode {
        let n = SCNNode()
        var m = Mesh(slots: 3)   // 0 light, 1 gun metal, 2 dark
        m.cylinder(0, V3(0, 0, 0), V3(0, 0.9, 0), 1.05, segments: 20)
        m.cylinder(0, V3(0, 0.9, 0), V3(0, 1.05, 0), 1.7, segments: 24)
        let top = model37 ? 3.0 : 2.55
        shield(&m, slot: 0, radius: 1.55, centre: 0.2, back: -1.1, y0: 1.05, y1: top, notch: (0.72, 1.55))
        if model37 {
            // roof plate over the front of the shield, and a sighting hood each side
            m.box(0, V3(0, top + 0.03, 0.85), V3(3.0, 0.06, 1.3))
        }
        for side in [-1.0, 1.0] { m.box(0, V3(side * 1.1, top + 0.18, 0.5), V3(0.35, 0.35, 0.6)) }
        // cradle, breeches, recoil cylinders and barrels
        let y = 1.95
        m.box(2, V3(0, y - 0.1, -0.3), V3(1.2, 0.75, 2.4))
        for x in [-0.34, 0.34] {
            m.box(1, V3(x, y, -1.2), V3(0.34, 0.4, 0.9))
            m.cylinder(1, V3(x, y + 0.28, -0.6), V3(x, y + 0.28, 1.6), 0.09, segments: 10)
            m.cylinder(1, V3(x, y, -0.8), V3(x, y, 1.9), 0.14, segments: 12)
            m.cylinder(1, V3(x, y, 1.9), V3(x, y, 6.0), 0.1, 0.075, segments: 12)
            m.cylinder(1, V3(x, y, 5.95), V3(x, y, 6.1), 0.085, segments: 12)
        }
        // gun layers' seats and hand wheels
        for side in [-1.0, 1.0] {
            m.box(2, V3(side * 0.95, 1.5, -0.5), V3(0.45, 0.08, 0.45))
            m.cylinder(2, V3(side * 0.75, 1.8, -0.1), V3(side * 0.7, 1.8, -0.1), 0.22, segments: 10)
        }
        n.addChildNode(node(m, [paint.light, paint.gun, paint.dark], name: model37 ? "flak105C37" : "flak105C31"))
        return n
    }

    /// 3.7 cm SK C/30 twin on its stabilised Dopp. L C/30 mounting: pedestal, trunnion carriage, flat shield.
    static func flak37(_ paint: Paint) -> SCNNode {
        let n = SCNNode()
        var m = Mesh(slots: 3)
        m.cylinder(0, V3(0, 0, 0), V3(0, 0.75, 0), 0.55, segments: 16)
        m.cylinder(0, V3(0, 0.75, 0), V3(0, 0.85, 0), 0.95, segments: 18)
        m.box(2, V3(0, 1.05, 0), V3(0.9, 0.45, 0.9))
        for side in [-1.0, 1.0] { m.box(0, V3(side * 0.52, 1.25, 0.05), V3(0.12, 0.7, 0.7)) }
        // shield: centre plate with the barrels through it, wings angled back
        m.box(0, V3(0, 1.4, 0.62), V3(1.1, 0.95, 0.05))
        for side in [-1.0, 1.0] { m.box(0, V3(side * 0.78, 1.35, 0.5), V3(0.5, 0.8, 0.05), yaw: side * 0.45) }
        for x in [-0.21, 0.21] {
            m.box(1, V3(x, 1.28, -0.2), V3(0.14, 0.22, 1.1))
            m.cylinder(1, V3(x, 1.28, 0.3), V3(x, 1.28, 2.95), 0.05, 0.04, segments: 10)
            m.cylinder(1, V3(x, 1.28, 2.95), V3(x, 1.28, 3.25), 0.065, segments: 10)
        }
        for side in [-1.0, 1.0] { m.box(2, V3(side * 0.85, 0.95, -0.45), V3(0.4, 0.06, 0.4)) }
        n.addChildNode(node(m, [paint.light, paint.gun, paint.dark], name: "flak37"))
        return n
    }

    /// 2 cm C/30 single on its pedestal: curved shield, magazine, shoulder rests.
    static func flak20(_ paint: Paint) -> SCNNode {
        let n = SCNNode()
        var m = Mesh(slots: 3)
        m.cylinder(2, V3(0, 0, 0), V3(0, 0.95, 0), 0.12, segments: 10)
        m.cylinder(2, V3(0, 0, 0), V3(0, 0.08, 0), 0.4, segments: 12)
        m.box(2, V3(0, 1.05, 0.1), V3(0.3, 0.25, 0.6))
        shield(&m, slot: 0, radius: 0.45, centre: 0.1, back: 0.05, y0: 0.85, y1: 1.5, notch: (0.1, 1.05))
        m.cylinder(1, V3(0, 1.12, -0.35), V3(0, 1.12, 1.25), 0.035, segments: 8)
        m.cylinder(1, V3(0, 1.12, 1.15), V3(0, 1.12, 1.4), 0.055, segments: 8)
        m.box(1, V3(-0.16, 1.25, 0.05), V3(0.14, 0.3, 0.22))
        for side in [-1.0, 1.0] { m.box(2, V3(side * 0.22, 1.1, -0.45), V3(0.06, 0.18, 0.3)) }
        n.addChildNode(node(m, [paint.light, paint.gun, paint.dark], name: "flak20"))
        return n
    }

    /// 2 cm Flakvierling 38: four barrels on one carriage, angled shield, layer's seat.
    static func vierling(_ paint: Paint) -> SCNNode {
        let n = SCNNode()
        var m = Mesh(slots: 3)
        m.cylinder(0, V3(0, 0, 0), V3(0, 0.45, 0), 1.1, segments: 18)
        m.box(2, V3(0, 0.8, 0), V3(0.9, 0.6, 0.9))
        m.box(0, V3(0, 1.3, 0.72), V3(1.3, 1.0, 0.05))
        for side in [-1.0, 1.0] { m.box(0, V3(side * 0.9, 1.25, 0.55), V3(0.6, 0.9, 0.05), yaw: side * 0.5) }
        for x in [-0.36, 0.36] { for y in [0.98, 1.34] {
            m.cylinder(1, V3(x, y, -0.35), V3(x, y, 1.35), 0.035, segments: 8)
            m.cylinder(1, V3(x, y, 1.3), V3(x, y, 1.55), 0.055, segments: 8)
            m.box(1, V3(x + (x < 0 ? -0.12 : 0.12), y + 0.1, 0.0), V3(0.1, 0.25, 0.2))
        } }
        m.box(2, V3(0, 0.95, -0.7), V3(0.45, 0.06, 0.45))
        n.addChildNode(node(m, [paint.light, paint.gun, paint.dark], name: "vierling"))
        return n
    }
}
