import AppKit
import SceneKit
import simd

// Deck equipment, masts and jumping wires of the detailed VIIC, placed on its own deck line.

func detailedDeckTop(_ z:Double,x:Double=0)->Double {
    let w=max(0.01,DetailedHull.deckWidth(z))
    return DetailedHull.deckHeight(z)+0.04*(1-pow(min(1,abs(x)/w),2))
}

/// Round pressure-tight hatch with coaming, dogs and handwheel.
func detailedHatch(_ parent:SCNNode,z:Double,x:Double=0,radius:CGFloat=0.46,_ m:VIICMaterials) {
    let h=detailedDeckTop(z,x:x)-0.04
    fitting(parent,SCNCylinder(radius:radius+0.1,height:0.13),m.dark,SCNVector3(x,h+0.07,z))
    fitting(parent,SCNCylinder(radius:radius,height:0.085),m.steel,SCNVector3(x,h+0.17,z))
    ring(parent,SCNVector3(x,h+0.22,z),radius-0.03,0.018,m.wornEdge)
    handwheel(parent,center:SCNVector3(x,h+0.29,z),radius:0.16,mat:m.dark)
    // Hinge on the forward edge, dogs round the rim.
    for s in [-1.0,1.0] {fitting(parent,SCNBox(width:0.14,height:0.12,length:0.2,chamferRadius:0.03),m.dark,SCNVector3(x+s*0.22,h+0.17,z-Double(radius)-0.02))}
    for i in 0..<8 {
        let a=Double(i)*2 * .pi/8+0.2
        fitting(parent,SCNBox(width:0.07,height:0.05,length:0.12,chamferRadius:0.012),m.dark,SCNVector3(x+sin(a)*Double(radius+0.07),h+0.16,z+cos(a)*Double(radius+0.07))).eulerAngles.y=CGFloat(a)
    }
}

/// Removable deck section over an inclined torpedo loading hatch.
func detailedLoadingHatch(_ parent:SCNNode,z:Double,_ m:VIICMaterials) {
    let h=detailedDeckTop(z)
    fitting(parent,SCNBox(width:1.18,height:0.05,length:2.4,chamferRadius:0.02),m.dark,SCNVector3(0,h-0.005,z))
    fitting(parent,SCNBox(width:1.06,height:0.045,length:2.28,chamferRadius:0.02),m.timber,SCNVector3(0,h+0.012,z))
    for dz in [-0.95,0.0,0.95] {
        for s in [-1.0,1.0] {
            let lug=ring(parent,SCNVector3(s*0.36,h+0.05,z+dz),0.045,0.012,m.steel);lug.eulerAngles.z = .pi/2
        }
    }
    for s in [-1.0,1.0] {tube(parent,SCNVector3(s*0.56,h+0.03,z-1.18),SCNVector3(s*0.56,h+0.03,z+1.18),0.018,m.steel)}
}

/// Flush circular lid (marker buoy, ready-use ammunition, KDB well).
func detailedLid(_ parent:SCNNode,z:Double,x:Double=0,radius:CGFloat,_ m:VIICMaterials) {
    let h=detailedDeckTop(z,x:x)
    fitting(parent,SCNCylinder(radius:radius+0.05,height:0.03),m.dark,SCNVector3(x,h,z))
    fitting(parent,SCNCylinder(radius:radius,height:0.035),m.steel,SCNVector3(x,h+0.012,z))
    tube(parent,SCNVector3(x-Double(radius)*0.45,h+0.045,z),SCNVector3(x+Double(radius)*0.45,h+0.045,z),0.014,m.dark)
}

func buildDetailedDeck(_ parent:SCNNode,_ m:VIICMaterials) {
    // Access hatches: forward crew hatch and galley hatch aft of the bridge.
    detailedHatch(parent,z:-13.5,m)
    detailedHatch(parent,z:13.7,m)
    // Deck sections over the forward and aft torpedo loading hatches.
    detailedLoadingHatch(parent,z:-17.6,m)
    detailedLoadingHatch(parent,z:20.6,m)
    // Marker buoys, ready-use ammunition near the gun.
    detailedLid(parent,z:-20.4,radius:0.34,m)
    detailedLid(parent,z:4.4,radius:0.34,m)
    for s in [-1.0,1.0] {detailedLid(parent,z:-6.3,x:s*0.95,radius:0.22,m)}
    // Retractable bollards in pairs.
    for z in [-28.2,-24.4,23.8,27.6] {
        let h=DetailedHull.deckHeight(z)
        for side in [-1.0,1.0] {
            let x=side*DetailedHull.deckWidth(z)*0.66
            fitting(parent,SCNBox(width:0.33,height:0.045,length:0.7,chamferRadius:0.03),m.steel,SCNVector3(x,h+0.03,z))
            for dz in [-0.19,0.19] {
                fitting(parent,SCNCylinder(radius:0.08,height:0.25),m.dark,SCNVector3(x,h+0.15,z+dz))
                fitting(parent,SCNCylinder(radius:0.115,height:0.06),m.steel,SCNVector3(x,h+0.29,z+dz))
            }
        }
    }
    // Capstan, chain and hawse pipe to the starboard anchor pocket.
    let cz = -26.3,ch=DetailedHull.deckHeight(cz)
    fitting(parent,SCNCylinder(radius:0.35,height:0.5),m.dark,SCNVector3(0,ch+0.26,cz))
    fitting(parent,SCNCylinder(radius:0.46,height:0.12),m.steel,SCNVector3(0,ch+0.54,cz))
    for i in 0..<5 {let a=Double(i)*2 * .pi/5;fitting(parent,SCNBox(width:0.06,height:0.3,length:0.12,chamferRadius:0.02),m.dark,SCNVector3(sin(a)*0.36,ch+0.3,cz+cos(a)*0.36)).eulerAngles.y=CGFloat(a)}
    let hawse=(0.66,-28.75)
    fitting(parent,SCNCylinder(radius:0.16,height:0.09),m.dark,SCNVector3(hawse.0,DetailedHull.deckHeight(hawse.1)+0.05,hawse.1))
    for i in 0..<16 {
        let t=Double(i)/15,x=0.3+(hawse.0-0.3)*t,z=cz-0.3+(hawse.1-cz+0.3)*t
        let link=ring(parent,SCNVector3(x,detailedDeckTop(z,x:x)+0.06,z),0.065,0.017,m.dark)
        link.eulerAngles.y=CGFloat(atan2(hawse.0-0.3,hawse.1-cz+0.3))
        if i%2==0 {link.eulerAngles.z = .pi/2}
    }
    // Early-war KDB sound receiver head on the forward deck.
    let kz = -27.75,kh=DetailedHull.deckHeight(kz)
    fitting(parent,SCNCylinder(radius:0.3,height:0.06),m.dark,SCNVector3(0,kh+0.04,kz))
    fitting(parent,SCNCylinder(radius:0.13,height:0.34),m.steel,SCNVector3(0,kh+0.24,kz))
    let dome=fitting(parent,SCNSphere(radius:0.16),m.steel,SCNVector3(0,kh+0.43,kz));dome.scale=SCNVector3(1,0.55,1.35)
    // Ventilation grilles.
    for z in [-15.6,8.0,16.8] {for side in [-1.0,1.0] {
        let x=side*1.2,h=detailedDeckTop(z,x:x)
        fitting(parent,SCNBox(width:0.56,height:0.05,length:1.1,chamferRadius:0.05),m.recess,SCNVector3(x,h,z))
        for i in 0..<8 {tube(parent,SCNVector3(x-0.26,h+0.035,z-0.48+Double(i)*0.135),SCNVector3(x+0.26,h+0.035,z-0.48+Double(i)*0.135),0.022,m.steel)}
    }}
    // Guard rails along the working deck.
    for side in [-1.0,1.0] {
        let zs=Array(stride(from:-19.0,through:-4.0,by:2.5))+Array(stride(from:6.0,through:20.0,by:2.8))
        for z in zs {
            let x=side*(DetailedHull.deckWidth(z)-0.16),h=DetailedHull.deckHeight(z)
            tube(parent,SCNVector3(x,h,z),SCNVector3(x,h+0.85,z),0.027,m.steel)
            fitting(parent,SCNCylinder(radius:0.055,height:0.06),m.dark,SCNVector3(x,h+0.05,z))
        }
        for range in [(-19.0,-4.0),(6.0,20.0)] {for level in [0.4,0.84] {
            for i in 0..<28 {
                let z=range.0+(range.1-range.0)*Double(i)/28,nz=range.0+(range.1-range.0)*Double(i+1)/28
                tube(parent,SCNVector3(side*(DetailedHull.deckWidth(z)-0.16),DetailedHull.deckHeight(z)+level,z),SCNVector3(side*(DetailedHull.deckWidth(nz)-0.16),DetailedHull.deckHeight(nz)+level,nz),0.013,m.dark)
            }
        }}
    }
}

/// Periscopes, direction-finding loop and the jumping wires to the net cutter and stern post.
func buildDetailedMasts(_ root:SCNNode,_ fixed:SCNNode,_ m:VIICMaterials) {
    let T=TowerLayout.self
    // Forward sky periscope and taller aft attack periscope, rising from their standards.
    for (z,height) in [(T.forwardScopeZ,3.0),(T.aftScopeZ,4.1)] {
        let scope=SCNNode();scope.name="periscope";scope.position=SCNVector3(0,T.rim-0.5,z);root.addChildNode(scope)
        tube(scope,SCNVector3(0,0,0),SCNVector3(0,height*0.48,0),0.11,m.dark)
        tube(scope,SCNVector3(0,height*0.42,0),SCNVector3(0,height,0),0.072,m.chrome)
        fitting(scope,SCNBox(width:0.19,height:0.22,length:0.23,chamferRadius:0.075),m.steel,SCNVector3(0,height,0))
        fitting(scope,SCNBox(width:0.11,height:0.095,length:0.012,chamferRadius:0.014),m.recess,SCNVector3(0,height+0.025,-0.122))
    }
    // Retractable direction-finding loop on the port side of the bridge.
    tube(fixed,SCNVector3(-0.62,T.ledge,-2.6),SCNVector3(-0.62,T.rim+0.62,-2.6),0.05,m.dark)
    let loop=ring(fixed,SCNVector3(-0.62,T.rim+0.78,-2.6),0.32,0.024,m.dark,axis:"z");loop.scale.x=0.8
    let insulator=material(0x9faaa0,rough:0.3)
    func wire(_ a:SCNVector3,_ b:SCNVector3,_ at:[Double]) {
        tube(fixed,a,b,0.013,m.dark)
        for f in at {
            let p=SCNVector3(a.x+(b.x-a.x)*CGFloat(f),a.y+(b.y-a.y)*CGFloat(f),a.z+(b.z-a.z)*CGFloat(f))
            fitting(fixed,SCNSphere(radius:0.062),insulator,p).scale=SCNVector3(0.6,0.7,1.5)
        }
    }
    // One forward jumping wire (net deflector) from the tower front to the net cutter,
    // two aft jumping wires from the platform to the stern post: all three serve as aerials.
    let nose=SCNVector3(0,T.rim+0.06,T.front-0.06)
    fitting(fixed,SCNBox(width:0.08,height:0.16,length:0.14,chamferRadius:0.02),m.dark,SCNVector3(0,T.rim+0.02,T.front+0.02))
    wire(nose,SCNVector3(0,4.55,-30.4),[0.03,0.052,0.074])
    let pz=30.4,ph=DetailedHull.deckHeight(pz)
    let post=SCNVector3(0,ph+0.62,pz)
    for side in [-1.0,1.0] {
        let a=T.platformZ+0.95,x=side*sqrt(max(0,T.railRadius*T.railRadius-0.95*0.95))
        wire(SCNVector3(x,T.ledge+0.96,a),post,[0.03,0.05,0.07])
    }
    // Short stern post carrying the stern light.
    tube(fixed,SCNVector3(0,ph,pz),post,0.032,m.dark)
    tube(fixed,SCNVector3(0,ph,pz+0.55),SCNVector3(0,ph+0.45,pz+0.05),0.022,m.dark)
    fitting(fixed,SCNBox(width:0.12,height:0.12,length:0.12,chamferRadius:0.03),m.dark,SCNVector3(0,ph+0.7,pz))
    let lamp=material(0xd9dccb,rough:0.2);lamp.emission.contents=color(0x3a3a30)
    fitting(fixed,SCNSphere(radius:0.05),lamp,SCNVector3(0,ph+0.7,pz+0.065))
}
