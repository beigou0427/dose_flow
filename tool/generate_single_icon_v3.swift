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

// 1. High-Contrast Deep Navy Background (#0B192C -> #1A365D)
let bgColors = [
    NSColor(red: 11/255, green: 25/255, blue: 44/255, alpha: 1).cgColor,
    NSColor(red: 26/255, green: 54/255, blue: 93/255, alpha: 1).cgColor
] as CFArray
let bgGrad = CGGradient(colorsSpace: cs, colors: bgColors, locations: [0.0, 1.0])!
cg.drawLinearGradient(bgGrad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: w, y: h), options: [])

cg.setAllowsAntialiasing(true)
cg.setShouldAntialias(true)

let center = CGPoint(x: w * 0.5, y: h * 0.5)
let radius = w * 0.33
let strokeW = w * 0.058 // 20% Thicker, Sharp!

// 2. Outer 7-Segment Weekly Cycle Ring
let segCount = 7
let gapAngle = 0.12
let segAngle = (2.0 * .pi - (Double(segCount) * gapAngle)) / Double(segCount)

for i in 0..<segCount {
    let start = Double(i) * (segAngle + gapAngle) - .pi / 2.0 + 0.1
    let end = start + segAngle

    cg.saveGState()
    cg.setLineWidth(strokeW)
    cg.setLineCap(.round)

    if i < 5 {
        // Active Days: Mint Green (#2EE59D)
        cg.setStrokeColor(NSColor(red: 46/255, green: 229/255, blue: 157/255, alpha: 1).cgColor)
    } else {
        // Pending Days: Slate Blue
        cg.setStrokeColor(NSColor(red: 51/255, green: 78/255, blue: 104/255, alpha: 0.7).cgColor)
    }

    cg.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
    cg.strokePath()
    cg.restoreGState()
}

// 3. Minimalist 45-Degree Injection Pen at Top Right (2 o'clock)
cg.saveGState()
let penCenter = CGPoint(x: w * 0.69, y: h * 0.69)
cg.translateBy(x: penCenter.x, y: penCenter.y)
cg.rotate(by: -45 * .pi / 180)

// Pen Body
cg.setFillColor(NSColor(red: 0/255, green: 180/255, blue: 216/255, alpha: 1).cgColor)
let penBody = CGRect(x: -w * 0.024, y: -h * 0.055, width: w * 0.048, height: h * 0.11)
let penPath = NSBezierPath(roundedRect: penBody, xRadius: w * 0.015, yRadius: w * 0.015)
penPath.fill()

// Pen Needle Tip
cg.move(to: CGPoint(x: 0, y: -h * 0.055))
cg.addLine(to: CGPoint(x: 0, y: -h * 0.095))
cg.setLineWidth(w * 0.016)
cg.setStrokeColor(NSColor.white.cgColor)
cg.strokePath()
cg.restoreGState()

// 4. Downward Mass Loss Trend Wave with Arrow Tip
cg.saveGState()
let trendPath = CGMutablePath()
let startP = CGPoint(x: w * 0.28, y: h * 0.62)
let endP = CGPoint(x: w * 0.62, y: h * 0.36)

trendPath.move(to: startP)
trendPath.addCurve(
    to: endP,
    control1: CGPoint(x: w * 0.40, y: h * 0.66),
    control2: CGPoint(x: w * 0.52, y: h * 0.34)
)

cg.setLineWidth(w * 0.052)
cg.setLineCap(.round)
cg.setStrokeColor(NSColor.white.cgColor)
cg.addPath(trendPath)
cg.strokePath()

// Downward Arrow Head at endP
cg.setFillColor(NSColor(red: 46/255, green: 229/255, blue: 157/255, alpha: 1).cgColor)
let aSize = w * 0.055
cg.move(to: CGPoint(x: endP.x + aSize * 0.4, y: endP.y - aSize * 0.2))
cg.addLine(to: CGPoint(x: endP.x - aSize * 0.6, y: endP.y - aSize * 0.6))
cg.addLine(to: CGPoint(x: endP.x - aSize * 0.2, y: endP.y + aSize * 0.5))
cg.closePath()
cg.fillPath()
cg.restoreGState()

guard let cgImg = cg.makeImage() else { exit(1) }

let targets = [
    ("docs/icon_b_v3.jpg", "public.jpeg"),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png", "public.png")
]

for (path, uti) in targets {
    let url = URL(fileURLWithPath: path) as CFURL
    if let dest = CGImageDestinationCreateWithURL(url, uti as CFString, 1, nil) {
        CGImageDestinationAddImage(dest, cgImg, nil)
        CGImageDestinationFinalize(dest)
    }
}
print("🟢 [第 1 張完美藍圖版] App Icon v3 生成完成並寫入工程！")
