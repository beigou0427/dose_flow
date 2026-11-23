import Foundation
import AppKit
import CoreGraphics

func createPng(width: Int, height: Int, draw: (CGContext, CGFloat, CGFloat) -> Void, outPath: String) {
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let cg = CGContext(
        data: nil, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: width * 4,
        space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { return }

    let nsCtx = NSGraphicsContext(cgContext: cg, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx

    draw(cg, CGFloat(width), CGFloat(height))

    NSGraphicsContext.restoreGraphicsState()

    if let cgImg = cg.makeImage() {
        let rep = NSBitmapImageRep(cgImage: cgImg)
        if let jpg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.95]) {
            try? jpg.write(to: URL(fileURLWithPath: outPath))
        }
    }
}

// =========================================================================
// 1. 生成 App Icon 方案 A (極簡針筒) 與 方案 B (隱私膠囊趨勢 - 預設推薦)
// =========================================================================
func drawIconOptionB(cg: CGContext, w: CGFloat, h: CGFloat) {
    // Mint Green & Navy Gradient Background
    let colors = [
        NSColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1).cgColor,
        NSColor(red: 14/255, green: 116/255, blue: 144/255, alpha: 1).cgColor
    ] as CFArray
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0])!
    cg.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: w, y: h), options: [])

    // Outer Glow Ring (Capsule / Cycle)
    let ringRect = NSRect(x: w * 0.18, y: h * 0.18, width: w * 0.64, height: h * 0.64)
    let ringPath = NSBezierPath(ovalIn: ringRect)
    NSColor(red: 14/255, green: 165/255, blue: 233/255, alpha: 0.25).setStroke()
    ringPath.lineWidth = w * 0.08
    ringPath.stroke()

    let activePath = NSBezierPath()
    activePath.appendArc(withCenter: NSPoint(x: w * 0.5, y: h * 0.5), radius: w * 0.32, startAngle: 40, endAngle: 280)
    NSColor(red: 52/255, green: 211/255, blue: 153/255, alpha: 1).setStroke()
    activePath.lineWidth = w * 0.08
    activePath.lineCapStyle = .round
    activePath.stroke()

    // Smooth Downward Weight Velocity Trend
    let trend = NSBezierPath()
    trend.move(to: NSPoint(x: w * 0.28, y: h * 0.62))
    trend.curve(to: NSPoint(x: w * 0.72, y: h * 0.36), controlPoint1: NSPoint(x: w * 0.42, y: h * 0.64), controlPoint2: NSPoint(x: w * 0.58, y: h * 0.38))
    NSColor.white.setStroke()
    trend.lineWidth = w * 0.065
    trend.lineCapStyle = .round
    trend.stroke()

    // Key Milestone Node
    let dotRect = NSRect(x: w * 0.72 - w * 0.06, y: h * 0.36 - h * 0.06, width: w * 0.12, height: h * 0.12)
    NSColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 1).setFill()
    NSBezierPath(ovalIn: dotRect).fill()
}

func drawIconOptionA(cg: CGContext, w: CGFloat, h: CGFloat) {
    let colors = [
        NSColor(red: 248/255, green: 250/255, blue: 252/255, alpha: 1).cgColor,
        NSColor(red: 224/255, green: 242/255, blue: 254/255, alpha: 1).cgColor
    ] as CFArray
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0])!
    cg.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: w, y: h), options: [])

    let calRect = NSRect(x: w * 0.2, y: h * 0.2, width: w * 0.6, height: h * 0.6)
    NSColor(red: 14/255, green: 165/255, blue: 233/255, alpha: 0.18).setFill()
    NSBezierPath(roundedRect: calRect, xRadius: 36, yRadius: 36).fill()

    let check = NSBezierPath()
    check.move(to: NSPoint(x: w * 0.32, y: h * 0.5))
    check.line(to: NSPoint(x: w * 0.45, y: h * 0.36))
    check.line(to: NSPoint(x: w * 0.68, y: h * 0.62))
    NSColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 1).setStroke()
    check.lineWidth = w * 0.08
    check.lineCapStyle = .round
    check.stroke()
}

createPng(width: 1024, height: 1024, draw: drawIconOptionB, outPath: "tool/screenshots/app_icon_option_b_privacy.jpg")
createPng(width: 1024, height: 1024, draw: drawIconOptionA, outPath: "tool/screenshots/app_icon_option_a_direct.jpg")
createPng(width: 1024, height: 1024, draw: drawIconOptionB, outPath: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png")
print("🟢 1024x1024 App Icon (方案 B 隱私尊爵版) 已成功應用入 iOS 工程！")

// =========================================================================
// 2. 5 張頂級 App Store 截圖版面設計藍圖
// =========================================================================
struct ShotBlueprint {
    let id: Int
    let titleZh: String
    let subZh: String
    let titleEn: String
    let subEn: String
    let rawImageName: String
    let r: CGFloat
    let g: CGFloat
    let b: CGFloat
}

let blueprints: [ShotBlueprint] = [
    ShotBlueprint(id: 1, titleZh: "這週該打哪一邊？\n左右腹輪替視覺紀錄", subZh: "告別硬塊與吸收不良 ‧ 自動提示下一次施打部位", titleEn: "Which Side To Inject?\nSmart Site Rotation", subEn: "Prevent Knots & Bruising with Automatic Rotation Rules", rawImageName: "raw_outer_zh-Hant_2.png", r: 16/255, g: 185/255, b: 129/255),
    ShotBlueprint(id: 2, titleZh: "體內藥效濃度曲線\n精準掌握代謝節奏", subZh: "支援猛健樂、善纖達、週纖達半衰期推估", titleEn: "GLP-1 PK Level Curve\nTrack Active Half-Life", subEn: "Calibrated to Official FDA Prescribing Information", rawImageName: "raw_outer_zh-Hant_1.png", r: 14/255, g: 165/255, b: 233/255),
    ShotBlueprint(id: 3, titleZh: "劑量調升與體重趨勢\n療程進度一目了然", subZh: "完整記錄 2.5mg 至 15mg 階段變化與身體反應", titleEn: "Dose Titration & Weight\nTrack Every Step", subEn: "Correlate Mass Loss Slope Across 2.5mg to 15mg Tiers", rawImageName: "raw_outer_zh-Hant_3.png", r: 139/255, g: 92/255, b: 246/255),
    ShotBlueprint(id: 4, titleZh: "智慧週期施打提醒\n黃金施打日不漏針", subZh: "自訂提醒時間 ‧ 蛋白質/補水/腸道順暢微習慣", titleEn: "Smart Titration Alerts\nNever Miss Your Shot", subEn: "Custom Reminders & Anti-Muscle Loss Habit Rings", rawImageName: "raw_outer_zh-Hant_4.png", r: 249/255, g: 115/255, b: 22/255),
    ShotBlueprint(id: 5, titleZh: "100% 本地隱私儲存\n無須註冊・資料不外流", subZh: "支援 iCloud 私人備份 ‧ 回診一鍵匯出週期報表", titleEn: "100% Local Privacy\nZero External Servers", subEn: "Private iCloud Sync & 1-Tap Physician PDF Summary", rawImageName: "raw_outer_zh-Hant_5.png", r: 236/255, g: 72/255, b: 153/255)
]

func renderPoster(width: Int, height: Int, bp: ShotBlueprint, isZh: Bool, outPath: String) {
    let rawPath = "tool/screenshots/\(bp.rawImageName)"
    let rawImg = NSImage(contentsOfFile: rawPath)

    createPng(width: width, height: height, draw: { cg, w, h in
        // Background Gradient
        let colors = [
            NSColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1).cgColor,
            NSColor(red: bp.r * 0.42, green: bp.g * 0.42, blue: bp.b * 0.42, alpha: 1).cgColor
        ] as CFArray
        let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0])!
        cg.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: w, y: h), options: [])

        let title = isZh ? bp.titleZh : bp.titleEn
        let sub = isZh ? bp.subZh : bp.subEn
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        para.lineSpacing = 8

        // Top Headline (30% Height)
        let titleSize = max(38.0, w * 0.054)
        let subSize = max(20.0, w * 0.027)

        (title as NSString).draw(
            in: NSRect(x: w * 0.05, y: h * 0.84, width: w * 0.90, height: h * 0.11),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: titleSize, weight: .heavy),
                .foregroundColor: NSColor.white,
                .paragraphStyle: para
            ]
        )
        (sub as NSString).draw(
            in: NSRect(x: w * 0.06, y: h * 0.77, width: w * 0.88, height: h * 0.06),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: subSize, weight: .semibold),
                .foregroundColor: NSColor(red: 226/255, green: 232/255, blue: 240/255, alpha: 1),
                .paragraphStyle: para
            ]
        )

        // Bottom Phone UI (70% Height)
        if let img = rawImg {
            let imgSize = img.size
            let maxW = w * 0.86
            let maxH = h * 0.72
            let scale = min(maxW / imgSize.width, maxH / imgSize.height)
            let drawW = imgSize.width * scale
            let drawH = imgSize.height * scale
            let drawX = (w - drawW) / 2.0
            let drawY = h * 0.02

            let bezelRect = NSRect(x: drawX - 10, y: drawY - 10, width: drawW + 20, height: drawH + 20)
            NSColor(red: 30/255, green: 41/255, blue: 59/255, alpha: 1).setFill()
            NSBezierPath(roundedRect: bezelRect, xRadius: 46, yRadius: 46).fill()

            let screenRect = NSRect(x: drawX, y: drawY, width: drawW, height: drawH)
            NSBezierPath(roundedRect: screenRect, xRadius: 38, yRadius: 38).addClip()
            img.draw(in: screenRect, from: NSRect(origin: .zero, size: imgSize), operation: .sourceOver, fraction: 1.0)
        }
    }, outPath: outPath)
}

for isZh in [true, false] {
    let code = isZh ? "zh-Hant" : "en-US"
    for bp in blueprints {
        renderPoster(width: 1290, height: 2796, bp: bp, isZh: isZh, outPath: "tool/screenshots/\(code)_67_\(bp.id).jpg")
    }
}
print("🟢 5 張全新爆款海報截圖矩陣渲染完成！")
