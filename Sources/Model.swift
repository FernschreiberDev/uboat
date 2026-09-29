import AppKit
import SceneKit

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: alpha)
}
func material(_ hex: UInt32, metal: CGFloat = 0, rough: CGFloat = 0.65) -> SCNMaterial {
    let m = SCNMaterial()
    m.diffuse.contents = color(hex)
    m.lightingModel = .physicallyBased
    m.metalness.contents = metal
    m.roughness.contents = rough
    return m
}
@discardableResult func part(_ parent: SCNNode, _ shape: SCNGeometry, _ mat: SCNMaterial, _ p: SCNVector3 = SCNVector3Zero) -> SCNNode {
    shape.materials = [mat]
    let n = SCNNode(geometry: shape)
    n.position = p
    parent.addChildNode(n)
    return n
}
func rod(_ parent: SCNNode, _ a: SCNVector3, _ b: SCNVector3, _ radius: CGFloat, _ mat: SCNMaterial) {
    let dx = b.x-a.x, dy = b.y-a.y, dz = b.z-a.z
    let len = sqrt(dx*dx+dy*dy+dz*dz)
    let n = part(parent, SCNCylinder(radius: radius, height: CGFloat(len)), mat, SCNVector3((a.x+b.x)/2, (a.y+b.y)/2, (a.z+b.z)/2))
    n.look(at: b, up: SCNVector3(0,0,1), localFront: SCNVector3(0,1,0))
}
func hullGeometry() -> SCNGeometry {
    let rings: [(Float,Float,Float)] = [(-33.5,0.06,0.1),(-31,0.65,1.4),(-27,1.55,2.5),(-21,2.6,3.2),(-12,3.08,3.45),(0,3.13,3.5),(12,2.85,3.3),(21,2.1,2.7),(28,0.95,1.65),(32,0.25,0.8),(33.5,0.02,0.12)]
    var verts = [SCNVector3](), norms = [SCNVector3](), indices = [Int32]()
    let sides = 40
    for (z,rx,ry) in rings {
        for j in 0...sides {
            let a = Float(j) / Float(sides) * .pi * 2
            verts.append(SCNVector3(sin(a)*rx, cos(a)*ry, z))
            norms.append(SCNVector3(sin(a),cos(a),0))
        }
    }
    for i in 0..<rings.count-1 { for j in 0..<sides {
        let a = Int32(i*(sides+1)+j), b = a+Int32(sides+1)
        indices += [a,b,a+1,a+1,b,b+1]
    }}
    let g = SCNGeometry(sources: [SCNGeometrySource(vertices: verts), SCNGeometrySource(normals: norms)], elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
    return g
}

func buildVIICHull(_ parent:SCNNode,_ m:VIICMaterials) {
    part(parent,viicPressureHull(),m.hull).name="pressureHull"
    for side in [-1.0,1.0] {
        let tank=longitudinalMesh(start:-21,end:20,steps:110,sides:40) {z,a in
            let f=pow(max(0.001,sin((z+21)/41 * .pi)),0.65)
            let x=side*hullSection(z).0*0.94+sin(a)*0.89*f
            return SCNVector3(x,-0.13+cos(a)*1.53*f,z)
        }
        part(parent,tank,m.hull).name="saddleTank"
        sheet(parent,m.casing,z0:-32.4,z1:29.8,side:side,lower:-0.49,upper:0)
        sheet(parent,m.casing,z0:29.79,z1:30.55,side:side,lower:-0.70,upper:0)
        sheet(parent,m.casing,z0:-33.35,z1:-32.39,side:side,lower:-0.70,upper:0)
        part(parent,lowerCasing(side),m.hull)
        // Open flood slots are made from wall ribs over a recessed dark interior.
        sheet(parent,m.recess,z0:-32.35,z1:29.75,side:side*0.965,lower:-0.70,upper:-0.5)
        for i in 0..<87 {
            let z = -32.4+Double(i)*0.715
            sheet(parent,m.casing,z0:z,z1:min(z+0.17,29.8),side:side,lower:-0.70,upper:-0.49)
        }
        for i in 0..<150 {
            let z = -32.9+Double(i)*0.42,nz=z+0.42
            if nz>30.2 {continue}
            tube(parent,SCNVector3(side*deckWidth(z),deckHeight(z)+0.035,z),SCNVector3(side*deckWidth(nz),deckHeight(nz)+0.035,nz),0.033,m.steel)
        }
        // Grouped lower drain ports, inset into the flanks.
        for z in stride(from:-23.0,through:22.0,by:1.15) {
            let (radius,lo,hi)=hullSection(z),cy=(hi+lo)/2,ry=(hi-lo)/2,y=0.7
            let x=radius*sqrt(max(0,1-pow((y-cy)/ry,2)))+0.015
            let hole=fitting(parent,SCNBox(width:0.025,height:0.14,length:0.48,chamferRadius:0.05),m.recess,SCNVector3(side*x,y,z))
            hole.name="lowerDrain"
        }
        // Four closed bow tube shutters, two per side, fitted to the tapered shell.
        for y in [-0.35,0.63] {
            let z = -30.2,(rx,lo,hi)=hullSection(z),cy=(hi+lo)/2,ry=(hi-lo)/2
            let x=rx*sqrt(max(0,1-pow((y-cy)/ry,2)))
            let frame=fitting(parent,SCNBox(width:0.055,height:0.68,length:2.25,chamferRadius:0.18),m.recess,SCNVector3(side*(x+0.015),y,z))
            frame.eulerAngles.y = CGFloat(side * -0.27)
            let lid=fitting(parent,SCNBox(width:0.055,height:0.57,length:2.08,chamferRadius:0.17),m.hull,SCNVector3(side*(x+0.044),y,z))
            lid.eulerAngles.y=frame.eulerAngles.y
        }
        for z in [-23.4,22.2] {
            for i in 0..<5 {
                let y = -0.9+Double(i)*0.4,(rx,lo,hi)=hullSection(z),cy=(hi+lo)/2,ry=(hi-lo)/2
                let x=rx*sqrt(max(0,1-pow((y-cy)/ry,2)))+0.03
                let label=SCNText(string:"\(i+2)",extrusionDepth:0.001);label.font=NSFont.monospacedSystemFont(ofSize:1,weight:.medium);label.flatness=0.5
                let n=part(parent,label,m.wornEdge,SCNVector3(side*x,y,z));n.scale=SCNVector3(0.17,0.17,0.17);n.eulerAngles.y=CGFloat(side) * .pi/2
                tube(parent,SCNVector3(side*x,y-0.02,z-0.02),SCNVector3(side*x,y-0.02,z+0.2),0.009,m.wornEdge)
            }
        }
    }
    part(parent,deckMesh(),m.timber).name="timberDeck"
    fitting(parent,SCNBox(width:0.27,height:0.2,length:40,chamferRadius:0.06),m.dark,SCNVector3(0,-2.79,0))
    // Starboard stockless anchor seated in its hawse recess.
    let anchor=SCNNode();anchor.position=SCNVector3(1.48,1.55,-28.0);anchor.eulerAngles.y = .pi/2;parent.addChildNode(anchor)
    fitting(anchor,SCNBox(width:0.72,height:0.93,length:0.08,chamferRadius:0.2),m.recess)
    tube(anchor,SCNVector3(0,0.34,-0.09),SCNVector3(0,-0.27,-0.09),0.06,m.dark)
    for side in [-1.0,1.0] {
        tube(anchor,SCNVector3(0,-0.23,-0.1),SCNVector3(side*0.3,-0.34,-0.1),0.075,m.steel)
        tube(anchor,SCNVector3(side*0.3,-0.34,-0.1),SCNVector3(side*0.32,-0.06,-0.1),0.045,m.steel)
    }
    // Early-war bow net deflector, consistent with the single aft AA platform.
    tube(parent,SCNVector3(0,3.5,-32.4),SCNVector3(0,4.15,-28.5),0.045,m.dark)
    tube(parent,SCNVector3(0,4.15,-28.5),SCNVector3(0,deckHeight(-26.8),-26.8),0.04,m.dark)
    for i in 0..<16 {
        let t=Double(i)/16,z = -32.3+t*3.7,y=3.53+t*0.61
        tube(parent,SCNVector3(0,y,z),SCNVector3(0,y+0.12,z-0.035),0.016,m.steel)
    }
}
func makeScrew(_ side:Double,_ m:VIICMaterials) -> SCNNode {
    let root=SCNNode();root.name="propeller";root.position=SCNVector3(side*1.24,-0.65,29.9)
    let hub=fitting(root,SCNCone(topRadius:0.09,bottomRadius:0.2,height:0.5),m.brass);hub.eulerAngles.x = .pi/2
    let bladeMaterial=m.brass.copy() as! SCNMaterial;bladeMaterial.isDoubleSided=true
    for blade in 0..<3 {
        var v=[SCNVector3](),ix=[Int32]()
        for i in 0...14 {
            let t=Double(i)/14,r=0.17+0.64*t,width=0.05+0.5*pow(sin(t * .pi),0.7)
            for j in 0...10 {
                let across=Double(j)/10-0.5,angle=Double(blade)*2 * .pi/3+side*(t*0.3+across*width/max(r,0.1))
                v.append(SCNVector3(sin(angle)*r,cos(angle)*r,side*across*0.28+sin(t * .pi)*0.045))
                if i<14 && j<10 {let a=Int32(i*11+j),b=a+11;ix += [a,b,a+1,a+1,b,b+1]}
            }
        }
        part(root,mesh(v,ix),bladeMaterial)
    }
    return root
}
func buildControlSurfaces(_ root:SCNNode,_ fixed:SCNNode,_ m:VIICMaterials) {
    for (name,z,span,chord) in [("bowPlanes",-26.5,2.12,1.62),("sternPlanes",28.3,1.76,1.83)] {
        let pivot=SCNNode();pivot.name=name;pivot.position=SCNVector3(0,-0.55,z);root.addChildNode(pivot)
        for side in [-1.0,1.0] {
            let n=part(pivot,foilGeometry(span:span,chord:chord),m.hull,SCNVector3(side*1.4,0,0));n.eulerAngles.x = .pi/2;n.scale.x=CGFloat(side)
            tube(fixed,SCNVector3(side*0.9,-0.55,z),SCNVector3(side*1.9,-0.55,z),0.095,m.dark)
            if name=="bowPlanes" {
                tube(fixed,SCNVector3(side*1.5,-0.55,z-1.6),SCNVector3(side*3.48,-0.55,z-0.65),0.055,m.steel)
                tube(fixed,SCNVector3(side*3.48,-0.55,z-0.65),SCNVector3(side*3.65,-0.55,z+0.5),0.055,m.steel)
            }
        }
    }
    for side in [-1.0,1.0] {
        tube(fixed,SCNVector3(side*0.9,-0.6,24.5),SCNVector3(side*1.24,-0.65,30.0),0.12,m.dark)
        tube(fixed,SCNVector3(side*0.35,0.55,28.4),SCNVector3(side*1.24,-0.65,29.25),0.1,m.steel)
        let rudder=SCNNode();rudder.name="rudder";rudder.position=SCNVector3(side*1.25,-0.42,31.25);root.addChildNode(rudder)
        let p=NSBezierPath();p.move(to:NSPoint(x:-0.5,y:-1.35));p.line(to:NSPoint(x:0.95,y:-1.02));p.line(to:NSPoint(x:0.8,y:1.15));p.line(to:NSPoint(x:-0.48,y:1.35));p.close()
        let shape=SCNShape(path:p,extrusionDepth:0.12);shape.chamferRadius=0.045
        let n=part(rudder,shape,m.hull);n.eulerAngles.y = .pi/2
        tube(fixed,SCNVector3(side*1.25,-1.4,31.2),SCNVector3(side*1.25,0.9,31.2),0.06,m.dark)
    }
    // Aft torpedo tube cap inside the stern fairing.
    let cap=fitting(fixed,SCNCylinder(radius:0.27,height:0.07),m.dark,SCNVector3(0,0.13,32.1));cap.eulerAngles.x = .pi/2
    ring(fixed,SCNVector3(0,0.13,32.15),0.25,0.025,m.steel,axis:"z")
}
func buildMasts(_ root:SCNNode,_ fixed:SCNNode,_ m:VIICMaterials) {
    for (i,z,height) in [(0,-0.78,4.35),(1,0.51,3.35)] {
        fitting(fixed,SCNCone(topRadius:0.17,bottomRadius:0.26,height:1.33),m.steel,SCNVector3(0,6.62,z))
        let scope=SCNNode();scope.name="periscope";scope.position=SCNVector3(0,6.53,z);root.addChildNode(scope)
        tube(scope,SCNVector3(0,0,0),SCNVector3(0,height*0.48,0),0.11,m.dark)
        tube(scope,SCNVector3(0,height*0.42,0),SCNVector3(0,height,0),0.072,m.chrome)
        fitting(scope,SCNBox(width:0.19,height:0.22,length:0.23,chamferRadius:0.075),m.steel,SCNVector3(0,height,0))
        fitting(scope,SCNBox(width:0.11,height:0.095,length:0.012,chamferRadius:0.014),m.recess,SCNVector3(0,height+0.025,-0.122))
        if i==0 {tube(fixed,SCNVector3(0.11,7.15,z),SCNVector3(0.18,8.43,z),0.018,m.dark)}
    }
    tube(fixed,SCNVector3(-0.67,6.05,-1.02),SCNVector3(-0.67,7.7,-1.02),0.055,m.dark)
    let loop=ring(fixed,SCNVector3(-0.67,7.86,-1.02),0.34,0.024,m.dark,axis:"z");loop.scale.x=0.8
    for side in [-1.0,1.0] {
        let mast=SCNVector3(side*0.72,7.33,-1.7),bow=SCNVector3(0,3.73,-31.1)
        tube(fixed,mast,bow,0.012,m.dark)
        for i in 0..<3 {
            let f=0.15+Double(i)*0.019
            let pos=SCNVector3(mast.x+(bow.x-mast.x)*f,mast.y+(bow.y-mast.y)*f,mast.z+(bow.z-mast.z)*f)
            let n=fitting(fixed,SCNSphere(radius:0.064),material(0x9faaa0,rough:0.3),pos);n.scale=SCNVector3(0.6,0.7,1.5)
        }
    }
    let a=SCNVector3(0,7.3,1.28),b=SCNVector3(0,deckHeight(28)+0.36,28)
    tube(fixed,SCNVector3(0,deckHeight(28),28),b,0.028,m.dark)
    tube(fixed,SCNVector3(0,deckHeight(-31.1),-31.1),SCNVector3(0,3.73,-31.1),0.025,m.dark)
    tube(fixed,a,b,0.014,m.dark)
    for i in 0..<4 {
        let f=0.22+Double(i)*0.023
        fitting(fixed,SCNSphere(radius:0.06),m.steel,SCNVector3(0,a.y+(b.y-a.y)*f,a.z+(b.z-a.z)*f))
    }
}
func makeSubmarine() -> (SCNNode,[SCNNode]) {
    let root=SCNNode();root.name="Type VIIC — early configuration"
    let fixed=SCNNode(),m=VIICMaterials()
    buildVIICHull(fixed,m)
    buildDeckFittings(fixed,m)
    buildBridge(fixed,m)
    buildDeckGun(fixed,m)
    buildFlak(fixed,m)
    buildControlSurfaces(root,fixed,m)
    buildMasts(root,fixed,m)
    // Batch static fittings by material; moving control surfaces remain independent.
    let merged=batchStaticHierarchy(fixed);merged.name="staticFittings";root.addChildNode(merged)
    var screws=[SCNNode]()
    for side in [-1.0,1.0] {let n=makeScrew(side,m);root.addChildNode(n);screws.append(n)}
    return (root,screws)
}
