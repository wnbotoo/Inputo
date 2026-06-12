import { describe, expect, it } from "vitest";
import { InputoBridgeClient, type BridgeRuntime } from "../bridge/bridgeClient";
import type { BridgeResult } from "../bridge/types";

describe("InputoBridgeClient", () => {
  it("posts typed bridge envelopes and resolves matching responses", async () => {
    const posted: string[] = [];
    const runtime: BridgeRuntime = {
      atob: (data) => Buffer.from(data, "base64").toString("binary"),
      webkit: {
        messageHandlers: {
          inputoNative: {
            postMessage(message: string) {
              posted.push(message);
            }
          }
        }
      }
    };
    const client = new InputoBridgeClient(runtime);
    const pending = client.callTool("app.snapshot", {}, null, "request-1");

    expect(JSON.parse(posted[0])).toEqual({
      version: 1,
      id: "request-1",
      type: "tool.call",
      tool: "app.snapshot",
      payload: {}
    });

    client.receiveBase64(encodeBase64JSON({
      version: 1,
      id: "request-1",
      type: "tool.result",
      ok: true,
      payload: { ok: "yes" }
    }));

    await expect(pending).resolves.toEqual({
      version: 1,
      id: "request-1",
      type: "tool.result",
      ok: true,
      payload: { ok: "yes" }
    });
  });

  it("returns a safe error when the native handler is unavailable", async () => {
    const runtime: BridgeRuntime = {
      atob: (data) => Buffer.from(data, "base64").toString("binary")
    };
    const client = new InputoBridgeClient(runtime);

    const result = await client.callTool("app.snapshot", {}, null, "request-1");

    expect(result.ok).toBe(false);
    expect((result as BridgeResult & { ok: false }).error.code).toBe("internal_error");
  });

  it("routes native events to listeners", () => {
    const runtime: BridgeRuntime = {
      atob: (data) => Buffer.from(data, "base64").toString("binary")
    };
    const client = new InputoBridgeClient(runtime);
    const events: string[] = [];
    client.onEvent((event) => {
      events.push(event.event);
    });

    client.receiveBase64(encodeBase64JSON({
      version: 1,
      type: "event",
      event: "llm.completed"
    }));

    expect(events).toEqual(["llm.completed"]);
  });
});

function encodeBase64JSON(value: unknown): string {
  return Buffer.from(JSON.stringify(value), "utf8").toString("base64");
}
