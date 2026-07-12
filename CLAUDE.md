# AI-Remotty-app（Claude Permission Remote）

macOS menubar app：用 Nintendo Joy-Con (L) 當 Claude Code permission 遙控器——AI 要確認時 Joy-Con 震動、按 A 批准 B 拒絕，免切視窗。

## 文件

- `SPEC.md` — 規格書（含結尾 TerminalAdapter 補充章，必讀）
- `PLAN.md` — 分 Phase 實作計畫＋驗收條件，照順序做
- `docs/` — spike 筆記放這

## 原則

- Swift 原生（SPM），scaffold 抄 `~/Code/Configgy-app` 的結構與簽章流程
- 三個抽象層別混：**Provider**（permission 事件來源）／**Queue**（pending 管理）／**TerminalAdapter**（喚起 terminal、備援打字）
- API 優先、AppleScript 模擬輸入是最後備援；不依賴前景 focus
- 不寫死任何 terminal，一律走 TerminalAdapter + 使用者選擇
- 動 `~/.claude/settings.json` 前先備份＋徵求同意
- Auto Approve 預設關

## 目前狀態

**MVP 實作完成（2026-07-13）**。Phase 0–5 打通並驗證：build+簽章過、IPC round-trip 實測、hook installer 保留既有 hook+備份驗過。
- 建置：`./Scripts/build-app.sh` → `build/AI-Remotty.app`
- CLI：`Remotty ask|install-hook|uninstall-hook|status`
- 程式在 `Sources/Remotty/`（12 檔）
- ⚠️ 待人工實機：① 實體按 Joy-Con A → 真的放行某筆 ② 真開 Claude Code session 跑完整 PreToolUse 端到端
- backlog 見 PLAN.md（Launch at Login、按鍵 remap UI、GitHub repo、AppIcon/dmg）
