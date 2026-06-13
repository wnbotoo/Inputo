import { describe, expect, it } from "vitest";
import { composerReducer, initialComposerViewState } from "./composerReducer";

describe("composerReducer", () => {
  it("applies native snapshots without dropping default composer fields", () => {
    const state = composerReducer(initialComposerViewState, {
      type: "applySnapshot",
      snapshot: {
        recipes: [{ id: "polish", name: "Polish" }],
        composer: {
          draftText: "hello",
          selectedRecipeID: "polish"
        }
      }
    });

    expect(state.recipes).toEqual([{ id: "polish", name: "Polish" }]);
    expect(state.composer.draftText).toBe("hello");
    expect(state.composer.generatedOutput).toBe("");
    expect(state.composer.errorMessage).toBeNull();
  });

  it("tracks streaming lifecycle events", () => {
    const started = composerReducer(initialComposerViewState, {
      type: "startGeneration",
      requestID: "request-1"
    });
    const withDelta = composerReducer(started, {
      type: "nativeEvent",
      event: {
        version: 1,
        type: "event",
        event: "llm.delta",
        requestID: "request-1",
        payload: { text: "Hi" }
      }
    });
    const completed = composerReducer(withDelta, {
      type: "nativeEvent",
      event: {
        version: 1,
        type: "event",
        event: "llm.completed",
        requestID: "request-1"
      }
    });

    expect(withDelta.composer.generatedOutput).toBe("Hi");
    expect(withDelta.composer.isGenerating).toBe(true);
    expect(completed.activeRequestID).toBeNull();
    expect(completed.composer.statusMessage).toBe("Ready to copy.");
  });

  it("stores safe display errors from failed streams", () => {
    const state = composerReducer(initialComposerViewState, {
      type: "nativeEvent",
      event: {
        version: 1,
        type: "event",
        event: "llm.failed",
        payload: { message: "Provider is not configured." }
      }
    });

    expect(state.composer.isGenerating).toBe(false);
    expect(state.composer.errorMessage).toBe("Provider is not configured.");
    expect(state.composer.statusMessage).toBeNull();
  });

  it("stores provider setup data from native snapshots", () => {
    const state = composerReducer(initialComposerViewState, {
      type: "applySnapshot",
      snapshot: {
        recipes: [],
        composer: {},
        settings: {
          provider: {
            baseURL: "https://provider.example",
            model: "inputo-model",
            endpointPreview: "https://provider.example/v1/chat/completions",
            hasAPIKey: false,
            validationError: null
          },
          hasHotKey: true,
          customRecipeCount: 0
        },
        permissions: [
          {
            id: "clipboard.write",
            displayName: "Clipboard",
            state: "requires_user_action",
            detail: "Explicit copy only."
          }
        ],
        anchors: [],
        tools: []
      }
    });

    expect(state.settings?.provider.hasAPIKey).toBe(false);
    expect(state.agentMode).toBeNull();
    expect(state.permissions[0]?.id).toBe("clipboard.write");
  });

  it("clears stale status and errors after local edits", () => {
    const withError = composerReducer(initialComposerViewState, {
      type: "applyComposer",
      composer: {
        statusMessage: "Copied to clipboard.",
        errorMessage: "Provider failed."
      }
    });

    const edited = composerReducer(withError, {
      type: "localDraft",
      draftText: "new draft"
    });

    expect(edited.composer.statusMessage).toBeNull();
    expect(edited.composer.errorMessage).toBeNull();
  });
});
