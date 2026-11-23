import Foundation
import AppKit
import CoreGraphics
import ImageIO

let width = 1024
let height = 1024
let cs = CGColorSpaceCreateDeviceRGB()
guard let cg = CGContext(
    data: nil, width: width, height: height,
    bitsPerComponent: 8, bytesPerRow: width * 4,
    space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else { exit(1) }

let w = CGFloat(width)
let h = CGFloat(height)

// 1. Apple Deep Space Navy Gradient
let bgColors = [
    NSColor(red: 10/255, green: 22/255, blue: 40/255, alpha: 1).cgColor,
    NSColor(red: 4/255, green: 10/255, blue: 20/255, alpha: 1).cgColor
] as CFArray
let bgGrad = CGGradient(colorsSpace: cs, colors: bgColors, locations: [0.0, 1.0])!
cg.drawLinearGradient(bgGrad, start: CGPoint(x: w * 0.2, y: h * 0.9), end: CGPoint(x: w * 0.8, y: h * 0.1), options: [])

// Center Ambient Glow
let glowColors = [
    NSColor(red: 14/255, green: 165/255, blue: 233/255, alpha: 0.18).cgColor,
    NSColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor
] as CFArray
let glowGrad = CGGradient(colorsSpace: cs, colors: glowColors, locations: [0.0, 1.0])!
cg.drawRadialGradient(glowGrad, startCenter: CGPoint(x: w * 0.5, y: h * 0.5), startRadius: 0, endCenter: CGPoint(x: w * 0.5, y: h * 0.5), endRadius: w * 0.45, options: [])

// 2. Refined Background Track Ring
let ringRadius = w * 0.28
let center = CGPoint(x: w * 0.5, y: h * 0.52)

cg.saveGState()
cg.setLineWidth(w * 0.04)
cg.setStrokeColor(NSColor(red: 30/255, green: 58/255, blue: 86/255, alpha: 0.6).cgColor)
cg.addArc(center: center, radius: ringRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
cg.strokePath()
cg.restoreGState()

// 3. Glowing Active Neon Mint Progress Segment
cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: 0), blur: 22, color: NSColor(red: 0/255, green: 245/255, blue: 212/255, alpha: 0.65).cgColor)
cg.setLineWidth(w * 0.042)
cg.setLineCap(.round)
cg.setStrokeColor(NSColor(red: 0/255, green: 245/255, blue: 212/255, alpha: 1).cgColor)
cg.addArc(center: center, radius: ringRadius, startAngle: -0.2, endAngle: .pi * 1.35, clockwise: false)
cg.strokePath()
cg.restoreGState()

// 4. Downward Pharmacokinetic & Weight Trend Wave
cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -3), blur: 14, color: NSColor(red: 14/255, green: 165/255, blue: 233/255, alpha: 0.5).cgColor)

let startP = CGPoint(x: w * 0.30, y: h * 0.64)
let endP = CGPoint(x: w * 0.70, y: h * 0.38)

cg.move(to: startP)
cg.addCurve(to: endP, control1: CGPoint(x: w * 0.44, y: h * 0.68), control2: CGPoint(x: w * 0.56, y: h * 0.36))
cg.setLineWidth(w * 0.038)
cg.setLineCap(.round)
cg.setStrokeColor(NSColor.white.cgColor)
cg.strokePath()
cg.restoreGState()

// 5. Precision Crystal Milestone Node
cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: 0), blur: 18, color: NSColor(red: 0/255, green: 245/255, blue: 212/255, alpha: 0.85).cgColor)

let dotCenter = CGPoint(x: w * 0.70, y: h * 0.38)
cg.setFillColor(NSColor(red: 0/255, green: 245/255, blue: 212/255, alpha: 1).cgColor)
cg.addEllipse(in: CGRect(x: dotCenter.x - w * 0.05, y: dotCenter.y - w * 0.05, width: w * 0.10, height: w * 0.10))
cg.fillPath()

cg.setFillColor(NSColor.white.cgColor)
cg.addEllipse(in: CGRect(x: dotCenter.x - w * 0.022, y: dotCenter.y - w * 0.022, width: w * 0.044, height: w * 0.044))
cg.fillPath()
cg.restoreGState()

guard let cgImg = cg.makeImage() else { exit(1) }

let targets = [
    ("docs/icon_b_v2.jpg", "public.jpeg"),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png", "public.png")
]

for (path, uti) in targets {
    let url = URL(fileURLWithPath: path) as CFURL
    if let dest = CGImageDestinationCreateWithURL(url, uti as CFString, 1, nil) {
        CGImageDestinationAddImage(dest, cgImg, nil)
        CGImageDestinationFinalize(dest)
    }
}
print("🟢 [第 1 張精修版] App Icon v2 生成完畢！")
