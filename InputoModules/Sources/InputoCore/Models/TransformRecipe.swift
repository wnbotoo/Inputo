import Foundation

public struct TransformRecipe: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var systemPrompt: String
    public var outputHint: String
    public var isBuiltIn: Bool

    public init(id: String, name: String, systemPrompt: String, outputHint: String, isBuiltIn: Bool) {
        self.id = id
        self.name = name
        self.systemPrompt = systemPrompt
        self.outputHint = outputHint
        self.isBuiltIn = isBuiltIn
    }

    public static let builtIns: [TransformRecipe] = [
        TransformRecipe(
            id: "polish",
            name: "Polish",
            systemPrompt: "You polish user-provided text while preserving meaning, intent, and important details.",
            outputHint: "Return a clearer, smoother version in the same language.",
            isBuiltIn: true
        ),
        TransformRecipe(
            id: "translate-en",
            name: "English",
            systemPrompt: "You translate user-provided text into natural English.",
            outputHint: "Return only the translated English text.",
            isBuiltIn: true
        ),
        TransformRecipe(
            id: "translate-zh",
            name: "中文",
            systemPrompt: "You translate user-provided text into natural Simplified Chinese.",
            outputHint: "Return only the translated Chinese text.",
            isBuiltIn: true
        ),
        TransformRecipe(
            id: "emoji",
            name: "Emoji",
            systemPrompt: "You lightly decorate text with relevant emoji without making it noisy.",
            outputHint: "Keep the original meaning and add a small number of tasteful emoji.",
            isBuiltIn: true
        ),
        TransformRecipe(
            id: "concise",
            name: "Shorten",
            systemPrompt: "You make text concise and direct while preserving the core message.",
            outputHint: "Return a shorter version that still sounds natural.",
            isBuiltIn: true
        )
    ]
}
