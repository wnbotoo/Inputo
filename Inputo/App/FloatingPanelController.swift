import AppKit
import Carbon.HIToolbox
import InputoComposerFeature
import SwiftUI

@MainActor
final class FloatingPanelController: NSObject, NSWindowDelegate {
    private let appState: AppState
    private let panel: InputoFloatingPanel
    private var keyDownMonitor: Any?

    var onEscape: (() -> Void)?

    var isVisible: Bool {
        panel.isVisible
    }

    init(appState: AppState) {
        self.appState = appState

        let contentView = ComposerView(appState: appState)
        let hostingView = NSHostingView(rootView: contentView)

        panel = InputoFloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 320),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.ignoresNativeCancelOperation = InputoWebComposerAssets.areBundled
        panel.contentView = hostingView
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true

        super.init()
        panel.delegate = self
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isKeyWindow, event.keyCode == UInt16(kVK_Escape) else {
                return event
            }
            guard !InputoWebComposerAssets.areBundled else {
                return event
            }
            self.onEscape?()
            return nil
    }
}

private final class InputoFloatingPanel: NSPanel {
    var ignoresNativeCancelOperation = false

    override func cancelOperation(_ sender: Any?) {
        guard !ignoresNativeCancelOperation else { return }
        super.cancelOperation(sender)
    }
}

    deinit {
        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
        }
    }

    func show() {
        positionPanel()
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        NotificationCenter.default.post(name: .inputoFocusComposer, object: nil)
    }

    func hide() {
        panel.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        panel.orderOut(nil)
    }

    private func positionPanel() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let width = min(860, visibleFrame.width - 64)
        let targetHeight = visibleFrame.height * 0.34
        let maxHeight = visibleFrame.height * 0.5
        let height = min(max(280, targetHeight), maxHeight)
        let bottomMargin = max(28, min(56, visibleFrame.height * 0.05))
        let x = visibleFrame.midX - width / 2
        let y = visibleFrame.minY + bottomMargin
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }

}
