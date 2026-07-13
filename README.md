# AI-Remotty

macOS menu bar app：把 **Nintendo Joy-Con (L)** 當成 Claude Code 的 permission 遙控器。

當 Claude Code 要你確認某個工具動作（Approve / Reject）時：

- Joy-Con **震動**提醒
- 按 **A 批准 / B 拒絕 / X 跳過**
- 不必切視窗、不依賴前景焦點
- 多個 Claude Code session 同時跑也能分辨來源

狀態：**MVP 可用**。核心流程（hook → socket → queue → Joy-Con 震動/按鍵 → 回覆決策）已打通並驗證。

## 運作原理

```
Claude Code ──PreToolUse hook──▶ remotty-hook.sh ──unix socket──▶ AI-Remotty (menu bar)
                                                                        │ 入 queue、Joy-Con 震
     ◀────────── permissionDecision ◀──────── 決策 ◀──────────────────  按 A/B/X
```

- **Provider**：permission 來源。MVP = Claude Code 的 `PreToolUse` hook（阻塞式，stdout 回 `permissionDecision` allow/deny/ask）。抽象層預留 Codex / Gemini / WebSocket / HTTP。
- **Queue**：多筆 pending，依序處理，每筆帶 session_id + cwd 可路由。
- **TerminalAdapter**：喚起你選定的 terminal（不寫死任何一家）。內建 Otty / Terminal.app / iTerm2 / Warp / Ghostty / WezTerm / VS Code / Cursor / Windsurf + Other 自訂。

三層分離，互不假設對方。

## 安裝

需要 macOS 14+、Command Line Tools（`swift`、`codesign`）。

```bash
./Scripts/build-app.sh          # → build/AI-Remotty.app
cp -R build/AI-Remotty.app /Applications/
open /Applications/AI-Remotty.app
```

首次啟動會開設定視窗：選你的 Terminal、按「安裝 Hook」。

### 授予 Accessibility 權限（模擬鍵入必需）

回答原生 prompt 靠模擬鍵入，需要 Accessibility：

1. 系統設定 → 隱私權與安全性 → 輔助使用
2. 加入 `/Applications/AI-Remotty.app` 並打勾
3. **在選單列 Quit 一次 AI-Remotty 再重開**（TCC 權限要重啟才生效）

沒授權時：選單列會顯示「⚠️ 需要 Accessibility 權限」，且按鍵不會亂送（會擋住並開設定面板）。

## 設定

選單列圖示 →「設定…」：

- **Terminal Client**：選內建或自訂（bundle id）
- **Joy-Con**：震動開關、提醒間隔
- **Auto Approve**：自動放行（**預設關**，開啟會全部自動 allow）
- **Claude Code Hook**：一鍵安裝／移除

### Joy-Con 按鍵（預設）

左 Joy-Con 的四顆方向鍵（GCController 實際回報成 Button B/Y/X/A）：

| 實體鍵 | 動作 |
|----|------|
| 上 ↑ | Approve（放行最前一筆）|
| 下 ↓ | Reject |
| 右 → | Skip（退回 Claude Code 原生 prompt）|
| 左 ← | 開啟選定的 Terminal |
| − / Menu | 切換 Auto Approve |

### Hook 安裝做了什麼

寫一條 `PreToolUse` hook 進 `~/.claude/settings.json`，command 指向 `~/.remotty/remotty-hook.sh`。

- **動 settings.json 前會自動備份**（`settings.json.remotty-bak-<timestamp>`）
- merge-append，保留你既有的 hook（例如 Otty 的）
- 移除時只拿掉自己那條

## 安全設計

- **Auto Approve 預設關**。
- **送鍵前確認前景是目標 terminal**：activate 後若最前景 app 不是選定的 terminal（例如你切到別的 Space / 別的 app），中止送鍵並震動提示，不會把按鍵打到別處。
- **沒 Accessibility 權限時擋住**：不會靜默失敗或亂打字，改開設定面板。
- **只在有 pending 時送鍵**：queue 空時按鍵不做事；pending 過久自動清除。
- Joy-Con 沒回應時，逼近 hook timeout（預設 120s）前會自動回 `ask` —— 退回 Claude Code 原生 prompt，**不誤放行也不誤擋**。
- app 沒在跑時，hook 直接回 `ask`（照常跳原生 prompt），不會卡住 Claude Code。
- enterprise/managed 的 deny 規則永遠優先，`allow` 蓋不過（Claude Code 行為）。

## CLI

同一個 binary：

```bash
Remotty                 # menu bar app
Remotty ask             # hook client（讀 stdin hook JSON → 回 decision）
Remotty install-hook    # 裝 hook（會備份）
Remotty uninstall-hook  # 移除 hook
Remotty status          # 看 hook/socket 狀態
```

## 技術筆記

Phase 0 spike 結論在 `docs/`：

- **Joy-Con** 走 `GameController`（`GCController` 直認 Joy-Con (L)，免 IOKit）；按鍵讀 `physicalInputProfile.buttons`；震動**必須用 `hapticContinuous`**（`hapticTransient` 是 no-op）。
- **Provider** 走 `PreToolUse` 阻塞式 hook（timeout 600s 上限，stdin 帶 session_id + cwd）。

## 後續（見 SPEC.md）

Stream Deck / Xbox / DualSense / Flic / ESP32 硬體鈕 / Apple Watch / iPhone remote / Web Dashboard。
