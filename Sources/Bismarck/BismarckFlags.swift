import AppKit
import SceneKit
import simd

// National markings of May 1941, for the historical simulation: the war ensign flown at the mainmast gaff
// at sea, and the red air-recognition panels with a white disc and a black swastika painted on the
// forecastle and quarterdeck until they were painted grey on 22 May (only in the Korsfjord livery).
extension Bismarck {
    /// Paint scheme of the model: Operation Rheinübung on 24 May 1941 (Denmark Strait, stripes and deck
    /// markings painted over), or on entering the Korsfjord on 21 May 1941 (black and white stripes on the
    /// hull, darker ends, air-recognition panels on the decks), after the plans of M. P. González López.
    enum Livery: String { case denmarkStrait = "24mai", korsfjord = "21mai" }
    static var livery: Livery = .denmarkStrait

    /// Reichskriegsflagge 1938–1945 after its specification (Wikimedia Commons SVG, 5000 × 3000 units):
    /// red field, black cross bordered white, white disc ringed black with the swastika at 45°, iron cross
    /// in the canton.
    static func ensignTexture() -> NSImage {
        let w = 1000, h = 600, s = CGFloat(w) / 5000
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.translateBy(x: 0, y: CGFloat(h)); ctx.scaleBy(x: s, y: -s)   // SVG units, y down
        let red = CGColor(srgbRed: 0xDD / 255.0, green: 0, blue: 0, alpha: 1)
        let white = CGColor(gray: 1, alpha: 1), black = CGColor(gray: 0, alpha: 1)
        ctx.setFillColor(red); ctx.fill(CGRect(x: 0, y: 0, width: 5000, height: 3000))
        // iron cross in the canton: cross pattée outlined white, black, white
        let cross = CGMutablePath()
        cross.move(to: CGPoint(x: 725.6171875, y: 821.5))
        cross.addCurve(to: CGPoint(x: 668.6420898, y: 591.1420898), control1: CGPoint(x: 693.3481445, y: 750.6108398), control2: CGPoint(x: 673.4365234, y: 672.9086914))
        cross.addCurve(to: CGPoint(x: 899, y: 648.1171875), control1: CGPoint(x: 750.4082031, y: 595.9365234), control2: CGPoint(x: 828.1108398, y: 615.8481445))
        cross.addLine(to: CGPoint(x: 899, y: 456.8828125))
        cross.addCurve(to: CGPoint(x: 668.6420898, y: 513.8579102), control1: CGPoint(x: 828.1108398, y: 489.1518555), control2: CGPoint(x: 750.4082031, y: 509.0634766))
        cross.addCurve(to: CGPoint(x: 725.6171875, y: 283.5), control1: CGPoint(x: 673.4365234, y: 432.0913086), control2: CGPoint(x: 693.3481445, y: 354.3891602))
        cross.addLine(to: CGPoint(x: 534.3828125, y: 283.5))
        cross.addCurve(to: CGPoint(x: 591.3579102, y: 513.8579102), control1: CGPoint(x: 566.6518555, y: 354.3891602), control2: CGPoint(x: 586.5634766, y: 432.0913086))
        cross.addCurve(to: CGPoint(x: 361, y: 456.8828125), control1: CGPoint(x: 509.5917969, y: 509.0634766), control2: CGPoint(x: 431.8891602, y: 489.1518555))
        cross.addLine(to: CGPoint(x: 361, y: 648.1171875))
        cross.addCurve(to: CGPoint(x: 591.3579102, y: 591.1420898), control1: CGPoint(x: 431.8891602, y: 615.8481445), control2: CGPoint(x: 509.5917969, y: 595.9365234))
        cross.addCurve(to: CGPoint(x: 534.3828125, y: 821.5), control1: CGPoint(x: 586.5634766, y: 672.9086914), control2: CGPoint(x: 566.6518555, y: 750.6108398))
        cross.closeSubpath()
        for (colour, width) in [(white, 132.0), (black, 72.0), (white, 34.0)] {
            ctx.addPath(cross); ctx.setStrokeColor(colour); ctx.setLineWidth(width); ctx.strokePath()
        }
        ctx.addPath(cross); ctx.setFillColor(black); ctx.fillPath()
        // bands of the cross and the ringed disc
        ctx.setFillColor(white)
        ctx.fill(CGRect(x: 0, y: 1125, width: 5000, height: 750)); ctx.fill(CGRect(x: 1525, y: 0, width: 750, height: 3000))
        ctx.fillEllipse(in: CGRect(x: 900, y: 500, width: 2000, height: 2000))
        ctx.setFillColor(black)
        ctx.fill(CGRect(x: 0, y: 1200, width: 5000, height: 600)); ctx.fill(CGRect(x: 1600, y: 0, width: 600, height: 3000))
        ctx.fillEllipse(in: CGRect(x: 975, y: 575, width: 1850, height: 1850))
        ctx.setStrokeColor(white); ctx.setLineWidth(76)
        for angle in [0.0, Double.pi / 2] {
            ctx.saveGState()
            ctx.translateBy(x: 1900, y: 1500); ctx.rotate(by: CGFloat(angle)); ctx.translateBy(x: -1900, y: -1500)
            ctx.stroke(CGRect(x: -248, y: 1310, width: 5500, height: 376))
            ctx.restoreGState()
        }
        ctx.setFillColor(white); ctx.fillEllipse(in: CGRect(x: 1050, y: 650, width: 1700, height: 1700))
        ctx.setStrokeColor(black); ctx.setLineWidth(46); ctx.strokeEllipse(in: CGRect(x: 1118, y: 718, width: 1564, height: 1564))
        // swastika: four hooked arms turned 45°, outlined white and black
        let arms = CGMutablePath()
        for k in 0..<4 {
            let t = CGAffineTransform(translationX: 1900, y: 1500).rotated(by: CGFloat(Double.pi / 4 + Double(k) * Double.pi / 2))
                .translatedBy(x: -1900, y: -1500)
            arms.move(to: CGPoint(x: 1480, y: 975), transform: t)
            arms.addLine(to: CGPoint(x: 1480, y: 1500), transform: t)
            arms.addLine(to: CGPoint(x: 2080, y: 1500), transform: t)
        }
        ctx.setLineCap(.butt); ctx.setLineJoin(.miter)
        for (colour, width) in [(black, 210.0), (white, 180.0), (black, 150.0)] {
            ctx.addPath(arms); ctx.setStrokeColor(colour); ctx.setLineWidth(width); ctx.strokePath()
        }
        return NSImage(cgImage: ctx.makeImage()!, size: NSSize(width: w, height: h))
    }

    /// The ensign hoisted to the peak of the mainmast gaff (2.4 × 4.0 m), streaming aft with a slight wave.
    /// Both faces are modelled: the design reads from the port side (hoist on the left), mirrored from starboard.
    static func ensign(_ paint: Paint) -> SCNNode {
        let peak = p(99.0, 49.75), height = 2.4, length = 4.0
        let nu = 16, nv = 8
        func point(_ u: Double, _ v: Double) -> V3 {
            let wave = 0.22 * u * sin(2 * Double.pi * (1.1 * u) + 0.6)
            return peak + V3(wave, -0.1 - v * height - 0.25 * u * u, -0.05 - u * length)
        }
        var m = Mesh(slots: 1)
        for face in [0, 1] {
            var ids: [[UInt32]] = []
            for j in 0...nv {
                ids.append((0...nu).map { i in
                    let u = Double(i) / Double(nu), v = Double(j) / Double(nv)
                    return m.vertex(point(u, v), V3(face == 0 ? -1 : 1, 0, 0), SIMD2(u, v))
                })
            }
            for j in 0..<nv { for i in 0..<nu {
                let a = ids[j][i], b = ids[j][i + 1], c = ids[j + 1][i + 1], d = ids[j + 1][i]
                if face == 0 { m.quad(0, a, b, c, d) } else { m.quad(0, a, d, c, b) }
            } }
        }
        // halyard from the gaff peak down to the flag's hoist
        var line = Mesh(slots: 1)
        line.beam(0, peak, peak + V3(0, -0.12, -0.05), width: 0.02)
        let n = SCNNode()
        n.name = "ensign"
        n.addChildNode(node(m, [paint.ensign], name: "ensignCloth"))
        n.addChildNode(node(line, [paint.rope], name: "ensignHalyard"))
        return n
    }

    /// Red air-recognition panel across the deck from `from` to `to` (frames), with a white disc of 5.1 m and
    /// an upright black swastika (bars 6.8 m, 0.72 m wide) centred on `centre`, as on the plan of 21 May 1941.
    /// Drawn in deck-texture space: x(f) along the ship, y(s) athwartships with starboard up.
    static func drawAirRecognition(_ ctx: CGContext, x: (Double) -> CGFloat, y: (Double) -> CGFloat,
                                   from: Double, to: Double, centre fc: Double) {
        ctx.setFillColor(CGColor(srgbRed: 0.69, green: 0.07, blue: 0.08, alpha: 1))
        ctx.fill(CGRect(x: x(from), y: y(-18), width: x(to) - x(from), height: y(18) - y(-18)))
        let r = 5.1
        ctx.setFillColor(CGColor(srgbRed: 0.93, green: 0.93, blue: 0.91, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: x(fc - r), y: y(-r), width: x(fc + r) - x(fc - r), height: y(r) - y(-r)))
        let l = 3.4, w = 0.72
        // (frame range, starboard range): cross bars, then the four hooks turning the same way as on the plan
        let bars: [((Double, Double), (Double, Double))] = [
            ((fc - w / 2, fc + w / 2), (-l, l)), ((fc - l, fc + l), (-w / 2, w / 2)),
            ((fc - w / 2, fc + l), (-l, -l + w)),        // port end, turned forward
            ((fc - l, fc + w / 2), (l - w, l)),          // starboard end, turned aft
            ((fc + l - w, fc + l), (-w / 2, l)),         // forward end, turned to starboard
            ((fc - l, fc - l + w), (-l, w / 2))]         // after end, turned to port
        ctx.setFillColor(CGColor(srgbRed: 0.08, green: 0.08, blue: 0.08, alpha: 1))
        for (f, s) in bars { ctx.fill(CGRect(x: x(f.0), y: y(s.0), width: x(f.1) - x(f.0), height: y(s.1) - y(s.0))) }
    }
}
