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

### Phase 0 — Spike（先驗證再蓋房子）— ✅ 完成 2026-07-13
- [x] Joy-Con spike：GCController 抓 Joy-Con (L)、讀按鍵、觸發震動 → `docs/spike-joycon.md`
      **結果**：全綠。GCController 直認 Joy-Con (L) 免 IOKit；按鍵走 `physicalInputProfile.buttons`（microGamepad 別名有 bug）；震動須用 `hapticContinuous`（transient 是 no-op），三段實際樣式使用者實測有感。
- [x] Provider spike：hooks 路線實測 → `docs/spike-provider.md`
      **結果**：MVP 走 `PreToolUse` 阻塞式 hook，stdout 回 `permissionDecision` allow/deny/ask，預設 timeout 600s；stdin 帶 session_id+cwd 可路由多 session。逾時前回 `ask` 當安全 fallback。⚠️ 文件仍要對當前 CC 版本實測 4 點（見 doc 末）。
- 驗收：✅ 兩份筆記完成，MVP 路線＋理由＋坑齊。無死路。

### Phase 1 — App scaffold ✅
- [x] SPM 專案（照 Configgy 結構）：menubar app + 同 binary CLI 入口（`main.swift` 依 argv 分派）
- [x] Menu bar 狀態：🟢 Idle / 🔴 Waiting (N)，下拉含 Pending 清單/Approve/Reject/Open Terminal/Auto Approve/設定/Quit（`MenuBarController`）
- [x] 設定持久化（UserDefaults suite）：terminal、按鍵 mapping、rumble、reminder、autoApprove、autoAnswerAfter（`AppSettings`）
- 驗收：✅ app 啟動、menubar 紅/綠切換實測（IPC round-trip 時 Waiting(1)）

### Phase 2 — Joy-Con 模組 ✅
- [x] 配對偵測、斷線監聽（`JoyConManager`，GCController connect/disconnect）
- [x] 按鍵事件：A/B/X/Home/Menu → 動作，走 physicalInputProfile.buttons，mapping 可設定
- [x] 震動：新 request ×2、20s 提醒 ×2 長、完成 ×1，全用 hapticContinuous
- 驗收：✅ 按鍵/震動法在 Phase 0 spike 實機驗過；app 內 buzz 封裝完成
- ⚠️ 待實機一次：實體按 A → 真的解除某筆（onAction→decide→resolve 接線已完成，唯一沒自動化的一環）

### Phase 3 — Provider 層 + Claude Code Provider ✅
- [x] `PermissionProvider` protocol（source-agnostic）
- [x] Claude Code provider：unix socket server（`ClaudeCodeProvider`）+ hook client（`HookClient` = `remotty ask`）
- [x] Queue：多筆 pending（id/session_id/cwd/tool/command/timestamp），依序處理，front 為 Joy-Con 作用對象
- [x] hook 安裝器：merge-append 進 `~/.claude/settings.json`，**自動備份**，保留既有 hook（`HookInstaller`）
- 驗收：✅ IPC round-trip 實測（4.1s 阻塞證明 connect→enqueue→resolve）；installer 保留 Otty hook + 備份驗過
- ⚠️ 待實機一次：真開 Claude Code session 觸發 PreToolUse → 走完整條

### Phase 4 — TerminalAdapter 層 ✅（AppleScript 備援降級為選用）
- [x] Swift protocol 照 SPEC 補充章（`TerminalAdapter`）
- [x] 內建 adapters（Otty/Terminal.app/iTerm2/Warp/Ghostty/WezTerm/VS Code/Cursor/Windsurf）+ Other 自訂
- [x] onboarding：首啟開設定視窗選 terminal；設定頁隨時可改（`SettingsWindow`）
- [~] AppleScript 模擬輸入備援：**MVP 未做**——因 Provider 走 hook 直接回決策，不需要打字備援（見 spike-provider）。真的要「開 terminal」用 NSWorkspace activate 即可。留待有無 hook 的 provider 再補。
- 驗收：✅ activate 走 NSWorkspace（Otty/Terminal.app 等 bundle id 已列）

### Phase 5 — 收尾 ✅（git push 待使用者決定公開/私有）
- [x] 打包 .app（`Scripts/build-app.sh`，SPM release + 自簽，沿用 Findly Self-Signed）
- [x] 權限盤點：GameController 免特殊授權（spike 已證）、LSUIElement 無 Dock、NSAppleEventsUsageDescription 給 activate
- [x] README（中文，含安裝/設定/按鍵/hook/安全/CLI）
- [ ] git push：本機 commit 完成，**建 GitHub repo 待使用者決定公開/私有**
- [ ] Launch at Login：設定有欄位，實作（SMAppService）未接——留 backlog
- 驗收：✅ build→open→socket→IPC 全過；重開/重配/實體按鍵整條待一次人工實機

## 剩餘 backlog（MVP 後）
- 實體按鍵→放行 的一次人工實機驗證（onAction→resolve 接線已完成）
- 真開 Claude Code session 跑完整 PreToolUse 一次（driver 端 spike 已驗，端到端待實跑）
- Launch at Login（SMAppService）
- AppleScript 備援輸入（只有走非 hook provider 才需要）
- 按鍵 remapping UI（資料層 mapping 已可設，UI 未做）
- GitHub repo（公開/私有待使用者定）+ AppIcon + dmg 打包

## 鐵則

- 動 `~/.claude/settings.json`（hook 安裝）前先備份並徵求同意。（installer 已自動備份；CLI 直裝要留意）
- AppleScript 模擬鍵入是最後備援——使用者常在別的 Space 工作（見 Findly memory），亂打字會災難；輸入前必須確認目標視窗真的是該 terminal。
- Auto Approve 預設關，開啟要二次確認（安全）。
- 不可逆/對外動作先問。
