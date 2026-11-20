import AppKit

let output = CommandLine.arguments.dropFirst().first ?? "assets/AppIcon.iconset"
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)

func render(size: Int) -> Data {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let body = NSRect(x: s * 100 / 1024, y: s * 100 / 1024, width: s * 824 / 1024, height: s * 824 / 1024)
    let radius = body.width * 0.2237
    let shape = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.012)
    shadow.shadowBlurRadius = s * 0.03
    shadow.set()
    NSColor.black.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(
        starting: NSColor(red: 0.22, green: 0.24, blue: 0.46, alpha: 1),
        ending: NSColor(red: 0.08, green: 0.09, blue: 0.19, alpha: 1)
    )?.draw(in: shape, angle: -90)

    NSColor.white.withAlphaComponent(0.16).setStroke()
    let rim = NSBezierPath(roundedRect: body.insetBy(dx: s * 0.004, dy: s * 0.004), xRadius: radius, yRadius: radius)
    rim.lineWidth = max(1, s * 0.006)
    rim.stroke()

    let config = NSImage.SymbolConfiguration(pointSize: s * 0.42, weight: .bold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    if let club = NSImage(systemSymbolName: "suit.club.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
        let fit = s * 0.5 / max(club.size.width, club.size.height)
        let size = NSSize(width: club.size.width * fit, height: club.size.height * fit)
        let origin = NSPoint(x: body.midX - size.width / 2, y: body.midY - size.height / 2)
        NSGraphicsContext.saveGraphicsState()
        let glow = NSShadow()
        glow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        glow.shadowOffset = NSSize(width: 0, height: -s * 0.008)
        glow.shadowBlurRadius = s * 0.02
        glow.set()
        club.draw(in: NSRect(origin: origin, size: size))
        NSGraphicsContext.restoreGraphicsState()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for points in [16, 32, 128, 256, 512] {
    try render(size: points).write(to: URL(fileURLWithPath: "\(output)/icon_\(points)x\(points).png"))
    try render(size: points * 2).write(to: URL(fileURLWithPath: "\(output)/icon_\(points)x\(points)@2x.png"))
}
