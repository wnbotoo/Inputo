@preconcurrency import AppKit
@preconcurrency import ObjectiveC
@preconcurrency import Foundation
import SwiftUI
@preconcurrency import WebKit

public struct InputoWebComposerView: NSViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(appState: appState)
    }

    public func makeNSView(context: Context) -> WKWebView {
        let userContentController = WKUserContentController()
        userContentController.add(
            InputoWeakScriptMessageHandler(target: context.coordinator),
            name: Coordinator.messageHandlerName
        )
        userContentController.addUserScript(
            WKUserScript(
                source: initialThemeScript(for: colorScheme),
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        context.coordinator.installRemoteContentBlocker(on: userContentController)

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController
        configuration.websiteDataStore = .nonPersistent()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = InputoTransparentWKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsMagnification = false
        configureTransparentBackground(for: webView)

        context.coordinator.attach(webView)
        context.coordinator.applyColorScheme(colorScheme)
        if let indexURL = InputoWebComposerAssets.indexURL,
           let readAccessURL = InputoWebComposerAssets.readAccessURL {
            webView.loadFileURL(indexURL, allowingReadAccessTo: readAccessURL)
        }
        return webView
    }

    public func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.attach(webView)
        configureTransparentBackground(for: webView)
        context.coordinator.applyColorScheme(colorScheme)
    }

    public static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: Coordinator.messageHandlerName)
        coordinator.detach(webView)
    }
}

extension InputoWebComposerView {
    @MainActor
    public final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        fileprivate static let messageHandlerName = "inputoNative"

        private let appState: AppState
        private var bridgeHost: InputoNativeBridgeHost?
        private weak var webView: WKWebView?
        private var activeThemeName: String?
        private var isDocumentReady = false
        private var pendingBridgeBase64: [String] = []
        nonisolated(unsafe) private var focusObserver: NSObjectProtocol?
        nonisolated(unsafe) private var previewObserver: NSObjectProtocol?

        init(appState: AppState) {
            self.appState = appState
            super.init()

            let eventEmitter = InputoBridgeEventEmitter { [weak self] data in
                self?.sendBridgeDataToWeb(data)
            }
            let dispatcher = InputoNativeBridgeDispatcher(
                appState: appState,
                eventEmitter: eventEmitter
            )
            bridgeHost = InputoNativeBridgeHost(dispatcher: dispatcher)
            focusObserver = NotificationCenter.default.addObserver(
                forName: .inputoFocusComposer,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.focusComposer()
                }
            }
            previewObserver = NotificationCenter.default.addObserver(
                forName: .inputoPreviewBridgeEvent,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let data = notification.object as? Data else { return }
                Task { @MainActor in
                    self?.sendBridgeDataToWeb(data)
                }
            }
        }

        deinit {
            if let focusObserver {
                NotificationCenter.default.removeObserver(focusObserver)
            }
            if let previewObserver {
                NotificationCenter.default.removeObserver(previewObserver)
            }
        }

        fileprivate func attach(_ webView: WKWebView) {
            self.webView = webView
        }

        fileprivate func detach(_ webView: WKWebView) {
            if self.webView === webView {
                self.webView = nil
            }
        }

        fileprivate func installRemoteContentBlocker(on userContentController: WKUserContentController) {
            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "InputoBlockRemoteWebContent",
                encodedContentRuleList: InputoWebComposerAssets.remoteContentBlockRuleList
            ) { contentRuleList, _ in
                guard let contentRuleList else { return }
                Task { @MainActor in
                    userContentController.add(contentRuleList)
                }
            }
        }

        fileprivate func applyColorScheme(_ colorScheme: ColorScheme) {
            let themeName = Self.themeName(for: colorScheme)
            webView?.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
            guard activeThemeName != themeName else { return }
            activeThemeName = themeName
            evaluate("window.InputoNativeThemeSet && window.InputoNativeThemeSet(\"\(themeName)\");")
        }

        fileprivate func receiveBridgeMessage(_ json: String?) {
            guard let json, let bridgeHost else { return }
            Task { @MainActor in
                let response = await bridgeHost.receiveBridgeMessage(json)
                self.sendBridgeStringToWeb(response)
            }
        }

        public func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.targetFrame?.isMainFrame == false {
                guard isAllowedPreviewFrameNavigationURL(navigationAction.request.url) else {
                    decisionHandler(.cancel)
                    return
                }
                decisionHandler(.allow)
                return
            }
            guard isAllowedNavigationURL(navigationAction.request.url) else {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        public func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            nil
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            configureTransparentBackground(for: webView)
            applyColorScheme(ColorScheme.theme(named: activeThemeName))
            isDocumentReady = true
            flushPendingBridgeMessages()
        }

        private func isAllowedNavigationURL(_ url: URL?) -> Bool {
            guard let url else { return false }
            guard url.isFileURL else { return false }
            guard let readAccessURL = InputoWebComposerAssets.readAccessURL else { return false }

            let allowedDirectory = readAccessURL.standardizedFileURL.path
            let requestedPath = url.standardizedFileURL.path
            return requestedPath == allowedDirectory || requestedPath.hasPrefix(allowedDirectory + "/")
        }

        private func isAllowedPreviewFrameNavigationURL(_ url: URL?) -> Bool {
            guard let url else { return true }
            if url.scheme == "about" || url.scheme == "data" || url.scheme == "blob" {
                return true
            }
            return isAllowedNavigationURL(url)
        }

        private func focusComposer() {
            evaluate("window.InputoComposerFocus && window.InputoComposerFocus();")
        }

        private func sendBridgeDataToWeb(_ data: Data) {
            sendBridgeBase64ToWeb(data.base64EncodedString())
        }

        private func sendBridgeStringToWeb(_ json: String) {
            sendBridgeDataToWeb(Data(json.utf8))
        }

        private func sendBridgeBase64ToWeb(_ base64: String) {
            guard isDocumentReady else {
                pendingBridgeBase64.append(base64)
                return
            }
            evaluate("window.InputoNativeBridgeReceiveBase64 && window.InputoNativeBridgeReceiveBase64(\"\(base64)\");")
        }

        private func flushPendingBridgeMessages() {
            guard !pendingBridgeBase64.isEmpty else { return }
            let messages = pendingBridgeBase64
            pendingBridgeBase64.removeAll()
            for base64 in messages {
                sendBridgeBase64ToWeb(base64)
            }
        }

        private func evaluate(_ javaScript: String) {
            webView?.evaluateJavaScript(javaScript)
        }

        private static func themeName(for colorScheme: ColorScheme) -> String {
            colorScheme == .dark ? "dark" : "light"
        }
    }
}

private func initialThemeScript(for colorScheme: ColorScheme) -> String {
    let themeName = colorScheme == .dark ? "dark" : "light"
    return """
    window.InputoInitialTheme = "\(themeName)";
    document.documentElement.dataset.theme = "\(themeName)";
    document.documentElement.style.background = "transparent";
    document.addEventListener("DOMContentLoaded", function () {
      document.documentElement.style.background = "transparent";
      document.body.style.background = "transparent";
    });
    """
}

@MainActor
private func configureTransparentBackground(for webView: WKWebView) {
    webView.underPageBackgroundColor = .clear
    disableWebKitBackgroundDrawing(for: webView)
    setWebKitBackgroundColor(.clear, for: webView)
    webView.wantsLayer = true
    webView.layer?.backgroundColor = NSColor.clear.cgColor
    clearViewBackgrounds(in: webView)
}

@MainActor
private func clearViewBackgrounds(in view: NSView) {
    view.wantsLayer = true
    view.layer?.backgroundColor = NSColor.clear.cgColor

    if let scrollView = view as? NSScrollView {
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.contentView.drawsBackground = false
        scrollView.contentView.backgroundColor = .clear
    }

    for subview in view.subviews {
        clearViewBackgrounds(in: subview)
    }
}

private func disableWebKitBackgroundDrawing(for webView: WKWebView) {
    let selector = Selector(("_setDrawsBackground:"))
    guard let method = class_getInstanceMethod(type(of: webView), selector) else {
        return
    }
    typealias Setter = @convention(c) (AnyObject, Selector, Bool) -> Void
    let setter = unsafeBitCast(method_getImplementation(method), to: Setter.self)
    setter(webView, selector, false)
}

private func setWebKitBackgroundColor(_ color: NSColor, for webView: WKWebView) {
    let selector = NSSelectorFromString("setBackgroundColor:")
    guard webView.responds(to: selector) else { return }
    webView.perform(selector, with: color)
}

private final class InputoTransparentWKWebView: WKWebView {
    override var isOpaque: Bool {
        false
    }
}

private extension ColorScheme {
    static func theme(named themeName: String?) -> ColorScheme {
        themeName == "dark" ? .dark : .light
    }
}

private final class InputoWeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: InputoWebComposerView.Coordinator?

    init(target: InputoWebComposerView.Coordinator) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame else { return }
        let json = message.body as? String
        Task { @MainActor [weak target] in
            target?.receiveBridgeMessage(json)
        }
    }
}
