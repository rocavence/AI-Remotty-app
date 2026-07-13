import Foundation

/// 使用者設定（存 UserDefaults）。
final class AppSettings {
    static let shared = AppSettings()
    private let d = UserDefaults(suiteName: "com.rocavence.remotty") ?? .standard

    // 按鍵映射：動作 → GameController 按鍵名。
    // Joy-Con (L) 實體箭頭 → GCController（實測）：上=Button B 右=Button Y 下=Button X 左=Button A。
    // 預設：右=approve、左=reject、上=上一個 tab、下=下一個 tab。
    enum Action: String, CaseIterable { case approve, reject, tabPrev, tabNext, openTerminal, toggleAuto }
    private static let defaultMapping: [String: String] = [
        Action.approve.rawValue: "Button Y",      // 右 →
        Action.reject.rawValue: "Button A",       // 左 ←
        Action.tabPrev.rawValue: "Button B",      // 上 ↑  切上一個 tab
        Action.tabNext.rawValue: "Button X",      // 下 ↓  切下一個 tab
        Action.openTerminal.rawValue: "Button Menu", // − / Menu
        Action.toggleAuto.rawValue: "Button Home",   // □ Capture
    ]

    /// 按鍵名 → 人看得懂的箭頭標籤。
    static func buttonLabel(_ name: String) -> String {
        switch name {
        case "Button B": return "上 ↑"
        case "Button X": return "下 ↓"
        case "Button Y": return "右 →"
        case "Button A": return "左 ←"
        case "Button Menu": return "− / Menu"
        case "Button Home": return "□ Capture"
        case "Left Shoulder": return "L"
        case "Right Shoulder": return "ZL"
        default: return name
        }
    }

    var mapping: [String: String] {
        get { (d.dictionary(forKey: "mapping") as? [String: String]) ?? Self.defaultMapping }
        set { d.set(newValue, forKey: "mapping") }
    }
    func action(forButton name: String) -> Action? {
        for (k, v) in mapping where v == name { return Action(rawValue: k) }
        return nil
    }

    var rumbleEnabled: Bool {
        get { d.object(forKey: "rumble") == nil ? true : d.bool(forKey: "rumble") }
        set { d.set(newValue, forKey: "rumble") }
    }
    var autoApprove: Bool {
        get { d.bool(forKey: "autoApprove") } // 預設 false（安全）
        set { d.set(newValue, forKey: "autoApprove") }
    }
    var reminderInterval: Double {
        get { let v = d.double(forKey: "reminder"); return v == 0 ? 20 : v }
        set { d.set(newValue, forKey: "reminder") }
    }
    /// 沒人按時，逼近 hook timeout 前自動回覆的秒數（回 ask，安全退回原生 prompt）。
    var autoAnswerAfter: Double {
        get { let v = d.double(forKey: "autoAnswerAfter"); return v == 0 ? 110 : v }
        set { d.set(newValue, forKey: "autoAnswerAfter") }
    }

    // 選定的 terminal adapter id
    var terminalId: String {
        get { d.string(forKey: "terminalId") ?? "" }
        set { d.set(newValue, forKey: "terminalId") }
    }
    // Other terminal 自訂
    var customBundleId: String {
        get { d.string(forKey: "customBundleId") ?? "" }
        set { d.set(newValue, forKey: "customBundleId") }
    }
    var customAppName: String {
        get { d.string(forKey: "customAppName") ?? "" }
        set { d.set(newValue, forKey: "customAppName") }
    }

    var launchAtLogin: Bool {
        get { d.bool(forKey: "launchAtLogin") }
        set { d.set(newValue, forKey: "launchAtLogin") }
    }

    var onboardingDone: Bool {
        get { d.bool(forKey: "onboardingDone") }
        set { d.set(newValue, forKey: "onboardingDone") }
    }
}
