# Spike: Provider（Phase 0）— ✅ 通過，MVP 走 PreToolUse 阻塞式

日期 2026-07-13。來源：claude-code-guide（官方文件）。**實作前仍要對當前 CC 版本實測一次 JSON 欄位**（下面標 ⚠️ 者）。

## 結論：MVP Provider = Claude Code `PreToolUse` hook，阻塞等 Joy-Con，回 permissionDecision

不需要 AppleScript 模擬鍵入當主線——hook 直接回決策，最乾淨。備援仍保留給無 hook 的 provider。

## 為何選 PreToolUse（而非 PermissionRequest / Notification）
- **可回決策**：stdout 送
  ```json
  {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}
  ```
  值 = `allow` / `deny` / `ask`（`allow` 跳過互動 prompt；`deny` 擋下並回原因；`ask` 走原本 prompt）。
- **會阻塞**：Claude Code 等 hook script 結束才繼續。**command hook 預設 timeout 600 秒**（可用 hook 的 `timeout` 欄位改，單位秒）。→ 等 Joy-Con 按鍵 60s 綽綽有餘。
- **互動+非互動都觸發**：`PreToolUse` 在 `-p` headless 也會 fire；`PermissionRequest` 在 headless 不 fire。
- ⚠️ timeout 若到，該 tool call 被擋+顯示 error，無自動重試 → Joy-Con 沒回應時要有 fallback（見下）。

## stdin payload（路由多 session 用）
```json
{
  "session_id": "…",              // 哪個 session
  "cwd": "/path/to/project",      // 哪個工作目錄 → 對回哪個 terminal 視窗
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": { "command": "…" }
}
```
- queue 每筆存 session_id + cwd + tool_name + tool_input(command) + timestamp
- 多 session 併發：靠 session_id 區分；顯示用 cwd basename

## 架構（實作用）
```
Claude Code ──PreToolUse hook──▶ remotty-hook.sh
                                      │ 讀 stdin JSON
                                      │ POST/寫 給 app（本機 Unix socket 或 loopback HTTP）
                                      │ 阻塞等 app 回 allow/deny/ask（long-poll 或 socket read）
                                      ▼
                              app: 入 queue → Joy-Con 震 → 使用者按 A/B/X
                                      │
                                      ▼ 回決策
                                stdout JSON → Claude Code 放行/擋
```
- **hook script**：極輕，只做 stdin→轉交 app→等回覆→印 JSON。用本機 Unix domain socket（`~/.remotty.sock`）最省事，免開埠。
- **app 端 server**：menubar app 內跑 socket listener；收到 request 建 queue 項、觸發 Joy-Con；Joy-Con 按鍵 → 對應 request 回覆 → 解除 hook 阻塞。
- **fallback（Joy-Con 沒回/timeout 逼近）**：hook 逾時前回 `"ask"`（退回原本互動 prompt，不誤放行也不誤擋）——比硬 deny 安全。app 可設「X 秒沒按就回 ask」。

## hook 安裝器（Phase 3）
- 寫進 `~/.claude/settings.json` 的 `hooks.PreToolUse`：matcher 可用 `"*"`（全 tool）或指定 `Bash` 等。
  ```json
  {"hooks":{"PreToolUse":[{"matcher":"*","hooks":[{"type":"command","command":"~/.remotty/remotty-hook.sh","timeout":120}]}]}}
  ```
- ⚠️ **動 settings.json 前先備份 + 徵求同意**（既有已有 Otty 的 PermissionRequest hook，別覆蓋，用 merge append）。
- 可 per-project（`.claude/settings.json`）或 global（`~/.claude/settings.json`）。

## ⚠️ 實作前要驗的點（別全信文件）
1. `permissionDecision` 三值行為、`allow` 是否真跳過 prompt → 真開 session 觸發一次確認。
2. `timeout` 欄位單位/上限、逾時實際行為。
3. `PermissionRequest` 的 `decision.behavior` 形狀（文件說可回但和 Otty 用法不同）——MVP 用 PreToolUse 就先不碰。
4. enterprise/managed deny 規則會蓋過 `allow`（政策優先）——個人機無影響。

## 未來 Provider（抽象層預留）
Codex CLI / Gemini CLI / MCP / WebSocket / HTTP —— 各自實作 `PermissionProvider`，共用 queue + Joy-Con + TerminalAdapter。
