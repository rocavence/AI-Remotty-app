import Foundation

/// 簡單檔案日誌 → ~/.remotty/remotty.log（除錯用）。
enum Log {
    private static let url = Paths.dir.appendingPathComponent("remotty.log")
    private static let q = DispatchQueue(label: "remotty.log")

    static func write(_ msg: String) {
        q.async {
            let line = "\(Date()) \(msg)\n"
            if let data = line.data(using: .utf8) {
                if let h = try? FileHandle(forWritingTo: url) {
                    h.seekToEndOfFile(); h.write(data); try? h.close()
                } else {
                    try? data.write(to: url)
                }
            }
        }
    }
}
