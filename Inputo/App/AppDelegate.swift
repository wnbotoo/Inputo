import AppKit
import InputoComposerFeature
import InputoMacPlatform
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let appState = AppState.shared
    private var panelController: FloatingPanelController?
    private var statusBarController: StatusBarController?
    private var settingsWindowController: SettingsWindowController?
    private let hotKeyManager = HotKeyManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let panelController = FloatingPanelController(appState: appState)
        self.panelController = panelController

        statusBarController = StatusBarController(
            onShow: { [weak self] in self?.showComposer() },
            onSettings: { [weak self] in self?.showSettings() },
            onQuit: { NSApp.terminate(nil) }
        )

        appState.onActivateAnchor = { [weak self] anchor in
            self?.activate(anchor: anchor)
        }

        appState.onRequestSettings = { [weak self] in
            self?.showSettings()
        }

        appState.onSettingsChanged = { [weak self] settings in
            self?.hotKeyManager.register(shortcut: settings.hotKey)
        }

        hotKeyManager.onHotKey = { [weak self] in
            self?.toggleComposer()
        }
        hotKeyManager.register(shortcut: appState.settings.hotKey)
        appState.refreshAnchors()
    }

    private func toggleComposer() {
        if panelController?.isVisible == true {
            hideComposer(reset: false)
        } else {
            showComposer()
        }
    }

    private func showComposer() {
        appState.refreshAnchors()
        panelController?.show()
    }

    private func hideComposer(reset: Bool) {
        panelController?.hide()
        if reset {
            appState.resetSession()
        }
    }

    private func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(appState: appState)
        }
        settingsWindowController?.show()
    }

    private func activate(anchor: AppAnchor) {
        if appState.activate(anchor: anchor) {
            panelController?.hide()
            appState.resetSession()
        } else {
            panelController?.show()
        }
    }
}
