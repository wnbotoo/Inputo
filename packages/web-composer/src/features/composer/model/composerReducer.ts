import type {
  ComposerState,
  LLMDeltaPayload,
  LLMFailurePayload,
  NativeEvent,
  NativeSnapshot,
  TransformRecipe
} from "../../../shared/bridge/types";

export const defaultComposerState: ComposerState = {
  draftText: "",
  instruction: "",
  selectedRecipeID: "polish",
  generatedOutput: "",
  isGenerating: false,
  canGenerate: false,
  canCopy: false,
  statusMessage: null,
  errorMessage: null
};

export interface ComposerViewState {
  recipes: TransformRecipe[];
  composer: ComposerState;
  activeRequestID: string | null;
}

export const initialComposerViewState: ComposerViewState = {
  recipes: [],
  composer: defaultComposerState,
  activeRequestID: null
};

export type ComposerAction =
  | { type: "applySnapshot"; snapshot: NativeSnapshot }
  | { type: "applyComposer"; composer: Partial<ComposerState> }
  | { type: "localDraft"; draftText: string }
  | { type: "localInstruction"; instruction: string }
  | { type: "localRecipe"; recipeID: string }
  | { type: "startGeneration"; requestID: string }
  | { type: "nativeEvent"; event: NativeEvent }
  | { type: "clearActiveRequest" };

export function composerReducer(
  state: ComposerViewState,
  action: ComposerAction
): ComposerViewState {
  switch (action.type) {
    case "applySnapshot":
      return {
        ...state,
        recipes: Array.isArray(action.snapshot.recipes) ? action.snapshot.recipes : state.recipes,
        composer: mergeComposer(state.composer, action.snapshot.composer)
      };
    case "applyComposer":
      return {
        ...state,
        composer: mergeComposer(state.composer, action.composer)
      };
    case "localDraft":
      return {
        ...state,
        composer: {
          ...state.composer,
          draftText: action.draftText,
          errorMessage: null
        }
      };
    case "localInstruction":
      return {
        ...state,
        composer: {
          ...state.composer,
          instruction: action.instruction,
          errorMessage: null
        }
      };
    case "localRecipe":
      return {
        ...state,
        composer: {
          ...state.composer,
          selectedRecipeID: action.recipeID
        }
      };
    case "startGeneration":
      return {
        ...state,
        activeRequestID: action.requestID,
        composer: {
          ...state.composer,
          generatedOutput: "",
          isGenerating: true,
          statusMessage: null,
          errorMessage: null
        }
      };
    case "nativeEvent":
      return applyNativeEvent(state, action.event);
    case "clearActiveRequest":
      return {
        ...state,
        activeRequestID: null
      };
  }
}

export function mergeComposer(
  current: ComposerState,
  next: Partial<ComposerState> | undefined
): ComposerState {
  if (!next) {
    return current;
  }
  return {
    ...current,
    ...next
  };
}

export function applyNativeEvent(
  state: ComposerViewState,
  event: NativeEvent
): ComposerViewState {
  switch (event.event) {
    case "llm.started":
      return {
        ...state,
        composer: {
          ...state.composer,
          generatedOutput: "",
          isGenerating: true,
          statusMessage: null,
          errorMessage: null
        }
      };
    case "llm.delta": {
      const payload = event.payload as LLMDeltaPayload | undefined;
      return {
        ...state,
        composer: {
          ...state.composer,
          generatedOutput: `${state.composer.generatedOutput}${payload?.text ?? ""}`,
          isGenerating: true
        }
      };
    }
    case "llm.completed":
      return {
        ...state,
        activeRequestID: null,
        composer: {
          ...state.composer,
          isGenerating: false,
          statusMessage: "Ready to copy.",
          errorMessage: null
        }
      };
    case "llm.failed": {
      const payload = event.payload as LLMFailurePayload | undefined;
      return {
        ...state,
        activeRequestID: null,
        composer: {
          ...state.composer,
          isGenerating: false,
          errorMessage: payload?.message ?? "Generation failed."
        }
      };
    }
    case "llm.cancelled":
      return {
        ...state,
        activeRequestID: null,
        composer: {
          ...state.composer,
          isGenerating: false,
          statusMessage: "Generation cancelled.",
          errorMessage: null
        }
      };
  }
}
