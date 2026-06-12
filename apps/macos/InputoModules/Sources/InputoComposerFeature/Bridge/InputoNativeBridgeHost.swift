import Foundation

@MainActor
public protocol InputoNativeBridgeMessageHandling {
    func receiveBridgeMessage(_ data: Data) async -> Data
    func receiveBridgeMessage(_ json: String) async -> String
}

@MainActor
public final class InputoNativeBridgeHost: InputoNativeBridgeMessageHandling {
    private let handler: any InputoNativeBridgeMessageHandling

    public init(handler: any InputoNativeBridgeMessageHandling) {
        self.handler = handler
    }

    public convenience init(dispatcher: InputoNativeBridgeDispatcher) {
        self.init(handler: dispatcher)
    }

    public func receiveBridgeMessage(_ data: Data) async -> Data {
        await handler.receiveBridgeMessage(data)
    }

    public func receiveBridgeMessage(_ json: String) async -> String {
        await handler.receiveBridgeMessage(json)
    }
}

extension InputoNativeBridgeDispatcher: InputoNativeBridgeMessageHandling {
    public func receiveBridgeMessage(_ data: Data) async -> Data {
        await dispatch(data)
    }

    public func receiveBridgeMessage(_ json: String) async -> String {
        await dispatch(json)
    }
}
