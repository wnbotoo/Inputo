import Foundation
import InputoCore

@MainActor
public struct InputoBridgeEventEmitter {
    public static let none = InputoBridgeEventEmitter { _ in }

    private let encoder: JSONEncoder
    private let emitData: (Data) -> Void

    public init(encoder: JSONEncoder = JSONEncoder(), emitData: @escaping (Data) -> Void) {
        self.encoder = encoder
        self.emitData = emitData
    }

    public func emit<Payload: Codable & Equatable & Sendable>(
        event: InputoToolEventName,
        requestID: String?,
        payload: Payload
    ) {
        let envelope = InputoBridgeEventEnvelope(
            event: event,
            requestID: requestID,
            payload: payload
        )
        guard let data = try? encoder.encode(envelope) else { return }
        emitData(data)
    }
}

public struct InputoStreamDeltaCoalescer {
    private var buffer = ""
    private var sequence = 0
    private let maxBufferedCharacters: Int

    public init(maxBufferedCharacters: Int = 256) {
        self.maxBufferedCharacters = max(1, maxBufferedCharacters)
    }

    public mutating func append(_ text: String) -> [InputoStreamDelta] {
        guard !text.isEmpty else { return [] }
        buffer += text
        guard buffer.count >= maxBufferedCharacters else { return [] }
        return flush(isFinal: false).map { [$0] } ?? []
    }

    public mutating func flush(isFinal: Bool) -> InputoStreamDelta? {
        guard !buffer.isEmpty else { return nil }
        defer {
            buffer = ""
            sequence += 1
        }
        return InputoStreamDelta(text: buffer, sequence: sequence, isFinal: isFinal)
    }
}
