// Joy-Con spike — 用 GameController 偵測 Joy-Con (L)、讀按鍵、觸發震動
// 跑法: swift spikes/joycon-detect.swift   然後配對 Joy-Con，按鍵看 log
import GameController
import Foundation

func describe(_ c: GCController) {
    let name = c.vendorName ?? "?"
    let cat = c.productCategory
    let haptics = c.haptics != nil ? "yes" : "NO"
    print("controller: name=\(name) category=\(cat) haptics=\(haptics)")
    if let gp = c.extendedGamepad {
        print("  profile: extendedGamepad")
        gp.valueChangedHandler = { _, el in
            if let b = el as? GCControllerButtonInput, b.isPressed {
                print("  button pressed: \(el.localizedName ?? el.sfSymbolsName ?? "?")")
            }
        }
    } else if let mp = c.microGamepad {
        print("  profile: microGamepad")
        mp.valueChangedHandler = { _, _ in print("  micro input") }
    } else {
        print("  profile: NONE (單支 Joy-Con 可能只認 raw HID，見筆記)")
    }
}

setvbuf(stdout, nil, _IONBF, 0)
print("=== Joy-Con spike ===")
print("已連控制器: \(GCController.controllers().count)")
GCController.controllers().forEach(describe)

NotificationCenter.default.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { note in
    if let c = note.object as? GCController {
        print(">> 連上"); describe(c)
    }
}
NotificationCenter.default.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { _ in
    print(">> 斷線")
}

print("等待輸入… Ctrl-C 結束。現在去配對 Joy-Con。")
GCController.startWirelessControllerDiscovery {}
RunLoop.main.run()
