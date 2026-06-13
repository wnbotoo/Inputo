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
import {
  BRIDGE_VERSION,
  type BridgeResult,
  type ComposerState,
  type FilePickRequest,
  type FilePickResponse,
  type FileReadTextRequest,
  type FileReadTextResponse,
  type FileWriteTextRequest,
  type FileWriteTextResponse,
  type LLMCancelPayload,
  type LLMStreamPayload,
  type LLMStreamResult,
  type NativeEvent,
  type NativeSnapshot,
  type PermissionSnapshot,
  type PermissionState,
  type SettingsSummary,
  type ToolCancelResponse
} from "@inputo/bridge-contracts";
import {
  composerReducer,
  initialComposerViewState,
  type ComposerViewState
} from "../model/composerReducer";
import { composerStrings } from "../model/composerStrings";

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
  readDetail: string;
  writeDetail: string;
  canRead: boolean;
  canWrite: boolean;
}

export interface PermissionSummaryItem {
  id: string;
  label: string;
  stateLabel: string;
  detail: string;
  tone: "ok" | "warn" | "off";
}

export interface RuntimeDiagnostics {
  summary: string;
  items: Array<{
    label: string;
    value: string;
  }>;
  permissions: PermissionSummaryItem[];
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
  diagnostics: RuntimeDiagnostics;
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
  const ignoredRequestIDs = useRef(new Set<string>());
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
    ignoredRequestIDs.current.delete(requestID);
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

    const activeRequestID = stateRef.current.activeRequestID;
    if (ignoredRequestIDs.current.has(requestID) || (activeRequestID && activeRequestID !== requestID)) {
      return;
    }
    dispatch({ type: "clearActiveRequest" });
    if (response.ok) {
      dispatch({
        type: "applyComposer",
        composer: {
          isGenerating: false,
          ...(response.payload.composer ?? {})
        }
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
      ignoredRequestIDs.current.add(requestID);
      dispatch({
        type: "applyComposer",
        composer: {
          isGenerating: false,
          statusMessage: composerStrings.generationCancelled,
          errorMessage: null
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
    const activeRequestID = stateRef.current.activeRequestID;
    if (activeRequestID) {
      ignoredRequestIDs.current.add(activeRequestID);
      await inputoBridge.callTool<LLMCancelPayload, ToolCancelResponse>("llm.cancel", {
        requestID: activeRequestID
      });
    }
    const response = await inputoBridge.callTool<Record<string, never>, Partial<ComposerState>>(
      "composer.clear",
      {},
      USER_ACTION_CONTEXT
    );
    dispatch({ type: "clearActiveRequest" });
    applyToolComposerResult(response);
    focusDraft();
  }, [applyToolComposerResult, focusDraft]);

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
              statusMessage: composerStrings.loadedFile(displayName),
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
    dispatch({
      type: "applyComposer",
      composer: {
        statusMessage: composerStrings.chooseReadableFile,
        errorMessage: null
      }
    });
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
      dispatch({ type: "applyComposer", composer: { errorMessage: composerStrings.noReadableFileSelected } });
      return;
    }
    dispatch({
      type: "applyComposer",
      composer: {
        statusMessage: composerStrings.readingFile,
        errorMessage: null
      }
    });
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
    dispatch({
      type: "applyComposer",
      composer: {
        statusMessage: composerStrings.chooseWritableFile,
        errorMessage: null
      }
    });
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
      dispatch({ type: "applyComposer", composer: { errorMessage: composerStrings.noWriteTargetSelected } });
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
          statusMessage: composerStrings.savedFile(writeResponse.payload.displayName),
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
      if (event.requestID && ignoredRequestIDs.current.has(event.requestID)) {
        return;
      }
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
    : (composer.isGenerating ? composerStrings.generatingStatus : composerStrings.emptyPreview);
  const providerSetup = useMemo(
    () => providerSetupNotice(viewState.settings),
    [viewState.settings]
  );
  const fileTools = useMemo(
    () => fileToolsState(viewState),
    [viewState]
  );
  const diagnostics = useMemo(
    () => runtimeDiagnostics(viewState, providerSetup),
    [providerSetup, viewState]
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
      return { text: composerStrings.generatingStatus, isError: false };
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
    diagnostics,
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

export function providerSetupNotice(settings: SettingsSummary | null): ProviderSetupNotice | null {
  if (!settings) {
    return null;
  }
  if (settings.provider.validationError) {
    return {
      message: settings.provider.validationError,
      detail: composerStrings.providerValidationDetail
    };
  }
  if (!settings.provider.hasAPIKey) {
    return {
      message: composerStrings.missingAPIKey,
      detail: composerStrings.missingAPIKeyDetail
    };
  }
  return null;
}

export function fileToolsState(state: ComposerViewState): NativeFileToolsState {
  const readPermission = state.permissions.find((permission) => permission.id === "file.read");
  const writePermission = state.permissions.find((permission) => permission.id === "file.write");
  const canRead = readPermission?.state === "available" || readPermission?.state === "requires_user_action";
  const canWrite = writePermission?.state === "available" || writePermission?.state === "requires_user_action";
  if (canRead && canWrite) {
    return {
      label: composerStrings.filesNeedConfirmation,
      readDetail: readPermission?.detail ?? "",
      writeDetail: writePermission?.detail ?? "",
      canRead,
      canWrite
    };
  }
  if (canRead) {
    return {
      label: composerStrings.filesReadOnly,
      readDetail: readPermission?.detail ?? "",
      writeDetail: writePermission?.detail ?? "",
      canRead,
      canWrite
    };
  }
  if (canWrite) {
    return {
      label: composerStrings.filesWriteOnly,
      readDetail: readPermission?.detail ?? "",
      writeDetail: writePermission?.detail ?? "",
      canRead,
      canWrite
    };
  }
  return {
    label: composerStrings.filesUnavailable,
    readDetail: readPermission?.detail ?? "",
    writeDetail: writePermission?.detail ?? "",
    canRead: false,
    canWrite: false
  };
}

export function runtimeDiagnostics(
  state: ComposerViewState,
  providerSetup: ProviderSetupNotice | null
): RuntimeDiagnostics {
  const providerState = state.settings
    ? (providerSetup ? composerStrings.providerNeedsSetup : composerStrings.providerConfigured)
    : composerStrings.providerUnknown;
  const permissions = permissionSummaryItems(state.permissions);
  const availableCount = state.permissions.filter((permission) => permission.state === "available").length;
  const actionableCount = state.permissions.filter(
    (permission) => permission.state === "requires_user_action"
  ).length;
  const summary = state.permissions.length === 0
    ? composerStrings.noPermissionsReported
    : `${availableCount} available, ${actionableCount} user action`;

  return {
    summary,
    items: [
      { label: "Bridge", value: `v${BRIDGE_VERSION}` },
      { label: "Assets", value: composerStrings.bundledAssets },
      { label: "Provider", value: providerState },
      { label: "Mode", value: formatAgentMode(state.agentMode) },
      { label: "Tools", value: String(state.tools.length) }
    ],
    permissions
  };
}

function permissionSummaryItems(permissions: PermissionSnapshot[]): PermissionSummaryItem[] {
  return permissions.map((permission) => ({
    id: permission.id,
    label: permission.displayName,
    stateLabel: permissionStateLabel(permission.state),
    detail: permission.detail,
    tone: permissionTone(permission.state)
  }));
}

function permissionStateLabel(state: PermissionState): string {
  switch (state) {
    case "available":
      return composerStrings.available;
    case "unavailable":
      return composerStrings.unavailable;
    case "not_required":
      return composerStrings.notRequired;
    case "not_requested":
      return composerStrings.notRequested;
    case "requires_user_action":
      return composerStrings.requiresUserAction;
    case "denied":
      return composerStrings.denied;
    default:
      return composerStrings.unknown;
  }
}

function permissionTone(state: PermissionState): PermissionSummaryItem["tone"] {
  switch (state) {
    case "available":
    case "not_required":
      return "ok";
    case "requires_user_action":
    case "not_requested":
      return "warn";
    default:
      return "off";
  }
}

function formatAgentMode(agentMode: ComposerViewState["agentMode"]): string {
  switch (agentMode) {
    case "manual_transform":
      return "Manual";
    case "assisted_workflow":
      return "Assisted";
    case "live_agent":
      return "Live";
    default:
      return composerStrings.unknown;
  }
}
