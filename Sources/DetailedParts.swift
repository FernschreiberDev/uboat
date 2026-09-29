import AppKit
import SceneKit
import simd

// Moving gear and hull-fitted parts of the detailed VIIC: streamlined control surfaces,
// real three-bladed screws, shaft lines, stern gear and flush torpedo-tube shutters.

// MARK: - Layout (metres, same frame as the hull)

enum DetailedLayout {
    // Twin screws: 1620 mm three-bladed, turning top outboard (1940 VIIC manual).
    static let shaftX=1.37,shaftY = -1.0,screwZ=28.8,screwRadius=0.81
    static let strutZ=27.95
    // After planes directly behind the screws, 2.25 m² each, on a common shaft.
    static let sternPlaneZ=29.9,sternPlaneY = -1.0,sternPlaneTip=2.7,sternPlaneChord=1.0
    // Twin balanced rudders, 2.75 m² each, hung under the stern overhang and held by skeg arms.
    static let rudderX=0.8,rudderZ=31.35,rudderHeel = -1.85,rudderChord=1.25,rudderStock=0.36
    // Forward planes low on the bow, below the torpedo tubes, 2.40 m² each (axis from U-570 survey).
    static let bowPlaneZ = -24.9,bowPlaneY = -1.45,bowPlaneTip=2.75,bowPlaneChord=1.4
    // Four 53.3 cm bow tubes in two vertical pairs (outer radius), muzzles near frame 106; one stern
    // tube between the rudders.
    static let tubeX=0.55,upperTubeY=0.72,lowerTubeY = -0.28,tubeRadius=0.29,sternTubeY=0.55
}

// MARK: - Hull surface queries

/// Half-width of the detailed hull at station z and height y; negative outside the hull.
func detailedHalfWidth(_ z:Double,_ y:Double)->Double {HullSection2(z:z).halfWidth(y)}

/// Station between z0 and z1 where the hull surface crosses |x| at height y (sign change search).
func detailedSurfaceZ(x:Double,y:Double,from z0:Double,to z1:Double)->Double? {
    let f={(z:Double)->Double in detailedHalfWidth(z,y)-abs(x)}
    var a=z0,b=z1,fa=f(a)
    let fb=f(b)
    if fa*fb>0 {
        // Scan for a bracket when the ends agree in sign.
        var found=false,prev=a,fp=fa
        for i in 1...60 {
            let z=z0+(z1-z0)*Double(i)/60,fz=f(z)
            if fp*fz<=0 {a=prev;b=z;fa=fp;found=true;break}
            prev=z;fp=fz
        }
        if !found {return nil}
    }
    for _ in 0..<40 {
        let m=(a+b)/2,fm=f(m)
        if fa*fm<=0 {b=m} else {a=m;fa=fm}
    }
    return (a+b)/2
}

/// Lowest point of the hull at lateral offset x (underside of the stern overhang, for example).
func detailedUnderside(z:Double,x:Double)->Double {
    let s=HullSection2(z:z)
    var y=s.knuckleY
    while y>s.keelY-0.2 && s.halfWidth(y-0.02)>=abs(x) {y-=0.02}
    var a=y-0.02,b=y
    for _ in 0..<30 {let m=(a+b)/2;if s.halfWidth(m)>=abs(x) {b=m} else {a=m}}
    return b
}

/// Outward normal of the starboard hull surface x = w(y,z) at (y, z).
func detailedNormal(z:Double,y:Double)->simd_double3 {
    let h=0.01
    let dy=(detailedHalfWidth(z,y+h)-detailedHalfWidth(z,y-h))/(2*h)
    let dz=(detailedHalfWidth(z+h,y)-detailedHalfWidth(z-h,y))/(2*h)
    return simd_normalize(simd_double3(1,-dy,-dz))
}

func vec(_ v:simd_double3)->SCNVector3 {SCNVector3(v.x,v.y,v.z)}

/// Build a mesh and fix the winding so the first triangle faces `outward`.
func facingMesh(_ v:[SCNVector3],_ ix:[Int32],outward:simd_double3,uv:[CGPoint]?=nil)->SCNGeometry {
    var ix=ix
    if ix.count>=3 {
        // Use the largest triangle to decide the winding robustly.
        var best=0.0,sign=1.0
        for t in stride(from:0,to:ix.count,by:3) {
            let a=v[Int(ix[t])],b=v[Int(ix[t+1])],c=v[Int(ix[t+2])]
            let u=simd_double3(Double(b.x-a.x),Double(b.y-a.y),Double(b.z-a.z)),w=simd_double3(Double(c.x-a.x),Double(c.y-a.y),Double(c.z-a.z))
            let n=simd_cross(u,w),l=simd_length(n)
            if l>best {best=l;sign=simd_dot(n,outward)}
        }
        if sign<0 {for t in stride(from:0,to:ix.count,by:3) {ix.swapAt(t+1,t+2)}}
    }
    return mesh(v,ix,uv:uv)
}

// MARK: - Control surfaces

/// Symmetric NACA 00xx foil. Span along +Y, chord along +Z from the leading edge, thickness along X.
/// `chord` and `lead` give the local chord and leading-edge station for the normalised span t.
/// Vertices can be remapped (for horizontal planes); `mirrored` flips the winding for reflections.
func streamlinedFoil(span:Double,chord:(Double)->Double,lead:(Double)->Double,thickness:Double,tipRound:Double=0.14,rootRound:Double=0,sections:Int=24,points:Int=14,map:(SCNVector3)->SCNVector3={$0},mirrored:Bool=false)->SCNGeometry {
    var xs=[Double]()
    for i in 0...points {xs.append((1-cos(Double(i)/Double(points) * .pi))/2)}
    func yt(_ x:Double)->Double {5*thickness*(0.2969*sqrt(x)-0.1260*x-0.3516*x*x+0.2843*x*x*x-0.1036*x*x*x*x)}
    var ring=[(Double,Double)]()
    for i in stride(from:points,through:0,by:-1) {ring.append((xs[i],yt(xs[i])))}
    for i in 1..<points {ring.append((xs[i],-yt(xs[i])))}
    let n=ring.count
    var v=[SCNVector3](),uv=[CGPoint](),ix=[Int32]()
    // Texture coordinates at hull plating scale (67 m along u, about 15 m along v).
    for s in 0...sections {
        let t=Double(s)/Double(sections)
        var k=1.0
        if tipRound>0 && t>1-tipRound {let u=(t-(1-tipRound))/tipRound;k=sqrt(max(0,1-u*u))}
        if rootRound>0 && t<rootRound {let u=(rootRound-t)/rootRound;k=min(k,sqrt(max(0,1-u*u)))}
        let c=chord(t),mid=lead(t)+c/2,cc=max(c*k,0.004),y=t*span
        for p in ring {
            let z=mid+(p.0-0.5)*cc
            v.append(map(SCNVector3(p.1*c*max(k,0.05),y,z)))
            uv.append(CGPoint(x:0.46+z/67.1+(p.1>=0 ? 0:0.03),y:0.3+y/15))
        }
    }
    for s in 0..<sections {for j in 0..<n {
        let a=Int32(s*n+j),b=Int32(s*n+(j+1)%n),c=a+Int32(n),d=b+Int32(n)
        ix += [a,b,c,b,d,c]
    }}
    // End caps.
    for (s,root) in [(0,true),(sections,false)] {
        let t=Double(s)/Double(sections),c=chord(t)
        v.append(map(SCNVector3(0,t*span,lead(t)+c/2)))
        uv.append(CGPoint(x:0.46+(lead(t)+c/2)/67.1,y:0.3+t*span/15))
        let center=Int32(v.count-1)
        for j in 0..<n {
            let a=Int32(s*n+j),b=Int32(s*n+(j+1)%n)
            ix += root ? [center,b,a] : [center,a,b]
        }
    }
    if mirrored {for t in stride(from:0,to:ix.count,by:3) {ix.swapAt(t+1,t+2)}}
    return mesh(v,ix,uv:uv)
}

/// Streamlined bar between two points, its section elongated along the flow (Z).
func streamlinedBar(_ parent:SCNNode,_ a:SCNVector3,_ b:SCNVector3,thickness:Double,chord:Double,_ mat:SCNMaterial) {
    let pa=simd_double3(Double(a.x),Double(a.y),Double(a.z)),pb=simd_double3(Double(b.x),Double(b.y),Double(b.z))
    let axis=simd_normalize(pb-pa)
    var flow=simd_double3(0,0,1)-axis*axis.z
    if simd_length(flow)<1e-3 {flow=simd_double3(0,1,0)-axis*axis.y}
    flow=simd_normalize(flow)
    let side=simd_normalize(simd_cross(axis,flow))
    var v=[SCNVector3](),uv=[CGPoint](),ix=[Int32]()
    let k=14,length=simd_length(pb-pa)
    for (e,p) in [pa,pb].enumerated() {
        for j in 0..<k {
            uv.append(CGPoint(x:0.3+Double(e)*length/67.1,y:0.5+Double(j)/Double(k)*chord*2.2/15))
            let a=Double(j)/Double(k)*2 * .pi
            // Rounded nose, fine tail.
            let c=cos(a),s=sin(a)
            let along=c>=0 ? c*chord*0.42 : c*chord*0.58
            let across=s*thickness/2*(c>=0 ? 1:sqrt(max(0,1+c*0.55)))
            v.append(vec(p+flow*along+side*across))
        }
    }
    for j in 0..<k {
        let a=Int32(j),b=Int32((j+1)%k),c=a+Int32(k),d=b+Int32(k)
        ix += [a,b,c,b,d,c]
    }
    part(parent,mesh(v,ix,uv:uv),mat)
}

// MARK: - Screws

/// Three-bladed screw, 1.62 m diameter, 1.54 m pitch. Local shaft axis along +Z (aft).
func detailedScrew(side:Double,_ m:VIICMaterials)->SCNNode {
    let L=DetailedLayout.self
    let root=SCNNode();root.name="propeller"
    root.position=SCNVector3(side*L.shaftX,L.shaftY,L.screwZ)
    let R=L.screwRadius,rh=0.17,P=1.54
    let bronze=m.brass
    for blade in 0..<3 {
        let nr=16,ns=12
        var face=[SCNVector3](),back=[SCNVector3]()
        for i in 0...nr {
            let rho=Double(i)/Double(nr)
            let r=rh*0.85+(R-rh*0.85)*rho
            let c=0.58*sqrt(max(0,1-pow(rho,3)))*(0.6+0.4*sin(rho*0.9 * .pi))
            let phi=atan(P/(2 * .pi*r))
            let skew=0.32*rho*rho
            let theta0=Double(blade)*2 * .pi/3+side*skew
            let t0=0.055*(1-rho)+0.009
            for j in 0...ns {
                let s = -1+2*Double(j)/Double(ns)
                let theta=theta0+s*side*(c/2)*cos(phi)/r
                let z=s*(c/2)*sin(phi)+0.07*rho
                let t=t0*pow(max(0,1-s*s),0.6)
                face.append(SCNVector3(r*cos(theta),r*sin(theta),z))
                back.append(SCNVector3(r*cos(theta),r*sin(theta),z-t))
            }
        }
        var faceIx=[Int32]()
        let w=Int32(ns+1)
        for i in 0..<nr {for j in 0..<ns {
            let a=Int32(i)*w+Int32(j),b=a+w
            faceIx += [a,b,a+1,a+1,b,b+1]
        }}
        // The pressure face looks aft (+Z); the back is the same grid wound the other way.
        let va=face[Int(faceIx[0])],vb=face[Int(faceIx[1])],vc=face[Int(faceIx[2])]
        if (vb.x-va.x)*(vc.y-va.y)-(vb.y-va.y)*(vc.x-va.x)<0 {
            for t in stride(from:0,to:faceIx.count,by:3) {faceIx.swapAt(t+1,t+2)}
        }
        var backIx=faceIx.map{$0+Int32(face.count)}
        for t in stride(from:0,to:backIx.count,by:3) {backIx.swapAt(t+1,t+2)}
        part(root,mesh(face+back,faceIx+backIx),bronze)
    }
    // Hub, cowling cap over the nut, and forward boss.
    let hub=fitting(root,SCNCylinder(radius:0.175,height:0.46),bronze,SCNVector3(0,0,0.02));hub.eulerAngles.x = .pi/2
    let cap=fitting(root,SCNCone(topRadius:0.035,bottomRadius:0.172,height:0.36),bronze,SCNVector3(0,0,0.43));cap.eulerAngles.x = .pi/2
    let boss=fitting(root,SCNCone(topRadius:0.172,bottomRadius:0.13,height:0.12),bronze,SCNVector3(0,0,-0.27));boss.eulerAngles.x = .pi/2
    return root
}
