import Foundation
import AppKit
import CoreGraphics

struct ShotSpec {
    let idx: Int
    let titleZh: String
    let subZh: String
    let titleEn: String
    let subEn: String
    let r: CGFloat
    let g: CGFloat
    let b: CGFloat
}

let iphoneSpecs: [ShotSpec] = [
    ShotSpec(idx: 1, titleZh: "即時 GLP-1 血中濃度曲線", subZh: "FDA 仿單 Bateman 模型 ‧ 掌握個人半衰期趨勢", titleEn: "Live GLP-1 Half-Life Curve", subEn: "FDA Reference Bateman Model & 7-Day Decay View", r: 46/255, g: 229/255, b: 157/255),
    ShotSpec(idx: 2, titleZh: "視覺化人體部位輪替導引", subZh: "避開肚臍 5 公分 ‧ 自動輪替紀錄與歷史日誌", titleEn: "Visual Injection Site Rotation", subEn: "Smart 8-Zone Rotation Map & Complete Shot Diary", r: 0/255, g: 180/255, b: 216/255),
    ShotSpec(idx: 3, titleZh: "劑量染色體重趨勢與回診摘要", subZh: "食慾抑制動態紀錄 ‧ 一鍵匯出回診評估報告", titleEn: "Dose-Colored Weight & Insights", subEn: "Food Noise Dynamics & 1-Tap Doctor Visit Summary", r: 155/255, g: 135/255, b: 245/255),
    ShotSpec(idx: 4, titleZh: "智慧週期日曆與在地隱私保護", subZh: "每週施打與換針提醒 ‧ Face ID 與本機離線安全", titleEn: "Smart Weekly Calendar & Privacy", subEn: "Custom Shot Alerts, Face ID Lock & Local-First Data", r: 16/255, g: 185/255, b: 129/255)
]

let ipadSpecs: [ShotSpec] = [
    ShotSpec(idx: 1, titleZh: "iPad 雙欄視圖 ✕ GLP-1 週期儀表", subZh: "即時理論半衰期曲線、部位輪替與體重趨勢同屏檢視", titleEn: "Dual-Pane GLP-1 Cycle Dashboard", subEn: "Live Half-Life Curve, Site Rotation & Weight Trends", r: 46/255, g: 229/255, b: 157/255),
    ShotSpec(idx: 2, titleZh: "視覺化人體部位輪替與施打日誌", subZh: "避開肚臍 5 公分 ‧ 一鍵記錄處方劑量與輪替部位", titleEn: "Visual Site Rotation & Shot Diary", subEn: "Avoid Repeated Spots & Log Every Weekly Injection", r: 0/255, g: 180/255, b: 216/255),
    ShotSpec(idx: 4, titleZh: "智慧用藥日曆 ✕ 100% 本地隱私", subZh: "自訂每週推播提醒、Face ID 加密與回診 PDF 匯出", titleEn: "Smart Shot Calendar & Local Privacy", subEn: "Weekly Alerts, Face ID Protection & Visit Export", r: 16/255, g: 185/255, b: 129/255)
]

func composite(rawPath: String, outPath: String, width: Int, height: Int, title: String, sub: String, r: CGFloat, g: CGFloat, b: CGFloat) {
    guard let rawImg = NSImage(contentsOfFile: rawPath) else {
        print("⚠️ Missing: \(rawPath)")
        return
    }
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let cg = CGContext(
        data: nil, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: width * 4,
        space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { return }

    let nsCtx = NSGraphicsContext(cgContext: cg, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx

    let w = CGFloat(width)
    let h = CGFloat(height)

    let colors = [
        NSColor(red: 6/255, green: 11/255, blue: 18/255, alpha: 1).cgColor,
        NSColor(red: r * 0.24, green: g * 0.28, blue: b * 0.32, alpha: 1).cgColor
    ] as CFArray
    let grad = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0])!
    cg.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: w, y: h), options: [])

    let para = NSMutableParagraphStyle()
    para.alignment = .center
    para.lineSpacing = 6

    (title as NSString).draw(
        in: NSRect(x: w * 0.05, y: h * 0.875, width: w * 0.90, height: h * 0.08),
        withAttributes: [
            .font: NSFont.systemFont(ofSize: max(46, w * 0.048), weight: .heavy),
            .foregroundColor: NSColor.white,
            .paragraphStyle: para
        ]
    )
    (sub as NSString).draw(
        in: NSRect(x: w * 0.06, y: h * 0.825, width: w * 0.88, height: h * 0.05),
        withAttributes: [
            .font: NSFont.systemFont(ofSize: max(26, w * 0.024), weight: .semibold),
            .foregroundColor: NSColor(red: 186/255, green: 210/255, blue: 228/255, alpha: 1),
            .paragraphStyle: para
        ]
    )

    let imgSize = rawImg.size
    let maxBoxW = w * 0.86
    let maxBoxH = h * 0.76
    let scale = min(maxBoxW / imgSize.width, maxBoxH / imgSize.height)
    let drawW = imgSize.width * scale
    let drawH = imgSize.height * scale
    let drawX = (w - drawW) / 2.0
    let drawY = h * 0.035

    let bezelRect = NSRect(x: drawX - 12, y: drawY - 12, width: drawW + 24, height: drawH + 24)
    let bezelPath = NSBezierPath(roundedRect: bezelRect, xRadius: 54, yRadius: 54)
    NSColor(red: 33/255, green: 58/255, blue: 87/255, alpha: 1).setFill()
    bezelPath.fill()

    let screenRect = NSRect(x: drawX, y: drawY, width: drawW, height: drawH)
    let clipPath = NSBezierPath(roundedRect: screenRect, xRadius: 44, yRadius: 44)
    clipPath.addClip()
    rawImg.draw(in: screenRect, from: NSRect(origin: .zero, size: imgSize), operation: .sourceOver, fraction: 1.0)

    NSGraphicsContext.restoreGraphicsState()

    if let cgImage = cg.makeImage() {
        let rep = NSBitmapImageRep(cgImage: cgImage)
        if let jpg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.94]) {
            try? jpg.write(to: URL(fileURLWithPath: outPath))
        }
    }
}

for isZh in [true, false] {
    let code = isZh ? "zh-Hant" : "en-US"
    for spec in iphoneSpecs {
        composite(
            rawPath: "tool/screenshots/v110_iphone_\(code)_\(spec.idx).png",
            outPath: "tool/screenshots/final_\(code)_67_\(spec.idx).jpg",
            width: 1290, height: 2796,
            title: isZh ? spec.titleZh : spec.titleEn,
            sub: isZh ? spec.subZh : spec.subEn,
            r: spec.r, g: spec.g, b: spec.b
        )
    }
    for (outIdx, spec) in ipadSpecs.enumerated() {
        composite(
            rawPath: "tool/screenshots/v110_ipad_\(code)_\(spec.idx).png",
            outPath: "tool/screenshots/final_\(code)_ipad13_\(outIdx + 1).jpg",
            width: 2048, height: 2732,
            title: isZh ? spec.titleZh : spec.titleEn,
            sub: isZh ? spec.subZh : spec.subEn,
            r: spec.r, g: spec.g, b: spec.b
        )
    }
}
print("🟢 Generated all 14 clean v1.1.0 Build 6 App Store screenshots!")
