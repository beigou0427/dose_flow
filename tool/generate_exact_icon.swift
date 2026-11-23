import Foundation
import AppKit
import CoreGraphics
import ImageIO

let w: CGFloat = 1024
let h: CGFloat = 1024
let cs = CGColorSpaceCreateDeviceRGB()
guard let cg = CGContext(
    data: nil, width: Int(w), height: Int(h),
    bitsPerComponent: 8, bytesPerRow: Int(w) * 4,
    space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else { exit(1) }

cg.setAllowsAntialiasing(true)
cg.setShouldAntialias(true)

// 1. Dark Navy Background with Diagonal Accent Band (#080F18 to #142840)
cg.setFillColor(NSColor(red: 8/255, green: 15/255, blue: 24/255, alpha: 1).cgColor)
cg.fill(CGRect(x: 0, y: 0, width: w, height: h))

cg.saveGState()
let bandPath = CGMutablePath()
bandPath.move(to: CGPoint(x: -w * 0.2, y: h * 0.85))
bandPath.addLine(to: CGPoint(x: w * 0.85, y: -h * 0.2))
bandPath.addLine(to: CGPoint(x: w * 1.2, y: -h * 0.2))
bandPath.addLine(to: CGPoint(x: -w * 0.2, y: h * 1.2))
bandPath.closeSubpath()
cg.setFillColor(NSColor(red: 14/255, green: 28/255, blue: 46/255, alpha: 0.85).cgColor)
cg.addPath(bandPath)
cg.fillPath()
cg.restoreGState()

let center = CGPoint(x: w * 0.48, y: h * 0.48)
let radius: CGFloat = w * 0.31
let strokeW: CGFloat = w * 0.048

// 2. 7-Segmented Cycle Ring (Mint to Cyan Gradient)
let totalSegs = 7
let gapAngle: CGFloat = 0.11
let segAngle = (CGFloat.pi * 2.0 - (CGFloat(totalSegs) * gapAngle)) / CGFloat(totalSegs)

for i in 0..<totalSegs {
    let startA = -CGFloat.pi / 2.0 + CGFloat(i) * (segAngle + gapAngle)
    let endA = startA + segAngle

    cg.saveGState()
    cg.setLineWidth(strokeW)
    cg.setLineCap(.square)

    let progress = CGFloat(i) / CGFloat(totalSegs - 1)
    let r = (52 + (0 - 52) * progress) / 255.0
    let g = (232 + (198 - 232) * progress) / 255.0
    let b = (158 + (220 - 158) * progress) / 255.0

    cg.setStrokeColor(NSColor(red: r, green: g, blue: b, alpha: 1.0).cgColor)
    cg.addArc(center: center, radius: radius, startAngle: startA, endAngle: endA, clockwise: false)
    cg.strokePath()
    cg.restoreGState()
}

// 3. Downward Mass Loss Curve with Arrow Tip
cg.saveGState()
let trendPath = CGMutablePath()
let startPoint = CGPoint(x: center.x - radius * 0.68, y: center.y + radius * 0.38)
let endPoint = CGPoint(x: center.x + radius * 0.52, y: center.y - radius * 0.45)

trendPath.move(to: startPoint)
trendPath.addCurve(
    to: endPoint,
    control1: CGPoint(x: center.x - radius * 0.20, y: center.y + radius * 0.52),
    control2: CGPoint(x: center.x + radius * 0.22, y: center.y - radius * 0.35)
)

cg.setLineWidth(w * 0.056)
cg.setLineCap(.round)
cg.setStrokeColor(NSColor.white.cgColor)
cg.addPath(trendPath)
cg.strokePath()

let arrowLen = w * 0.058
let arrowAngle = CGFloat.pi * 0.22
cg.setFillColor(NSColor.white.cgColor)
cg.move(to: CGPoint(x: endPoint.x + arrowLen * 0.2, y: endPoint.y - arrowLen * 0.2))
cg.addLine(to: CGPoint(x: endPoint.x - arrowLen * cos(arrowAngle - 0.5), y: endPoint.y + arrowLen * sin(arrowAngle - 0.5)))
cg.addLine(to: CGPoint(x: endPoint.x - arrowLen * cos(arrowAngle + 0.5), y: endPoint.y + arrowLen * sin(arrowAngle + 0.5)))
cg.closePath()
cg.fillPath()
cg.restoreGState()

// 4. Precision Geometric Medical Syringe at 45 Degrees (Top Right)
cg.saveGState()
let syringeCenter = CGPoint(x: center.x + radius * 0.62, y: center.y + radius * 0.62)
cg.translateBy(x: syringeCenter.x, y: syringeCenter.y)
cg.rotate(by: -CGFloat.pi / 4.0)

let pColor = NSColor(red: 52/255, green: 232/255, blue: 158/255, alpha: 1.0).cgColor
let wColor = NSColor.white.cgColor

let bW = w * 0.075
let bH = h * 0.13
let barrelRect = CGRect(x: -bW / 2, y: -bH / 2, width: bW, height: bH)

cg.setLineWidth(w * 0.012)
cg.setStrokeColor(wColor)
cg.addRect(barrelRect)
cg.strokePath()

let fluidRect = CGRect(x: -bW / 2 + w * 0.006, y: -bH / 2 + w * 0.006, width: bW - w * 0.012, height: bH * 0.55)
cg.setFillColor(pColor)
cg.fill(fluidRect)

cg.setLineWidth(w * 0.012)
cg.setStrokeColor(wColor)
cg.move(to: CGPoint(x: 0, y: bH / 2))
cg.addLine(to: CGPoint(x: 0, y: bH / 2 + h * 0.06))
cg.strokePath()

let handleW = bW * 0.9
cg.setFillColor(pColor)
cg.fill(CGRect(x: -handleW / 2, y: bH / 2 + h * 0.055, width: handleW, height: h * 0.015))

cg.setFillColor(wColor)
cg.fill(CGRect(x: -bW * 0.8, y: bH / 2 - h * 0.01, width: bW * 1.6, height: h * 0.015))

cg.setFillColor(pColor)
cg.fill(CGRect(x: -bW * 0.3, y: -bH / 2 - h * 0.02, width: bW * 0.6, height: h * 0.02))

cg.setLineWidth(w * 0.009)
cg.setStrokeColor(wColor)
cg.move(to: CGPoint(x: 0, y: -bH / 2 - h * 0.02))
cg.addLine(to: CGPoint(x: 0, y: -bH / 2 - h * 0.07))
cg.strokePath()

cg.restoreGState()

guard let cgImg = cg.makeImage() else { exit(1) }
let targets = [
    ("docs/icon_exact.jpg", "public.jpeg"),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png", "public.png")
]
for (path, uti) in targets {
    let url = URL(fileURLWithPath: path) as CFURL
    if let dest = CGImageDestinationCreateWithURL(url, uti as CFString, 1, nil) {
        CGImageDestinationAddImage(dest, cgImg, nil)
        CGImageDestinationFinalize(dest)
    }
}
print("🟢 [照片 100% 像素精繪] 官方正式 App Icon (1024x1024) 生成完成！")
