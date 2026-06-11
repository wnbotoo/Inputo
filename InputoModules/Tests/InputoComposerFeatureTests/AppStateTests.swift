import Foundation
import InputoComposerFeature
import InputoCore
import InputoMacPlatform
import Testing

@MainActor
@Test
func generateRequiresInputBeforeCallingProvider() async {
    let harness = makeHarness()

    harness.state.inputText = " \n "
    await harness.state.generate().value

    #expect(harness.state.errorMessage == "Add text to transform first.")
    #expect(harness.state.isGenerating == false)
    #expect(harness.provider.requests.isEmpty)
    #expect(harness.clipboard.copiedTexts.isEmpty)
}

@MainActor
@Test
func generateRequiresAPIKeyBeforeCallingProvider() async {
    let harness = makeHarness(apiKey: "  ")

    harness.state.inputText = "Hello"
    await harness.state.generate().value

    #expect(harness.state.errorMessage == AIProviderError.missingAPIKey.errorDescription)
    #expect(harness.state.isGenerating == false)
    #expect(harness.state.outputText.isEmpty)
    #expect(harness.provider.requests.isEmpty)
}

@MainActor
@Test
func generateValidatesProviderSettingsBeforeCallingProvider() async {
    let settings = AppSettings(
        provider: AIProviderConfig(
            baseURL: "https://provider.example",
            model: " ",
            timeoutSeconds: 30,
            headers: [:]
        ),
        hotKey: nil,
        customPresets: []
    )
    let harness = makeHarness(settings: settings, apiKey: "test-key")

    harness.state.inputText = "Hello"
    await harness.state.generate().value

    #expect(harness.state.providerSetupMessage == AIProviderError.invalidModel.errorDescription)
    #expect(harness.state.errorMessage == AIProviderError.invalidModel.errorDescription)
    #expect(harness.state.isGenerating == false)
    #expect(harness.provider.requests.isEmpty)
}

@MainActor
@Test
func generateStoresPreviewWithoutCopyingUntilUserClicksCopy() async throws {
    let providerConfig = AIProviderConfig(
        baseURL: "https://provider.example",
        model: "inputo-test",
        timeoutSeconds: 20,
        headers: ["X-Test": "1"]
    )
    let settings = AppSettings(
        provider: providerConfig,
        hotKey: nil,
        customPresets: []
    )
    let harness = makeHarness(
        settings: settings,
        apiKey: "test-api-key",
        providerResult: .success("Generated result")
    )

    harness.state.inputText = "  Hello world  "
    harness.state.instruction = "  make it warmer  "
    harness.state.selectedRecipeID = "translate-en"
    await harness.state.generate().value

    let request = try #require(harness.provider.requests.first)
    #expect(request.text == "Hello world")
    #expect(request.instruction == "make it warmer")
    #expect(request.recipe.id == "translate-en")
    #expect(request.config == providerConfig)
    #expect(request.apiKey == "test-api-key")
    #expect(harness.state.outputText == "Generated result")
    #expect(harness.state.statusMessage == "Ready to copy.")
    #expect(harness.state.errorMessage == nil)
    #expect(harness.clipboard.copiedTexts.isEmpty)

    harness.state.copyOutput()

    #expect(harness.clipboard.copiedTexts == ["Generated result"])
    #expect(harness.state.statusMessage == "Copied to clipboard.")
    #expect(harness.state.errorMessage == nil)
}

@MainActor
@Test
func resetSessionClearsTransientComposerState() {
    let harness = makeHarness()

    harness.state.instruction = "Tone down"
    harness.state.inputText = "Draft"
    harness.state.outputText = "Result"
    harness.state.statusMessage = "Ready"
    harness.state.errorMessage = "Problem"
    harness.state.isGenerating = true

    harness.state.resetSession()

    #expect(harness.state.instruction.isEmpty)
    #expect(harness.state.inputText.isEmpty)
    #expect(harness.state.outputText.isEmpty)
    #expect(harness.state.statusMessage == nil)
    #expect(harness.state.errorMessage == nil)
    #expect(harness.state.isGenerating == false)
}

@MainActor
@Test
func resetSessionCancelsInFlightGenerationAndIgnoresLateProviderResult() async {
    let settingsService = FakeSettingsService(settings: .default)
    let apiKeyService = FakeAPIKeyService(apiKey: "test-key")
    let clipboard = FakeClipboardService()
    let anchors = FakeAnchorService()
    let provider = ControlledTextTransformer()
    let state = AppState(
        services: AppStateServices(
            settings: settingsService,
            apiKeys: apiKeyService,
            clipboard: clipboard,
            anchors: anchors,
            textTransformer: provider
        )
    )

    state.inputText = "Draft"
    let task = state.generate()
    await provider.waitForRequest()
    #expect(state.isGenerating == true)

    state.resetSession()
    provider.complete(with: "Late result")
    await task.value

    #expect(state.inputText.isEmpty)
    #expect(state.outputText.isEmpty)
    #expect(state.statusMessage == nil)
    #expect(state.errorMessage == nil)
    #expect(state.isGenerating == false)
    #expect(clipboard.copiedTexts.isEmpty)
}

@MainActor
@Test
func anchorFlowRefreshesRequestsAndReportsActivationFailure() {
    let anchor = makeAnchor(id: "notes", appName: "Notes", pid: 42)
    let harness = makeHarness()
    harness.anchors.availableAnchors = [anchor]
    harness.anchors.activationResults[anchor.id] = false

    harness.state.refreshAnchors()
    #expect(harness.state.anchors == [anchor])

    var requestedAnchor: AppAnchor?
    harness.state.onActivateAnchor = { requestedAnchor = $0 }
    harness.state.requestActivate(anchor: anchor)
    #expect(requestedAnchor == anchor)

    let didActivate = harness.state.activate(anchor: anchor)

    #expect(didActivate == false)
    #expect(harness.anchors.activatedAnchors == [anchor])
    #expect(harness.state.errorMessage == "Could not switch to Notes. Please switch manually.")
    #expect(harness.state.statusMessage == nil)
}

@MainActor
@Test
func saveSettingsPersistsSettingsAPIKeyAndFallsBackFromRemovedPreset() {
    let customRecipe = TransformRecipe(
        id: "custom-test",
        name: "Custom",
        systemPrompt: "Rewrite for tests.",
        outputHint: "Return only rewritten text.",
        isBuiltIn: false
    )
    let loadedSettings = AppSettings(
        provider: .default,
        hotKey: nil,
        customPresets: [customRecipe]
    )
    let harness = makeHarness(settings: loadedSettings)
    let newSettings = AppSettings(
        provider: AIProviderConfig(
            baseURL: "https://new.example",
            model: "new-model",
            timeoutSeconds: 30,
            headers: [:]
        ),
        hotKey: nil,
        customPresets: []
    )
    var callbackSettings: AppSettings?

    harness.state.selectedRecipeID = customRecipe.id
    harness.state.onSettingsChanged = { callbackSettings = $0 }
    harness.state.saveSettings(newSettings, apiKey: "new-key")

    #expect(harness.settings.savedSettings == [newSettings])
    #expect(harness.apiKeys.savedAPIKeys == ["new-key"])
    #expect(harness.state.settings == newSettings)
    #expect(harness.state.selectedRecipeID == TransformRecipe.builtIns[0].id)
    #expect(callbackSettings == newSettings)
}

@MainActor
@Test
func testProviderConnectionUsesSavedProviderAndDoesNotCopy() async throws {
    let providerConfig = AIProviderConfig(
        baseURL: "https://provider.example",
        model: "inputo-test",
        timeoutSeconds: 20,
        headers: [:]
    )
    let settings = AppSettings(
        provider: providerConfig,
        hotKey: nil,
        customPresets: []
    )
    let harness = makeHarness(
        settings: settings,
        apiKey: "test-key",
        providerResult: .success("ok")
    )

    await harness.state.testProviderConnection().value

    let request = try #require(harness.provider.requests.first)
    #expect(request.text == "ping")
    #expect(request.instruction == "Reply with exactly: ok")
    #expect(request.recipe.id == "provider-connection-test")
    #expect(request.config == providerConfig)
    #expect(request.apiKey == "test-key")
    #expect(harness.state.providerTestMessage == "Connection test succeeded.")
    #expect(harness.state.providerTestError == nil)
    #expect(harness.state.statusMessage == "Connection test succeeded.")
    #expect(harness.clipboard.copiedTexts.isEmpty)
}

@MainActor
@Test
func nativeExecutorSnapshotExposesCurrentStateWithoutSecretsOrWindowData() throws {
    let providerConfig = AIProviderConfig(
        baseURL: "https://provider.example",
        model: "inputo-test",
        timeoutSeconds: 20,
        headers: ["X-Provider-Token": "header-secret"]
    )
    let settings = AppSettings(
        provider: providerConfig,
        hotKey: nil,
        customPresets: [
            TransformRecipe(
                id: "custom-test",
                name: "Custom",
                systemPrompt: "Rewrite for tests.",
                outputHint: "Return only rewritten text.",
                isBuiltIn: false
            )
        ]
    )
    let anchor = makeAnchor(id: "notes", appName: "Notes", pid: 42)
    let harness = makeHarness(settings: settings, apiKey: "stored-api-key")
    harness.anchors.availableAnchors = [anchor]

    harness.state.inputText = "Draft"
    harness.state.instruction = "Make it warmer"
    harness.state.outputText = "Generated"
    harness.state.statusMessage = "Ready"
    harness.state.refreshAnchors()

    let snapshot = harness.state.nativeExecutorSnapshot()
    let data = try JSONEncoder().encode(snapshot)
    let json = String(decoding: data, as: UTF8.self)

    #expect(snapshot.version == InputoBridgeContract.version)
    #expect(snapshot.agentMode == .manualTransform)
    #expect(snapshot.composer.draftText == "Draft")
    #expect(snapshot.composer.generatedOutput == "Generated")
    #expect(snapshot.composer.canGenerate == true)
    #expect(snapshot.composer.canCopy == true)
    #expect(snapshot.settings.provider.hasAPIKey == true)
    #expect(snapshot.settings.provider.endpointPreview == "https://provider.example/v1/chat/completions")
    #expect(snapshot.settings.customRecipeCount == 1)
    #expect(snapshot.anchors == [
        InputoAppAnchorSnapshot(
            id: "notes",
            appName: "Notes",
            bundleIdentifier: "app.inputo.tests.notes",
            processIdentifier: 42,
            lastActiveAt: nil,
            canActivate: true
        )
    ])
    #expect(snapshot.tools.map(\.id).contains(.llmChat))
    #expect(snapshot.permissions.contains { $0.id == .screenRecording && $0.state == .notRequested })
    #expect(snapshot.permissions.contains { $0.id == .fileRead && $0.state == .unavailable })
    #expect(snapshot.permissions.contains { $0.id == .fileWrite && $0.state == .unavailable })
    #expect(json.contains("stored-api-key") == false)
    #expect(json.contains("header-secret") == false)
    #expect(json.contains("icon") == false)
    #expect(json.contains("windowTitle") == false)
}

@MainActor
@Test
func nativeExecutorSnapshotMarksFileToolsAsUserGrantedInAssistedWorkflow() {
    let harness = makeHarness(apiKey: "stored-api-key")
    let snapshot = harness.state.nativeExecutorSnapshot(agentMode: .assistedWorkflow)

    #expect(snapshot.permissions.contains { $0.id == .fileRead && $0.state == .requiresUserAction })
    #expect(snapshot.permissions.contains { $0.id == .fileWrite && $0.state == .requiresUserAction })
    #expect(snapshot.tools.first { $0.id == .filesReadText }?.isAvailable(in: .assistedWorkflow) == true)
    #expect(snapshot.tools.first { $0.id == .filesWriteText }?.isAvailable(in: .assistedWorkflow) == true)
}

@MainActor
@Test
func cancelActiveGenerationCancelsInFlightProviderResult() async {
    let settingsService = FakeSettingsService(settings: .default)
    let apiKeyService = FakeAPIKeyService(apiKey: "test-key")
    let clipboard = FakeClipboardService()
    let anchors = FakeAnchorService()
    let provider = ControlledTextTransformer()
    let state = AppState(
        services: AppStateServices(
            settings: settingsService,
            apiKeys: apiKeyService,
            clipboard: clipboard,
            anchors: anchors,
            textTransformer: provider
        )
    )

    state.inputText = "Draft"
    let task = state.generate()
    await provider.waitForRequest()

    state.cancelActiveGeneration()
    provider.complete(with: "Late result")
    await task.value

    #expect(state.isGenerating == false)
    #expect(state.outputText.isEmpty)
    #expect(state.statusMessage == nil)
    #expect(state.errorMessage == nil)
    #expect(clipboard.copiedTexts.isEmpty)
}

@MainActor
private func makeHarness(
    settings: AppSettings = .default,
    apiKey: String = "test-key",
    providerResult: Result<String, Error> = .success("Generated")
) -> AppStateHarness {
    let settingsService = FakeSettingsService(settings: settings)
    let apiKeyService = FakeAPIKeyService(apiKey: apiKey)
    let clipboard = FakeClipboardService()
    let anchors = FakeAnchorService()
    let provider = FakeTextTransformer(result: providerResult)
    let state = AppState(
        services: AppStateServices(
            settings: settingsService,
            apiKeys: apiKeyService,
            clipboard: clipboard,
            anchors: anchors,
            textTransformer: provider
        )
    )

    return AppStateHarness(
        state: state,
        settings: settingsService,
        apiKeys: apiKeyService,
        clipboard: clipboard,
        anchors: anchors,
        provider: provider
    )
}

private struct AppStateHarness {
    let state: AppState
    let settings: FakeSettingsService
    let apiKeys: FakeAPIKeyService
    let clipboard: FakeClipboardService
    let anchors: FakeAnchorService
    let provider: FakeTextTransformer
}

@MainActor
private final class FakeSettingsService: AppSettingsServicing {
    var settings: AppSettings
    private(set) var savedSettings: [AppSettings] = []

    init(settings: AppSettings) {
        self.settings = settings
    }

    func loadSettings() -> AppSettings {
        settings
    }

    func saveSettings(_ settings: AppSettings) {
        savedSettings.append(settings)
        self.settings = settings
    }
}

@MainActor
private final class FakeAPIKeyService: APIKeyServicing {
    var apiKey: String
    var readError: Error?
    var saveError: Error?
    private(set) var savedAPIKeys: [String] = []

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func readAPIKey() throws -> String {
        if let readError {
            throw readError
        }
        return apiKey
    }

    func saveAPIKey(_ apiKey: String) throws {
        if let saveError {
            throw saveError
        }
        savedAPIKeys.append(apiKey)
        self.apiKey = apiKey
    }
}

@MainActor
private final class FakeClipboardService: ClipboardServicing {
    private(set) var copiedTexts: [String] = []

    func copy(_ text: String) {
        copiedTexts.append(text)
    }
}

@MainActor
private final class FakeAnchorService: AppAnchorServicing {
    var availableAnchors: [AppAnchor] = []
    var activationResults: [String: Bool] = [:]
    private(set) var activatedAnchors: [AppAnchor] = []

    func currentAnchors() -> [AppAnchor] {
        availableAnchors
    }

    func activate(_ anchor: AppAnchor) -> Bool {
        activatedAnchors.append(anchor)
        return activationResults[anchor.id] ?? true
    }
}

private struct TransformRequest {
    let text: String
    let instruction: String
    let recipe: TransformRecipe
    let config: AIProviderConfig
    let apiKey: String
}

@MainActor
private final class FakeTextTransformer: TextTransforming {
    var result: Result<String, Error>
    private(set) var requests: [TransformRequest] = []

    init(result: Result<String, Error>) {
        self.result = result
    }

    func transformText(
        text: String,
        instruction: String,
        recipe: TransformRecipe,
        config: AIProviderConfig,
        apiKey: String
    ) async throws -> String {
        requests.append(
            TransformRequest(
                text: text,
                instruction: instruction,
                recipe: recipe,
                config: config,
                apiKey: apiKey
            )
        )
        return try result.get()
    }
}

@MainActor
private final class ControlledTextTransformer: TextTransforming {
    private var requestContinuation: CheckedContinuation<Void, Never>?
    private var resultContinuation: CheckedContinuation<String, Error>?
    private(set) var requests: [TransformRequest] = []

    func waitForRequest() async {
        if !requests.isEmpty {
            return
        }
        await withCheckedContinuation { continuation in
            requestContinuation = continuation
        }
    }

    func complete(with result: String) {
        resultContinuation?.resume(returning: result)
        resultContinuation = nil
    }

    func transformText(
        text: String,
        instruction: String,
        recipe: TransformRecipe,
        config: AIProviderConfig,
        apiKey: String
    ) async throws -> String {
        requests.append(
            TransformRequest(
                text: text,
                instruction: instruction,
                recipe: recipe,
                config: config,
                apiKey: apiKey
            )
        )
        requestContinuation?.resume()
        requestContinuation = nil

        return try await withCheckedThrowingContinuation { continuation in
            resultContinuation = continuation
        }
    }
}

private func makeAnchor(id: String, appName: String, pid: pid_t) -> AppAnchor {
    AppAnchor(
        id: id,
        appName: appName,
        bundleIdentifier: "app.inputo.tests.\(id)",
        processIdentifier: pid,
        icon: nil,
        lastActiveAt: nil,
        canActivate: true
    )
}
