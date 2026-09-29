import AppKit
import SceneKit
import simd

// Geometry is generated in metres. The bow points toward -Z.
struct HullStation {
    let z: Double, radius: Double, bottom: Double, top: Double
}
let viicStations: [HullStation] = [
    .init(z:-33.55,radius:0.025,bottom:0.35,top:3.55),
    .init(z:-32,radius:0.45,bottom:-0.6,top:3.5),
    .init(z:-30,radius:1.0,bottom:-1.65,top:3.35),
    .init(z:-27,radius:1.65,bottom:-2.35,top:3.0),
    .init(z:-23,radius:2.13,bottom:-2.7,top:2.55),
    .init(z:-18,radius:2.35,bottom:-2.85,top:1.92),
    .init(z:-10,radius:2.35,bottom:-2.85,top:1.85),
    .init(z:6,radius:2.35,bottom:-2.85,top:1.85),
    .init(z:15,radius:2.22,bottom:-2.75,top:1.8),
    .init(z:21,radius:1.85,bottom:-2.35,top:1.65),
    .init(z:26,radius:1.18,bottom:-1.65,top:1.35),
    .init(z:30,radius:0.55,bottom:-0.85,top:0.8),
    .init(z:33.55,radius:0.025,bottom:0.1,top:0.28)
]
func hullSection(_ z:Double) -> (Double,Double,Double) {
    let z=clamp(z,viicStations.first!.z,viicStations.last!.z)
    for i in 0..<viicStations.count-1 where z <= viicStations[i+1].z {
        let a=viicStations[i],b=viicStations[i+1],t=(z-a.z)/(b.z-a.z)
        // Linear interpolation at closely spaced stations preserves a fair silhouette.
        return (a.radius+(b.radius-a.radius)*t,a.bottom+(b.bottom-a.bottom)*t,a.top+(b.top-a.top)*t)
    }
    return (0.025,0.1,0.28)
}
func deckWidth(_ z:Double) -> Double {
    let points:[(Double,Double)]=[(-33.4,0.04),(-31,0.65),(-28,1.25),(-24,1.75),(-18,2.02),(-9,2.18),(5,2.13),(14,1.9),(22,1.43),(27,0.9),(30.6,0.05)]
    for i in 0..<points.count-1 where z<=points[i+1].0 {
        let t=clamp((z-points[i].0)/(points[i+1].0-points[i].0),0,1)
        return points[i].1+(points[i+1].1-points[i].1)*t
    }
    return 0.05
}
func deckHeight(_ z:Double) -> Double {
    3.03 + 0.45*pow(max(0,-z/33.55),3) - 0.4*pow(max(0,z/33.55),3) - 1.5*pow(clamp((z-19)/12,0,1),2)
}
func mesh(_ vertices:[SCNVector3],_ indices:[Int32],uv:[CGPoint]?=nil) -> SCNGeometry {
    var normals=Array(repeating:SCNVector3Zero,count:vertices.count)
    for i in stride(from:0,to:indices.count,by:3) {
        let a=Int(indices[i]),b=Int(indices[i+1]),c=Int(indices[i+2])
        let u=SCNVector3(vertices[b].x-vertices[a].x,vertices[b].y-vertices[a].y,vertices[b].z-vertices[a].z)
        let v=SCNVector3(vertices[c].x-vertices[a].x,vertices[c].y-vertices[a].y,vertices[c].z-vertices[a].z)
        let n=SCNVector3(u.y*v.z-u.z*v.y,u.z*v.x-u.x*v.z,u.x*v.y-u.y*v.x)
        for j in [a,b,c] {normals[j].x+=n.x;normals[j].y+=n.y;normals[j].z+=n.z}
    }
    normals=normals.map { n in
        let d=sqrt(n.x*n.x+n.y*n.y+n.z*n.z)
        return d>0.0000001 ? SCNVector3(n.x/d,n.y/d,n.z/d) : SCNVector3(0,1,0)
    }
    var sources=[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:normals)]
    if let uv=uv {sources.append(SCNGeometrySource(textureCoordinates:uv))}
    return SCNGeometry(sources:sources,elements:[SCNGeometryElement(indices:indices,primitiveType:.triangles)])
}
func longitudinalMesh(start:Double,end:Double,steps:Int=160,sides:Int=64,point:(Double,Double)->SCNVector3) -> SCNGeometry {
    var v=[SCNVector3](),uv=[CGPoint](),ix=[Int32]()
    for i in 0...steps {
        let z=start+(end-start)*Double(i)/Double(steps)
        for j in 0...sides {
            v.append(point(z,Double(j)/Double(sides)*2 * .pi))
            uv.append(CGPoint(x:Double(i)/Double(steps),y:Double(j)/Double(sides)))
        }
    }
    for i in 0..<steps {for j in 0..<sides {
        let a=Int32(i*(sides+1)+j),b=a+Int32(sides+1)
        ix += [a,b,a+1,a+1,b,b+1]
    }}
    return mesh(v,ix,uv:uv)
}
func viicPressureHull() -> SCNGeometry {
    longitudinalMesh(start:-33.55,end:33.55) {z,a in
        let (rx,lo,hi)=hullSection(z)
        return SCNVector3(sin(a)*rx,(hi+lo)/2+cos(a)*(hi-lo)/2,z)
    }
}
func sheet(_ parent:SCNNode,_ mat:SCNMaterial,z0:Double,z1:Double,side:Double,lower:Double,upper:Double) {
    let steps=max(1,Int((z1-z0)*3))
    var v=[SCNVector3](),uv=[CGPoint](),ix=[Int32]()
    for i in 0...steps {
        let z=z0+(z1-z0)*Double(i)/Double(steps),w=deckWidth(z),h=deckHeight(z)
        v += [SCNVector3(side*w,h+lower,z),SCNVector3(side*w,h+upper,z)]
        uv += [CGPoint(x:(z+33.55)/67.1,y:(lower+1.4)/1.4),CGPoint(x:(z+33.55)/67.1,y:(upper+1.4)/1.4)]
        if i<steps {
            let a=Int32(i*2)
            ix += side>0 ? [a,a+1,a+2,a+1,a+3,a+2] : [a,a+2,a+1,a+1,a+2,a+3]
        }
    }
    part(parent,mesh(v,ix,uv:uv),mat)
}
func deckMesh() -> SCNGeometry {
    var v=[SCNVector3](),uv=[CGPoint](),ix=[Int32]()
    for i in 0...180 {
        let z = -33.4+64*Double(i)/180,h=deckHeight(z),w=deckWidth(z)
        for j in 0...8 {
            let x = -w+2*w*Double(j)/8
            v.append(SCNVector3(x,h+0.04*(1-pow(x/max(w,0.01),2)),z))
            uv.append(CGPoint(x:(x+2.3)/4.6,y:(z+33.4)/64))
        }
        if i<180 {for j in 0..<8 {let a=Int32(i*9+j),b=a+9;ix += [a,b,a+1,a+1,b,b+1]}}
    }
    return mesh(v,ix,uv:uv)
}
func horizontalDisk(_ width:Double,_ length:Double,_ y:Double,_ z:Double=0) -> SCNGeometry {
    var v=[SCNVector3(0,y,z)],uv=[CGPoint(x:0.5,y:0.5)],ix=[Int32]()
    for i in 0...64 {
        let a=Double(i)/64*2 * .pi
        v.append(SCNVector3(sin(a)*width,y,z-cos(a)*length))
        uv.append(CGPoint(x:0.5+sin(a)/2,y:0.5-cos(a)/2))
        if i<64 {ix += [0,Int32(i+2),Int32(i+1)]}
    }
    return mesh(v,ix,uv:uv)
}
func towerShell(y0:Double,y1:Double,w0:Double,w1:Double,front:Double,rear:Double,zOffset:Double=0,thickness:Double=0) -> SCNGeometry {
    var v=[SCNVector3](),uv=[CGPoint](),ix=[Int32]()
    let count=80
    // The bridge shell is genuinely open, with an inner skin and capped rim.
    let loops=thickness>0 ? 4 : 2
    for layer in 0..<loops {
        let top=layer==1 || layer==2,inside=layer>=2
        let w=(top ? w1:w0)-(inside ? thickness:0)
        let y=top ? y1:y0
        for i in 0...count {
            let a=Double(i)/Double(count)*2 * .pi,c=cos(a)
            let l=(c>=0 ? front:rear)-(inside ? thickness:0)
            v.append(SCNVector3(sin(a)*w,y,zOffset-c*l))
            uv.append(CGPoint(x:Double(i)/Double(count)*2,y:top ? 1:0))
        }
    }
    let bands=thickness>0 ? 3:1
    for layer in 0..<bands {for i in 0..<count {
        let a=Int32(layer*(count+1)+i),b=a+Int32(count+1)
        ix += [a,b,a+1,a+1,b,b+1]
    }}
    return mesh(v,ix,uv:uv)
}
func foilGeometry(span:Double,chord:Double,sweep:Double=0.45) -> SCNGeometry {
    let shape=NSBezierPath()
    shape.move(to:NSPoint(x:0,y:-chord/2))
    shape.line(to:NSPoint(x:span*0.86,y:-chord/2+sweep))
    shape.curve(to:NSPoint(x:span,y:chord*0.22+sweep),controlPoint1:NSPoint(x:span*1.08,y:-chord*0.1+sweep),controlPoint2:NSPoint(x:span*1.04,y:chord*0.12+sweep))
    shape.line(to:NSPoint(x:span*0.82,y:chord/2+sweep))
    shape.line(to:NSPoint(x:0,y:chord/2));shape.close()
    let g=SCNShape(path:shape,extrusionDepth:0.13);g.chamferRadius=0.045;g.chamferMode = .both
    return g
}
func tube(_ parent:SCNNode,_ a:SCNVector3,_ b:SCNVector3,_ radius:CGFloat,_ mat:SCNMaterial) {
    let dx=b.x-a.x,dy=b.y-a.y,dz=b.z-a.z
    let length=sqrt(dx*dx+dy*dy+dz*dz)
    guard length>0.00001 else{return}
    let shape=SCNCylinder(radius:radius,height:length);shape.radialSegmentCount=10;shape.heightSegmentCount=1
    let n=part(parent,shape,mat,SCNVector3((a.x+b.x)/2,(a.y+b.y)/2,(a.z+b.z)/2))
    n.simdOrientation=simd_quatf(from:SIMD3<Float>(0,1,0),to:simd_normalize(SIMD3<Float>(Float(dx),Float(dy),Float(dz))))
}
@discardableResult func ring(_ parent:SCNNode,_ center:SCNVector3,_ radius:CGFloat,_ pipe:CGFloat,_ mat:SCNMaterial,axis:String="y") -> SCNNode {
    let g=SCNTorus(ringRadius:radius,pipeRadius:pipe);g.ringSegmentCount=32;g.pipeSegmentCount=6
    let n=part(parent,g,mat,center)
    if axis=="x" {n.eulerAngles.z = .pi/2}
    if axis=="z" {n.eulerAngles.x = .pi/2}
    return n
}

func lowerCasing(_ side:Double) -> SCNGeometry {
    var v=[SCNVector3](),uv=[CGPoint](),ix=[Int32]()
    let steps=180,rows=6
    for i in 0...steps {
        let z = -33.35+63.9*Double(i)/Double(steps),w=deckWidth(z),h=deckHeight(z)
        let (rx,lo,hi)=hullSection(z),inner=rx*0.62,join=(lo+hi)/2+(hi-lo)/2*sqrt(1-0.62*0.62)
        for j in 0...rows {
            let t=Double(j)/Double(rows),blend=t*t*(3-2*t)
            v.append(SCNVector3(side*(w+(inner-w)*blend),(h-0.70)*(1-t)+join*t,z))
            uv.append(CGPoint(x:(z+33.55)/67.1,y:0.64-t*0.4))
        }
        if i<steps {for j in 0..<rows {
            let a=Int32(i*(rows+1)+j),b=a+Int32(rows+1)
            ix += side>0 ? [a,b,a+1,a+1,b,b+1] : [a,a+1,b,a+1,b+1,b]
        }}
    }
    return mesh(v,ix,uv:uv)
}
func towerFloor(y:Double,width:Double,front:Double,rear:Double,zOffset:Double) -> SCNGeometry {
    var v=[SCNVector3(0,y,zOffset)],uv=[CGPoint(x:0.5,y:0.5)],ix=[Int32]()
    for i in 0...80 {
        let a=Double(i)/80*2 * .pi,c=cos(a)
        v.append(SCNVector3(sin(a)*width,y,zOffset-c*(c>0 ? front:rear)))
        uv.append(CGPoint(x:0.5+sin(a)/2,y:0.5-c/2))
        if i<80 {ix += [0,Int32(i+2),Int32(i+1)]}
    }
    return mesh(v,ix,uv:uv)
}

func batchStaticHierarchy(_ root:SCNNode) -> SCNNode {
    let flat=SCNNode()
    func collect(_ node:SCNNode,_ parentTransform:simd_float4x4) {
        let transform=parentTransform * node.simdTransform
        if let geometry=node.geometry {
            let leaf=SCNNode(geometry:geometry)
            leaf.simdTransform=transform
            flat.addChildNode(leaf)
        }
        for child in node.childNodes {collect(child,transform)}
    }
    collect(root,matrix_identity_float4x4)
    return flat.flattenedClone()
}


func runModelGeometryTests() {
    let parent=SCNNode();parent.position=SCNVector3(7,4,-8);parent.eulerAngles.y=0.6
    let a=SCNVector3(0,1,-1),b=SCNVector3(0.2,1.2,-4)
    tube(parent,a,b,0.1,material(0x666666))
    let node=parent.childNodes[0],length=(node.geometry as! SCNCylinder).height
    let end=parent.convertPosition(SCNVector3(0,length/2,0),from:node)
    let start=parent.convertPosition(SCNVector3(0,-length/2,0),from:node)
    func error(_ p:SCNVector3,_ q:SCNVector3)->CGFloat {abs(p.x-q.x)+abs(p.y-q.y)+abs(p.z-q.z)}
    precondition(error(end,b)<0.0001 && error(start,a)<0.0001,"Fittings must use parent-local axes")
    let hull=viicPressureHull()
    precondition(hull.sources(for:.vertex).first!.vectorCount == 161*65)
    precondition(hull.elements[0].primitiveCount == 160*64*2)
    precondition(abs(viicStations.last!.z-viicStations.first!.z-67.1)<0.0001)
    precondition(deckHeight(30.5)<1.5 && deckHeight(0)>3,"Fair aft casing")
    print("PASS — VIIC mesh, hull length, aft fairing, transformed fitting alignment")
}
