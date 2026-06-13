import { describe, expect, it } from "vitest";
import {
  BRIDGE_VERSION,
  type BridgeToolsFixture,
  NATIVE_EVENT_NAMES,
  NATIVE_TOOL_DESCRIPTORS
} from "@inputo/bridge-contracts";
import fixture from "../../../../../contracts/bridge-tools.v1.json";

describe("bridge contract drift", () => {
  it("keeps TypeScript bridge descriptors aligned with shared fixtures", () => {
    const bridgeTools = fixture as BridgeToolsFixture;

    expect(bridgeTools.version).toBe(BRIDGE_VERSION);
    expect(bridgeTools.tools).toEqual(NATIVE_TOOL_DESCRIPTORS);
    expect(bridgeTools.events).toEqual(NATIVE_EVENT_NAMES);
  });
});
