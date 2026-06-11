import Foundation

public struct AIProviderClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func transform(
        text: String,
        instruction: String,
        recipe: TransformRecipe,
        config: AIProviderConfig,
        apiKey: String
    ) async throws -> String {
        guard let baseURL = URL(string: config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw AIProviderError.invalidBaseURL
        }

        let endpoint = baseURL.appendingPathComponent("v1/chat/completions")
        var request = URLRequest(url: endpoint, timeoutInterval: config.timeoutSeconds)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        for (key, value) in config.headers where !key.isEmpty {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let userMessage = """
        Transform this input for the user.

        Additional user instruction:
        \(instruction.isEmpty ? "None." : instruction)

        Input:
        \(text)
        """

        let body = ChatCompletionRequest(
            model: config.model,
            messages: [
                .init(role: "system", content: """
                \(recipe.systemPrompt)
                \(recipe.outputHint)
                Return only the final transformed text. Do not explain your changes.
                """),
                .init(role: "user", content: userMessage)
            ],
            temperature: 0.4
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProviderError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            if let error = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                throw AIProviderError.provider(error.error.message)
            }
            throw AIProviderError.httpStatus(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
            throw AIProviderError.emptyOutput
        }
        return content
    }
}

public enum AIProviderError: LocalizedError {
    case invalidBaseURL
    case invalidResponse
    case httpStatus(Int)
    case provider(String)
    case emptyOutput
    case missingAPIKey

    public var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Provider base URL is invalid."
        case .invalidResponse:
            return "Provider returned an invalid response."
        case .httpStatus(let status):
            return "Provider request failed with HTTP \(status)."
        case .provider(let message):
            return message
        case .emptyOutput:
            return "Provider returned an empty result."
        case .missingAPIKey:
            return "Add an API key in Settings before generating."
        }
    }
}

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [Message]
    let temperature: Double

    struct Message: Encodable {
        let role: String
        let content: String
    }
}

private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String
    }
}

private struct OpenAIErrorResponse: Decodable {
    let error: ErrorBody

    struct ErrorBody: Decodable {
        let message: String
    }
}
