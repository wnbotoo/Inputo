import Foundation
import InputoCore
import InputoMacPlatform

@MainActor
public protocol InputoFileToolServicing {
    func pickReadableFiles(_ request: InputoFilePickRequest) async throws -> InputoFilePickResponse
    func readText(_ request: InputoFileReadTextRequest) async throws -> InputoFileReadTextResponse
    func pickWritableFile(_ request: InputoFilePickRequest) async throws -> InputoFilePickResponse
    func writeText(_ request: InputoFileWriteTextRequest) async throws -> InputoFileWriteTextResponse
}

@MainActor
public final class InputoNativeBridgeDispatcher {
    private struct ActiveBridgeRequest {
        var toolID: InputoNativeToolID
        var task: Task<Data, Never>
    }

    private let appState: AppState
    private let agentMode: InputoAgentMode
    private let fileTools: any InputoFileToolServicing
    private let eventEmitter: InputoBridgeEventEmitter
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private var activeRequests: [String: ActiveBridgeRequest] = [:]

    public convenience init(
        appState: AppState,
        agentMode: InputoAgentMode = .manualTransform,
        eventEmitter: InputoBridgeEventEmitter = .none,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.init(
            appState: appState,
            agentMode: agentMode,
            fileTools: LiveBridgeFileToolService(),
            eventEmitter: eventEmitter,
            decoder: decoder,
            encoder: encoder
        )
    }

    public init(
        appState: AppState,
        agentMode: InputoAgentMode = .manualTransform,
        fileTools: any InputoFileToolServicing,
        eventEmitter: InputoBridgeEventEmitter = .none,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.appState = appState
        self.agentMode = agentMode
        self.fileTools = fileTools
        self.eventEmitter = eventEmitter
        self.decoder = decoder
        self.encoder = encoder
    }

    public func dispatch(_ json: String) async -> String {
        let response = await dispatch(Data(json.utf8))
        return String(decoding: response, as: UTF8.self)
    }

    public func dispatch(_ data: Data) async -> Data {
        let raw: RawBridgeEnvelope
        do {
            raw = try decoder.decode(RawBridgeEnvelope.self, from: data)
        } catch {
            return failure(
                id: "invalid-request",
                code: .invalidRequest,
                message: "Bridge message must be a valid envelope."
            )
        }

        let requestID = raw.id ?? "invalid-request"
        guard raw.version == InputoBridgeContract.version else {
            return failure(
                id: requestID,
                code: .unsupportedVersion,
                message: "Unsupported bridge contract version."
            )
        }

        if raw.type == InputoBridgeMessageType.toolCancel.rawValue {
            return handleCancelEnvelope(data, fallbackID: requestID)
        }

        guard raw.type == InputoBridgeMessageType.toolCall.rawValue else {
            return failure(
                id: requestID,
                code: .invalidRequest,
                message: "Bridge dispatcher only accepts tool.call and tool.cancel messages."
            )
        }

        guard let toolName = raw.tool, let toolID = InputoNativeToolID(rawValue: toolName) else {
            return failure(
                id: requestID,
                code: .unknownTool,
                message: "Unknown native tool: \(raw.tool ?? "missing")."
            )
        }

        guard let descriptor = InputoNativeToolDescriptor.v1DefaultTools.first(where: { $0.id == toolID }) else {
            return failure(
                id: requestID,
                code: .unknownTool,
                message: "Unknown native tool: \(toolID.rawValue)."
            )
        }

        if let policyError = policyError(for: descriptor, context: raw.context) {
            return failure(id: requestID, error: policyError)
        }

        switch toolID {
        case .toolsList:
            return success(id: requestID, payload: appState.nativeExecutorSnapshot(agentMode: agentMode).tools)
        case .composerGetState:
            return success(id: requestID, payload: appState.nativeExecutorSnapshot(agentMode: agentMode).composer)
        case .settingsSummary:
            return success(id: requestID, payload: appState.nativeExecutorSnapshot(agentMode: agentMode).settings)
        case .permissionsStatus:
            return success(id: requestID, payload: appState.nativeExecutorSnapshot(agentMode: agentMode).permissions)
        case .composerSetDraft:
            return handleComposerSetDraft(data, id: requestID)
        case .composerSelectRecipe:
            return handleComposerSelectRecipe(data, id: requestID)
        case .composerClear:
            appState.resetSession()
            return success(id: requestID, payload: appState.nativeExecutorSnapshot(agentMode: agentMode).composer)
        case .llmChat:
            return await runTracked(id: requestID, toolID: toolID) {
                await self.handleLLM(data, id: requestID, streams: false)
            }
        case .llmStream:
            return await runTracked(id: requestID, toolID: toolID) {
                await self.handleLLM(data, id: requestID, streams: true)
            }
        case .llmCancel:
            return handleLLMCancel(data, id: requestID)
        case .clipboardCopyGeneratedOutput:
            return handleClipboardCopy(id: requestID)
        case .appAnchorsList:
            appState.refreshAnchors()
            return success(id: requestID, payload: appState.nativeExecutorSnapshot(agentMode: agentMode).anchors)
        case .appAnchorsActivate:
            return handleAppAnchorActivate(data, id: requestID)
        case .settingsOpen:
            appState.openSettings()
            return success(id: requestID, payload: appState.nativeExecutorSnapshot(agentMode: agentMode).settings)
        case .permissionsRequest:
            return handlePermissionRequest(data, id: requestID)
        case .filesPickReadable:
            return await handleFileTool(id: requestID) {
                let request = try self.decodePayload(InputoFilePickRequest.self, from: data)
                return try await self.fileTools.pickReadableFiles(request)
            }
        case .filesReadText:
            return await handleFileTool(id: requestID) {
                let request = try self.decodePayload(InputoFileReadTextRequest.self, from: data)
                return try await self.fileTools.readText(request)
            }
        case .filesPickWritable:
            return await handleFileTool(id: requestID) {
                let request = try self.decodePayload(InputoFilePickRequest.self, from: data)
                return try await self.fileTools.pickWritableFile(request)
            }
        case .filesWriteText:
            return await handleFileTool(id: requestID) {
                let request = try self.decodePayload(InputoFileWriteTextRequest.self, from: data)
                return try await self.fileTools.writeText(request)
            }
        case .networkFetch:
            return failure(
                id: requestID,
                code: .policyViolation,
                message: "network.fetch is deferred until manifest-governed network policy is implemented."
            )
        }
    }

    private func runTracked(
        id: String,
        toolID: InputoNativeToolID,
        operation: @escaping @MainActor () async -> Data
    ) async -> Data {
        guard activeRequests[id] == nil else {
            return failure(
                id: id,
                code: .invalidRequest,
                message: "A bridge request with this id is already active."
            )
        }

        let task = Task { @MainActor in
            await operation()
        }
        activeRequests[id] = ActiveBridgeRequest(toolID: toolID, task: task)
        let response = await task.value
        activeRequests[id] = nil
        return response
    }

    private func cancelRequest(_ requestID: String) -> Bool {
        guard let active = activeRequests[requestID] else { return false }
        active.task.cancel()
        if active.toolID == .llmChat || active.toolID == .llmStream {
            appState.cancelActiveGeneration()
        }
        activeRequests[requestID] = nil
        return true
    }

    private func handleCancelEnvelope(_ data: Data, fallbackID: String) -> Data {
        do {
            let envelope = try decoder.decode(InputoBridgeCancelEnvelope.self, from: data)
            let didCancel = cancelRequest(envelope.requestID)
            return success(
                id: envelope.id,
                payload: InputoToolCancelResponse(requestID: envelope.requestID, didCancel: didCancel)
            )
        } catch {
            return failure(
                id: fallbackID,
                code: .invalidRequest,
                message: "tool.cancel messages must include a requestID."
            )
        }
    }

    private func handleComposerSetDraft(_ data: Data, id: String) -> Data {
        do {
            let request = try decodePayload(InputoComposerSetDraftRequest.self, from: data)
            appState.inputText = request.draftText
            appState.errorMessage = nil
            return success(id: id, payload: appState.nativeExecutorSnapshot(agentMode: agentMode).composer)
        } catch {
            return invalidPayload(id: id, field: "payload")
        }
    }

    private func handleComposerSelectRecipe(_ data: Data, id: String) -> Data {
        do {
            let request = try decodePayload(InputoComposerSelectRecipeRequest.self, from: data)
            guard appState.recipes.contains(where: { $0.id == request.recipeID }) else {
                return failure(
                    id: id,
                    code: .invalidRequest,
                    message: "Recipe is not available.",
                    field: "payload.recipeID"
                )
            }
            appState.selectedRecipeID = request.recipeID
            return success(id: id, payload: appState.nativeExecutorSnapshot(agentMode: agentMode).composer)
        } catch {
            return invalidPayload(id: id, field: "payload")
        }
    }

    private func handleLLM(_ data: Data, id: String, streams: Bool) async -> Data {
        let request: InputoLLMChatRequest
        do {
            request = try decodePayload(InputoLLMChatRequest.self, from: data)
        } catch {
            return invalidPayload(id: id, field: "payload")
        }

        guard applyLLMRequest(request, id: id) else {
            return failure(
                id: id,
                code: .invalidRequest,
                message: "Recipe is not available.",
                field: "payload.recipeID"
            )
        }

        emit(event: .llmStarted, requestID: id, payload: InputoEmptyPayload())
        let generationTask = appState.generate()
        await generationTask.value

        let snapshot = appState.nativeExecutorSnapshot(agentMode: agentMode).composer
        if Task.isCancelled {
            emit(event: .llmCancelled, requestID: id, payload: InputoEmptyPayload())
            return failure(id: id, code: .cancelled, message: "LLM request was cancelled.")
        }

        if let errorMessage = snapshot.errorMessage {
            let error = InputoNativeToolError(code: llmErrorCode(for: errorMessage), message: errorMessage)
            emit(event: .llmFailed, requestID: id, payload: error)
            return failure(id: id, error: error)
        }

        if streams {
            emitStreamDelta(output: snapshot.generatedOutput, requestID: id)
        }
        emit(event: .llmCompleted, requestID: id, payload: InputoEmptyPayload())
        return success(
            id: id,
            payload: InputoLLMChatResponse(generatedOutput: snapshot.generatedOutput, composer: snapshot)
        )
    }

    private func applyLLMRequest(_ request: InputoLLMChatRequest, id: String) -> Bool {
        guard appState.recipes.contains(where: { $0.id == request.recipeID }) else { return false }
        appState.inputText = request.draftText
        appState.instruction = request.instruction
        appState.selectedRecipeID = request.recipeID
        appState.errorMessage = nil
        appState.statusMessage = nil
        return true
    }

    private func emitStreamDelta(output: String, requestID: String) {
        var coalescer = InputoStreamDeltaCoalescer()
        for delta in coalescer.append(output) {
            emit(event: .llmDelta, requestID: requestID, payload: delta)
        }
        if let finalDelta = coalescer.flush(isFinal: true) {
            emit(event: .llmDelta, requestID: requestID, payload: finalDelta)
        }
    }

    private func handleLLMCancel(_ data: Data, id: String) -> Data {
        do {
            let request = try decodePayload(InputoToolCancelRequest.self, from: data)
            let didCancel = cancelRequest(request.requestID)
            return success(id: id, payload: InputoToolCancelResponse(requestID: request.requestID, didCancel: didCancel))
        } catch {
            return invalidPayload(id: id, field: "payload.requestID")
        }
    }

    private func handleClipboardCopy(id: String) -> Data {
        guard !appState.outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return failure(
                id: id,
                code: .clipboardEmptyOutput,
                message: "Generate a result before copying."
            )
        }
        appState.copyOutput()
        return success(id: id, payload: appState.nativeExecutorSnapshot(agentMode: agentMode).composer)
    }

    private func handleAppAnchorActivate(_ data: Data, id: String) -> Data {
        do {
            let request = try decodePayload(InputoAppAnchorActivateRequest.self, from: data)
            appState.refreshAnchors()
            guard let anchor = appState.anchors.first(where: { $0.id == request.anchorID }) else {
                return failure(
                    id: id,
                    code: .anchorUnavailable,
                    message: "The requested app anchor is no longer available.",
                    field: "payload.anchorID"
                )
            }
            guard appState.activate(anchor: anchor) else {
                return failure(
                    id: id,
                    code: .anchorUnavailable,
                    message: "Could not switch to \(anchor.appName). Please switch manually."
                )
            }
            return success(id: id, payload: appState.nativeExecutorSnapshot(agentMode: agentMode).anchors)
        } catch {
            return invalidPayload(id: id, field: "payload")
        }
    }

    private func handlePermissionRequest(_ data: Data, id: String) -> Data {
        do {
            let request = try decodePayload(InputoPermissionRequest.self, from: data)
            let permissions = appState.nativeExecutorSnapshot(agentMode: agentMode).permissions
            guard let permission = permissions.first(where: { $0.id == request.permissionID }) else {
                return failure(
                    id: id,
                    code: .invalidRequest,
                    message: "Permission is not known.",
                    field: "payload.permissionID"
                )
            }
            return success(id: id, payload: InputoPermissionResponse(permission: permission))
        } catch {
            return invalidPayload(id: id, field: "payload")
        }
    }

    private func handleFileTool<Payload: Codable & Equatable & Sendable>(
        id: String,
        operation: @escaping @MainActor () async throws -> Payload
    ) async -> Data {
        do {
            return success(id: id, payload: try await operation())
        } catch let error as InputoNativeToolError {
            return failure(id: id, error: error)
        } catch {
            return failure(
                id: id,
                code: .internalError,
                message: "File tool failed."
            )
        }
    }

    private func policyError(
        for descriptor: InputoNativeToolDescriptor,
        context: InputoToolCallPolicyContext?
    ) -> InputoNativeToolError? {
        guard descriptor.isAvailable(in: agentMode) else {
            return InputoNativeToolError(
                code: .permissionDenied,
                message: "\(descriptor.id.rawValue) is not allowed in \(agentMode.rawValue) mode."
            )
        }

        let context = context ?? .none
        if descriptor.requiresExplicitUserAction && !context.userAction {
            return InputoNativeToolError(
                code: .permissionDenied,
                message: "\(descriptor.id.rawValue) requires an explicit user action."
            )
        }

        if descriptor.requiresPerCallConfirmation && !context.confirmed {
            return InputoNativeToolError(
                code: .permissionDenied,
                message: "\(descriptor.id.rawValue) requires per-call confirmation."
            )
        }

        return nil
    }

    private func decodePayload<Payload: Codable & Equatable & Sendable>(
        _ type: Payload.Type,
        from data: Data
    ) throws -> Payload {
        try decoder.decode(InputoBridgeToolCallEnvelope<Payload>.self, from: data).payload
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

    private func emit<Payload: Codable & Equatable & Sendable>(
        event: InputoToolEventName,
        requestID: String,
        payload: Payload
    ) {
        eventEmitter.emit(event: event, requestID: requestID, payload: payload)
    }

    private func success<Payload: Codable & Equatable & Sendable>(id: String, payload: Payload) -> Data {
        encodeResult(
            InputoBridgeToolResultEnvelope(
                id: id,
                ok: true,
                payload: payload
            )
        )
    }

    private func invalidPayload(id: String, field: String) -> Data {
        failure(
            id: id,
            code: .invalidRequest,
            message: "Tool payload is invalid.",
            field: field
        )
    }

    private func failure(
        id: String,
        code: InputoNativeToolErrorCode,
        message: String,
        field: String? = nil,
        retryable: Bool = false
    ) -> Data {
        failure(
            id: id,
            error: InputoNativeToolError(
                code: code,
                message: message,
                field: field,
                retryable: retryable
            )
        )
    }

    private func failure(id: String, error: InputoNativeToolError) -> Data {
        encodeResult(
            InputoBridgeToolResultEnvelope<InputoEmptyPayload>(
                id: id,
                ok: false,
                error: error
            )
        )
    }

    private func encodeResult<Payload: Codable & Equatable & Sendable>(
        _ result: InputoBridgeToolResultEnvelope<Payload>
    ) -> Data {
        do {
            return try encoder.encode(result)
        } catch {
            return Data(
                """
                {"version":\(InputoBridgeContract.version),"id":"internal-error","type":"tool.result","ok":false,"error":{"code":"internal_error","message":"Bridge dispatcher failed to encode a response.","field":null,"retryable":false}}
                """.utf8
            )
        }
    }
}

private struct LiveBridgeFileToolService: InputoFileToolServicing {
    private let service = FileGrantService()

    func pickReadableFiles(_ request: InputoFilePickRequest) async throws -> InputoFilePickResponse {
        try service.pickReadableFiles(request)
    }

    func readText(_ request: InputoFileReadTextRequest) async throws -> InputoFileReadTextResponse {
        try service.readText(request)
    }

    func pickWritableFile(_ request: InputoFilePickRequest) async throws -> InputoFilePickResponse {
        try service.pickWritableFile(request)
    }

    func writeText(_ request: InputoFileWriteTextRequest) async throws -> InputoFileWriteTextResponse {
        try service.writeText(request)
    }
}

private struct RawBridgeEnvelope: Decodable {
    var version: Int?
    var id: String?
    var type: String?
    var tool: String?
    var context: InputoToolCallPolicyContext?
}
