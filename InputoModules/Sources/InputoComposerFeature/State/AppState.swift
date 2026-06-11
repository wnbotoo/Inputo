import AppKit
import InputoCore
import InputoMacPlatform
import SwiftUI

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    @Published public private(set) var settings: AppSettings
    @Published public var selectedRecipeID: String
    @Published public var instruction: String = ""
    @Published public var inputText: String = ""
    @Published public var outputText: String = ""
    @Published public var anchors: [AppAnchor] = []
    @Published public var isGenerating = false
    @Published public var statusMessage: String?
    @Published public var errorMessage: String?

    public var onActivateAnchor: ((AppAnchor) -> Void)?
    public var onRequestSettings: (() -> Void)?
    public var onSettingsChanged: ((AppSettings) -> Void)?

    private let settingsStore = SettingsStore()
    private let keychain = KeychainService()
    private let clipboard = ClipboardService()
    private let anchorService = AnchorService()

    public var recipes: [TransformRecipe] {
        TransformRecipe.builtIns + settings.customPresets
    }

    public var selectedRecipe: TransformRecipe {
        recipes.first(where: { $0.id == selectedRecipeID }) ?? TransformRecipe.builtIns[0]
    }

    private init() {
        let loaded = settingsStore.load()
        settings = loaded
        selectedRecipeID = TransformRecipe.builtIns[0].id
    }

    public func refreshAnchors() {
        anchors = anchorService.currentAnchors()
    }

    public func generate() {
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            errorMessage = "Add text to transform first."
            return
        }

        isGenerating = true
        errorMessage = nil
        statusMessage = nil

        Task {
            do {
                let apiKey = try keychain.readAPIKey()
                guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw AIProviderError.missingAPIKey
                }

                let result = try await AIProviderClient().transform(
                    text: trimmedInput,
                    instruction: instruction.trimmingCharacters(in: .whitespacesAndNewlines),
                    recipe: selectedRecipe,
                    config: settings.provider,
                    apiKey: apiKey
                )
                outputText = result
                statusMessage = "Ready to copy."
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isGenerating = false
        }
    }

    public func copyOutput() {
        let trimmedOutput = outputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOutput.isEmpty else {
            errorMessage = "Generate a result before copying."
            return
        }
        clipboard.copy(trimmedOutput)
        statusMessage = "Copied to clipboard."
        errorMessage = nil
    }

    public func requestActivate(anchor: AppAnchor) {
        onActivateAnchor?(anchor)
    }

    public func activate(anchor: AppAnchor) -> Bool {
        let didActivate = anchorService.activate(anchor)
        if !didActivate {
            statusMessage = nil
            errorMessage = "Could not switch to \(anchor.appName). Please switch manually."
        }
        return didActivate
    }

    public func resetSession() {
        instruction = ""
        inputText = ""
        outputText = ""
        statusMessage = nil
        errorMessage = nil
        isGenerating = false
    }

    public func openSettings() {
        onRequestSettings?()
    }

    public func saveSettings(_ newSettings: AppSettings, apiKey: String?) {
        settings = newSettings
        settingsStore.save(newSettings)
        if let apiKey {
            keychain.saveAPIKey(apiKey)
        }
        if !recipes.contains(where: { $0.id == selectedRecipeID }) {
            selectedRecipeID = TransformRecipe.builtIns[0].id
        }
        onSettingsChanged?(newSettings)
    }

    public func currentAPIKeyForEditing() -> String {
        (try? keychain.readAPIKey()) ?? ""
    }
}
