import AppKit
import SceneKit
import Metal
import simd
import ModelIO
import SceneKit.ModelIO

// OBJ uses metres, Y up and the original SceneKit winding. The model is rendered once before export so
// that every primitive carries its real mesh. Unreal import applies
// a scale of 100; scene actors rotate 90 degrees around X to make Y vertical. Materials/textures are written explicitly,
// avoiding a ModelIO exporter crash on macOS 27.
@main struct ExportSubmarine {
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
    static func main() throws {
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let root = makeDetailedSubmarine().0
        // SceneKit only regenerates a primitive's mesh after a parameter change (segment counts set by
        // the model helpers) and tessellates extruded shapes when it renders them. Read before that,
        // most fittings come back as 1 m placeholders and shapes without vertices. Render one frame.
        guard let device = MTLCreateSystemDefaultDevice() else { fatalError("Metal device unavailable") }
        let scene = SCNScene()
        scene.rootNode.addChildNode(root)
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.position = SCNVector3(60, 20, 40)
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
        var obj = "# Nordatlantik VIIC; metres; Y up\nmtllib VIIC.mtl\n"
        var mtl = "# Nordatlantik materials\n"
        var materials: [ObjectIdentifier: String] = [:]
        var base = 1, meshCount = 0, faces = 0
        func materialName(_ m: SCNMaterial) throws -> String {
            let key = ObjectIdentifier(m)
            if let name = materials[key] { return name }
            let name = "Material_\(materials.count)"
            materials[key] = name
            mtl += "\nnewmtl \(name)\nKa 0 0 0\n"
            if let image = m.diffuse.contents as? NSImage,
               let data = image.tiffRepresentation, let rep = NSBitmapImageRep(data: data),
               let png = rep.representation(using: .png, properties: [:]) {
                let filename = "\(name)_baseColor.png"
                try png.write(to: output.appendingPathComponent(filename))
                mtl += "Kd 1 1 1\nmap_Kd \(filename)\n"
            } else if let color = (m.diffuse.contents as? NSColor)?.usingColorSpace(.deviceRGB) {
                mtl += "Kd \(color.redComponent) \(color.greenComponent) \(color.blueComponent)\n"
            } else { mtl += "Kd 0.5 0.5 0.5\n" }
            let rough = (m.roughness.contents as? NSNumber)?.doubleValue ?? 0.7
            let metal = (m.metalness.contents as? NSNumber)?.doubleValue ?? 0
            mtl += "Pr \(rough)\nPm \(metal)\nNs \(max(1, 2 / max(0.01, rough * rough) - 2))\nd 1\nillum 2\n"
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
                    obj += "v \(p.x) \(p.y) \(p.z)\n"
                    let t = uv.map { values($0, i) } ?? [0, 0]
                    obj += "vt \(t[0]) \(t[1])\n"
                    let n = normals.map { values($0, i) } ?? [0, 1, 0]
                    let q = normalTransform * SIMD4<Float>(n[0], n[1], n[2], 0)
                    let direction = simd_normalize(SIMD3<Float>(q.x,q.y,q.z))
                    obj += "vn \(direction.x) \(direction.y) \(direction.z)\n"
                }
                for (slot, element) in geometry.elements.enumerated() {
                    if !geometry.materials.isEmpty {
                        obj += "usemtl \(try materialName(geometry.materials[slot % geometry.materials.count]))\n"
                    }
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
                        let ids = [a,b,c].map { index($0) + base }
                        obj += "f " + ids.map { "\($0)/\($0)/\($0)" }.joined(separator: " ") + "\n"
                        faces += 1
                    }
                    switch element.primitiveType {
                    case .triangles:
                        for i in 0..<element.primitiveCount { triangle(i*3,i*3+1,i*3+2) }
                    case .triangleStrip:
                        for i in 0..<element.primitiveCount { triangle(i, i + (i%2 == 0 ? 1:2), i + (i%2 == 0 ? 2:1)) }
                    default: fatalError("Unsupported primitive \(element.primitiveType)")
                    }
                }
                base += vertices.vectorCount
                meshCount += 1
            }
            for child in node.childNodes { try walk(child, transform) }
        }
        try walk(root, matrix_identity_float4x4)
        try obj.write(to: output.appendingPathComponent("VIIC.obj"), atomically: true, encoding: .utf8)
        try mtl.write(to: output.appendingPathComponent("VIIC.mtl"), atomically: true, encoding: .utf8)
        print("Exported \(meshCount) meshes, \(base-1) vertices, \(faces) triangles, \(materials.count) materials")
    }
}
