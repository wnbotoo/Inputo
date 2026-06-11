import ApplicationServices
import InputoCore
import InputoMacPlatform
import SwiftUI

public struct SettingsView: View {
    @ObservedObject public var appState: AppState

    @State private var settings: AppSettings
    @State private var apiKey: String
    @State private var newPresetName = ""
    @State private var newPresetPrompt = ""
    @State private var isRecordingShortcut = false

    public init(appState: AppState) {
        self.appState = appState
        _settings = State(initialValue: appState.settings)
        _apiKey = State(initialValue: appState.currentAPIKeyForEditing())
    }

    public var body: some View {
        TabView {
            providerTab
                .tabItem { Label("Provider", systemImage: "network") }
            shortcutTab
                .tabItem { Label("Hotkey", systemImage: "keyboard") }
            presetsTab
                .tabItem { Label("Presets", systemImage: "slider.horizontal.3") }
            permissionsTab
                .tabItem { Label("Privacy", systemImage: "hand.raised") }
        }
        .padding(18)
        .onChange(of: appState.settings) { _, newValue in
            settings = newValue
        }
    }

    private var providerTab: some View {
        Form {
            TextField("Base URL", text: $settings.provider.baseURL)
            TextField("Model", text: $settings.provider.model)
            SecureField("API Key", text: $apiKey)
            HStack {
                Text("Timeout")
                Slider(value: $settings.provider.timeoutSeconds, in: 10...120, step: 5)
                Text("\(Int(settings.provider.timeoutSeconds))s")
                    .monospacedDigit()
            }

            providerStatusRows

            HStack {
                Button("Save Provider Settings") {
                    appState.saveSettings(settings, apiKey: apiKey)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    if appState.saveSettings(settings, apiKey: apiKey) {
                        appState.testProviderTranslation()
                    }
                } label: {
                    if appState.isTestingProvider {
                        Label("Testing", systemImage: "hourglass")
                    } else {
                        Label("Save & Test Translation", systemImage: "checkmark.bubble")
                    }
                }
                .disabled(appState.isTestingProvider)
            }
        }
    }

    @ViewBuilder
    private var providerStatusRows: some View {
        if let message = settings.provider.validationErrorDescription {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        } else {
            Label("Provider settings look ready.", systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Label("API key is empty.", systemImage: "key")
                .font(.caption)
                .foregroundStyle(.orange)
        }

        if let output = appState.providerTestOutput {
            VStack(alignment: .leading, spacing: 4) {
                Label("Translation test succeeded.", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(output)
                    .font(.caption)
                    .textSelection(.enabled)
            }
        } else if let error = appState.providerTestError {
            Label(error, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    private var shortcutTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Inputo does not install a default shortcut. Record one that does not conflict with your input method or system shortcuts.")
                .foregroundStyle(.secondary)

            HStack {
                Text("Current")
                Spacer()
                Text(settings.hotKey?.displayText ?? "Not set")
                    .font(.title3.monospaced())
            }

            ShortcutRecorderField(
                isRecording: $isRecordingShortcut,
                shortcut: settings.hotKey
            ) { shortcut in
                settings.hotKey = shortcut
                isRecordingShortcut = false
            }
            .frame(height: 54)

            HStack {
                Button(isRecordingShortcut ? "Press Shortcut..." : "Record Shortcut") {
                    isRecordingShortcut.toggle()
                }
                Button("Clear") {
                    settings.hotKey = nil
                }
                Spacer()
                Button("Save Hotkey") {
                    appState.saveSettings(settings, apiKey: nil)
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
    }

    private var presetsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Built-in recipes are fixed. Custom recipes stay local and only define prompts; v1 does not run external tools.")
                .foregroundStyle(.secondary)

            List {
                Section("Built-in") {
                    ForEach(TransformRecipe.builtIns) { recipe in
                        VStack(alignment: .leading) {
                            Text(recipe.name)
                            Text(recipe.outputHint)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Custom") {
                    ForEach(settings.customPresets) { recipe in
                        VStack(alignment: .leading) {
                            Text(recipe.name)
                            Text(recipe.systemPrompt)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { offsets in
                        settings.customPresets.remove(atOffsets: offsets)
                    }
                }
            }

            TextField("Preset name", text: $newPresetName)
                .textFieldStyle(.roundedBorder)
            TextField("System prompt", text: $newPresetPrompt)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Add Preset") {
                    addPreset()
                }
                .disabled(newPresetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newPresetPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
                Button("Save Presets") {
                    appState.saveSettings(settings, apiKey: nil)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var permissionsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Minimal permission mode", systemImage: "checkmark.shield")
                .font(.headline)
            Text("Inputo v1 uses app-level anchors. It does not read window titles, capture screenshots, paste automatically, or request screen recording by default.")
                .foregroundStyle(.secondary)

            Divider()

            PermissionRow(title: "Accessibility", status: AXIsProcessTrusted() ? "Granted" : "Not required")
            PermissionRow(title: "Screen Recording", status: "Not requested")
            PermissionRow(title: "Clipboard", status: "Written only when you click Copy")
            PermissionRow(title: "History", status: "Not saved")

            Spacer()
        }
    }

    private func addPreset() {
        let name = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = newPresetPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !prompt.isEmpty else { return }

        settings.customPresets.append(
            TransformRecipe(
                id: "custom-\(UUID().uuidString)",
                name: name,
                systemPrompt: prompt,
                outputHint: "Follow the custom recipe and return only the final transformed text.",
                isBuiltIn: false
            )
        )
        newPresetName = ""
        newPresetPrompt = ""
    }
}

private struct PermissionRow: View {
    let title: String
    let status: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(status)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
