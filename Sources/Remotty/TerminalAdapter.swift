import AppKit

/// 對應 SPEC 補充章的 TerminalAdapter。
/// 只負責「找到並喚起 terminal」；permission 語意層走 Provider，兩層分離。
protocol TerminalAdapter {
    var id: String { get }
    var name: String { get }
    var bundleId: String { get }
    func isInstalled() -> Bool
    func activate()
}

extension TerminalAdapter {
    func isInstalled() -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil
    }
    func activate() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { return }
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: cfg)
    }
}

struct BuiltinTerminal: TerminalAdapter {
    let id: String
    let name: String
    let bundleId: String
}

/// Other：使用者自訂 bundle id + app name。
struct CustomTerminal: TerminalAdapter {
    let id = "custom"
    var name: String
    var bundleId: String
}

enum Terminals {
    static let builtins: [BuiltinTerminal] = [
        .init(id: "otty",     name: "Otty",              bundleId: "com.otty.Otty"),
        .init(id: "apple",    name: "Terminal.app",      bundleId: "com.apple.Terminal"),
        .init(id: "iterm",    name: "iTerm2",            bundleId: "com.googlecode.iterm2"),
        .init(id: "warp",     name: "Warp",              bundleId: "dev.warp.Warp-Stable"),
        .init(id: "ghostty",  name: "Ghostty",           bundleId: "com.mitchellh.ghostty"),
        .init(id: "wezterm",  name: "WezTerm",           bundleId: "com.github.wez.wezterm"),
        .init(id: "vscode",   name: "VS Code",           bundleId: "com.microsoft.VSCode"),
        .init(id: "cursor",   name: "Cursor",            bundleId: "com.todesktop.230313mzl4w4u92"),
        .init(id: "windsurf", name: "Windsurf",          bundleId: "com.exafunction.windsurf"),
    ]

    static func current() -> TerminalAdapter {
        let s = AppSettings.shared
        if s.terminalId == "custom" {
            return CustomTerminal(name: s.customAppName.isEmpty ? "Custom" : s.customAppName,
                                  bundleId: s.customBundleId)
        }
        return builtins.first { $0.id == s.terminalId } ?? builtins[1] // 預設 Terminal.app
    }
}
