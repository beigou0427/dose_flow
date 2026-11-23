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

// 1. Dark Navy Base Background with Diagonal Split
cg.setFillColor(NSColor(red: 8/255, green: 16/255, blue: 26/255, alpha: 1).cgColor)
cg.fill(CGRect(x: 0, y: 0, width: w, height: h))

cg.saveGState()
let bgPath = CGMutablePath()
bgPath.move(to: CGPoint(x: -w * 0.1, y: h * 1.1))
bgPath.addLine(to: CGPoint(x: w * 1.1, y: -h * 0.1))
bgPath.addLine(to: CGPoint(x: w * 1.1, y: h * 1.1))
bgPath.closeSubpath()
cg.setFillColor(NSColor(red: 14/255, green: 27/255, blue: 42/255, alpha: 1).cgColor)
cg.addPath(bgPath)
cg.fillPath()
cg.restoreGState()

let center = CGPoint(x: w * 0.48, y: h * 0.48)
let radius: CGFloat = w * 0.31
let strokeW: CGFloat = w * 0.052

// 2. 7-Segmented Cycle Ring with Sharp Cuts (#2EE59D -> #00D2D3)
let totalSegs = 7
let gapAngle: CGFloat = 0.14
let segAngle = (CGFloat.pi * 2.0 - (CGFloat(totalSegs) * gapAngle)) / CGFloat(totalSegs)

for i in 0..<totalSegs {
    let startA = -CGFloat.pi / 2.0 + CGFloat(i) * (segAngle + gapAngle) + 0.05
    let endA = startA + segAngle

    cg.saveGState()
    cg.setLineWidth(strokeW)
    cg.setLineCap(.butt)

    let progress = CGFloat(i) / CGFloat(totalSegs - 1)
    let r = (46 + (0 - 46) * progress) / 255.0
    let g = (232 + (210 - 229) * progress) / 255.0
    let b = (157 + (211 - 157) * progress) / 255.0

    cg.setStrokeColor(NSColor(red: r, green: g, blue: b, alpha: 1.0).cgColor)
    cg.addArc(center: center, radius: radius, startAngle: startA, endAngle: endA, clockwise: false)
    cg.strokePath()
    cg.restoreGState()
}

// 3. Downward Curve with Integrated Vector Arrow Tip
let startP = CGPoint(x: center.x - radius * 0.72, y: center.y + radius * 0.28)
let control1 = CGPoint(x: center.x - radius * 0.22, y: center.y + radius * 0.48)
let control2 = CGPoint(x: center.x + radius * 0.20, y: center.y - radius * 0.32)
let endP = CGPoint(x: center.x + radius * 0.50, y: center.y - radius * 0.42)

let trendPath = CGMutablePath()
trendPath.move(to: startP)
trendPath.addCurve(to: endP, control1: control1, control2: control2)

cg.saveGState()
cg.setLineWidth(w * 0.060)
cg.setLineCap(.round)
cg.setStrokeColor(NSColor.white.cgColor)
cg.addPath(trendPath)
cg.strokePath()
cg.restoreGState()

// Exact Arrow Angle calculated from curve tangent
let tangentDx = endP.x - control2.x
let tangentDy = endP.y - control2.y
let angle = atan2(tangentDy, tangentDx)

cg.saveGState()
cg.translateBy(x: endP.x, y: endP.y)
cg.rotate(by: angle)

let arrowPath = CGMutablePath()
let arrowLen = w * 0.08
let arrowHalfW = w * 0.038

arrowPath.move(to: CGPoint(x: arrowLen * 0.8, y: 0))
arrowPath.addLine(to: CGPoint(x: -arrowLen * 0.4, y: arrowHalfW))
arrowPath.addLine(to: CGPoint(x: -arrowLen * 0.1, y: 0))
arrowPath.addLine(to: CGPoint(x: -arrowLen * 0.4, y: -arrowHalfW))
arrowPath.closeSubpath()

cg.setFillColor(NSColor.white.cgColor)
cg.addPath(arrowPath)
cg.fillPath()
cg.restoreGState()

// 4. Precision Geometric Medical Syringe at 45 Degrees (Top Right)
cg.saveGState()
let syringeCenter = CGPoint(x: center.x + radius * 0.64, y: center.y + radius * 0.64)
cg.translateBy(x: syringeCenter.x, y: syringeCenter.y)
cg.rotate(by: -CGFloat.pi / 4.0)

let pColor = NSColor(red: 46/255, green: 229/255, blue: 157/255, alpha: 1.0).cgColor
let wColor = NSColor.white.cgColor

let bW = w * 0.082
let bH = h * 0.14
let strokeThick = w * 0.014

// Barrel Frame
let barrelRect = CGRect(x: -bW / 2, y: -bH / 2, width: bW, height: bH)
cg.setLineWidth(strokeThick)
cg.setStrokeColor(wColor)
cg.addRect(barrelRect)
cg.strokePath()

// Green Liquid
let fluidRect = CGRect(x: -bW / 2 + strokeThick, y: -bH / 2 + strokeThick, width: bW - strokeThick * 2, height: bH * 0.52)
cg.setFillColor(pColor)
cg.fill(fluidRect)

// Finger Flange
let flangeW = bW * 1.7
let flangeH = h * 0.018
cg.setFillColor(wColor)
cg.fill(CGRect(x: -flangeW / 2, y: bH / 2, width: flangeW, height: flangeH))

// Plunger Shaft
cg.setLineWidth(strokeThick)
cg.setStrokeColor(wColor)
cg.move(to: CGPoint(x: 0, y: bH / 2 + flangeH))
cg.addLine(to: CGPoint(x: 0, y: bH / 2 + flangeH + h * 0.065))
cg.strokePath()

// Plunger Handle
let handleW = bW * 1.0
cg.setFillColor(pColor)
cg.fill(CGRect(x: -handleW / 2, y: bH / 2 + flangeH + h * 0.06, width: handleW, height: h * 0.020))

// Needle Hub
let hubW = bW * 0.6
let hubH = h * 0.022
cg.setFillColor(pColor)
cg.fill(CGRect(x: -hubW / 2, y: -bH / 2 - hubH, width: hubW, height: hubH))

// Needle Tip
cg.setLineWidth(w * 0.010)
cg.setStrokeColor(wColor)
cg.move(to: CGPoint(x: 0, y: -bH / 2 - hubH))
cg.addLine(to: CGPoint(x: 0, y: -bH / 2 - hubH - h * 0.08))
cg.strokePath()

cg.restoreGState()

guard let cgImg = cg.makeImage() else { exit(1) }
let targets = [
    ("docs/icon_exact_v3.jpg", "public.jpeg"),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png", "public.png")
]
for (path, uti) in targets {
    let url = URL(fileURLWithPath: path) as CFURL
    if let dest = CGImageDestinationCreateWithURL(url, uti as CFString, 1, nil) {
        CGImageDestinationAddImage(dest, cgImg, nil)
        CGImageDestinationFinalize(dest)
    }
}
print("🟢 [終極向量完全體] App Icon v3 (1024x1024) 生成完成！")
