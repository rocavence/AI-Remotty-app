import AppKit

/// 螢幕中央短暫彈出的反饋 HUD（按鍵後給視覺回饋）。
final class HUD {
    private var window: NSWindow?
    private var hideTimer: Timer?

    func show(text: String, ok: Bool) {
        let panel = window ?? makeWindow()
        window = panel

        guard let label = panel.contentView?.subviews.compactMap({ $0 as? NSTextField }).first else { return }
        label.stringValue = text
        label.textColor = .white

        if let bg = panel.contentView as? NSVisualEffectView {
            bg.material = ok ? .hudWindow : .hudWindow
        }

        // 置中於主螢幕
        if let screen = NSScreen.main {
            let size = NSSize(width: 260, height: 90)
            let origin = NSPoint(x: screen.frame.midX - size.width / 2,
                                 y: screen.frame.midY - size.height / 2)
            panel.setFrame(NSRect(origin: origin, size: size), display: true)
        }

        panel.alphaValue = 1
        panel.orderFrontRegardless()

        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 0.9, repeats: false) { [weak panel] _ in
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.35
                panel?.animator().alphaValue = 0
            } completionHandler: { panel?.orderOut(nil) }
        }
    }

    private func makeWindow() -> NSWindow {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 260, height: 90),
                         styleMask: [.borderless], backing: .buffered, defer: false)
        w.level = .floating
        w.isOpaque = false
        w.backgroundColor = .clear
        w.ignoresMouseEvents = true
        w.collectionBehavior = [.canJoinAllSpaces, .transient]

        let bg = NSVisualEffectView(frame: w.contentRect(forFrameRect: w.frame))
        bg.material = .hudWindow
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 16
        bg.layer?.masksToBounds = true
        bg.autoresizingMask = [.width, .height]

        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.alignment = .center
        label.textColor = .white
        label.frame = bg.bounds
        label.autoresizingMask = [.width, .height]
        label.cell?.usesSingleLineMode = true
        label.cell?.alignment = .center
        // 垂直置中：用容器
        label.frame = NSRect(x: 0, y: 30, width: 260, height: 30)
        bg.addSubview(label)

        w.contentView = bg
        return w
    }
}
