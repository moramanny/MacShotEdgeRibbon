// SPDX-License-Identifier: LicenseRef-BocaTechForce-Free-Use-No-Sale-1.0
// Copyright (c) 2026 BocaTechForce

import AppKit
import Foundation

let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let image = NSImage(size: NSSize(width: 1024, height: 1024), flipped: false) { _ in
            let base = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 200, yRadius: 200)
            NSGradient(starting: NSColor(calibratedRed: 0.12, green: 0.64, blue: 0.98, alpha: 1), ending: NSColor(calibratedRed: 0.08, green: 0.24, blue: 0.73, alpha: 1))!.draw(in: base, angle: -70)
            NSColor(calibratedWhite: 1, alpha: 0.20).setFill()
            NSBezierPath(roundedRect: NSRect(x: 817, y: 273, width: 90, height: 478), xRadius: 37, yRadius: 37).fill()
            NSColor.white.setFill()
            NSBezierPath(roundedRect: NSRect(x: 220, y: 324, width: 545, height: 365), xRadius: 65, yRadius: 65).fill()
            NSBezierPath(roundedRect: NSRect(x: 342, y: 648, width: 225, height: 101), xRadius: 27, yRadius: 27).fill()
            NSColor(calibratedRed: 0.08, green: 0.35, blue: 0.81, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 377, y: 377, width: 239, height: 239)).fill()
            NSColor(calibratedRed: 0.20, green: 0.66, blue: 1, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 408, y: 408, width: 177, height: 177)).fill()
            NSColor(calibratedWhite: 1, alpha: 0.85).setFill()
            NSBezierPath(ovalIn: NSRect(x: 434, y: 513, width: 42, height: 42)).fill()
            return true
        }
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        let target = destination.appendingPathComponent("icon_\(points)x\(points)\(suffix).png")
        try bitmap.representation(using: .png, properties: [:])!.write(to: target)
    }
}
