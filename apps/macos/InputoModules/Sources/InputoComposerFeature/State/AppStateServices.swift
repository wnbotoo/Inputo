import Foundation
import InputoCore
import InputoMacPlatform

@MainActor
public protocol AppSettingsServicing {
    func loadSettings() -> AppSettings
    func saveSettings(_ settings: AppSettings)
}

@MainActor
public protocol APIKeyServicing {
    func readAPIKey() throws -> String
    func saveAPIKey(_ apiKey: String) throws
}

@MainActor
public protocol ClipboardServicing {
    func copy(_ text: String)
}

@MainActor
public protocol AppAnchorServicing {
    func currentAnchors() -> [AppAnchor]
    func activate(_ anchor: AppAnchor) -> Bool
}

@MainActor
public protocol TextTransforming {
    func transformText(
        text: String,
        instruction: String,
        recipe: TransformRecipe,
        config: AIProviderConfig,
        apiKey: String
    ) async throws -> String

    func streamText(
        text: String,
        instruction: String,
        recipe: TransformRecipe,
        config: AIProviderConfig,
        apiKey: String
    ) async throws -> AsyncThrowingStream<String, Error>
}

public extension TextTransforming {
    func streamText(
        text: String,
        instruction: String,
        recipe: TransformRecipe,
        config: AIProviderConfig,
        apiKey: String
    ) async throws -> AsyncThrowingStream<String, Error> {
        let result = try await transformText(
            text: text,
            instruction: instruction,
            recipe: recipe,
            config: config,
            apiKey: apiKey
        )
        return AsyncThrowingStream { continuation in
            continuation.yield(result)
            continuation.finish()
        }
    }
}

public struct AppStateServices {
    public var settings: any AppSettingsServicing
    public var apiKeys: any APIKeyServicing
    public var clipboard: any ClipboardServicing
    public var anchors: any AppAnchorServicing
    public var textTransformer: any TextTransforming

    public init(
        settings: any AppSettingsServicing,
        apiKeys: any APIKeyServicing,
        clipboard: any ClipboardServicing,
        anchors: any AppAnchorServicing,
        textTransformer: any TextTransforming
    ) {
        self.settings = settings
        self.apiKeys = apiKeys
        self.clipboard = clipboard
        self.anchors = anchors
        self.textTransformer = textTransformer
    }

    @MainActor
    public static func live() -> AppStateServices {
        AppStateServices(
            settings: LiveSettingsService(),
            apiKeys: LiveAPIKeyService(),
            clipboard: LiveClipboardService(),
            anchors: LiveAnchorService(),
            textTransformer: LiveTextTransformer()
        )
    }
}

private struct LiveSettingsService: AppSettingsServicing {
    private let store: SettingsStore

    init(store: SettingsStore = SettingsStore()) {
        self.store = store
    }

    func loadSettings() -> AppSettings {
        store.load()
    }

    func saveSettings(_ settings: AppSettings) {
        store.save(settings)
    }
}

private struct LiveAPIKeyService: APIKeyServicing {
    private let keychain: KeychainService

    init(keychain: KeychainService = KeychainService()) {
        self.keychain = keychain
    }

    func readAPIKey() throws -> String {
        try keychain.readAPIKey()
    }

    func saveAPIKey(_ apiKey: String) throws {
        try keychain.saveAPIKey(apiKey)
    }
}

private struct LiveClipboardService: ClipboardServicing {
    private let clipboard: ClipboardService

    init(clipboard: ClipboardService = ClipboardService()) {
        self.clipboard = clipboard
    }

    func copy(_ text: String) {
        clipboard.copy(text)
    }
}

private struct LiveAnchorService: AppAnchorServicing {
    private let service: AnchorService

    init(service: AnchorService = AnchorService()) {
        self.service = service
    }

    func currentAnchors() -> [AppAnchor] {
        service.currentAnchors()
    }

    func activate(_ anchor: AppAnchor) -> Bool {
        service.activate(anchor)
    }
}

private struct LiveTextTransformer: TextTransforming {
    private let client: AIProviderClient

    init(client: AIProviderClient = AIProviderClient()) {
        self.client = client
    }

    func transformText(
        text: String,
        instruction: String,
        recipe: TransformRecipe,
        config: AIProviderConfig,
        apiKey: String
    ) async throws -> String {
        try await client.transform(
            text: text,
            instruction: instruction,
            recipe: recipe,
            config: config,
            apiKey: apiKey
        )
    }

    func streamText(
        text: String,
        instruction: String,
        recipe: TransformRecipe,
        config: AIProviderConfig,
        apiKey: String
    ) async throws -> AsyncThrowingStream<String, Error> {
        try await client.streamTransform(
            text: text,
            instruction: instruction,
            recipe: recipe,
            config: config,
            apiKey: apiKey
        )
    }
}
