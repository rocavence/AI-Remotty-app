import CoreGraphics
import Foundation

/// 模擬鍵盤輸入（送到目前最前景 app）。需要 Accessibility 權限。
/// ⚠️ 只在確定目標 terminal 已在最前、且有 pending prompt 時才用（避免亂打字）。
enum KeySim {
    private static let src = CGEventSource(stateID: .combinedSessionState)

    /// 打一段文字（用 unicode，數字/字母都可）。
    static func type(_ s: String) {
        for scalar in s.unicodeScalars {
            postUnicode(UniChar(scalar.value))
        }
    }

    static func pressReturn() { postKeycode(36) }   // Return
    static func pressEscape() { postKeycode(53) }   // Esc

    // Otty/多數 macOS terminal 切 tab：⌘⇧[ 上一個 / ⌘⇧] 下一個
    static func prevTab() { postKeycode(33, flags: [.maskCommand, .maskShift]) } // [
    static func nextTab() { postKeycode(30, flags: [.maskCommand, .maskShift]) } // ]

    private static func postUnicode(_ ch: UniChar) {
        var c = ch
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: down) else { continue }
            e.keyboardSetUnicodeString(stringLength: 1, unicodeString: &c)
            e.post(tap: .cghidEventTap)
        }
        usleep(8_000)
    }

    private static func postKeycode(_ key: CGKeyCode, flags: CGEventFlags = []) {
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: down)
            if !flags.isEmpty { e?.flags = flags }
            e?.post(tap: .cghidEventTap)
        }
        usleep(8_000)
    }
}
