import AppKit

@MainActor
final class StatusBarController {
    private let item: NSStatusItem

    init(onShow: @escaping @MainActor () -> Void, onSettings: @escaping @MainActor () -> Void, onQuit: @escaping @MainActor () -> Void) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Inputo"
        item.button?.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Inputo")
        item.button?.imagePosition = .imageLeading

        let menu = NSMenu()
        menu.addItem(MenuActionItem(title: "Show Inputo", actionHandler: onShow))
        menu.addItem(MenuActionItem(title: "Settings...", actionHandler: onSettings))
        menu.addItem(.separator())
        menu.addItem(MenuActionItem(title: "Quit Inputo", actionHandler: onQuit))
        item.menu = menu
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
