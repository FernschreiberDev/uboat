import AppKit
import SceneKit
import simd

// Stern and bow gear of the detailed VIIC, fitted to the hull surface.

// MARK: - Surface patches

/// Elliptical patch lying on the side of the hull, centred at (cz, cy) in the (z, y) plane.
func hullSidePatch(side:Double,cz:Double,cy:Double,rz:Double,ry:Double,offset:Double,rings:Int=4,segments:Int=32)->SCNGeometry {
    var v=[SCNVector3](),uv=[CGPoint](),ix=[Int32]()
    func point(_ z:Double,_ y:Double)->SCNVector3 {
        let w=max(0,detailedHalfWidth(z,y))
        var n=detailedNormal(z:z,y:y);n.x *= side
        uv.append(CGPoint(x:(z+33.55)/67.1,y:0.2+(y+3)/15))
        return vec(simd_double3(side*w,y,z)+n*offset)
    }
    v.append(point(cz,cy))
    for i in 1...rings {
        let rho=Double(i)/Double(rings)
        for j in 0..<segments {
            let a=Double(j)/Double(segments)*2 * .pi
            v.append(point(cz+rho*rz*cos(a),cy+rho*ry*sin(a)))
        }
    }
    for j in 0..<segments {ix += [0,Int32(1+j),Int32(1+(j+1)%segments)]}
    for i in 0..<rings-1 {for j in 0..<segments {
        let a=Int32(1+i*segments+j),b=Int32(1+i*segments+(j+1)%segments),c=a+Int32(segments),d=b+Int32(segments)
        ix += [a,c,b,b,c,d]
    }}
    var n=detailedNormal(z:cz,y:cy);n.x *= side
    return facingMesh(v,ix,outward:n,uv:uv)
}

/// Local frame on the hull side: z outward along the normal, y up the surface, x along the hull
/// (towards the bow on starboard, towards the stern on port, so text reads left to right).
func hullFrame(side:Double,z:Double,y:Double,lift:Double=0)->simd_float4x4 {
    var n=detailedNormal(z:z,y:y);n.x *= side
    let up=simd_normalize(simd_double3(0,1,0)-n*n.y)
    let along=simd_normalize(simd_cross(up,n))
    let p=simd_double3(side*max(0,detailedHalfWidth(z,y)),y,z)+n*lift
    func f(_ v:simd_double3)->SIMD4<Float> {SIMD4<Float>(Float(v.x),Float(v.y),Float(v.z),0)}
    return simd_float4x4(columns:(f(along),f(up),f(n),SIMD4<Float>(Float(p.x),Float(p.y),Float(p.z),1)))
}

/// Tubes along a polyline with rounded joints.
func railPath(_ parent:SCNNode,_ pts:[SCNVector3],_ radius:CGFloat,_ mat:SCNMaterial) {
    for i in 0..<pts.count-1 {tube(parent,pts[i],pts[i+1],radius,mat)}
    for p in pts.dropFirst().dropLast() {fitting(parent,SCNSphere(radius:radius),mat,p)}
}

/// Flat profile drawn in the (z, y) plane and extruded symmetrically across the centreline.
@discardableResult func centrelinePlate(_ parent:SCNNode,_ pts:[(Double,Double)],thickness:Double,chamfer:CGFloat=0.01,_ mat:SCNMaterial,x:Double=0)->SCNNode {
    let path=NSBezierPath()
    path.move(to:NSPoint(x:pts[0].0,y:pts[0].1))
    for p in pts.dropFirst() {path.line(to:NSPoint(x:p.0,y:p.1))}
    path.close();path.flatness=0.002
    let shape=SCNShape(path:path,extrusionDepth:thickness);shape.chamferRadius=chamfer
    let n=part(parent,shape,mat,SCNVector3(x,0,0))
    n.eulerAngles.y = -.pi/2
    return n
}

// MARK: - Stern

func buildDetailedStern(_ root:SCNNode,_ fixed:SCNNode,_ m:VIICMaterials)->[SCNNode] {
    let L=DetailedLayout.self
    var screws=[SCNNode]()
    for side in [-1.0,1.0] {
        let x=side*L.shaftX,y=L.shaftY
        // Shaft leaves the hull through a faired stern-tube boss.
        let exitZ=detailedSurfaceZ(x:L.shaftX,y:y,from:18,to:28) ?? 24.8
        let boss=fitting(fixed,SCNCone(topRadius:0.12,bottomRadius:0.36,height:2.2),m.hull,SCNVector3(x,y,exitZ+0.55))
        boss.eulerAngles.x = .pi/2
        tube(fixed,SCNVector3(x,y,exitZ-0.4),SCNVector3(x,y,L.screwZ-0.28),0.095,m.steel)
        // Strut bearing ("Wellenbock") with a streamlined arm up into the overhang.
        let bearing=fitting(fixed,SCNCylinder(radius:0.165,height:0.56),m.dark,SCNVector3(x,y,L.strutZ));bearing.eulerAngles.x = .pi/2
        var p=simd_double3(side*L.shaftX,y,L.strutZ)
        let dir=simd_normalize(simd_double3(-side*0.42,1,0.1))
        for _ in 0..<200 {if detailedHalfWidth(p.z,p.y)>abs(p.x) {break};p+=dir*0.02}
        streamlinedBar(fixed,SCNVector3(x,y+0.1,L.strutZ),vec(p+dir*0.25),thickness:0.1,chord:0.46,m.hull)
        // Sheet-metal fairing between the strut bearing and the hub.
        let fairing=fitting(fixed,SCNCone(topRadius:0.13,bottomRadius:0.15,height:0.3),m.dark,SCNVector3(x,y,L.strutZ+0.43));fairing.eulerAngles.x = .pi/2
        // Zinc protection plates beside the shaft exit.
        for dz in [0.4,1.1] {
            let f=SCNNode();f.simdTransform=hullFrame(side:side,z:exitZ-dz,y:y+0.55,lift:0.02);fixed.addChildNode(f)
            fitting(f,SCNBox(width:0.32,height:0.14,length:0.035,chamferRadius:0.01),m.steel)
        }
        // Guard frame at shaft height: from the bearing, round the screw tips, to the plane tip.
        let guardPts:[(Double,Double)]=[(1.53,27.95),(2.25,27.98),(2.84,28.24),(3.06,28.72),(3.06,29.38),(2.88,29.9)]
        railPath(fixed,guardPts.map{SCNVector3(side*$0.0,y,$0.1)},0.045,m.dark)
        let tip=fitting(fixed,SCNCapsule(capRadius:0.075,height:0.36),m.dark,SCNVector3(side*2.84,y,L.sternPlaneZ));tip.eulerAngles.z = .pi/2
        let screw=detailedScrew(side:side,m);root.addChildNode(screw);screws.append(screw)
    }
    // After planes on one common shaft, pivoting at 30 % chord.
    let planes=SCNNode();planes.name="sternPlanes";planes.position=SCNVector3(0,L.sternPlaneY,L.sternPlaneZ);root.addChildNode(planes)
    let chord={(t:Double)->Double in L.sternPlaneChord*(1.04-0.08*t)}
    for side in [-1.0,1.0] {
        let g=streamlinedFoil(span:L.sternPlaneTip-0.25,chord:chord,lead:{t in -0.3*chord(t)},thickness:0.12,tipRound:0.08,map:{v in SCNVector3(CGFloat(side)*(0.25+v.y),v.x,v.z)},mirrored:side>0)
        part(planes,g,m.hull)
        tube(planes,SCNVector3(side*0.1,0,0),SCNVector3(side*0.5,0,0),0.07,m.dark)
    }
    // Twin balanced rudders under the overhang; their heels are held by the skeg arms.
    for side in [-1.0,1.0] {
        let rudder=SCNNode();rudder.name="rudder";rudder.position=SCNVector3(side*L.rudderX,0,L.rudderZ);root.addChildNode(rudder)
        let under=(0...6).map{detailedUnderside(z:L.rudderZ-0.45+Double($0)*0.2,x:L.rudderX)}.min() ?? 0.3
        let top=under+0.12,span=top-L.rudderHeel
        let rc={(t:Double)->Double in L.rudderChord*(0.94+0.1*t)}
        let g=streamlinedFoil(span:span,chord:rc,lead:{t in -L.rudderStock*rc(t)},thickness:0.14,tipRound:0,rootRound:0.09,map:{v in SCNVector3(v.x,v.y+CGFloat(L.rudderHeel),v.z)})
        part(rudder,g,m.hull)
        fitting(rudder,SCNCylinder(radius:0.08,height:0.4),m.dark,SCNVector3(0,top+0.12,0))
        fitting(rudder,SCNCylinder(radius:0.07,height:0.2),m.dark,SCNVector3(0,L.rudderHeel-0.06,0))
    }
    // Skeg protecting the rudders from grounding, with two arms to the rudder heels.
    var skeg=[(Double,Double)]()
    for z in stride(from:24.9,through:29.25,by:0.25) {skeg.append((z,HullSection2(z:z).keelY+0.3))}
    skeg += [(29.3,-1.3),(29.05,-2.26),(26.8,-2.2),(25.4,-2.08),(24.9,HullSection2(z:24.9).keelY-0.03)]
    centrelinePlate(fixed,skeg.reversed(),thickness:0.16,chamfer:0.05,m.hull)
    for side in [-1.0,1.0] {
        streamlinedBar(fixed,SCNVector3(0,-2.14,28.95),SCNVector3(side*L.rudderX,L.rudderHeel-0.08,L.rudderZ),thickness:0.09,chord:0.22,m.hull)
    }
    // Stern torpedo tube housing ending the aft body between the rudders, with its closed shutter.
    let tubeY=L.sternTubeY,endZ=32.8
    let housing=fitting(fixed,SCNCylinder(radius:0.33,height:0.9),m.hull,SCNVector3(0,tubeY,endZ-0.45));housing.eulerAngles.x = .pi/2
    let lip=fitting(fixed,SCNCylinder(radius:0.35,height:0.06),m.dark,SCNVector3(0,tubeY,endZ-0.02));lip.eulerAngles.x = .pi/2
    let shutter=fitting(fixed,SCNCylinder(radius:0.285,height:0.05),m.hull,SCNVector3(0,tubeY,endZ+0.02));shutter.eulerAngles.x = .pi/2
    ring(fixed,SCNVector3(0,tubeY,endZ+0.012),0.3,0.014,m.recess,axis:"z")
    for dx in [-0.12,0.12] {fitting(fixed,SCNBox(width:0.08,height:0.07,length:0.08,chamferRadius:0.02),m.dark,SCNVector3(dx,tubeY+0.3,endZ+0.01))}
    return screws
}

// MARK: - Bow

/// Opening cut in the outer hull by a bow tube running parallel to the centre line: the hull
/// stations where its outline leaves the hull (forward end near the stem, aft end at the muzzle).
func tubeOpening(side:Double,y ty:Double)->(front:Double,aft:Double) {
    let L=DetailedLayout.self
    var zs=[Double]()
    for i in 0..<48 {
        let a=Double(i)/48*2 * .pi
        let x=L.tubeX+L.tubeRadius*cos(a),y=ty+L.tubeRadius*sin(a)
        if let z=detailedSurfaceZ(x:x,y:y,from:DetailedHull.bowZ,to:-24) {zs.append(z)}
    }
    return (zs.min() ?? -31,zs.max() ?? -28.5)
}

/// Flush shutter over a bow tube opening. In side view it is a long rounded rectangle, as on U-995;
/// its forward edge keeps clear of the stem, which chamfers the lower forward corner.
struct TubeShutter {
    let yBottom:Double,yTop:Double,zFront:Double,zAft:Double
    static let stemClearance=0.2,corner=0.11
    init(side:Double,tubeY:Double,below:Double,above:Double) {
        let o=tubeOpening(side:side,y:tubeY)
        yBottom=tubeY-below;yTop=tubeY+above
        zFront=o.front-0.12;zAft=o.aft+0.16
    }
    func front(_ y:Double)->Double {max(zFront,DetailedHull.stemZ(atHeight:y)+TubeShutter.stemClearance)}
    /// Forward and aft limits at height y, with rounded corners.
    func span(_ y:Double)->(Double,Double) {
        let c=TubeShutter.corner,d=min(y-yBottom,yTop-y)
        let cut=d<c ? c-sqrt(max(0,c*c-(c-d)*(c-d))) : 0
        return (front(y)+cut,zAft-cut)
    }
    /// Closed boundary in the (z, y) plane (first point repeated at the end), finely subdivided so
    /// that it follows the curved plating: aft edge up, top edge forward, front edge down, bottom aft.
    func boundary(_ n:Int=28,along m:Int=40)->[(Double,Double)] {
        var pts=[(Double,Double)]()
        for i in 0..<n {let y=yBottom+(yTop-yBottom)*Double(i)/Double(n);pts.append((span(y).1,y))}
        let top=span(yTop),bottom=span(yBottom)
        for i in 0..<m {pts.append((top.1+(top.0-top.1)*Double(i)/Double(m),yTop))}
        for i in 0..<n {let y=yTop-(yTop-yBottom)*Double(i)/Double(n);pts.append((span(y).0,y))}
        for i in 0..<m {pts.append((bottom.0+(bottom.1-bottom.0)*Double(i)/Double(m),yBottom))}
        pts.append(pts[0])
        return pts
    }
}

/// Point on the hull side at (z, y), lifted along the outward normal.
func hullPoint(side:Double,z:Double,y:Double,lift:Double)->SCNVector3 {
    var n=detailedNormal(z:z,y:y);n.x *= side
    return vec(simd_double3(side*max(0,detailedHalfWidth(z,y)),y,z)+n*lift)
}

func buildTubeShutter(_ fixed:SCNNode,_ m:VIICMaterials,side:Double,_ sh:TubeShutter) {
    // Shutter plate following the bow plating.
    var v=[SCNVector3](),uv=[CGPoint](),ix=[Int32]()
    let nu=26,nv=12
    for j in 0...nv {
        let y=sh.yBottom+(sh.yTop-sh.yBottom)*Double(j)/Double(nv),(z0,z1)=sh.span(y)
        for i in 0...nu {
            let z=z0+(z1-z0)*Double(i)/Double(nu)
            v.append(hullPoint(side:side,z:z,y:y,lift:0.013))
            uv.append(CGPoint(x:(z+33.55)/67.1,y:0.2+(y+3)/15))
        }
    }
    for j in 0..<nv {for i in 0..<nu {
        let a=Int32(j*(nu+1)+i),b=a+Int32(nu+1)
        ix += [a,a+1,b,a+1,b+1,b]
    }}
    var n=detailedNormal(z:(sh.zFront+sh.zAft)/2,y:(sh.yBottom+sh.yTop)/2);n.x *= side
    part(fixed,facingMesh(v,ix,outward:n,uv:uv),m.hull).name="tubeShutter"
    // Dark seam around the plate.
    let b=sh.boundary()
    var sv=[SCNVector3](),six=[Int32]()
    let cz=(sh.zFront+sh.zAft)/2,cy=(sh.yBottom+sh.yTop)/2
    for p in b {
        var dz=p.0-cz,dy=(p.1-cy)*3
        let l=max(1e-6,hypot(dz,dy));dz/=l;dy/=l
        sv.append(hullPoint(side:side,z:p.0-dz*0.012,y:p.1-dy*0.012,lift:0.007))
        sv.append(hullPoint(side:side,z:p.0+dz*0.04,y:p.1+dy*0.04,lift:0.007))
    }
    for i in 0..<b.count-1 {let a=Int32(2*i);six += [a,a+2,a+1,a+1,a+2,a+3]}
    part(fixed,facingMesh(sv,six,outward:n),m.recess)
}

func buildDetailedBow(_ root:SCNNode,_ fixed:SCNNode,_ m:VIICMaterials) {
    let L=DetailedLayout.self,H=DetailedHull.self
    // Four flush tube shutters, two per side, stacked with a narrow gap between them.
    for side in [-1.0,1.0] {
        buildTubeShutter(fixed,m,side:side,TubeShutter(side:side,tubeY:L.upperTubeY,below:0.47,above:0.47))
        buildTubeShutter(fixed,m,side:side,TubeShutter(side:side,tubeY:L.lowerTubeY,below:0.47,above:0.47))
    }
    // Forward planes low on the bow, on a common shaft, with guard frames and guy wires.
    let planes=SCNNode();planes.name="bowPlanes";planes.position=SCNVector3(0,L.bowPlaneY,L.bowPlaneZ);root.addChildNode(planes)
    let chord={(t:Double)->Double in L.bowPlaneChord*(1.03-0.1*t)}
    for side in [-1.0,1.0] {
        let g=streamlinedFoil(span:L.bowPlaneTip-0.35,chord:chord,lead:{t in -0.3*chord(t)},thickness:0.11,tipRound:0.08,map:{v in SCNVector3(CGFloat(side)*(0.35+v.y),v.x,v.z)},mirrored:side>0)
        part(planes,g,m.hull)
    }
    for side in [-1.0,1.0] {
        let y=L.bowPlaneY,dz=L.bowPlaneZ+25.8
        let hullZ = -28.3+dz,hullX=max(0.05,detailedHalfWidth(hullZ,y+0.12))
        let frame:[SCNVector3]=[SCNVector3(side*(hullX-0.05),y+0.12,hullZ),SCNVector3(side*1.3,y+0.04,-27.95+dz),SCNVector3(side*2.18,y,-27.42+dz),SCNVector3(side*2.78,y,-26.74+dz),SCNVector3(side*2.95,y,-26.12+dz),SCNVector3(side*2.9,y,L.bowPlaneZ)]
        railPath(fixed,frame,0.045,m.dark)
        let tip=fitting(fixed,SCNCapsule(capRadius:0.075,height:0.34),m.dark,SCNVector3(side*2.87,y,L.bowPlaneZ));tip.eulerAngles.z = .pi/2
        let aftZ = -22.8,aftY = -1.2
        tube(fixed,SCNVector3(side*2.9,y,L.bowPlaneZ+0.1),SCNVector3(side*(detailedHalfWidth(aftZ,aftY)-0.02),aftY,aftZ),0.012,m.dark)
    }
    // Net cutter: serrated saw on the stem head carrying the forward jumping wire.
    let base=(-33.25,H.deckHeight(-33.25)+0.03),top=(-30.4,4.55)
    let d=(top.0-base.0,top.1-base.1),len=hypot(d.0,d.1),t=(d.0/len,d.1/len),n=(-t.1,t.0)
    var saw=[(Double,Double)]()
    saw.append((base.0+n.0*(-0.04),base.1+n.1*(-0.04)))
    saw.append((top.0+n.0*(-0.04),top.1+n.1*(-0.04)))
    let teeth=13
    for k in stride(from:teeth,through:1,by:-1) {
        let s1=Double(k)/Double(teeth),s0=Double(k-1)/Double(teeth),sm=(s0+s1)/2
        func at(_ s:Double,_ h:Double)->(Double,Double) {(base.0+d.0*s+n.0*h,base.1+d.1*s+n.1*h)}
        saw.append(at(s1,0.1));saw.append(at(sm-0.012,0.25));saw.append(at(s0+0.01,0.1))
    }
    centrelinePlate(fixed,saw,thickness:0.035,chamfer:0.004,m.steel)
    tube(fixed,SCNVector3(0,top.1,top.0),SCNVector3(0,H.deckHeight(top.0),top.0),0.05,m.dark)
    tube(fixed,SCNVector3(0,4.2,-30.62),SCNVector3(0,H.deckHeight(-29.15),-29.15),0.04,m.dark)
    fitting(fixed,SCNSphere(radius:0.075),m.dark,SCNVector3(0,top.1,top.0))
    // Lower net saw on the stem bar, along the forefoot below the tubes.
    var stem=[(Double,Double)]()
    for i in 0...18 {let y = -0.25-1.0*Double(i)/18;stem.append((H.stemZ(atHeight:y),y))}
    var lower=[(Double,Double)](),outer=[(Double,Double)]()
    for i in 0..<stem.count {
        let a=stem[max(0,i-1)],b=stem[min(stem.count-1,i+1)]
        let tz=b.0-a.0,ty=b.1-a.1,l=max(1e-6,hypot(tz,ty))
        let nz=ty/l,ny = -tz/l
        lower.append((stem[i].0+nz*0.02,stem[i].1+ny*0.02))
        outer.append((stem[i].0+nz*0.17,stem[i].1+ny*0.17))
        if i<stem.count-1 {
            let c=((stem[i].0+stem[i+1].0)/2,(stem[i].1+stem[i+1].1)/2)
            outer.append((c.0+nz*0.3,c.1+ny*0.3))
        }
    }
    centrelinePlate(fixed,lower+outer.reversed(),thickness:0.035,chamfer:0.004,m.steel)
    // Starboard Hall stockless anchor stowed in its hawse pocket above the tube shutters.
    let az = -29.35,ay=2.1,prz=0.58,pry=0.5
    part(fixed,hullSidePatch(side:1,cz:az,cy:ay,rz:prz,ry:pry,offset:0.008),m.recess)
    var rim=[SCNVector3]()
    for i in 0...40 {
        let a=Double(i)/40*2 * .pi
        rim.append(hullPoint(side:1,z:az+prz*1.04*cos(a),y:ay+pry*1.04*sin(a),lift:0.02))
    }
    railPath(fixed,rim,0.028,m.hull)
    let anchor=SCNNode();anchor.simdTransform=hullFrame(side:1,z:az,y:ay,lift:0.05);fixed.addChildNode(anchor)
    fitting(anchor,SCNCylinder(radius:0.1,height:0.012),m.recess,SCNVector3(0,0.2,-0.01)).eulerAngles.x = .pi/2
    fitting(anchor,SCNBox(width:0.1,height:0.5,length:0.09,chamferRadius:0.03),m.dark,SCNVector3(0,0.02,0))
    fitting(anchor,SCNBox(width:0.44,height:0.14,length:0.13,chamferRadius:0.05),m.dark,SCNVector3(0,-0.22,0))
    for s in [-1.0,1.0] {
        let fluke=fitting(anchor,SCNBox(width:0.16,height:0.46,length:0.07,chamferRadius:0.035),m.dark,SCNVector3(s*0.2,-0.04,0.02))
        fluke.eulerAngles.z = CGFloat(-s*0.18)
        fitting(anchor,SCNSphere(radius:0.05),m.dark,SCNVector3(s*0.22,0.2,0.02))
    }
}

// MARK: - Markings and flood openings

/// Flood holes of the stern tanks and of the saddle tanks.
func buildDetailedMarkings(_ fixed:SCNNode,_ m:VIICMaterials) {
    for side in [-1.0,1.0] {
        // Flood holes of the stern buoyancy and ballast tanks below the knuckle.
        for z in [30.15,30.7,31.25] {for y in [0.95,1.22] {
            part(fixed,hullSidePatch(side:side,cz:z+(y>1 ? 0.25:0),cy:y,rz:0.17,ry:0.055,offset:0.006,rings:2,segments:20),m.recess)
        }}
        // Flooding slots along the bottom of the saddle tanks.
        for run in [(-14.2,-8.6),(-5.6,3.4),(6.4,14.2)] {
            var z=run.0
            while z<run.1 {
                for (k,deg) in [132.0,147.0].enumerated() {
                    let a=deg * .pi/180,zz=z+Double(k)*0.27
                    let fz=DetailedHull.saddleTankBulge(zz)
                    let cx=side*DetailedHull.lowerRadius(zz)*0.94
                    let p=simd_double3(cx+side*sin(a)*0.89*fz,-0.13+cos(a)*1.53*fz,zz)
                    let n=simd_normalize(simd_double3(side*sin(a)/0.89,cos(a)/1.53,0))
                    let t=simd_double3(0,0,1),b=simd_cross(n,t)
                    func f4(_ v:simd_double3,_ w:Float=0)->SIMD4<Float> {SIMD4<Float>(Float(v.x),Float(v.y),Float(v.z),w)}
                    let node=SCNNode();node.simdTransform=simd_float4x4(columns:(f4(t),f4(b),f4(n),f4(p+n*0.004,1)));fixed.addChildNode(node)
                    fitting(node,SCNBox(width:0.34,height:0.09,length:0.03,chamferRadius:0.012),m.recess)
                }
                z+=0.62
            }
        }
    }
}
