// Renders the app icon: a forest-to-fern gradient with a white runner.
//
//     swift Tools/make_icon.swift
//
// Writes C25K/Assets.xcassets/AppIcon.appiconset/icon-1024.png (opaque, as iOS requires).

import AppKit

let size = 1024
// 32 bits per pixel with the alpha byte skipped: opaque, which CoreGraphics can draw into.
let cg = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                   space: CGColorSpace(name: CGColorSpace.sRGB)!,
                   bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: false)

func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

let rect = NSRect(x: 0, y: 0, width: size, height: size)
NSGradient(colors: [color(0x173D2F), color(0x2E5E4E), color(0x4F8A6B)])!.draw(in: rect, angle: 60)

// A soft mint glow in the upper right, echoing the app's header.
NSGradient(colors: [color(0xE2EFE6).withAlphaComponent(0.35), color(0xE2EFE6).withAlphaComponent(0)])!
    .draw(in: NSBezierPath(ovalIn: NSRect(x: 420, y: 420, width: 900, height: 900)),
          relativeCenterPosition: .zero)

let config = NSImage.SymbolConfiguration(pointSize: 560, weight: .semibold)
    .applying(.init(paletteColors: [.white]))
let runner = NSImage(systemSymbolName: "figure.run", accessibilityDescription: nil)!
    .withSymbolConfiguration(config)!
let s = runner.size
runner.draw(in: NSRect(x: (CGFloat(size) - s.width) / 2, y: (CGFloat(size) - s.height) / 2,
                       width: s.width, height: s.height))

NSGraphicsContext.current?.flushGraphics()
NSGraphicsContext.restoreGraphicsState()
let out = URL(fileURLWithPath: "C25K/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
let rep = NSBitmapImageRep(cgImage: cg.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: out)
print("wrote \(out.path)")
