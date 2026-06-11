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

public struct ValidatedAIProviderConfig: Equatable, Sendable {
    public let baseURL: URL
    public let chatCompletionsURL: URL
    public let model: String
    public let timeoutSeconds: Double
    public let headers: [String: String]
}

extension AIProviderConfig {
    public func validated() throws -> ValidatedAIProviderConfig {
        let trimmedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBaseURL.isEmpty,
              let components = URLComponents(string: trimmedBaseURL),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host?.isEmpty == false,
              let url = components.url else {
            throw AIProviderError.invalidBaseURL
        }

        guard components.query == nil, components.fragment == nil else {
            throw AIProviderError.invalidBaseURL
        }

        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedModel.isEmpty else {
            throw AIProviderError.invalidModel
        }

        guard timeoutSeconds.isFinite, timeoutSeconds >= 1, timeoutSeconds <= 300 else {
            throw AIProviderError.invalidTimeout
        }

        let validatedHeaders = try headers.reduce(into: [String: String]()) { result, entry in
            let key = entry.key.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else {
                throw AIProviderError.invalidHeader("Header names cannot be empty.")
            }
            guard key.localizedCaseInsensitiveCompare("Authorization") != .orderedSame else {
                throw AIProviderError.invalidHeader("Authorization is managed by Inputo.")
            }
            guard key.rangeOfCharacter(from: CharacterSet(charactersIn: ":\r\n")) == nil else {
                throw AIProviderError.invalidHeader("Header names cannot contain colons or line breaks.")
            }
            guard value.rangeOfCharacter(from: CharacterSet(charactersIn: "\r\n")) == nil else {
                throw AIProviderError.invalidHeader("Header values cannot contain line breaks.")
            }
            result[key] = value
        }

        return ValidatedAIProviderConfig(
            baseURL: url,
            chatCompletionsURL: chatCompletionsURL(for: url),
            model: trimmedModel,
            timeoutSeconds: timeoutSeconds,
            headers: validatedHeaders
        )
    }

    public var validationErrorDescription: String? {
        do {
            _ = try validated()
            return nil
        } catch {
            return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func chatCompletionsURL(for baseURL: URL) -> URL {
        let pathComponents = baseURL.pathComponents.filter { $0 != "/" }
        if pathComponents.last == "v1" {
            return baseURL
                .appendingPathComponent("chat")
                .appendingPathComponent("completions")
        }

        return baseURL
            .appendingPathComponent("v1")
            .appendingPathComponent("chat")
            .appendingPathComponent("completions")
    }
}
