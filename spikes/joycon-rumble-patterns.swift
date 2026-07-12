// 測實際 app 震動樣式：短 continuous 脈衝
import GameController
import CoreHaptics
import Foundation
setvbuf(stdout, nil, _IONBF, 0)
var engines: [CHHapticEngine] = []

func engine(_ c: GCController) -> CHHapticEngine? {
    guard let h = c.haptics, let e = h.createEngine(withLocality: .default) else { return nil }
    try? e.start(); engines.append(e); return e
}

// 一下 = 短 continuous 脈衝
func pulse(_ e: CHHapticEngine, dur: Double, intensity: Float = 1.0) {
    let ev = CHHapticEvent(eventType: .hapticContinuous,
        parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                     CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)],
        relativeTime: 0, duration: dur)
    if let p = try? e.makePlayer(with: CHHapticPattern(events: [ev], parameters: [])) {
        try? p.start(atTime: 0)
    }
}

func run(_ c: GCController) {
    guard let e = engine(c) else { print("無引擎"); return }
    print("① 新 permission = 兩下（0.15s ×2，間隔 0.12s）")
    pulse(e, dur: 0.15); RunLoop.main.run(until: Date().addingTimeInterval(0.27)); pulse(e, dur: 0.15)
    RunLoop.main.run(until: Date().addingTimeInterval(1.2))
    print("② 完成 = 一下（0.15s）")
    pulse(e, dur: 0.15)
    RunLoop.main.run(until: Date().addingTimeInterval(1.2))
    print("③ 20s 提醒 = 兩下較長（0.22s ×2）")
    pulse(e, dur: 0.22); RunLoop.main.run(until: Date().addingTimeInterval(0.34)); pulse(e, dur: 0.22)
    RunLoop.main.run(until: Date().addingTimeInterval(1.0))
    print("done")
}
GCController.controllers().forEach(run)
NotificationCenter.default.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) {
    if let c = $0.object as? GCController { run(c) }
}
if GCController.controllers().isEmpty { print("配對中…"); GCController.startWirelessControllerDiscovery {} }
RunLoop.main.run(until: Date().addingTimeInterval(8))
