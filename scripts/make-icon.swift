#!/usr/bin/env swift
//
// Glassbook app icon generator.
// On-brand: Aurora 3-spot gradient background + frosted glass card + ¥ in ultraLight ink.
// Draws directly to a 1024×1024 CGContext (bypasses NSImage retina auto-scaling).
// Run: swift scripts/make-icon.swift

import AppKit
import CoreText

let size: CGFloat = 1024
let output = "Glassbook/Glassbook/Assets.xcassets/AppIcon.appiconset/Icon-1024.png"

let colorSpace = CGColorSpaceCreateDeviceRGB()
let bytesPerRow = Int(size) * 4
guard let ctx = CGContext(
    data: nil,
    width: Int(size), height: Int(size),
    bitsPerComponent: 8,
    bytesPerRow: bytesPerRow,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("CGContext create failed") }

// ——— Base vertical gradient ———
let baseGrad = CGGradient(colorsSpace: colorSpace, colors: [
    CGColor(srgbRed: 0.99, green: 0.89, blue: 0.82, alpha: 1.0),   // warm peach
    CGColor(srgbRed: 0.91, green: 0.88, blue: 1.0, alpha: 1.0),    // lavender
] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(baseGrad,
                       start: .init(x: 0, y: size),
                       end:   .init(x: 0, y: 0),
                       options: [])

// ——— Three aurora spots ———
func spot(at c: CGPoint, r: CGFloat, color: CGColor) {
    let colors = [color, color.copy(alpha: 0)!] as CFArray
    let g = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1])!
    ctx.drawRadialGradient(g, startCenter: c, startRadius: 0,
                           endCenter: c, endRadius: r, options: [])
}
spot(at: .init(x: size * 0.15, y: size * 0.08), r: size * 0.55,
     color: CGColor(srgbRed: 1.0, green: 0.69, blue: 0.60, alpha: 0.80))
spot(at: .init(x: size * 0.85, y: size * 0.22), r: size * 0.58,
     color: CGColor(srgbRed: 0.61, green: 0.75, blue: 1.0, alpha: 0.80))
spot(at: .init(x: size * 0.50, y: size * 0.82), r: size * 0.68,
     color: CGColor(srgbRed: 0.83, green: 0.65, blue: 1.0, alpha: 0.60))

// ——— Glass card drop shadow ———
let inset: CGFloat = 180
let rect = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
let corner: CGFloat = 140
let roundedPath = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)

ctx.saveGState()
ctx.setShadow(offset: .init(width: 0, height: -18),
              blur: 50,
              color: CGColor(srgbRed: 0.31, green: 0.24, blue: 0.47, alpha: 0.28))
ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.48))
ctx.addPath(roundedPath)
ctx.fillPath()
ctx.restoreGState()

// ——— Highlight border ———
let borderRect = rect.insetBy(dx: 3, dy: 3)
let borderPath = CGPath(roundedRect: borderRect,
                        cornerWidth: corner - 3, cornerHeight: corner - 3,
                        transform: nil)
ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.85))
ctx.setLineWidth(6)
ctx.addPath(borderPath)
ctx.strokePath()

// ——— ¥ glyph in ultralight ink ———
let font = CTFontCreateWithName(
    "SFProDisplay-Ultralight" as CFString,
    560,
    nil
)
let fallback = CTFontCreateUIFontForLanguage(.system, 560, "en" as CFString)
// Use whichever resolves — SF Pro UltraLight on 13+, fallback on older.
let useFont = CTFontCopyFullName(font) as String == "SFProDisplay-Ultralight"
    ? font
    : (fallback ?? font)

let attrs: [CFString: Any] = [
    kCTFontAttributeName: useFont,
    kCTForegroundColorAttributeName: CGColor(srgbRed: 0.10, green: 0.10, blue: 0.18, alpha: 1.0),
]
let attrStr = CFAttributedStringCreate(nil, "¥" as CFString, attrs as CFDictionary)!
let line = CTLineCreateWithAttributedString(attrStr)
let textBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)

ctx.textMatrix = .identity
ctx.textPosition = CGPoint(
    x: (size - textBounds.width) / 2 - textBounds.origin.x,
    y: (size - textBounds.height) / 2 - textBounds.origin.y
)
CTLineDraw(line, ctx)

// ——— Write PNG ———
guard let cg = ctx.makeImage() else { fatalError("makeImage failed") }
let rep = NSBitmapImageRep(cgImage: cg)
guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("PNG encode failed")
}
let url = URL(fileURLWithPath: output)
try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                         withIntermediateDirectories: true)
try png.write(to: url)
print("✓ Icon saved \(Int(size))×\(Int(size)) → \(url.path)")
