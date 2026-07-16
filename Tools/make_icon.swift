import AppKit

// Regenerates Resources/POMO.icns. Run via Tools/make_icon.sh — not part of the build.
// The mark is the same depleting ring the status bar draws.

func icon(size: Double) -> NSImage {
    NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
        let unit = size / 1024

        // Apple's icon grid: an 824pt shape on a 1024pt canvas.
        let shape = NSRect(x: 100 * unit, y: 100 * unit, width: 824 * unit, height: 824 * unit)
        let squircle = NSBezierPath(roundedRect: shape,
                                    xRadius: 185 * unit,
                                    yRadius: 185 * unit)
        squircle.addClip()
        NSGradient(starting: NSColor(srgbRed: 1.00, green: 0.42, blue: 0.36, alpha: 1),
                   ending: NSColor(srgbRed: 0.87, green: 0.20, blue: 0.16, alpha: 1))?
            .draw(in: shape, angle: -90)

        let center = NSPoint(x: size / 2, y: size / 2)
        let radius = 230 * unit
        let width = 64 * unit

        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        track.lineWidth = width
        NSColor(white: 1, alpha: 0.3).setStroke()
        track.stroke()

        // 75% remaining — reads as a timer mid-run rather than an empty circle.
        let arc = NSBezierPath()
        arc.appendArc(withCenter: center, radius: radius,
                      startAngle: 90, endAngle: 90 - 360 * 0.75, clockwise: true)
        arc.lineWidth = width
        arc.lineCapStyle = .round
        NSColor.white.setStroke()
        arc.stroke()

        return true
    }
}

let iconset = URL(fileURLWithPath: CommandLine.arguments[1])
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

// Each size is drawn at its native resolution, never downscaled.
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = base * scale
        let image = icon(size: Double(pixels))
        let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let png = rep.representation(using: .png, properties: [:])!
        let suffix = scale == 2 ? "@2x" : ""
        try! png.write(to: iconset.appendingPathComponent("icon_\(base)x\(base)\(suffix).png"))
    }
}
print("wrote \(iconset.path)")
