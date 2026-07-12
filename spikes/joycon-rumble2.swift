// 震動 plan B — 試 JoyCon(L) 專屬 locality + continuous 強震
import GameController
import CoreHaptics
import Foundation
setvbuf(stdout, nil, _IONBF, 0)
var engines: [CHHapticEngine] = []

func tryRumble(_ c: GCController) {
    guard let h = c.haptics else { print("無 haptics"); return }
    for locRaw in h.supportedLocalities {
        guard let eng = h.createEngine(withLocality: locRaw) else { print("createEngine nil @\(locRaw.rawValue)"); continue }
        do {
            try eng.start()
            engines.append(eng)
            let cont = CHHapticEvent(eventType: .hapticContinuous,
                parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                             CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)],
                relativeTime: 0, duration: 0.8)
            let pat = try CHHapticPattern(events: [cont], parameters: [])
            let p = try eng.makePlayer(with: pat)
            try p.start(atTime: 0)
            print("送出 continuous @locality=\(locRaw.rawValue) — 感覺到嗎？")
            RunLoop.main.run(until: Date().addingTimeInterval(1.5))
        } catch { print("err @\(locRaw.rawValue): \(error)") }
    }
}
GCController.controllers().forEach(tryRumble)
NotificationCenter.default.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) {
    if let c = $0.object as? GCController { tryRumble(c) }
}
if GCController.controllers().isEmpty { print("先配對…") ; GCController.startWirelessControllerDiscovery {} }
RunLoop.main.run(until: Date().addingTimeInterval(6))
print("done")
