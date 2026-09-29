import AppKit
import SceneKit
import simd

// Conning tower of the detailed VIIC, after the 1941 survey drawing of U-570 (early tower):
// a narrow U-shaped bridge with a rounded front, a spray ledge at bridge-deck height, a flared
// wind deflector on the coaming and a round AA platform ("Wintergarten") aft, all on one fairing.

enum TowerLayout {
    static let front = -4.45,noseLength=1.25,halfWidth=1.1
    /// Aft end of the bridge coaming, where it opens onto the AA platform.
    static let bridgeAft = -0.33
    static let platformZ=0.91,platformRadius=1.7,fairingRadius=1.24,railRadius=1.64
    static let base=3.0,ledge=4.83,rim=6.38,wall=0.06
    static let forwardScopeZ = -3.35,aftScopeZ = -1.45,uzoZ = -3.95,hatchZ = -2.35
}

/// Half-width of the bridge: rounded nose, then near-parallel sides.
func towerHalfWidth(_ z:Double)->Double {
    let T=TowerLayout.self,d=z-T.front
    if d<=0 {return 0}
    if d<T.noseLength {
        let t=(T.noseLength-d)/T.noseLength
        return T.halfWidth*pow(max(0,1-pow(t,2.2)),1/2.2)
    }
    return T.halfWidth*(1-0.03*min(1,(d-T.noseLength)/3))
}
/// Half-width of the lower fairing: the bridge shape joined to the round part under the platform.
func fairingHalfWidth(_ z:Double)->Double {
    let T=TowerLayout.self,dz=z-T.platformZ
    let circle=abs(dz)<T.fairingRadius ? sqrt(T.fairingRadius*T.fairingRadius-dz*dz) : 0
    return max(z<=T.platformZ ? towerHalfWidth(z) : 0,circle)
}

/// Outline in plan, ordered so the exterior lies on the right when walking along it:
/// starboard from `aft` to the nose, then port back to `aft`. Stations cluster at both ends.
func towerOutline(to aft:Double,count:Int=56,width:(Double)->Double)->[(Double,Double)] {
    let T=TowerLayout.self
    let zs=(0...count).map {i -> Double in
        let t=Double(i)/Double(count)
        return aft+(T.front-aft)*(1-cos(t * .pi))/2
    }
    let starboard=zs.map{(width($0),$0)}
    let port=zs.reversed().dropFirst().map{(-width($0),$0)}
    return starboard+port
}

/// Offset a plan outline along its outward (right-hand) normals by d(z).
/// A closed outline repeats its first point at the end; both copies then move together.
func offsetOutline(_ p:[(Double,Double)],closed:Bool,_ d:(Double)->Double)->[(Double,Double)] {
    let n=p.count
    return (0..<n).map {j in
        var a=p[max(0,j-1)],b=p[min(n-1,j+1)]
        if closed && (j==0 || j==n-1) {a=p[n-2];b=p[1]}
        var tx=b.0-a.0,tz=b.1-a.1
        let l=hypot(tx,tz)
        if l<1e-9 {return p[j]}
        tx/=l;tz/=l
        let o=d(p[j].1)
        return (p[j].0-tz*o,p[j].1+tx*o)
    }
}

/// Wall lofted through rings of one outline: (height, offset along the outline normal).
func outlineWall(_ outline:[(Double,Double)],closed:Bool,rings:[(Double,(Double)->Double)],inward:Bool=false)->SCNGeometry {
    var v=[SCNVector3](),uv=[CGPoint](),ix=[Int32]()
    let n=outline.count
    var arc=[0.0]
    for j in 1..<n {arc.append(arc[j-1]+hypot(outline[j].0-outline[j-1].0,outline[j].1-outline[j-1].1))}
    for r in rings {
        let ring=offsetOutline(outline,closed:closed,r.1)
        for j in 0..<n {
            v.append(SCNVector3(ring[j].0,r.0,ring[j].1))
            uv.append(CGPoint(x:0.05+arc[j]/12,y:0.1+(r.0-TowerLayout.base)/4))
        }
    }
    for k in 0..<rings.count-1 {for j in 0..<n-1 {
        let a=Int32(k*n+j),b=a+1,c=a+Int32(n),d=c+1
        ix += inward ? [a,c,b,b,c,d] : [a,b,c,b,d,c]
    }}
    return mesh(v,ix,uv:uv)
}

/// Flat polygon at height y, fanned from `center` (the polygon must be star-shaped around it).
func flatPolygon(_ pts:[(Double,Double)],y:Double,center:(Double,Double),up:Bool,uvScale:Double=4.6)->SCNGeometry {
    var v=[SCNVector3(center.0,y,center.1)],uv=[CGPoint(x:0.5+center.0/uvScale,y:0.5+center.1/uvScale)],ix=[Int32]()
    for p in pts {v.append(SCNVector3(p.0,y,p.1));uv.append(CGPoint(x:0.5+p.0/uvScale,y:0.5+p.1/uvScale))}
    for j in 0..<pts.count {
        let a=Int32(1+j),b=Int32(1+(j+1)%pts.count)
        ix += [0,a,b]
    }
    // Orient the fan: the outline runs clockwise seen from above, so flip for an upward face.
    let p0=pts[0],p1=pts[1]
    let ny=(p0.1-center.1)*(p1.0-center.0)-(p0.0-center.0)*(p1.1-center.1)
    if (ny>0) != up {for t in stride(from:0,to:ix.count,by:3) {ix.swapAt(t+1,t+2)}}
    return mesh(v,ix,uv:uv)
}

func buildDetailedTower(_ root:SCNNode,_ fixed:SCNNode,_ m:VIICMaterials) {
    let T=TowerLayout.self
    let aftEnd=T.platformZ+T.fairingRadius
    // Lower fairing, flared into the deck.
    let fairing=towerOutline(to:aftEnd,count:72,width:fairingHalfWidth)
    part(fixed,outlineWall(fairing,closed:true,rings:[(T.base,{_ in 0.13}),(T.base+0.22,{_ in 0.035}),(T.base+0.5,{_ in 0}),(T.ledge,{_ in 0})]),m.tower).name="towerFairing"
    // Bridge coaming: open U, vertical sides, wind deflector flaring out at the top front.
    let bridge=towerOutline(to:T.bridgeAft,count:56,width:towerHalfWidth)
    let flare={(z:Double)->Double in 0.4+0.6*min(1,max(0,(T.bridgeAft-z)/(T.bridgeAft-T.front)*1.6))}
    part(fixed,outlineWall(bridge,closed:false,rings:[(T.ledge-0.02,{_ in 0}),(T.rim-0.3,{_ in 0}),(T.rim-0.13,{z in 0.07*flare(z)}),(T.rim,{z in 0.17*flare(z)})]),m.tower).name="bridgeCoaming"
    part(fixed,outlineWall(bridge,closed:false,rings:[(T.ledge,{_ in -T.wall}),(T.rim-0.3,{_ in -T.wall}),(T.rim-0.13,{z in 0.07*flare(z)-T.wall}),(T.rim-0.01,{z in 0.17*flare(z)-T.wall})],inward:true),m.tower)
    // Rounded capping along the coaming.
    let cap=offsetOutline(bridge,closed:false){z in 0.17*flare(z)-T.wall/2}
    for j in 0..<cap.count-1 {tube(fixed,SCNVector3(cap[j].0,T.rim+0.005,cap[j].1),SCNVector3(cap[j+1].0,T.rim+0.005,cap[j+1].1),0.038,m.wornEdge)}
    for p in [cap.first!,cap.last!] {
        fitting(fixed,SCNBox(width:0.1,height:T.rim-T.ledge,length:0.1,chamferRadius:0.02),m.tower,SCNVector3(p.0*0.97,(T.rim+T.ledge)/2,p.1))
    }
    // Spray ledge around the bridge at deck-of-bridge height, meeting the platform edge.
    part(fixed,outlineWall(bridge,closed:false,rings:[(T.ledge-0.05,{_ in 0}),(T.ledge-0.05,{_ in 0.13}),(T.ledge+0.02,{_ in 0.13}),(T.ledge+0.02,{_ in 0})]),m.tower)
    // Bridge and platform deck: one timber floor, closed underneath where it overhangs the fairing.
    let rr=T.railRadius+0.06
    let meet=T.platformZ-sqrt(rr*rr-pow(towerHalfWidth(T.bridgeAft)-T.wall,2))
    let inner=offsetOutline(towerOutline(to:meet,count:48,width:towerHalfWidth),closed:false){_ in -T.wall}
    var floor=inner
    // Platform arc from the port end of the coaming, round the stern side, to the starboard end.
    let a0=atan2(inner.last!.0,inner.last!.1-T.platformZ),a1=atan2(inner.first!.0,inner.first!.1-T.platformZ)
    for i in 1..<40 {
        let a=a0+(a1-a0)*Double(i)/40
        floor.append((sin(a)*rr,T.platformZ+cos(a)*rr))
    }
    part(fixed,flatPolygon(floor,y:T.ledge+0.02,center:(0,T.platformZ-0.6),up:true),m.timber).name="bridgeFloor"
    part(fixed,flatPolygon(floor,y:T.ledge-0.05,center:(0,T.platformZ-0.6),up:false),m.tower)
    // Platform edge (toe plate), brackets under the overhang, railing.
    var edge=[(Double,Double)]()
    for i in 0...40 {let a=a0+(a1-a0)*Double(i)/40;edge.append((sin(a)*rr,T.platformZ+cos(a)*rr))}
    part(fixed,outlineWall(edge,closed:false,rings:[(T.ledge-0.06,{_ in 0}),(T.ledge+0.12,{_ in 0})]),m.tower)
    part(fixed,outlineWall(edge,closed:false,rings:[(T.ledge-0.06,{_ in -0.02}),(T.ledge+0.12,{_ in -0.02})],inward:true),m.tower)
    // Triangular gussets under the overhang, in radial planes.
    for i in 0..<9 {
        let a=a0+(a1-a0)*(Double(i)+0.5)/9,r0=T.fairingRadius-0.03,span=rr-0.08-r0
        let path=NSBezierPath();path.move(to:NSPoint(x:0,y:0));path.line(to:NSPoint(x:0,y:-0.3));path.line(to:NSPoint(x:span,y:0));path.close()
        let g=part(fixed,SCNShape(path:path,extrusionDepth:0.035),m.tower,SCNVector3(sin(a)*r0,T.ledge-0.05,T.platformZ+cos(a)*r0))
        g.eulerAngles.y=CGFloat(a - .pi/2)
    }
    for i in 0...12 {
        let a=a0+(a1-a0)*Double(i)/12,x=sin(a)*T.railRadius,z=T.platformZ+cos(a)*T.railRadius
        tube(fixed,SCNVector3(x,T.ledge,z),SCNVector3(x,T.ledge+0.95,z),0.024,m.steel)
    }
    for level in [0.47,0.95] {for i in 0..<36 {
        let s=a0+(a1-a0)*Double(i)/36,e=a0+(a1-a0)*Double(i+1)/36
        tube(fixed,SCNVector3(sin(s)*T.railRadius,T.ledge+level,T.platformZ+cos(s)*T.railRadius),SCNVector3(sin(e)*T.railRadius,T.ledge+level,T.platformZ+cos(e)*T.railRadius),0.02,m.steel)
    }}
    // 2 cm AA gun of the classic model, moved onto the new platform.
    let flak=SCNNode();flak.position=SCNVector3(0,T.ledge+0.02-5.92,T.platformZ-3.6);fixed.addChildNode(flak)
    buildFlak(flak,m)
    // Fittings on the bridge: UZO pedestal, compass, conning tower hatch, periscope standards.
    fitting(fixed,SCNCylinder(radius:0.13,height:0.86),m.steel,SCNVector3(0,T.ledge+0.45,T.uzoZ))
    fitting(fixed,SCNSphere(radius:0.19),m.dark,SCNVector3(0,T.ledge+0.95,T.uzoZ))
    let glass=material(0x203d46,metal:0.35,rough:0.12)
    for x in [-0.1,0.1] {
        tube(fixed,SCNVector3(x,T.ledge+1.01,T.uzoZ+0.15),SCNVector3(x,T.ledge+1.05,T.uzoZ-0.36),0.055,m.dark)
        fitting(fixed,SCNCylinder(radius:0.045,height:0.008),glass,SCNVector3(x,T.ledge+1.05,T.uzoZ-0.365)).eulerAngles.x = .pi/2
    }
    fitting(fixed,SCNCylinder(radius:0.17,height:0.72),m.steel,SCNVector3(0.52,T.ledge+0.38,-3.55))
    fitting(fixed,SCNSphere(radius:0.19),m.chrome,SCNVector3(0.52,T.ledge+0.78,-3.55)).scale=SCNVector3(1,0.6,1)
    fitting(fixed,SCNCylinder(radius:0.4,height:0.16),m.dark,SCNVector3(0,T.ledge+0.09,T.hatchZ))
    fitting(fixed,SCNCylinder(radius:0.34,height:0.08),m.steel,SCNVector3(0,T.ledge+0.2,T.hatchZ))
    handwheel(fixed,center:SCNVector3(0,T.ledge+0.29,T.hatchZ),radius:0.14,mat:m.dark)
    for z in [T.forwardScopeZ,T.aftScopeZ] {
        let h=T.rim+0.17-T.ledge
        fitting(fixed,SCNCone(topRadius:0.16,bottomRadius:0.27,height:CGFloat(h)),m.steel,SCNVector3(0,T.ledge+h/2,z))
        ring(fixed,SCNVector3(0,T.rim+0.17,z),0.15,0.03,m.dark)
    }
    // Navigation lights in housings on the bridge sides.
    for side in [-1.0,1.0] {
        let z = -2.55,x=side*(towerHalfWidth(z)+0.05)
        fitting(fixed,SCNBox(width:0.13,height:0.28,length:0.42,chamferRadius:0.04),m.dark,SCNVector3(x,T.ledge+0.62,z))
        fitting(fixed,SCNSphere(radius:0.07),material(side<0 ? 0x863a30:0x347562,rough:0.23),SCNVector3(x+side*0.06,T.ledge+0.64,z-0.1))
    }
    // Flood openings in the fairing and boarding steps on the round aft part.
    for side in [-1.0,1.0] {
        for (z,y) in [(-3.2,3.32),(-2.2,3.32),(-1.2,3.32),(-0.9,4.05),(-0.35,4.05)] {
            let x=side*(fairingHalfWidth(z)+0.004)
            let d=(fairingHalfWidth(z+0.05)-fairingHalfWidth(z-0.05))/0.1
            fitting(fixed,SCNBox(width:0.02,height:0.11,length:0.3,chamferRadius:0.01),m.recess,SCNVector3(x,y,z)).eulerAngles.y=CGFloat(side*atan(d))
        }
        let sz=1.35,sx=side*(fairingHalfWidth(sz)+0.09)
        for i in 0..<5 {tube(fixed,SCNVector3(sx,3.38+Double(i)*0.3,sz-0.2),SCNVector3(sx,3.38+Double(i)*0.3,sz+0.2),0.022,m.steel)}
        for dz in [-0.2,0.2] {tube(fixed,SCNVector3(side*(fairingHalfWidth(sz+dz)+0.005),3.38,sz+dz),SCNVector3(sx,3.38,sz+dz),0.018,m.steel)}
    }
    for a in [-0.45,0.45] {
        let x=sin(a)*(T.fairingRadius+0.004),z=aftEnd-T.fairingRadius+cos(a)*(T.fairingRadius+0.004)
        fitting(fixed,SCNBox(width:0.3,height:0.11,length:0.02,chamferRadius:0.01),m.recess,SCNVector3(x,3.4,z)).eulerAngles.y=CGFloat(a)
    }
    // Low tapered fairing in front of the tower foot, as on the U-570 survey drawing.
    let sections:[(Double,Double,Double)]=[(T.front+0.3,0.46,0.86),(T.front-0.25,0.4,0.66),(T.front-0.75,0.25,0.4),(T.front-1.02,0.08,0.2),(T.front-1.08,0.0,0.12)]
    var bv=[SCNVector3](),bix=[Int32](),buv=[CGPoint]()
    let profile:[(Double,Double)]=[(-1,0),(-1,0.72),(-0.62,1),(0,1.03),(0.62,1),(1,0.72),(1,0)]
    for (i,sec) in sections.enumerated() {
        for (j,p) in profile.enumerated() {
            bv.append(SCNVector3(p.0*sec.1,T.base+p.1*sec.2,sec.0))
            buv.append(CGPoint(x:0.3+Double(j)*0.03,y:0.2+Double(i)*0.05))
        }
        if i<sections.count-1 {for j in 0..<profile.count-1 {
            let a=Int32(i*profile.count+j),b=a+Int32(profile.count)
            bix += [a,a+1,b,a+1,b+1,b]
        }}
    }
    part(fixed,mesh(bv,bix,uv:buv),m.tower)
}
