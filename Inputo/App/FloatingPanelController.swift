import AppKit
import InputoComposerFeature
import SwiftUI

@MainActor
final class FloatingPanelController: NSObject, NSWindowDelegate {
    private let appState: AppState
    private let panel: NSPanel

    var isVisible: Bool {
        panel.isVisible
    }

    init(appState: AppState) {
        self.appState = appState

        let contentView = ComposerView(appState: appState)
        let hostingView = NSHostingView(rootView: contentView)

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 620),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
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
        let width = min(820, visibleFrame.width - 64)
        let height = min(620, visibleFrame.height - 96)
        let x = visibleFrame.midX - width / 2
        let y = visibleFrame.minY + 72
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }
}
