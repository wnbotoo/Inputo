import Foundation

public struct AIProviderClient: Sendable {
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
        let validatedConfig = try config.validated()
        let request = try makeChatCompletionsRequest(
            text: text,
            instruction: instruction,
            recipe: recipe,
            validatedConfig: validatedConfig,
            apiKey: apiKey,
            stream: false
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw mapURLError(error, endpoint: validatedConfig.chatCompletionsURL)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProviderError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            if let error = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                throw AIProviderError.provider(
                    redactSensitiveValues(
                        in: error.error.message,
                        apiKey: apiKey,
                        headers: validatedConfig.headers
                    )
                )
            }
            throw AIProviderError.httpStatus(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
            throw AIProviderError.emptyOutput
        }
        return content
    }

    public func streamTransform(
        text: String,
        instruction: String,
        recipe: TransformRecipe,
        config: AIProviderConfig,
        apiKey: String
    ) async throws -> AsyncThrowingStream<String, Error> {
        let validatedConfig = try config.validated()
        let request = try makeChatCompletionsRequest(
            text: text,
            instruction: instruction,
            recipe: recipe,
            validatedConfig: validatedConfig,
            apiKey: apiKey,
            stream: true
        )
        let session = session

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw AIProviderError.invalidResponse
                    }
                    guard (200..<300).contains(httpResponse.statusCode) else {
                        let body = try await collectData(from: bytes)
                        if let error = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: body) {
                            throw AIProviderError.provider(
                                redactSensitiveValues(
                                    in: error.error.message,
                                    apiKey: apiKey,
                                    headers: validatedConfig.headers
                                )
                            )
                        }
                        throw AIProviderError.httpStatus(httpResponse.statusCode)
                    }

                    var emittedOutput = false
                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        guard let chunk = try parseStreamingLine(line) else { continue }
                        if chunk.isDone { break }
                        if let text = chunk.text, !text.isEmpty {
                            emittedOutput = true
                            continuation.yield(text)
                        }
                    }

                    if !emittedOutput {
                        throw AIProviderError.emptyOutput
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: CancellationError())
                } catch let error as URLError {
                    continuation.finish(throwing: mapURLError(error, endpoint: validatedConfig.chatCompletionsURL))
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func makeChatCompletionsRequest(
        text: String,
        instruction: String,
        recipe: TransformRecipe,
        validatedConfig: ValidatedAIProviderConfig,
        apiKey: String,
        stream: Bool
    ) throws -> URLRequest {
        var request = URLRequest(url: validatedConfig.chatCompletionsURL, timeoutInterval: validatedConfig.timeoutSeconds)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        for (key, value) in validatedConfig.headers {
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
            model: validatedConfig.model,
            messages: [
                .init(role: "system", content: """
                \(recipe.systemPrompt)
                \(recipe.outputHint)
                Return only the final transformed text. Do not explain your changes.
                """),
                .init(role: "user", content: userMessage)
            ],
            temperature: 0.4,
            stream: stream ? true : nil
        )
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }
}

public enum AIProviderError: LocalizedError, Equatable {
    case invalidBaseURL
    case invalidModel
    case invalidTimeout
    case invalidHeader(String)
    case cannotResolveHost(String)
    case network(String)
    case invalidResponse
    case httpStatus(Int)
    case provider(String)
    case emptyOutput
    case missingAPIKey

    public var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Provider base URL is invalid."
        case .invalidModel:
            return "Add a provider model before generating."
        case .invalidTimeout:
            return "Provider timeout must be between 1 and 300 seconds."
        case .invalidHeader(let message):
            return message
        case .cannotResolveHost(let host):
            return "Cannot resolve provider host: \(host). Check the Base URL, DNS, proxy, or network access."
        case .network(let message):
            return message
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

private func mapURLError(_ error: URLError, endpoint: URL) -> AIProviderError {
    switch error.code {
    case .cannotFindHost:
        return .cannotResolveHost(endpoint.host ?? endpoint.absoluteString)
    case .notConnectedToInternet:
        return .network("No internet connection is available.")
    case .timedOut:
        return .network("Provider request timed out.")
    case .cannotConnectToHost:
        return .network("Cannot connect to provider host: \(endpoint.host ?? endpoint.absoluteString).")
    default:
        return .network(error.localizedDescription)
    }
}

private func redactSensitiveValues(in message: String, apiKey: String, headers: [String: String]) -> String {
    let sensitiveValues = ([apiKey] + headers.compactMap { key, value in
        isSensitiveHeaderName(key) ? value : nil
    })
    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    .filter { $0.count >= 4 }

    return sensitiveValues.reduce(message) { redacted, value in
        redacted.replacingOccurrences(of: value, with: "[REDACTED]")
    }
}

private func isSensitiveHeaderName(_ name: String) -> Bool {
    let lowercased = name.lowercased()
    return lowercased.contains("authorization") ||
        lowercased.contains("api-key") ||
        lowercased.contains("token") ||
        lowercased.contains("secret") ||
        lowercased.contains("key")
}

private func collectData(from bytes: URLSession.AsyncBytes) async throws -> Data {
    var data = Data()
    for try await byte in bytes {
        data.append(byte)
    }
    return data
}

private struct StreamingLine {
    var text: String?
    var isDone: Bool
}

private func parseStreamingLine(_ line: String) throws -> StreamingLine? {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed.hasPrefix("data:") else { return nil }

    let payload = trimmed.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
    if payload == "[DONE]" {
        return StreamingLine(text: nil, isDone: true)
    }

    let data = Data(payload.utf8)
    let chunk = try JSONDecoder().decode(ChatCompletionStreamChunk.self, from: data)
    return StreamingLine(text: chunk.choices.first?.delta.content, isDone: false)
}

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [Message]
    let temperature: Double
    let stream: Bool?

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

private struct ChatCompletionStreamChunk: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let delta: Delta
    }

    struct Delta: Decodable {
        let content: String?
    }
}
