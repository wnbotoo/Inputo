import {
  useCallback,
  useEffect,
  useMemo,
  useReducer,
  useRef,
  type ChangeEvent,
  type CompositionEvent,
  type InputEvent as ReactInputEvent
} from "react";
import {
  inputoBridge,
  makeBridgeID,
  USER_ACTION_CONTEXT
} from "./bridge/bridgeClient";
import type {
  BridgeResult,
  ComposerState,
  LLMCancelPayload,
  LLMStreamPayload,
  LLMStreamResult,
  NativeEvent,
  NativeSnapshot
} from "./bridge/types";
import {
  composerReducer,
  initialComposerViewState,
  type ComposerViewState
} from "./state/composer";

const SYNC_DELAY_MS = 160;
const COMPOSITION_ESCAPE_GRACE_MS = 700;

export function App() {
  const [viewState, dispatch] = useReducer(composerReducer, initialComposerViewState);
  const stateRef = useRef<ComposerViewState>(viewState);
  const draftRef = useRef<HTMLTextAreaElement | null>(null);
  const draftSyncTimer = useRef<number | null>(null);
  const instructionSyncTimer = useRef<number | null>(null);
  const isComposingText = useRef(false);
  const lastCompositionActivityAt = useRef(0);

  useEffect(() => {
    stateRef.current = viewState;
  }, [viewState]);

  const cancelPendingSync = useCallback(() => {
    if (draftSyncTimer.current !== null) {
      window.clearTimeout(draftSyncTimer.current);
      draftSyncTimer.current = null;
    }
    if (instructionSyncTimer.current !== null) {
      window.clearTimeout(instructionSyncTimer.current);
      instructionSyncTimer.current = null;
    }
  }, []);

  const applyToolComposerResult = useCallback((response: BridgeResult<Partial<ComposerState>>) => {
    if (response.ok) {
      dispatch({ type: "applyComposer", composer: response.payload });
    } else {
      dispatch({
        type: "applyComposer",
        composer: {
          errorMessage: response.error.message
        }
      });
    }
  }, []);

  const focusDraft = useCallback(() => {
    window.requestAnimationFrame(() => {
      draftRef.current?.focus();
    });
  }, []);

  const markCompositionActivity = useCallback((isActive = true) => {
    isComposingText.current = isActive;
    lastCompositionActivityAt.current = performance.now();
  }, []);

  const wasRecentlyComposing = useCallback(() => {
    return performance.now() - lastCompositionActivityAt.current < COMPOSITION_ESCAPE_GRACE_MS;
  }, []);

  const scheduleDraftSync = useCallback((draftText: string) => {
    if (draftSyncTimer.current !== null) {
      window.clearTimeout(draftSyncTimer.current);
    }
    draftSyncTimer.current = window.setTimeout(() => {
      inputoBridge
        .callTool<{ draftText: string }, Partial<ComposerState>>("composer.setDraft", { draftText })
        .then(applyToolComposerResult);
    }, SYNC_DELAY_MS);
  }, [applyToolComposerResult]);

  const scheduleInstructionSync = useCallback((instruction: string) => {
    if (instructionSyncTimer.current !== null) {
      window.clearTimeout(instructionSyncTimer.current);
    }
    instructionSyncTimer.current = window.setTimeout(() => {
      inputoBridge
        .callTool<{ instruction: string }, Partial<ComposerState>>(
          "composer.setInstruction",
          { instruction }
        )
        .then(applyToolComposerResult);
    }, SYNC_DELAY_MS);
  }, [applyToolComposerResult]);

  const generate = useCallback(async () => {
    const current = stateRef.current;
    if (
      current.composer.draftText.trim().length === 0 ||
      current.composer.isGenerating ||
      current.activeRequestID
    ) {
      return;
    }

    cancelPendingSync();
    const requestID = makeBridgeID("llm-stream");
    dispatch({ type: "startGeneration", requestID });

    const response = await inputoBridge.callTool<LLMStreamPayload, LLMStreamResult>(
      "llm.stream",
      {
        draftText: current.composer.draftText,
        instruction: current.composer.instruction,
        recipeID: current.composer.selectedRecipeID
      },
      USER_ACTION_CONTEXT,
      requestID
    );

    dispatch({ type: "clearActiveRequest" });
    if (response.ok) {
      dispatch({
        type: "applyComposer",
        composer: response.payload.composer ?? {}
      });
    } else {
      dispatch({
        type: "applyComposer",
        composer: {
          isGenerating: false,
          errorMessage: response.error.message
        }
      });
    }
  }, [cancelPendingSync]);

  const cancelGeneration = useCallback(async () => {
    const requestID = stateRef.current.activeRequestID;
    if (!requestID) {
      return;
    }
    await inputoBridge.callTool<LLMCancelPayload, Partial<ComposerState>>("llm.cancel", {
      requestID
    });
  }, []);

  const clearComposer = useCallback(async () => {
    const response = await inputoBridge.callTool<Record<string, never>, Partial<ComposerState>>(
      "composer.clear",
      {},
      USER_ACTION_CONTEXT
    );
    dispatch({ type: "clearActiveRequest" });
    applyToolComposerResult(response);
  }, [applyToolComposerResult]);

  const copyOutput = useCallback(async () => {
    const response = await inputoBridge.callTool<Record<string, never>, Partial<ComposerState>>(
      "clipboard.copyGeneratedOutput",
      {},
      USER_ACTION_CONTEXT
    );
    applyToolComposerResult(response);
  }, [applyToolComposerResult]);

  useEffect(() => {
    inputoBridge.installGlobalReceiver(window);
    window.InputoComposerFocus = focusDraft;
    window.InputoNativeThemeSet = (theme: string) => {
      const nextTheme = theme === "dark" ? "dark" : "light";
      document.documentElement.dataset.theme = nextTheme;
    };
    window.InputoNativeThemeSet(
      window.InputoInitialTheme ||
      (window.matchMedia?.("(prefers-color-scheme: dark)")?.matches ? "dark" : "light")
    );

    const unsubscribe = inputoBridge.onEvent((event: NativeEvent) => {
      const activeRequestID = stateRef.current.activeRequestID;
      if (event.requestID && activeRequestID && event.requestID !== activeRequestID) {
        return;
      }
      dispatch({ type: "nativeEvent", event });
    });

    inputoBridge
      .callTool<Record<string, never>, NativeSnapshot>("app.snapshot", {})
      .then((response) => {
        if (response.ok) {
          dispatch({ type: "applySnapshot", snapshot: response.payload });
          focusDraft();
        } else {
          dispatch({
            type: "applyComposer",
            composer: {
              errorMessage: response.error.message || "Could not load native state."
            }
          });
        }
      });

    return () => {
      unsubscribe();
      cancelPendingSync();
    };
  }, [cancelPendingSync, focusDraft]);

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        if (event.isComposing || isComposingText.current || wasRecentlyComposing()) {
          return;
        }
        event.preventDefault();
        inputoBridge.callTool<Record<string, never>, unknown>(
          "app.hideComposer",
          {},
          USER_ACTION_CONTEXT
        );
        return;
      }

      if ((event.metaKey || event.ctrlKey) && event.key === "Enter" && !event.isComposing) {
        event.preventDefault();
        generate();
      }
    };

    document.addEventListener("keydown", handleKeyDown);
    return () => {
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, [generate, wasRecentlyComposing]);

  const composer = viewState.composer;
  const hasOutput = composer.generatedOutput.trim().length > 0;
  const previewText = hasOutput
    ? composer.generatedOutput
    : (composer.isGenerating ? "Generating..." : "No preview yet.");
  const canGenerate = composer.draftText.trim().length > 0 &&
    !composer.isGenerating &&
    !viewState.activeRequestID;
  const isGenerating = composer.isGenerating || Boolean(viewState.activeRequestID);
  const status = useMemo(() => {
    if (composer.errorMessage) {
      return { text: composer.errorMessage, isError: true };
    }
    if (composer.statusMessage) {
      return { text: composer.statusMessage, isError: false };
    }
    if (isGenerating) {
      return { text: "Generating...", isError: false };
    }
    return { text: "", isError: false };
  }, [composer.errorMessage, composer.statusMessage, isGenerating]);

  const handleDraftCompositionEnd = (event: CompositionEvent<HTMLTextAreaElement>) => {
    markCompositionActivity(false);
    const draftText = event.currentTarget.value;
    dispatch({ type: "localDraft", draftText });
    scheduleDraftSync(draftText);
  };

  const handleInstructionCompositionEnd = (event: CompositionEvent<HTMLInputElement>) => {
    markCompositionActivity(false);
    const instruction = event.currentTarget.value;
    dispatch({ type: "localInstruction", instruction });
    scheduleInstructionSync(instruction);
  };

  const handleDraftChange = (event: ChangeEvent<HTMLTextAreaElement>) => {
    const draftText = event.currentTarget.value;
    dispatch({ type: "localDraft", draftText });
    const nativeEvent = event.nativeEvent as unknown as globalThis.InputEvent;
    if (nativeEvent.isComposing) {
      markCompositionActivity(true);
    }
    if (!isComposingText.current) {
      scheduleDraftSync(draftText);
    }
  };

  const handleInstructionChange = (event: ChangeEvent<HTMLInputElement>) => {
    const instruction = event.currentTarget.value;
    dispatch({ type: "localInstruction", instruction });
    const nativeEvent = event.nativeEvent as unknown as globalThis.InputEvent;
    if (nativeEvent.isComposing) {
      markCompositionActivity(true);
    }
    if (!isComposingText.current) {
      scheduleInstructionSync(instruction);
    }
  };

  const handleRecipeChange = (event: ChangeEvent<HTMLSelectElement>) => {
    const recipeID = event.currentTarget.value;
    dispatch({ type: "localRecipe", recipeID });
    inputoBridge
      .callTool<{ recipeID: string }, Partial<ComposerState>>("composer.selectRecipe", { recipeID })
      .then(applyToolComposerResult);
  };

  const handleBeforeInput = (event: ReactInputEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const nativeEvent = event.nativeEvent as globalThis.InputEvent;
    if (nativeEvent.isComposing || nativeEvent.inputType === "insertCompositionText") {
      markCompositionActivity(true);
    }
  };

  return (
    <main className="composer-shell" aria-label="Inputo composer">
      <section className="preview-panel" aria-label="Preview">
        <div className="panel-title-row">
          <h2>Preview</h2>
          <button
            type="button"
            className="secondary-button"
            disabled={!hasOutput}
            onClick={copyOutput}
          >
            Copy
          </button>
        </div>
        <textarea
          className={`preview-output${hasOutput ? "" : " is-empty"}`}
          readOnly
          spellCheck={false}
          aria-label="Generated preview"
          value={previewText}
        />
      </section>

      <section className="control-row" aria-label="Transform controls">
        <select
          value={composer.selectedRecipeID}
          aria-label="Preset"
          onChange={handleRecipeChange}
        >
          {viewState.recipes.map((recipe) => (
            <option key={recipe.id} value={recipe.id}>
              {recipe.name}
            </option>
          ))}
        </select>
        <input
          type="text"
          value={composer.instruction}
          autoComplete="off"
          spellCheck
          aria-label="Instruction"
          placeholder="Instruction"
          onCompositionStart={() => markCompositionActivity(true)}
          onCompositionUpdate={() => markCompositionActivity(true)}
          onCompositionEnd={handleInstructionCompositionEnd}
          onBeforeInput={handleBeforeInput}
          onChange={handleInstructionChange}
        />
      </section>

      <section className="draft-panel" aria-label="Draft">
        <textarea
          ref={draftRef}
          className="draft-input"
          value={composer.draftText}
          autoComplete="off"
          spellCheck
          placeholder="Paste or type the text you want Inputo to transform..."
          onCompositionStart={() => markCompositionActivity(true)}
          onCompositionUpdate={() => markCompositionActivity(true)}
          onCompositionEnd={handleDraftCompositionEnd}
          onBeforeInput={handleBeforeInput}
          onChange={handleDraftChange}
        />
        <div className="action-row">
          <p className={`status-text${status.isError ? " is-error" : ""}`} role="status">
            {status.text}
          </p>
          <div className="action-buttons">
            <button
              type="button"
              className="secondary-button"
              disabled={composer.isGenerating && !viewState.activeRequestID}
              onClick={clearComposer}
            >
              Clear
            </button>
            {isGenerating ? (
              <button type="button" className="secondary-button" onClick={cancelGeneration}>
                Cancel
              </button>
            ) : null}
            <button
              type="button"
              className="primary-button"
              disabled={!canGenerate}
              onClick={generate}
            >
              {isGenerating ? "Generating" : "Generate"}
            </button>
          </div>
        </div>
      </section>
    </main>
  );
}
