import AppKit
import simd

// Relief of the textured paints, as tangent-space normal maps for the Unreal port: plate seams and welds,
// the armour belt's edge, side scuttles and rungs on the hull; plank grooves on the deck; panel seams and
// scuttle rims on the superstructure plating. Heights are drawn in grey at the colour textures' positions,
// then turned into normals (DirectX convention, green towards the bottom of the image, as Unreal expects).
extension Bismarck {
    /// Normal maps by paint name ("hull", "deck", "wall"), made with the paints.
    static var reliefs: [String: NSImage] = [:]

    static func makeReliefs() -> [String: NSImage] {
        ["hull": normalMap(hullRelief(), strength: 5, wrap: false),
         "deck": normalMap(deckRelief(), strength: 4, wrap: false),
         "wall": normalMap(wallRelief(), strength: 5, wrap: true)]
    }

    static func greyContext(_ w: Int, _ h: Int) -> CGContext {
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        ctx.setFillColor(gray: 0.5, alpha: 1); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        return ctx
    }

    /// Normals from a height map (grey, 0…1): n = normalize(-s·∂h/∂x, -s·∂h/∂y, 1) with y running down the image.
    static func normalMap(_ height: CGContext, strength s: Double, wrap: Bool) -> NSImage {
        let w = height.width, h = height.height, stride = height.bytesPerRow
        let src = height.data!.bindMemory(to: UInt8.self, capacity: stride * h)
        let out = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        // tagged sRGB only so that the export's resampling leaves the values alone; imported without sRGB
        let dst = out.data!.bindMemory(to: UInt8.self, capacity: w * h * 4)
        func at(_ x: Int, _ y: Int) -> Double {
            let xx = wrap ? (x + w) % w : min(max(x, 0), w - 1), yy = wrap ? (y + h) % h : min(max(y, 0), h - 1)
            return Double(src[yy * stride + xx]) / 255
        }
        for y in 0..<h { for x in 0..<w {
            let dx = (at(x + 1, y) - at(x - 1, y)) / 2, dy = (at(x, y + 1) - at(x, y - 1)) / 2
            let n = simd_normalize(SIMD3(-s * dx, -s * dy, 1))
            let k = (y * w + x) * 4
            dst[k] = UInt8((n.x * 0.5 + 0.5) * 255); dst[k + 1] = UInt8((n.y * 0.5 + 0.5) * 255)
            dst[k + 2] = UInt8((n.z * 0.5 + 0.5) * 255); dst[k + 3] = 255
        } }
        return NSImage(cgImage: out.makeImage()!, size: NSSize(width: w, height: h))
    }

    /// Hull plating: 8192 × 640 over the length and 20 m from the keel, like `hullTexture`.
    static func hullRelief() -> CGContext {
        let w = 8192, h = 640, span = stemFrame - sternFrame
        func x(_ f: Double) -> CGFloat { CGFloat((f - sternFrame) / span * Double(w)) }
        func y(_ height: Double) -> CGFloat { CGFloat(height / 20 * Double(h)) }
        let ctx = greyContext(w, h)
        func grey(_ v: CGFloat) { ctx.setFillColor(gray: v, alpha: 1) }
        // external armour belt, 7.6 to 12.4 m, standing proud of the plating above it
        grey(0.58)
        var f = Lines.frame(460)
        while f < Lines.frame(2500) {
            let rise = max(0, (f - 150) / 55) * 0.17
            ctx.fill(CGRect(x: x(f), y: y(7.6), width: x(f + 1) - x(f) + 1, height: y(12.42 + rise) - y(7.6)))
            f += 1
        }
        // strake seams every 2.3 m and plate butts every 6 m: weld beads
        grey(0.56)
        var s = 1.2
        while s < 16 { ctx.fill(CGRect(x: 0, y: y(s), width: CGFloat(w), height: 2)); s += 2.3 }
        f = 0
        while f < 244 { ctx.fill(CGRect(x: x(f), y: y(1), width: 2, height: y(15.5) - y(1))); f += 6 }
        // side scuttles: raised rims round recessed glasses, brows above
        for q in scuttles {
            let c = CGPoint(x: x(Lines.frame(q.0)), y: y(Lines.height(q.1)))
            grey(0.75); ctx.fillEllipse(in: CGRect(x: c.x - 7.5, y: c.y - 7.5, width: 15, height: 15))
            grey(0.3); ctx.fillEllipse(in: CGRect(x: c.x - 5, y: c.y - 5, width: 10, height: 10))
            grey(0.72); ctx.fill(CGRect(x: c.x - 9, y: c.y + 10, width: 18, height: 3))
        }
        grey(0.8)
        for px in hullRungs {
            var py = 504.0
            while py < 556 {
                let c = CGPoint(x: x(Lines.frame(px)), y: y(Lines.height(py)))
                ctx.fill(CGRect(x: c.x - 6, y: c.y, width: 12, height: 2))
                py += 4
            }
        }
        return ctx
    }

    /// Upper deck: grooves between 0.12 m teak planks and at their butts, seams in the steel plating.
    static func deckRelief() -> CGContext {
        let w = 8192, h = 1152, span = stemFrame - sternFrame
        func x(_ f: Double) -> CGFloat { CGFloat((f - sternFrame) / span * Double(w)) }
        func y(_ s: Double) -> CGFloat { CGFloat((s + 18) / 36 * Double(h)) }
        let ctx = greyContext(w, h)
        ctx.setFillColor(gray: 0.3, alpha: 1)
        var s = -18.0, row = 0
        while s < 18 {
            ctx.fill(CGRect(x: 0, y: y(s), width: CGFloat(w), height: 1))
            var f = sternFrame + Double(row % 4) * 1.5
            while f < stemFrame { ctx.fill(CGRect(x: x(f), y: y(s), width: 1, height: y(s + 0.12) - y(s))); f += 6.0 }
            s += 0.12; row += 1
        }
        // steel areas: smooth plating with welded seams every 2 m
        let steel: [(Double, Double)] = [(Lines.frame(145), Lines.frame(306)), (Lines.frame(2658), Lines.frame(2805)), (Lines.frame(2985), stemFrame)]
        for (a, b) in steel {
            ctx.setFillColor(gray: 0.5, alpha: 1); ctx.fill(CGRect(x: x(a), y: 0, width: x(b) - x(a), height: CGFloat(h)))
            ctx.setFillColor(gray: 0.56, alpha: 1)
            var ss = -18.0
            while ss < 18 { ctx.fill(CGRect(x: x(a), y: y(ss), width: x(b) - x(a), height: 2)); ss += 2.0 }
        }
        return ctx
    }

    /// Superstructure plating tile, 7.2 × 2.6 m (720 × 260), like `wallMaterial`.
    static func wallRelief() -> CGContext {
        let w = 720, h = 260
        let ctx = greyContext(w, h)
        ctx.setFillColor(gray: 0.58, alpha: 1)
        for k in 0..<4 { ctx.fill(CGRect(x: k * 180, y: 0, width: 3, height: h)) }
        ctx.fill(CGRect(x: 0, y: 120, width: w, height: 2))
        ctx.setFillColor(gray: 0.62, alpha: 1); ctx.fill(CGRect(x: 0, y: 0, width: w, height: 5))
        for k in 0..<4 {
            let cx = CGFloat(90 + k * 180), cy: CGFloat = 160
            ctx.setFillColor(gray: 0.78, alpha: 1); ctx.fillEllipse(in: CGRect(x: cx - 22, y: cy - 22, width: 44, height: 44))
            ctx.setFillColor(gray: 0.32, alpha: 1); ctx.fillEllipse(in: CGRect(x: cx - 17, y: cy - 17, width: 34, height: 34))
            ctx.setFillColor(gray: 0.72, alpha: 1); ctx.fill(CGRect(x: cx - 26, y: cy + 25, width: 52, height: 4))
        }
        return ctx
    }
}
