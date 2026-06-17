import InputoMacPlatform
import SwiftUI

public struct ComposerView: View {
    @ObservedObject public var appState: AppState
    @FocusState private var isCommandFocused: Bool

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        ZStack(alignment: .top) {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 6) {
                header
                if let providerSetupMessage = appState.providerSetupMessage {
                    ProviderSetupBanner(appState: appState, message: providerSetupMessage)
                }
                AnchorBarView(appState: appState)
                nativeComposer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .ignoresSafeArea(.container, edges: .top)
        }
    }

    private var nativeComposer: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $appState.commandText)
                    .focused($isCommandFocused)
                    .font(.system(size: 15))
                    .scrollContentBackground(.hidden)
                    .background(.clear)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                    .accessibilityLabel("Command input")
                if appState.commandText.isEmpty {
                    Text("/polish selected text")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 96)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.quaternary)
            )

            HStack(spacing: 8) {
                statusText
                Spacer(minLength: 8)
                Button {
                    appState.commandText = ""
                    appState.resetSession()
                    focusCommand()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help("Clear")

                if appState.isGenerating {
                    Button {
                        appState.cancelNativeCommand()
                    } label: {
                        Image(systemName: "stop.fill")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .help("Cancel")
                }

                Button {
                    appState.submitCommandInput()
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(appState.commandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appState.isGenerating)
                .keyboardShortcut(.return, modifiers: [.command])
                .help("Run command")
            }
        }
        .onAppear(perform: focusCommand)
        .onReceive(NotificationCenter.default.publisher(for: .inputoFocusComposer)) { _ in
            focusCommand()
        }
    }

    @ViewBuilder
    private var statusText: some View {
        if let errorMessage = appState.errorMessage {
            Text(errorMessage)
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(1)
        } else if let statusMessage = appState.statusMessage {
            Text(statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } else if appState.isGenerating {
            Text("Generating...")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } else {
            Text("")
                .font(.caption)
                .lineLimit(1)
        }
    }

    private func focusCommand() {
        DispatchQueue.main.async {
            isCommandFocused = true
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Label("Inputo", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button {
                appState.openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .help("Settings")
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct AnchorBarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(spacing: 6) {
            Label("Jump", systemImage: "arrowshape.turn.up.forward")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
            if appState.anchors.isEmpty {
                Text("No anchors")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                                            .frame(width: 18, height: 18)
                                    } else {
                                        Image(systemName: "app")
                                    }
                                    Text(anchor.appName)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                            }
                            .buttonStyle(.plain)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                            .fixedSize(horizontal: true, vertical: false)
                            .help("Switch to \(anchor.appName)")
                        }
                    }
                }
                .frame(height: 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                appState.refreshAnchors()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .help("Refresh app anchors")
        }
    }
}
