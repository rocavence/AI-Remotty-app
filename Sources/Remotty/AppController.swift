import AppKit

/// app 大腦：擁有 queue、provider、Joy-Con、menubar，串起流程。
final class AppController: NSObject, NSApplicationDelegate {
    private let provider: PermissionProvider = ClaudeCodeProvider()
    private let joycon = JoyConManager.shared
    private var menu: MenuBarController!
    private let hud: HUD? = HUD()
    private var reminderTimers: [String: Timer] = [:]
    private var autoAnswerTimers: [String: Timer] = [:]

    private(set) var queue: [PermissionRequest] = []

    func applicationDidFinishLaunching(_ n: Notification) {
        menu = MenuBarController(controller: self)
        wireJoyCon()
        wireProvider()
        joycon.start()
        provider.start()

        if !AppSettings.shared.onboardingDone {
            DispatchQueue.main.async { [weak self] in self?.showSettings() }
        }
        refresh()
    }

    func applicationWillTerminate(_ n: Notification) { provider.stop() }

    // MARK: 串線

    private func wireProvider() {
        provider.onRequest = { [weak self] req in self?.enqueue(req) }
        provider.onCancel = { [weak self] id in self?.remove(id, buzz: false) }
    }

    private func wireJoyCon() {
        joycon.onConnection = { [weak self] _ in self?.refresh() }
        joycon.onAction = { [weak self] action in self?.handle(action) }
    }

    // MARK: Queue

    private func enqueue(_ req: PermissionRequest) {
        queue.append(req)
        joycon.buzzNewRequest()
        scheduleReminder(req)
        scheduleExpiry(req)
        refresh()
        // Auto Approve：自動送出放行鍵入（預設關）
        if AppSettings.shared.autoApprove {
            answer(req, approve: true)
        }
    }

    private func remove(_ id: String, buzz: Bool) {
        queue.removeAll { $0.id == id }
        reminderTimers[id]?.invalidate(); reminderTimers[id] = nil
        autoAnswerTimers[id]?.invalidate(); autoAnswerTimers[id] = nil
        if buzz { joycon.buzzDone() }
        refresh()
    }

    /// 對「最前一筆」作用（Joy-Con 按鍵對象）。
    private var front: PermissionRequest? { queue.first }

    /// 切到 terminal → 模擬鍵入回答原生 prompt。approve=打「1 ↵」、reject=Esc。
    private func answer(_ req: PermissionRequest, approve: Bool) {
        Log.write("answer approve=\(approve) req=\(req.id) trusted=\(AXHelper.isTrusted)")
        // 沒 Accessibility 權限 → 擋住、開面板（模擬鍵入會靜默失敗）
        guard AXHelper.isTrusted else {
            Log.write("  擋下：無 Accessibility 權限")
            hud?.show(text: "需要 Accessibility 權限", ok: false)
            AXHelper.openSettings()
            NSApp.activate(ignoringOtherApps: true)
            return  // 不移除 queue，權限好了可再按
        }
        let terminal = Terminals.current()
        terminal.activate()
        // 等視窗真的到最前再送鍵
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            let front = AXHelper.frontmostBundleId
            Log.write("  activate \(terminal.name)(\(terminal.bundleId)) 後 前景=\(front ?? "nil")")
            // 防呆：前景必須是目標 terminal，否則中止（避免打到別的 app / 別的 Space）
            guard front == terminal.bundleId else {
                Log.write("  中止送鍵：前景不是目標 terminal")
                self?.hud?.show(text: "前景不是 \(terminal.name)，沒送出", ok: false)
                self?.joycon.buzzReminder()   // 提示沒送出
                return
            }
            if approve {
                KeySim.type("1"); KeySim.pressReturn()
            } else {
                KeySim.pressEscape()
            }
            Log.write("  送鍵完成 approve=\(approve)")
        }
        hud?.show(text: approve ? "✓ Approve" : "✗ Reject", ok: approve)
        remove(req.id, buzz: true)
    }

    // 給選單用（指定 id）
    func approve(id: String) { if let r = queue.first(where: { $0.id == id }) { answer(r, approve: true) } }
    func reject(id: String)  { if let r = queue.first(where: { $0.id == id }) { answer(r, approve: false) } }

    // MARK: Joy-Con 動作

    private func handle(_ action: AppSettings.Action) {
        Log.write("handle \(action.rawValue) queue=\(queue.count) front=\(front?.id ?? "nil")")
        switch action {
        case .approve:
            if let r = front { answer(r, approve: true) } else { hud?.show(text: "沒有待處理", ok: false) }
        case .reject:
            if let r = front { answer(r, approve: false) } else { hud?.show(text: "沒有待處理", ok: false) }
        case .skip:
            if let r = front { remove(r.id, buzz: false); hud?.show(text: "跳過", ok: false) }
        case .openTerminal:
            Terminals.current().activate()
        case .toggleAuto:
            AppSettings.shared.autoApprove.toggle()
            hud?.show(text: AppSettings.shared.autoApprove ? "Auto Approve 開" : "Auto Approve 關",
                      ok: AppSettings.shared.autoApprove)
            refresh()
        }
    }

    // MARK: 提醒 / 過期清除

    private func scheduleReminder(_ req: PermissionRequest) {
        let iv = AppSettings.shared.reminderInterval
        let t = Timer.scheduledTimer(withTimeInterval: iv, repeats: true) { [weak self] _ in
            guard let self, self.queue.contains(where: { $0.id == req.id }) else { return }
            self.joycon.buzzReminder()
        }
        reminderTimers[req.id] = t
    }

    /// pending 太久（可能已在別處回答）自動清掉，避免之後亂送鍵入。
    private func scheduleExpiry(_ req: PermissionRequest) {
        let after = AppSettings.shared.autoAnswerAfter
        let t = Timer.scheduledTimer(withTimeInterval: after, repeats: false) { [weak self] _ in
            self?.remove(req.id, buzz: false)
        }
        autoAnswerTimers[req.id] = t
    }

    // MARK: UI

    func refresh() {
        menu?.update(queue: queue, joyconConnected: joycon.connected, autoApprove: AppSettings.shared.autoApprove)
    }

    func openTerminal() { Terminals.current().activate() }

    private var settingsWindow: SettingsWindowController?
    func showSettings() {
        if settingsWindow == nil { settingsWindow = SettingsWindowController() }
        settingsWindow?.showAndFocus()
    }
}
