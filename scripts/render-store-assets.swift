import AppKit

// Deterministic marketing layouts. The app captures are embedded unchanged.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let out = root.appendingPathComponent("release/store-assets")
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255)/255, green: CGFloat((hex >> 8) & 255)/255, blue: CGFloat(hex & 255)/255, alpha: 1)
}
let forest = color(0x123F32)
let ivory = color(0xF4F2E9)
let captions = [
    ("Keep the board.\nLose the scorepad.", "Every player. Every turn. All in one place.", "01-Board"),
    ("Zoom in.\nStay in the game.", "Pinch, pan, and place with precision.", "02-Zoom"),
    ("Place your tiles.\nCount every point.", "Words, cross-words, blanks, and bonuses.", "03-Score")
]
for kind in (CommandLine.arguments.count > 1 ? Array(CommandLine.arguments.dropFirst()) : ["iPhone", "iPad"]) {
    let w: CGFloat = kind == "iPhone" ? 1320 : 2064
    let h: CGFloat = kind == "iPhone" ? 2868 : 2752
    for (index, item) in captions.enumerated() {
        let dark = index == 1
        let cg = CGContext(data: nil, width: Int(w), height: Int(h), bitsPerComponent: 8, bytesPerRow: Int(w)*4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: false)
        cg.translateBy(x: 0, y: h); cg.scaleBy(x: 1, y: -1)
        let canvas = NSRect(x: 0, y: 0, width: w, height: h)
        (dark ? forest : ivory).setFill(); canvas.fill()
        let textColor = dark ? ivory : forest
        let muted = dark ? color(0xCAD8CC) : color(0x62746A)
        func text(_ string: String, _ rect: NSRect, size: CGFloat, weight: NSFont.Weight, ink: NSColor, tracking: CGFloat = 0) {
            let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center; paragraph.lineSpacing = 0
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: ink, .paragraphStyle: paragraph, .kern: tracking]
            // AppKit text drawing uses its own coordinate orientation.
            NSGraphicsContext.saveGraphicsState()
            let context = NSGraphicsContext.current!
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context.cgContext, flipped: true)
            (string as NSString).draw(in: rect, withAttributes: attrs)
            NSGraphicsContext.restoreGraphicsState()
        }
        let ipad = kind == "iPad"
        text("WORD CHECK", NSRect(x: 80,y: ipad ? 66 : 96,width:w-160,height:58), size: ipad ? 40 : 34,weight:.semibold,ink:muted,tracking:5)
        text(item.0, NSRect(x: 90,y: ipad ? 138 : 180,width:w-180,height:300),size:ipad ? 116 : 98,weight:.bold,ink:textColor,tracking:-3)
        text(item.1, NSRect(x:70,y:ipad ? 431 : 462,width:w-140,height:76),size:ipad ? 43 : 36,weight:.regular,ink:muted,tracking:-0.6)
        let capture = NSImage(contentsOf: root.appendingPathComponent("release/screenshots/\(kind)-\(item.2).png"))!
        let sw: CGFloat = ipad ? 1550 : 960
        let sh = sw * capture.size.height / capture.size.width
        let frame = NSRect(x:(w-sw)/2,y:ipad ? 602 : 654,width:sw,height:sh)
        let radius: CGFloat = ipad ? 66 : 96
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(dark ? 0.32 : 0.16); shadow.shadowBlurRadius = 56; shadow.shadowOffset = NSSize(width: 0, height: 24); shadow.set()
        color(0xD0D2C9).setFill()
        NSBezierPath(roundedRect: frame.insetBy(dx:-8,dy:-8), xRadius:radius+8,yRadius:radius+8).fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect:frame,xRadius:radius,yRadius:radius).addClip()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
        capture.draw(in:frame,from:.zero,operation:.copy,fraction:1,respectFlipped:true,hints:[.interpolation:NSImageInterpolation.high])
        NSGraphicsContext.restoreGraphicsState()
        NSGraphicsContext.restoreGraphicsState()
        try NSBitmapImageRep(cgImage: cg.makeImage()!).representation(using:.png,properties:[:])!.write(to:out.appendingPathComponent("\(kind)-\(item.2).png"))
    }
}
