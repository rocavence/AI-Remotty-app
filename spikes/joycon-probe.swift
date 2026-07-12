// Joy-Con probe — 印所有按鍵事件 + 連上就震一下
import GameController
import CoreHaptics
import Foundation

setvbuf(stdout, nil, _IONBF, 0)
var engines: [CHHapticEngine] = []

func rumble(_ c: GCController) {
    guard let h = c.haptics else { print("  無 haptics"); return }
    // Joy-Con 只有一顆 actuator，用 default locality
    guard let eng = h.createEngine(withLocality: .default) else { print("  createEngine nil"); return }
    do {
        try eng.start()
        engines.append(eng)
        let ev = CHHapticEvent(eventType: .hapticTransient,
                               parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)],
                               relativeTime: 0)
        let pattern = try CHHapticPattern(events: [ev], parameters: [])
        let player = try eng.makePlayer(with: pattern)
        try player.start(atTime: 0)
        print("  >>> 震動已送出（應感覺到一下）")
    } catch { print("  haptics error: \(error)") }
}

func hook(_ c: GCController) {
    print("hook: \(c.vendorName ?? "?")  localities=\(c.haptics?.supportedLocalities.map{$0.rawValue} ?? [])")
    rumble(c)
    if let mp = c.microGamepad {
        mp.reportsAbsoluteDpadValues = true
        mp.valueChangedHandler = { _, el in
            if let b = el as? GCControllerButtonInput {
                print("  BTN \(el.localizedName ?? "?") pressed=\(b.isPressed) val=\(b.value)")
            } else if let d = el as? GCControllerDirectionPad {
                print("  DPAD x=\(d.xAxis.value) y=\(d.yAxis.value)")
            }
        }
        // 逐一列出可用元素
        print("  buttonA=\(mp.buttonA) buttonX=\(mp.buttonX) menu=\(String(describing: mp.buttonMenu))")
    }
    // 也掛 input.buttons 全量（Joy-Con 額外鍵走 GCControllerInput）
    if #available(macOS 11.0, *), let input = c.physicalInputProfile as GCPhysicalInputProfile? {
        for (name, el) in input.buttons {
            el.valueChangedHandler = { _, val, pressed in
                if pressed { print("  RAW \(name) val=\(val)") }
            }
        }
        print("  raw buttons: \(input.buttons.keys.sorted())")
    }
}

GCController.controllers().forEach(hook)
NotificationCenter.default.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) {
    if let c = $0.object as? GCController { hook(c) }
}
print("probe 起動，按 Joy-Con 各鍵… (10s)")
GCController.startWirelessControllerDiscovery {}
RunLoop.main.run(until: Date().addingTimeInterval(10))
print("probe 結束")
