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

    func update(queue: [PermissionRequest], joyconConnected: Bool, autoApprove: Bool) {
        // 圖示：Idle 綠、Waiting 紅（用 SF Symbol + 數字）
        if let btn = item.button {
            let n = queue.count
            let symbol = n > 0 ? "bell.badge.fill" : "gamecontroller.fill"
            btn.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Remotty")
            btn.image?.isTemplate = true
            btn.title = n > 0 ? " \(n)" : ""
        }
        item.menu = buildMenu(queue: queue, joyconConnected: joyconConnected, autoApprove: autoApprove)
    }

    private func buildMenu(queue: [PermissionRequest], joyconConnected: Bool, autoApprove: Bool) -> NSMenu {
        let menu = NSMenu()

        // 標頭：狀態
        let status = queue.isEmpty ? "🟢 Idle" : "🔴 Waiting (\(queue.count))"
        menu.addItem(disabled(status))
        let jc = joyconConnected ? "🎮 Joy-Con 已連線" : "⚪️ Joy-Con 未連線"
        menu.addItem(disabled(jc))
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
    @objc private func onToggleAuto() {
        AppSettings.shared.autoApprove.toggle(); controller?.refresh()
    }
    @objc private func onSettings() {
        NSApp.activate(ignoringOtherApps: true)
        controller?.showSettings()
    }
    @objc private func onQuit() { NSApp.terminate(nil) }
}
