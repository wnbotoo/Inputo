import Foundation
import InputoCore

public struct AppSettings: Codable, Equatable, Sendable {
    public var provider: AIProviderConfig
    public var hotKey: GlobalShortcut?
    public var customPresets: [TransformRecipe]

    public init(provider: AIProviderConfig, hotKey: GlobalShortcut?, customPresets: [TransformRecipe]) {
        self.provider = provider
        self.hotKey = hotKey
        self.customPresets = customPresets
    }

    public static let `default` = AppSettings(
        provider: .default,
        hotKey: nil,
        customPresets: []
    )
}
