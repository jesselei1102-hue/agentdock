// Renders the AgentDock app icon at every macOS AppIcon size.
// Usage: swift scripts/make_icon.swift   (run from repo root)
import AppKit
import CoreGraphics

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}

/// Apple-style continuous squircle (superellipse) path.
func squircle(_ r: CGRect, exponent n: CGFloat = 4.4) -> CGPath {
    let p = CGMutablePath()
    let a = r.width / 2, b = r.height / 2, cx = r.midX, cy = r.midY
    let steps = 720
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let c = cos(t), s = sin(t)
        let x = cx + a * copysign(pow(abs(c), 2 / n), c)
        let y = cy + b * copysign(pow(abs(s), 2 / n), s)
        if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
    }
    p.closeSubpath()
    return p
}

func render(px: Int) -> Data {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                        space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let k = CGFloat(px) / 1024
    ctx.scaleBy(x: k, y: k)
    ctx.interpolationQuality = .high
    ctx.setShouldAntialias(true)

    // Big Sur grid: 824pt body centred in 1024 canvas, slightly raised for the drop shadow.
    let body = CGRect(x: 100, y: 112, width: 824, height: 824)
    let shape = squircle(body)

    // Drop shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 34, color: rgb(0x000000, 0.45))
    ctx.addPath(shape); ctx.setFillColor(rgb(0x111214)); ctx.fillPath()
    ctx.restoreGState()

    // Body gradient (graphite top -> near black bottom)
    ctx.saveGState()
    ctx.addPath(shape); ctx.clip()
    let g = CGGradient(colorsSpace: cs, colors: [rgb(0x3A3D44), rgb(0x1C1D21), rgb(0x0A0A0C)] as CFArray,
                       locations: [0, 0.45, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: 512, y: body.maxY), end: CGPoint(x: 512, y: body.minY), options: [])
    // Soft top sheen
    let sheen = CGGradient(colorsSpace: cs, colors: [rgb(0xFFFFFF, 0.13), rgb(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(sheen, startCenter: CGPoint(x: 512, y: body.maxY + 40), startRadius: 0,
                           endCenter: CGPoint(x: 512, y: body.maxY + 40), endRadius: 560, options: [])
    // Ambient glow from the status dots
    let glow = CGGradient(colorsSpace: cs, colors: [rgb(0x30D158, 0.10), rgb(0x30D158, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 512, y: 628), startRadius: 0,
                           endCenter: CGPoint(x: 512, y: 628), endRadius: 420, options: [])
    ctx.restoreGState()

    // Hairline rim: bright at top, fading down
    ctx.saveGState()
    ctx.addPath(shape); ctx.setLineWidth(5); ctx.replacePathWithStrokedPath(); ctx.clip()
    let rim = CGGradient(colorsSpace: cs, colors: [rgb(0xFFFFFF, 0.28), rgb(0xFFFFFF, 0.04), rgb(0xFFFFFF, 0.08)] as CFArray,
                         locations: [0, 0.6, 1])!
    ctx.drawLinearGradient(rim, start: CGPoint(x: 512, y: body.maxY), end: CGPoint(x: 512, y: body.minY), options: [])
    ctx.restoreGState()

    // Notch / island pill hanging from the top edge
    let pill = CGRect(x: 512 - 250, y: 548, width: 500, height: 160)
    let pillPath = CGPath(roundedRect: pill, cornerWidth: 80, cornerHeight: 80, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 30, color: rgb(0x000000, 0.7))
    ctx.addPath(pillPath); ctx.setFillColor(rgb(0x000000)); ctx.fillPath()
    ctx.restoreGState()
    // pill inner rim
    ctx.saveGState()
    ctx.addPath(pillPath); ctx.setLineWidth(3); ctx.replacePathWithStrokedPath(); ctx.clip()
    let prim = CGGradient(colorsSpace: cs, colors: [rgb(0xFFFFFF, 0.22), rgb(0xFFFFFF, 0.03)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(prim, start: CGPoint(x: 512, y: pill.maxY), end: CGPoint(x: 512, y: pill.minY), options: [])
    ctx.restoreGState()

    // Status dots: green, yellow, orange
    let colors: [UInt32] = [0x30D158, 0xFFD60A, 0xFF9F0A]
    let d: CGFloat = 64, gap: CGFloat = 46
    let total = d * 3 + gap * 2
    for (i, c) in colors.enumerated() {
        let x = 512 - total / 2 + CGFloat(i) * (d + gap)
        let r = CGRect(x: x, y: pill.midY - d / 2, width: d, height: d)
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 26, color: rgb(c, 0.75))
        ctx.setFillColor(rgb(c)); ctx.fillEllipse(in: r)
        ctx.restoreGState()
        // specular highlight
        ctx.saveGState()
        ctx.addEllipse(in: r); ctx.clip()
        let hl = CGGradient(colorsSpace: cs, colors: [rgb(0xFFFFFF, 0.45), rgb(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(hl, startCenter: CGPoint(x: r.midX - 8, y: r.midY + 14), startRadius: 0,
                               endCenter: CGPoint(x: r.midX - 8, y: r.midY + 14), endRadius: d * 0.55, options: [])
        ctx.restoreGState()
    }

    // Faint "expanded panel" rows below the island
    ctx.saveGState()
    for (i, w) in [CGFloat(420), 340].enumerated() {
        let y = 430 - CGFloat(i) * 76
        let row = CGRect(x: 512 - w / 2, y: y, width: w, height: 30)
        ctx.addPath(CGPath(roundedRect: row, cornerWidth: 15, cornerHeight: 15, transform: nil))
        ctx.setFillColor(rgb(0xFFFFFF, i == 0 ? 0.10 : 0.06)); ctx.fillPath()
    }
    ctx.restoreGState()

    let img = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: img)
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath)
let set = root.appendingPathComponent("native/AgentStatusBar/Resources/Assets.xcassets/AppIcon.appiconset")
try fm.createDirectory(at: set, withIntermediateDirectories: true)
var images: [[String: String]] = []
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(base)x\(base)\(scale == 2 ? "@2x" : "").png"
        try render(px: base * scale).write(to: set.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(base)x\(base)", "scale": "\(scale)x", "filename": name])
    }
}
let json: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
try data.write(to: set.appendingPathComponent("Contents.json"))
try fm.createDirectory(at: root.appendingPathComponent("docs"), withIntermediateDirectories: true)
try render(px: 1024).write(to: root.appendingPathComponent("docs/icon.png"))
print("ok")
