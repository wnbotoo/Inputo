import InputoMacPlatform
import SwiftUI

public struct ComposerView: View {
    @ObservedObject public var appState: AppState
    @FocusState private var focusedField: ComposerFocusField?

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                header
                if let providerSetupMessage = appState.providerSetupMessage {
                    ProviderSetupBanner(appState: appState, message: providerSetupMessage)
                }
                AnchorBarView(appState: appState)
                PreviewPanel(appState: appState)
                ComposerInputPanel(appState: appState, focusedField: $focusedField)
            }
            .padding(18)
        }
        .onReceive(NotificationCenter.default.publisher(for: .inputoFocusComposer)) { _ in
            focusedField = .input
        }
    }

    private var header: some View {
        HStack {
            Label("Inputo", systemImage: "sparkles")
                .font(.headline)
            Text("AI input source")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                appState.openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Jump target")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    appState.refreshAnchors()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh app anchors")
            }

            if appState.anchors.isEmpty {
                Text("No app anchors available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
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
                                .padding(.vertical, 7)
                            }
                            .buttonStyle(.plain)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                            .help("Switch to \(anchor.appName)")
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
    }
}

private struct PreviewPanel: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Preview", systemImage: "doc.text.magnifyingglass")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    appState.copyOutput()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .disabled(appState.outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .textBackgroundColor).opacity(0.72))

                if appState.isGenerating {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Generating...")
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                } else if appState.outputText.isEmpty {
                    Text("No preview yet.")
                        .foregroundStyle(.secondary)
                        .padding(14)
                } else {
                    ScrollView {
                        Text(appState.outputText)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                    }
                }
            }
            .frame(minHeight: 180)

            if let error = appState.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if let status = appState.statusMessage {
                Label(status, systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ComposerInputPanel: View {
    @ObservedObject var appState: AppState
    var focusedField: FocusState<ComposerFocusField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(appState.recipes) { recipe in
                        Button {
                            appState.selectedRecipeID = recipe.id
                        } label: {
                            Text(recipe.name)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .background(
                            appState.selectedRecipeID == recipe.id ? Color.accentColor.opacity(0.22) : Color(nsColor: .quaternaryLabelColor).opacity(0.18),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                    }
                }
            }

            TextField("Optional instruction, e.g. make it warmer, translate to Japanese", text: $appState.instruction)
                .textFieldStyle(.roundedBorder)
                .focused(focusedField, equals: .instruction)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $appState.inputText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .focused(focusedField, equals: .input)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.72), in: RoundedRectangle(cornerRadius: 8))

                if appState.inputText.isEmpty {
                    Text("Paste or type the text you want Inputo to transform...")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 112)

            HStack {
                Button {
                } label: {
                    Image(systemName: "photo")
                }
                .disabled(true)
                .help("Image input is reserved for a later version")

                Button {
                } label: {
                    Image(systemName: "paperclip")
                }
                .disabled(true)
                .help("Attachments are reserved for a later version")

                Spacer()

                Button {
                    appState.resetSession()
                } label: {
                    Label("Clear", systemImage: "xmark.circle")
                }

                Button {
                    appState.generate()
                } label: {
                    if appState.isGenerating {
                        Label("Generating", systemImage: "hourglass")
                    } else {
                        Label("Generate", systemImage: "wand.and.sparkles")
                    }
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(appState.isGenerating || appState.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

enum ComposerFocusField: Hashable {
    case instruction
    case input
}
