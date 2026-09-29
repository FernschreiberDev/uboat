import AppKit
import SceneKit
import simd

// Detailed VIIC (model 2). Same frame as the classic model: metres, bow toward -Z,
// +X to starboard, waterline near y = 1.9 when surfaced. Proportions follow the
// Skizzenbuch general arrangement (plate 5), the 1940 VIIC manual and U-995 photographs.

/// Monotone cubic interpolation (PCHIP): smooth hull lines without overshoot between stations.
struct HullCurve {
    let xs:[Double], ys:[Double], ms:[Double]
    init(_ points:[(Double,Double)]) {
        xs=points.map{$0.0};ys=points.map{$0.1}
        let n=xs.count
        var h=[Double](),d=[Double]()
        for i in 0..<n-1 {h.append(xs[i+1]-xs[i]);d.append((ys[i+1]-ys[i])/h[i])}
        var m=[Double](repeating:0,count:n)
        if n==2 {m=[d[0],d[0]]} else {
            for i in 1..<n-1 where d[i-1]*d[i]>0 {
                let w1=2*h[i]+h[i-1],w2=h[i]+2*h[i-1]
                m[i]=(w1+w2)/(w1/d[i-1]+w2/d[i])
            }
            func end(_ h0:Double,_ h1:Double,_ d0:Double,_ d1:Double)->Double {
                var s=((2*h0+h1)*d0-h0*d1)/(h0+h1)
                if s*d0<=0 {s=0} else if d0*d1<=0 && abs(s)>abs(3*d0) {s=3*d0}
                return s
            }
            m[0]=end(h[0],h[1],d[0],d[1]);m[n-1]=end(h[n-2],h[n-3],d[n-2],d[n-3])
        }
        ms=m
    }
    func callAsFunction(_ t:Double)->Double {
        if t<=xs[0] {return ys[0]}
        if t>=xs[xs.count-1] {return ys[ys.count-1]}
        var i=0
        while t>xs[i+1] {i+=1}
        let h=xs[i+1]-xs[i],s=(t-xs[i])/h
        let h00=(1+2*s)*(1-s)*(1-s),h10=s*(1-s)*(1-s),h01=s*s*(3-2*s),h11=s*s*(s-1)
        return h00*ys[i]+h10*h*ms[i]+h01*ys[i+1]+h11*h*ms[i+1]
    }
}

enum DetailedHull {
    static let bowZ = -33.55, sternZ = 33.55
    /// Height of the flood-slot band: the casing wall runs from the deck edge down to the knuckle.
    static let wallDepth = 0.70

    // Upper deck. Forward of frame 90 the deck edge follows the U-570 survey plan; the stern
    // stays high, ending in a broad rounded overhang as on U-995.
    static let deckWidthCurve=HullCurve([(-33.55,0),(-33.3,0.12),(-32.2,0.32),(-31.1,0.56),(-29.9,0.77),(-28.7,0.98),(-27.6,1.15),(-26.4,1.32),(-25.2,1.45),(-24,1.54),(-22.9,1.61),(-21.7,1.68),(-20.5,1.75),(-19.4,1.81),(-18.2,1.89),(-17,1.96),(-15,2.05),(-12,2.13),(-9,2.17),(5,2.13),(10,2.06),(15,1.95),(20,1.82),(24,1.64),(27,1.45),(29,1.3)])
    static func deckWidth(_ z:Double)->Double {
        if z<=29 {return max(0,deckWidthCurve(z))}
        // Elliptical spoon-shaped stern in plan view.
        let t=min(1,(z-29)/(sternZ-29))
        return 1.3*sqrt(max(0,1-t*t))
    }
    static func deckSheer(_ z:Double)->Double {
        3.03+0.45*pow(max(0,-z/33.55),3)-0.6*pow(max(0,(z-8)/25.5),2)
    }
    /// Deck line, rounded down at the bow into the stem head.
    static func deckHeight(_ z:Double)->Double {
        if z>=noseStart {return deckSheer(z)}
        let u=min(1,(noseStart-z)/(noseStart-bowZ))
        let top=deckSheer(noseStart)
        return top-noseDrop+noseDrop*pow(max(0,1-pow(u,2.4)),1/2.4)
    }
    /// Depth of the casing wall; it shrinks where the stem head leaves no room for it.
    static func wallDepth(_ z:Double)->Double {
        z<bowBlendEnd ? max(0,min(wallDepth,0.35*(deckHeight(z)-stemCurve(z)))) : wallDepth
    }
    static func knuckle(_ z:Double)->Double {deckHeight(z)-wallDepth(z)}

    // Bow after the 1941 British survey drawing of U-570: the deck corner rounds down into a stem
    // raked about 36°, the forefoot sweeps into a keel that rises from frame 90, and the sections
    // are wall-sided around the torpedo tubes with a V towards the stem.
    static let noseStart = -32.25, noseDrop = 0.53
    static let bowBlendStart = -18.0, bowBlendEnd = -13.0
    /// Stem and keel line forward of the parallel keel (z, height of the hull bottom).
    static let stemCurve=HullCurve([(-33.55,2.9),(-33.46,2.67),(-33.23,2.37),(-32.72,1.67),(-32.26,1.04),(-31.66,0.2),(-30.8,-0.47),(-30.19,-0.82),(-29.46,-1.13),(-28.43,-1.38),(-26.97,-1.6),(-24.05,-2.02),(-21.12,-2.43),(-18.05,-2.85),(-16,-2.85)])
    /// Width of the wall-sided part of each bow section relative to the deck edge (flare).
    static let bowFullness=HullCurve([(-33.55,0.72),(-31.4,0.76),(-29.9,0.8),(-28.8,0.83),(-26.24,0.86),(-24.05,0.89),(-21.85,0.93),(-18,0.97),(-13,1)])
    /// Depth fraction below the knuckle where the bilge starts to round into the keel.
    static let bowBilge=HullCurve([(-33.55,0),(-31.4,0.02),(-31,0.24),(-30.6,0.38),(-29.9,0.62),(-28.8,0.8),(-26,0.74),(-24,0.72),(-21,0.7),(-18,0.68),(-13,0.66)])
    static let bowFlareDepth = 0.45
    /// Weight of the bow section: 1 forward of frame 90, easing to the midship sections.
    static func bowWeight(_ z:Double)->Double {
        if z<=bowBlendStart {return 1}
        if z>=bowBlendEnd {return 0}
        let t=(bowBlendEnd-z)/(bowBlendEnd-bowBlendStart)
        return t*t*(3-2*t)
    }
    /// Station where the stem or keel line reaches height y (forward end of the hull at y).
    static func stemZ(atHeight y:Double)->Double {
        if y>=stemCurve(bowZ) {return bowZ}
        var a=bowZ,b=bowBlendStart
        for _ in 0..<50 {let m=(a+b)/2;if stemCurve(m)>y {a=m} else {b=m}}
        return (a+b)/2
    }

    // Upper body below the knuckle: casing transition amidships, broad overhang aft.
    static let bulgeCurve=HullCurve([(17,0),(21,0.12),(24,0.29),(27,0.43),(29,0.38),(30.5,0.18),(31.5,0.1),(32.5,0.06),(33.2,0.05),(33.55,0)])
    static let bulgeDropCurve=HullCurve([(17,0),(21,0.25),(24,0.4),(27,0.45),(30.5,0.45),(32.5,0.36),(33.55,0.3)])
    static let upperBottomCurve=HullCurve([(-33.55,1.55),(-30,1.2),(-24,0.95),(-18,0.8),(12,0.8),(17,0.75),(21,0.62),(24,0.38),(27,0.05),(29,-0.12),(30.5,-0.02),(31.5,0.22),(32.5,0.6),(33.2,0.98),(33.55,1.2)])
    static let upperExponentCurve=HullCurve([(-33.55,2),(17,2),(24,2.5),(31,2.6),(33.55,2.2)])

    // Lower body: pressure hull amidships, tapering forward of the control room, narrow skeg-like
    // body aft. Forward of frame 90 the bow sections above replace it.
    // (z, half-width, keel line, top, height of maximum width, superellipse exponent)
    static let lowerStations:[(Double,Double,Double,Double,Double,Double)] = [
        (-33.55,0.02,0.35,3.55,2.9,1.8),(-33.0,0.2,0.0,3.55,2.75,1.8),(-32.0,0.47,-0.6,3.5,2.55,1.8),
        (-30.0,0.98,-1.65,3.35,2.35,1.85),(-27.0,1.52,-2.35,3.0,2.05,1.9),(-23.0,1.8,-2.72,2.55,0.3,2.0),
        (-18.0,2.0,-2.85,1.9,-0.5,2.0),(-16,2.12,-2.85,1.88,-0.5,2),(-13,2.3,-2.85,1.86,-0.5,2),(-10,2.35,-2.85,1.85,-0.5,2),(6,2.35,-2.85,1.85,-0.5,2),
        (15,2.22,-2.75,1.8,-0.475,2),(18,2.1,-2.62,1.75,-0.435,2),(21,1.88,-2.42,1.7,-0.36,2),
        (23.5,1.58,-2.18,1.62,-0.28,2),(26,1.12,-1.88,1.5,-0.19,2),(28,0.6,-1.6,1.4,-0.1,2.05),
        (29.5,0.45,-1.42,1.3,-0.06,2.1),(31,0.37,-1.15,1.15,0,2.1),(32,0.36,-0.25,1.05,0.45,2.1),
        (32.5,0.29,0.18,0.95,0.55,2.0),(32.7,0.16,0.3,0.86,0.56,2.0),(32.85,0.02,0.5,0.62,0.56,2.0)]
    static let lowerRadius=HullCurve(lowerStations.map{($0.0,$0.1)})
    static let lowerKeel=HullCurve(lowerStations.map{($0.0,$0.2)})
    static let lowerTop=HullCurve(lowerStations.map{($0.0,$0.3)})
    static let lowerCenter=HullCurve(lowerStations.map{($0.0,$0.4)})
    static let lowerExponent=HullCurve(lowerStations.map{($0.0,$0.5)})
    static let lowerEnd=32.85

    /// Arc-length share of the upper body in the midship outline where the bow blend ends, so that
    /// bow and midship rings distribute their vertices alike.
    static let bowOutlineSplit:Double={
        let parts=HullSection2(z:bowBlendEnd).midshipOutlineParts()
        func length(_ p:[(Double,Double)])->Double {zip(p,p.dropFirst()).reduce(0){$0+hypot($1.1.0-$1.0.0,$1.1.1-$1.0.1)}}
        let a=length(parts.0),b=length(parts.1)
        return a+b>1e-6 ? a/(a+b) : 0.3
    }()

    /// Lateral bulge of the saddle tanks (0 at their ends, 1 at their widest).
    static func saddleTankBulge(_ z:Double)->Double {
        // Forward ends taper into the bow at frame 88 (U-570 plan); the aft part is unchanged.
        if z < -0.5 {return pow(max(0.001,sin(max(0,(z+17.5)/17) * .pi/2)),0.65)}
        return pow(max(0.001,sin((z+21)/41 * .pi)),0.65)
    }
}

/// One transverse section of the detailed hull. Amidships and aft it is the union of an upper body
/// (casing and stern overhang) and a lower body (pressure hull, aft skeg body); forward of frame 90
/// it is a bow section drawn from the deck edge, the knuckle and the stem/keel line.
struct HullSection2 {
    let z:Double
    let deckY:Double,deckW:Double,knuckleY:Double
    let bulgeW:Double,bulgeY:Double,upperBottom:Double,upperTopH:Double,pUpper:Double,pLower:Double
    let r:Double,centerY:Double,topH:Double,bottomH:Double,p:Double
    let bowW:Double,bowB:Double,bowGW:Double,bowSB:Double

    init(z:Double) {
        self.z=z
        let H=DetailedHull.self
        deckY=H.deckHeight(z);deckW=H.deckWidth(z);knuckleY=H.knuckle(z)
        let bulge=z>17 ? max(0,H.bulgeCurve(z)) : 0
        bulgeW=deckW+bulge
        bulgeY=knuckleY-(bulge>0.005 ? H.bulgeDropCurve(z) : 0)
        upperBottom=min(H.upperBottomCurve(z),bulgeY-0.05)
        pUpper=2.2;pLower=H.upperExponentCurve(z)
        if bulgeW-deckW>0.005 && knuckleY-bulgeY>0.005 {
            let f=pow(deckW/bulgeW,pUpper)
            upperTopH=(knuckleY-bulgeY)/pow(max(1e-6,1-f),1/pUpper)
        } else {upperTopH=0}
        if z>=H.lowerEnd || z<=H.bowZ-1e-9 {
            r=0;centerY=upperBottom;topH=0;bottomH=0;p=2
        } else {
            r=max(0,H.lowerRadius(z));centerY=H.lowerCenter(z)
            topH=max(0.01,H.lowerTop(z)-centerY);bottomH=max(0.01,centerY-H.lowerKeel(z));p=H.lowerExponent(z)
        }
        bowW=H.bowWeight(z)
        bowB=bowW>0 ? min(H.stemCurve(z),deckY) : 0
        bowGW=H.bowFullness(z);bowSB=min(0.98,max(0,H.bowBilge(z)))
    }
    private var midshipKeelY:Double {r>0 ? centerY-bottomH : upperBottom}
    var keelY:Double {bowW>0 ? bowB*bowW+midshipKeelY*(1-bowW) : midshipKeelY}

    // Lower body (superellipse with different upper and lower semi-heights).
    func lowerHalfWidth(_ y:Double)->Double {
        guard r>0 else {return -1}
        let dy=y-centerY,h=dy>=0 ? topH:bottomH
        let t=abs(dy)/h
        if t>1 {return -1}
        return r*pow(max(0,1-pow(t,p)),1/p)
    }
    func insideLower(_ x:Double,_ y:Double)->Bool {
        let w=lowerHalfWidth(y);return w>=0 && abs(x)<w
    }
    func lowerPoint(_ a:Double)->(Double,Double) {
        let s=sin(a),c=cos(a)
        let x=r*pow(abs(s),2/p)
        let y=centerY+(c>=0 ? topH:-bottomH)*pow(abs(c),2/p)
        return (x,y)
    }
    // Upper body half-width at height y (below the knuckle), -1 when outside its range.
    func upperHalfWidth(_ y:Double)->Double {
        if y>knuckleY+1e-9 {return y<=deckY+1e-9 ? deckW : -1}
        if y>=bulgeY {
            guard upperTopH>0 else {return deckW}
            let t=(y-bulgeY)/upperTopH
            return bulgeW*pow(max(0,1-pow(t,pUpper)),1/pUpper)
        }
        let hl=bulgeY-upperBottom
        if hl<=0 {return -1}
        let t=(bulgeY-y)/hl
        if t>1 {return -1}
        return bulgeW*pow(max(0,1-pow(t,pLower)),1/pLower)
    }
    /// Midship definition: union of the upper and lower bodies.
    func midshipHalfWidth(_ y:Double)->Double {max(upperHalfWidth(y),lowerHalfWidth(y))}
    /// Bow definition: casing wall, slight flare down to the tubes, then the bilge rounding into the stem or keel.
    func bowHalfWidth(_ y:Double)->Double {
        if y>deckY+1e-9 || y<bowB-1e-9 {return -1}
        if y>=knuckleY {return deckW}
        let depth=knuckleY-bowB
        if depth<=1e-6 {return 0}
        let s=min(1,max(0,(knuckleY-y)/depth))
        let sw=DetailedHull.bowFlareDepth
        let flare=bowGW+(1-bowGW)*pow(max(0,1-s/sw),2)
        let bilge=s<=bowSB ? 1 : sqrt(max(0,1-pow((s-bowSB)/(1-bowSB),2)))
        return deckW*flare*bilge
    }
    /// Outer half-width of the complete hull at height y; -1 when y is outside the hull.
    func halfWidth(_ y:Double)->Double {
        if bowW<=0 {return midshipHalfWidth(y)}
        let b=bowHalfWidth(y)
        if bowW>=1 {return b}
        let m=midshipHalfWidth(y)
        if b<0 && m<0 {return -1}
        return max(0,b)*bowW+max(0,m)*(1-bowW)
    }

    /// Dense samples along the upper body from the knuckle down to its bottom centre.
    func upperSamples(_ n:Int=160)->[(Double,Double)] {
        var pts=[(Double,Double)]()
        if upperTopH>0 {
            let sK=acos(min(1,pow(deckW/bulgeW,pUpper/2)))
            for i in 0..<n/4 {
                let s=sK*(1-Double(i)/Double(n/4))
                pts.append((bulgeW*pow(cos(s),2/pUpper),bulgeY+upperTopH*pow(sin(s),2/pUpper)))
            }
        } else {pts.append((deckW,knuckleY))}
        let hl=bulgeY-upperBottom
        for i in 0...n {
            let s=Double(i)/Double(n) * .pi/2
            pts.append((bulgeW*pow(cos(s),2/pLower),bulgeY-hl*pow(sin(s),2/pLower)))
        }
        return pts
    }
    /// Midship outline split into the upper body (knuckle → crease) and the lower body (crease → keel).
    func midshipOutlineParts()->([(Double,Double)],[(Double,Double)]) {
        let dense=upperSamples()
        var crease:(Double,Double)?=nil,cut=dense.count
        if r>0 {
            if insideLower(dense[0].0,dense[0].1) {crease=dense[0];cut=1}
            else {
                for i in 1..<dense.count where insideLower(dense[i].0,dense[i].1) || (i==dense.count-1 && lowerHalfWidth(dense[i].1)>=0) {
                    var a=dense[i-1],b=dense[i]
                    for _ in 0..<30 {
                        let m=((a.0+b.0)/2,(a.1+b.1)/2)
                        if insideLower(m.0,m.1) {b=m} else {a=m}
                    }
                    crease=b;cut=i;break
                }
            }
        }
        var upperPart=Array(dense[0..<cut])
        let join=crease ?? dense[dense.count-1]
        upperPart.append(join)
        guard let c=crease else {return (upperPart,[join,join])}
        // Continue along the lower body from the crease to the keel.
        let h=c.1>=centerY ? topH:bottomH
        let sa=pow(min(1,abs(c.0)/max(r,1e-9)),p/2)
        let ca=pow(min(1,abs(c.1-centerY)/h),p/2)*(c.1>=centerY ? 1:-1)
        let a0=atan2(sa,ca)
        var lower=[(Double,Double)]()
        for i in 0...200 {lower.append(lowerPoint(a0+(Double.pi-a0)*Double(i)/200))}
        lower[0]=c
        return (upperPart,lower)
    }
    /// Starboard half outline from the knuckle to the keel centreline.
    func outline(upper nA:Int,lower nB:Int)->[(Double,Double)] {
        if bowW<=0 {
            let parts=midshipOutlineParts()
            if parts.1.count==2 && parts.1[0]==parts.1[1] {return resample(parts.0,nA)+Array(repeating:parts.1[0],count:nB)}
            return resample(parts.0,nA)+resample(parts.1,nB+1).dropFirst()
        }
        // Bow and blend: sample the section densely, closer together near the keel, then split it
        // at the same arc-length share as the midship rings.
        let top=knuckleY,bottom=keelY
        var dense=[(Double,Double)]()
        let n=360
        for i in 0...n {
            let u=Double(i)/Double(n)
            let y=top-(top-bottom)*(1-pow(1-u,1.8))
            dense.append((max(0,halfWidth(y)),y))
        }
        dense[n]=(0,bottom)
        var acc=[0.0]
        for i in 1..<dense.count {acc.append(acc[i-1]+hypot(dense[i].0-dense[i-1].0,dense[i].1-dense[i-1].1))}
        let split=acc.last!*DetailedHull.bowOutlineSplit
        var k=1
        while k<dense.count-1 && acc[k]<split {k+=1}
        let t=(split-acc[k-1])/max(1e-12,acc[k]-acc[k-1])
        let joint=(dense[k-1].0+(dense[k].0-dense[k-1].0)*t,dense[k-1].1+(dense[k].1-dense[k-1].1)*t)
        let first=Array(dense[0..<k])+[joint],second=[joint]+Array(dense[k...])
        return resample(first,nA)+resample(second,nB+1).dropFirst()
    }
}

/// Resample a polyline to n points evenly spaced by arc length.
func resample(_ pts:[(Double,Double)],_ n:Int)->[(Double,Double)] {
    guard pts.count>1,n>1 else {return Array(repeating:pts.first ?? (0,0),count:max(n,1))}
    var acc=[0.0]
    for i in 1..<pts.count {acc.append(acc[i-1]+hypot(pts[i].0-pts[i-1].0,pts[i].1-pts[i-1].1))}
    let total=acc.last!
    if total<1e-9 {return Array(repeating:pts[0],count:n)}
    var out=[(Double,Double)](),k=1
    for i in 0..<n {
        let target=total*Double(i)/Double(n-1)
        while k<pts.count-1 && acc[k]<target {k+=1}
        let span=max(1e-12,acc[k]-acc[k-1]),t=min(1,max(0,(target-acc[k-1])/span))
        out.append((pts[k-1].0+(pts[k].0-pts[k-1].0)*t,pts[k-1].1+(pts[k].1-pts[k-1].1)*t))
    }
    return out
}

/// Stations along the hull, concentrated towards the rounded ends.
func detailedStations(_ count:Int)->[Double] {
    (0...count).map {i in
        let t=Double(i)/Double(count)
        // Blend of uniform and cosine spacing keeps both ends finely resolved.
        let c=(1-cos(t * .pi))/2
        return DetailedHull.bowZ+(DetailedHull.sternZ-DetailedHull.bowZ)*(0.55*t+0.45*c)
    }
}

/// Lower hull surface from the port knuckle, under the keel, to the starboard knuckle.
func detailedHullGeometry(stations:Int=280,upper nA:Int=18,lower nB:Int=30)->SCNGeometry {
    let zs=detailedStations(stations)
    let half=nA+nB
    var v=[SCNVector3](),uv=[CGPoint](),ix=[Int32]()
    let ring=2*half-1
    for (i,z) in zs.enumerated() {
        let o=HullSection2(z:z).outline(upper:nA,lower:nB)
        // Starboard knuckle -> keel -> port knuckle.
        var loop=o.map{SCNVector3($0.0,$0.1,z)}
        loop += o.dropLast().reversed().map{SCNVector3(-$0.0,$0.1,z)}
        var arc=[0.0]
        for j in 1..<loop.count {arc.append(arc[j-1]+Double(hypot(loop[j].x-loop[j-1].x,loop[j].y-loop[j-1].y)))}
        let total=max(arc.last!,1e-6)
        for j in 0..<loop.count {
            v.append(loop[j])
            uv.append(CGPoint(x:(z+33.55)/67.1,y:0.04+0.92*arc[j]/total))
        }
        if i<zs.count-1 {for j in 0..<ring-1 {
            let a=Int32(i*ring+j),b=a+Int32(ring)
            ix += [a,b,a+1,a+1,b,b+1]
        }}
    }
    return mesh(v,ix,uv:uv)
}
