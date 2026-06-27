#!/usr/bin/env swift

// Generates Le Castelet's app icon — a warm toy-theatre / maquette mark.
//
// Design: a brass-gilt proscenium arch with two swept velvet curtains framing a tiny golden
// house (the maquette) on a glowing stage, over a deep curtain-red squircle. Reads from the
// Dock down to a 1024 Home-Screen render.
//
// Writes a single 1024 full-bleed opaque icon into Resources/Assets.xcassets/AppIcon.appiconset
// and rewrites its Contents.json. iOS applies its own rounded mask, so the icon is a full,
// opaque square.
//
// Run from the project root:  swift scripts/make-icon.swift

import AppKit
import CoreGraphics
import Foundation

let redTop    = CGColor(srgbRed: 0.55, green: 0.13, blue: 0.18, alpha: 1)   // #8C2230
let redBottom = CGColor(srgbRed: 0.33, green: 0.08, blue: 0.12, alpha: 1)   // #54141F
let brass     = CGColor(srgbRed: 0.82, green: 0.64, blue: 0.30, alpha: 1)   // #D1A34D
let brassHi   = CGColor(srgbRed: 0.95, green: 0.83, blue: 0.50, alpha: 1)
let velvet    = CGColor(srgbRed: 0.62, green: 0.13, blue: 0.18, alpha: 1)
let velvetHi  = CGColor(srgbRed: 0.78, green: 0.20, blue: 0.25, alpha: 1)
let stageGlow = CGColor(srgbRed: 0.99, green: 0.86, blue: 0.58, alpha: 1)
let houseGold = CGColor(srgbRed: 0.97, green: 0.80, blue: 0.42, alpha: 1)
let houseDk   = CGColor(srgbRed: 0.80, green: 0.55, blue: 0.22, alpha: 1)

func renderIcon(pixelSize: Int) -> Data {
    let size = CGFloat(pixelSize)
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil, width: pixelSize, height: pixelSize,
                              bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
        fatalError("CGContext init failed")
    }
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    func p(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint { CGPoint(x: fx * size, y: fy * size) }
    func len(_ f: CGFloat) -> CGFloat { f * size }

    // Background — vertical velvet-red gradient.
    ctx.setFillColor(redBottom); ctx.fill(rect)
    if let g = CGGradient(colorsSpace: cs, colors: [redTop, redBottom] as CFArray, locations: [0, 1]) {
        ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])
    }

    // Stage glow — a warm radial pool behind the house.
    if let glow = CGGradient(colorsSpace: cs,
                             colors: [stageGlow, CGColor(srgbRed: 0.99, green: 0.86, blue: 0.58, alpha: 0)] as CFArray,
                             locations: [0, 1]) {
        ctx.drawRadialGradient(glow,
                               startCenter: p(0.5, 0.46), startRadius: 0,
                               endCenter: p(0.5, 0.46), endRadius: len(0.34),
                               options: [])
    }

    // Stage floor — a brass band the house stands on.
    ctx.setFillColor(brass)
    ctx.fill(CGRect(x: len(0.20), y: len(0.30), width: len(0.60), height: len(0.045)))

    // The tiny house (maquette) on the stage.
    let hx = size * 0.5, baseY = size * 0.345
    let bodyW = len(0.20), bodyH = len(0.155)
    ctx.setFillColor(houseGold)
    ctx.fill(CGRect(x: hx - bodyW/2, y: baseY, width: bodyW, height: bodyH))
    // Roof.
    ctx.beginPath()
    ctx.move(to: CGPoint(x: hx - bodyW/2 - len(0.018), y: baseY + bodyH))
    ctx.addLine(to: CGPoint(x: hx, y: baseY + bodyH + len(0.085)))
    ctx.addLine(to: CGPoint(x: hx + bodyW/2 + len(0.018), y: baseY + bodyH))
    ctx.closePath()
    ctx.setFillColor(houseDk); ctx.fillPath()
    // A glowing window + door.
    ctx.setFillColor(redBottom)
    ctx.fill(CGRect(x: hx - len(0.028), y: baseY, width: len(0.056), height: len(0.075)))      // door
    ctx.setFillColor(stageGlow)
    ctx.fill(CGRect(x: hx + len(0.04), y: baseY + len(0.06), width: len(0.045), height: len(0.045)))  // window

    // Proscenium arch — a brass top valance.
    ctx.setFillColor(brass)
    ctx.fill(CGRect(x: len(0.14), y: len(0.72), width: len(0.72), height: len(0.10)))
    // Scalloped valance edge.
    let scallops = 7
    let valW = len(0.72) / CGFloat(scallops)
    for i in 0..<scallops {
        let cx = len(0.14) + valW * (CGFloat(i) + 0.5)
        ctx.setFillColor(brassHi)
        ctx.fillEllipse(in: CGRect(x: cx - valW/2, y: len(0.69), width: valW, height: len(0.06)))
    }

    // Two velvet curtains sweeping in from each side.
    func curtain(left: Bool) {
        let sign: CGFloat = left ? 1 : -1
        let edge: CGFloat = left ? 0.16 : 0.84
        ctx.beginPath()
        ctx.move(to: p(edge, 0.74))
        ctx.addCurve(to: p(edge + sign * 0.16, 0.30),
                     control1: p(edge + sign * 0.02, 0.58),
                     control2: p(edge + sign * 0.20, 0.44))
        ctx.addCurve(to: p(edge + sign * 0.05, 0.30),
                     control1: p(edge + sign * 0.10, 0.30),
                     control2: p(edge + sign * 0.07, 0.30))
        ctx.addCurve(to: p(edge, 0.74),
                     control1: p(edge + sign * 0.02, 0.50),
                     control2: p(edge - sign * 0.01, 0.62))
        ctx.closePath()
        if let g = CGGradient(colorsSpace: cs, colors: [velvetHi, velvet] as CFArray, locations: [0, 1]) {
            ctx.saveGState(); ctx.clip()
            ctx.drawLinearGradient(g,
                                   start: p(edge, 0.5), end: p(edge + sign * 0.16, 0.5), options: [])
            ctx.restoreGState()
        } else {
            ctx.setFillColor(velvet); ctx.fillPath()
        }
        // Curtain fold highlights.
        ctx.setStrokeColor(velvetHi)
        ctx.setLineWidth(len(0.006))
        for k in 0..<3 {
            let off = sign * (0.04 + CGFloat(k) * 0.035)
            ctx.beginPath()
            ctx.move(to: p(edge + off, 0.72))
            ctx.addLine(to: p(edge + off * 1.3, 0.36))
            ctx.strokePath()
        }
    }
    curtain(left: true)
    curtain(left: false)

    guard let cgImage = ctx.makeImage() else { fatalError("makeImage failed") }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("PNG encoding failed")
    }
    return data
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iosDir = root.appendingPathComponent("Resources/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: iosDir, withIntermediateDirectories: true)
try renderIcon(pixelSize: 1024).write(to: iosDir.appendingPathComponent("icon_1024.png"))
print("  wrote icon_1024.png")

let contents = """
{
  "images" : [
    { "filename" : "icon_1024.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
try contents.write(to: iosDir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
print("done.")
