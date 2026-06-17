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

  it("accepts native-started streaming events without a Web-originated request", () => {
    const started = composerReducer(initialComposerViewState, {
      type: "nativeEvent",
      event: {
        version: 1,
        type: "event",
        event: "llm.started",
        requestID: "native-request"
      }
    });
    const withDelta = composerReducer(started, {
      type: "nativeEvent",
      event: {
        version: 1,
        type: "event",
        event: "llm.delta",
        requestID: "native-request",
        payload: { text: "Native output" }
      }
    });

    expect(started.activeRequestID).toBe("native-request");
    expect(withDelta.composer.generatedOutput).toBe("Native output");
  });

  it("stores unknown native commands for the Web preview runtime", () => {
    const state = composerReducer(initialComposerViewState, {
      type: "nativeEvent",
      event: {
        version: 1,
        type: "event",
        event: "command.received",
        payload: {
          commandName: "custom",
          inputText: "/custom Build a widget",
          bodyText: "Build a widget",
          arguments: ["Build", "a", "widget"]
        }
      }
    });

    expect(state.routedCommand?.commandName).toBe("custom");
    expect(state.routedCommand?.bodyText).toBe("Build a widget");
    expect(state.composer.statusMessage).toBe("Received /custom.");
  });

  it("renders Web preview commands when they map to a preview payload", () => {
    const state = composerReducer(initialComposerViewState, {
      type: "nativeEvent",
      event: {
        version: 1,
        type: "event",
        event: "command.received",
        payload: {
          commandName: "html",
          inputText: "/html <h1>Hello</h1>",
          bodyText: "<h1>Hello</h1>",
          arguments: ["<h1>Hello</h1>"]
        }
      }
    });

    expect(state.routedCommand?.commandName).toBe("html");
    expect(state.previewPayload?.kind).toBe("html");
    expect(state.previewPayload?.capabilities.allowScripts).toBe(false);
    expect(state.composer.statusMessage).toBe("Rendered /html.");
  });

  it("stores explicit preview.render payloads", () => {
    const state = composerReducer(initialComposerViewState, {
      type: "nativeEvent",
      event: {
        version: 1,
        type: "event",
        event: "preview.render",
        payload: {
          kind: "document",
          content: "<h1>Widget</h1>",
          title: "Widget preview",
          capabilities: {
            allowInlineStyles: true,
            allowScripts: true,
            allowDataImages: true,
            allowNetwork: true
          }
        }
      }
    });

    expect(state.previewPayload?.kind).toBe("document");
    expect(state.previewPayload?.title).toBe("Widget preview");
    expect(state.previewPayload?.capabilities.allowNetwork).toBe(false);
    expect(state.composer.statusMessage).toBe("Preview rendered.");
  });

  it("promotes completed HTML output to an isolated document preview", () => {
    const started = composerReducer(initialComposerViewState, {
      type: "nativeEvent",
      event: {
        version: 1,
        type: "event",
        event: "llm.started",
        requestID: "native-request"
      }
    });
    const withDelta = composerReducer(started, {
      type: "nativeEvent",
      event: {
        version: 1,
        type: "event",
        event: "llm.delta",
        requestID: "native-request",
        payload: { text: "<!doctype html><html><body><h1>Hi</h1></body></html>" }
      }
    });
    const completed = composerReducer(withDelta, {
      type: "nativeEvent",
      event: {
        version: 1,
        type: "event",
        event: "llm.completed",
        requestID: "native-request"
      }
    });

    expect(completed.previewPayload?.kind).toBe("document");
    expect(completed.previewPayload?.capabilities.allowScripts).toBe(true);
  });

  it("ignores late stream events after a request is no longer active", () => {
    const started = composerReducer(initialComposerViewState, {
      type: "startGeneration",
      requestID: "request-1"
    });
    const cancelled = composerReducer(started, {
      type: "nativeEvent",
      event: {
        version: 1,
        type: "event",
        event: "llm.cancelled",
        requestID: "request-1"
      }
    });
    const lateDelta = composerReducer(cancelled, {
      type: "nativeEvent",
      event: {
        version: 1,
        type: "event",
        event: "llm.delta",
        requestID: "request-1",
        payload: { text: "late text" }
      }
    });

    expect(cancelled.activeRequestID).toBeNull();
    expect(cancelled.composer.statusMessage).toBe("Generation cancelled.");
    expect(lateDelta).toBe(cancelled);
  });

  it("does not let duplicate completion events restore stale status after edits", () => {
    const started = composerReducer(initialComposerViewState, {
      type: "startGeneration",
      requestID: "request-1"
    });
    const completed = composerReducer(started, {
      type: "nativeEvent",
      event: {
        version: 1,
        type: "event",
        event: "llm.completed",
        requestID: "request-1"
      }
    });
    const edited = composerReducer(completed, {
      type: "localDraft",
      draftText: "fresh draft"
    });
    const duplicateCompletion = composerReducer(edited, {
      type: "nativeEvent",
      event: {
        version: 1,
        type: "event",
        event: "llm.completed",
        requestID: "request-1"
      }
    });

    expect(edited.composer.statusMessage).toBeNull();
    expect(duplicateCompletion).toBe(edited);
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

  it("stops generating when active request state is cleared", () => {
    const started = composerReducer(initialComposerViewState, {
      type: "startGeneration",
      requestID: "request-1"
    });
    const cleared = composerReducer(started, {
      type: "clearActiveRequest"
    });

    expect(cleared.activeRequestID).toBeNull();
    expect(cleared.composer.isGenerating).toBe(false);
  });

  it("falls back to the first available recipe when snapshots remove the selected one", () => {
    const state = composerReducer(initialComposerViewState, {
      type: "applySnapshot",
      snapshot: {
        recipes: [{ id: "summarize", name: "Summarize" }],
        composer: {
          selectedRecipeID: "removed-custom-preset"
        }
      }
    });

    expect(state.composer.selectedRecipeID).toBe("summarize");
  });
});
