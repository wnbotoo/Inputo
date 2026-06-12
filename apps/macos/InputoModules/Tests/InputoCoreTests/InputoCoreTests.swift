//
//  InputoCoreTests.swift
//  InputoModules
//
//  Created by Wenbo Tu on 6/11/26.
//

import Foundation
import InputoCore
import Testing

@Test
func providerConfigRoundTripsWithoutSecrets() throws {
    let config = AIProviderConfig(
        baseURL: "https://example.com",
        model: "inputo-test-model",
        timeoutSeconds: 30,
        headers: ["X-Test": "1"]
    )

    let data = try JSONEncoder().encode(config)
    let decoded = try JSONDecoder().decode(AIProviderConfig.self, from: data)

    #expect(decoded == config)
    #expect(String(decoding: data, as: UTF8.self).contains("apiKey") == false)
}

@Test
func builtInRecipesExposeStableIDs() {
    let ids = Set(TransformRecipe.builtIns.map(\.id))

    #expect(ids.contains("polish"))
    #expect(ids.contains("translate-en"))
    #expect(ids.contains("translate-zh"))
    #expect(ids.contains("emoji"))
    #expect(ids.contains("concise"))
}

@Test
func nativeExecutorContractEncodesVersionedToolCallEnvelope() throws {
    let envelope = InputoBridgeToolCallEnvelope(
        id: "request-1",
        tool: .llmChat,
        payload: InputoLLMChatRequest(
            draftText: "Hello",
            instruction: "Make it warmer",
            recipeID: "polish"
        )
    )

    let data = try JSONEncoder().encode(envelope)
    let decoded = try JSONDecoder().decode(
        InputoBridgeToolCallEnvelope<InputoLLMChatRequest>.self,
        from: data
    )
    let json = String(decoding: data, as: UTF8.self)

    #expect(decoded == envelope)
    #expect(decoded.version == InputoBridgeContract.version)
    #expect(json.contains(#""type":"tool.call""#))
    #expect(json.contains(#""tool":"llm.chat""#))
}

@Test
func nativeExecutorDefaultToolsAreConservativeInManualMode() throws {
    let tools = InputoNativeToolDescriptor.v1DefaultTools
    let toolIDs = Set(tools.map(\.id))

    #expect(toolIDs == Set(InputoNativeToolID.allCases))
    #expect(try #require(tools.first { $0.id == .llmStream }) .streams == true)
    #expect(try #require(tools.first { $0.id == .llmChat }) .supportsCancellation == true)
    #expect(try #require(tools.first { $0.id == .appHideComposer }) .requiresExplicitUserAction == true)
    #expect(try #require(tools.first { $0.id == .clipboardCopyGeneratedOutput }) .requiresExplicitUserAction == true)
    #expect(try #require(tools.first { $0.id == .appAnchorsActivate }) .requiresExplicitUserAction == true)
    #expect(try #require(tools.first { $0.id == .filesPickReadable }) .isAvailable(in: .manualTransform) == false)
    #expect(try #require(tools.first { $0.id == .filesReadText }) .requiresPerCallConfirmation == true)
    #expect(try #require(tools.first { $0.id == .filesPickWritable }) .isAvailable(in: .manualTransform) == false)
    #expect(try #require(tools.first { $0.id == .filesWriteText }) .requiresPerCallConfirmation == true)
    #expect(try #require(tools.first { $0.id == .networkFetch }) .isAvailable(in: .manualTransform) == false)
    #expect(try #require(tools.first { $0.id == .networkFetch }) .requiresPerCallConfirmation == true)
}

@Test
func nativeFileToolDTOsUseGrantsInsteadOfPaths() throws {
    let grant = InputoFileGrantSnapshot(
        id: "grant-1",
        scope: .read,
        displayName: "draft.txt",
        contentType: "public.text",
        byteCount: 42,
        expiresAt: nil
    )
    let response = InputoFileReadTextResponse(
        grantID: grant.id,
        displayName: grant.displayName,
        text: "Hello",
        encoding: "utf-8"
    )

    let data = try JSONEncoder().encode(response)
    let json = String(decoding: data, as: UTF8.self)
    let decoded = try JSONDecoder().decode(InputoFileReadTextResponse.self, from: data)

    #expect(decoded == response)
    #expect(json.contains("grant-1"))
    #expect(json.contains("draft.txt"))
    #expect(json.contains("path") == false)
    #expect(json.contains("/Users/") == false)
}

@Test
func nativeExecutorErrorsMapProviderFailuresToSafeCodes() {
    let missingKey = InputoNativeToolError.from(AIProviderError.missingAPIKey)
    let network = InputoNativeToolError.from(AIProviderError.cannotResolveHost("provider.example"))
    let invalidConfig = InputoNativeToolError.from(AIProviderError.invalidModel)

    #expect(missingKey.code == .missingAPIKey)
    #expect(missingKey.retryable == false)
    #expect(network.code == .networkUnavailable)
    #expect(network.retryable == true)
    #expect(invalidConfig.code == .providerConfigurationInvalid)
}

@Test
func providerConfigValidationBuildsChatCompletionsEndpoint() throws {
    let config = AIProviderConfig(
        baseURL: " https://provider.example/api/v1/ ",
        model: " inputo-test ",
        timeoutSeconds: 30,
        headers: ["X-Test": " value "]
    )

    let validated = try config.validated()

    #expect(validated.chatCompletionsURL.absoluteString == "https://provider.example/api/v1/chat/completions")
    #expect(validated.model == "inputo-test")
    #expect(validated.headers == ["X-Test": "value"])
}

@Test
func providerConfigValidationAcceptsFullChatCompletionsEndpoint() throws {
    let config = AIProviderConfig(
        baseURL: "https://provider.example/api/v1/chat/completions",
        model: "inputo-test",
        timeoutSeconds: 30,
        headers: [:]
    )

    let validated = try config.validated()

    #expect(validated.chatCompletionsURL.absoluteString == "https://provider.example/api/v1/chat/completions")
}

@Test
func providerConfigValidationRejectsInvalidValues() {
    #expect(throws: AIProviderError.invalidBaseURL) {
        try AIProviderConfig(baseURL: "", model: "model", timeoutSeconds: 30, headers: [:]).validated()
    }
    #expect(throws: AIProviderError.invalidModel) {
        try AIProviderConfig(baseURL: "https://provider.example", model: " ", timeoutSeconds: 30, headers: [:]).validated()
    }
    #expect(throws: AIProviderError.invalidTimeout) {
        try AIProviderConfig(baseURL: "https://provider.example", model: "model", timeoutSeconds: 0, headers: [:]).validated()
    }
    #expect(throws: AIProviderError.invalidHeader("Authorization is managed by Inputo.")) {
        try AIProviderConfig(
            baseURL: "https://provider.example",
            model: "model",
            timeoutSeconds: 30,
            headers: ["Authorization": "Bearer test"]
        ).validated()
    }
}

@Test
func providerClientSendsOpenAICompatibleRequestShape() async throws {
    let host = "shape.provider.example"
    let session = MockURLProtocol.makeSession(host: host) { request in
        let response = try makeHTTPResponse(for: request, statusCode: 200)
        let data = Data(#"{"choices":[{"message":{"content":" Polished output "}}]}"#.utf8)
        return (response, data)
    }
    let client = AIProviderClient(session: session)
    let config = AIProviderConfig(
        baseURL: "https://\(host)/root",
        model: "inputo-model",
        timeoutSeconds: 25,
        headers: ["X-Workspace": "test-workspace"]
    )

    let output = try await client.transform(
        text: "Hello",
        instruction: "Make it crisp",
        recipe: TransformRecipe.builtIns[0],
        config: config,
        apiKey: "sk-test-secret"
    )

    let request = try #require(MockURLProtocol.requests(for: host).first)
    let body = try #require(bodyData(from: request))
    let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    let messages = try #require(json["messages"] as? [[String: Any]])

    #expect(output == "Polished output")
    #expect(request.url?.absoluteString == "https://shape.provider.example/root/v1/chat/completions")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test-secret")
    #expect(request.value(forHTTPHeaderField: "X-Workspace") == "test-workspace")
    #expect(json["model"] as? String == "inputo-model")
    #expect(messages.first?["role"] as? String == "system")
    #expect(messages.last?["role"] as? String == "user")
    #expect((messages.last?["content"] as? String)?.contains("Make it crisp") == true)
    #expect((messages.last?["content"] as? String)?.contains("Hello") == true)
}

@Test
func providerClientStreamsOpenAICompatibleChunks() async throws {
    let host = "stream.provider.example"
    let session = MockURLProtocol.makeSession(host: host) { request in
        let response = try makeHTTPResponse(for: request, statusCode: 200)
        let data = Data(
            """
            data: {"choices":[{"delta":{"content":"Hello"}}]}

            data: {"choices":[{"delta":{"content":" stream"}}]}

            data: [DONE]

            """.utf8
        )
        return (response, data)
    }
    let client = AIProviderClient(session: session)
    let config = AIProviderConfig(
        baseURL: "https://\(host)",
        model: "inputo-model",
        timeoutSeconds: 25,
        headers: [:]
    )

    let stream = try await client.streamTransform(
        text: "Hello",
        instruction: "",
        recipe: TransformRecipe.builtIns[0],
        config: config,
        apiKey: "sk-test-secret"
    )
    var chunks: [String] = []
    for try await chunk in stream {
        chunks.append(chunk)
    }

    let request = try #require(MockURLProtocol.requests(for: host).first)
    let body = try #require(bodyData(from: request))
    let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])

    #expect(chunks == ["Hello", " stream"])
    #expect(json["stream"] as? Bool == true)
}

@Test
func providerClientRedactsSensitiveValuesFromProviderErrors() async throws {
    let host = "redact.provider.example"
    let session = MockURLProtocol.makeSession(host: host) { request in
        let response = try makeHTTPResponse(for: request, statusCode: 401)
        let data = Data(#"{"error":{"message":"Rejected sk-test-secret and header-secret."}}"#.utf8)
        return (response, data)
    }
    let client = AIProviderClient(session: session)
    let config = AIProviderConfig(
        baseURL: "https://\(host)",
        model: "inputo-model",
        timeoutSeconds: 25,
        headers: ["X-Provider-Token": "header-secret"]
    )

    do {
        _ = try await client.transform(
            text: "Hello",
            instruction: "",
            recipe: TransformRecipe.builtIns[0],
            config: config,
            apiKey: "sk-test-secret"
        )
        Issue.record("Expected provider error.")
    } catch {
        let description = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        #expect(description.contains("sk-test-secret") == false)
        #expect(description.contains("header-secret") == false)
        #expect(description.contains("[REDACTED]") == true)
    }
}

@Test
func providerClientMapsCannotFindHostToActionableError() async throws {
    let host = "missing.provider.example"
    let session = MockURLProtocol.makeSession(host: host) { _ in
        throw URLError(.cannotFindHost)
    }
    let client = AIProviderClient(session: session)
    let config = AIProviderConfig(
        baseURL: "https://\(host)",
        model: "inputo-model",
        timeoutSeconds: 25,
        headers: [:]
    )

    do {
        _ = try await client.transform(
            text: "Hello",
            instruction: "",
            recipe: TransformRecipe.builtIns[0],
            config: config,
            apiKey: "sk-test-secret"
        )
        Issue.record("Expected cannot-resolve-host error.")
    } catch {
        #expect(error as? AIProviderError == .cannotResolveHost(host))
        #expect((error as? LocalizedError)?.errorDescription?.contains(host) == true)
    }
}

private final class MockURLProtocol: URLProtocol {
    typealias Handler = (URLRequest) throws -> (HTTPURLResponse, Data)

    private static let lock = NSLock()
    nonisolated(unsafe) private static var handlers: [String: Handler] = [:]
    nonisolated(unsafe) private static var requestsByHost: [String: [URLRequest]] = [:]

    static func makeSession(host: String, handler: @escaping Handler) -> URLSession {
        lock.withLock {
            handlers[host] = handler
            requestsByHost[host] = []
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func requests(for host: String) -> [URLRequest] {
        lock.withLock {
            requestsByHost[host] ?? []
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let host = try Self.host(for: request)
            let handler = try Self.recordRequestAndHandler(for: host, request: request)
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    private static func host(for request: URLRequest) throws -> String {
        guard let host = request.url?.host else {
            throw MockURLProtocolError.missingURL
        }
        return host
    }

    private static func recordRequestAndHandler(for host: String, request: URLRequest) throws -> Handler {
        try lock.withLock {
            requestsByHost[host, default: []].append(request)
            guard let handler = handlers[host] else {
                throw MockURLProtocolError.missingHandler
            }
            return handler
        }
    }

    override func stopLoading() {}
}

private enum MockURLProtocolError: Error {
    case missingHandler
    case missingURL
    case invalidResponse
}

private func makeHTTPResponse(for request: URLRequest, statusCode: Int) throws -> HTTPURLResponse {
    guard let url = request.url else {
        throw MockURLProtocolError.missingURL
    }
    guard let response = HTTPURLResponse(
        url: url,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
    ) else {
        throw MockURLProtocolError.invalidResponse
    }
    return response
}

private func bodyData(from request: URLRequest) -> Data? {
    if let httpBody = request.httpBody {
        return httpBody
    }

    guard let bodyStream = request.httpBodyStream else {
        return nil
    }

    bodyStream.open()
    defer { bodyStream.close() }

    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 1024)
    while bodyStream.hasBytesAvailable {
        let bytesRead = bodyStream.read(&buffer, maxLength: buffer.count)
        guard bytesRead > 0 else { break }
        data.append(buffer, count: bytesRead)
    }
    return data
}
