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
    #expect(snapshot.permissions.first { $0.id == .fileRead }?.detail.contains("native file picker grants") == true)
    #expect(snapshot.permissions.first { $0.id == .fileWrite }?.detail.contains("native save-panel grants") == true)
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
func bridgeDispatcherReturnsToolsList() async throws {
    let harness = makeHarness()
    let dispatcher = InputoNativeBridgeDispatcher(appState: harness.state)

    let response = try await dispatch(
        tool: .toolsList,
        id: "tools-request",
        dispatcher: dispatcher,
        payloadType: [InputoNativeToolDescriptor].self
    )

    #expect(response.id == "tools-request")
    #expect(response.ok == true)
    #expect(response.payload?.map(\.id) == InputoNativeToolDescriptor.v1DefaultTools.map(\.id))
    #expect(response.error == nil)
}

@MainActor
@Test
func bridgeDispatcherReturnsComposerSettingsAndPermissionsSnapshots() async throws {
    let settings = AppSettings(
        provider: AIProviderConfig(
            baseURL: "https://provider.example",
            model: "inputo-test",
            timeoutSeconds: 20,
            headers: ["X-Provider-Token": "header-secret"]
        ),
        hotKey: nil,
        customPresets: []
    )
    let harness = makeHarness(settings: settings, apiKey: "stored-api-key")
    harness.state.inputText = "Draft"
    harness.state.instruction = "Make it warmer"
    harness.state.outputText = "Generated"
    let dispatcher = InputoNativeBridgeDispatcher(appState: harness.state)

    let composer = try await dispatch(
        tool: .composerGetState,
        id: "composer-request",
        dispatcher: dispatcher,
        payloadType: InputoComposerSnapshot.self
    )
    let settingsSummary = try await dispatch(
        tool: .settingsSummary,
        id: "settings-request",
        dispatcher: dispatcher,
        payloadType: InputoSettingsSummary.self
    )
    let permissions = try await dispatch(
        tool: .permissionsStatus,
        id: "permissions-request",
        dispatcher: dispatcher,
        payloadType: [InputoPermissionSnapshot].self
    )
    let appSnapshot = try await dispatch(
        tool: .appSnapshot,
        id: "app-snapshot-request",
        dispatcher: dispatcher,
        payloadType: InputoNativeExecutorSnapshot.self
    )
    let settingsJSON = try await responseJSON(
        tool: .settingsSummary,
        id: "settings-json-request",
        dispatcher: dispatcher
    )
    let appSnapshotJSON = try await responseJSON(
        tool: .appSnapshot,
        id: "app-snapshot-json-request",
        dispatcher: dispatcher
    )

    #expect(composer.payload?.draftText == "Draft")
    #expect(composer.payload?.generatedOutput == "Generated")
    #expect(settingsSummary.payload?.provider.hasAPIKey == true)
    #expect(settingsSummary.payload?.provider.endpointPreview == "https://provider.example/v1/chat/completions")
    #expect(permissions.payload?.contains { $0.id == .screenRecording && $0.state == .notRequested } == true)
    #expect(appSnapshot.payload?.composer.draftText == "Draft")
    #expect(appSnapshot.payload?.recipes.map(\.id).contains("polish") == true)
    #expect(appSnapshot.payload?.tools.map(\.id).contains(.appSnapshot) == true)
    #expect(settingsJSON.contains("stored-api-key") == false)
    #expect(settingsJSON.contains("header-secret") == false)
    #expect(appSnapshotJSON.contains("stored-api-key") == false)
    #expect(appSnapshotJSON.contains("header-secret") == false)
    #expect(appSnapshotJSON.contains("windowTitle") == false)
}

@MainActor
@Test
func bridgeDispatcherRejectsUnsupportedVersionUnknownToolAndPolicyViolations() async throws {
    let harness = makeHarness()
    let dispatcher = InputoNativeBridgeDispatcher(appState: harness.state)

    let unsupportedVersion = try await errorResponse(
        """
        {"version":999,"id":"old-request","type":"tool.call","tool":"tools.list","payload":{}}
        """,
        dispatcher: dispatcher
    )
    let unknownTool = try await errorResponse(
        """
        {"version":1,"id":"unknown-request","type":"tool.call","tool":"native.runShell","payload":{}}
        """,
        dispatcher: dispatcher
    )
    let missingUserAction = try await errorResponse(
        try request(
            tool: .llmChat,
            id: "llm-request",
            payload: InputoLLMChatRequest(
                draftText: "Draft",
                instruction: "",
                recipeID: "polish"
            )
        ),
        dispatcher: dispatcher
    )
    let deferredNetwork = try await errorResponse(
        try request(
            tool: .networkFetch,
            id: "network-request",
            context: .confirmedUserAction,
            payload: InputoEmptyPayload()
        ),
        dispatcher: InputoNativeBridgeDispatcher(appState: harness.state, agentMode: .assistedWorkflow)
    )

    #expect(unsupportedVersion.ok == false)
    #expect(unsupportedVersion.error?.code == .unsupportedVersion)
    #expect(unknownTool.ok == false)
    #expect(unknownTool.error?.code == .unknownTool)
    #expect(missingUserAction.ok == false)
    #expect(missingUserAction.error?.code == .permissionDenied)
    #expect(deferredNetwork.ok == false)
    #expect(deferredNetwork.error?.code == .policyViolation)
}

@MainActor
@Test
func bridgeDispatcherRunsComposerClipboardSettingsAndAnchorTools() async throws {
    let anchor = makeAnchor(id: "notes", appName: "Notes", pid: 42)
    let harness = makeHarness()
    harness.anchors.availableAnchors = [anchor]
    harness.state.outputText = "Generated"
    var didOpenSettings = false
    let didRequestHide = ThreadSafeFlag()
    harness.state.onRequestSettings = { didOpenSettings = true }
    let hideObserver = NotificationCenter.default.addObserver(
        forName: .inputoHideComposer,
        object: nil,
        queue: nil
    ) { _ in
        didRequestHide.set()
    }
    defer {
        NotificationCenter.default.removeObserver(hideObserver)
    }
    let dispatcher = InputoNativeBridgeDispatcher(appState: harness.state)

    let draft = try await dispatch(
        tool: .composerSetDraft,
        id: "draft-request",
        dispatcher: dispatcher,
        payload: InputoComposerSetDraftRequest(draftText: "New draft"),
        payloadType: InputoComposerSnapshot.self
    )
    let instruction = try await dispatch(
        tool: .composerSetInstruction,
        id: "instruction-request",
        dispatcher: dispatcher,
        payload: InputoComposerSetInstructionRequest(instruction: "New instruction"),
        payloadType: InputoComposerSnapshot.self
    )
    let recipe = try await dispatch(
        tool: .composerSelectRecipe,
        id: "recipe-request",
        dispatcher: dispatcher,
        payload: InputoComposerSelectRecipeRequest(recipeID: "translate-en"),
        payloadType: InputoComposerSnapshot.self
    )
    let copy = try await dispatch(
        tool: .clipboardCopyGeneratedOutput,
        id: "copy-request",
        dispatcher: dispatcher,
        context: .userInitiated,
        payloadType: InputoComposerSnapshot.self
    )
    let anchors = try await dispatch(
        tool: .appAnchorsList,
        id: "anchors-request",
        dispatcher: dispatcher,
        payloadType: [InputoAppAnchorSnapshot].self
    )
    let activation = try await dispatch(
        tool: .appAnchorsActivate,
        id: "activate-request",
        dispatcher: dispatcher,
        context: .userInitiated,
        payload: InputoAppAnchorActivateRequest(anchorID: anchor.id),
        payloadType: [InputoAppAnchorSnapshot].self
    )
    let settings = try await dispatch(
        tool: .settingsOpen,
        id: "settings-open-request",
        dispatcher: dispatcher,
        context: .userInitiated,
        payloadType: InputoSettingsSummary.self
    )
    let hide = try await dispatch(
        tool: .appHideComposer,
        id: "hide-composer-request",
        dispatcher: dispatcher,
        context: .userInitiated,
        payloadType: InputoComposerSnapshot.self
    )
    let clear = try await dispatch(
        tool: .composerClear,
        id: "clear-request",
        dispatcher: dispatcher,
        context: .userInitiated,
        payloadType: InputoComposerSnapshot.self
    )

    #expect(draft.payload?.draftText == "New draft")
    #expect(instruction.payload?.instruction == "New instruction")
    #expect(recipe.payload?.selectedRecipeID == "translate-en")
    #expect(copy.ok == true)
    #expect(harness.clipboard.copiedTexts == ["Generated"])
    #expect(anchors.payload?.first?.id == anchor.id)
    #expect(activation.ok == true)
    #expect(harness.anchors.activatedAnchors == [anchor])
    #expect(settings.ok == true)
    #expect(didOpenSettings == true)
    #expect(hide.ok == true)
    #expect(didRequestHide.value == true)
    #expect(clear.payload?.draftText.isEmpty == true)
    #expect(clear.payload?.generatedOutput.isEmpty == true)
}

@MainActor
@Test
func bridgeDispatcherRunsLLMChatWithoutCopying() async throws {
    let harness = makeHarness(providerResult: .success("Generated by bridge"))
    let dispatcher = InputoNativeBridgeDispatcher(appState: harness.state)

    let response = try await dispatch(
        tool: .llmChat,
        id: "llm-chat-request",
        dispatcher: dispatcher,
        context: .userInitiated,
        payload: InputoLLMChatRequest(
            draftText: "Draft",
            instruction: "Make it warmer",
            recipeID: "polish"
        ),
        payloadType: InputoLLMChatResponse.self
    )

    #expect(response.ok == true)
    #expect(response.payload?.generatedOutput == "Generated by bridge")
    #expect(harness.provider.requests.first?.text == "Draft")
    #expect(harness.provider.requests.first?.instruction == "Make it warmer")
    #expect(harness.clipboard.copiedTexts.isEmpty)
}

@MainActor
@Test
func bridgeDispatcherStreamsLLMEventsAndCoalescedDelta() async throws {
    let harness = makeHarness(
        providerResult: .success("Generated stream output"),
        providerStreamChunks: ["Generated ", "stream ", "output"]
    )
    let events = ThreadSafeStrings()
    let emitter = InputoBridgeEventEmitter { data in
        events.append(String(decoding: data, as: UTF8.self))
    }
    let dispatcher = InputoNativeBridgeDispatcher(appState: harness.state, eventEmitter: emitter)

    let response = try await dispatch(
        tool: .llmStream,
        id: "llm-stream-request",
        dispatcher: dispatcher,
        context: .userInitiated,
        payload: InputoLLMChatRequest(
            draftText: "Draft",
            instruction: "",
            recipeID: "polish"
        ),
        payloadType: InputoLLMChatResponse.self
    )

    #expect(response.ok == true)
    #expect(events.values.contains { $0.contains(#""event":"llm.started""#) })
    #expect(events.values.contains { $0.contains(#""event":"llm.delta""#) && $0.contains("Generated stream output") })
    #expect(events.values.contains { $0.contains(#""event":"llm.completed""#) })
}

@MainActor
@Test
func nativeCommandRunsBuiltInRecipeAndPublishesPreviewEvents() async throws {
    let harness = makeHarness(
        providerResult: .success("Polished output"),
        providerStreamChunks: ["Polished ", "output"]
    )
    let events = ThreadSafeStrings()
    let observer = NotificationCenter.default.addObserver(
        forName: .inputoPreviewBridgeEvent,
        object: nil,
        queue: nil
    ) { notification in
        if let data = notification.object as? Data {
            events.append(String(decoding: data, as: UTF8.self))
        }
    }
    defer {
        NotificationCenter.default.removeObserver(observer)
    }

    harness.state.commandText = "/polish Draft text"
    await harness.state.submitCommandInput().value

    let request = try #require(harness.provider.requests.first)
    #expect(request.text == "Draft text")
    #expect(request.instruction == "")
    #expect(request.recipe.id == "polish")
    #expect(harness.state.outputText == "Polished output")
    #expect(events.values.contains { $0.contains(#""event":"llm.started""#) })
    #expect(events.values.contains { $0.contains(#""event":"llm.delta""#) && $0.contains("Polished output") })
    #expect(events.values.contains { $0.contains(#""event":"llm.completed""#) })
}

@MainActor
@Test
func nativeCommandForwardsUnknownCommandToWebWithoutProviderRequest() async {
    let harness = makeHarness()
    let events = ThreadSafeStrings()
    let observer = NotificationCenter.default.addObserver(
        forName: .inputoPreviewBridgeEvent,
        object: nil,
        queue: nil
    ) { notification in
        if let data = notification.object as? Data {
            events.append(String(decoding: data, as: UTF8.self))
        }
    }
    defer {
        NotificationCenter.default.removeObserver(observer)
    }

    harness.state.commandText = "/custom Build a weather widget"
    await harness.state.submitCommandInput().value

    #expect(harness.provider.requests.isEmpty)
    #expect(harness.state.inputText == "Build a weather widget")
    #expect(harness.state.statusMessage == "Sent /custom to Web.")
    #expect(events.values.contains { $0.contains(#""event":"command.received""#) })
    #expect(events.values.contains { $0.contains(#""commandName":"custom""#) })
    #expect(events.values.contains { $0.contains("Build a weather widget") })
}

@MainActor
@Test
func bridgeHostForwardsMessagesThroughHostBoundary() async throws {
    let harness = makeHarness()
    let dispatcher = InputoNativeBridgeDispatcher(appState: harness.state)
    let host: any InputoNativeBridgeMessageHandling = InputoNativeBridgeHost(dispatcher: dispatcher)

    let responseJSON = await host.receiveBridgeMessage(
        try request(tool: .toolsList, id: "host-tools-request", payload: InputoEmptyPayload())
    )
    let response = try JSONDecoder().decode(
        InputoBridgeToolResultEnvelope<[InputoNativeToolDescriptor]>.self,
        from: Data(responseJSON.utf8)
    )

    #expect(response.id == "host-tools-request")
    #expect(response.payload?.map(\.id) == InputoNativeToolDescriptor.v1DefaultTools.map(\.id))
}

@MainActor
@Test
func bridgeDispatcherRejectsMalformedPayloadDuplicateRequestIDAndMissingCancelTarget() async throws {
    let provider = ControlledTextTransformer()
    let state = AppState(
        services: AppStateServices(
            settings: FakeSettingsService(settings: .default),
            apiKeys: FakeAPIKeyService(apiKey: "test-key"),
            clipboard: FakeClipboardService(),
            anchors: FakeAnchorService(),
            textTransformer: provider
        )
    )
    let dispatcher = InputoNativeBridgeDispatcher(appState: state)

    let malformed = try await errorResponse(
        """
        {"version":1,"id":"bad-draft","type":"tool.call","tool":"composer.setDraft","payload":{}}
        """,
        dispatcher: dispatcher
    )

    let llmJSON = try request(
        tool: .llmChat,
        id: "duplicate-request",
        context: .userInitiated,
        payload: InputoLLMChatRequest(draftText: "Draft", instruction: "", recipeID: "polish")
    )
    let firstTask = Task { @MainActor in
        await dispatcher.dispatch(llmJSON)
    }
    await provider.waitForRequest()
    let duplicate = try await errorResponse(llmJSON, dispatcher: dispatcher)

    let cancelMissing = InputoBridgeCancelEnvelope(
        id: "cancel-missing",
        requestID: "not-active",
        reason: nil
    )
    let cancelMissingResponse = try JSONDecoder().decode(
        InputoBridgeToolResultEnvelope<InputoToolCancelResponse>.self,
        from: await dispatcher.dispatch(try JSONEncoder().encode(cancelMissing))
    )

    provider.complete(with: "Generated")
    _ = await firstTask.value

    #expect(malformed.error?.code == .invalidRequest)
    #expect(malformed.error?.field == "payload")
    #expect(duplicate.error?.code == .invalidRequest)
    #expect(cancelMissingResponse.payload?.didCancel == false)
}

@MainActor
@Test
func bridgeDispatcherCancelsTrackedLLMRequestByRequestID() async throws {
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
    let dispatcher = InputoNativeBridgeDispatcher(appState: state)
    let llmJSON = try request(
        tool: .llmChat,
        id: "long-llm-request",
        context: .userInitiated,
        payload: InputoLLMChatRequest(draftText: "Draft", instruction: "", recipeID: "polish")
    )

    let llmTask = Task { @MainActor in
        await dispatcher.dispatch(llmJSON)
    }
    await provider.waitForRequest()

    let cancelJSON = InputoBridgeCancelEnvelope(
        id: "cancel-request",
        requestID: "long-llm-request",
        reason: "test"
    )
    let cancelData = try JSONEncoder().encode(cancelJSON)
    let cancelResponse = try JSONDecoder().decode(
        InputoBridgeToolResultEnvelope<InputoToolCancelResponse>.self,
        from: await dispatcher.dispatch(cancelData)
    )

    provider.complete(with: "Late result")
    let llmResponse = try JSONDecoder().decode(
        InputoBridgeToolResultEnvelope<InputoEmptyPayload>.self,
        from: Data((await llmTask.value).utf8)
    )

    #expect(cancelResponse.payload?.didCancel == true)
    #expect(llmResponse.ok == false)
    #expect(llmResponse.error?.code == .cancelled)
    #expect(state.outputText.isEmpty)
}

@MainActor
@Test
func bridgeDispatcherRunsGrantBasedFileToolsWithConfirmation() async throws {
    let fileTools = FakeFileToolService()
    let dispatcher = InputoNativeBridgeDispatcher(
        appState: makeHarness().state,
        agentMode: .assistedWorkflow,
        fileTools: fileTools,
        confirmationService: FakeConfirmationService(allows: true)
    )

    let readable = try await dispatch(
        tool: .filesPickReadable,
        id: "pick-readable-request",
        dispatcher: dispatcher,
        context: .userInitiated,
        payload: InputoFilePickRequest(),
        payloadType: InputoFilePickResponse.self
    )
    let read = try await dispatch(
        tool: .filesReadText,
        id: "read-file-request",
        dispatcher: dispatcher,
        context: .userInitiated,
        payload: InputoFileReadTextRequest(grantID: "read-grant"),
        payloadType: InputoFileReadTextResponse.self
    )
    let writable = try await dispatch(
        tool: .filesPickWritable,
        id: "pick-writable-request",
        dispatcher: dispatcher,
        context: .userInitiated,
        payload: InputoFilePickRequest(suggestedFileName: "out.txt"),
        payloadType: InputoFilePickResponse.self
    )
    let writeJSON = try await responseJSON(
        tool: .filesWriteText,
        id: "write-file-request",
        dispatcher: dispatcher,
        context: .userInitiated,
        payload: InputoFileWriteTextRequest(grantID: "write-grant", text: "Saved", overwrite: true)
    )
    let write = try JSONDecoder().decode(
        InputoBridgeToolResultEnvelope<InputoFileWriteTextResponse>.self,
        from: Data(writeJSON.utf8)
    )

    #expect(readable.payload?.grants.first?.id == "read-grant")
    #expect(read.payload?.text == "File body")
    #expect(writable.payload?.grants.first?.id == "write-grant")
    #expect(write.payload?.byteCount == 5)
    #expect(fileTools.writtenText == "Saved")
    #expect(writeJSON.contains("/Users/") == false)
    #expect(writeJSON.contains("path") == false)
}

@MainActor
@Test
func bridgeDispatcherPropagatesFileToolErrorsSafely() async throws {
    let fileTools = FakeFileToolService()
    let dispatcher = InputoNativeBridgeDispatcher(
        appState: makeHarness().state,
        agentMode: .assistedWorkflow,
        fileTools: fileTools,
        confirmationService: FakeConfirmationService(allows: true)
    )

    let response = try await errorResponse(
        try request(
            tool: .filesReadText,
            id: "bad-grant-request",
            context: .userInitiated,
            payload: InputoFileReadTextRequest(grantID: "missing-grant")
        ),
        dispatcher: dispatcher
    )

    #expect(response.error?.code == .fileGrantInvalid)
    #expect(response.error?.message == "Invalid read grant.")
}

@MainActor
@Test
func bridgeDispatcherRejectsFileToolsWithoutAssistedModeOrConfirmation() async throws {
    let harness = makeHarness()
    let manualDispatcher = InputoNativeBridgeDispatcher(appState: harness.state)
    let assistedDispatcher = InputoNativeBridgeDispatcher(
        appState: harness.state,
        agentMode: .assistedWorkflow,
        fileTools: FakeFileToolService(),
        confirmationService: FakeConfirmationService(allows: false)
    )

    let unavailableInManual = try await errorResponse(
        try request(
            tool: .filesReadText,
            id: "manual-file-request",
            context: .confirmedUserAction,
            payload: InputoFileReadTextRequest(grantID: "read-grant")
        ),
        dispatcher: manualDispatcher
    )
    let deniedConfirmation = try await errorResponse(
        try request(
            tool: .filesReadText,
            id: "unconfirmed-file-request",
            context: .userInitiated,
            payload: InputoFileReadTextRequest(grantID: "read-grant")
        ),
        dispatcher: assistedDispatcher
    )

    #expect(unavailableInManual.error?.code == .permissionDenied)
    #expect(deniedConfirmation.error?.code == .permissionDenied)
}

@Test
func streamDeltaCoalescerBuffersSmallDeltas() {
    var coalescer = InputoStreamDeltaCoalescer(maxBufferedCharacters: 8)

    #expect(coalescer.append("hel").isEmpty)
    #expect(coalescer.append("lo").isEmpty)
    let first = coalescer.append("!!!")
    let final = coalescer.flush(isFinal: true)

    #expect(first == [InputoStreamDelta(text: "hello!!!", sequence: 0, isFinal: false)])
    #expect(final == nil)
}

@Test
func webComposerAssetsAreBundledAndRestrictNetwork() throws {
    let indexURL = try #require(InputoWebComposerAssets.indexURL)
    let html = try String(contentsOf: indexURL, encoding: .utf8)
    let assetDirectory = try #require(InputoWebComposerAssets.readAccessURL)
    let scriptURL = assetDirectory.appendingPathComponent("composer.js")
    let styleURL = assetDirectory.appendingPathComponent("composer.css")
    let script = try String(contentsOf: scriptURL, encoding: .utf8)
    let style = try String(contentsOf: styleURL, encoding: .utf8)

    #expect(InputoWebComposerAssets.areBundled == true)
    #expect(html.contains("script-src 'self'"))
    #expect(html.contains("connect-src 'none'"))
    #expect(html.contains("object-src 'none'"))
    #expect(html.contains("frame-src 'self' data: blob:"))
    #expect(html.contains("Inputo Composer"))
    #expect(html.contains(#"<script defer src="./composer.js"></script>"#))
    #expect(html.contains(#"<link rel="stylesheet" href="./composer.css">"#))
    #expect(html.contains("type=\"module\"") == false)
    #expect(html.contains("crossorigin") == false)
    #expect(InputoWebComposerAssets.remoteContentBlockRuleList.contains(#""url-filter": "https?://.*""#))
    #expect(InputoWebComposerAssets.remoteContentBlockRuleList.contains(#""type": "block""#))
    #expect(script.contains("InputoNativeThemeSet"))
    #expect(script.contains("InputoNativeBridgeReceiveBase64"))
    #expect(script.contains("InputoComposerFocus"))
    #expect(script.contains("fetch(") == false)
    #expect(script.contains("localStorage") == false)
    #expect(script.contains("sessionStorage") == false)
    #expect(script.contains("indexedDB") == false)
    #expect(script.contains("navigator.serviceWorker") == false)
    #expect(script.contains("Network access is disabled in Inputo Preview Runtime V1."))
    #expect(script.contains("XMLHttpRequest"))
    #expect(script.contains("WebSocket"))
    #expect(script.contains("app.hideComposer"))
    #expect(script.contains("llm.stream"))
    #expect(script.contains("clipboard.copyGeneratedOutput"))
    let compactStyle = style.filter { !$0.isWhitespace }
    #expect(
        compactStyle.contains("background:transparent!important") ||
        compactStyle.contains("background:00!important")
    )
    #expect(compactStyle.contains("--panel:transparent;"))
    #expect(compactStyle.contains("--field:transparent;"))
    #expect(compactStyle.contains("--surface:"))
    #expect(compactStyle.contains("appearance:none"))
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
private func dispatch<Payload: Codable & Equatable & Sendable>(
    tool: InputoNativeToolID,
    id: String,
    dispatcher: InputoNativeBridgeDispatcher,
    context: InputoToolCallPolicyContext? = nil,
    payloadType _: Payload.Type
) async throws -> InputoBridgeToolResultEnvelope<Payload> {
    let json = try request(tool: tool, id: id, context: context, payload: InputoEmptyPayload())
    let response = await dispatcher.dispatch(json)
    return try JSONDecoder().decode(InputoBridgeToolResultEnvelope<Payload>.self, from: Data(response.utf8))
}

@MainActor
private func dispatch<RequestPayload: Codable & Equatable & Sendable, ResponsePayload: Codable & Equatable & Sendable>(
    tool: InputoNativeToolID,
    id: String,
    dispatcher: InputoNativeBridgeDispatcher,
    context: InputoToolCallPolicyContext? = nil,
    payload: RequestPayload,
    payloadType _: ResponsePayload.Type
) async throws -> InputoBridgeToolResultEnvelope<ResponsePayload> {
    let json = try request(tool: tool, id: id, context: context, payload: payload)
    let response = await dispatcher.dispatch(json)
    return try JSONDecoder().decode(InputoBridgeToolResultEnvelope<ResponsePayload>.self, from: Data(response.utf8))
}

@MainActor
private func errorResponse(
    _ json: String,
    dispatcher: InputoNativeBridgeDispatcher
) async throws -> InputoBridgeToolResultEnvelope<InputoEmptyPayload> {
    let response = await dispatcher.dispatch(json)
    return try JSONDecoder().decode(
        InputoBridgeToolResultEnvelope<InputoEmptyPayload>.self,
        from: Data(response.utf8)
    )
}

@MainActor
private func responseJSON<Payload: Codable & Equatable & Sendable>(
    tool: InputoNativeToolID,
    id: String,
    dispatcher: InputoNativeBridgeDispatcher,
    context: InputoToolCallPolicyContext? = nil,
    payload: Payload
) async throws -> String {
    await dispatcher.dispatch(try request(tool: tool, id: id, context: context, payload: payload))
}

@MainActor
private func responseJSON(
    tool: InputoNativeToolID,
    id: String,
    dispatcher: InputoNativeBridgeDispatcher
) async throws -> String {
    try await responseJSON(tool: tool, id: id, dispatcher: dispatcher, payload: InputoEmptyPayload())
}

private func request<Payload: Codable & Equatable & Sendable>(
    tool: InputoNativeToolID,
    id: String,
    context: InputoToolCallPolicyContext? = nil,
    payload: Payload
) throws -> String {
    let envelope = InputoBridgeToolCallEnvelope(id: id, tool: tool, context: context, payload: payload)
    let data = try JSONEncoder().encode(envelope)
    return String(decoding: data, as: UTF8.self)
}

@MainActor
private func makeHarness(
    settings: AppSettings = .default,
    apiKey: String = "test-key",
    providerResult: Result<String, Error> = .success("Generated"),
    providerStreamChunks: [String]? = nil
) -> AppStateHarness {
    let settingsService = FakeSettingsService(settings: settings)
    let apiKeyService = FakeAPIKeyService(apiKey: apiKey)
    let clipboard = FakeClipboardService()
    let anchors = FakeAnchorService()
    let provider = FakeTextTransformer(result: providerResult, streamChunks: providerStreamChunks)
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

private final class ThreadSafeStrings: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValues: [String] = []

    var values: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storedValues
    }

    func append(_ value: String) {
        lock.lock()
        storedValues.append(value)
        lock.unlock()
    }
}

private final class ThreadSafeFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue = false

    var value: Bool {
        lock.lock()
        defer { lock.unlock() }
        return storedValue
    }

    func set() {
        lock.lock()
        storedValue = true
        lock.unlock()
    }
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

@MainActor
private final class FakeFileToolService: InputoFileToolServicing {
    private(set) var writtenText: String?

    func pickReadableFiles(_ request: InputoFilePickRequest) async throws -> InputoFilePickResponse {
        InputoFilePickResponse(
            grants: [
                InputoFileGrantSnapshot(
                    id: "read-grant",
                    scope: .read,
                    displayName: "draft.txt",
                    contentType: "public.text",
                    byteCount: 9,
                    expiresAt: nil
                )
            ]
        )
    }

    func readText(_ request: InputoFileReadTextRequest) async throws -> InputoFileReadTextResponse {
        guard request.grantID == "read-grant" else {
            throw InputoNativeToolError(code: .fileGrantInvalid, message: "Invalid read grant.")
        }
        return InputoFileReadTextResponse(
            grantID: request.grantID,
            displayName: "draft.txt",
            text: "File body",
            encoding: "utf-8"
        )
    }

    func pickWritableFile(_ request: InputoFilePickRequest) async throws -> InputoFilePickResponse {
        InputoFilePickResponse(
            grants: [
                InputoFileGrantSnapshot(
                    id: "write-grant",
                    scope: .write,
                    displayName: request.suggestedFileName ?? "output.txt",
                    contentType: "public.text",
                    byteCount: nil,
                    expiresAt: nil
                )
            ]
        )
    }

    func writeText(_ request: InputoFileWriteTextRequest) async throws -> InputoFileWriteTextResponse {
        guard request.grantID == "write-grant" else {
            throw InputoNativeToolError(code: .fileGrantInvalid, message: "Invalid write grant.")
        }
        writtenText = request.text
        return InputoFileWriteTextResponse(
            grantID: request.grantID,
            displayName: "output.txt",
            byteCount: request.text.utf8.count
        )
    }
}

@MainActor
private struct FakeConfirmationService: InputoNativeConfirmationServicing {
    var allows: Bool

    func confirm(_ request: InputoNativeConfirmationRequest) async -> Bool {
        allows
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
    var streamChunks: [String]?
    private(set) var requests: [TransformRequest] = []

    init(result: Result<String, Error>, streamChunks: [String]? = nil) {
        self.result = result
        self.streamChunks = streamChunks
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

    func streamText(
        text: String,
        instruction: String,
        recipe: TransformRecipe,
        config: AIProviderConfig,
        apiKey: String
    ) async throws -> AsyncThrowingStream<String, Error> {
        requests.append(
            TransformRequest(
                text: text,
                instruction: instruction,
                recipe: recipe,
                config: config,
                apiKey: apiKey
            )
        )

        if let streamChunks {
            return AsyncThrowingStream { continuation in
                for chunk in streamChunks {
                    continuation.yield(chunk)
                }
                continuation.finish()
            }
        }

        let output = try result.get()
        return AsyncThrowingStream { continuation in
            continuation.yield(output)
            continuation.finish()
        }
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
