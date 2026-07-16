#!/usr/bin/env swift
//
// Render AI-Remotty's app icon at 1024×1024 as Resources/icon-1024.png.
// Run via `swift Scripts/make-icon.swift` from the project root.
//
// Concept: a terminal window floating on a green squircle, its traffic lights
// showing green — the app's whole job is turning a blocked permission prompt
// into a go.
//

import AppKit
import CoreGraphics

let size: CGFloat = 1024
let inset: CGFloat = 96
let squircleCorner: CGFloat = 228   // matches macOS Tahoe app squircle proportion

let space = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: Int(size),
    height: Int(size),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: space,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Failed to create CGContext")
}

let bounds = CGRect(x: 0, y: 0, width: size, height: size)
ctx.clear(bounds)

let squircleRect = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
let squirclePath = CGPath(roundedRect: squircleRect, cornerWidth: squircleCorner, cornerHeight: squircleCorner, transform: nil)

// Palette.
let goGreen   = NSColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1.0)   // the "allow" green
let lightRed  = NSColor(red: 0.98, green: 0.35, blue: 0.32, alpha: 1.0)
let lightAmber = NSColor(red: 1.00, green: 0.75, blue: 0.20, alpha: 1.0)
let barGrey   = NSColor(white: 0.78, alpha: 1.0)

func fillRounded(_ r: CGRect, radius: CGFloat, color: NSColor) {
    ctx.setFillColor(color.cgColor)
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.fillPath()
}

func fillCircle(_ center: CGPoint, radius: CGFloat, color: NSColor) {
    ctx.setFillColor(color.cgColor)
    ctx.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
}

// MARK: Background — green gradient.

ctx.saveGState()
ctx.addPath(squirclePath)
ctx.clip()

let bgColors = [
    NSColor(red: 0.24, green: 0.80, blue: 0.40, alpha: 1.0).cgColor,
    NSColor(red: 0.02, green: 0.36, blue: 0.19, alpha: 1.0).cgColor
] as CFArray
let bgGradient = CGGradient(colorsSpace: space, colors: bgColors, locations: [0.0, 1.0])!
ctx.drawLinearGradient(
    bgGradient,
    start: CGPoint(x: squircleRect.minX, y: squircleRect.maxY),
    end:   CGPoint(x: squircleRect.maxX, y: squircleRect.minY),
    options: []
)

// Subtle top sheen.
let sheenColors = [
    NSColor.white.withAlphaComponent(0.18).cgColor,
    NSColor.white.withAlphaComponent(0.0).cgColor
] as CFArray
let sheen = CGGradient(colorsSpace: space, colors: sheenColors, locations: [0.0, 0.55])!
ctx.drawLinearGradient(
    sheen,
    start: CGPoint(x: squircleRect.midX, y: squircleRect.maxY),
    end:   CGPoint(x: squircleRect.midX, y: squircleRect.midY),
    options: []
)
ctx.restoreGState()

// MARK: Terminal window.

let winWidth: CGFloat = squircleRect.width * 0.80
let winHeight: CGFloat = squircleRect.height * 0.62
let winRect = CGRect(
    x: squircleRect.midX - winWidth / 2,
    y: squircleRect.midY - winHeight / 2,
    width: winWidth,
    height: winHeight
)
let winCorner: CGFloat = 52
let winPath = CGPath(roundedRect: winRect, cornerWidth: winCorner, cornerHeight: winCorner, transform: nil)

ctx.saveGState()
ctx.addPath(squirclePath)
ctx.clip()

// Drop shadow for depth.
ctx.saveGState()
ctx.setShadow(
    offset: CGSize(width: 0, height: -22),
    blur: 44,
    color: NSColor.black.withAlphaComponent(0.34).cgColor
)
ctx.setFillColor(NSColor(white: 0.99, alpha: 1.0).cgColor)
ctx.addPath(winPath)
ctx.fillPath()
ctx.restoreGState()

// Clip window contents.
ctx.saveGState()
ctx.addPath(winPath)
ctx.clip()

// Title bar.
let titleH: CGFloat = 104
let titleRect = CGRect(x: winRect.minX, y: winRect.maxY - titleH, width: winRect.width, height: titleH)
ctx.setFillColor(NSColor(white: 0.93, alpha: 1.0).cgColor)
ctx.fill(titleRect)
ctx.setFillColor(NSColor(white: 0.80, alpha: 1.0).cgColor)
ctx.fill(CGRect(x: titleRect.minX, y: titleRect.minY, width: titleRect.width, height: 3))

// Traffic lights — red and amber dimmed, green lit with a glow.
let lightR: CGFloat = 17
let lightY = titleRect.midY
let lightX0 = titleRect.minX + 52
let lightGap: CGFloat = 52
fillCircle(CGPoint(x: lightX0, y: lightY), radius: lightR, color: lightRed.withAlphaComponent(0.30))
fillCircle(CGPoint(x: lightX0 + lightGap, y: lightY), radius: lightR, color: lightAmber.withAlphaComponent(0.30))
let greenCenter = CGPoint(x: lightX0 + lightGap * 2, y: lightY)
fillCircle(greenCenter, radius: lightR * 2.0, color: goGreen.withAlphaComponent(0.18))
fillCircle(greenCenter, radius: lightR * 1.5, color: goGreen.withAlphaComponent(0.24))
fillCircle(greenCenter, radius: lightR, color: goGreen)

// MARK: Body — a prompt line, a wrapped line, then the allow row.

let pad: CGFloat = 54
let contentMinX = winRect.minX + pad
let contentMaxX = winRect.maxX - pad
let barH: CGFloat = 26

// Prompt chevron ">" then the command bar.
let chevY = titleRect.minY - 72
ctx.setStrokeColor(goGreen.cgColor)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.setLineWidth(14)
let chevX = contentMinX + 6
let chevSize: CGFloat = 20
ctx.move(to: CGPoint(x: chevX, y: chevY + chevSize))
ctx.addLine(to: CGPoint(x: chevX + chevSize, y: chevY))
ctx.addLine(to: CGPoint(x: chevX, y: chevY - chevSize))
ctx.strokePath()

let cmdX = chevX + chevSize + 44
fillRounded(CGRect(x: cmdX, y: chevY - barH / 2, width: contentMaxX - cmdX - 40, height: barH),
            radius: barH / 2, color: barGrey)

// Second, shorter line of output.
let line2Y = chevY - 74
fillRounded(CGRect(x: cmdX, y: line2Y - barH / 2, width: (contentMaxX - cmdX) * 0.58, height: barH),
            radius: barH / 2, color: barGrey)

// Allow row: a green pill with a label bar and a checkmark.
let pillH: CGFloat = 92
let pillRect = CGRect(x: winRect.minX + 34, y: winRect.minY + 44, width: winRect.width - 68, height: pillH)
fillRounded(pillRect, radius: 30, color: goGreen)

let labelX = pillRect.minX + 40
fillRounded(CGRect(x: labelX, y: pillRect.midY - barH / 2, width: pillRect.width * 0.46, height: barH),
            radius: barH / 2, color: .white)

// Checkmark on the right end of the pill.
ctx.setStrokeColor(NSColor.white.cgColor)
ctx.setLineWidth(16)
let checkX = pillRect.maxX - 92
ctx.move(to: CGPoint(x: checkX, y: pillRect.midY + 2))
ctx.addLine(to: CGPoint(x: checkX + 20, y: pillRect.midY - 20))
ctx.addLine(to: CGPoint(x: checkX + 56, y: pillRect.midY + 24))
ctx.strokePath()

ctx.restoreGState() // end window clip
ctx.restoreGState() // end squircle clip

// Save PNG.
guard let cg = ctx.makeImage() else { fatalError("makeImage failed") }
let rep = NSBitmapImageRep(cgImage: cg)
let data = rep.representation(using: .png, properties: [:])!
let outURL = URL(fileURLWithPath: "Resources/icon-1024.png")
try data.write(to: outURL)
print("Wrote \(outURL.path)")
