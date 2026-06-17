import AppKit

@MainActor
final class StatusBarController {
    private let item: NSStatusItem
    private let menu = NSMenu()
    private let onShow: @MainActor () -> Void

    init(onShow: @escaping @MainActor () -> Void, onSettings: @escaping @MainActor () -> Void, onQuit: @escaping @MainActor () -> Void) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.onShow = onShow
        item.button?.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Inputo")
        item.button?.imagePosition = .imageLeading
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        menu.addItem(MenuActionItem(title: "Show Inputo", actionHandler: onShow))
        menu.addItem(MenuActionItem(title: "Settings...", actionHandler: onSettings))
        menu.addItem(.separator())
        menu.addItem(MenuActionItem(title: "Quit Inputo", actionHandler: onQuit))
    }

    @MainActor @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else {
            onShow()
            return
        }

        if event.type == .rightMouseUp {
            showMenu()
        } else {
            toggleAppVisibility()
        }
    }

    private func toggleAppVisibility() {
        if isAppShowing {
            NSApp.hide(nil)
        } else {
            onShow()
        }
    }

    private var isAppShowing: Bool {
        guard !NSApp.isHidden else { return false }

        return NSApp.windows.contains { window in
            window.isVisible && !window.isMiniaturized && window.canBecomeKey
        }
    }

    private func showMenu() {
        guard let button = item.button else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
    }
}

private final class MenuActionItem: NSMenuItem {
    private let actionHandler: @MainActor () -> Void

    init(title: String, actionHandler: @escaping @MainActor () -> Void) {
        self.actionHandler = actionHandler
        super.init(title: title, action: #selector(runAction), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @MainActor @objc private func runAction() {
        DispatchQueue.main.async { [actionHandler] in
            actionHandler()
        }
    }
}
