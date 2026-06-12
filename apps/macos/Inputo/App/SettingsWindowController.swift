import AppKit
import InputoComposerFeature
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let window: NSWindow

    init(appState: AppState) {
        let preferredSize = SettingsView.preferredSize
        let rootView = SettingsView(appState: appState)
            .frame(width: preferredSize.width, height: preferredSize.height)
        let hostingController = NSHostingController(rootView: rootView)
        if #available(macOS 13.0, *) {
            hostingController.sizingOptions = []
        }
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: preferredSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Inputo Settings"
        window.contentViewController = hostingController
        window.contentMinSize = preferredSize
        window.contentMaxSize = preferredSize
        window.center()
        window.isReleasedWhenClosed = false
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
