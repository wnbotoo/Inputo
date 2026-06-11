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
