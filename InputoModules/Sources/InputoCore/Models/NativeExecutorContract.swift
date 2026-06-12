import Foundation

public enum InputoBridgeContract {
    public static let version = 1
}

public enum InputoAgentMode: String, Codable, Equatable, Sendable {
    case manualTransform = "manual_transform"
    case assistedWorkflow = "assisted_workflow"
    case liveAgent = "live_agent"

    public func allows(minimumMode: InputoAgentMode) -> Bool {
        priority >= minimumMode.priority
    }

    private var priority: Int {
        switch self {
        case .manualTransform:
            return 0
        case .assistedWorkflow:
            return 1
        case .liveAgent:
            return 2
        }
    }
}

public enum InputoBridgeMessageType: String, Codable, Equatable, Sendable {
    case toolCall = "tool.call"
    case toolResult = "tool.result"
    case event
    case toolCancel = "tool.cancel"
    case toolApprove = "tool.approve"
    case toolReject = "tool.reject"
}

public struct InputoToolCallPolicyContext: Codable, Equatable, Sendable {
    public var userAction: Bool
    public var confirmed: Bool

    public init(userAction: Bool = false, confirmed: Bool = false) {
        self.userAction = userAction
        self.confirmed = confirmed
    }

    public static let none = InputoToolCallPolicyContext()
    public static let userInitiated = InputoToolCallPolicyContext(userAction: true, confirmed: false)
    public static let confirmedUserAction = InputoToolCallPolicyContext(userAction: true, confirmed: true)
}

public enum InputoNativeToolID: String, Codable, CaseIterable, Identifiable, Equatable, Sendable {
    case composerGetState = "composer.getState"
    case composerSetDraft = "composer.setDraft"
    case composerSelectRecipe = "composer.selectRecipe"
    case composerClear = "composer.clear"
    case llmChat = "llm.chat"
    case llmStream = "llm.stream"
    case llmCancel = "llm.cancel"
    case clipboardCopyGeneratedOutput = "clipboard.copyGeneratedOutput"
    case appAnchorsList = "appAnchors.list"
    case appAnchorsActivate = "appAnchors.activate"
    case settingsOpen = "settings.open"
    case settingsSummary = "settings.summary"
    case permissionsStatus = "permissions.status"
    case permissionsRequest = "permissions.request"
    case filesPickReadable = "files.pickReadable"
    case filesReadText = "files.readText"
    case filesPickWritable = "files.pickWritable"
    case filesWriteText = "files.writeText"
    case networkFetch = "network.fetch"
    case toolsList = "tools.list"

    public var id: String {
        rawValue
    }
}

public enum InputoNativeToolEffect: String, Codable, Equatable, Sendable {
    case readState = "read_state"
    case writeTransientState = "write_transient_state"
    case providerNetwork = "provider_network"
    case clipboardWrite = "clipboard_write"
    case appActivation = "app_activation"
    case settings = "settings"
    case permissionPrompt = "permission_prompt"
    case filePicker = "file_picker"
    case fileRead = "file_read"
    case fileWrite = "file_write"
    case network = "network"
    case cancellation = "cancellation"
}

public struct InputoNativeToolDescriptor: Codable, Equatable, Identifiable, Sendable {
    public var id: InputoNativeToolID
    public var displayName: String
    public var description: String
    public var effect: InputoNativeToolEffect
    public var minimumAgentMode: InputoAgentMode
    public var requiresExplicitUserAction: Bool
    public var requiresPerCallConfirmation: Bool
    public var supportsCancellation: Bool
    public var streams: Bool

    public init(
        id: InputoNativeToolID,
        displayName: String,
        description: String,
        effect: InputoNativeToolEffect,
        minimumAgentMode: InputoAgentMode,
        requiresExplicitUserAction: Bool,
        requiresPerCallConfirmation: Bool,
        supportsCancellation: Bool,
        streams: Bool
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.effect = effect
        self.minimumAgentMode = minimumAgentMode
        self.requiresExplicitUserAction = requiresExplicitUserAction
        self.requiresPerCallConfirmation = requiresPerCallConfirmation
        self.supportsCancellation = supportsCancellation
        self.streams = streams
    }

    public func isAvailable(in mode: InputoAgentMode) -> Bool {
        mode.allows(minimumMode: minimumAgentMode)
    }
}

public extension InputoNativeToolDescriptor {
    static let v1DefaultTools: [InputoNativeToolDescriptor] = [
        InputoNativeToolDescriptor(
            id: .composerGetState,
            displayName: "Get Composer State",
            description: "Read the current transient composer state snapshot.",
            effect: .readState,
            minimumAgentMode: .manualTransform,
            requiresExplicitUserAction: false,
            requiresPerCallConfirmation: false,
            supportsCancellation: false,
            streams: false
        ),
        InputoNativeToolDescriptor(
            id: .composerSetDraft,
            displayName: "Set Draft",
            description: "Replace the current transient composer draft.",
            effect: .writeTransientState,
            minimumAgentMode: .manualTransform,
            requiresExplicitUserAction: false,
            requiresPerCallConfirmation: false,
            supportsCancellation: false,
            streams: false
        ),
        InputoNativeToolDescriptor(
            id: .composerSelectRecipe,
            displayName: "Select Recipe",
            description: "Select one of the current transform recipes.",
            effect: .writeTransientState,
            minimumAgentMode: .manualTransform,
            requiresExplicitUserAction: false,
            requiresPerCallConfirmation: false,
            supportsCancellation: false,
            streams: false
        ),
        InputoNativeToolDescriptor(
            id: .composerClear,
            displayName: "Clear Composer",
            description: "Clear the current transient composer session.",
            effect: .writeTransientState,
            minimumAgentMode: .manualTransform,
            requiresExplicitUserAction: true,
            requiresPerCallConfirmation: false,
            supportsCancellation: false,
            streams: false
        ),
        InputoNativeToolDescriptor(
            id: .llmChat,
            displayName: "Generate Text",
            description: "Ask native to run one OpenAI-compatible chat completion with stored provider settings.",
            effect: .providerNetwork,
            minimumAgentMode: .manualTransform,
            requiresExplicitUserAction: true,
            requiresPerCallConfirmation: false,
            supportsCancellation: true,
            streams: false
        ),
        InputoNativeToolDescriptor(
            id: .llmStream,
            displayName: "Stream Text",
            description: "Ask native to stream an OpenAI-compatible chat completion with stored provider settings.",
            effect: .providerNetwork,
            minimumAgentMode: .manualTransform,
            requiresExplicitUserAction: true,
            requiresPerCallConfirmation: false,
            supportsCancellation: true,
            streams: true
        ),
        InputoNativeToolDescriptor(
            id: .llmCancel,
            displayName: "Cancel Generation",
            description: "Cancel an in-flight native LLM request.",
            effect: .cancellation,
            minimumAgentMode: .manualTransform,
            requiresExplicitUserAction: false,
            requiresPerCallConfirmation: false,
            supportsCancellation: false,
            streams: false
        ),
        InputoNativeToolDescriptor(
            id: .clipboardCopyGeneratedOutput,
            displayName: "Copy Output",
            description: "Write the current generated output to the clipboard after an explicit Copy action.",
            effect: .clipboardWrite,
            minimumAgentMode: .manualTransform,
            requiresExplicitUserAction: true,
            requiresPerCallConfirmation: false,
            supportsCancellation: false,
            streams: false
        ),
        InputoNativeToolDescriptor(
            id: .appAnchorsList,
            displayName: "List App Anchors",
            description: "Read app-level jump anchors without window titles or screenshots.",
            effect: .readState,
            minimumAgentMode: .manualTransform,
            requiresExplicitUserAction: false,
            requiresPerCallConfirmation: false,
            supportsCancellation: false,
            streams: false
        ),
        InputoNativeToolDescriptor(
            id: .appAnchorsActivate,
            displayName: "Activate App Anchor",
            description: "Switch back to a selected app-level anchor.",
            effect: .appActivation,
            minimumAgentMode: .manualTransform,
            requiresExplicitUserAction: true,
            requiresPerCallConfirmation: false,
            supportsCancellation: false,
            streams: false
        ),
        InputoNativeToolDescriptor(
            id: .settingsOpen,
            displayName: "Open Settings",
            description: "Ask native to open the settings window.",
            effect: .settings,
            minimumAgentMode: .manualTransform,
            requiresExplicitUserAction: true,
            requiresPerCallConfirmation: false,
            supportsCancellation: false,
            streams: false
        ),
        InputoNativeToolDescriptor(
            id: .settingsSummary,
            displayName: "Read Settings Summary",
            description: "Read a non-secret settings summary.",
            effect: .readState,
            minimumAgentMode: .manualTransform,
            requiresExplicitUserAction: false,
            requiresPerCallConfirmation: false,
            supportsCancellation: false,
            streams: false
        ),
        InputoNativeToolDescriptor(
            id: .permissionsStatus,
            displayName: "Read Permission Status",
            description: "Read native permission and privacy status.",
            effect: .readState,
            minimumAgentMode: .manualTransform,
            requiresExplicitUserAction: false,
            requiresPerCallConfirmation: false,
            supportsCancellation: false,
            streams: false
        ),
        InputoNativeToolDescriptor(
            id: .permissionsRequest,
            displayName: "Request Permission",
            description: "Ask native to start a platform permission flow.",
            effect: .permissionPrompt,
            minimumAgentMode: .manualTransform,
            requiresExplicitUserAction: true,
            requiresPerCallConfirmation: true,
            supportsCancellation: false,
            streams: false
        ),
        InputoNativeToolDescriptor(
            id: .filesPickReadable,
            displayName: "Choose Readable File",
            description: "Ask native to open a file picker and issue an ephemeral read grant for one user-selected file.",
            effect: .filePicker,
            minimumAgentMode: .assistedWorkflow,
            requiresExplicitUserAction: true,
            requiresPerCallConfirmation: true,
            supportsCancellation: false,
            streams: false
        ),
        InputoNativeToolDescriptor(
            id: .filesReadText,
            displayName: "Read Text File",
            description: "Ask native to read text from a file grant issued by a native file picker.",
            effect: .fileRead,
            minimumAgentMode: .assistedWorkflow,
            requiresExplicitUserAction: true,
            requiresPerCallConfirmation: true,
            supportsCancellation: false,
            streams: false
        ),
        InputoNativeToolDescriptor(
            id: .filesPickWritable,
            displayName: "Choose Write Target",
            description: "Ask native to open a save panel and issue an ephemeral write grant for one user-approved file target.",
            effect: .filePicker,
            minimumAgentMode: .assistedWorkflow,
            requiresExplicitUserAction: true,
            requiresPerCallConfirmation: true,
            supportsCancellation: false,
            streams: false
        ),
        InputoNativeToolDescriptor(
            id: .filesWriteText,
            displayName: "Write Text File",
            description: "Ask native to write text to a file grant issued by a native save panel.",
            effect: .fileWrite,
            minimumAgentMode: .assistedWorkflow,
            requiresExplicitUserAction: true,
            requiresPerCallConfirmation: true,
            supportsCancellation: false,
            streams: false
        ),
        InputoNativeToolDescriptor(
            id: .networkFetch,
            displayName: "Fetch Network Resource",
            description: "Ask native to execute a manifest-governed network request.",
            effect: .network,
            minimumAgentMode: .assistedWorkflow,
            requiresExplicitUserAction: true,
            requiresPerCallConfirmation: true,
            supportsCancellation: true,
            streams: false
        ),
        InputoNativeToolDescriptor(
            id: .toolsList,
            displayName: "List Tools",
            description: "Read native-hosted tool descriptors and policies.",
            effect: .readState,
            minimumAgentMode: .manualTransform,
            requiresExplicitUserAction: false,
            requiresPerCallConfirmation: false,
            supportsCancellation: false,
            streams: false
        )
    ]
}

public enum InputoNativeToolErrorCode: String, Codable, Equatable, Sendable {
    case invalidRequest = "invalid_request"
    case unsupportedVersion = "unsupported_version"
    case unknownTool = "unknown_tool"
    case permissionDenied = "permission_denied"
    case policyViolation = "policy_violation"
    case cancellationUnsupported = "cancellation_unsupported"
    case cancelled
    case providerConfigurationInvalid = "provider_configuration_invalid"
    case missingAPIKey = "missing_api_key"
    case providerError = "provider_error"
    case networkUnavailable = "network_unavailable"
    case timeout
    case emptyOutput = "empty_output"
    case anchorUnavailable = "anchor_unavailable"
    case clipboardEmptyOutput = "clipboard_empty_output"
    case fileAccessDenied = "file_access_denied"
    case fileGrantInvalid = "file_grant_invalid"
    case fileTooLarge = "file_too_large"
    case fileUnsupportedEncoding = "file_unsupported_encoding"
    case fileReadFailed = "file_read_failed"
    case fileWriteFailed = "file_write_failed"
    case internalError = "internal_error"
}

public struct InputoNativeToolError: Codable, Equatable, LocalizedError, Sendable {
    public var code: InputoNativeToolErrorCode
    public var message: String
    public var field: String?
    public var retryable: Bool

    public init(
        code: InputoNativeToolErrorCode,
        message: String,
        field: String? = nil,
        retryable: Bool = false
    ) {
        self.code = code
        self.message = message
        self.field = field
        self.retryable = retryable
    }

    public var errorDescription: String? {
        message
    }
}

public extension InputoNativeToolError {
    static func from(_ error: AIProviderError) -> InputoNativeToolError {
        let message = error.errorDescription ?? "Provider request failed."
        switch error {
        case .invalidBaseURL, .invalidModel, .invalidTimeout, .invalidHeader:
            return InputoNativeToolError(code: .providerConfigurationInvalid, message: message)
        case .cannotResolveHost, .network:
            return InputoNativeToolError(code: .networkUnavailable, message: message, retryable: true)
        case .httpStatus, .provider, .invalidResponse:
            return InputoNativeToolError(code: .providerError, message: message, retryable: true)
        case .emptyOutput:
            return InputoNativeToolError(code: .emptyOutput, message: message)
        case .missingAPIKey:
            return InputoNativeToolError(code: .missingAPIKey, message: message)
        }
    }
}

public enum InputoToolEventName: String, Codable, Equatable, Sendable {
    case llmStarted = "llm.started"
    case llmDelta = "llm.delta"
    case llmCompleted = "llm.completed"
    case llmFailed = "llm.failed"
    case llmCancelled = "llm.cancelled"
    case toolStarted = "tool.started"
    case toolProgress = "tool.progress"
    case toolResultDelta = "tool.resultDelta"
    case toolCompleted = "tool.completed"
    case toolFailed = "tool.failed"
    case toolCancelled = "tool.cancelled"
}

public struct InputoStreamDelta: Codable, Equatable, Sendable {
    public var text: String
    public var sequence: Int
    public var isFinal: Bool

    public init(text: String, sequence: Int, isFinal: Bool = false) {
        self.text = text
        self.sequence = sequence
        self.isFinal = isFinal
    }
}

public struct InputoBridgeToolCallEnvelope<Payload: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public var version: Int
    public var id: String
    public var type: InputoBridgeMessageType
    public var tool: InputoNativeToolID
    public var context: InputoToolCallPolicyContext?
    public var payload: Payload

    public init(
        version: Int = InputoBridgeContract.version,
        id: String,
        type: InputoBridgeMessageType = .toolCall,
        tool: InputoNativeToolID,
        context: InputoToolCallPolicyContext? = nil,
        payload: Payload
    ) {
        self.version = version
        self.id = id
        self.type = type
        self.tool = tool
        self.context = context
        self.payload = payload
    }
}

public struct InputoBridgeToolResultEnvelope<Payload: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public var version: Int
    public var id: String
    public var type: InputoBridgeMessageType
    public var ok: Bool
    public var payload: Payload?
    public var error: InputoNativeToolError?

    public init(
        version: Int = InputoBridgeContract.version,
        id: String,
        type: InputoBridgeMessageType = .toolResult,
        ok: Bool,
        payload: Payload? = nil,
        error: InputoNativeToolError? = nil
    ) {
        self.version = version
        self.id = id
        self.type = type
        self.ok = ok
        self.payload = payload
        self.error = error
    }
}

public struct InputoBridgeEventEnvelope<Payload: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public var version: Int
    public var type: InputoBridgeMessageType
    public var event: InputoToolEventName
    public var requestID: String?
    public var payload: Payload

    public init(
        version: Int = InputoBridgeContract.version,
        type: InputoBridgeMessageType = .event,
        event: InputoToolEventName,
        requestID: String?,
        payload: Payload
    ) {
        self.version = version
        self.type = type
        self.event = event
        self.requestID = requestID
        self.payload = payload
    }
}

public struct InputoBridgeCancelEnvelope: Codable, Equatable, Sendable {
    public var version: Int
    public var id: String
    public var type: InputoBridgeMessageType
    public var requestID: String
    public var reason: String?

    public init(
        version: Int = InputoBridgeContract.version,
        id: String,
        type: InputoBridgeMessageType = .toolCancel,
        requestID: String,
        reason: String? = nil
    ) {
        self.version = version
        self.id = id
        self.type = type
        self.requestID = requestID
        self.reason = reason
    }
}

public struct InputoEmptyPayload: Codable, Equatable, Sendable {
    public init() {}
}

public struct InputoComposerSetDraftRequest: Codable, Equatable, Sendable {
    public var draftText: String

    public init(draftText: String) {
        self.draftText = draftText
    }
}

public struct InputoComposerSelectRecipeRequest: Codable, Equatable, Sendable {
    public var recipeID: String

    public init(recipeID: String) {
        self.recipeID = recipeID
    }
}

public struct InputoLLMChatRequest: Codable, Equatable, Sendable {
    public var draftText: String
    public var instruction: String
    public var recipeID: String

    public init(draftText: String, instruction: String, recipeID: String) {
        self.draftText = draftText
        self.instruction = instruction
        self.recipeID = recipeID
    }
}

public struct InputoLLMChatResponse: Codable, Equatable, Sendable {
    public var generatedOutput: String
    public var composer: InputoComposerSnapshot

    public init(generatedOutput: String, composer: InputoComposerSnapshot) {
        self.generatedOutput = generatedOutput
        self.composer = composer
    }
}

public struct InputoToolCancelRequest: Codable, Equatable, Sendable {
    public var requestID: String

    public init(requestID: String) {
        self.requestID = requestID
    }
}

public struct InputoToolCancelResponse: Codable, Equatable, Sendable {
    public var requestID: String
    public var didCancel: Bool

    public init(requestID: String, didCancel: Bool) {
        self.requestID = requestID
        self.didCancel = didCancel
    }
}

public struct InputoAppAnchorActivateRequest: Codable, Equatable, Sendable {
    public var anchorID: String

    public init(anchorID: String) {
        self.anchorID = anchorID
    }
}

public struct InputoPermissionRequest: Codable, Equatable, Sendable {
    public var permissionID: InputoPermissionID

    public init(permissionID: InputoPermissionID) {
        self.permissionID = permissionID
    }
}

public struct InputoPermissionResponse: Codable, Equatable, Sendable {
    public var permission: InputoPermissionSnapshot

    public init(permission: InputoPermissionSnapshot) {
        self.permission = permission
    }
}

public enum InputoFileGrantScope: String, Codable, Equatable, Sendable {
    case read
    case write
}

public struct InputoFilePickRequest: Codable, Equatable, Sendable {
    public var allowedContentTypes: [String]
    public var allowsMultipleSelection: Bool
    public var suggestedFileName: String?

    public init(
        allowedContentTypes: [String] = ["public.text"],
        allowsMultipleSelection: Bool = false,
        suggestedFileName: String? = nil
    ) {
        self.allowedContentTypes = allowedContentTypes
        self.allowsMultipleSelection = allowsMultipleSelection
        self.suggestedFileName = suggestedFileName
    }
}

public struct InputoFileGrantSnapshot: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var scope: InputoFileGrantScope
    public var displayName: String
    public var contentType: String?
    public var byteCount: Int?
    public var expiresAt: Date?

    public init(
        id: String,
        scope: InputoFileGrantScope,
        displayName: String,
        contentType: String?,
        byteCount: Int?,
        expiresAt: Date?
    ) {
        self.id = id
        self.scope = scope
        self.displayName = displayName
        self.contentType = contentType
        self.byteCount = byteCount
        self.expiresAt = expiresAt
    }
}

public struct InputoFilePickResponse: Codable, Equatable, Sendable {
    public var grants: [InputoFileGrantSnapshot]

    public init(grants: [InputoFileGrantSnapshot]) {
        self.grants = grants
    }
}

public struct InputoFileReadTextRequest: Codable, Equatable, Sendable {
    public var grantID: String
    public var maxBytes: Int
    public var encoding: String?

    public init(grantID: String, maxBytes: Int = 1_048_576, encoding: String? = nil) {
        self.grantID = grantID
        self.maxBytes = maxBytes
        self.encoding = encoding
    }
}

public struct InputoFileReadTextResponse: Codable, Equatable, Sendable {
    public var grantID: String
    public var displayName: String
    public var text: String
    public var encoding: String

    public init(grantID: String, displayName: String, text: String, encoding: String) {
        self.grantID = grantID
        self.displayName = displayName
        self.text = text
        self.encoding = encoding
    }
}

public struct InputoFileWriteTextRequest: Codable, Equatable, Sendable {
    public var grantID: String
    public var text: String
    public var encoding: String
    public var overwrite: Bool

    public init(grantID: String, text: String, encoding: String = "utf-8", overwrite: Bool = false) {
        self.grantID = grantID
        self.text = text
        self.encoding = encoding
        self.overwrite = overwrite
    }
}

public struct InputoFileWriteTextResponse: Codable, Equatable, Sendable {
    public var grantID: String
    public var displayName: String
    public var byteCount: Int

    public init(grantID: String, displayName: String, byteCount: Int) {
        self.grantID = grantID
        self.displayName = displayName
        self.byteCount = byteCount
    }
}

public enum InputoPermissionID: String, Codable, Equatable, Sendable {
    case providerNetwork = "provider.network"
    case clipboardWrite = "clipboard.write"
    case appAnchors = "appAnchors"
    case accessibility
    case screenRecording = "screenRecording"
    case fileRead = "file.read"
    case fileWrite = "file.write"
    case networkTools = "network.tools"
    case mcpTools = "mcp.tools"
}

public enum InputoPermissionState: String, Codable, Equatable, Sendable {
    case available
    case unavailable
    case notRequired = "not_required"
    case notRequested = "not_requested"
    case requiresUserAction = "requires_user_action"
    case denied
}

public struct InputoPermissionSnapshot: Codable, Equatable, Identifiable, Sendable {
    public var id: InputoPermissionID
    public var displayName: String
    public var state: InputoPermissionState
    public var detail: String

    public init(id: InputoPermissionID, displayName: String, state: InputoPermissionState, detail: String) {
        self.id = id
        self.displayName = displayName
        self.state = state
        self.detail = detail
    }
}

public struct InputoProviderSummary: Codable, Equatable, Sendable {
    public var baseURL: String
    public var model: String
    public var endpointPreview: String?
    public var hasAPIKey: Bool
    public var validationError: String?

    public init(
        baseURL: String,
        model: String,
        endpointPreview: String?,
        hasAPIKey: Bool,
        validationError: String?
    ) {
        self.baseURL = baseURL
        self.model = model
        self.endpointPreview = endpointPreview
        self.hasAPIKey = hasAPIKey
        self.validationError = validationError
    }
}

public struct InputoSettingsSummary: Codable, Equatable, Sendable {
    public var provider: InputoProviderSummary
    public var hasHotKey: Bool
    public var customRecipeCount: Int

    public init(provider: InputoProviderSummary, hasHotKey: Bool, customRecipeCount: Int) {
        self.provider = provider
        self.hasHotKey = hasHotKey
        self.customRecipeCount = customRecipeCount
    }
}

public struct InputoAppAnchorSnapshot: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var appName: String
    public var bundleIdentifier: String?
    public var processIdentifier: Int
    public var lastActiveAt: Date?
    public var canActivate: Bool

    public init(
        id: String,
        appName: String,
        bundleIdentifier: String?,
        processIdentifier: Int,
        lastActiveAt: Date?,
        canActivate: Bool
    ) {
        self.id = id
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
        self.lastActiveAt = lastActiveAt
        self.canActivate = canActivate
    }
}

public struct InputoComposerSnapshot: Codable, Equatable, Sendable {
    public var draftText: String
    public var instruction: String
    public var selectedRecipeID: String
    public var generatedOutput: String
    public var isGenerating: Bool
    public var canGenerate: Bool
    public var canCopy: Bool
    public var statusMessage: String?
    public var errorMessage: String?

    public init(
        draftText: String,
        instruction: String,
        selectedRecipeID: String,
        generatedOutput: String,
        isGenerating: Bool,
        canGenerate: Bool,
        canCopy: Bool,
        statusMessage: String?,
        errorMessage: String?
    ) {
        self.draftText = draftText
        self.instruction = instruction
        self.selectedRecipeID = selectedRecipeID
        self.generatedOutput = generatedOutput
        self.isGenerating = isGenerating
        self.canGenerate = canGenerate
        self.canCopy = canCopy
        self.statusMessage = statusMessage
        self.errorMessage = errorMessage
    }
}

public struct InputoNativeExecutorSnapshot: Codable, Equatable, Sendable {
    public var version: Int
    public var agentMode: InputoAgentMode
    public var composer: InputoComposerSnapshot
    public var settings: InputoSettingsSummary
    public var recipes: [TransformRecipe]
    public var anchors: [InputoAppAnchorSnapshot]
    public var permissions: [InputoPermissionSnapshot]
    public var tools: [InputoNativeToolDescriptor]

    public init(
        version: Int = InputoBridgeContract.version,
        agentMode: InputoAgentMode,
        composer: InputoComposerSnapshot,
        settings: InputoSettingsSummary,
        recipes: [TransformRecipe],
        anchors: [InputoAppAnchorSnapshot],
        permissions: [InputoPermissionSnapshot],
        tools: [InputoNativeToolDescriptor]
    ) {
        self.version = version
        self.agentMode = agentMode
        self.composer = composer
        self.settings = settings
        self.recipes = recipes
        self.anchors = anchors
        self.permissions = permissions
        self.tools = tools
    }
}
