import AppKit
import ApplicationServices

/// Accessibility（輔助使用）權限——模擬鍵入必需。
enum AXHelper {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// 開系統設定的 Accessibility 面板。
    static func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// 目前最前景 app 的 bundle id。
    static var frontmostBundleId: String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}
