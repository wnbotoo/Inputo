# Native Executor Contract

This document records the Phase 0 and Phase 1 landing work for the planned web planner plus native executor architecture.

Inputo has not started a React, Vite, or WKWebView implementation. The current goal is to make the native capability boundary explicit and testable while the native v0.1 app remains the primary product surface.

## Phase 0 Status

The native v0.1 loop remains the baseline:

- The Xcode `Inputo` app target stays thin and owns only app lifecycle, menu bar wiring, window hosting, hotkey registration, and panel activation.
- Product behavior lives in `InputoModules`.
- `InputoCore` remains Foundation-only.
- `InputoMacPlatform` owns macOS services: Keychain, clipboard, hotkey, settings, and app anchors.
- `InputoComposerFeature.AppState` remains the native feature composition root and uses injectable service protocols with fake test services.
- Clipboard writes still happen only through the explicit Copy action.
- Input text, generated output, window titles, screenshots, and tool history are not persisted.
- MCP/tools, arbitrary network tools, automatic paste, and screen recording remain disabled by default.

## Phase 1 Landing

The first native executor contracts now live in `InputoCore`:

- `InputoBridgeContract`
- `InputoAgentMode`
- `InputoBridgeMessageType`
- `InputoNativeToolID`
- `InputoNativeToolDescriptor`
- `InputoNativeToolError`
- `InputoToolEventName`
- `InputoStreamDelta`
- typed bridge envelopes for tool calls, tool results, events, and cancel messages
- composer, provider, settings, permission, app-anchor, and native executor snapshots

`InputoComposerFeature` now exposes:

- `AppState.nativeExecutorSnapshot(agentMode:)`
- `AppState.cancelActiveGeneration()`

The snapshot is an adapter over the current native state. Phase 2 adds the bridge dispatcher that reads this snapshot and executes allowlisted native tools.

## Default Native Tools

The initial native tool registry is allowlisted:

- `composer.getState`
- `composer.setDraft`
- `composer.selectRecipe`
- `composer.clear`
- `llm.chat`
- `llm.stream`
- `llm.cancel`
- `clipboard.copyGeneratedOutput`
- `appAnchors.list`
- `appAnchors.activate`
- `settings.open`
- `settings.summary`
- `permissions.status`
- `permissions.request`
- `files.pickReadable`
- `files.readText`
- `files.pickWritable`
- `files.writeText`
- `network.fetch`
- `tools.list`

Each descriptor declares:

- stable tool id
- display name and description
- side-effect class
- minimum agent mode
- whether explicit user action is required
- whether per-call confirmation is required
- whether cancellation is supported
- whether streaming is expected

In manual transform mode, provider LLM calls, clipboard writes, app activation, settings opening, permission prompts, file tools, and network tools are not automatically executable. `network.fetch` is present as a future contract, but it requires assisted workflow mode and per-call confirmation.

## File Tools

File access is a native platform capability and must not become a generic JavaScript filesystem API.

The initial file contract is grant-based:

- `files.pickReadable` opens a native picker and returns ephemeral read grants for user-selected files.
- `files.readText` reads text only from a native-issued read grant.
- `files.pickWritable` opens a native save panel and returns an ephemeral write grant for a user-approved target.
- `files.writeText` writes text only to a native-issued write grant.

File tool payloads use `grantID` and display metadata. They do not accept or return arbitrary absolute paths by default. File tools require assisted workflow mode, explicit user action, and per-call confirmation.

## Snapshot Privacy Boundary

`nativeExecutorSnapshot(agentMode:)` may expose the current transient composer draft and generated output to a future bundled web UI, because that UI would render the active composer surface.

The snapshot must not expose:

- API keys
- provider secret header values
- Keychain references that can read secrets
- arbitrary filesystem paths
- security-scoped bookmark data
- window titles
- screenshots
- app icons as binary data
- input history
- generated history
- MCP or connector state

App anchors are serialized as app-level metadata only: stable id, app name, bundle id, process id, last active date, and activation availability.

## Bridge Shape

Phase 1 defines Codable DTOs but does not implement the bridge host. The intended envelope shape is:

```json
{
  "version": 1,
  "id": "request-uuid",
  "type": "tool.call",
  "tool": "llm.chat",
  "payload": {}
}
```

Results use `tool.result` with either a typed payload or a display-safe `InputoNativeToolError`. Native-to-Web streaming uses `event` envelopes with names such as `llm.started`, `llm.delta`, `llm.completed`, `llm.failed`, and `llm.cancelled`.

## Phase 2 Bridge Dispatcher

Phase 2 proves the contract without building the final Web UI:

- implements a JSON bridge dispatcher around the typed envelopes
- routes allowlisted tools to `AppState` and native services
- adds an event emitter abstraction
- supports cancellation by request id
- keeps provider and tool errors display-safe
- coalesces streaming deltas before event emission
- includes JSON fixture examples under `Contracts/examples`

Only after this dispatcher works should Inputo add a minimal `WKWebView` host or React/Vite workspace.

## Phase 2A-D Landing

The dispatcher now lives in `InputoComposerFeature`:

- `Bridge/InputoNativeBridgeDispatcher.swift`
- accepts version 1 `tool.call` JSON envelopes
- returns version 1 `tool.result` JSON envelopes
- accepts version 1 `tool.cancel` JSON envelopes
- checks tool mode, explicit user action, and per-call confirmation policy
- implements `tools.list`, `composer.getState`, `settings.summary`, and `permissions.status`
- implements composer tools: `composer.setDraft`, `composer.selectRecipe`, and `composer.clear`
- implements LLM tools: `llm.chat`, `llm.stream`, and `llm.cancel`
- implements clipboard copy through `clipboard.copyGeneratedOutput`
- implements app-anchor list and activation through `appAnchors.list` and `appAnchors.activate`
- implements native settings open through `settings.open`
- implements `permissions.request` as a policy-checked status response; v1 does not request new screen-recording or accessibility permissions
- implements grant-based file tools through `InputoMacPlatform.FileGrantService`
- emits `llm.started`, `llm.delta`, `llm.completed`, `llm.failed`, and `llm.cancelled` events
- rejects unsupported bridge versions
- rejects unknown tools
- rejects policy violations with display-safe errors
- rejects `network.fetch` until manifest-governed network policy is implemented

The dispatcher still does not host Web UI. It does not expose arbitrary native APIs, raw filesystem paths, API keys, security-scoped bookmark data, shell access, MCP execution, or connector execution.

Fixtures live in:

- `Contracts/examples/bridge-readonly-tool-calls.v1.json`
- `Contracts/examples/bridge-side-effect-tool-calls.v1.json`

## Placeholder Implementation Expectations

Placeholder contracts should be implemented in dependency order, not by starting a frontend first:

1. Phase 2A: implement the JSON bridge dispatcher, `tools.list`, `composer.getState`, `settings.summary`, and `permissions.status`. Done.
2. Phase 2B: wire existing native `AppState` actions as tools: composer draft/recipe/clear, `llm.chat`, `llm.cancel`, `clipboard.copyGeneratedOutput`, `appAnchors.list`, `appAnchors.activate`, and `settings.open`. Done.
3. Phase 2C: add event emission, request-id cancellation, streaming delta coalescing, and `llm.stream`. Done. Current provider calls still return whole completions, so `llm.stream` emits lifecycle events and a coalesced result delta until the provider client gains token streaming.
4. Phase 2D: implement grant-based file picker/read/write tools after bridge policy and confirmation UI exist. Done at native executor level through `FileGrantService`; future Web UI still needs to render the confirmation surface before invoking these tools.
5. Later agent phases: implement manifest-governed `network.fetch`, connector tools, and MCP tools only after their review, credential, cancellation, and audit policies exist. Not enabled; `network.fetch` is explicitly policy-denied.
