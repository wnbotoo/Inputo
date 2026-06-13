import { describe, expect, it } from "vitest";
import { initialComposerViewState, type ComposerViewState } from "../model/composerReducer";
import {
  fileToolsState,
  providerSetupNotice,
  runtimeDiagnostics
} from "./useComposerController";

describe("composer controller helpers", () => {
  it("explains provider setup without exposing provider details", () => {
    const notice = providerSetupNotice({
      provider: {
        baseURL: "https://provider.example",
        model: "inputo-test",
        endpointPreview: "https://provider.example/v1/chat/completions",
        hasAPIKey: false,
        validationError: null
      },
      hasHotKey: false,
      customRecipeCount: 0
    });

    expect(notice?.message).toBe("Add an API key in Settings before generating.");
    expect(notice?.detail).toContain("native keychain");
    expect(JSON.stringify(notice)).not.toContain("provider.example");
  });

  it("derives file tool availability from permission snapshots", () => {
    const state: ComposerViewState = {
      ...initialComposerViewState,
      permissions: [
        {
          id: "file.read",
          displayName: "File Read",
          state: "requires_user_action",
          detail: "Reads use native file picker grants."
        },
        {
          id: "file.write",
          displayName: "File Write",
          state: "unavailable",
          detail: "Assisted workflow is required."
        }
      ]
    };

    expect(fileToolsState(state)).toEqual({
      label: "File read available; save unavailable",
      readDetail: "Reads use native file picker grants.",
      writeDetail: "Assisted workflow is required.",
      canRead: true,
      canWrite: false
    });
  });

  it("builds diagnostics from counts and safe state labels only", () => {
    const state: ComposerViewState = {
      ...initialComposerViewState,
      agentMode: "assisted_workflow",
      settings: {
        provider: {
          baseURL: "https://provider.example",
          model: "secret-model-name",
          endpointPreview: "https://provider.example/v1/chat/completions",
          hasAPIKey: true,
          validationError: null
        },
        hasHotKey: true,
        customRecipeCount: 2
      },
      permissions: [
        {
          id: "provider.network",
          displayName: "Provider Network",
          state: "available",
          detail: "Native owns provider requests."
        },
        {
          id: "network.tools",
          displayName: "Network Tools",
          state: "unavailable",
          detail: "Deferred until policy exists."
        }
      ],
      tools: [
        {
          id: "app.snapshot",
          displayName: "Get App Snapshot",
          description: "Read safe app state.",
          effect: "read_state",
          minimumAgentMode: "manual_transform",
          requiresExplicitUserAction: false,
          requiresPerCallConfirmation: false,
          supportsCancellation: false,
          streams: false
        }
      ]
    };

    const diagnostics = runtimeDiagnostics(state, null);

    expect(diagnostics.summary).toBe("1 available, 0 user action");
    expect(diagnostics.items).toContainEqual({ label: "Provider", value: "Provider configured" });
    expect(diagnostics.items).toContainEqual({ label: "Mode", value: "Assisted" });
    expect(diagnostics.permissions.map((permission) => permission.stateLabel)).toEqual([
      "Available",
      "Unavailable"
    ]);
    expect(JSON.stringify(diagnostics)).not.toContain("secret-model-name");
    expect(JSON.stringify(diagnostics)).not.toContain("provider.example");
  });
});
