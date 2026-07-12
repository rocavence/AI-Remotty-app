import Foundation

/// `remotty ask` —— Claude Code PreToolUse hook 的 command 目標。
/// 讀 stdin(hook JSON) → 連 app socket → 阻塞等決策 → 印 permissionDecision → exit 0。
/// app 沒跑 / 逾時 → 回 "ask"（安全退回原生 prompt）。
enum HookClient {
    /// `remotty notify` —— PermissionRequest hook 目標：只通知 app（非阻塞），立刻退出。
    /// 不回決策 → Claude Code 照常顯示原生 prompt，由使用者按 Joy-Con → app 模擬鍵入回答。
    static func notify() -> Never {
        let req = parseRequest()
        let fd = UnixSocket.connect(Paths.socket)
        if fd >= 0 {
            if let data = try? JSONEncoder.iso.encode(WireMessage.request(req)) {
                _ = UnixSocket.writeLine(fd, data)
            }
            close(fd)
        }
        exit(0) // 一律 exit 0，不影響 Claude 原生流程
    }

    /// `remotty ask` —— （保留）阻塞式 hook-decision 模式，給沒有原生 prompt 的 provider 用。
    static func run() -> Never {
        let req = parseRequest()
        let decision = ask(req)
        emit(decision)
        exit(0)
    }

    private static func parseRequest() -> PermissionRequest {
        let input = FileHandle.standardInput.readDataToEndOfFile()
        let hook = ((try? JSONSerialization.jsonObject(with: input)) as? [String: Any]) ?? [:]
        let sessionId = hook["session_id"] as? String ?? ""
        let cwd = hook["cwd"] as? String ?? FileManager.default.currentDirectoryPath
        let toolName = hook["tool_name"] as? String ?? "?"
        let command = summarize(toolInput: hook["tool_input"] as? [String: Any] ?? [:], toolName: toolName)
        return PermissionRequest(
            id: UUID().uuidString, sessionId: sessionId, cwd: cwd,
            toolName: toolName, command: command, timestamp: Date())
    }

    private static func summarize(toolInput: [String: Any], toolName: String) -> String {
        if let c = toolInput["command"] as? String { return c }
        if let f = toolInput["file_path"] as? String { return f }
        if let p = toolInput["path"] as? String { return p }
        if let s = try? JSONSerialization.data(withJSONObject: toolInput),
           let str = String(data: s, encoding: .utf8) { return String(str.prefix(200)) }
        return toolName
    }

    private static func ask(_ req: PermissionRequest) -> PermissionDecision {
        let fd = UnixSocket.connect(Paths.socket)
        guard fd >= 0 else { return .ask } // app 沒跑
        defer { close(fd) }
        guard let data = try? JSONEncoder.iso.encode(WireMessage.request(req)),
              UnixSocket.writeLine(fd, data) else { return .ask }
        // 等決策；逾時（略短於 hook timeout）回 ask
        let timeout = envDouble("REMOTTY_TIMEOUT") ?? 110
        guard let line = UnixSocket.readLine(fd, timeoutSec: timeout),
              let msg = try? JSONDecoder.iso.decode(WireMessage.self, from: line),
              case .decision(_, let d) = msg else { return .ask }
        return d
    }

    private static func emit(_ d: PermissionDecision) {
        let out: [String: Any] = ["hookSpecificOutput": [
            "hookEventName": "PreToolUse",
            "permissionDecision": d.rawValue,
        ]]
        if let data = try? JSONSerialization.data(withJSONObject: out) {
            FileHandle.standardOutput.write(data)
        }
    }

    private static func envDouble(_ k: String) -> Double? {
        ProcessInfo.processInfo.environment[k].flatMap(Double.init)
    }
}
