import Foundation
import AppKit
import CoreGraphics

struct FrameSpec {
    let idx: Int
    let titleZh: String
    let subZh: String
    let titleEn: String
    let subEn: String
    let r: CGFloat
    let g: CGFloat
    let b: CGFloat
}

let frames: [FrameSpec] = [
    FrameSpec(idx: 1, titleZh: "即時 GLP-1 血中濃度曲線", subZh: "iPhone Duo 雙欄同步洞察 ‧ FDA Bateman 模型", titleEn: "Live GLP-1 Active Level Curve", subEn: "iPhone Duo Dual-Pane Insights & FDA Bateman PK", r: 14/255, g: 165/255, b: 233/255),
    FrameSpec(idx: 2, titleZh: "U-100 針筒一秒防呆換算", subZh: "乾粉泡製與現成藥液 ‧ 8 大腹部智慧輪替", titleEn: "Exact U-100 Syringe Math", subEn: "Reconstituted Peptides & Smart 8-Site Rotation", r: 139/255, g: 92/255, b: 246/255),
    FrameSpec(idx: 3, titleZh: "劑量染色體重趨勢與回診報表", subZh: "食慾抑制曲線分析 ‧ 30 秒匯出醫師摘要", titleEn: "Dose-Colored Weight & Analytics", subEn: "Food Noise Dynamics & 1-Page Doctor Summary", r: 16/255, g: 185/255, b: 129/255),
    FrameSpec(idx: 4, titleZh: "100% 本地離線隱私防護", subZh: "零雲端伺服器、免註冊 ‧ 個人數據完全自主", titleEn: "100% Local-First Privacy", subEn: "Zero Cloud Servers, Zero Account & Zero Ad Trackers", r: 249/255, g: 115/255, b: 22/255),
    FrameSpec(idx: 5, titleZh: "專為 iPhone Duo 懸停設計", subZh: "雙手免持抽藥引導 ‧ 防硬塊自動部位輪替", titleEn: "Made for iPhone Duo Tabletop", subEn: "Hands-Free Injection Guide & Auto Site Rotation", r: 16/255, g: 185/255, b: 129/255)
]

func composite(rawPath: String, fallbackPath: String, outPath: String, width: Int, height: Int, spec: FrameSpec, isZh: Bool) {
    let fm = FileManager.default
    var chosenPath = rawPath
    if let attrs = try? fm.attributesOfItem(atPath: rawPath), let sz = attrs[.size] as? Int, sz < 45000 {
        chosenPath = fallbackPath
    }
    guard let rawImg = NSImage(contentsOfFile: chosenPath) ?? NSImage(contentsOfFile: fallbackPath) else {
        print("⚠️ 找不到實機圖: \(chosenPath)")
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
        NSColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1).cgColor,
        NSColor(red: spec.r * 0.48, green: spec.g * 0.48, blue: spec.b * 0.48, alpha: 1).cgColor
    ] as CFArray
    let grad = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0])!
    cg.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: w, y: h), options: [])

    let title = isZh ? spec.titleZh : spec.titleEn
    let sub = isZh ? spec.subZh : spec.subEn
    let para = NSMutableParagraphStyle()
    para.alignment = .center
    para.lineSpacing = 6

    (title as NSString).draw(
        in: NSRect(x: w * 0.05, y: h * 0.86, width: w * 0.90, height: h * 0.09),
        withAttributes: [
            .font: NSFont.systemFont(ofSize: max(38, w * 0.052), weight: .heavy),
            .foregroundColor: NSColor.white,
            .paragraphStyle: para
        ]
    )
    (sub as NSString).draw(
        in: NSRect(x: w * 0.06, y: h * 0.80, width: w * 0.88, height: h * 0.06),
        withAttributes: [
            .font: NSFont.systemFont(ofSize: max(20, w * 0.026), weight: .semibold),
            .foregroundColor: NSColor(white: 0.90, alpha: 1),
            .paragraphStyle: para
        ]
    )

    let imgSize = rawImg.size
    let maxBoxW = w * 0.86
    let maxBoxH = h * 0.74
    let scale = min(maxBoxW / imgSize.width, maxBoxH / imgSize.height)
    let drawW = imgSize.width * scale
    let drawH = imgSize.height * scale
    let drawX = (w - drawW) / 2.0
    let drawY = h * 0.04

    let bezelRect = NSRect(x: drawX - 10, y: drawY - 10, width: drawW + 20, height: drawH + 20)
    let bezelPath = NSBezierPath(roundedRect: bezelRect, xRadius: 48, yRadius: 48)
    NSColor(red: 30/255, green: 41/255, blue: 59/255, alpha: 1).setFill()
    bezelPath.fill()

    let screenRect = NSRect(x: drawX, y: drawY, width: drawW, height: drawH)
    let clipPath = NSBezierPath(roundedRect: screenRect, xRadius: 40, yRadius: 40)
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
    for f in frames {
        let inner = "tool/screenshots/raw_inner_\(code)_\(f.idx).png"
        let outer = "tool/screenshots/raw_outer_\(code)_\(f.idx).png"
        composite(rawPath: f.idx == 1 ? inner : outer, fallbackPath: inner, outPath: "tool/screenshots/\(code)_67_\(f.idx).jpg", width: 1290, height: 2796, spec: f, isZh: isZh)
    }
    composite(rawPath: "tool/screenshots/raw_outer_\(code)_2.png", fallbackPath: "tool/screenshots/raw_inner_\(code)_2.png", outPath: "tool/screenshots/\(code)_duo_outer_1.jpg", width: 1398, height: 2034, spec: frames[1], isZh: isZh)
    composite(rawPath: "tool/screenshots/raw_inner_\(code)_1.png", fallbackPath: "tool/screenshots/raw_inner_\(code)_1.png", outPath: "tool/screenshots/\(code)_duo_inner_1.jpg", width: 2007, height: 2853, spec: frames[0], isZh: isZh)
}
print("🟢 真實 iPhone Duo App UI 截圖套框合成完畢！")
