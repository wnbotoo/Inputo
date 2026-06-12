import { describe, expect, it } from "vitest";
import { composerReducer, initialComposerViewState } from "../state/composer";

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
  });
});
