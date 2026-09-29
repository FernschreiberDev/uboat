import AppKit
import SceneKit
import simd

// Assembly of the detailed VIIC (model 2). The classic model in Model.swift is untouched;
// shared helpers (mesh, tube, ring, fitting, materials) come from the classic sources.

/// Casing wall strip following the detailed deck edge, between two depths below the deck.
func detailedSheet(_ parent:SCNNode,_ mat:SCNMaterial,z0:Double,z1:Double,side:Double,lower:Double,upper:Double,inset:Double=0) {
    let steps=max(1,Int((z1-z0)*3))
    var v=[SCNVector3](),uv=[CGPoint](),ix=[Int32]()
    for i in 0...steps {
        let z=z0+(z1-z0)*Double(i)/Double(steps)
        let w=max(0,DetailedHull.deckWidth(z)-inset),h=DetailedHull.deckHeight(z)
        // The casing wall never reaches below the knuckle (it shrinks over the stem head).
        let floor=DetailedHull.knuckle(z)-(inset>0 ? 0.02:0)
        let lo=max(h+lower,floor),hi=max(h+upper,lo)
        v += [SCNVector3(side*w,lo,z),SCNVector3(side*w,hi,z)]
        uv += [CGPoint(x:(z+33.55)/67.1,y:(lower+1.4)/1.4),CGPoint(x:(z+33.55)/67.1,y:(upper+1.4)/1.4)]
        if i<steps {
            let a=Int32(i*2)
            ix += side>0 ? [a,a+1,a+2,a+1,a+3,a+2] : [a,a+2,a+1,a+1,a+2,a+3]
        }
    }
    part(parent,mesh(v,ix,uv:uv),mat)
}

/// A band of the casing wall pierced by openings: solid plating between the openings and a
/// dark recessed skin behind them, so the slots read as real holes into the free-flooding casing.
func detailedPiercedBand(_ parent:SCNNode,_ m:VIICMaterials,side:Double,lower:Double,upper:Double,from:Double,to:Double,openings:[(Double,Double)]) {
    var z=from
    for o in openings.sorted(by:{$0.0<$1.0}) where o.1>from && o.0<to {
        let a=max(from,o.0),b=min(to,o.1)
        if a>z+0.001 {detailedSheet(parent,m.casing,z0:z,z1:a,side:side,lower:lower,upper:upper)}
        detailedSheet(parent,m.recess,z0:a-0.02,z1:b+0.02,side:side,lower:lower-0.02,upper:upper+0.02,inset:0.08)
        z=b
    }
    if to>z+0.001 {detailedSheet(parent,m.casing,z0:z,z1:to,side:side,lower:lower,upper:upper)}
}

/// Evenly spaced slot openings between two stations.
func slotRun(_ start:Double,_ end:Double,length:Double,pitch:Double)->[(Double,Double)] {
    var out=[(Double,Double)](),z=start
    while z+length<=end+1e-6 {out.append((z,z+length));z+=pitch}
    return out
}

/// Deck surface between two stations: timber planking aft of the stem head, steel over the nose.
func detailedDeckMesh(from z0:Double = DetailedHull.noseStart-0.02,to z1:Double=33.5,steps n:Int=260)->SCNGeometry {
    var v=[SCNVector3](),uv=[CGPoint](),ix=[Int32]()
    for i in 0...n {
        let z=z0+(z1-z0)*Double(i)/Double(n),h=DetailedHull.deckHeight(z),w=max(0.004,DetailedHull.deckWidth(z))
        for j in 0...8 {
            let x = -w+2*w*Double(j)/8
            v.append(SCNVector3(x,h+0.04*(1-pow(x/max(w,0.01),2)),z))
            uv.append(CGPoint(x:(x+2.3)/4.6,y:(z+33.4)/67))
        }
        if i<n {for j in 0..<8 {let a=Int32(i*9+j),b=a+9;ix += [a,b,a+1,a+1,b,b+1]}}
    }
    return mesh(v,ix,uv:uv)
}

/// Stem and keel bar: one rounded bar swept from the stem head, down the raked stem and the
/// forefoot, then aft along the keel. Narrow on the stem as on U-995, a broader keel box aft.
func detailedKeel(_ parent:SCNNode,_ m:VIICMaterials) {
    let H=DetailedHull.self
    var path=[(Double,Double)]()
    for i in 0...10 {let z = -33.05+(H.bowZ+33.05)*Double(i)/10;path.append((z,H.deckHeight(z)))}
    let stemTop=H.stemCurve(H.bowZ)
    for i in 1...60 {let y=stemTop+(-1.0-stemTop)*Double(i)/60;path.append((H.stemZ(atHeight:y),y))}
    let zk=path.last!.0
    for i in 1...220 {let z=zk+(24.8-zk)*Double(i)/220;path.append((z,HullSection2(z:z).keelY))}
    let pts=resample(path,420)
    var acc=[0.0]
    for i in 1..<pts.count {acc.append(acc[i-1]+hypot(pts[i].0-pts[i-1].0,pts[i].1-pts[i-1].1))}
    let total=acc.last!
    var v=[SCNVector3](),ix=[Int32]()
    let k=9
    for (i,p) in pts.enumerated() {
        let a=pts[max(0,i-1)],b=pts[min(pts.count-1,i+1)]
        var tz=b.0-a.0,ty=b.1-a.1
        let l=max(1e-9,hypot(tz,ty));tz/=l;ty/=l
        // Outward normal in the centre plane: up at the stem head, forward on the stem, down on the keel.
        let nz=ty,ny = -tz
        let taper=min(1,min(acc[i],total-acc[i])/0.4)
        // Stem bar forward of frame 104, keel box aft of frame 98.
        let keelness=min(1,max(0,(p.0+28.0)/3.5))
        let half=(0.075+0.085*keelness)*(0.35+0.65*taper),out=(0.085+0.085*keelness)*taper,embed=0.1+0.15*keelness
        for j in 0...k {
            let a=Double(j)/Double(k) * .pi
            let x = -cos(a)*half,d=sin(a)*out
            v.append(SCNVector3(x,p.1+ny*d,p.0+nz*d))
        }
        v.append(SCNVector3(half,p.1-ny*embed,p.0-nz*embed));v.append(SCNVector3(-half,p.1-ny*embed,p.0-nz*embed))
        if i<pts.count-1 {
            let w=Int32(k+3),base=Int32(i)*w
            for j in 0..<Int32(k) {ix += [base+j,base+j+1,base+w+j,base+j+1,base+w+j+1,base+w+j]}
            // Flanks down into the hull.
            ix += [base+Int32(k),base+Int32(k+1),base+w+Int32(k),base+Int32(k+1),base+w+Int32(k+1),base+w+Int32(k)]
            ix += [base+Int32(k+2),base,base+w+Int32(k+2),base,base+w,base+w+Int32(k+2)]
        }
    }
    part(parent,mesh(v,ix),m.dark).name="keel"
}

func buildDetailedHull(_ parent:SCNNode,_ m:VIICMaterials) {
    part(parent,detailedHullGeometry(),m.hull).name="detailedHull"
    part(parent,detailedDeckMesh(),m.timber).name="timberDeck"
    // Steel stem head: the deck rounds down over the bow into the stem.
    part(parent,detailedDeckMesh(from:DetailedHull.bowZ,to:DetailedHull.noseStart,steps:24),m.casing).name="stemHead"
    detailedKeel(parent,m)
    for side in [-1.0,1.0] {
        // Saddle tanks, blended into the lower hull; their forward ends taper in at frame 88.
        let tank=longitudinalMesh(start:-17.5,end:20,steps:120,sides:40) {z,a in
            let f=DetailedHull.saddleTankBulge(z)
            let x=side*DetailedHull.lowerRadius(z)*0.94+sin(a)*0.89*f
            return SCNVector3(x,-0.13+cos(a)*1.53*f,z)
        }
        part(parent,tank,m.hull).name="saddleTank"
        // Upper casing plating, with grouped flood openings instead of one uniform row.
        detailedPiercedBand(parent,m,side:side,lower:-0.42,upper:-0.24,from:-33.55,to:33.55,openings:detailedUpperOpenings)
        detailedSheet(parent,m.casing,z0:-33.55,z1:33.55,side:side,lower:-0.24,upper:0)
        detailedSheet(parent,m.casing,z0:-33.55,z1:33.55,side:side,lower:-0.49,upper:-0.42)
        detailedPiercedBand(parent,m,side:side,lower:-0.70,upper:-0.49,from:-33.55,to:33.55,openings:detailedLowerOpenings)
        // Toe rail along the deck edge.
        let zs=Array(stride(from:-33.2,through:33.3,by:0.4))
        for i in 0..<zs.count-1 {
            let z=zs[i],nz=zs[i+1]
            tube(parent,SCNVector3(side*DetailedHull.deckWidth(z),DetailedHull.deckHeight(z)+0.035,z),SCNVector3(side*DetailedHull.deckWidth(nz),DetailedHull.deckHeight(nz)+0.035,nz),0.03,m.steel)
        }
    }
}

// Flood openings: long rounded groups in the lower band, larger ports in the bow and stern.
let detailedLowerOpenings:[(Double,Double)]=[
    slotRun(-29.6,-25.0,length:0.46,pitch:0.62),slotRun(-23.8,-14.6,length:0.46,pitch:0.62),
    slotRun(-12.6,-4.4,length:0.38,pitch:0.55),slotRun(4.4,12.4,length:0.38,pitch:0.55),
    slotRun(13.6,22.2,length:0.46,pitch:0.62),slotRun(23.4,31.2,length:0.46,pitch:0.62)].flatMap{$0}
let detailedUpperOpenings:[(Double,Double)]=[
    slotRun(-30.8,-27.9,length:0.3,pitch:0.72),slotRun(-27.5,-26.0,length:0.3,pitch:0.5),
    slotRun(29.6,32.2,length:0.42,pitch:0.62)].flatMap{$0}

func makeDetailedSubmarine() -> (SCNNode,[SCNNode]) {
    let root=SCNNode();root.name="Type VIIC — detailed configuration"
    let fixed=SCNNode(),m=VIICMaterials()
    buildDetailedHull(fixed,m)
    buildDetailedDeck(fixed,m)
    // Conning tower after U-570; the deck gun of the classic model sits on the unchanged midship deck.
    buildDetailedTower(root,fixed,m)
    buildDeckGun(fixed,m)
    buildDetailedBow(root,fixed,m)
    let screws=buildDetailedStern(root,fixed,m)
    buildDetailedMarkings(fixed,m)
    buildDetailedMasts(root,fixed,m)
    // Batch static fittings by material; planes, rudders, screws and periscopes stay separate.
    let merged=batchStaticHierarchy(fixed);merged.name="staticFittings";root.addChildNode(merged)
    return (root,screws)
}

func runDetailedModelTests() {
    let L=DetailedLayout.self,H=DetailedHull.self
    // Hull closes at both ends and keeps the classic overall length.
    precondition(abs(H.sternZ-H.bowZ-67.1)<0.0001,"VIIC length")
    precondition(H.deckWidth(H.sternZ)<0.001 && H.deckWidth(H.bowZ)<0.001,"Closed ends")
    precondition(H.deckHeight(33)>2.3,"High stern overhang, not a dropped cone")
    // Screw discs clear the hull, the skeg and the guard frames.
    for side in [-1.0,1.0] {for i in 0..<36 {
        let a=Double(i)/36*2 * .pi
        let x=side*L.shaftX+cos(a)*L.screwRadius,y=L.shaftY+sin(a)*L.screwRadius
        precondition(detailedHalfWidth(L.screwZ,y)<abs(x)-0.1,"Screw tip clears the hull")
    }}
    precondition(L.screwRadius*2>1.6 && L.screwRadius*2<1.65,"1620 mm screws")
    // Order along the stern: screw, after planes directly behind, then rudders.
    let hubEnd=L.screwZ+0.62
    let planeLead=L.sternPlaneZ-0.3*L.sternPlaneChord*1.04,planeTrail=L.sternPlaneZ+0.7*L.sternPlaneChord*1.04
    let rudderLead=L.rudderZ-L.rudderStock*L.rudderChord*1.04
    precondition(hubEnd<planeLead && planeTrail<rudderLead,"Screw, then planes, then rudders")
    // Rudders hang under the overhang and inboard of its edge; their tops meet the hull.
    let under=detailedUnderside(z:L.rudderZ,x:L.rudderX)
    let s=HullSection2(z:L.rudderZ)
    precondition(s.bulgeW>L.rudderX+0.25 && under>L.rudderHeel+2,"Rudder under the stern overhang")
    precondition(L.rudderX<L.shaftX && L.rudderX>L.shaftX-L.screwRadius,"Rudders in the screw race")
    let rudderArea=(under+0.12-L.rudderHeel)*L.rudderChord*0.99
    precondition(abs(rudderArea-2.75)/2.75<0.12,"Rudder area close to 2.75 m²")
    // Plane areas: exposed span outside the hull times mean chord.
    let sternRoot=detailedHalfWidth(L.sternPlaneZ,L.sternPlaneY),bowRoot=detailedHalfWidth(L.bowPlaneZ,L.bowPlaneY)
    let sternArea=(L.sternPlaneTip-sternRoot)*L.sternPlaneChord,bowArea=(L.bowPlaneTip-bowRoot)*L.bowPlaneChord*0.98
    precondition(abs(sternArea-2.25)/2.25<0.12 && abs(bowArea-2.40)/2.40<0.15,"Plane areas close to the manual")
    precondition(L.bowPlaneY+0.2<L.lowerTubeY-L.tubeRadius,"Forward planes below the torpedo tubes")
    // Bow after the U-570 survey: stem raked about 36° between the tubes and the stem head, rounded
    // stem head below the deck line, keel rising from frame 90 into the forefoot.
    let rake=atan((H.stemZ(atHeight:0.3)-H.stemZ(atHeight:2.3))/2.0)*180 / .pi
    precondition(rake>32 && rake<40,"Raked stem")
    precondition(abs(H.deckHeight(H.bowZ)-H.stemCurve(H.bowZ))<0.01 && H.deckHeight(-32.25)-H.deckHeight(H.bowZ)>0.45,"Rounded stem head")
    precondition(abs(HullSection2(z:-17).keelY+2.85)<0.01 && HullSection2(z:-28.4).keelY > -1.5,"Keel rises into the forefoot")
    // Forward of frame 90 the bow is no wider than its deck edge (the survey plan's outline).
    for z in stride(from:-33.4,through:H.bowBlendStart,by:0.2) {
        let sec=HullSection2(z:z)
        for k in 0...20 {
            let y=sec.keelY+(sec.deckY-sec.keelY)*Double(k)/20
            precondition(sec.halfWidth(y)<=H.deckWidth(z)+1e-6,"Bow sections inside the deck edge")
        }
    }
    // Each tube runs inside the hull up to its muzzle (frame 106 on the survey), then cuts a long
    // opening towards the stem that its shutter covers; upper openings reach further forward.
    var openings=[(front:Double,aft:Double)]()
    for ty in [L.upperTubeY,L.lowerTubeY] {
        let o=tubeOpening(side:1,y:ty);openings.append(o)
        precondition(o.aft > -29.1 && o.aft < -28.1 && o.aft-o.front>1.8,"Tube opening ends at the muzzle")
        for z in stride(from:o.aft+0.05,through:-25.0,by:0.25) {for i in 0..<24 {
            let a=Double(i)/24*2 * .pi
            precondition(detailedHalfWidth(z,ty+sin(a)*L.tubeRadius) >= L.tubeX+cos(a)*L.tubeRadius-1e-3,"Tube enclosed aft of its opening")
        }}
        let sh=TubeShutter(side:1,tubeY:ty,below:0.47,above:0.47)
        for y in stride(from:sh.yBottom,through:sh.yTop,by:0.05) {
            precondition(sh.span(y).0>=H.stemZ(atHeight:y)+TubeShutter.stemClearance-1e-9 && sh.span(y).0<sh.span(y).1,"Shutter clear of the stem bar")
        }
    }
    precondition(openings[0].front<openings[1].front-0.4 && openings[0].aft-openings[0].front>openings[1].aft-openings[1].front,"Upper shutters longer, starting further forward")
    // Conning tower after U-570: low narrow bridge, platform aft, clear of the deck gun and deck edge.
    let T=TowerLayout.self,towerDeck=H.deckHeight(-2)
    precondition(T.rim-towerDeck>3.2 && T.rim-towerDeck<3.5 && T.ledge-towerDeck>1.7,"Bridge height above the deck")
    var widest=0.0
    for i in 0...200 {
        let z=T.front+(T.platformZ+T.fairingRadius-T.front)*Double(i)/200
        widest=max(widest,fairingHalfWidth(z))
        precondition(fairingHalfWidth(z)<H.deckWidth(z)-0.5,"Tower inside the deck casing")
    }
    precondition(widest<1.3 && towerHalfWidth(-2)<1.15,"Narrow early-war bridge")
    for z in [T.forwardScopeZ,T.aftScopeZ,T.uzoZ,T.hatchZ] {precondition(z>T.front+0.4 && z<T.bridgeAft && towerHalfWidth(z)>0.7,"Bridge fittings inside the coaming")}
    precondition(T.uzoZ<T.forwardScopeZ && T.forwardScopeZ<T.hatchZ && T.hatchZ<T.aftScopeZ,"UZO, sky periscope, hatch, attack periscope from fore to aft")
    let coamingEnd=hypot(towerHalfWidth(T.bridgeAft),T.bridgeAft-T.platformZ)
    precondition(abs(coamingEnd-T.railRadius)<0.06,"Platform railing continues the coaming")
    precondition(T.front-1.1 > -8+1.4,"Deck gun clear of the tower foot")
    // Moving parts are found by the game under the same names as on the classic model.
    let (model,screws)=makeDetailedSubmarine()
    precondition(screws.count==2 && screws[0].position.x<0 && screws[1].position.x>0,"Port then starboard screw")
    precondition(model.childNode(withName:"bowPlanes",recursively:true) != nil && model.childNode(withName:"sternPlanes",recursively:true) != nil,"Dive planes")
    precondition(model.childNodes.filter{$0.name=="rudder"}.count==2 && model.childNodes.filter{$0.name=="periscope"}.count==2,"Rudders and periscopes")
    print(String(format:"PASS — detailed VIIC: stern order, screw clearance, rudder %.2f m², planes %.2f / %.2f m², stem raked %.0f°, tube openings %.1f / %.1f m, tower %.2f m high × %.2f m",rudderArea,sternArea,bowArea,rake,openings[0].aft-openings[0].front,openings[1].aft-openings[1].front,T.rim-towerDeck,widest*2))
}
