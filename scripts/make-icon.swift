import AppKit

let size = 1024.0
let output = URL(fileURLWithPath: CommandLine.arguments[1])
let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
    let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
    let squircle = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    NSColor.black.setFill()
    squircle.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    NSGradient(colors: [
        NSColor(red: 0.49, green: 0.36, blue: 1.0, alpha: 1),
        NSColor(red: 0.93, green: 0.27, blue: 0.48, alpha: 1),
    ])!.draw(in: squircle, angle: -50)

    NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), NSColor.white.withAlphaComponent(0)])!
        .draw(in: NSBezierPath(ovalIn: NSRect(x: 60, y: 460, width: 700, height: 600)), relativeCenterPosition: .zero)

    let lens = NSRect(x: 270, y: 350, width: 380, height: 380)
    NSColor.white.withAlphaComponent(0.16).setFill()
    NSBezierPath(ovalIn: lens).fill()
    let ring = NSBezierPath(ovalIn: lens)
    ring.lineWidth = 58
    NSColor.white.setStroke()
    ring.stroke()

    let handle = NSBezierPath()
    handle.move(to: NSPoint(x: 615, y: 385))
    handle.line(to: NSPoint(x: 760, y: 240))
    handle.lineWidth = 78
    handle.lineCapStyle = .round
    handle.stroke()

    NSColor(red: 1.0, green: 0.27, blue: 0.33, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: 410, y: 490, width: 100, height: 100)).fill()
    return true
}

let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: output)
