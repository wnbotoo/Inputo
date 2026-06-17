import AppKit
import Carbon.HIToolbox
import InputoComposerFeature
import SwiftUI

@MainActor
final class FloatingPanelController: NSObject, NSWindowDelegate {
    private let panel: InputoFloatingPanel
    private let appState: AppState
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
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 238),
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
        panel.hasShadow = false

        super.init()

        panel.delegate = self
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isKeyWindow, event.keyCode == UInt16(kVK_Escape) else {
                return event
            }
            if self.panel.hasMarkedTextInFirstResponder {
                self.panel.deferCancelOperationForCurrentInputMethodEvent()
                return event
            }
            self.onEscape?()
            return nil
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
        let width = min(900, visibleFrame.width - 64)
        let preferredHeight: CGFloat = appState.providerSetupMessage == nil ? 238 : 302
        let height = min(preferredHeight, visibleFrame.height - 64)
        let bottomMargin = max(28, min(56, visibleFrame.height * 0.05))
        let x = visibleFrame.midX - width / 2
        let y = visibleFrame.minY + bottomMargin
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }
}

@MainActor
final class PreviewWindowController: NSObject, NSWindowDelegate {
    private let panel: InputoFloatingPanel
    private var previewObserver: NSObjectProtocol?

    init(appState: AppState) {
        let contentView = InputoWebComposerView(appState: appState)
        let hostingView = NSHostingView(rootView: contentView)

        panel = InputoFloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 380),
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
        previewObserver = NotificationCenter.default.addObserver(
            forName: .inputoPreviewBridgeEvent,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.show()
            }
        }
    }

    deinit {
        if let previewObserver {
            NotificationCenter.default.removeObserver(previewObserver)
        }
    }

    func show() {
        positionPanel()
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func positionPanel() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let width = min(860, visibleFrame.width - 64)
        let height = min(max(320, visibleFrame.height * 0.38), visibleFrame.height * 0.52)
        let bottomMargin = max(252, min(320, visibleFrame.height * 0.28))
        let x = visibleFrame.midX - width / 2
        let y = min(visibleFrame.maxY - height - 32, visibleFrame.minY + bottomMargin)
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }
}

private final class InputoFloatingPanel: NSPanel {
    private var ignoresCurrentInputMethodCancelOperation = false

    override func cancelOperation(_ sender: Any?) {
        if ignoresCurrentInputMethodCancelOperation {
            ignoresCurrentInputMethodCancelOperation = false
            return
        }
        guard !hasMarkedTextInFirstResponder else {
            return
        }
        orderOut(nil)
    }

    func deferCancelOperationForCurrentInputMethodEvent() {
        ignoresCurrentInputMethodCancelOperation = true
        DispatchQueue.main.async { [weak self] in
            self?.ignoresCurrentInputMethodCancelOperation = false
        }
    }

    var hasMarkedTextInFirstResponder: Bool {
        firstResponder.inputoHasMarkedText
    }
}

private extension Optional where Wrapped == NSResponder {
    var inputoHasMarkedText: Bool {
        guard let responder = self else {
            return false
        }
        if let textInputClient = responder as? NSTextInputClient, textInputClient.hasMarkedText() {
            return true
        }
        guard let view = responder as? NSView else {
            return false
        }
        guard let fieldEditor = view.window?.fieldEditor(false, for: view) as? NSTextInputClient else {
            return false
        }
        return fieldEditor.hasMarkedText()
    }
}
