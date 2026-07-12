import Foundation

/// 一筆 permission 請求（來自任一 Provider）。
struct PermissionRequest: Identifiable, Codable {
    let id: String
    let sessionId: String
    let cwd: String
    let toolName: String
    let command: String          // tool_input 摘要（Bash 的 command，或其他 tool 的簡述）
    let timestamp: Date

    var title: String {
        let dir = (cwd as NSString).lastPathComponent
        return "\(toolName) · \(dir.isEmpty ? cwd : dir)"
    }
}

enum PermissionDecision: String, Codable {
    case allow, deny, ask
}

/// hook client ↔ app 之間走 unix socket 的線路協定（每則一行 JSON）。
enum WireMessage: Codable {
    case request(PermissionRequest)
    case decision(id: String, decision: PermissionDecision)

    // 手寫 coding 讓 JSON 扁平好讀
    private enum Keys: String, CodingKey { case type, request, id, decision }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .request(let r):
            try c.encode("request", forKey: .type)
            try c.encode(r, forKey: .request)
        case .decision(let id, let d):
            try c.encode("decision", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(d, forKey: .decision)
        }
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        switch try c.decode(String.self, forKey: .type) {
        case "request":
            self = .request(try c.decode(PermissionRequest.self, forKey: .request))
        case "decision":
            self = .decision(id: try c.decode(String.self, forKey: .id),
                             decision: try c.decode(PermissionDecision.self, forKey: .decision))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "unknown type")
        }
    }
}

enum Paths {
    static var dir: URL {
        let d = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".remotty", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    static var socket: String { dir.appendingPathComponent("remotty.sock").path }
    static var hookScript: URL { dir.appendingPathComponent("remotty-hook.sh") }
}
