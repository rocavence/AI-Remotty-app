# Claude Permission Remote 規格書 (MVP)

## 目標

建立一個 macOS Menu Bar 常駐程式，使用 Nintendo Joy-Con (L) 作為 Claude
Code / Claude CLI 的 Permission Remote。

當 AI 要求使用者確認 (Yes / No、Approve / Reject) 時：

-   Joy-Con 發出震動提醒
-   使用者按下按鍵即可批准或拒絕
-   不需要手動切換視窗
-   不依賴目前前景視窗 (Focus)

------------------------------------------------------------------------

# 系統架構

    Claude Code / CLI
            │
    Permission Event
            │
    Permission Bridge
    (Menu Bar App)
            │
    Joy-Con (Bluetooth)
            │
    Approve / Reject

Bridge 負責：

-   接收 Permission Event
-   管理 Pending Queue
-   控制 Joy-Con
-   回覆 Permission

------------------------------------------------------------------------

# Terminal Client

本工具不得綁定任何特定 Terminal。

第一次啟動時請讓使用者選擇 Terminal Client。

例如：

-   Otty
-   Terminal.app
-   iTerm2
-   Warp
-   Ghostty
-   WezTerm
-   VS Code Terminal
-   Cursor Terminal
-   Windsurf Terminal
-   其他...

介面：

    Terminal Client

    ( ) Otty
    ( ) Terminal.app
    ( ) iTerm2
    ( ) Warp
    ( ) Ghostty
    ( ) WezTerm
    ( ) VS Code
    ( ) Cursor
    ( ) Other...

若選擇 Other，可自行指定：

-   Bundle Identifier
-   App Name
-   AppleScript Activate 指令

此設定可隨時修改。

------------------------------------------------------------------------

# Permission Provider

Bridge 不應假設 Permission 來源。

設計 Provider 抽象層，例如：

-   Claude Code
-   Claude CLI
-   Codex CLI
-   Gemini CLI
-   MCP
-   Custom WebSocket
-   HTTP API

未來可新增 Provider。

------------------------------------------------------------------------

# Joy-Con

預設按鍵：

-   A：Approve
-   B：Reject
-   X：Skip
-   Home：打開 Terminal Client
-   +：切換 Auto Approve（選用）

按鍵可重新設定。

------------------------------------------------------------------------

# 震動

收到新的 Permission：

-   短震兩下

若超過 20 秒仍未處理：

-   再提醒一次

完成：

-   短震一下

避免持續震動。

------------------------------------------------------------------------

# Menu Bar

狀態：

-   🟢 Idle
-   🔴 Waiting (1)
-   🔴 Waiting (N)

下拉內容：

-   Pending 數量
-   Command
-   Approve
-   Reject
-   Open Terminal

------------------------------------------------------------------------

# Queue

支援多筆 Pending。

每筆：

-   id
-   title
-   command
-   timestamp

依序處理。

------------------------------------------------------------------------

# Terminal 整合策略

優先順序：

1.  Provider API
2.  MCP
3.  WebSocket
4.  CLI IPC
5.  AppleScript + 模擬輸入（最後備援）

不得直接依賴目前 Focus。

只有在沒有任何 API 可用時，才：

1.  Activate Terminal
2.  輸入 approve/reject
3.  Return
4.  可選擇切回原本 App

------------------------------------------------------------------------

# 設定

-   Terminal Client
-   Joy-Con Mapping
-   Rumble 開關
-   Auto Approve
-   Reminder Interval
-   啟動時自動執行

------------------------------------------------------------------------

# MVP

-   Menu Bar App
-   Joy-Con 配對
-   Joy-Con 按鍵事件
-   Joy-Con 震動
-   Terminal Client 選擇
-   Permission Queue
-   Provider Interface
-   Claude Code Provider
-   API 優先，AppleScript 備援

------------------------------------------------------------------------

# 後續版本

-   Stream Deck
-   Xbox Controller
-   DualSense
-   Flic Button
-   ESP32 Hardware Button
-   OLED 顯示器
-   Apple Watch
-   iPhone Remote
-   Web Dashboard

------------------------------------------------------------------------

# 補充：Terminal Adapter 介面（使用者追加）

Terminal 必須可由使用者選擇，不得寫死任何一家（含 Otty）。
定義 Adapter 介面（原始概念以 TypeScript 表達，實作時翻成 Swift protocol）：

    interface TerminalAdapter {
      name: string
      connect(): Promise<void>
      approve(requestId: string): Promise<void>
      reject(requestId: string): Promise<void>
      activate(): Promise<void>
      getPendingRequests(): Promise<PermissionRequest[]>
    }

Swift 對應（草案，實作時可調）：

    protocol TerminalAdapter {
      var name: String { get }
      func connect() async throws
      func approve(requestId: String) async throws
      func reject(requestId: String) async throws
      func activate() async throws
      func pendingRequests() async throws -> [PermissionRequest]
    }

- 內建 adapter：Terminal.app / iTerm2 / Warp / Ghostty / WezTerm / VS Code / Cursor / Otty / Other(自訂 bundle id + activate 指令)
- Adapter 只負責「找到並喚起 terminal、必要時打字」；Permission 語意層走 Provider，兩層別混。
