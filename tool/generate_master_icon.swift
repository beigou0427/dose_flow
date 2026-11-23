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

// 1. Deep Midnight Navy Background (#09131F -> #142840)
let bgColors = [
    NSColor(red: 9/255, green: 19/255, blue: 31/255, alpha: 1).cgColor,
    NSColor(red: 20/255, green: 40/255, blue: 64/255, alpha: 1).cgColor
] as CFArray
let bgGrad = CGGradient(colorsSpace: cs, colors: bgColors, locations: [0.0, 1.0])!
cg.drawLinearGradient(bgGrad, start: CGPoint(x: w * 0.2, y: h * 0.9), end: CGPoint(x: w * 0.8, y: h * 0.1), options: [])

// Ambient Spotlight
let glowColors = [
    NSColor(red: 0/255, green: 180/255, blue: 216/255, alpha: 0.16).cgColor,
    NSColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor
] as CFArray
let glowGrad = CGGradient(colorsSpace: cs, colors: glowColors, locations: [0.0, 1.0])!
cg.drawRadialGradient(glowGrad, startCenter: CGPoint(x: w * 0.5, y: h * 0.5), startRadius: 0, endCenter: CGPoint(x: w * 0.5, y: h * 0.5), endRadius: w * 0.48, options: [])

let center = CGPoint(x: w * 0.5, y: h * 0.48)
let radius: CGFloat = w * 0.30
let ringWidth: CGFloat = w * 0.052

// 2. 7-Segment Weekly Cycle Ring
let totalSegs = 7
let gapAngle: CGFloat = 0.12
let segAngle = (CGFloat.pi * 2.0 - (CGFloat(totalSegs) * gapAngle)) / CGFloat(totalSegs)

for i in 0..<totalSegs {
    let startA = -CGFloat.pi / 2.0 + CGFloat(i) * (segAngle + gapAngle)
    let endA = startA + segAngle

    cg.saveGState()
    cg.setLineWidth(ringWidth)
    cg.setLineCap(.round)

    if i < 5 {
        // Active Days: Mint Green (#2EE59D)
        cg.setStrokeColor(NSColor(red: 46/255, green: 229/255, blue: 157/255, alpha: 1.0).cgColor)
    } else {
        // Inactive Days: Slate Blue
        cg.setStrokeColor(NSColor(red: 35/255, green: 55/255, blue: 80/255, alpha: 0.7).cgColor)
    }

    cg.addArc(center: center, radius: radius, startAngle: startA, endAngle: endA, clockwise: false)
    cg.strokePath()
    cg.restoreGState()
}

// 3. Crisp Downward Mass & PK Curve inside Ring
cg.saveGState()
let trendPath = CGMutablePath()
let startPoint = CGPoint(x: center.x - radius * 0.68, y: center.y + radius * 0.42)
let endPoint = CGPoint(x: center.x + radius * 0.52, y: center.y - radius * 0.42)

trendPath.move(to: startPoint)
trendPath.addCurve(
    to: endPoint,
    control1: CGPoint(x: center.x - radius * 0.20, y: center.y + radius * 0.55),
    control2: CGPoint(x: center.x + radius * 0.20, y: center.y - radius * 0.55)
)

cg.setLineWidth(w * 0.046)
cg.setLineCap(.round)
cg.setStrokeColor(NSColor.white.cgColor)
cg.addPath(trendPath)
cg.strokePath()

// Downward Arrow Head at endPoint
let arrowLen = w * 0.045
let arrowAngle = CGFloat.pi * 0.25
cg.setFillColor(NSColor(red: 46/255, green: 229/255, blue: 157/255, alpha: 1.0).cgColor)
cg.move(to: CGPoint(x: endPoint.x, y: endPoint.y))
cg.addLine(to: CGPoint(x: endPoint.x - arrowLen * cos(arrowAngle - 0.5), y: endPoint.y + arrowLen * sin(arrowAngle - 0.5)))
cg.addLine(to: CGPoint(x: endPoint.x - arrowLen * cos(arrowAngle + 0.5), y: endPoint.y + arrowLen * sin(arrowAngle + 0.5)))
cg.closePath()
cg.fillPath()
cg.restoreGState()

// 4. Sleek 45-Degree Injection Pen Icon at Top Right (2 o'clock)
cg.saveGState()
let penPos = CGPoint(x: center.x + radius * 0.72, y: center.y + radius * 0.72)
cg.translateBy(x: penPos.x, y: penPos.y)
cg.rotate(by: -CGFloat.pi / 4.0)

// Pen Body
let bodyWidth = w * 0.042
let bodyHeight = h * 0.14
let bodyRect = CGRect(x: -bodyWidth / 2, y: -bodyHeight / 2, width: bodyWidth, height: bodyHeight)
let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: bodyWidth * 0.3, yRadius: bodyWidth * 0.3)
NSColor(red: 0/255, green: 180/255, blue: 216/255, alpha: 1.0).setFill()
bodyPath.fill()

// Dosage Window (White)
let capRect = CGRect(x: -bodyWidth / 2, y: bodyHeight / 2 - bodyHeight * 0.35, width: bodyWidth, height: bodyHeight * 0.35)
let capPath = NSBezierPath(roundedRect: capRect, xRadius: bodyWidth * 0.2, yRadius: bodyWidth * 0.2)
NSColor.white.setFill()
capPath.fill()

// Plunger Button (Mint Green)
let btnRect = CGRect(x: -bodyWidth * 0.35, y: bodyHeight / 2, width: bodyWidth * 0.7, height: h * 0.02)
NSColor(red: 46/255, green: 229/255, blue: 157/255, alpha: 1.0).setFill()
NSBezierPath(roundedRect: btnRect, xRadius: 4, yRadius: 4).fill()

// Needle Tip
cg.setLineWidth(w * 0.012)
cg.setStrokeColor(NSColor.white.cgColor)
cg.move(to: CGPoint(x: 0, y: -bodyHeight / 2))
cg.addLine(to: CGPoint(x: 0, y: -bodyHeight / 2 - h * 0.035))
cg.strokePath()

cg.restoreGState()

guard let cgImg = cg.makeImage() else { exit(1) }

let targets = [
    ("docs/icon_master.jpg", "public.jpeg"),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png", "public.png")
]

for (path, uti) in targets {
    let url = URL(fileURLWithPath: path) as CFURL
    if let dest = CGImageDestinationCreateWithURL(url, uti as CFString, 1, nil) {
        CGImageDestinationAddImage(dest, cgImg, nil)
        CGImageDestinationFinalize(dest)
    }
}
print("🟢 [向量精繪 Master 版] App Icon 1024x1024 生成完畢！")
