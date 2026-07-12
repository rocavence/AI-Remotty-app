# 實作計畫（給下個 session 用，建議 Opus 跑）

先讀 `SPEC.md`（含結尾 TerminalAdapter 補充）再動工。照 Phase 順序做，每個 Phase 有驗收條件，過了才進下一個。

## 既有資產可抄

- `~/Code/Configgy-app`：Swift 原生 menubar app 完整範本（SPM 結構、Timer watch、單視窗設定頁、CLI 同 binary、自簽憑證簽章流程）。scaffold 直接參考它。
- `~/Code/Findly-app`：AX/AppleScript 操控其他 app 視窗的經驗；自簽 key 沿用（見 memory `configgy-project`）。
- Menubar 選單分組照 memory `menubar-menu-grouping` 慣例。

## 關鍵技術決策（Phase 0 要驗證，別跳過）

1. **Joy-Con 連線**：優先試 GameController framework（`GCController`）——macOS 原生支援 Joy-Con，按鍵事件用 `GCControllerButtonInput`、震動用 `GCDeviceHaptics`（CoreHaptics engine）。若單支 Joy-Con (L) 抓不到才退 IOKit HID 反解（成本高，盡量避免）。
   - 驗證法：寫 10 行 CLI 印 `GCController.controllers()`，配對 Joy-Con (L) 按 A/B 看有沒有 event、`hapticEngines` 是否非 nil。
2. **Claude Code permission 事件來源**（Provider 層核心，先做 spike）：
   - 候選 A：Claude Code hooks——`Notification` hook（`permission` 類通知）拿到「有 prompt 在等」事件 → hook script POST 到 Bridge 本機 HTTP/Unix socket。**只解決「得知」，不解決「回覆」**。
   - 候選 B：`PreToolUse` hook 回 `decision: approve/block`——能直接回覆，但 hook 是同步等 script 結束，要讓 script 卡住等 Joy-Con 按鍵再輸出 JSON（timeout 要查，可能 60s 上限，需 config）。這條若可行是最乾淨的「API 優先」路。
   - 候選 C：headless `--permission-prompt-tool`（MCP）——只適用非互動場景，MVP 非主線。
   - 回覆備援：AppleScript activate terminal + 模擬鍵入（y/enter 或方向鍵），照 SPEC 優先序，只在 A 路線時搭配用。
   - 驗收：寫出 spike 筆記（`docs/spike-provider.md`），確定 MVP 走哪條，列出 timeout/多 session 併發的坑。
3. **多 session 對應**：同時開多個 Claude Code session 時，事件要帶得出來源（hook payload 有 session_id/cwd），queue 每筆要能對回正確 terminal 視窗。MVP 至少做到「帶 cwd 顯示」，精準 focus 可後補。

## Phases

### Phase 0 — Spike（先驗證再蓋房子）
- [ ] Joy-Con spike：GCController 抓 Joy-Con (L)、讀按鍵、觸發震動 → `docs/spike-joycon.md`
- [ ] Provider spike：hooks 路線 A/B 實測（真開一個 Claude Code session 觸發 permission）→ `docs/spike-provider.md`
- 驗收：兩份 spike 筆記寫明「MVP 採用路線＋理由＋坑」。**兩個 spike 有任一死路要先回報使用者再繼續。**

### Phase 1 — App scaffold
- [ ] SPM 專案（照 Configgy 結構）：menubar app + 同 binary CLI 入口
- [ ] Menu bar 狀態：🟢 Idle / 🔴 Waiting (N)，下拉照 SPEC（Pending 清單、Approve/Reject、Open Terminal、Settings、Quit），分組照 menubar 慣例
- [ ] 設定持久化（UserDefaults 或 plist）：terminal 選擇、按鍵 mapping、rumble 開關、reminder interval、launch at login
- 驗收：app 可啟動、假資料 queue 顯示正常

### Phase 2 — Joy-Con 模組
- [ ] 配對偵測、斷線重連提示
- [ ] 按鍵事件：A=Approve、B=Reject、X=Skip、Home=開 terminal、+=Auto Approve toggle（mapping 可改）
- [ ] 震動：新 permission 短震×2、20s 未處理再提醒、完成短震×1（interval 可設）
- 驗收：CONFIGGY 式測試旗標或 debug 選單可手動觸發各震動；實機按鍵印 log

### Phase 3 — Provider 層 + Claude Code Provider
- [ ] `PermissionProvider` protocol（source-agnostic：Claude Code / Codex / Gemini / WebSocket / HTTP 之後可加）
- [ ] Claude Code provider：照 Phase 0 選定路線實作（hook script + 本機 socket/HTTP server in app）
- [ ] Queue：多筆 pending（id/title/command/timestamp/來源 cwd），依序處理
- [ ] hook 安裝器：app 內一鍵把 hook 寫進 `~/.claude/settings.json`（動使用者設定檔前先備份、要提示）
- 驗收：真實 Claude Code session 觸發 permission → menubar 亮紅 → Joy-Con 震動 → 按 A 真的放行

### Phase 4 — TerminalAdapter 層
- [ ] Swift protocol 照 SPEC 補充章
- [ ] 內建 adapters（Terminal.app / iTerm2 / Warp / Ghostty / WezTerm / VS Code / Cursor / Otty）＋ Other 自訂（bundle id + app name + activate 指令）
- [ ] 首次啟動 onboarding：選 terminal；設定頁可隨時改
- [ ] AppleScript 備援：activate + 模擬輸入 + return + 可選切回原 app（需 Accessibility 權限，onboarding 要引導授權）
- 驗收：至少 Terminal.app + iTern2 兩家實測 activate/備援輸入可用

### Phase 5 — 收尾
- [ ] 打包 .app（PyInstaller 不適用，走 Configgy 的 SPM build + 自簽流程）
- [ ] 權限盤點：Bluetooth、Accessibility（模擬鍵入）、Launch at Login
- [ ] README（中英雙版可後補，先中文）：安裝、配對、hook 安裝、troubleshooting
- [ ] git 收乾淨、建 GitHub 私有 repo `rocavence/claude-permission-remote`（推之前問使用者要私有還公開）
- 驗收：關掉重開 app、重配 Joy-Con、跑一次完整 approve 流程

## 鐵則

- 動 `~/.claude/settings.json`（hook 安裝）前先備份並徵求同意。
- AppleScript 模擬鍵入是最後備援——使用者常在別的 Space 工作（見 Findly memory），亂打字會災難；輸入前必須確認目標視窗真的是該 terminal。
- Auto Approve 預設關，開啟要二次確認（安全）。
- 不可逆/對外動作先問。
