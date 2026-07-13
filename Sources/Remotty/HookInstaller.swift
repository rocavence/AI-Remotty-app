import Foundation

/// 安裝/移除 Claude Code 的 PermissionRequest hook（只通知、不阻塞、不決定）。
/// 動 ~/.claude/settings.json 前先備份；merge-append，保留既有 hook（如 Otty 的）。
enum HookInstaller {
    static let marker = "remotty-hook.sh"
    static let event = "PermissionRequest"

    static var settingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")
    }

    static func isInstalled() -> Bool {
        guard let dict = readSettings(),
              let hooks = dict["hooks"] as? [String: Any],
              let pre = hooks[event] as? [[String: Any]] else { return false }
        return pre.contains { entry in
            (entry["hooks"] as? [[String: Any]])?.contains {
                ($0["command"] as? String)?.contains(marker) ?? false
            } ?? false
        }
    }

    /// 安裝。回傳備份檔路徑（若原本有檔）。
    @discardableResult
    static func install(binaryPath: String) throws -> String? {
        writeWrapper(binaryPath: binaryPath)

        var dict = readSettings() ?? [:]
        let backup = try backupIfExists()

        var hooks = dict["hooks"] as? [String: Any] ?? [:]
        var pre = hooks[event] as? [[String: Any]] ?? []

        // 去重
        pre.removeAll { entry in
            (entry["hooks"] as? [[String: Any]])?.contains {
                ($0["command"] as? String)?.contains(marker) ?? false
            } ?? false
        }
        pre.append([
            "hooks": [[
                "type": "command",
                "command": Paths.hookScript.path,
            ]],
        ])
        hooks[event] = pre
        dict["hooks"] = hooks
        try writeSettings(dict)
        return backup
    }

    @discardableResult
    static func uninstall() throws -> Bool {
        guard var dict = readSettings(),
              var hooks = dict["hooks"] as? [String: Any] else { return false }
        var changed = false
        // 清所有 event 裡的 remotty hook（防呆：舊版曾裝在 PreToolUse）
        for ev in Array(hooks.keys) {
            guard var arr = hooks[ev] as? [[String: Any]] else { continue }
            let before = arr.count
            arr.removeAll { entry in
                (entry["hooks"] as? [[String: Any]])?.contains {
                    ($0["command"] as? String)?.contains(marker) ?? false
                } ?? false
            }
            if arr.count != before {
                changed = true
                if arr.isEmpty { hooks.removeValue(forKey: ev) } else { hooks[ev] = arr }
            }
        }
        guard changed else { return false }
        _ = try? backupIfExists()
        dict["hooks"] = hooks
        try writeSettings(dict)
        return true
    }

    // MARK: 內部

    private static func writeWrapper(binaryPath: String) {
        let script = """
        #!/bin/bash
        # AI-Remotty PermissionRequest hook —— 只通知 app（非阻塞），使用者按 Joy-Con 回答原生 prompt。
        exec "\(binaryPath)" notify
        """
        try? script.write(to: Paths.hookScript, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: Paths.hookScript.path)
    }

    private static func readSettings() -> [String: Any]? {
        guard let data = try? Data(contentsOf: settingsURL) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func writeSettings(_ dict: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
        try FileManager.default.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: settingsURL, options: .atomic)
    }

    private static func backupIfExists() throws -> String? {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return nil }
        let stamp = Int(Date().timeIntervalSince1970)
        let bak = settingsURL.deletingLastPathComponent()
            .appendingPathComponent("settings.json.remotty-bak-\(stamp)")
        try? FileManager.default.copyItem(at: settingsURL, to: bak)
        return bak.path
    }
}
