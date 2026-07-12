# Spike: Joy-Con（Phase 0）— ✅ 通過

日期 2026-07-13。環境：macOS 26 (arm64)、Swift 6.3、CLT only（無 Xcode）。

## 結論：走 GameController framework，IOKit HID 反解免了

單支 **Joy-Con (L)** 透過藍牙配對後被 `GCController` 直接辨識。三項全綠。

## 1. 偵測 ✓
- `GCController.controllers()` 連上後含 Joy-Con (L)
- `vendorName == "Joy-Con (L)"`、`productCategory == "Nintendo Switch Joy-Con (L)"`
- 用 `.GCControllerDidConnect` / `.GCControllerDidDisconnect` 監聽熱插拔
- `GCController.startWirelessControllerDiscovery {}` 觸發配對掃描

## 2. 按鍵 ✓ —— 用 physicalInputProfile.buttons（別用 microGamepad 別名）
- 單 Joy-Con 只提供 `microGamepad` profile，但 **microGamepad 的 `buttonA` / `buttonX` 別名有 bug**：兩個都回報 `localizedName == "Button A"`。**不可用**。
- 正解：`controller.physicalInputProfile.buttons`（`[String: GCControllerButtonInput]`），按 key 名綁 handler。實測可用鍵：
  ```
  Button A, Button B, Button X, Button Y,   // Joy-Con L 四顆方向箭頭鍵映射成 ABXY
  Button Home, Button Menu,
  Left Shoulder (= L), Right Shoulder (= ZL),
  Direction Pad Up/Down/Left/Right
  ```
- 綁法：`el.valueChangedHandler = { _, val, pressed in ... }`；`pressed` 去彈跳（每次按放各觸發一次）。
- **mapping 對應 SPEC 預設**（可在設定改）：
  - Approve → Button A
  - Reject → Button B
  - Skip → Button X
  - Open Terminal → Button Home
  - Auto Approve toggle → Button Menu（SPEC 寫 +，單 L 無 +，用 Menu 代）

## 3. 震動 ✓ —— 必須用 continuous，transient 是 no-op
- `controller.haptics`（`GCDeviceHaptics`）非 nil，`supportedLocalities == ["Default", "JoyCon (L)", "All"]`
- `haptics.createEngine(withLocality:)` → `CHHapticEngine`（CoreHaptics），任一 locality 都可（實測 Default 即可）
- ⚠️ **關鍵坑**：`hapticTransient` 送出無 error 但**不驅動 Joy-Con 馬達**（使用者實測無感）。
- ✅ **`hapticContinuous`（含 duration）確定驅動馬達**（使用者實測有感）。intensity 1.0 / sharpness 1.0 / duration 0.8 明顯。
- 實作「一下」= 短 continuous 脈衝（~0.12–0.18s）；「兩下」= 兩段短脈衝間隔 ~120ms。
- 引擎要留參考（別讓 CHHapticEngine 被釋放），app 內 JoyConManager 持有陣列。

## 實作要點（給 Phase 2）
- `setvbuf(stdout, nil, _IONBF, 0)` 只是 spike 為了即時 log，app 不需要
- JoyConManager：持有 engine 陣列、監聽 connect/disconnect、physicalInputProfile.buttons 綁 handler、mapping 可設定
- 震動樣式（全用 continuous 短脈衝）：新 permission = ×2（間隔 ~120ms）、完成 = ×1、20s 提醒 = ×2

## spike 檔
- `spikes/joycon-detect.swift` — 基本偵測
- `spikes/joycon-probe.swift` — 按鍵全量 + 震動（← 主要證據）
