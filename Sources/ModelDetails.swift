import AppKit
import SceneKit

@discardableResult func fitting(_ parent:SCNNode,_ geometry:SCNGeometry,_ mat:SCNMaterial,_ position:SCNVector3=SCNVector3Zero) -> SCNNode {
    if let g=geometry as? SCNCylinder {g.radialSegmentCount=16;g.heightSegmentCount=1}
    if let g=geometry as? SCNCone {g.radialSegmentCount=20;g.heightSegmentCount=1}
    if let g=geometry as? SCNSphere {g.segmentCount=12}
    if let g=geometry as? SCNBox {g.chamferSegmentCount=2}
    return part(parent,geometry,mat,position)
}
func handwheel(_ parent:SCNNode,center:SCNVector3,radius:CGFloat,mat:SCNMaterial,axis:String="y") {
    let node=SCNNode();node.position=center;parent.addChildNode(node)
    if axis=="x" {node.eulerAngles.z = .pi/2}
    if axis=="z" {node.eulerAngles.x = .pi/2}
    ring(node,SCNVector3Zero,radius,0.018,mat)
    fitting(node,SCNCylinder(radius:0.045,height:0.05),mat)
    for i in 0..<4 {let a=Double(i)*Double.pi/2;tube(node,SCNVector3Zero,SCNVector3(sin(a)*radius,0,cos(a)*radius),0.012,mat)}
}
func hatch(_ parent:SCNNode,z:Double,radius:CGFloat=0.48,mat:VIICMaterials) {
    let h=deckHeight(z)
    fitting(parent,SCNCylinder(radius:radius+0.1,height:0.13),mat.dark,SCNVector3(0,h+0.07,z))
    fitting(parent,SCNCylinder(radius:radius,height:0.085),mat.steel,SCNVector3(0,h+0.17,z))
    ring(parent,SCNVector3(0,h+0.22,z),radius-0.03,0.018,mat.wornEdge)
    handwheel(parent,center:SCNVector3(0,h+0.29,z),radius:0.16,mat:mat.dark)
    for side in [-1.0,1.0] {
        fitting(parent,SCNBox(width:0.15,height:0.13,length:0.22,chamferRadius:0.03),mat.dark,SCNVector3(side*0.24,h+0.18,z+Double(radius)))
    }
    for i in 0..<10 {
        let a=Double(i)*2 * .pi/10
        fitting(parent,SCNCylinder(radius:0.028,height:0.026),mat.wornEdge,SCNVector3(sin(a)*Double(radius+0.045),h+0.149,z+cos(a)*Double(radius+0.045)))
    }
}
func buildDeckFittings(_ parent:SCNNode,_ m:VIICMaterials) {
    for z in [-18.2,-13.5,11.5,19.0] {hatch(parent,z:z,mat:m)}
    for z in [-21.3,15.5] {
        let h=deckHeight(z)
        fitting(parent,SCNBox(width:1.35,height:0.07,length:2.15,chamferRadius:0.12),m.dark,SCNVector3(0,h+0.035,z))
        fitting(parent,SCNBox(width:1.22,height:0.055,length:2.0,chamferRadius:0.1),m.steel,SCNVector3(0,h+0.085,z))
        for dz in [-0.8,0.8] {tube(parent,SCNVector3(-0.2,h+0.18,z+dz),SCNVector3(0.2,h+0.18,z+dz),0.028,m.dark)}
        for side in [-1.0,1.0] {for dz in stride(from:-0.8,through:0.8,by:0.4) {
            fitting(parent,SCNCylinder(radius:0.035,height:0.02),m.dark,SCNVector3(side*0.52,h+0.122,z+dz))
        }}
    }
    // Retractable mooring bitts, paired fairleads and anchor capstan.
    for z in [-28.2,-24.4,24.1,27.4] {
        let h=deckHeight(z)
        for side in [-1.0,1.0] {
            let x=side*deckWidth(z)*0.68
            fitting(parent,SCNBox(width:0.33,height:0.045,length:0.7,chamferRadius:0.03),m.steel,SCNVector3(x,h+0.025,z))
            for dz in [-0.19,0.19] {
                fitting(parent,SCNCylinder(radius:0.08,height:0.25),m.dark,SCNVector3(x,h+0.15,z+dz))
                fitting(parent,SCNCylinder(radius:0.115,height:0.06),m.steel,SCNVector3(x,h+0.29,z+dz))
            }
        }
    }
    let cz = -26.3,h=deckHeight(cz)
    fitting(parent,SCNCylinder(radius:0.35,height:0.5),m.dark,SCNVector3(0,h+0.26,cz))
    fitting(parent,SCNCylinder(radius:0.46,height:0.12),m.steel,SCNVector3(0,h+0.54,cz))
    for i in 0..<18 {
        let z = -26.4-Double(i)*0.13
        let n=ring(parent,SCNVector3(0.14,deckHeight(z)+0.07,z),0.07,0.018,m.dark)
        if i%2==0 {n.eulerAngles.z = .pi/2}
    }
    // Raised ventilation grilles and longitudinal side rails.
    for z in [-16.0,8.0,16.8] {for side in [-1.0,1.0] {
        let x=side*1.2,h=deckHeight(z)
        fitting(parent,SCNBox(width:0.56,height:0.055,length:1.1,chamferRadius:0.05),m.recess,SCNVector3(x,h+0.035,z))
        for i in 0..<8 {tube(parent,SCNVector3(x-0.26,h+0.07,z-0.48+Double(i)*0.135),SCNVector3(x+0.26,h+0.07,z-0.48+Double(i)*0.135),0.022,m.steel)}
    }}
    for side in [-1.0,1.0] {
        let zs=Array(stride(from:-19.0,through:-4.0,by:2.5))+Array(stride(from:6.0,through:20.0,by:2.8))
        for z in zs {
            let x=side*(deckWidth(z)-0.16),h=deckHeight(z)
            tube(parent,SCNVector3(x,h,z),SCNVector3(x,h+0.85,z),0.027,m.steel)
            fitting(parent,SCNCylinder(radius:0.055,height:0.06),m.dark,SCNVector3(x,h+0.05,z))
        }
        for range in [(-19.0,-4.0),(6.0,20.0)] {for level in [0.4,0.84] {
            for i in 0..<28 {
                let z=range.0+(range.1-range.0)*Double(i)/28,nz=range.0+(range.1-range.0)*Double(i+1)/28
                tube(parent,SCNVector3(side*(deckWidth(z)-0.16),deckHeight(z)+level,z),SCNVector3(side*(deckWidth(nz)-0.16),deckHeight(nz)+level,nz),0.013,m.dark)
            }
        }}
    }
}
func buildDeckGun(_ parent:SCNNode,_ m:VIICMaterials) {
    let gun=SCNNode();gun.position=SCNVector3(0,deckHeight(-8.0),-8.0);parent.addChildNode(gun)
    fitting(gun,SCNCylinder(radius:0.64,height:0.15),m.dark,SCNVector3(0,0.09,0))
    fitting(gun,SCNCone(topRadius:0.22,bottomRadius:0.47,height:0.85),m.steel,SCNVector3(0,0.57,0))
    fitting(gun,SCNBox(width:0.56,height:0.48,length:0.73,chamferRadius:0.07),m.steel,SCNVector3(0,1.16,0))
    let barrel=SCNNode();barrel.position=SCNVector3(0,1.29,0);barrel.eulerAngles.x=0.09;gun.addChildNode(barrel)
    tube(barrel,SCNVector3(0,0,0.47),SCNVector3(0,0,-0.9),0.16,m.dark)
    tube(barrel,SCNVector3(0,0,-0.85),SCNVector3(0,0,-2.8),0.09,m.steel)
    tube(barrel,SCNVector3(0,0,-2.8),SCNVector3(0,0,-3.05),0.11,m.dark)
    ring(barrel,SCNVector3(0,0,-3.057),0.083,0.023,m.steel,axis:"z")
    let bore=fitting(barrel,SCNCylinder(radius:0.059,height:0.008),m.recess,SCNVector3(0,0,-3.06));bore.eulerAngles.x = .pi/2
    for side in [-1.0,1.0] {
        tube(barrel,SCNVector3(side*0.15,0.21,0.2),SCNVector3(side*0.15,0.21,-1.1),0.065,m.steel)
        tube(gun,SCNVector3(side*0.25,0.9,0.1),SCNVector3(side*0.64,0.9,0.1),0.07,m.dark)
        handwheel(gun,center:SCNVector3(side*0.7,1.0,0.05),radius:0.22,mat:m.dark,axis:"x")
        fitting(gun,SCNBox(width:0.3,height:0.07,length:0.37,chamferRadius:0.09),m.dark,SCNVector3(side*0.62,0.61,0.67))
        tube(gun,SCNVector3(side*0.26,0.3,0.3),SCNVector3(side*0.62,0.56,0.67),0.05,m.steel)
        tube(gun,SCNVector3(side*0.34,1.1,0.2),SCNVector3(side*0.34,1.5,0.2),0.03,m.dark)
        ring(gun,SCNVector3(side*0.34,1.48,0.12),0.065,0.014,m.dark,axis:"z")
    }
    for i in 0..<12 {let a=Double(i)*2 * .pi/12;fitting(gun,SCNCylinder(radius:0.03,height:0.026),m.wornEdge,SCNVector3(sin(a)*0.54,0.18,cos(a)*0.54))}
}
func buildFlak(_ parent:SCNNode,_ m:VIICMaterials) {
    let gun=SCNNode();gun.position=SCNVector3(0,5.92,3.6);gun.eulerAngles.y=0.3;parent.addChildNode(gun)
    fitting(gun,SCNCylinder(radius:0.38,height:0.12),m.dark,SCNVector3(0,0.08,0))
    fitting(gun,SCNCone(topRadius:0.1,bottomRadius:0.28,height:0.76),m.steel,SCNVector3(0,0.5,0))
    fitting(gun,SCNBox(width:0.22,height:0.2,length:0.62,chamferRadius:0.04),m.dark,SCNVector3(0,0.99,0.15))
    tube(gun,SCNVector3(0,1.0,0.35),SCNVector3(0,1.4,1.8),0.035,m.dark)
    fitting(gun,SCNBox(width:0.08,height:0.32,length:0.19,chamferRadius:0.01),m.steel,SCNVector3(-0.16,1.08,0.13))
    fitting(gun,SCNBox(width:0.38,height:0.055,length:0.32,chamferRadius:0.07),m.dark,SCNVector3(0,0.63,-0.45))
    tube(gun,SCNVector3(0,0.3,0),SCNVector3(0,0.6,-0.45),0.04,m.steel)
    ring(gun,SCNVector3(0.09,1.29,0.49),0.075,0.009,m.dark,axis:"z")
    for side in [-1.0,1.0] {tube(gun,SCNVector3(side*0.16,0.95,-0.14),SCNVector3(side*0.22,0.95,-0.38),0.025,m.dark)}
}
func buildBridge(_ parent:SCNNode,_ m:VIICMaterials) {
    part(parent,towerShell(y0:3.02,y1:5.97,w0:1.45,w1:1.29,front:3.05,rear:2.0,zOffset:-0.15),m.tower)
    part(parent,towerFloor(y:5.98,width:1.29,front:3.05,rear:2.0,zOffset:-0.15),m.steel)
    part(parent,towerFloor(y:5.99,width:1.18,front:2.71,rear:1.61,zOffset:-0.15),m.timber)
    part(parent,towerShell(y0:5.98,y1:7.08,w0:1.29,w1:1.46,front:2.82,rear:1.72,zOffset:-0.15,thickness:0.105),m.tower)
    for i in 0..<80 {
        let a=Double(i)*2 * .pi/80,b=Double(i+1)*2 * .pi/80
        func pt(_ a:Double,_ width:Double,_ y:Double)->SCNVector3 {SCNVector3(sin(a)*width,y,-0.15-cos(a)*(cos(a)>0 ? 2.82:1.72))}
        tube(parent,pt(a,1.465,7.095),pt(b,1.465,7.095),0.036,m.wornEdge)
        if cos(a)>0.05 {
            let pa=pt(a,1.5,6.72),pb=pt(b,1.5,6.72)
            tube(parent,pa,pb,0.06,m.steel)
        }
    }
    // Slatted bridge lining, compass binnacle and UZO binocular pedestal.
    for side in [-1.0,1.0] {
        for i in 0..<9 {
            fitting(parent,SCNBox(width:0.055,height:0.66,length:0.095,chamferRadius:0.012),m.dark,SCNVector3(side*1.27,6.48,-0.9+Double(i)*0.22))
        }
        fitting(parent,SCNBox(width:0.36,height:0.2,length:0.75,chamferRadius:0.035),m.dark,SCNVector3(side*0.97,6.22,0.45))
        // Recessed navigation lamps and housings.
        fitting(parent,SCNBox(width:0.12,height:0.26,length:0.4,chamferRadius:0.04),m.dark,SCNVector3(side*1.41,6.41,-0.38))
        let lens=material(side<0 ? 0x863a30:0x347562,rough:0.23)
        fitting(parent,SCNSphere(radius:0.07),lens,SCNVector3(side*1.49,6.43,-0.46))
    }
    fitting(parent,SCNCylinder(radius:0.16,height:0.72),m.steel,SCNVector3(0,6.36,-1.48))
    fitting(parent,SCNSphere(radius:0.23),m.dark,SCNVector3(0,6.76,-1.48))
    for x in [-0.115,0.115] {
        tube(parent,SCNVector3(x,6.83,-1.29),SCNVector3(x,6.89,-1.92),0.064,m.dark)
        let glass=material(0x203d46,metal:0.35,rough:0.12)
        let n=fitting(parent,SCNCylinder(radius:0.052,height:0.008),glass,SCNVector3(x,6.89,-1.927));n.eulerAngles.x = .pi/2
    }
    // Aft AA platform: circular deck, stanchions, toe rail and horizontal safety rails.
    part(parent,horizontalDisk(1.56,1.68,5.91,3.15),m.timber)
    for level in [6.35,6.94] {for i in 0..<52 {
        let a=Double(i)/52*2 * .pi,b=Double(i+1)/52*2 * .pi
        tube(parent,SCNVector3(sin(a)*1.58,level,3.15+cos(a)*1.69),SCNVector3(sin(b)*1.58,level,3.15+cos(b)*1.69),0.026,m.steel)
    }}
    for i in 0..<16 {
        let a=Double(i)/16*2 * .pi
        tube(parent,SCNVector3(sin(a)*1.58,5.88,3.15+cos(a)*1.69),SCNVector3(sin(a)*1.58,6.96,3.15+cos(a)*1.69),0.027,m.steel)
    }
    for side in [-1.0,1.0] {
        tube(parent,SCNVector3(side*0.9,3.12,2.3),SCNVector3(side*1.45,5.85,3.8),0.09,m.steel)
        tube(parent,SCNVector3(side*1.21,3.25,1.35),SCNVector3(side*1.21,5.9,1.35),0.035,m.dark)
        tube(parent,SCNVector3(side*1.21,3.25,1.87),SCNVector3(side*1.21,5.9,1.87),0.035,m.dark)
        for i in 0..<9 {tube(parent,SCNVector3(side*1.24,3.4+Double(i)*0.29,1.35),SCNVector3(side*1.24,3.4+Double(i)*0.29,1.87),0.027,m.steel)}
        // Main air induction trunks follow the aft tower.
        tube(parent,SCNVector3(side*0.63,3.2,2.05),SCNVector3(side*0.63,5.8,2.05),0.19,m.steel)
        fitting(parent,SCNSphere(radius:0.22),m.dark,SCNVector3(side*0.63,5.8,2.05))
    }
}
