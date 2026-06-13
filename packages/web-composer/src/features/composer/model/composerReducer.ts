import type {
  ComposerState,
  LLMDeltaPayload,
  LLMFailurePayload,
  AppAnchorSnapshot,
  AgentMode,
  NativeEvent,
  NativeSnapshot,
  NativeToolDescriptor,
  PermissionSnapshot,
  SettingsSummary,
  TransformRecipe
} from "@inputo/bridge-contracts";

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
  agentMode: AgentMode | null;
  recipes: TransformRecipe[];
  composer: ComposerState;
  settings: SettingsSummary | null;
  anchors: AppAnchorSnapshot[];
  permissions: PermissionSnapshot[];
  tools: NativeToolDescriptor[];
  activeRequestID: string | null;
}

export const initialComposerViewState: ComposerViewState = {
  agentMode: null,
  recipes: [],
  composer: defaultComposerState,
  settings: null,
  anchors: [],
  permissions: [],
  tools: [],
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
        agentMode: action.snapshot.agentMode ?? state.agentMode,
        recipes: Array.isArray(action.snapshot.recipes) ? action.snapshot.recipes : state.recipes,
        settings: action.snapshot.settings ?? state.settings,
        anchors: Array.isArray(action.snapshot.anchors) ? action.snapshot.anchors : state.anchors,
        permissions: Array.isArray(action.snapshot.permissions)
          ? action.snapshot.permissions
          : state.permissions,
        tools: Array.isArray(action.snapshot.tools) ? action.snapshot.tools : state.tools,
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
          statusMessage: null,
          errorMessage: null
        }
      };
    case "localInstruction":
      return {
        ...state,
        composer: {
          ...state.composer,
          instruction: action.instruction,
          statusMessage: null,
          errorMessage: null
        }
      };
    case "localRecipe":
      return {
        ...state,
        composer: {
          ...state.composer,
          selectedRecipeID: action.recipeID,
          statusMessage: null,
          errorMessage: null
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
          statusMessage: null,
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
    default:
      return state;
  }
}
