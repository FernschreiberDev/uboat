import AppKit
import SceneKit
import Metal
import simd
import ModelIO
import SceneKit.ModelIO

// Bismarck for Unreal: Bismarck.obj (metres, Y up, waterline at y = 0), Bismarck.mtl, one PNG per textured
// paint and Bismarck.json (paints and hydrostatics for the port and flotation scripts). The OBJ follows
// VIIC.obj: bow towards −Z, starboard +X, a true (not mirrored) image in its right-handed frame, which Unreal
// imports with the bow along +X and starboard along +Y. The SceneKit model has its bow towards +Z with
// starboard +X, a mirror image: z is negated here, with the normals and the winding of every triangle.
// The model is rendered once before export so that every primitive carries its real mesh. Texture coordinates go from SceneKit's convention (origin at the top
// of the image) to OBJ's (origin at the bottom), and textures are resized to powers of two so that Unreal
// builds their mipmaps.
@main struct ExportBismarck {
    static func values(_ source: SCNGeometrySource, _ i: Int) -> [Float] {
        (0..<source.componentsPerVector).map { c in
            let offset = source.dataOffset + i * source.dataStride + c * source.bytesPerComponent
            return source.data.withUnsafeBytes { bytes in
                if source.bytesPerComponent == 4 { return bytes.loadUnaligned(fromByteOffset: offset, as: Float.self) }
                if source.bytesPerComponent == 8 { return Float(bytes.loadUnaligned(fromByteOffset: offset, as: Double.self)) }
                fatalError("Unsupported geometry component")
            }
        }
    }

    /// PNG resized to the next powers of two (at most 8192).
    static func writeTexture(_ image: NSImage, to url: URL) throws -> (Int, Int) {
        var rect = NSRect(origin: .zero, size: image.size)
        guard let source = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { fatalError("Texture without bitmap") }
        func power(_ n: Int) -> Int { var p = 1; while p < n { p *= 2 }; return min(p, 8192) }
        let w = power(source.width), h = power(source.height)
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.interpolationQuality = .high
        ctx.draw(source, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let png = NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:]) else {
            fatalError("PNG encoding failed")
        }
        try png.write(to: url)
        return (w, h)
    }

    static func main() throws {
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let paint = Bismarck.makePaint()
        var labels: [ObjectIdentifier: String] = [:]
        for child in Mirror(reflecting: paint).children {
            if let label = child.label, let material = child.value as? SCNMaterial { labels[ObjectIdentifier(material)] = label }
        }
        let root = Bismarck.make(paint)
        // SceneKit only builds a primitive's mesh, with its segment counts, when it renders it.
        guard let device = MTLCreateSystemDefaultDevice() else { fatalError("Metal device unavailable") }
        let scene = SCNScene()
        scene.rootNode.addChildNode(root)
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.zFar = 2000
        camera.position = SCNVector3(250, 80, 150)
        camera.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(camera)
        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = camera
        _ = renderer.snapshot(atTime: 0, with: CGSize(width: 64, height: 64), antialiasingMode: .none)
        // Every exported part must now match the size SceneKit reports for it.
        var mismatched = 0
        root.enumerateHierarchy { node, _ in
            guard let g = node.geometry else { return }
            guard let source = g.sources(for: .vertex).first, source.vectorCount > 0 else { mismatched += 1; return }
            var lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude), hi = -lo
            for i in 0..<source.vectorCount {
                let v = values(source, i)
                lo = simd_min(lo, SIMD3<Float>(v[0], v[1], v[2])); hi = simd_max(hi, SIMD3<Float>(v[0], v[1], v[2]))
            }
            let (bmin, bmax) = g.boundingBox
            let want = SIMD3<Float>(Float(bmax.x - bmin.x), Float(bmax.y - bmin.y), Float(bmax.z - bmin.z))
            if simd_length((hi - lo) - want) > 0.02 * max(1, simd_length(want)) { mismatched += 1 }
        }
        guard mismatched == 0 else { fatalError("\(mismatched) parts still have placeholder geometry") }

        var obj = "# Bismarck, Operation Rheinübung (May 1941); metres; Y up, bow +Z, starboard +X, waterline y = 0\nmtllib Bismarck.mtl\n"
        var mtl = "# Bismarck paints (Kd in sRGB)\n"
        var paints: [[String: Any]] = []
        var names: Set<String> = []
        var base = 1, meshCount = 0, faces = 0
        var lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude), hi = -lo
        var top = SIMD3<Float>(0, -.greatestFiniteMagnitude, 0)
        func materialName(_ m: SCNMaterial) throws -> String {
            guard let label = labels[ObjectIdentifier(m)] else { fatalError("Material outside Bismarck.Paint") }
            let name = "Bismarck_" + label
            if names.contains(name) { return name }
            names.insert(name)
            var entry: [String: Any] = ["name": name, "paint": label]
            mtl += "\nnewmtl \(name)\nKa 0 0 0\n"
            if let image = m.diffuse.contents as? NSImage {
                let filename = "T_Bismarck_\(label).png"
                let (w, h) = try writeTexture(image, to: output.appendingPathComponent(filename))
                mtl += "Kd 1 1 1\nmap_Kd \(filename)\n"
                entry["texture"] = filename
                entry["texture_size"] = [w, h]
                entry["tiling"] = m.diffuse.wrapS == .repeat
                // the Korsfjord livery of 21 May 1941 (stripes, darker ends, deck air-recognition panels)
                let variant: NSImage? = label == "hull" ? Bismarck.hullTexture(.korsfjord) : label == "deck" ? Bismarck.deckTexture(.korsfjord) : nil
                if let variant {
                    let file = "T_Bismarck_\(label)_21mai.png"
                    _ = try writeTexture(variant, to: output.appendingPathComponent(file))
                    entry["variants"] = ["21mai": file]
                }
                if let relief = Bismarck.reliefs[label] {
                    let normal = "T_Bismarck_\(label)_N.png"
                    _ = try writeTexture(relief, to: output.appendingPathComponent(normal))
                    entry["normal"] = normal
                }
            } else if let color = (m.diffuse.contents as? NSColor)?.usingColorSpace(.sRGB) {
                let rgb = [color.redComponent, color.greenComponent, color.blueComponent].map { Double($0) }
                mtl += "Kd \(rgb[0]) \(rgb[1]) \(rgb[2])\n"
                entry["srgb"] = rgb
            } else { fatalError("Paint \(label) has no colour") }
            let rough = (m.roughness.contents as? NSNumber)?.doubleValue ?? 0.7
            let metal = (m.metalness.contents as? NSNumber)?.doubleValue ?? 0
            mtl += "Pr \(rough)\nPm \(metal)\nNs \(max(1, 2 / max(0.01, rough * rough) - 2))\nd 1\nillum 2\n"
            entry["roughness"] = rough
            entry["metallic"] = metal
            paints.append(entry)
            return name
        }
        func walk(_ node: SCNNode, _ parent: simd_float4x4) throws {
            let transform = parent * node.simdTransform
            if let original = node.geometry {
                let geometry: SCNGeometry
                if original.sources(for: .vertex).isEmpty {
                    geometry = SCNGeometry(mdlMesh: MDLMesh(scnGeometry: original))
                    geometry.materials = original.materials
                } else { geometry = original }
                guard let vertices = geometry.sources(for: .vertex).first else { fatalError("Missing vertices") }
                let normals = geometry.sources(for: .normal).first
                let uv = geometry.sources(for: .texcoord).first
                let normalTransform = simd_transpose(simd_inverse(transform))
                obj += "\no Part_\(meshCount)\n"
                for i in 0..<vertices.vectorCount {
                    let v = values(vertices, i)
                    let p = transform * SIMD4<Float>(v[0], v[1], v[2], 1)
                    lo = simd_min(lo, SIMD3(p.x, p.y, p.z)); hi = simd_max(hi, SIMD3(p.x, p.y, p.z))
                    if p.y > top.y { top = SIMD3(p.x, p.y, p.z) }
                    obj += "v \(p.x) \(p.y) \(-p.z)\n"
                    let t = uv.map { values($0, i) } ?? [0, 0]
                    obj += "vt \(t[0]) \(1 - t[1])\n"
                    let n = normals.map { values($0, i) } ?? [0, 1, 0]
                    let q = normalTransform * SIMD4<Float>(n[0], n[1], n[2], 0)
                    let direction = simd_normalize(SIMD3<Float>(q.x, q.y, q.z))
                    obj += "vn \(direction.x) \(direction.y) \(-direction.z)\n"
                }
                for (slot, element) in geometry.elements.enumerated() {
                    guard !geometry.materials.isEmpty else { fatalError("Part without material") }
                    obj += "usemtl \(try materialName(geometry.materials[slot % geometry.materials.count]))\n"
                    func index(_ i: Int) -> Int {
                        element.data.withUnsafeBytes { bytes in
                            let offset = i * element.bytesPerIndex
                            switch element.bytesPerIndex {
                            case 1: return Int(bytes.loadUnaligned(fromByteOffset: offset, as: UInt8.self))
                            case 2: return Int(bytes.loadUnaligned(fromByteOffset: offset, as: UInt16.self))
                            case 4: return Int(bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
                            default: fatalError("Unsupported index width")
                            }
                        }
                    }
                    func triangle(_ a: Int, _ b: Int, _ c: Int) {
                        let ids = [a, c, b].map { index($0) + base }   // z mirrored: reverse the winding
                        obj += "f " + ids.map { "\($0)/\($0)/\($0)" }.joined(separator: " ") + "\n"
                        faces += 1
                    }
                    switch element.primitiveType {
                    case .triangles:
                        for i in 0..<element.primitiveCount { triangle(i * 3, i * 3 + 1, i * 3 + 2) }
                    case .triangleStrip:
                        for i in 0..<element.primitiveCount { triangle(i, i + (i % 2 == 0 ? 1 : 2), i + (i % 2 == 0 ? 2 : 1)) }
                    default: fatalError("Unsupported primitive \(element.primitiveType)")
                    }
                }
                base += vertices.vectorCount
                meshCount += 1
            }
            for child in node.childNodes { try walk(child, transform) }
        }
        try walk(root, matrix_identity_float4x4)
        // The tallest point is the main mast's truck, 19 m aft of amidships (frame 102.2).
        guard abs(Double(top.z) - (102.2 - Bismarck.midFrame)) < 1.0 else {
            fatalError("Tallest point at z = \(top.z) m, expected the main mast 19.1 m aft")
        }
        try obj.write(to: output.appendingPathComponent("Bismarck.obj"), atomically: true, encoding: .utf8)
        try mtl.write(to: output.appendingPathComponent("Bismarck.mtl"), atomically: true, encoding: .utf8)

        // Hydrostatics at the model waterline, in model metres (x to starboard, y up from the waterline,
        // z forward of the middle of the overall length).
        let h = Bismarck.Lines.hydrostatics(draught: Bismarck.draught)
        let mid = Bismarck.midFrame
        let info: [String: Any] = [
            "source": "Sources/Bismarck (UnrealDemo/Tools/export-bismarck.sh)",
            "frame": "lengths in model metres: x to starboard, y up from the waterline, z forward of amidships; the OBJ has z negated (bow towards -Z, as VIIC.obj)",
            "main_mast_top_m": [Double(top.x), Double(top.y), Double(top.z)],
            "size_m": [Double(hi.x - lo.x), Double(hi.y - lo.y), Double(hi.z - lo.z)],
            "min_m": [Double(lo.x), Double(lo.y), Double(lo.z)],
            "max_m": [Double(hi.x), Double(hi.y), Double(hi.z)],
            "draught_m": Bismarck.draught,
            "displacement_t": h.volume * 1.025,
            "volume_m3": h.volume,
            "waterplane_m2": h.waterplane,
            "lcb_m": h.lcb - mid,
            "lcf_m": h.lcf - mid,
            "kb_m": h.kb,
            "bm_t_m": h.inertiaT / h.volume,
            "bm_l_m": h.inertiaL / h.volume,
            "waterline_m": [h.aft - mid, h.fore - mid],
            "beam_m": 36.0,
            "deck_at_side_m": Bismarck.Lines.deckHeight(mid) - Bismarck.draught,
            "paints": paints,
            "meshes": meshCount, "vertices": base - 1, "triangles": faces,
        ]
        let json = try JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted, .sortedKeys])
        try json.write(to: output.appendingPathComponent("Bismarck.json"))
        print("Exported \(meshCount) meshes, \(base - 1) vertices, \(faces) triangles, \(paints.count) paints")
        print(String(format: "size %.2f × %.2f × %.2f m, keel at %.2f m, main mast top %.1f m above the waterline, %.1f m aft of amidships",
                     hi.x - lo.x, hi.y - lo.y, hi.z - lo.z, lo.y, top.y, -top.z))
    }
}
