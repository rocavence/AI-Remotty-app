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

規劃完成、未動工。從 PLAN.md Phase 0（spike）開始。
