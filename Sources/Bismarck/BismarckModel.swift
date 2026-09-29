import AppKit
import SceneKit
import simd

/// Battleship Bismarck as she sailed on Operation Rheinübung (24 May 1941, Denmark Strait).
///
/// Sources: official data from kbismarck.com (length 250.50 m overall, 241.55 m at the waterline, beam
/// 36.00 m, depth 15.00 m, block coefficient 0.55, midship 0.97, waterplane 0.66 (5,740 m²); turrets at
/// frames 192.55, 174.35, 64.35 and 46.15), measured against Manuel P. González López's 1/1000 plan
/// "Bismarck, 24 May 1941" (profile and deck plan) for the hull outline, sheer, deck outline, paint and
/// the position of every mount; hull sections below the waterline are fitted to the official coefficients.
///
/// Frame: x to starboard, y up from the loaded waterline (10.0 m draught, about 49,700 t), z towards the
/// bow — the same convention as the U-boat models. Lengths are given in frames (metres forward of the aft
/// perpendicular, as numbered aboard) and heights above the keel, then converted with `p(_:_:_:)`.
enum Bismarck {
    static let draught = 10.0
    /// Frame at the middle of the overall length (stern −3.92, stem 246.58).
    static let midFrame = 121.33
    static let sternFrame = -3.92, stemFrame = 246.58

    /// Model position from a frame, a height above the keel and an offset to starboard.
    static func p(_ frame: Double, _ aboveKeel: Double, _ starboard: Double = 0) -> V3 {
        V3(starboard, aboveKeel - draught, frame - midFrame)
    }

    struct Paint {
        let hull, deck, light, dark, gun, canvas, black, glass, bronze, boat, boatHull, rope, bottom, wall, roof, funnelCap, ensign: SCNMaterial
    }

    static func material(_ rgb: UInt32, rough: Double, metal: Double = 0, image: NSImage? = nil) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        if let image {
            m.diffuse.contents = image
            m.diffuse.wrapS = .clamp; m.diffuse.wrapT = .clamp
            m.diffuse.mipFilter = .linear
        } else {
            m.diffuse.contents = NSColor(srgbRed: CGFloat((rgb >> 16) & 255) / 255, green: CGFloat((rgb >> 8) & 255) / 255,
                                         blue: CGFloat(rgb & 255) / 255, alpha: 1)
        }
        m.roughness.contents = NSNumber(value: rough)
        m.metalness.contents = NSNumber(value: metal)
        return m
    }

    /// Kriegsmarine greys after the Korsfjord repaint of 21–22 May 1941: darker hull, lighter
    /// superstructure, turret tops overpainted grey.
    static func makePaint() -> Paint {
        reliefs = makeReliefs()
        return Paint(hull: material(0, rough: 0.72, metal: 0.1, image: hullTexture(livery)),
              deck: material(0, rough: 0.82, image: deckTexture(livery)),
              light: material(0xB0B4BA, rough: 0.68, metal: 0.12),
              dark: material(0x6D717A, rough: 0.72, metal: 0.12),
              gun: material(0x5E6269, rough: 0.5, metal: 0.35),
              canvas: material(0xD9D5C8, rough: 0.92),
              black: material(0x16181B, rough: 0.9),
              glass: material(0x1D2A33, rough: 0.12, metal: 0.4),
              bronze: material(0x9C7F45, rough: 0.35, metal: 0.9),
              boat: material(0xA86A3E, rough: 0.45),
              boatHull: material(0xA8ACB2, rough: 0.55, metal: 0.05),
              rope: material(0x3A3C40, rough: 0.8, metal: 0.4),
              bottom: material(0x5B2A19, rough: 0.75, metal: 0.1),
              wall: wallMaterial(),
              roof: material(0x9EA2A8, rough: 0.74, metal: 0.12),
              funnelCap: material(0xCFD2D5, rough: 0.6, metal: 0.15),
              ensign: material(0, rough: 0.95, image: ensignTexture()))
    }

    /// Superstructure walls: light grey plating with seams and a row of portholes 1.6 m above each deck,
    /// repeating every 7.2 m along the wall and every 2.6 m (one deck) upwards.
    static func wallMaterial() -> SCNMaterial {
        let w = 720, h = 260
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        func fill(_ rgb: UInt32) {
            ctx.setFillColor(red: CGFloat((rgb >> 16) & 255) / 255, green: CGFloat((rgb >> 8) & 255) / 255, blue: CGFloat(rgb & 255) / 255, alpha: 1)
        }
        fill(0xB0B4BA); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        fill(0xA3A7AD)
        for k in 0..<4 { ctx.fill(CGRect(x: k * 180, y: 0, width: 2, height: h)) }
        ctx.fill(CGRect(x: 0, y: 120, width: w, height: 1))
        fill(0x85898F); ctx.fill(CGRect(x: 0, y: 0, width: w, height: 4))
        fill(0xBEC1C6); ctx.fill(CGRect(x: 0, y: h - 4, width: w, height: 4))
        // grime settling towards the deck, rust tears under the scuttles
        for row in 0..<40 {
            ctx.setFillColor(red: 0.35, green: 0.36, blue: 0.37, alpha: 0.13 * CGFloat(40 - row) / 40)
            ctx.fill(CGRect(x: 0, y: 4 + row, width: w, height: 1))
        }
        for k in 0..<4 {
            ctx.setFillColor(red: 0.45, green: 0.36, blue: 0.3, alpha: 0.16)
            ctx.fill(CGRect(x: CGFloat(88 + k * 180), y: 70, width: 4, height: 70))
            ctx.fill(CGRect(x: CGFloat(95 + k * 180), y: 96, width: 2, height: 44))
        }
        for k in 0..<4 {
            let cx = CGFloat(90 + k * 180), cy: CGFloat = 160, r: CGFloat = 17
            fill(0xC5C8CC); ctx.fillEllipse(in: CGRect(x: cx - r - 3, y: cy - r - 3, width: 2 * r + 6, height: 2 * r + 6))
            fill(0x222A31); ctx.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
            fill(0x93979D); ctx.fill(CGRect(x: cx - 26, y: cy + 25, width: 52, height: 4))
        }
        let m = material(0, rough: 0.68, metal: 0.12,
                         image: NSImage(cgImage: ctx.makeImage()!, size: NSSize(width: w, height: h)))
        m.diffuse.wrapS = .repeat; m.diffuse.wrapT = .repeat
        return m
    }

    /// The whole ship at rest on the 10 m waterline.
    static func make(_ paint: Paint = makePaint()) -> SCNNode {
        houses = []; obstacles = []
        let ship = SCNNode()
        ship.name = "Bismarck"
        ship.addChildNode(hull(paint))
        ship.addChildNode(armament(paint))
        ship.addChildNode(superstructure(paint))
        ship.addChildNode(outfit(paint))
        return ship
    }
}
