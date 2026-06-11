import Foundation

public struct AIProviderConfig: Codable, Equatable, Sendable {
    public var baseURL: String
    public var model: String
    public var timeoutSeconds: Double
    public var headers: [String: String]

    public init(baseURL: String, model: String, timeoutSeconds: Double, headers: [String: String]) {
        self.baseURL = baseURL
        self.model = model
        self.timeoutSeconds = timeoutSeconds
        self.headers = headers
    }

    public static let `default` = AIProviderConfig(
        baseURL: "https://api.openai.com",
        model: "gpt-4.1-mini",
        timeoutSeconds: 45,
        headers: [:]
    )
}
