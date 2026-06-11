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

            VStack(spacing: 6) {
                header
                if let providerSetupMessage = appState.providerSetupMessage {
                    ProviderSetupBanner(appState: appState, message: providerSetupMessage)
                }
                TransformControlsView(appState: appState, focusedField: $focusedField)
                AnchorBarView(appState: appState)
                PreviewPanel(appState: appState)
                    .frame(minHeight: 82, idealHeight: 96, maxHeight: 116)
                ComposerInputPanel(appState: appState, focusedField: $focusedField)
                    .frame(maxHeight: .infinity)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .onReceive(NotificationCenter.default.publisher(for: .inputoFocusComposer)) { _ in
            focusedField = .input
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

private struct TransformControlsView: View {
    @ObservedObject var appState: AppState
    var focusedField: FocusState<ComposerFocusField?>.Binding

    var body: some View {
        HStack(spacing: 8) {
            Picker("Preset", selection: $appState.selectedRecipeID) {
                ForEach(appState.recipes) { recipe in
                    Text(recipe.name).tag(recipe.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 138)
            .help("Preset")

            TextField("Instruction", text: $appState.instruction)
                .textFieldStyle(.roundedBorder)
                .focused(focusedField, equals: .instruction)
        }
        .controlSize(.small)
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

private struct PreviewPanel: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Preview", systemImage: "doc.text.magnifyingglass")
                    .font(.caption.weight(.semibold))
                Spacer()
                Button {
                    appState.copyOutput()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .controlSize(.small)
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
                            .padding(10)
                    }
                }
            }
            .frame(maxHeight: .infinity)

            if let error = appState.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            } else if let status = appState.statusMessage {
                Label(status, systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ComposerInputPanel: View {
    @ObservedObject var appState: AppState
    var focusedField: FocusState<ComposerFocusField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $appState.inputText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .focused(focusedField, equals: .input)
                    .padding(6)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.72), in: RoundedRectangle(cornerRadius: 8))

                if appState.inputText.isEmpty {
                    Text("Paste or type the text you want Inputo to transform...")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 78, maxHeight: .infinity)

            HStack {
                Button {
                } label: {
                    Image(systemName: "photo")
                }
                .disabled(true)
                .controlSize(.small)
                .help("Image input is reserved for a later version")

                Button {
                } label: {
                    Image(systemName: "paperclip")
                }
                .disabled(true)
                .controlSize(.small)
                .help("Attachments are reserved for a later version")

                Spacer()

                Button {
                    appState.resetSession()
                } label: {
                    Label("Clear", systemImage: "xmark.circle")
                }
                .controlSize(.small)

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
                .controlSize(.small)
                .disabled(appState.isGenerating || appState.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

enum ComposerFocusField: Hashable {
    case instruction
    case input
}
