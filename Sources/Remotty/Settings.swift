import Foundation
import GameController

/// 使用者設定（存 UserDefaults）。
final class AppSettings {
    static let shared = AppSettings()
    private let d = UserDefaults(suiteName: "com.rocavence.remotty") ?? .standard

    // 按鍵映射：動作 → GameController 按鍵名。分 profile 存（不同控制器鍵名不同）。
    enum Action: String, CaseIterable {
        case approve, reject, tabPrev, tabNext, openTerminal, toggleAuto
        case navUp, navDown, navLeft, navRight, goOn

        /// 設定 UI 用的中文名。
        var displayName: String {
            switch self {
            case .approve: return "確認 / 放行"
            case .reject: return "拒絕"
            case .tabPrev: return "上一個 tab"
            case .tabNext: return "下一個 tab"
            case .navUp: return "上 ↑"
            case .navDown: return "下 ↓"
            case .navLeft: return "左 ←"
            case .navRight: return "右 →"
            case .goOn: return "打「go on」"
            case .openTerminal: return "開啟 Terminal"
            case .toggleAuto: return "切換 Auto Approve"
            }
        }
    }

    // MARK: Profile（控制器類型）

    static let profileStandard = "standard"   // Xbox / PS4 / PS5 / PC 通用（extendedGamepad 標準鍵名）
    static let profileJoyCon = "joycon"       // 單 Joy-Con (L)

    /// 依連線控制器判定 profile。
    static func profileId(for c: GCController) -> String {
        (c.vendorName ?? "").contains("Joy-Con") ? profileJoyCon : profileStandard
    }
    static let profiles = [profileStandard, profileJoyCon]
    static func profileName(_ p: String) -> String {
        p == profileJoyCon ? "Joy-Con (L)" : "標準手把 (Xbox / PS4 / PS5 / PC)"
    }

    // ⚠️ 單 Joy-Con (L) 只有這些鍵會 fire：面板 A/B/X/Y、Direction Pad(蘑菇頭)、Button Menu(−)。
    // 肩鍵 L/ZL/SL/SR 與 Button Home(□) 不觸發（GCController 列了但按下無事件）。
    private static let joyconDefault: [String: String] = [
        Action.approve.rawValue: "Button Y",      // 面板 右 → Enter
        Action.reject.rawValue: "Button A",       // 面板 左 → Esc
        Action.tabPrev.rawValue: "Button B",      // 面板 上 ↑  切上一個 tab
        Action.tabNext.rawValue: "Button X",      // 面板 下 ↓  切下一個 tab
        Action.goOn.rawValue: "Button Menu",      // − → 打 "go on" + Enter
        // 蘑菇頭（Direction Pad）→ 方向鍵。垂直拿逆時針 90° 校正：
        Action.navUp.rawValue: "Direction Pad Left",
        Action.navRight.rawValue: "Direction Pad Up",
        Action.navDown.rawValue: "Direction Pad Right",
        Action.navLeft.rawValue: "Direction Pad Down",
    ]
    // 標準手把（Xbox 佈局，PS 依位置對應）：全部實體鍵都 fire。
    private static let standardDefault: [String: String] = [
        Action.approve.rawValue: "Button A",           // 下鈕（PS ✕）→ Enter
        Action.reject.rawValue: "Button B",            // 右鈕（PS ○）→ Esc
        Action.tabPrev.rawValue: "Left Shoulder",      // LB / L1
        Action.tabNext.rawValue: "Right Shoulder",     // RB / R1
        Action.navUp.rawValue: "Direction Pad Up",
        Action.navDown.rawValue: "Direction Pad Down",
        Action.navLeft.rawValue: "Direction Pad Left",
        Action.navRight.rawValue: "Direction Pad Right",
        Action.goOn.rawValue: "Button Y",              // 上鈕（PS △）
        Action.openTerminal.rawValue: "Button X",      // 左鈕（PS □）
        Action.toggleAuto.rawValue: "Button Menu",     // Menu / Options
    ]
    static func defaultMapping(_ profile: String) -> [String: String] {
        profile == profileJoyCon ? joyconDefault : standardDefault
    }

    /// 按鍵名 → 人看得懂的標籤（無即時控制器標籤時的 fallback）。
    static func buttonLabel(_ name: String, profile: String) -> String {
        if profile == profileJoyCon {
            switch name {
            case "Button B": return "上 ↑"
            case "Button X": return "下 ↓"
            case "Button Y": return "右 →"
            case "Button A": return "左 ←"
            case "Button Menu": return "− / Menu"
            case "Button Home": return "□ Capture"
            case "Left Shoulder": return "L 肩鍵"
            case "Right Shoulder": return "ZL 肩鍵"
            case "Direction Pad Left": return "蘑菇頭 ↑"
            case "Direction Pad Up": return "蘑菇頭 →"
            case "Direction Pad Right": return "蘑菇頭 ↓"
            case "Direction Pad Down": return "蘑菇頭 ←"
            default: return name
            }
        }
        // 標準手把：十字鍵美化，其餘用原名（即時 localizedName 會更準）。
        switch name {
        case "Direction Pad Up": return "十字鍵 ↑"
        case "Direction Pad Down": return "十字鍵 ↓"
        case "Direction Pad Left": return "十字鍵 ←"
        case "Direction Pad Right": return "十字鍵 →"
        default: return name
        }
    }

    // MARK: 按鍵映射（per profile）

    func mapping(_ profile: String) -> [String: String] {
        if let m = d.dictionary(forKey: "mapping.\(profile)") as? [String: String] { return m }
        // 舊版單一 "mapping" key = Joy-Con 設定 → 遷移沿用。
        if profile == Self.profileJoyCon, let legacy = d.dictionary(forKey: "mapping") as? [String: String] { return legacy }
        return Self.defaultMapping(profile)
    }
    private func setMapping(_ m: [String: String], profile: String) {
        d.set(m, forKey: "mapping.\(profile)")
    }
    func action(forButton name: String, profile: String) -> Action? {
        for (k, v) in mapping(profile) where v == name { return Action(rawValue: k) }
        return nil
    }
    /// 綁定：把某動作指到某按鍵；同一顆鍵原本的動作會先解除（避免一鍵多用）。
    func bind(_ a: Action, button: String, profile: String) {
        var m = mapping(profile).filter { $0.value != button }
        m[a.rawValue] = button
        setMapping(m, profile: profile)
    }
    func clearBinding(_ a: Action, profile: String) {
        var m = mapping(profile); m[a.rawValue] = nil; setMapping(m, profile: profile)
    }
    func resetMapping(profile: String) {
        d.removeObject(forKey: "mapping.\(profile)")
        if profile == Self.profileJoyCon { d.removeObject(forKey: "mapping") } // 清舊 key
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
