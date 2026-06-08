#!/usr/bin/env swift
import AppKit

// Renders the AppIcon as a full .iconset directory.
// Usage: swift generate_icon.swift <output.iconset>

let outDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon.iconset"

func draw(size s: CGFloat) {
    // Background: rounded-rect gradient (the macOS "squircle"-ish look).
    let inset = s * 0.06
    let bgRect = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: s * 0.225, yRadius: s * 0.225)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.30, green: 0.50, blue: 0.98, alpha: 1.0),
        NSColor(calibratedRed: 0.40, green: 0.28, blue: 0.85, alpha: 1.0)
    ])!
    gradient.draw(in: bgPath, angle: -90)

    // Clipboard paper (white rounded rect).
    let paper = NSRect(x: s * 0.30, y: s * 0.16, width: s * 0.40, height: s * 0.58)
    let paperPath = NSBezierPath(roundedRect: paper, xRadius: s * 0.045, yRadius: s * 0.045)
    NSColor.white.setFill()
    paperPath.fill()

    // Clip at the top.
    let clip = NSRect(x: s * 0.41, y: s * 0.68, width: s * 0.18, height: s * 0.10)
    let clipPath = NSBezierPath(roundedRect: clip, xRadius: s * 0.03, yRadius: s * 0.03)
    NSColor(calibratedWhite: 0.82, alpha: 1.0).setFill()
    clipPath.fill()

    // Text lines on the paper.
    NSColor(calibratedRed: 0.34, green: 0.40, blue: 0.62, alpha: 1.0).setStroke()
    let lineX0 = s * 0.36
    let lineX1 = s * 0.64
    for (i, frac) in [0.56, 0.46, 0.36].enumerated() {
        let y = s * CGFloat(frac)
        let line = NSBezierPath()
        line.lineWidth = s * 0.028
        line.lineCapStyle = .round
        let endX = i == 2 ? s * 0.54 : lineX1   // last line shorter
        line.move(to: NSPoint(x: lineX0, y: y))
        line.line(to: NSPoint(x: endX, y: y))
        line.stroke()
    }
}

func renderPNG(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    draw(size: CGFloat(pixels))
    ctx.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
try? fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// (filename, pixel dimension)
let variants: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, px) in variants {
    let data = renderPNG(pixels: px)
    let path = (outDir as NSString).appendingPathComponent(name)
    try! data.write(to: URL(fileURLWithPath: path))
}

print("Wrote \(variants.count) icon variants to \(outDir)")
