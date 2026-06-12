export const BRIDGE_VERSION = 1 as const;

export type ThemeName = "light" | "dark";
export type ThemeFunction = (theme: string) => void;
export type BridgeReceiveFunction = (base64: string) => void;
export type FocusFunction = () => void;

export type BridgeTool =
  | "app.hideComposer"
  | "app.snapshot"
  | "composer.setDraft"
  | "composer.setInstruction"
  | "composer.selectRecipe"
  | "composer.clear"
  | "llm.stream"
  | "llm.cancel"
  | "clipboard.copyGeneratedOutput";

export interface BridgeContext {
  userAction: boolean;
  confirmed: boolean;
}

export interface BridgeToolCall<Payload = unknown> {
  version: typeof BRIDGE_VERSION;
  id: string;
  type: "tool.call";
  tool: BridgeTool;
  payload: Payload;
  context?: BridgeContext;
}

export interface BridgeSafeError {
  code: string;
  message: string;
  field: string | null;
  retryable: boolean;
}

export interface BridgeSuccess<Payload = unknown> {
  version: typeof BRIDGE_VERSION;
  id: string;
  type: "tool.result";
  ok: true;
  payload: Payload;
}

export interface BridgeFailure {
  version: typeof BRIDGE_VERSION;
  id: string;
  type: "tool.result";
  ok: false;
  error: BridgeSafeError;
}

export type BridgeResult<Payload = unknown> = BridgeSuccess<Payload> | BridgeFailure;

export interface NativeEvent<Payload = Record<string, unknown>> {
  version: typeof BRIDGE_VERSION;
  type: "event";
  event: NativeEventName;
  requestID?: string;
  payload?: Payload;
}

export type NativeEventName =
  | "llm.started"
  | "llm.delta"
  | "llm.completed"
  | "llm.failed"
  | "llm.cancelled";

export interface TransformRecipe {
  id: string;
  name: string;
}

export interface ComposerState {
  draftText: string;
  instruction: string;
  selectedRecipeID: string;
  generatedOutput: string;
  isGenerating: boolean;
  canGenerate: boolean;
  canCopy: boolean;
  statusMessage: string | null;
  errorMessage: string | null;
}

export interface NativeSnapshot {
  recipes: TransformRecipe[];
  composer: Partial<ComposerState>;
}

export interface ComposerToolPayload {
  draftText?: string;
  instruction?: string;
  recipeID?: string;
}

export interface LLMStreamPayload {
  draftText: string;
  instruction: string;
  recipeID: string;
}

export interface LLMCancelPayload {
  requestID: string;
}

export interface LLMStreamResult {
  composer?: Partial<ComposerState>;
}

export interface LLMDeltaPayload {
  text?: string;
}

export interface LLMFailurePayload {
  message?: string;
}
