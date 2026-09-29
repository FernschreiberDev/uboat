import AppKit
import SceneKit

private func textureCanvas(_ width:Int,_ height:Int,_ draw:()->Void) -> NSImage {
    let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:rep)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    let image=NSImage(size:NSSize(width:width,height:height));image.addRepresentation(rep)
    return image
}
func navalPaint(_ base:UInt32,columns:Int=24,rows:Int=6) -> SCNMaterial {
    var seed:UInt64=54325
    func random()->Double {seed=6364136223846793005 &* seed &+ 1;return Double(seed>>33)/Double(UInt32.max>>1)}
    let width=2048,height=1024
    let image=textureCanvas(width,height) {
        color(base).setFill();NSRect(x:0,y:0,width:width,height:height).fill()
        let pw=Double(width)/Double(columns),ph=Double(height)/Double(rows)
        for row in 0..<rows {
            for column in -1...columns {
                let x=Double(column)*pw+(row%2==0 ? 0:pw/2),y=Double(row)*ph
                let r=NSRect(x:x,y:y,width:pw,height:ph)
                (random()>0.5 ? NSColor.white:NSColor.black).withAlphaComponent(0.01+random()*0.018).setFill();r.fill()
                NSColor.black.withAlphaComponent(0.3).setStroke()
                let seam=NSBezierPath(rect:r.insetBy(dx:0.6,dy:0.6));seam.lineWidth=1.3;seam.stroke()
                NSColor.white.withAlphaComponent(0.11).setStroke()
                let highlight=NSBezierPath();highlight.move(to:NSPoint(x:x+1.8,y:y+1.8));highlight.line(to:NSPoint(x:x+pw-1,y:y+1.8));highlight.line(to:NSPoint(x:x+pw-1,y:y+ph-1));highlight.lineWidth=0.8;highlight.stroke()
                for _ in 0..<3 {
                    let sx=x+random()*pw,sy=y+ph-3,length=8+random()*ph*0.7
                    color(0x493127,CGFloat(0.04+random()*0.09)).setStroke()
                    let drip=NSBezierPath();drip.move(to:NSPoint(x:sx,y:sy));drip.curve(to:NSPoint(x:sx+random()*3,y:sy-length),controlPoint1:NSPoint(x:sx+2,y:sy-length*0.3),controlPoint2:NSPoint(x:sx-2,y:sy-length*0.6));drip.lineWidth=1+random()*3;drip.stroke()
                }
            }
        }
        // Small chips and deposits break up the otherwise perfect painted surface.
        for _ in 0..<12000 {
            let x=random()*Double(width),y=random()*Double(height)
            (random()>0.5 ? NSColor.white:NSColor.black).withAlphaComponent(CGFloat(random()*0.11)).setFill()
            NSRect(x:x,y:y,width:1+random()*2,height:0.6+random()).fill()
        }
        for _ in 0..<250 {
            color(0x4a3429,CGFloat(0.05+random()*0.08)).setFill()
            NSBezierPath(ovalIn:NSRect(x:random()*Double(width),y:random()*Double(height),width:1+random()*10,height:1+random()*18)).fill()
        }
    }
    let m=material(base,metal:0.18,rough:0.76)
    m.diffuse.contents=image;m.diffuse.wrapS = .repeat;m.diffuse.wrapT = .repeat
    m.diffuse.mipFilter = .linear;m.diffuse.maxAnisotropy=8
    return m
}
func timberDeck() -> SCNMaterial {
    var seed:UInt64=593
    func random()->Double {seed=2862933555777941757 &* seed &+ 3037000493;return Double(seed>>33)/Double(UInt32.max>>1)}
    let image=textureCanvas(1024,2048) {
        color(0x343c39).setFill();NSRect(x:0,y:0,width:1024,height:2048).fill()
        let plankWidth=34.0
        for i in 0..<31 {
            let x=Double(i)*plankWidth
            let v=0.23+random()*0.055
            NSColor(srgbRed:v*0.96,green:v,blue:v*0.97,alpha:1).setFill()
            NSRect(x:x+1,y:0,width:plankWidth-2,height:2048).fill()
            for _ in 0..<25 {
                NSColor.black.withAlphaComponent(CGFloat(random()*0.15)).setStroke()
                let px=x+random()*plankWidth,p=NSBezierPath();p.move(to:NSPoint(x:px,y:0));p.line(to:NSPoint(x:px+random()*1.5,y:2048));p.lineWidth=0.4+random();p.stroke()
            }
            for j in 0..<13 {
                let y=Double(j)*170+Double(i%3)*52
                NSColor.black.withAlphaComponent(0.55).setFill();NSRect(x:x,y:y,width:plankWidth,height:1.5).fill()
                for bx in [x+6,x+plankWidth-6] {
                    NSBezierPath(ovalIn:NSRect(x:bx,y:y+5,width:2,height:2)).fill()
                    NSBezierPath(ovalIn:NSRect(x:bx,y:y-6,width:2,height:2)).fill()
                }
            }
        }
        // Rectangular drainage slots between the deck battens.
        color(0x121e1f).setFill()
        for i in stride(from:1,to:30,by:2) {for j in 0..<44 {
            NSBezierPath(roundedRect:NSRect(x:Double(i)*34+7,y:Double(j)*46+Double(i%3)*8,width:7,height:24),xRadius:2,yRadius:2).fill()
        }}
    }
    let m=material(0x4a4b42,rough:0.9);m.diffuse.contents=image;m.diffuse.maxAnisotropy=16
    return m
}
struct VIICMaterials {
    let hull=navalPaint(0x454f52,columns:30,rows:9)
    let casing=navalPaint(0x737c7c,columns:30,rows:4)
    let tower=navalPaint(0x939b99,columns:10,rows:4)
    let steel=material(0x727d7c,metal:0.23,rough:0.64)
    let dark=material(0x293335,metal:0.25,rough:0.72)
    let recess=material(0x0a1215,rough:1)
    let wornEdge=material(0x9daba7,metal:0.4,rough:0.58)
    let timber=timberDeck()
    let brass=material(0x8e794e,metal:0.8,rough:0.36)
    let chrome=material(0xb3b8b2,metal:0.85,rough:0.23)
    let rust=material(0x5d4636,metal:0.05,rough:0.97)
}
