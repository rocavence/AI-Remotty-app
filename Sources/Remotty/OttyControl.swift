import Foundation

/// 透過 Otty 的 AppleScript 字典查詢/控制 tab（Otty 專屬）。
/// tab 可讀 working directory / selected，可寫 selected → 依 cwd 精準切到對的 tab。
/// 需要 Automation 權限（app → Otty AppleEvents，首次會跳系統詢問）。
enum OttyControl {
    struct TabInfo { let cwd: String; let selected: Bool }

    /// 目前所有 tab（跨視窗）。失敗回空陣列。
    static func tabs() -> [TabInfo] {
        let script = """
        tell application "Otty"
          set out to ""
          repeat with w in windows
            repeat with t in tabs of w
              set out to out & (working directory of t) & "\\t" & (selected of t) & "\\n"
            end repeat
          end repeat
          return out
        end tell
        """
        guard let raw = run(script) else { return [] }
        return raw.split(separator: "\n").compactMap { line in
            let parts = line.components(separatedBy: "\t")
            guard parts.count >= 2 else { return nil }
            return TabInfo(cwd: parts[0], selected: parts[1].contains("true"))
        }
    }

    /// 依 cwd 選到對應 tab 並 activate Otty。回傳是否找到。
    /// cwd 用 argv 傳入避免注入。
    static func selectTab(cwd: String) -> Bool {
        let script = """
        on run argv
          set target to item 1 of argv
          tell application "Otty"
            repeat with w in windows
              repeat with t in tabs of w
                if (working directory of t) is target then
                  set selected of t to true
                  activate
                  return "ok"
                end if
              end repeat
            end repeat
          end tell
          return "notfound"
        end run
        """
        return run(script, args: [cwd]) == "ok"
    }

    // MARK: osascript 執行
    private static func run(_ script: String, args: [String] = []) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", script] + args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do { try p.run() } catch { return nil }
        p.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard p.terminationStatus == 0 else { return nil }
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
