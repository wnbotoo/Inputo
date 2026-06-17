import AppKit
import SwiftUI

public struct ComposerView: View {
    @ObservedObject public var appState: AppState
    @FocusState private var isCommandFocused: Bool

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .ignoresSafeArea()

            VStack(spacing: 10) {
                if let providerSetupMessage = appState.providerSetupMessage {
                    ProviderSetupBanner(appState: appState, message: providerSetupMessage)
                }
                AnchorBarView(appState: appState)
                nativeComposer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 16)
            .ignoresSafeArea(.container, edges: .top)
        }
    }

    private var nativeComposer: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $appState.commandText)
                .focused($isCommandFocused)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.primary)
                .scrollContentBackground(.hidden)
                .scrollIndicators(isComposerAtMaxHeight ? .visible : .hidden)
                .background(.clear)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 48)
                .accessibilityLabel("Command input")
            if appState.commandText.isEmpty {
                Text("Ask anything")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                    .allowsHitTesting(false)
            }

            commandToolbar
        }
        .frame(height: composerHeight)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.82), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.62), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.055), radius: 10, x: 0, y: 6)
        .shadow(color: Color.black.opacity(0.035), radius: 2, x: 0, y: 1)
        .onAppear(perform: focusCommand)
        .onReceive(NotificationCenter.default.publisher(for: .inputoFocusComposer)) { _ in
            focusCommand()
        }
    }

    @ViewBuilder
    private var commandToolbar: some View {
        HStack(spacing: 10) {
            toolbarButton(systemName: "plus", help: "New command") {
                appState.commandText = ""
                appState.resetSession()
                focusCommand()
            }

            toolbarButton(systemName: "globe", help: "Refresh app anchors") {
                appState.refreshAnchors()
            }

            toolbarButton(systemName: "slider.horizontal.3", help: "Settings") {
                appState.openSettings()
            }

            Text("Auto")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.70))
                .lineLimit(1)
                .fixedSize()

            statusText
                .frame(maxWidth: 180, alignment: .leading)

            Spacer(minLength: 8)

            if appState.isGenerating {
                Button {
                    appState.cancelNativeCommand()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .foregroundStyle(.primary.opacity(0.74))
                        .background(Color.primary.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Cancel")
            }

            Button {
                appState.submitCommandInput()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 26, height: 26)
                    .foregroundStyle(canSubmit ? Color.white : Color.primary.opacity(0.34))
                    .background(canSubmit ? Color.accentColor : Color.primary.opacity(0.10), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
            .keyboardShortcut(.return, modifiers: [.command])
            .help("Run command")
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    @ViewBuilder
    private var statusText: some View {
        if let errorMessage = appState.errorMessage {
            Text(errorMessage)
                .font(.caption2)
                .foregroundStyle(.red)
                .lineLimit(1)
        } else if let statusMessage = appState.statusMessage {
            Text(statusMessage)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } else if appState.isGenerating {
            Text("Generating...")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } else {
            Text("")
                .font(.caption2)
                .lineLimit(1)
        }
    }

    private var composerHeight: CGFloat {
        let lineCount = max(1, appState.commandText.split(separator: "\n", omittingEmptySubsequences: false).count)
        let textHeight = CGFloat(lineCount) * 18
        let chromeHeight: CGFloat = 58
        return min(max(82, textHeight + chromeHeight), maxComposerHeight)
    }

    private var maxComposerHeight: CGFloat {
        160
    }

    private var isComposerAtMaxHeight: Bool {
        composerHeight >= maxComposerHeight
    }

    private var canSubmit: Bool {
        !appState.commandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !appState.isGenerating
    }

    private func toolbarButton(systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .regular))
                .frame(width: 20, height: 20)
                .foregroundStyle(.primary.opacity(0.70))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func focusCommand() {
        DispatchQueue.main.async {
            isCommandFocused = true
        }
    }
}

private struct ProviderSetupBanner: View {
    @ObservedObject var appState: AppState
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Provider setup needed")
                    .font(.caption.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                appState.openSettings()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .controlSize(.small)
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
        }
    }
}

private struct AnchorBarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(spacing: 8) {
            if appState.anchors.isEmpty {
                Text("No anchors")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.regularMaterial, in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.48), lineWidth: 1)
                    }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(appState.anchors) { anchor in
                            Button {
                                appState.requestActivate(anchor: anchor)
                            } label: {
                                HStack(spacing: 7) {
                                    if let icon = anchor.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 16, height: 16)
                                    } else {
                                        Image(systemName: "app")
                                    }
                                    Text(anchor.appName)
                                        .lineLimit(1)
                                }
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                            }
                            .buttonStyle(.plain)
                            .background(.regularMaterial, in: Capsule())
                            .overlay {
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.48), lineWidth: 1)
                            }
                            .fixedSize(horizontal: true, vertical: false)
                            .help("Switch to \(anchor.appName)")
                        }
                    }
                }
                .frame(height: 34)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                appState.refreshAnchors()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .background(.regularMaterial, in: Circle())
            .overlay {
                Circle()
                    .strokeBorder(Color.white.opacity(0.48), lineWidth: 1)
            }
            .help("Refresh app anchors")
        }
        .frame(height: 36)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
