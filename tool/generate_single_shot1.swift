import Foundation
import AppKit
import CoreGraphics
import ImageIO

let width = 1290
let height = 2796
let cs = CGColorSpaceCreateDeviceRGB()
guard let cg = CGContext(
    data: nil, width: width, height: height,
    bitsPerComponent: 8, bytesPerRow: width * 4,
    space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else { exit(1) }

cg.setAllowsAntialiasing(true)
cg.setShouldAntialias(true)

let nsCtx = NSGraphicsContext(cgContext: cg, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = nsCtx

let w = CGFloat(width)
let h = CGFloat(height)

// 1. Background Gradient (Navy #0F172A to Deep Emerald #064E3B)
let colors = [
    NSColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1).cgColor,
    NSColor(red: 6/255, green: 78/255, blue: 59/255, alpha: 1).cgColor
] as CFArray
let grad = CGGradient(colorsSpace: cs, colors: colors, locations: [0.0, 1.0])!
cg.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: w, y: h), options: [])

// 2. Top Headline & Sub-headline (28% Height)
let title = "這週該打哪一邊？\n左右腹輪替視覺紀錄"
let sub = "告別硬塊與吸收不良 ‧ 自動提示下一次施打部位"

let para = NSMutableParagraphStyle()
para.alignment = .center
para.lineSpacing = 12

(title as NSString).draw(
    in: NSRect(x: w * 0.05, y: h * 0.83, width: w * 0.90, height: h * 0.12),
    withAttributes: [
        .font: NSFont.systemFont(ofSize: max(42, w * 0.056), weight: .heavy),
        .foregroundColor: NSColor.white,
        .paragraphStyle: para
    ]
)

(sub as NSString).draw(
    in: NSRect(x: w * 0.06, y: h * 0.77, width: w * 0.88, height: h * 0.05),
    withAttributes: [
        .font: NSFont.systemFont(ofSize: max(22, w * 0.027), weight: .semibold),
        .foregroundColor: NSColor(red: 167/255, green: 243/255, blue: 208/255, alpha: 1),
        .paragraphStyle: para
    ]
)

// 3. Phone Frame & Real App UI Mockup (72% Height)
let cardRect = NSRect(x: w * 0.08, y: h * 0.02, width: w * 0.84, height: h * 0.72)
let bezelPath = NSBezierPath(roundedRect: cardRect, xRadius: 48, yRadius: 48)
NSColor(red: 30/255, green: 41/255, blue: 59/255, alpha: 1).setFill()
bezelPath.fill()

let screenRect = NSRect(x: cardRect.minX + 12, y: cardRect.minY + 12, width: cardRect.width - 24, height: cardRect.height - 24)
let clipPath = NSBezierPath(roundedRect: screenRect, xRadius: 40, yRadius: 40)
clipPath.addClip()

let rawPath = "tool/screenshots/raw_outer_zh-Hant_2.png"
if let realImg = NSImage(contentsOfFile: rawPath) {
    realImg.draw(in: screenRect, from: NSRect(origin: .zero, size: realImg.size), operation: .sourceOver, fraction: 1.0)
} else {
    NSColor(red: 248/255, green: 250/255, blue: 252/255, alpha: 1).setFill()
    NSBezierPath(rect: screenRect).fill()

    let pillRect = NSRect(x: screenRect.minX + 32, y: screenRect.maxY - 140, width: screenRect.width - 64, height: 90)
    NSColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 0.15).setFill()
    NSBezierPath(roundedRect: pillRect, xRadius: 20, yRadius: 20).fill()

    let pillText = "建議下次部位：右下腹（避開肚臍 5 cm）"
    let pillPara = NSMutableParagraphStyle()
    pillPara.alignment = .center
    (pillText as NSString).draw(
        in: NSRect(x: pillRect.minX + 10, y: pillRect.minY + 24, width: pillRect.width - 20, height: 48),
        withAttributes: [
            .font: NSFont.systemFont(ofSize: 26, weight: .bold),
            .foregroundColor: NSColor(red: 4/255, green: 120/255, blue: 87/255, alpha: 1),
            .paragraphStyle: pillPara
        ]
    )
}

NSGraphicsContext.restoreGraphicsState()

guard let cgImg = cg.makeImage() else { exit(1) }

let targets = [
    ("docs/shot_1_zh.jpg", "public.jpeg"),
    ("tool/screenshots/zh-Hant_67_1.jpg", "public.jpeg")
]
for (path, uti) in targets {
    let url = URL(fileURLWithPath: path) as CFURL
    if let dest = CGImageDestinationCreateWithURL(url, uti as CFString, 1, nil) {
        CGImageDestinationAddImage(dest, cgImg, nil)
        CGImageDestinationFinalize(dest)
    }
}
print("🟢 [海報截圖 #1] 繁中版 (1290x2796) 生成完成！")
