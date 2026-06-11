import AppKit
import InputoCore
import InputoMacPlatform
import SwiftUI

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    @Published public private(set) var settings: AppSettings
    @Published public private(set) var hasAPIKey: Bool
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
    private var generationTask: Task<Void, Never>?
    private var activeGenerationID: UUID?

    public var recipes: [TransformRecipe] {
        TransformRecipe.builtIns + settings.customPresets
    }

    public var selectedRecipe: TransformRecipe {
        recipes.first(where: { $0.id == selectedRecipeID }) ?? TransformRecipe.builtIns[0]
    }

    public var providerSetupMessage: String? {
        if let validationError = settings.provider.validationErrorDescription {
            return validationError
        }
        if !hasAPIKey {
            return AIProviderError.missingAPIKey.errorDescription
        }
        return nil
    }

    public convenience init() {
        self.init(services: .live())
    }

    public init(services: AppStateServices) {
        self.services = services
        let loaded = services.settings.loadSettings()
        settings = loaded
        hasAPIKey = Self.hasUsableAPIKey((try? services.apiKeys.readAPIKey()) ?? "")
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

        generationTask?.cancel()
        let generationID = UUID()
        activeGenerationID = generationID
        isGenerating = true
        errorMessage = nil
        statusMessage = nil

        let task = Task { [weak self] in
            guard let self else { return }
            do {
                _ = try settings.provider.validated()
                let apiKey = try services.apiKeys.readAPIKey()
                hasAPIKey = Self.hasUsableAPIKey(apiKey)
                guard hasAPIKey else {
                    throw AIProviderError.missingAPIKey
                }

                let result = try await services.textTransformer.transformText(
                    text: trimmedInput,
                    instruction: instruction.trimmingCharacters(in: .whitespacesAndNewlines),
                    recipe: selectedRecipe,
                    config: settings.provider,
                    apiKey: apiKey
                )
                guard !Task.isCancelled, activeGenerationID == generationID else { return }
                outputText = result
                statusMessage = "Ready to copy."
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled, activeGenerationID == generationID else { return }
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            finishGeneration(id: generationID)
        }
        generationTask = task
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
        cancelGeneration()
        instruction = ""
        inputText = ""
        outputText = ""
        statusMessage = nil
        errorMessage = nil
    }

    public func openSettings() {
        onRequestSettings?()
    }

    public func saveSettings(_ newSettings: AppSettings, apiKey: String?) {
        settings = newSettings
        services.settings.saveSettings(newSettings)
        if let apiKey {
            services.apiKeys.saveAPIKey(apiKey)
            hasAPIKey = Self.hasUsableAPIKey(apiKey)
        }
        if !recipes.contains(where: { $0.id == selectedRecipeID }) {
            selectedRecipeID = TransformRecipe.builtIns[0].id
        }
        onSettingsChanged?(newSettings)
    }

    public func currentAPIKeyForEditing() -> String {
        let apiKey = (try? services.apiKeys.readAPIKey()) ?? ""
        hasAPIKey = Self.hasUsableAPIKey(apiKey)
        return apiKey
    }

    private func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        activeGenerationID = nil
        isGenerating = false
    }

    private func finishGeneration(id: UUID) {
        guard activeGenerationID == id else { return }
        generationTask = nil
        activeGenerationID = nil
        isGenerating = false
    }

    private static func hasUsableAPIKey(_ apiKey: String) -> Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
