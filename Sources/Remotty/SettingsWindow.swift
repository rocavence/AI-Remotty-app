import AppKit
import SwiftUI

/// 設定視窗（SwiftUI 內容 host 進 NSWindow）。
final class SettingsWindowController {
    private var window: NSWindow?

    func showAndFocus() {
        if window == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 560),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = "Remotty 設定"
            w.center()
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: SettingsView())
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @State private var terminalId = AppSettings.shared.terminalId
    @State private var customBundleId = AppSettings.shared.customBundleId
    @State private var customAppName = AppSettings.shared.customAppName
    @State private var rumble = AppSettings.shared.rumbleEnabled
    @State private var autoApprove = AppSettings.shared.autoApprove
    @State private var reminder = AppSettings.shared.reminderInterval
    @State private var hookInstalled = HookInstaller.isInstalled()
    @State private var status = ""

    private let terminals = Terminals.builtins

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header("Terminal Client")
                Picker("", selection: $terminalId) {
                    ForEach(terminals, id: \.id) { t in
                        Text(t.name + (t.isInstalled() ? "" : " （未安裝）")).tag(t.id)
                    }
                    Text("Other…").tag("custom")
                }
                .labelsHidden().pickerStyle(.radioGroup)
                .onChange(of: terminalId) { _, v in AppSettings.shared.terminalId = v }

                if terminalId == "custom" {
                    TextField("App 名稱", text: $customAppName)
                        .onChange(of: customAppName) { _, v in AppSettings.shared.customAppName = v }
                    TextField("Bundle Identifier", text: $customBundleId)
                        .onChange(of: customBundleId) { _, v in AppSettings.shared.customBundleId = v }
                }

                Divider()
                header("Joy-Con")
                Toggle("震動提醒", isOn: $rumble)
                    .onChange(of: rumble) { _, v in AppSettings.shared.rumbleEnabled = v }
                VStack(alignment: .leading, spacing: 3) {
                    Text("面板鍵：右 →=Enter（確認）· 左 ←=Esc · 上 ↑=上一個 tab · 下 ↓=下一個 tab")
                    Text("蘑菇頭=方向鍵（垂直拿，選項導航）· −=打「go on」+Enter")
                    Text("⚠️ 單 Joy-Con 肩鍵 L/ZL 與 □ 不觸發；開 Terminal / Auto Approve 走選單")
                        .foregroundStyle(.orange)
                }
                .font(.caption).foregroundStyle(.secondary)

                HStack {
                    Text("提醒間隔")
                    Slider(value: $reminder, in: 10...60, step: 5)
                        .onChange(of: reminder) { _, v in AppSettings.shared.reminderInterval = v }
                    Text("\(Int(reminder))s").monospacedDigit()
                }

                Divider()
                header("行為")
                Toggle("Auto Approve（自動放行，預設關）", isOn: $autoApprove)
                    .onChange(of: autoApprove) { _, v in AppSettings.shared.autoApprove = v }
                if autoApprove {
                    Text("⚠️ 所有請求會自動放行，不再詢問。")
                        .font(.caption).foregroundStyle(.orange)
                }

                Divider()
                header("Claude Code Hook")
                Text("安裝後 Claude Code 的每次工具確認都會轉到 Joy-Con。會先備份 ~/.claude/settings.json。")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    if hookInstalled {
                        Label("已安裝", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        Button("移除 Hook") { uninstall() }
                    } else {
                        Label("未安裝", systemImage: "circle").foregroundStyle(.secondary)
                        Button("安裝 Hook") { install() }
                    }
                }
                if !status.isEmpty {
                    Text(status).font(.caption).foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .frame(width: 460, height: 560)
    }

    private func header(_ t: String) -> some View {
        Text(t).font(.headline)
    }

    private func install() {
        let bin = Bundle.main.executablePath ?? CommandLine.arguments[0]
        do {
            let bak = try HookInstaller.install(binaryPath: bin)
            hookInstalled = true
            status = bak != nil ? "已安裝，備份：\((bak! as NSString).lastPathComponent)" : "已安裝。"
        } catch {
            status = "安裝失敗：\(error.localizedDescription)"
        }
    }
    private func uninstall() {
        do {
            _ = try HookInstaller.uninstall()
            hookInstalled = false
            status = "已移除。"
        } catch {
            status = "移除失敗：\(error.localizedDescription)"
        }
    }
}
