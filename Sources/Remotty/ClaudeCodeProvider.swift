import Foundation

/// Claude Code provider：跑 unix socket server，收 PermissionRequest hook（`remotty notify`）送來的
/// 通知，入 queue 讓 app 震動。回答走「切 terminal + 模擬鍵入」，不從 socket 回決策。
final class ClaudeCodeProvider: PermissionProvider {
    let name = "Claude Code"
    var onRequest: ((PermissionRequest) -> Void)?
    var onCancel: ((String) -> Void)?

    private var serverFd: Int32 = -1
    private let queue = DispatchQueue(label: "remotty.provider", attributes: .concurrent)
    private var running = false

    func start() {
        serverFd = UnixSocket.listen(Paths.socket)
        guard serverFd >= 0 else {
            NSLog("Remotty: 無法開 socket \(Paths.socket)")
            return
        }
        running = true
        queue.async { [weak self] in self?.acceptLoop() }
    }

    func stop() {
        running = false
        if serverFd >= 0 { close(serverFd); serverFd = -1 }
        unlink(Paths.socket)
    }

    private func acceptLoop() {
        while running {
            let fd = UnixSocket.accept(serverFd)
            if fd < 0 { if running { usleep(50_000) }; continue }
            queue.async { [weak self] in self?.handleClient(fd) }
        }
    }

    private func handleClient(_ fd: Int32) {
        defer { close(fd) }
        guard let line = UnixSocket.readLine(fd, timeoutSec: 5),
              let msg = try? JSONDecoder.iso.decode(WireMessage.self, from: line),
              case .request(let req) = msg else { return }
        DispatchQueue.main.async { [weak self] in self?.onRequest?(req) }
    }

    /// 新模型下不從 socket 回決策（改鍵入），保留介面相容。
    func resolve(id: String, decision: PermissionDecision) {}
}

extension JSONDecoder {
    static var iso: JSONDecoder { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }
}
extension JSONEncoder {
    static var iso: JSONEncoder { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e }
}
