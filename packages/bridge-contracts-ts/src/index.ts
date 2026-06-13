export const BRIDGE_VERSION = 1 as const;

export type BridgeMessageType =
  | "tool.call"
  | "tool.result"
  | "event"
  | "tool.cancel"
  | "tool.approve"
  | "tool.reject";

export type AgentMode = "manual_transform" | "assisted_workflow" | "live_agent";

export type NativeToolEffect =
  | "read_state"
  | "write_transient_state"
  | "provider_network"
  | "clipboard_write"
  | "app_activation"
  | "settings"
  | "permission_prompt"
  | "file_picker"
  | "file_read"
  | "file_write"
  | "network"
  | "cancellation";

export interface NativeToolDescriptor {
  id: string;
  displayName: string;
  description: string;
  effect: NativeToolEffect;
  minimumAgentMode: AgentMode;
  requiresExplicitUserAction: boolean;
  requiresPerCallConfirmation: boolean;
  supportsCancellation: boolean;
  streams: boolean;
}

export const NATIVE_TOOL_DESCRIPTORS = [
  {
    id: "app.hideComposer",
    displayName: "Hide Composer",
    description: "Hide the current native composer panel after an explicit user action.",
    effect: "app_activation",
    minimumAgentMode: "manual_transform",
    requiresExplicitUserAction: true,
    requiresPerCallConfirmation: false,
    supportsCancellation: false,
    streams: false
  },
  {
    id: "app.snapshot",
    displayName: "Get App Snapshot",
    description: "Read the current native executor snapshot without secrets, paths, screenshots, or window titles.",
    effect: "read_state",
    minimumAgentMode: "manual_transform",
    requiresExplicitUserAction: false,
    requiresPerCallConfirmation: false,
    supportsCancellation: false,
    streams: false
  },
  {
    id: "composer.getState",
    displayName: "Get Composer State",
    description: "Read the current transient composer state snapshot.",
    effect: "read_state",
    minimumAgentMode: "manual_transform",
    requiresExplicitUserAction: false,
    requiresPerCallConfirmation: false,
    supportsCancellation: false,
    streams: false
  },
  {
    id: "composer.setDraft",
    displayName: "Set Draft",
    description: "Replace the current transient composer draft.",
    effect: "write_transient_state",
    minimumAgentMode: "manual_transform",
    requiresExplicitUserAction: false,
    requiresPerCallConfirmation: false,
    supportsCancellation: false,
    streams: false
  },
  {
    id: "composer.setInstruction",
    displayName: "Set Instruction",
    description: "Replace the current transient composer instruction.",
    effect: "write_transient_state",
    minimumAgentMode: "manual_transform",
    requiresExplicitUserAction: false,
    requiresPerCallConfirmation: false,
    supportsCancellation: false,
    streams: false
  },
  {
    id: "composer.selectRecipe",
    displayName: "Select Recipe",
    description: "Select one of the current transform recipes.",
    effect: "write_transient_state",
    minimumAgentMode: "manual_transform",
    requiresExplicitUserAction: false,
    requiresPerCallConfirmation: false,
    supportsCancellation: false,
    streams: false
  },
  {
    id: "composer.clear",
    displayName: "Clear Composer",
    description: "Clear the current transient composer session.",
    effect: "write_transient_state",
    minimumAgentMode: "manual_transform",
    requiresExplicitUserAction: true,
    requiresPerCallConfirmation: false,
    supportsCancellation: false,
    streams: false
  },
  {
    id: "llm.chat",
    displayName: "Generate Text",
    description: "Ask native to run one OpenAI-compatible chat completion with stored provider settings.",
    effect: "provider_network",
    minimumAgentMode: "manual_transform",
    requiresExplicitUserAction: true,
    requiresPerCallConfirmation: false,
    supportsCancellation: true,
    streams: false
  },
  {
    id: "llm.stream",
    displayName: "Stream Text",
    description: "Ask native to stream an OpenAI-compatible chat completion with stored provider settings.",
    effect: "provider_network",
    minimumAgentMode: "manual_transform",
    requiresExplicitUserAction: true,
    requiresPerCallConfirmation: false,
    supportsCancellation: true,
    streams: true
  },
  {
    id: "llm.cancel",
    displayName: "Cancel Generation",
    description: "Cancel an in-flight native LLM request.",
    effect: "cancellation",
    minimumAgentMode: "manual_transform",
    requiresExplicitUserAction: false,
    requiresPerCallConfirmation: false,
    supportsCancellation: false,
    streams: false
  },
  {
    id: "clipboard.copyGeneratedOutput",
    displayName: "Copy Output",
    description: "Write the current generated output to the clipboard after an explicit Copy action.",
    effect: "clipboard_write",
    minimumAgentMode: "manual_transform",
    requiresExplicitUserAction: true,
    requiresPerCallConfirmation: false,
    supportsCancellation: false,
    streams: false
  },
  {
    id: "appAnchors.list",
    displayName: "List App Anchors",
    description: "Read app-level jump anchors without window titles or screenshots.",
    effect: "read_state",
    minimumAgentMode: "manual_transform",
    requiresExplicitUserAction: false,
    requiresPerCallConfirmation: false,
    supportsCancellation: false,
    streams: false
  },
  {
    id: "appAnchors.activate",
    displayName: "Activate App Anchor",
    description: "Switch back to a selected app-level anchor.",
    effect: "app_activation",
    minimumAgentMode: "manual_transform",
    requiresExplicitUserAction: true,
    requiresPerCallConfirmation: false,
    supportsCancellation: false,
    streams: false
  },
  {
    id: "settings.open",
    displayName: "Open Settings",
    description: "Ask native to open the settings window.",
    effect: "settings",
    minimumAgentMode: "manual_transform",
    requiresExplicitUserAction: true,
    requiresPerCallConfirmation: false,
    supportsCancellation: false,
    streams: false
  },
  {
    id: "settings.summary",
    displayName: "Read Settings Summary",
    description: "Read a non-secret settings summary.",
    effect: "read_state",
    minimumAgentMode: "manual_transform",
    requiresExplicitUserAction: false,
    requiresPerCallConfirmation: false,
    supportsCancellation: false,
    streams: false
  },
  {
    id: "permissions.status",
    displayName: "Read Permission Status",
    description: "Read native permission and privacy status.",
    effect: "read_state",
    minimumAgentMode: "manual_transform",
    requiresExplicitUserAction: false,
    requiresPerCallConfirmation: false,
    supportsCancellation: false,
    streams: false
  },
  {
    id: "permissions.request",
    displayName: "Request Permission",
    description: "Ask native to start a platform permission flow.",
    effect: "permission_prompt",
    minimumAgentMode: "manual_transform",
    requiresExplicitUserAction: true,
    requiresPerCallConfirmation: true,
    supportsCancellation: false,
    streams: false
  },
  {
    id: "files.pickReadable",
    displayName: "Choose Readable File",
    description: "Ask native to open a file picker and issue an ephemeral read grant for one user-selected file.",
    effect: "file_picker",
    minimumAgentMode: "assisted_workflow",
    requiresExplicitUserAction: true,
    requiresPerCallConfirmation: true,
    supportsCancellation: false,
    streams: false
  },
  {
    id: "files.readText",
    displayName: "Read Text File",
    description: "Ask native to read text from a file grant issued by a native file picker.",
    effect: "file_read",
    minimumAgentMode: "assisted_workflow",
    requiresExplicitUserAction: true,
    requiresPerCallConfirmation: true,
    supportsCancellation: false,
    streams: false
  },
  {
    id: "files.pickWritable",
    displayName: "Choose Write Target",
    description: "Ask native to open a save panel and issue an ephemeral write grant for one user-approved file target.",
    effect: "file_picker",
    minimumAgentMode: "assisted_workflow",
    requiresExplicitUserAction: true,
    requiresPerCallConfirmation: true,
    supportsCancellation: false,
    streams: false
  },
  {
    id: "files.writeText",
    displayName: "Write Text File",
    description: "Ask native to write text to a file grant issued by a native save panel.",
    effect: "file_write",
    minimumAgentMode: "assisted_workflow",
    requiresExplicitUserAction: true,
    requiresPerCallConfirmation: true,
    supportsCancellation: false,
    streams: false
  },
  {
    id: "network.fetch",
    displayName: "Fetch Network Resource",
    description: "Ask native to execute a manifest-governed network request.",
    effect: "network",
    minimumAgentMode: "assisted_workflow",
    requiresExplicitUserAction: true,
    requiresPerCallConfirmation: true,
    supportsCancellation: true,
    streams: false
  },
  {
    id: "tools.list",
    displayName: "List Tools",
    description: "Read native-hosted tool descriptors and policies.",
    effect: "read_state",
    minimumAgentMode: "manual_transform",
    requiresExplicitUserAction: false,
    requiresPerCallConfirmation: false,
    supportsCancellation: false,
    streams: false
  }
] as const satisfies readonly NativeToolDescriptor[];

export type BridgeTool = (typeof NATIVE_TOOL_DESCRIPTORS)[number]["id"];

export const NATIVE_EVENT_NAMES = [
  "llm.started",
  "llm.delta",
  "llm.completed",
  "llm.failed",
  "llm.cancelled",
  "tool.started",
  "tool.progress",
  "tool.resultDelta",
  "tool.completed",
  "tool.failed",
  "tool.cancelled"
] as const;

export type NativeEventName = (typeof NATIVE_EVENT_NAMES)[number];

export function toolDescriptorFor(tool: BridgeTool): NativeToolDescriptor {
  return NATIVE_TOOL_DESCRIPTORS.find((descriptor) => descriptor.id === tool) ??
    (() => {
      throw new Error(`Unknown Inputo bridge tool: ${tool}`);
    })();
}

export function toolRequiresConfirmation(tool: BridgeTool): boolean {
  return toolDescriptorFor(tool).requiresPerCallConfirmation;
}

export function toolRequiresUserAction(tool: BridgeTool): boolean {
  return toolDescriptorFor(tool).requiresExplicitUserAction;
}

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

export interface BridgeCancelEnvelope {
  version: typeof BRIDGE_VERSION;
  id: string;
  type: "tool.cancel";
  requestID: string;
  reason?: string;
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

export interface TransformRecipe {
  id: string;
  name: string;
  systemPrompt?: string;
  outputHint?: string;
  isBuiltIn?: boolean;
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

export interface ProviderSummary {
  baseURL: string;
  model: string;
  endpointPreview: string | null;
  hasAPIKey: boolean;
  validationError: string | null;
}

export interface SettingsSummary {
  provider: ProviderSummary;
  hasHotKey: boolean;
  customRecipeCount: number;
}

export type PermissionID =
  | "provider.network"
  | "clipboard.write"
  | "appAnchors"
  | "accessibility"
  | "screenRecording"
  | "file.read"
  | "file.write"
  | "network.tools"
  | "mcp.tools";

export type PermissionState =
  | "available"
  | "unavailable"
  | "not_required"
  | "not_requested"
  | "requires_user_action"
  | "denied";

export interface PermissionSnapshot {
  id: PermissionID;
  displayName: string;
  state: PermissionState;
  detail: string;
}

export interface AppAnchorSnapshot {
  id: string;
  appName: string;
  bundleIdentifier: string | null;
  processIdentifier: number;
  lastActiveAt: string | number | null;
  canActivate: boolean;
}

export type FileGrantScope = "read" | "write";

export interface FilePickRequest {
  allowedContentTypes: string[];
  allowsMultipleSelection: boolean;
  suggestedFileName: string | null;
}

export interface FileGrantSnapshot {
  id: string;
  scope: FileGrantScope;
  displayName: string;
  contentType: string | null;
  byteCount: number | null;
  expiresAt: string | number | null;
}

export interface FilePickResponse {
  grants: FileGrantSnapshot[];
}

export interface FileReadTextRequest {
  grantID: string;
  maxBytes: number;
  encoding: string | null;
}

export interface FileReadTextResponse {
  grantID: string;
  displayName: string;
  text: string;
  encoding: string;
}

export interface FileWriteTextRequest {
  grantID: string;
  text: string;
  encoding: string;
  overwrite: boolean;
}

export interface FileWriteTextResponse {
  grantID: string;
  displayName: string;
  byteCount: number;
}

export interface NativeSnapshot {
  version?: typeof BRIDGE_VERSION;
  agentMode?: AgentMode;
  recipes: TransformRecipe[];
  composer: Partial<ComposerState>;
  settings?: SettingsSummary;
  anchors?: AppAnchorSnapshot[];
  permissions?: PermissionSnapshot[];
  tools?: NativeToolDescriptor[];
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

export interface ToolCancelResponse {
  requestID: string;
  didCancel: boolean;
}

export interface LLMStreamResult {
  generatedOutput?: string;
  composer?: Partial<ComposerState>;
}

export interface LLMDeltaPayload {
  text?: string;
  sequence?: number;
  isFinal?: boolean;
}

export interface LLMFailurePayload {
  code?: string;
  message?: string;
  field?: string | null;
  retryable?: boolean;
}

export interface AppAnchorActivateRequest {
  anchorID: string;
}

export interface PermissionRequest {
  permissionID: PermissionID;
}

export interface PermissionResponse {
  permission: PermissionSnapshot;
}

export interface BridgeToolsFixture {
  version: typeof BRIDGE_VERSION;
  tools: NativeToolDescriptor[];
  events: NativeEventName[];
}
