import AppKit
let size = CGSize(width: 1024, height: 1024)
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor(red: 0.12, green: 0.35, blue: 0.29, alpha: 1).setFill()
NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
NSColor(red: 0.97, green: 0.97, blue: 0.95, alpha: 1).setFill()
NSBezierPath(roundedRect: CGRect(x: 190, y: 190, width: 644, height: 644), xRadius: 110, yRadius: 110).fill()
let text = "W" as NSString
text.draw(at: CGPoint(x: 268, y: 270), withAttributes: [.font: NSFont.systemFont(ofSize: 480, weight: .semibold), .foregroundColor: NSColor(red: 0.12, green: 0.35, blue: 0.29, alpha: 1)])
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
