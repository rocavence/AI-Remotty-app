import Foundation

/// 使用者設定（存 UserDefaults）。
final class AppSettings {
    static let shared = AppSettings()
    private let d = UserDefaults(suiteName: "com.rocavence.remotty") ?? .standard

    // 按鍵映射：動作 → GameController 按鍵名。
    // Joy-Con (L) 實測：面板四箭頭鍵=Button B/Y/X/A（上/右/下/左）；蘑菇頭=Direction Pad；L=Left Shoulder。
    // 面板鍵：右=approve 左=reject 上=上一個tab 下=下一個tab；蘑菇頭=方向鍵導航；L=空白鍵。
    enum Action: String, CaseIterable {
        case approve, reject, tabPrev, tabNext, openTerminal, toggleAuto
        case navUp, navDown, navLeft, navRight, goOn
    }
    // ⚠️ 單 Joy-Con (L) 只有這些鍵會 fire：面板 A/B/X/Y、Direction Pad(蘑菇頭)、Button Menu(−)。
    // 肩鍵 L/ZL/SL/SR 與 Button Home(□) 不觸發（GCController 列了但按下無事件）。
    private static let defaultMapping: [String: String] = [
        Action.approve.rawValue: "Button Y",      // 面板 右 → Enter
        Action.reject.rawValue: "Button A",       // 面板 左 → Esc
        Action.tabPrev.rawValue: "Button B",      // 面板 上 ↑  切上一個 tab
        Action.tabNext.rawValue: "Button X",      // 面板 下 ↓  切下一個 tab
        Action.goOn.rawValue: "Button Menu",      // − → 打 "go on" + Enter
        // 蘑菇頭（Direction Pad）→ 方向鍵。垂直拿逆時針 90° 校正：
        // 實體上=DP Left、實體右=DP Up、實體下=DP Right、實體左=DP Down
        Action.navUp.rawValue: "Direction Pad Left",
        Action.navRight.rawValue: "Direction Pad Up",
        Action.navDown.rawValue: "Direction Pad Right",
        Action.navLeft.rawValue: "Direction Pad Down",
        // openTerminal / toggleAuto 沒有可用實體鍵 → 走選單（□ Home 不 fire）
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
        case "Left Shoulder": return "L 肩鍵"
        case "Right Shoulder": return "ZL 肩鍵"
        // 垂直拿校正後的實體方向
        case "Direction Pad Left": return "蘑菇頭 ↑"
        case "Direction Pad Up": return "蘑菇頭 →"
        case "Direction Pad Right": return "蘑菇頭 ↓"
        case "Direction Pad Down": return "蘑菇頭 ←"
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
