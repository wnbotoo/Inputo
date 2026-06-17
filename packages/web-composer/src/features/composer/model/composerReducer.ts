import type {
  CommandReceivedPayload,
  ComposerState,
  LLMDeltaPayload,
  LLMFailurePayload,
  AppAnchorSnapshot,
  AgentMode,
  NativeEvent,
  NativeSnapshot,
  NativeToolDescriptor,
  PermissionSnapshot,
  PreviewPayload,
  SettingsSummary,
  TransformRecipe
} from "@inputo/bridge-contracts";
import { composerStrings } from "./composerStrings";
import {
  normalizePreviewPayload,
  previewPayloadFromCommand,
  previewPayloadFromOutput
} from "./previewRuntime";

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
  routedCommand: CommandReceivedPayload | null;
  previewPayload: PreviewPayload | null;
}

export const initialComposerViewState: ComposerViewState = {
  agentMode: null,
  recipes: [],
  composer: defaultComposerState,
  settings: null,
  anchors: [],
  permissions: [],
  tools: [],
  activeRequestID: null,
  routedCommand: null,
  previewPayload: null
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
    case "applySnapshot": {
      const recipes = Array.isArray(action.snapshot.recipes)
        ? action.snapshot.recipes
        : state.recipes;
      return {
        ...state,
        agentMode: action.snapshot.agentMode ?? state.agentMode,
        recipes,
        settings: action.snapshot.settings ?? state.settings,
        anchors: Array.isArray(action.snapshot.anchors) ? action.snapshot.anchors : state.anchors,
        permissions: Array.isArray(action.snapshot.permissions)
          ? action.snapshot.permissions
          : state.permissions,
        tools: Array.isArray(action.snapshot.tools) ? action.snapshot.tools : state.tools,
        composer: normalizeSelectedRecipe(
          mergeComposer(state.composer, action.snapshot.composer),
          recipes
        )
      };
    }
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
        routedCommand: null,
        previewPayload: null,
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
        activeRequestID: null,
        composer: {
          ...state.composer,
          isGenerating: false
        }
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
  if (event.event !== "llm.started" && event.requestID && state.activeRequestID !== event.requestID) {
    return state;
  }

  switch (event.event) {
    case "command.received": {
      const payload = event.payload as CommandReceivedPayload | undefined;
      const previewPayload = payload ? previewPayloadFromCommand(payload) : null;
      return {
        ...state,
        activeRequestID: null,
        routedCommand: payload ?? null,
        previewPayload,
        composer: {
          ...state.composer,
          generatedOutput: "",
          isGenerating: false,
          statusMessage: payload
            ? (previewPayload ? `Rendered /${payload.commandName}.` : `Received /${payload.commandName}.`)
            : null,
          errorMessage: null
        }
      };
    }
    case "preview.render": {
      const payload = normalizePreviewPayload(event.payload);
      return {
        ...state,
        activeRequestID: null,
        routedCommand: null,
        previewPayload: payload,
        composer: {
          ...state.composer,
          generatedOutput: payload?.content ?? "",
          isGenerating: false,
          statusMessage: payload ? composerStrings.previewRendered : null,
          errorMessage: payload ? null : composerStrings.previewPayloadInvalid
        }
      };
    }
    case "llm.started":
      return {
        ...state,
        activeRequestID: event.requestID ?? state.activeRequestID,
        routedCommand: null,
        previewPayload: null,
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
      const generatedOutput = `${state.composer.generatedOutput}${payload?.text ?? ""}`;
      return {
        ...state,
        previewPayload: previewPayloadFromOutput(generatedOutput, { isFinal: false }),
        composer: {
          ...state.composer,
          generatedOutput,
          isGenerating: true
        }
      };
    }
    case "llm.completed":
      return {
        ...state,
        activeRequestID: null,
        previewPayload: previewPayloadFromOutput(state.composer.generatedOutput, { isFinal: true }),
        composer: {
          ...state.composer,
          isGenerating: false,
          statusMessage: state.composer.generatedOutput.trim().length > 0
            ? composerStrings.readyToCopy
            : composerStrings.noOutputReturned,
          errorMessage: null
        }
      };
    case "llm.failed": {
      const payload = event.payload as LLMFailurePayload | undefined;
      return {
        ...state,
        activeRequestID: null,
        previewPayload: null,
        composer: {
          ...state.composer,
          isGenerating: false,
          statusMessage: null,
          errorMessage: payload?.message ?? composerStrings.generationFailed
        }
      };
    }
    case "llm.cancelled":
      return {
        ...state,
        activeRequestID: null,
        previewPayload: null,
        composer: {
          ...state.composer,
          isGenerating: false,
          statusMessage: composerStrings.generationCancelled,
          errorMessage: null
        }
      };
    default:
      return state;
  }
}

function normalizeSelectedRecipe(
  composer: ComposerState,
  recipes: TransformRecipe[]
): ComposerState {
  if (recipes.length === 0 || recipes.some((recipe) => recipe.id === composer.selectedRecipeID)) {
    return composer;
  }
  return {
    ...composer,
    selectedRecipeID: recipes[0].id
  };
}
