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

    // 方向鍵 + 空白鍵（給 Claude 多選項/多選清單導航）
    static func arrowUp()    { postKeycode(126) }
    static func arrowDown()  { postKeycode(125) }
    static func arrowLeft()  { postKeycode(123) }
    static func arrowRight() { postKeycode(124) }
    static func space()      { postKeycode(49) }

    /// 在指定全域座標點一下（左鍵）——切 tab 後把 focus 帶回終端輸入區。
    static func click(_ p: CGPoint) {
        for type in [CGEventType.leftMouseDown, .leftMouseUp] {
            CGEvent(mouseEventSource: src, mouseType: type, mouseCursorPosition: p, mouseButton: .left)?
                .post(tap: .cghidEventTap)
        }
        usleep(8_000)
    }

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
