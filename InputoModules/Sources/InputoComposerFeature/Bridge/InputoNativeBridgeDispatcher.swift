import Foundation
import InputoCore

@MainActor
public struct InputoNativeBridgeDispatcher {
    private let appState: AppState
    private let agentMode: InputoAgentMode
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(
        appState: AppState,
        agentMode: InputoAgentMode = .manualTransform,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.appState = appState
        self.agentMode = agentMode
        self.decoder = decoder
        self.encoder = encoder
    }

    public func dispatch(_ json: String) -> String {
        let response = dispatch(Data(json.utf8))
        return String(decoding: response, as: UTF8.self)
    }

    public func dispatch(_ data: Data) -> Data {
        let requestID: String
        let request: RawToolCallEnvelope
        do {
            request = try decoder.decode(RawToolCallEnvelope.self, from: data)
            requestID = request.id ?? "invalid-request"
        } catch {
            return failure(
                id: "invalid-request",
                code: .invalidRequest,
                message: "Bridge message must be a valid tool.call envelope."
            )
        }

        guard request.version == InputoBridgeContract.version else {
            return failure(
                id: requestID,
                code: .unsupportedVersion,
                message: "Unsupported bridge contract version.",
                retryable: false
            )
        }

        guard request.type == InputoBridgeMessageType.toolCall.rawValue else {
            return failure(
                id: requestID,
                code: .invalidRequest,
                message: "Bridge dispatcher only accepts tool.call messages."
            )
        }

        guard let toolName = request.tool, let toolID = InputoNativeToolID(rawValue: toolName) else {
            return failure(
                id: requestID,
                code: .unknownTool,
                message: "Unknown native tool: \(request.tool ?? "missing")."
            )
        }

        let snapshot = appState.nativeExecutorSnapshot(agentMode: agentMode)
        switch toolID {
        case .toolsList:
            return success(id: requestID, payload: snapshot.tools)
        case .composerGetState:
            return success(id: requestID, payload: snapshot.composer)
        case .settingsSummary:
            return success(id: requestID, payload: snapshot.settings)
        case .permissionsStatus:
            return success(id: requestID, payload: snapshot.permissions)
        default:
            return failure(
                id: requestID,
                code: .policyViolation,
                message: "\(toolID.rawValue) is declared but not implemented by this bridge dispatcher phase."
            )
        }
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

    private func failure(
        id: String,
        code: InputoNativeToolErrorCode,
        message: String,
        field: String? = nil,
        retryable: Bool = false
    ) -> Data {
        encodeResult(
            InputoBridgeToolResultEnvelope<InputoEmptyPayload>(
                id: id,
                ok: false,
                error: InputoNativeToolError(
                    code: code,
                    message: message,
                    field: field,
                    retryable: retryable
                )
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

private struct RawToolCallEnvelope: Decodable {
    var version: Int?
    var id: String?
    var type: String?
    var tool: String?
}
