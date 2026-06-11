import AppKit
import InputoComposerFeature
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let window: NSWindow

    init(appState: AppState) {
        let hostingView = NSHostingView(rootView: SettingsView(appState: appState))
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 620),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Inputo Settings"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
