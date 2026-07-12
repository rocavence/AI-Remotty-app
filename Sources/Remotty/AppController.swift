import AppKit

/// app 大腦：擁有 queue、provider、Joy-Con、menubar，串起流程。
final class AppController: NSObject, NSApplicationDelegate {
    private let provider: PermissionProvider = ClaudeCodeProvider()
    private let joycon = JoyConManager.shared
    private var menu: MenuBarController!
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
        // Auto Approve：直接放行
        if AppSettings.shared.autoApprove {
            provider.resolve(id: req.id, decision: .allow)
            return
        }
        queue.append(req)
        joycon.buzzNewRequest()
        scheduleReminder(req)
        scheduleAutoAnswer(req)
        refresh()
    }

    private func remove(_ id: String, buzz: Bool) {
        queue.removeAll { $0.id == id }
        reminderTimers[id]?.invalidate(); reminderTimers[id] = nil
        autoAnswerTimers[id]?.invalidate(); autoAnswerTimers[id] = nil
        if buzz { joycon.buzzDone() }
        refresh()
    }

    /// 對「最前一筆」下決策（Joy-Con 按鍵作用對象）。
    private var front: PermissionRequest? { queue.first }

    func decide(id: String, _ decision: PermissionDecision) {
        provider.resolve(id: id, decision: decision)
        remove(id, buzz: true)
    }

    // MARK: Joy-Con 動作

    private func handle(_ action: AppSettings.Action) {
        switch action {
        case .approve: if let r = front { decide(id: r.id, .allow) }
        case .reject:  if let r = front { decide(id: r.id, .deny) }
        case .skip:    if let r = front { decide(id: r.id, .ask) }   // 退回原生 prompt
        case .openTerminal: Terminals.current().activate()
        case .toggleAuto:
            AppSettings.shared.autoApprove.toggle()
            refresh()
        }
    }

    // MARK: 提醒 / 自動回覆

    private func scheduleReminder(_ req: PermissionRequest) {
        let iv = AppSettings.shared.reminderInterval
        let t = Timer.scheduledTimer(withTimeInterval: iv, repeats: true) { [weak self] _ in
            guard let self, self.queue.contains(where: { $0.id == req.id }) else { return }
            self.joycon.buzzReminder()
        }
        reminderTimers[req.id] = t
    }

    private func scheduleAutoAnswer(_ req: PermissionRequest) {
        let after = AppSettings.shared.autoAnswerAfter
        let t = Timer.scheduledTimer(withTimeInterval: after, repeats: false) { [weak self] _ in
            guard let self, self.queue.contains(where: { $0.id == req.id }) else { return }
            // 逼近 hook timeout：回 ask（安全退回原生 prompt），不誤放行也不誤擋
            self.provider.resolve(id: req.id, decision: .ask)
            self.remove(req.id, buzz: false)
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
