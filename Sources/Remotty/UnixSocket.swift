import Foundation

/// 極簡 POSIX unix-domain socket 封裝（server + client），每則訊息一行（\n 結尾）JSON。
enum UnixSocket {

    static func makeSockaddr(_ path: String) -> sockaddr_un {
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        _ = withUnsafeMutablePointer(to: &addr.sun_path.0) { dst in
            path.withCString { src in strncpy(dst, src, 103) }
        }
        return addr
    }

    // MARK: Server

    /// 建 listen socket，回 fd（失敗回 -1）。會先刪掉舊 socket 檔。
    static func listen(_ path: String) -> Int32 {
        unlink(path)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return -1 }
        var addr = makeSockaddr(path)
        let len = socklen_t(MemoryLayout<sockaddr_un>.size)
        let ok = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, len) }
        }
        guard ok == 0, Darwin.listen(fd, 16) == 0 else { close(fd); return -1 }
        return fd
    }

    static func accept(_ serverFd: Int32) -> Int32 {
        return Darwin.accept(serverFd, nil, nil)
    }

    // MARK: Client

    /// 連上 server，回 fd（失敗回 -1，代表 app 沒在跑）。
    static func connect(_ path: String, timeoutSec: Int = 3) -> Int32 {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return -1 }
        var addr = makeSockaddr(path)
        let len = socklen_t(MemoryLayout<sockaddr_un>.size)
        let ok = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(fd, $0, len) }
        }
        guard ok == 0 else { close(fd); return -1 }
        return fd
    }

    // MARK: IO

    static func writeLine(_ fd: Int32, _ data: Data) -> Bool {
        var payload = data
        payload.append(0x0A) // \n
        return payload.withUnsafeBytes { raw -> Bool in
            var sent = 0
            let base = raw.bindMemory(to: UInt8.self).baseAddress!
            while sent < payload.count {
                let n = Darwin.write(fd, base + sent, payload.count - sent)
                if n <= 0 { return false }
                sent += n
            }
            return true
        }
    }

    /// 阻塞讀一行（到 \n）。timeout 秒到回 nil；連線關閉也回 nil。
    static func readLine(_ fd: Int32, timeoutSec: Double) -> Data? {
        var buf = Data()
        let deadline = Date().addingTimeInterval(timeoutSec)
        var byte: UInt8 = 0
        while Date() < deadline {
            // 用 select 等可讀，避免忙等
            var rfds = fd_set()
            fdZero(&rfds); fdSet(fd, &rfds)
            var tv = timeval(tv_sec: 0, tv_usec: 200_000) // 200ms poll
            let r = select(fd + 1, &rfds, nil, nil, &tv)
            if r < 0 { return nil }
            if r == 0 { continue }
            let n = Darwin.read(fd, &byte, 1)
            if n <= 0 { return nil }        // EOF / 錯誤
            if byte == 0x0A { return buf }  // 一行完成
            buf.append(byte)
        }
        return nil // timeout
    }
}

// fd_set 在 Swift 沒有現成 macro，自己補。
private func fdZero(_ set: inout fd_set) {
    set = fd_set()
}
private func fdSet(_ fd: Int32, _ set: inout fd_set) {
    let intOffset = Int(fd) / 32
    let bitOffset = Int(fd) % 32
    let mask: Int32 = 1 << bitOffset
    withUnsafeMutablePointer(to: &set.fds_bits) { p in
        p.withMemoryRebound(to: Int32.self, capacity: 32) { bits in
            bits[intOffset] |= mask
        }
    }
}
