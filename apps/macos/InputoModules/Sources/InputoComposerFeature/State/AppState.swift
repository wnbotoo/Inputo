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
    @Published public var commandText: String = ""
    @Published public var instruction: String = ""
    @Published public var inputText: String = ""
    @Published public var outputText: String = ""
    @Published public var anchors: [AppAnchor] = []
    @Published public var isGenerating = false
    @Published public var isTestingProvider = false
    @Published public var providerTestMessage: String?
    @Published public var providerTestError: String?
    @Published public var statusMessage: String?
    @Published public var errorMessage: String?

    public var onActivateAnchor: ((AppAnchor) -> Void)?
    public var onRequestSettings: (() -> Void)?
    public var onSettingsChanged: ((AppSettings) -> Void)?

    private let services: AppStateServices
    private var generationTask: Task<Void, Never>?
    private var activeGenerationID: UUID?
    private var activeNativePreviewRequestID: String?
    private var providerTestTask: Task<Void, Never>?
    private var activeProviderTestID: UUID?

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

    @discardableResult
    public func streamGenerate(onDelta: @escaping @MainActor (String) -> Void) -> Task<Void, Never> {
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            errorMessage = "Add text to transform first."
            return Task { @MainActor in }
        }

        generationTask?.cancel()
        let generationID = UUID()
        activeGenerationID = generationID
        isGenerating = true
        outputText = ""
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

                let stream = try await services.textTransformer.streamText(
                    text: trimmedInput,
                    instruction: instruction.trimmingCharacters(in: .whitespacesAndNewlines),
                    recipe: selectedRecipe,
                    config: settings.provider,
                    apiKey: apiKey
                )

                var combinedOutput = ""
                for try await delta in stream {
                    guard !Task.isCancelled, activeGenerationID == generationID else { return }
                    combinedOutput += delta
                    outputText = combinedOutput
                    onDelta(delta)
                }

                guard !Task.isCancelled, activeGenerationID == generationID else { return }
                guard !combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw AIProviderError.emptyOutput
                }
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
        activeNativePreviewRequestID = nil
        commandText = ""
        instruction = ""
        inputText = ""
        outputText = ""
        statusMessage = nil
        errorMessage = nil
    }

    public func cancelActiveGeneration() {
        cancelGeneration()
    }

    public func cancelNativeCommand() {
        guard let requestID = activeNativePreviewRequestID else {
            cancelGeneration()
            return
        }
        activeNativePreviewRequestID = nil
        cancelGeneration()
        emitPreviewEvent(event: .llmCancelled, requestID: requestID, payload: InputoEmptyPayload())
        statusMessage = "Generation cancelled."
        errorMessage = nil
    }

    @discardableResult
    public func submitCommandInput() -> Task<Void, Never> {
        let trimmedInput = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            statusMessage = nil
            errorMessage = "Enter a /command first."
            return Task { @MainActor in }
        }

        guard let parsed = ParsedNativeCommand(rawInput: trimmedInput) else {
            statusMessage = nil
            errorMessage = "Start with a /command such as /polish or /translate."
            return Task { @MainActor in }
        }

        guard let builtIn = NativeBuiltInCommand(parsed: parsed) else {
            forwardCommandToWeb(parsed)
            return Task { @MainActor in }
        }

        return runNativeBuiltInCommand(builtIn, parsed: parsed)
    }

    public func openSettings() {
        onRequestSettings?()
    }

    @discardableResult
    public func saveSettings(_ newSettings: AppSettings, apiKey: String?) -> Bool {
        providerTestMessage = nil
        providerTestError = nil
        settings = newSettings
        services.settings.saveSettings(newSettings)
        if let apiKey {
            do {
                try services.apiKeys.saveAPIKey(apiKey)
                hasAPIKey = Self.hasUsableAPIKey(apiKey)
            } catch {
                statusMessage = nil
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                hasAPIKey = Self.hasUsableAPIKey((try? services.apiKeys.readAPIKey()) ?? "")
                onSettingsChanged?(newSettings)
                return false
            }
        }
        if !recipes.contains(where: { $0.id == selectedRecipeID }) {
            selectedRecipeID = TransformRecipe.builtIns[0].id
        }
        onSettingsChanged?(newSettings)
        return true
    }

    @discardableResult
    public func testProviderConnection() -> Task<Void, Never> {
        providerTestTask?.cancel()
        let testID = UUID()
        activeProviderTestID = testID
        providerTestMessage = nil
        providerTestError = nil
        isTestingProvider = true

        let task = Task { [weak self] in
            guard let self else { return }
            do {
                _ = try settings.provider.validated()
                let apiKey = try services.apiKeys.readAPIKey()
                hasAPIKey = Self.hasUsableAPIKey(apiKey)
                guard hasAPIKey else {
                    throw AIProviderError.missingAPIKey
                }

                _ = try await services.textTransformer.transformText(
                    text: "ping",
                    instruction: "Reply with exactly: ok",
                    recipe: Self.providerConnectionTestRecipe,
                    config: settings.provider,
                    apiKey: apiKey
                )
                guard !Task.isCancelled else { return }
                providerTestMessage = "Connection test succeeded."
                statusMessage = providerTestMessage
                errorMessage = nil
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled else { return }
                providerTestError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                statusMessage = nil
                errorMessage = providerTestError
            }
            finishProviderTest(id: testID)
        }
        providerTestTask = task
        return task
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

    private func finishProviderTest(id: UUID) {
        guard activeProviderTestID == id else { return }
        providerTestTask = nil
        activeProviderTestID = nil
        isTestingProvider = false
    }

    private static func hasUsableAPIKey(_ apiKey: String) -> Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func forwardCommandToWeb(_ command: ParsedNativeCommand) {
        cancelNativeCommand()
        inputText = command.bodyText
        instruction = ""
        outputText = ""
        statusMessage = "Sent /\(command.name) to Web."
        errorMessage = nil
        emitPreviewEvent(
            event: .commandReceived,
            requestID: nil,
            payload: InputoCommandReceivedPayload(
                commandName: command.name,
                inputText: command.rawInput,
                bodyText: command.bodyText,
                arguments: command.arguments
            )
        )
    }

    private func runNativeBuiltInCommand(
        _ command: NativeBuiltInCommand,
        parsed: ParsedNativeCommand
    ) -> Task<Void, Never> {
        let bodyText = command.bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bodyText.isEmpty else {
            statusMessage = nil
            errorMessage = "Add text after /\(parsed.name)."
            return Task { @MainActor in }
        }

        guard recipes.contains(where: { $0.id == command.recipeID }) else {
            statusMessage = nil
            errorMessage = "Native command /\(parsed.name) is not available."
            return Task { @MainActor in }
        }

        if let previousRequestID = activeNativePreviewRequestID {
            emitPreviewEvent(event: .llmCancelled, requestID: previousRequestID, payload: InputoEmptyPayload())
        }

        let requestID = "native-command-\(UUID().uuidString)"
        activeNativePreviewRequestID = requestID
        inputText = bodyText
        instruction = command.instruction
        selectedRecipeID = command.recipeID
        outputText = ""
        statusMessage = nil
        errorMessage = nil
        emitPreviewEvent(event: .llmStarted, requestID: requestID, payload: InputoEmptyPayload())

        var coalescer = InputoStreamDeltaCoalescer()
        let generation = streamGenerate { [weak self] delta in
            guard let self else { return }
            guard self.activeNativePreviewRequestID == requestID else { return }
            for streamDelta in coalescer.append(delta) {
                self.emitPreviewEvent(event: .llmDelta, requestID: requestID, payload: streamDelta)
            }
        }

        return Task { @MainActor [weak self] in
            await generation.value
            guard let self, self.activeNativePreviewRequestID == requestID else { return }
            if let errorMessage = self.errorMessage {
                self.emitPreviewEvent(
                    event: .llmFailed,
                    requestID: requestID,
                    payload: InputoNativeToolError(code: self.llmErrorCode(for: errorMessage), message: errorMessage)
                )
                self.activeNativePreviewRequestID = nil
                return
            }
            if let finalDelta = coalescer.flush(isFinal: true) {
                self.emitPreviewEvent(event: .llmDelta, requestID: requestID, payload: finalDelta)
            }
            self.emitPreviewEvent(event: .llmCompleted, requestID: requestID, payload: InputoEmptyPayload())
            self.activeNativePreviewRequestID = nil
        }
    }

    private func llmErrorCode(for message: String) -> InputoNativeToolErrorCode {
        if message == AIProviderError.missingAPIKey.errorDescription {
            return .missingAPIKey
        }
        if message == "Add text to transform first." {
            return .invalidRequest
        }
        if message == AIProviderError.emptyOutput.errorDescription {
            return .emptyOutput
        }
        return .providerError
    }

    private func emitPreviewEvent<Payload: Codable & Equatable & Sendable>(
        event: InputoToolEventName,
        requestID: String?,
        payload: Payload
    ) {
        InputoBridgeEventEmitter { data in
            NotificationCenter.default.post(name: .inputoPreviewBridgeEvent, object: data)
        }
        .emit(event: event, requestID: requestID, payload: payload)
    }

    private static let providerConnectionTestRecipe = TransformRecipe(
        id: "provider-connection-test",
        name: "Connection Test",
        systemPrompt: "You are checking whether the provider can process a minimal chat completion request.",
        outputHint: "Return exactly: ok",
        isBuiltIn: true
    )
}

private struct ParsedNativeCommand {
    var rawInput: String
    var name: String
    var bodyText: String
    var arguments: [String]

    init?(rawInput: String) {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return nil }
        let withoutSlash = String(trimmed.dropFirst())
        let commandPart: String
        let body: String
        if let separator = withoutSlash.firstIndex(where: { $0.isWhitespace }) {
            commandPart = String(withoutSlash[..<separator])
            body = String(withoutSlash[separator...]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            commandPart = withoutSlash
            body = ""
        }
        let commandName = commandPart.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !commandName.isEmpty else { return nil }
        self.rawInput = trimmed
        self.name = commandName
        self.bodyText = body
        self.arguments = body.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }
}

private struct NativeBuiltInCommand {
    var recipeID: String
    var bodyText: String
    var instruction: String

    init?(parsed: ParsedNativeCommand) {
        switch parsed.name {
        case "polish":
            self.init(recipeID: "polish", bodyText: parsed.bodyText)
        case "concise", "shorten":
            self.init(recipeID: "concise", bodyText: parsed.bodyText)
        case "emoji":
            self.init(recipeID: "emoji", bodyText: parsed.bodyText)
        case "translate-en", "translate-english":
            self.init(recipeID: "translate-en", bodyText: parsed.bodyText)
        case "translate-zh", "translate-cn", "translate-chinese":
            self.init(recipeID: "translate-zh", bodyText: parsed.bodyText)
        case "translate":
            let target = parsed.arguments.first.flatMap(Self.translationRecipeID)
            if let target {
                self.init(recipeID: target, bodyText: Self.dropFirstArgument(from: parsed.bodyText))
            } else {
                self.init(recipeID: "translate-en", bodyText: parsed.bodyText)
            }
        default:
            return nil
        }
    }

    private init(recipeID: String, bodyText: String, instruction: String = "") {
        self.recipeID = recipeID
        self.bodyText = bodyText
        self.instruction = instruction
    }

    private static func translationRecipeID(for token: String) -> String? {
        switch token.lowercased() {
        case "en", "english":
            return "translate-en"
        case "zh", "cn", "chinese", "中文":
            return "translate-zh"
        default:
            return nil
        }
    }

    private static func dropFirstArgument(from bodyText: String) -> String {
        let trimmed = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let separator = trimmed.firstIndex(where: { $0.isWhitespace }) else { return "" }
        return String(trimmed[separator...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
