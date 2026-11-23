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

// 1. Deep Navy to Mint Gradient Background
let colors = [
    NSColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1).cgColor,
    NSColor(red: 14/255, green: 116/255, blue: 144/255, alpha: 1).cgColor
] as CFArray
let grad = CGGradient(colorsSpace: cs, colors: colors, locations: [0.0, 1.0])!
cg.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: w, y: h), options: [])

// 2. Outer Glow Cycle Ring
cg.setLineWidth(w * 0.08)
cg.setStrokeColor(NSColor(red: 14/255, green: 165/255, blue: 233/255, alpha: 0.25).cgColor)
cg.addEllipse(in: CGRect(x: w * 0.18, y: h * 0.18, width: w * 0.64, height: h * 0.64))
cg.strokePath()

// Active Segment
cg.setLineWidth(w * 0.08)
cg.setLineCap(.round)
cg.setStrokeColor(NSColor(red: 52/255, green: 211/255, blue: 153/255, alpha: 1).cgColor)
cg.addArc(center: CGPoint(x: w * 0.5, y: h * 0.5), radius: w * 0.32, startAngle: 40 * .pi / 180, endAngle: 280 * .pi / 180, clockwise: false)
cg.strokePath()

// 3. Smooth Downward Weight Velocity Trend
cg.setLineWidth(w * 0.065)
cg.setLineCap(.round)
cg.setStrokeColor(NSColor.white.cgColor)
cg.move(to: CGPoint(x: w * 0.28, y: h * 0.62))
cg.addCurve(to: CGPoint(x: w * 0.72, y: h * 0.36), control1: CGPoint(x: w * 0.42, y: h * 0.64), control2: CGPoint(x: w * 0.58, y: h * 0.38))
cg.strokePath()

// 4. Milestone Node
cg.setFillColor(NSColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 1).cgColor)
cg.addEllipse(in: CGRect(x: w * 0.72 - w * 0.06, y: h * 0.36 - h * 0.06, width: w * 0.12, height: h * 0.12))
cg.fillPath()

guard let cgImg = cg.makeImage() else { exit(1) }

let targets = [
    ("docs/icon_b.jpg", "public.jpeg"),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png", "public.png")
]

for (path, uti) in targets {
    let url = URL(fileURLWithPath: path) as CFURL
    if let dest = CGImageDestinationCreateWithURL(url, uti as CFString, 1, nil) {
        CGImageDestinationAddImage(dest, cgImg, nil)
        CGImageDestinationFinalize(dest)
    }
}
print("🟢 [第 1/6 張] App Icon (方案 B 隱私尊爵版 1024x1024) 生成完成！")
