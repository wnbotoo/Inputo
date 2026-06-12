import {
  BRIDGE_VERSION,
  type BridgeContext,
  type BridgeFailure,
  type BridgeReceiveFunction,
  type BridgeResult,
  type BridgeTool,
  type BridgeToolCall,
  type NativeEvent
} from "./types";

interface PendingRequest {
  resolve: (message: BridgeResult) => void;
}

export interface BridgeRuntime {
  atob(data: string): string;
  webkit?: Window["webkit"];
}

type NativeEventListener = (event: NativeEvent) => void;

export const USER_ACTION_CONTEXT: BridgeContext = {
  userAction: true,
  confirmed: false
};

export function makeBridgeID(prefix: string): string {
  const random = Math.random().toString(36).slice(2);
  return `${prefix}-${Date.now().toString(36)}-${random}`;
}

export class InputoBridgeClient {
  private readonly pending = new Map<string, PendingRequest>();
  private readonly eventListeners = new Set<NativeEventListener>();

  constructor(private readonly runtime: BridgeRuntime = defaultRuntime()) {}

  installGlobalReceiver(receiver: { InputoNativeBridgeReceiveBase64?: BridgeReceiveFunction }): void {
    receiver.InputoNativeBridgeReceiveBase64 = (base64: string) => {
      this.receiveBase64(base64);
    };
  }

  onEvent(listener: NativeEventListener): () => void {
    this.eventListeners.add(listener);
    return () => {
      this.eventListeners.delete(listener);
    };
  }

  callTool<Payload = unknown, ResultPayload = unknown>(
    tool: BridgeTool,
    payload: Payload,
    context: BridgeContext | null = null,
    id = makeBridgeID(tool.replaceAll(".", "-"))
  ): Promise<BridgeResult<ResultPayload>> {
    const envelope: BridgeToolCall<Payload> = {
      version: BRIDGE_VERSION,
      id,
      type: "tool.call",
      tool,
      payload
    };
    if (context) {
      envelope.context = context;
    }

    return new Promise((resolve) => {
      this.pending.set(id, { resolve: resolve as PendingRequest["resolve"] });
      try {
        this.postEnvelope(envelope);
      } catch (error) {
        this.pending.delete(id);
        resolve(internalErrorResult(id, error) as BridgeResult<ResultPayload>);
      }
    });
  }

  receiveBase64(base64: string): void {
    let message: BridgeResult | NativeEvent;
    try {
      message = this.decodeBase64JSON(base64);
    } catch {
      this.emitEvent({
        version: BRIDGE_VERSION,
        type: "event",
        event: "llm.failed",
        payload: {
          message: "Native bridge returned an unreadable message."
        }
      });
      return;
    }

    if (message.type === "event") {
      this.emitEvent(message);
      return;
    }

    const pendingRequest = this.pending.get(message.id);
    if (pendingRequest) {
      this.pending.delete(message.id);
      pendingRequest.resolve(message);
    }
  }

  private postEnvelope(envelope: BridgeToolCall): void {
    const handler = this.runtime.webkit?.messageHandlers?.inputoNative;
    if (!handler) {
      throw new Error("Native bridge is unavailable.");
    }
    handler.postMessage(JSON.stringify(envelope));
  }

  private decodeBase64JSON(base64: string): BridgeResult | NativeEvent {
    const binary = this.runtime.atob(base64);
    const bytes = new Uint8Array(binary.length);
    for (let index = 0; index < binary.length; index += 1) {
      bytes[index] = binary.charCodeAt(index);
    }
    return JSON.parse(new TextDecoder().decode(bytes)) as BridgeResult | NativeEvent;
  }

  private emitEvent(event: NativeEvent): void {
    for (const listener of this.eventListeners) {
      listener(event);
    }
  }
}

function internalErrorResult(id: string, error: unknown): BridgeFailure {
  const message = error instanceof Error ? error.message : "Native bridge is unavailable.";
  return {
    version: BRIDGE_VERSION,
    id,
    type: "tool.result",
    ok: false,
    error: {
      code: "internal_error",
      message,
      field: null,
      retryable: false
    }
  };
}

function defaultRuntime(): BridgeRuntime {
  if (typeof window !== "undefined") {
    return {
      atob: window.atob.bind(window),
      webkit: window.webkit
    };
  }

  return {
    atob: globalThis.atob.bind(globalThis)
  };
}

export const inputoBridge = new InputoBridgeClient();
