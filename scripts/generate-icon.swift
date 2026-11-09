import AppKit
import Foundation

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Assets/AppIcon.png"
let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
bitmap.size = NSSize(width: size, height: size)
let context = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high
context.cgContext.setAllowsAntialiasing(true)
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: a) }
let background = NSBezierPath(roundedRect: NSRect(x: 40, y: 40, width: 944, height: 944), xRadius: 225, yRadius: 225)
NSGradient(starting: color(0.10, 0.22, 0.24), ending: color(0.035, 0.075, 0.10))!.draw(in: background, angle: -55)
// The interrupted orbital ring evokes observation without relying on a generic heart-beat mark.
let ring = NSBezierPath()
ring.appendArc(withCenter: NSPoint(x: 512, y: 512), radius: 310, startAngle: 36, endAngle: 315, clockwise: false)
ring.lineWidth = 39
ring.lineCapStyle = .round
color(0.36, 0.86, 0.71).setStroke(); ring.stroke()
let insetRing = NSBezierPath(ovalIn: NSRect(x: 254, y: 254, width: 516, height: 516))
insetRing.lineWidth = 3
color(0.65, 1.0, 0.89, 0.16).setStroke(); insetRing.stroke()
// Three distinct rounded bars form an abstract signal within the scope.
for (x, y, height) in [(350, 390, 220), (474, 322, 356), (598, 424, 152)] {
    let bar = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: 74, height: height), xRadius: 37, yRadius: 37)
    NSGradient(starting: color(0.82, 1.0, 0.93), ending: color(0.36, 0.85, 0.71))!.draw(in: bar, angle: 90)
}
let dot = NSBezierPath(ovalIn: NSRect(x: 720, y: 722, width: 66, height: 66))
color(0.84, 1.0, 0.94).setFill(); dot.fill()
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
