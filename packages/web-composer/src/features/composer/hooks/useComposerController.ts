import {
  useCallback,
  useEffect,
  useMemo,
  useReducer,
  useRef,
  type ChangeEvent,
  type CompositionEvent,
  type InputEvent as ReactInputEvent,
  type RefObject
} from "react";
import {
  inputoBridge,
  makeBridgeID,
  USER_ACTION_CONTEXT
} from "../../../shared/bridge/bridgeClient";
import type {
  BridgeResult,
  ComposerState,
  FilePickRequest,
  FilePickResponse,
  FileReadTextRequest,
  FileReadTextResponse,
  FileWriteTextRequest,
  FileWriteTextResponse,
  LLMCancelPayload,
  LLMStreamPayload,
  LLMStreamResult,
  NativeEvent,
  NativeSnapshot,
  SettingsSummary,
  ToolCancelResponse
} from "@inputo/bridge-contracts";
import {
  composerReducer,
  initialComposerViewState,
  type ComposerViewState
} from "../model/composerReducer";

const SYNC_DELAY_MS = 160;
const COMPOSITION_ESCAPE_GRACE_MS = 700;

export interface ComposerStatus {
  text: string;
  isError: boolean;
}

export interface ProviderSetupNotice {
  message: string;
  detail: string;
}

export interface NativeFileToolsState {
  label: string;
  canRead: boolean;
  canWrite: boolean;
}

export interface ComposerController {
  viewState: ComposerViewState;
  composer: ComposerState;
  draftRef: RefObject<HTMLTextAreaElement | null>;
  hasOutput: boolean;
  previewText: string;
  canGenerate: boolean;
  isGenerating: boolean;
  status: ComposerStatus;
  providerSetup: ProviderSetupNotice | null;
  fileTools: NativeFileToolsState;
  generate: () => Promise<void>;
  cancelGeneration: () => Promise<void>;
  clearComposer: () => Promise<void>;
  copyOutput: () => Promise<void>;
  openSettings: () => Promise<void>;
  readTextFile: () => Promise<void>;
  saveOutputFile: () => Promise<void>;
  markCompositionActivity: (isActive?: boolean) => void;
  handleDraftCompositionEnd: (event: CompositionEvent<HTMLTextAreaElement>) => void;
  handleInstructionCompositionEnd: (event: CompositionEvent<HTMLInputElement>) => void;
  handleDraftChange: (event: ChangeEvent<HTMLTextAreaElement>) => void;
  handleInstructionChange: (event: ChangeEvent<HTMLInputElement>) => void;
  handleRecipeChange: (event: ChangeEvent<HTMLSelectElement>) => void;
  handleBeforeInput: (event: ReactInputEvent<HTMLInputElement | HTMLTextAreaElement>) => void;
}

export function useComposerController(): ComposerController {
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
    const providerSetup = providerSetupNotice(current.settings);
    if (
      current.composer.draftText.trim().length === 0 ||
      providerSetup ||
      current.composer.isGenerating ||
      current.activeRequestID
    ) {
      if (providerSetup) {
        dispatch({
          type: "applyComposer",
          composer: {
            errorMessage: providerSetup.message
          }
        });
      }
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
    const response = await inputoBridge.callTool<LLMCancelPayload, ToolCancelResponse>("llm.cancel", {
      requestID
    });
    if (response.ok && response.payload.didCancel) {
      dispatch({
        type: "applyComposer",
        composer: {
          isGenerating: false,
          statusMessage: "Generation cancelled."
        }
      });
      dispatch({ type: "clearActiveRequest" });
    } else if (!response.ok) {
      dispatch({
        type: "applyComposer",
        composer: {
          isGenerating: false,
          errorMessage: response.error.message
        }
      });
    }
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

  const openSettings = useCallback(async () => {
    const response = await inputoBridge.callTool<Record<string, never>, unknown>(
      "settings.open",
      {},
      USER_ACTION_CONTEXT
    );
    if (!response.ok) {
      dispatch({
        type: "applyComposer",
        composer: {
          errorMessage: response.error.message
        }
      });
    }
  }, []);

  const applyDraftFromFile = useCallback((text: string, displayName: string) => {
    dispatch({ type: "localDraft", draftText: text });
    inputoBridge
      .callTool<{ draftText: string }, Partial<ComposerState>>("composer.setDraft", { draftText: text })
      .then((response) => {
        if (response.ok) {
          dispatch({
            type: "applyComposer",
            composer: {
              ...response.payload,
              statusMessage: `Loaded ${displayName}.`,
              errorMessage: null
            }
          });
        } else {
          dispatch({
            type: "applyComposer",
            composer: {
              errorMessage: response.error.message
            }
          });
        }
      });
  }, []);

  const readTextFile = useCallback(async () => {
    const currentFileTools = fileToolsState(stateRef.current);
    if (!currentFileTools.canRead) {
      return;
    }
    const pickResponse = await inputoBridge.callTool<FilePickRequest, FilePickResponse>(
      "files.pickReadable",
      {
        allowedContentTypes: ["public.text"],
        allowsMultipleSelection: false,
        suggestedFileName: null
      },
      USER_ACTION_CONTEXT
    );
    if (!pickResponse.ok) {
      dispatch({ type: "applyComposer", composer: { errorMessage: pickResponse.error.message } });
      return;
    }
    const grant = pickResponse.payload.grants[0];
    if (!grant) {
      dispatch({ type: "applyComposer", composer: { errorMessage: "No readable file was selected." } });
      return;
    }
    const readResponse = await inputoBridge.callTool<FileReadTextRequest, FileReadTextResponse>(
      "files.readText",
      {
        grantID: grant.id,
        maxBytes: 1_048_576,
        encoding: "utf-8"
      },
      USER_ACTION_CONTEXT
    );
    if (readResponse.ok) {
      applyDraftFromFile(readResponse.payload.text, readResponse.payload.displayName);
    } else {
      dispatch({ type: "applyComposer", composer: { errorMessage: readResponse.error.message } });
    }
  }, [applyDraftFromFile]);

  const saveOutputFile = useCallback(async () => {
    const current = stateRef.current;
    const currentFileTools = fileToolsState(current);
    const text = current.composer.generatedOutput;
    if (!currentFileTools.canWrite || text.trim().length === 0) {
      return;
    }
    const pickResponse = await inputoBridge.callTool<FilePickRequest, FilePickResponse>(
      "files.pickWritable",
      {
        allowedContentTypes: ["public.text"],
        allowsMultipleSelection: false,
        suggestedFileName: "inputo-output.txt"
      },
      USER_ACTION_CONTEXT
    );
    if (!pickResponse.ok) {
      dispatch({ type: "applyComposer", composer: { errorMessage: pickResponse.error.message } });
      return;
    }
    const grant = pickResponse.payload.grants[0];
    if (!grant) {
      dispatch({ type: "applyComposer", composer: { errorMessage: "No write target was selected." } });
      return;
    }
    const writeResponse = await inputoBridge.callTool<FileWriteTextRequest, FileWriteTextResponse>(
      "files.writeText",
      {
        grantID: grant.id,
        text,
        encoding: "utf-8",
        overwrite: true
      },
      USER_ACTION_CONTEXT
    );
    if (writeResponse.ok) {
      dispatch({
        type: "applyComposer",
        composer: {
          statusMessage: `Saved ${writeResponse.payload.displayName}.`,
          errorMessage: null
        }
      });
    } else {
      dispatch({ type: "applyComposer", composer: { errorMessage: writeResponse.error.message } });
    }
  }, []);

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
  const providerSetup = useMemo(
    () => providerSetupNotice(viewState.settings),
    [viewState.settings]
  );
  const fileTools = useMemo(
    () => fileToolsState(viewState),
    [viewState]
  );
  const canGenerate = composer.draftText.trim().length > 0 &&
    !providerSetup &&
    !composer.isGenerating &&
    !viewState.activeRequestID;
  const isGenerating = composer.isGenerating || Boolean(viewState.activeRequestID);
  const status = useMemo<ComposerStatus>(() => {
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

  return {
    viewState,
    composer,
    draftRef,
    hasOutput,
    previewText,
    canGenerate,
    isGenerating,
    status,
    providerSetup,
    fileTools,
    generate,
    cancelGeneration,
    clearComposer,
    copyOutput,
    openSettings,
    readTextFile,
    saveOutputFile,
    markCompositionActivity,
    handleDraftCompositionEnd,
    handleInstructionCompositionEnd,
    handleDraftChange,
    handleInstructionChange,
    handleRecipeChange,
    handleBeforeInput
  };
}

function providerSetupNotice(settings: SettingsSummary | null): ProviderSetupNotice | null {
  if (!settings) {
    return null;
  }
  if (settings.provider.validationError) {
    return {
      message: settings.provider.validationError,
      detail: "Open Settings to update the provider URL or model."
    };
  }
  if (!settings.provider.hasAPIKey) {
    return {
      message: "Add an API key in Settings before generating.",
      detail: "The API key stays in the native keychain and is never exposed to Web."
    };
  }
  return null;
}

function fileToolsState(state: ComposerViewState): NativeFileToolsState {
  const readPermission = state.permissions.find((permission) => permission.id === "file.read");
  const writePermission = state.permissions.find((permission) => permission.id === "file.write");
  const canRead = readPermission?.state === "available" || readPermission?.state === "requires_user_action";
  const canWrite = writePermission?.state === "available" || writePermission?.state === "requires_user_action";
  if (canRead || canWrite) {
    return {
      label: "Files require native confirmation",
      canRead,
      canWrite
    };
  }
  return {
    label: "Files unavailable",
    canRead: false,
    canWrite: false
  };
}
