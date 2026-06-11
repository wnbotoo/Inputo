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

    private let services: AppStateServices

    public var recipes: [TransformRecipe] {
        TransformRecipe.builtIns + settings.customPresets
    }

    public var selectedRecipe: TransformRecipe {
        recipes.first(where: { $0.id == selectedRecipeID }) ?? TransformRecipe.builtIns[0]
    }

    public convenience init() {
        self.init(services: .live())
    }

    public init(services: AppStateServices) {
        self.services = services
        let loaded = services.settings.loadSettings()
        settings = loaded
        selectedRecipeID = TransformRecipe.builtIns[0].id
    }

    public func refreshAnchors() {
        anchors = services.anchors.currentAnchors()
    }

    @discardableResult
    public func generate() -> Task<Void, Never> {
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            errorMessage = "Add text to transform first."
            return Task { @MainActor in }
        }

        isGenerating = true
        errorMessage = nil
        statusMessage = nil

        let task = Task {
            do {
                let apiKey = try services.apiKeys.readAPIKey()
                guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw AIProviderError.missingAPIKey
                }

                let result = try await services.textTransformer.transformText(
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
        return task
    }

    public func copyOutput() {
        let trimmedOutput = outputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOutput.isEmpty else {
            errorMessage = "Generate a result before copying."
            return
        }
        services.clipboard.copy(trimmedOutput)
        statusMessage = "Copied to clipboard."
        errorMessage = nil
    }

    public func requestActivate(anchor: AppAnchor) {
        onActivateAnchor?(anchor)
    }

    public func activate(anchor: AppAnchor) -> Bool {
        let didActivate = services.anchors.activate(anchor)
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
        services.settings.saveSettings(newSettings)
        if let apiKey {
            services.apiKeys.saveAPIKey(apiKey)
        }
        if !recipes.contains(where: { $0.id == selectedRecipeID }) {
            selectedRecipeID = TransformRecipe.builtIns[0].id
        }
        onSettingsChanged?(newSettings)
    }

    public func currentAPIKeyForEditing() -> String {
        (try? services.apiKeys.readAPIKey()) ?? ""
    }
}
