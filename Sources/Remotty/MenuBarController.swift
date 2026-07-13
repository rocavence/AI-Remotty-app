import AppKit

/// menubar 圖示 + 下拉選單。狀態變化時 rebuild NSMenu。
final class MenuBarController {
    private let item: NSStatusItem
    private weak var controller: AppController?

    init(controller: AppController) {
        self.controller = controller
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        update(queue: [], joyconConnected: false, autoApprove: false)
    }

    enum Light { case green, yellow, red }

    func update(queue: [PermissionRequest], joyconConnected: Bool, autoApprove: Bool) {
        let n = queue.count
        // 狀態燈：黃=有待確認、紅=尚未設好、綠=就緒
        let ready = joyconConnected && HookInstaller.isInstalled() && AXHelper.isTrusted
        let light: Light = n > 0 ? .yellow : (ready ? .green : .red)
        if let btn = item.button {
            btn.image = Self.trafficLight(light)
            btn.image?.isTemplate = false
            btn.title = n > 0 ? " \(n)" : ""
        }
        item.menu = buildMenu(queue: queue, joyconConnected: joyconConnected, autoApprove: autoApprove)
    }

    /// 垂直紅黃綠燈圖示：亮起 active 燈，其餘轉暗。
    static func trafficLight(_ active: Light) -> NSImage {
        let w: CGFloat = 11, h: CGFloat = 19, r: CGFloat = 3.4
        let img = NSImage(size: NSSize(width: w, height: h))
        img.lockFocus()
        let cx = w / 2
        let ys: [CGFloat] = [h - r - 1.5, h / 2, r + 1.5]   // 上紅 中黃 下綠
        let lights: [Light] = [.red, .yellow, .green]
        let colors: [Light: NSColor] = [
            .red: NSColor.systemRed, .yellow: NSColor.systemYellow, .green: NSColor.systemGreen,
        ]
        for (i, l) in lights.enumerated() {
            let on = (l == active)
            let color = colors[l]!
            (on ? color : color.withAlphaComponent(0.16)).setFill()
            let dot = NSBezierPath(ovalIn: NSRect(x: cx - r, y: ys[i] - r, width: r * 2, height: r * 2))
            dot.fill()
        }
        img.unlockFocus()
        return img
    }

    private func buildMenu(queue: [PermissionRequest], joyconConnected: Bool, autoApprove: Bool) -> NSMenu {
        let menu = NSMenu()

        // 標頭：狀態
        let status = queue.isEmpty ? "🟢 Idle" : "🔴 Waiting (\(queue.count))"
        menu.addItem(disabled(status))
        let jc = joyconConnected ? "🎮 Joy-Con 已連線" : "⚪️ Joy-Con 未連線"
        menu.addItem(disabled(jc))

        // Accessibility 未授權警告（模擬鍵入必需）
        if !AXHelper.isTrusted {
            let warn = NSMenuItem(title: "⚠️ 需要 Accessibility 權限 → 點此設定",
                                  action: #selector(onOpenAX), keyEquivalent: "")
            warn.target = self
            menu.addItem(warn)
        }
        menu.addItem(.separator())

        // Pending 清單
        if queue.isEmpty {
            menu.addItem(disabled("沒有待處理請求"))
        } else {
            for (i, req) in queue.enumerated() {
                menu.addItem(disabled(req.title))
                let cmd = disabled("   " + String(req.command.prefix(60)))
                cmd.toolTip = req.command
                menu.addItem(cmd)

                let approve = NSMenuItem(title: "   ✓ Approve", action: #selector(onApprove(_:)), keyEquivalent: "")
                approve.target = self; approve.representedObject = req.id
                menu.addItem(approve)
                let reject = NSMenuItem(title: "   ✗ Reject", action: #selector(onReject(_:)), keyEquivalent: "")
                reject.target = self; reject.representedObject = req.id
                menu.addItem(reject)
                if i < queue.count - 1 { menu.addItem(.separator()) }
            }
        }
        menu.addItem(.separator())

        // 動作群
        let open = NSMenuItem(title: "開啟 Terminal", action: #selector(onOpenTerminal), keyEquivalent: "")
        open.target = self; menu.addItem(open)

        let auto = NSMenuItem(title: "Auto Approve", action: #selector(onToggleAuto), keyEquivalent: "")
        auto.target = self; auto.state = autoApprove ? .on : .off
        menu.addItem(auto)

        let settings = NSMenuItem(title: "設定…", action: #selector(onSettings), keyEquivalent: ",")
        settings.target = self; menu.addItem(settings)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "結束 Remotty", action: #selector(onQuit), keyEquivalent: "q")
        quit.target = self; menu.addItem(quit)
        return menu
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        i.isEnabled = false
        return i
    }

    // MARK: actions
    @objc private func onApprove(_ s: NSMenuItem) {
        if let id = s.representedObject as? String { controller?.approve(id: id) }
    }
    @objc private func onReject(_ s: NSMenuItem) {
        if let id = s.representedObject as? String { controller?.reject(id: id) }
    }
    @objc private func onOpenTerminal() { controller?.openTerminal() }
    @objc private func onOpenAX() { AXHelper.openSettings() }
    @objc private func onToggleAuto() {
        AppSettings.shared.autoApprove.toggle(); controller?.refresh()
    }
    @objc private func onSettings() {
        NSApp.activate(ignoringOtherApps: true)
        controller?.showSettings()
    }
    @objc private func onQuit() { NSApp.terminate(nil) }
}
