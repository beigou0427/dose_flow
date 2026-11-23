import Foundation
import AppKit
import ApplicationServices

let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
if !AXIsProcessTrustedWithOptions(opts) {
    print("⚠️ 請在彈出的「系統設定 -> 隱私權與安全性 -> 輔助使用」允許終端機/VS Code，然後重跑一次！")
}

guard let app = NSWorkspace.shared.runningApplications.first(where: {
    ($0.localizedName ?? "").contains("DeviceHub") || ($0.bundleIdentifier ?? "").contains("DeviceHub")
}) else {
    print("🔴 找不到執行中的 DeviceHub")
    exit(1)
}
app.activate()
usleep(400_000)

func attrStr(_ el: AXUIElement, _ key: String) -> String {
    var val: AnyObject?
    guard AXUIElementCopyAttributeValue(el, key as CFString, &val) == .success else { return "" }
    return (val as? String) ?? ""
}

func walk(_ el: AXUIElement, depth: Int = 0) {
    if depth > 14 { return }
    let role = attrStr(el, kAXRoleAttribute)
    let title = attrStr(el, kAXTitleAttribute)
    let desc = attrStr(el, kAXDescriptionAttribute)
    let help = attrStr(el, kAXHelpAttribute)
    let ident = attrStr(el, "AXIdentifier")
    let combined = "\(title) \(desc) \(help) \(ident)".trimmingCharacters(in: .whitespaces)

    if !combined.isEmpty || role == "AXButton" || role == "AXRadioButton" || role == "AXSlider" {
        print("  [\(role)] title='\(title)' desc='\(desc)' help='\(help)' id='\(ident)'")
    }

    let lower = combined.lowercased()
    if (role == "AXButton" || role == "AXRadioButton") &&
       (title.lowercased() == "open" || desc.lowercased() == "open" || lower.contains("unfold") || lower.contains("flat") || lower.contains("180")) &&
       !lower.contains("partially") {
        let res = AXUIElementPerformAction(el, kAXPressAction as CFString)
        print("🟢 已對 [\(combined)] 發送點擊展開指令 (AXResult: \(res.rawValue))")
    }

    var children: AnyObject?
    if AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &children) == .success,
       let arr = children as? [AXUIElement] {
        for c in arr { walk(c, depth: depth + 1) }
    }
}

let appEl = AXUIElementCreateApplication(app.processIdentifier)
var wins: AnyObject?
if AXUIElementCopyAttributeValue(appEl, kAXWindowsAttribute as CFString, &wins) == .success,
   let wArr = wins as? [AXUIElement] {
    print("🔍 找到 \(wArr.count) 個 DeviceHub 視窗，開始掃描控制項...")
    for w in wArr { walk(w) }
} else {
    print("⚠️ 無法讀取 DeviceHub 視窗（請檢查系統設定 -> 輔助使用權限）")
}
