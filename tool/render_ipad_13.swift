import Foundation
import AppKit
import CoreGraphics

func renderIpad(rawPath: String, outPath: String, title: String, sub: String, r: CGFloat, g: CGFloat, b: CGFloat) {
    guard let rawImg = NSImage(contentsOfFile: rawPath) else {
        print("⚠️ 找不到圖: \(rawPath)")
        return
    }
    let width = 2048
    let height = 2732
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
        NSColor(red: r * 0.45, green: g * 0.45, blue: b * 0.45, alpha: 1).cgColor
    ] as CFArray
    let grad = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0])!
    cg.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: w, y: h), options: [])

    let para = NSMutableParagraphStyle()
    para.alignment = .center
    (title as NSString).draw(
        in: NSRect(x: w * 0.06, y: h * 0.87, width: w * 0.88, height: h * 0.08),
        withAttributes: [.font: NSFont.systemFont(ofSize: 82, weight: .heavy), .foregroundColor: NSColor.white, .paragraphStyle: para]
    )
    (sub as NSString).draw(
        in: NSRect(x: w * 0.08, y: h * 0.82, width: w * 0.84, height: h * 0.05),
        withAttributes: [.font: NSFont.systemFont(ofSize: 42, weight: .semibold), .foregroundColor: NSColor(white: 0.9, alpha: 1), .paragraphStyle: para]
    )

    let imgSize = rawImg.size
    let maxBoxW = w * 0.86
    let maxBoxH = h * 0.76
    let scale = min(maxBoxW / imgSize.width, maxBoxH / imgSize.height)
    let drawW = imgSize.width * scale
    let drawH = imgSize.height * scale
    let drawX = (w - drawW) / 2.0
    let drawY = h * 0.04

    let bezelRect = NSRect(x: drawX - 14, y: drawY - 14, width: drawW + 28, height: drawH + 28)
    NSColor(red: 30/255, green: 41/255, blue: 59/255, alpha: 1).setFill()
    NSBezierPath(roundedRect: bezelRect, xRadius: 52, yRadius: 52).fill()

    let screenRect = NSRect(x: drawX, y: drawY, width: drawW, height: drawH)
    NSBezierPath(roundedRect: screenRect, xRadius: 42, yRadius: 42).addClip()
    rawImg.draw(in: screenRect, from: NSRect(origin: .zero, size: imgSize), operation: .sourceOver, fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()

    if let cgImage = cg.makeImage() {
        let rep = NSBitmapImageRep(cgImage: cgImage)
        if let jpg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.93]) {
            try? jpg.write(to: URL(fileURLWithPath: outPath))
        }
    }
}

renderIpad(rawPath: "tool/screenshots/manual_duo/duo_2.jpg", outPath: "tool/screenshots/ipad13_zh_1.jpg", title: "GLP-1 代謝曲線 ✕ 雙欄分析", sub: "FDA Bateman 藥動學模型 ‧ 7 天半衰期預測", r: 14/255, g: 165/255, b: 233/255)
renderIpad(rawPath: "tool/screenshots/raw_outer_zh-Hant_2.png", outPath: "tool/screenshots/ipad13_zh_2.jpg", title: "U-100 針筒單位防呆換算", sub: "乾粉泡製與現成藥液 ‧ 8 大部位智慧輪替", r: 139/255, g: 92/255, b: 246/255)
renderIpad(rawPath: "tool/screenshots/manual_duo/duo_3.jpg", outPath: "tool/screenshots/ipad13_en_1.jpg", title: "Live GLP-1 PK & Dual-Pane View", sub: "FDA Bateman Curve & 7-Day Half-Life Forecast", r: 14/255, g: 165/255, b: 233/255)
renderIpad(rawPath: "tool/screenshots/raw_outer_en-US_2.png", outPath: "tool/screenshots/ipad13_en_2.jpg", title: "Exact U-100 Syringe Calculator", sub: "Reconstituted Peptides & Smart 8-Site Rotation", r: 139/255, g: 92/255, b: 246/255)
print("🟢 已生成 4 張 2048x2732 iPad 13 吋真實 UI 截圖！")
