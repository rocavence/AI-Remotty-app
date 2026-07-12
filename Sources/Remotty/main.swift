import AppKit

// 依 argv 分派：hook client / hook 安裝 / 或（預設）menubar app。
let args = CommandLine.arguments

if args.count > 1 {
    switch args[1] {
    case "notify":
        HookClient.notify()       // never returns（通知 app，非阻塞）
    case "ask":
        HookClient.run()          // never returns（保留：阻塞式 hook-decision）
    case "install-hook":
        let bin = Bundle.main.executablePath ?? args[0]
        let bak = try? HookInstaller.install(binaryPath: bin)
        print("hook 已安裝。" + ((bak.flatMap { $0 }).map { " 備份：\($0)" } ?? ""))
        exit(0)
    case "uninstall-hook":
        let ok = (try? HookInstaller.uninstall()) ?? false
        print(ok ? "hook 已移除。" : "沒有可移除的 hook。")
        exit(0)
    case "status":
        print("hook installed: \(HookInstaller.isInstalled())")
        print("socket: \(Paths.socket)")
        exit(0)
    default:
        FileHandle.standardError.write(Data("用法: remotty [ask|install-hook|uninstall-hook|status]\n".utf8))
        exit(2)
    }
}

// menubar app
let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // 無 Dock 圖示
let delegate = AppController()
app.delegate = delegate
app.run()
