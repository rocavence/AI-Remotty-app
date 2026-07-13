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
        // 定期刷新燈號（hook/Accessibility 狀態變了也能反映）
        Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.refresh() }
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
        // 同一 session 一次只會有一個權限停頓 → 新的來就清掉該 session 的舊 pending（已決策的）
        if let old = queue.first(where: { $0.sessionId == req.sessionId && !req.sessionId.isEmpty }) {
            Log.write("清除同 session 舊 pending \(old.id)")
            remove(old.id, buzz: false)
        }
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
    private var inFlight = Set<String>()   // 正在處理的 req id → 防同一決策送兩次

    private func answer(_ req: PermissionRequest, approve: Bool) {
        Log.write("answer approve=\(approve) req=\(req.id) cwd=\(req.cwd) trusted=\(AXHelper.isTrusted)")
        guard !inFlight.contains(req.id) else { Log.write("  略過：已在處理中"); return }
        // 沒 Accessibility 權限 → 擋住、開面板（模擬鍵入會靜默失敗）
        guard AXHelper.isTrusted else {
            Log.write("  擋下：無 Accessibility 權限")
            hud?.show(text: "需要 Accessibility 權限", ok: false)
            AXHelper.openSettings()
            NSApp.activate(ignoringOtherApps: true)
            return  // 不標 inFlight，授權後可再按
        }
        inFlight.insert(req.id)
        let terminal = Terminals.current()
        let finish: (Bool) -> Void = { [weak self] sent in
            guard let self else { return }
            if sent { self.remove(req.id, buzz: true) }  // 只在真的送出後才清（＝決策做完）
            self.inFlight.remove(req.id)
        }

        // Otty：依 cwd 精準切到對的 tab（跨視窗查詢後再送鍵）
        if terminal.id == "otty" {
            DispatchQueue.global().async { [weak self] in
                let tabs = OttyControl.tabs()
                let matched = OttyControl.selectTab(cwd: req.cwd)
                Log.write("  Otty \(tabs.count) tabs，cwd 對到 tab=\(matched)")
                DispatchQueue.main.async {
                    guard let self else { return }
                    let dir = (req.cwd as NSString).lastPathComponent
                    self.hud?.show(text: matched ? "Otty(\(tabs.count)) → \(dir)" : "Otty(\(tabs.count)) 沒對到 tab",
                                   ok: matched)
                    guard matched else { self.joycon.buzzReminder(); finish(false); return }
                    let sent = self.sendAnswerKeys(approve: approve, terminal: terminal)
                    finish(sent)
                }
            }
            return
        }

        // 其他 terminal：activate 到前景後送鍵（無 tab 精準路由）
        terminal.activate()
        hud?.show(text: approve ? "✓ Approve" : "✗ Reject", ok: approve)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            let sent = self?.sendAnswerKeys(approve: approve, terminal: terminal) ?? false
            finish(sent)
        }
    }

    /// 送出回答鍵。前景必須是目標 terminal，否則中止。回傳是否真的送出。
    @discardableResult
    private func sendAnswerKeys(approve: Bool, terminal: TerminalAdapter) -> Bool {
        let front = AXHelper.frontmostBundleId
        Log.write("  前景=\(front ?? "nil") 目標=\(terminal.bundleId)")
        guard front == terminal.bundleId else {
            Log.write("  中止送鍵：前景不是目標 terminal")
            hud?.show(text: "前景不是 \(terminal.name)，沒送出", ok: false)
            joycon.buzzReminder()
            return false
        }
        if approve { KeySim.pressReturn() }   // 右鍵 = Enter（確認目前選項）
        else { KeySim.pressEscape() }          // 左鍵 = Esc
        Log.write("  送鍵完成 approve=\(approve)")
        return true
    }

    /// 導航鍵（方向鍵/空白）→ terminal。前景已是 terminal 就即時送（流暢）；否則先切再送。
    private func sendNav(_ key: @escaping () -> Void) {
        guard AXHelper.isTrusted else { AXHelper.openSettings(); return }
        let terminal = Terminals.current()
        if AXHelper.frontmostBundleId == terminal.bundleId {
            key()   // 已在前景，直接送，導航才流暢
            return
        }
        terminal.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard AXHelper.frontmostBundleId == terminal.bundleId else { return }
            key()
        }
    }

    /// 切 terminal tab（⌘⇧[ / ⌘⇧]）。讓使用者先切到 pending 所在的 tab 再 approve。
    private func switchTab(next: Bool) {
        guard AXHelper.isTrusted else { AXHelper.openSettings(); return }
        let terminal = Terminals.current()
        terminal.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            guard AXHelper.frontmostBundleId == terminal.bundleId else { return }
            if next { KeySim.nextTab() } else { KeySim.prevTab() }
        }
    }

    // 給選單用（指定 id）
    func approve(id: String) { if let r = queue.first(where: { $0.id == id }) { answer(r, approve: true) } }
    func reject(id: String)  { if let r = queue.first(where: { $0.id == id }) { answer(r, approve: false) } }

    // MARK: Joy-Con 動作

    private func handle(_ action: AppSettings.Action) {
        Log.write("handle \(action.rawValue) queue=\(queue.count) front=\(front?.id ?? "nil")")
        switch action {
        case .approve:
            hud?.show(text: "Enter", ok: true)
            sendNav { KeySim.pressReturn() }   // 右鍵直接送 Enter 到前景 terminal
            if let r = front { remove(r.id, buzz: false) }
        case .reject:
            hud?.show(text: "Esc", ok: false)
            sendNav { KeySim.pressEscape() }
            if let r = front { remove(r.id, buzz: false) }
        case .tabPrev: switchTab(next: false)
        case .tabNext: switchTab(next: true)
        case .navUp:    sendNav { KeySim.arrowUp() }
        case .navDown:  sendNav { KeySim.arrowDown() }
        case .navLeft:  sendNav { KeySim.arrowLeft() }
        case .navRight: sendNav { KeySim.arrowRight() }
        case .goOn:     sendNav { KeySim.type("go on"); KeySim.pressReturn() }
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

    func clearAll() {
        Log.write("手動清除全部 pending (\(queue.count))")
        for r in queue { reminderTimers[r.id]?.invalidate(); autoAnswerTimers[r.id]?.invalidate() }
        reminderTimers.removeAll(); autoAnswerTimers.removeAll()
        queue.removeAll()
        refresh()
    }

    private var settingsWindow: SettingsWindowController?
    func showSettings() {
        if settingsWindow == nil { settingsWindow = SettingsWindowController() }
        settingsWindow?.showAndFocus()
    }
}
