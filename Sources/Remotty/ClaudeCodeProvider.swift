import Foundation

/// Claude Code provider：跑 unix socket server，收 hook client（`remotty ask`）送來的 request，
/// 阻塞住 client 連線直到有決策，再把決策寫回讓 hook 印出 permissionDecision。
final class ClaudeCodeProvider: PermissionProvider {
    let name = "Claude Code"
    var onRequest: ((PermissionRequest) -> Void)?
    var onCancel: ((String) -> Void)?

    private var serverFd: Int32 = -1
    private let queue = DispatchQueue(label: "remotty.provider", attributes: .concurrent)
    private var clientFds: [String: Int32] = [:]      // request id → client fd
    private let lock = NSLock()
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
        lock.lock()
        for (_, fd) in clientFds { close(fd) }
        clientFds.removeAll()
        lock.unlock()
    }

    private func acceptLoop() {
        while running {
            let fd = UnixSocket.accept(serverFd)
            if fd < 0 { if running { usleep(50_000) }; continue }
            queue.async { [weak self] in self?.handleClient(fd) }
        }
    }

    private func handleClient(_ fd: Int32) {
        // 讀一行 request
        guard let line = UnixSocket.readLine(fd, timeoutSec: 5),
              let msg = try? JSONDecoder.iso.decode(WireMessage.self, from: line),
              case .request(let req) = msg else {
            close(fd); return
        }
        lock.lock(); clientFds[req.id] = fd; lock.unlock()
        DispatchQueue.main.async { [weak self] in self?.onRequest?(req) }

        // 阻塞等 client 斷線（若 client 先 timeout 自己回 ask，會關連線 → 這裡 read 到 EOF）
        // 用一條讀取偵測斷線；決策由 resolve() 主動寫入並關閉。
        var byte: UInt8 = 0
        while running {
            lock.lock(); let stillHere = clientFds[req.id] != nil; lock.unlock()
            if !stillHere { return } // 已被 resolve 關閉
            var rfds = fd_set(); memset(&rfds, 0, MemoryLayout<fd_set>.size)
            withUnsafeMutablePointer(to: &rfds) { p in
                p.withMemoryRebound(to: Int32.self, capacity: 32) { $0[Int(fd) / 32] |= (1 << (Int(fd) % 32)) }
            }
            var tv = timeval(tv_sec: 0, tv_usec: 300_000)
            let r = select(fd + 1, &rfds, nil, nil, &tv)
            if r > 0 {
                let n = Darwin.read(fd, &byte, 1)
                if n <= 0 { // client 斷線（自己 timeout 回 ask 了）
                    lock.lock(); clientFds[req.id] = nil; lock.unlock()
                    close(fd)
                    DispatchQueue.main.async { [weak self] in self?.onCancel?(req.id) }
                    return
                }
            }
        }
    }

    func resolve(id: String, decision: PermissionDecision) {
        lock.lock()
        guard let fd = clientFds[id] else { lock.unlock(); return }
        clientFds[id] = nil
        lock.unlock()
        if let data = try? JSONEncoder.iso.encode(WireMessage.decision(id: id, decision: decision)) {
            _ = UnixSocket.writeLine(fd, data)
        }
        close(fd)
    }
}

extension JSONDecoder {
    static var iso: JSONDecoder { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }
}
extension JSONEncoder {
    static var iso: JSONEncoder { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e }
}
