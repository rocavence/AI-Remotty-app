import GameController
import CoreHaptics
import Foundation

/// 管 Joy-Con：連線偵測、按鍵事件、震動。
/// 依 docs/spike-joycon.md：按鍵走 physicalInputProfile.buttons；震動必用 hapticContinuous。
final class JoyConManager {
    static let shared = JoyConManager()

    /// 按下某動作時回呼（在 main queue）。
    var onAction: ((AppSettings.Action) -> Void)?
    /// 連線狀態變化回呼。
    var onConnection: ((Bool) -> Void)?

    private(set) var connected = false
    private var engines: [CHHapticEngine] = []
    private var boundControllers = Set<ObjectIdentifier>()

    func start() {
        GCController.controllers().forEach(bind)
        NotificationCenter.default.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] n in
            if let c = n.object as? GCController { self?.bind(c) }
        }
        NotificationCenter.default.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] n in
            if let c = n.object as? GCController { self?.boundControllers.remove(ObjectIdentifier(c)) }
            self?.updateConnection()
        }
        GCController.startWirelessControllerDiscovery {}
        updateConnection()
    }

    private func bind(_ c: GCController) {
        let key = ObjectIdentifier(c)
        guard !boundControllers.contains(key) else { return }
        boundControllers.insert(key)

        // 預備 haptics 引擎
        if let h = c.haptics, let eng = h.createEngine(withLocality: .default) {
            try? eng.start()
            engines.append(eng)
        }

        // 按鍵：physicalInputProfile.buttons（唯一可靠來源，見 spike）
        let profile = c.physicalInputProfile
        for (name, btn) in profile.buttons {
            btn.valueChangedHandler = { [weak self] _, _, pressed in
                guard pressed else { return } // 只在按下瞬間觸發
                guard let self, let action = AppSettings.shared.action(forButton: name) else { return }
                DispatchQueue.main.async { self.onAction?(action) }
            }
        }
        updateConnection()
    }

    private func updateConnection() {
        let now = GCController.controllers().contains { $0.vendorName?.contains("Joy-Con") ?? false }
            || !GCController.controllers().isEmpty
        if now != connected {
            connected = now
            onConnection?(now)
        }
    }

    // MARK: 震動（全用短 continuous 脈衝）

    func buzz(times: Int, duration: Double = 0.15, gap: Double = 0.12) {
        guard AppSettings.shared.rumbleEnabled else { return }
        guard let eng = engines.first else { return }
        for i in 0..<max(1, times) {
            let at = Double(i) * (duration + gap)
            playPulse(eng, at: at, duration: duration)
        }
    }

    private func playPulse(_ eng: CHHapticEngine, at: Double, duration: Double) {
        let ev = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0),
            ],
            relativeTime: at, duration: duration)
        guard let pattern = try? CHHapticPattern(events: [ev], parameters: []),
              let player = try? eng.makePlayer(with: pattern) else { return }
        try? eng.start()
        try? player.start(atTime: 0)
    }

    // 語意化封裝
    func buzzNewRequest() { buzz(times: 2) }
    func buzzReminder()   { buzz(times: 2, duration: 0.22) }
    func buzzDone()       { buzz(times: 1) }
}
