import Foundation
import InputoCore
import InputoMacPlatform

@MainActor
public extension AppState {
    func nativeExecutorSnapshot(agentMode: InputoAgentMode = .manualTransform) -> InputoNativeExecutorSnapshot {
        let providerSummary = InputoProviderSummary(
            baseURL: settings.provider.baseURL,
            model: settings.provider.model,
            endpointPreview: settings.provider.endpointPreview,
            hasAPIKey: hasAPIKey,
            validationError: settings.provider.validationErrorDescription
        )

        let settingsSummary = InputoSettingsSummary(
            provider: providerSummary,
            hasHotKey: settings.hotKey != nil,
            customRecipeCount: settings.customPresets.count
        )

        return InputoNativeExecutorSnapshot(
            agentMode: agentMode,
            composer: InputoComposerSnapshot(
                draftText: inputText,
                instruction: instruction,
                selectedRecipeID: selectedRecipeID,
                generatedOutput: outputText,
                isGenerating: isGenerating,
                canGenerate: !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating,
                canCopy: !outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                statusMessage: statusMessage,
                errorMessage: errorMessage
            ),
            settings: settingsSummary,
            recipes: recipes,
            anchors: anchors.map(InputoAppAnchorSnapshot.init(anchor:)),
            permissions: nativePermissionSnapshots(providerSummary: providerSummary, agentMode: agentMode),
            tools: InputoNativeToolDescriptor.v1DefaultTools
        )
    }

    private func nativePermissionSnapshots(
        providerSummary: InputoProviderSummary,
        agentMode: InputoAgentMode
    ) -> [InputoPermissionSnapshot] {
        [
            InputoPermissionSnapshot(
                id: .providerNetwork,
                displayName: "Provider Network",
                state: providerSummary.validationError == nil && providerSummary.hasAPIKey ? .available : .unavailable,
                detail: "Native owns provider requests and keeps API keys out of Web."
            ),
            InputoPermissionSnapshot(
                id: .clipboardWrite,
                displayName: "Clipboard",
                state: .requiresUserAction,
                detail: "Native writes only the generated output and only after an explicit Copy action."
            ),
            InputoPermissionSnapshot(
                id: .appAnchors,
                displayName: "App Anchors",
                state: .available,
                detail: "Native exposes app-level anchors without window titles, screenshots, or target-control contents."
            ),
            InputoPermissionSnapshot(
                id: .accessibility,
                displayName: "Accessibility",
                state: .notRequired,
                detail: "Native v0.1 does not require Accessibility permission for the default flow."
            ),
            InputoPermissionSnapshot(
                id: .screenRecording,
                displayName: "Screen Recording",
                state: .notRequested,
                detail: "Native v0.1 does not request screen recording and does not capture screenshots."
            ),
            InputoPermissionSnapshot(
                id: .fileRead,
                displayName: "File Read",
                state: agentMode.allows(minimumMode: .assistedWorkflow) ? .requiresUserAction : .unavailable,
                detail: "Reads use native file picker grants and never arbitrary Web-provided paths."
            ),
            InputoPermissionSnapshot(
                id: .fileWrite,
                displayName: "File Write",
                state: agentMode.allows(minimumMode: .assistedWorkflow) ? .requiresUserAction : .unavailable,
                detail: "Writes use native save-panel grants and per-call confirmation."
            ),
            InputoPermissionSnapshot(
                id: .networkTools,
                displayName: "Network Tools",
                state: agentMode.allows(minimumMode: .assistedWorkflow) ? .requiresUserAction : .unavailable,
                detail: "Manifest-defined network tools are deferred until native policy and review UI exist."
            ),
            InputoPermissionSnapshot(
                id: .mcpTools,
                displayName: "MCP Tools",
                state: .unavailable,
                detail: "MCP and connector execution are disabled in v1."
            )
        ]
    }
}

private extension InputoAppAnchorSnapshot {
    init(anchor: AppAnchor) {
        self.init(
            id: anchor.id,
            appName: anchor.appName,
            bundleIdentifier: anchor.bundleIdentifier,
            processIdentifier: Int(anchor.processIdentifier),
            lastActiveAt: anchor.lastActiveAt,
            canActivate: anchor.canActivate
        )
    }
}
