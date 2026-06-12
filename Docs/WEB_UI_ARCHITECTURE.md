# Inputo Hybrid Web Agent Architecture

This document defines the planned hybrid architecture for Inputo after the native macOS v0.1 loop is reliable.

The selected direction is **Plan B: web planner plus native executor**.

Inputo may grow into a small local agent, but it should not become a web app with unrestricted native powers. The web side can run the product-level agent that plans work, chooses tools, manages workflows, renders activity, and evolves quickly. The native side remains the trusted executor that owns secrets, provider access, system permissions, side effects, and platform services.

## Architecture Summary

Inputo should use this trust split:

- Web agent decides what it wants to do next.
- Native executor decides whether that action is allowed and how to perform it safely.
- Bridge contracts are explicit, versioned, typed, and allowlisted.
- Native capabilities are exposed as tools, not as generic OS APIs.
- Secrets and system permissions are never handed to JavaScript.

In short:

```text
Web Agent
  plans tasks, chooses tools, renders state, owns product iteration

Typed Bridge
  carries tool calls, events, state snapshots, streaming deltas, and errors

Native Executor
  owns LLM calls, secrets, clipboard, app anchors, permissions, network policy, and tool runtime
```

This preserves Inputo's privacy posture while still giving the open-source community a large web-friendly contribution surface.

## Product Roles

### Native Shell

The native shell remains a macOS app, not a browser wrapper.

Native shell responsibilities:

- app lifecycle
- menu bar item
- global hotkey
- floating panel window
- settings window hosting
- panel positioning across displays and Spaces
- focus, Escape handling, IME behavior, and keyboard routing
- native window material, blur, shadow, and transparency
- app-anchor row and anchor refresh
- app activation
- Keychain and future credential-store access
- clipboard writes
- macOS sandbox entitlements and OS permissions

The Xcode `Inputo` app target should remain thin. Product behavior still belongs in `InputoModules`.

### Native Executor

The native executor is the trusted capability broker. It exposes selected capabilities to the web agent as tools, but it does not expose raw secrets or generic native APIs.

Native executor responsibilities:

- provider configuration validation
- reading provider secrets from Keychain
- LLM calls and streaming
- prompt assembly that belongs to core contracts
- tool registry and capability policy
- network request policy and execution
- app activation
- clipboard writes
- permission prompts and permission-state reporting
- cancellation and timeouts
- rate limiting where needed
- sensitive error redaction
- no-history, no-autopaste, no-screenshot, and no-window-title invariants
- future MCP or connector hosting

The executor should live in Swift package targets, not in the thin app target. Over time, pure contracts and provider/tool DTOs should remain cross-platform-friendly so Windows can implement the same executor contract.

### Web Agent

The web side is a real agent at the planning and workflow layer. It can decide how to solve a task, which tools to request, how to present progress, and how to compose product features.

Web agent responsibilities:

- composer body UI
- local editing experience
- workflow planning
- tool selection proposals
- agent activity timeline
- result rendering
- tool cards and approval UI
- recipe and skill UX
- pure JS or WASM helper tools without native privileges
- bridge client implementation
- streaming output rendering
- future richer surfaces such as diffs, citations, structured outputs, and tool result previews

The web agent may be highly extensible, but privileged work must go through native-hosted tools.

## First Surface Boundary

The first hybrid UI slice should be:

```text
Native:
  Inputo header, settings entry, Jump app-anchor row, refresh anchors,
  panel/window/focus/material behavior

Web:
  preview, recipe picker, instruction input, main editor,
  Generate, Cancel, Clear, Copy presentation, status/error rendering,
  streaming output display, future tool activity surface
```

Even when Web renders a button, the side effect belongs to native.

Examples:

- Web renders Copy, but native writes the clipboard.
- Web renders Generate, but native calls the provider.
- Web renders a network-search tool card, but native applies network policy and executes the request.
- Web renders a permission request prompt, but native owns the actual permission flow.

Settings should stay native at first. Provider settings, API key editing, hotkey recording, and privacy/permission status are native-sensitive and do not need to move before the bridge is proven.

## Tool Model

Every privileged capability exposed to Web should be modeled as a tool.

The web agent calls tools. The native executor hosts tools.

Examples of native-hosted tools:

- `llm.chat`
- `llm.stream`
- `network.fetch`
- `clipboard.copy`
- `appAnchors.list`
- `appAnchors.activate`
- `settings.open`
- `permissions.status`
- `permissions.request`
- `files.pickReadable`
- `files.readText`
- `files.pickWritable`
- `files.writeText`
- future `connector.call`
- future `mcp.callTool`

The bridge should never expose broad APIs such as:

- `native.fetch`
- `native.runShell`
- `native.readKeychain`
- `native.writeClipboard`
- `native.activateApp`
- `native.requestPermission`
- `native.readFile`
- `native.writeFile`

Instead, each capability is a named tool with a schema, policy, lifecycle, and review surface.

## Tool Classes

Inputo should support several tool classes with different review costs.

### Web-Sandbox Tools

These can run in the web runtime because they have no native privileges.

Examples:

- diff rendering
- markdown rendering
- JSON formatting
- schema validation
- token counting approximations
- local text transforms
- preview-only parsing

These are the easiest contribution path for web contributors.

### Manifest-Defined Network Tools

These are contributed mostly through web-friendly files, but executed by native.

The contribution can include:

- tool manifest
- input schema
- output schema
- result renderer
- approval UI copy
- examples and tests

Native provides a generic network executor that enforces the manifest.

The manifest should declare:

- stable id
- version
- display name
- description
- input schema
- output schema
- allowed origins
- allowed methods
- credential policy
- whether user data may be sent
- whether per-call confirmation is required
- whether automatic execution is allowed
- rate limit hints
- platform availability

### Native Platform Tools

These require Swift on macOS and a future Windows implementation.

Examples:

- clipboard writes
- app activation
- app-anchor enumeration
- hotkey management
- permission prompts
- local file access if ever added
- window or screen related capabilities if ever added

These should be reviewed more strictly because they define Inputo's system-level behavior.

### Connector And MCP Tools

Connector and MCP execution is deferred until after v1. When introduced, it should be hosted by native executor policy, not directly by Web.

Web can provide:

- tool discovery UI
- connector configuration UI
- approval and activity UI
- result renderers

Native owns:

- process or network lifecycle
- credentials
- permission checks
- cancellation
- transport security
- error redaction

## LLM As A Tool

LLM access should also be a native-hosted tool.

Web should not receive long-lived provider API keys and should not call OpenAI-compatible providers directly.

The web agent can call:

- `llm.chat`
- `llm.stream`

Native executor handles:

- reading API keys from Keychain
- validating provider settings
- assembling provider requests
- applying timeout and cancellation
- streaming deltas
- redacting provider errors
- ensuring no automatic history persistence

This lets the web agent orchestrate real agent workflows without owning provider secrets.

## Network Access

The web agent may need network access in higher agent modes, but direct browser `fetch` should not become the default capability path.

Preferred model:

- Web requests `network.fetch`.
- Native checks tool policy.
- Native prompts the user when required.
- Native performs the request.
- Native returns a structured result to Web.

Reasons:

- central audit and policy
- consistent behavior between WKWebView and future WebView2
- controlled credential handling
- clearer user consent
- easier review of open-source tools

Local bundled web assets should still have a restrictive Content Security Policy. Remote JavaScript should not be loaded.

## Agent Modes

Inputo can expose capability levels over time.

### Mode 1: Manual Transform

- User explicitly clicks Generate.
- Native calls LLM once.
- Streaming output is allowed.
- No tools execute.
- No network access beyond the provider call.

This is the v1-compatible baseline.

### Mode 2: Assisted Workflow

- Web agent can suggest tool calls.
- Side-effecting tools require user confirmation.
- Network tools are manifest-bound and visible.
- File tools require native picker or save-panel grants.
- Native executor still owns all execution.

This is the likely first agent expansion.

### Mode 3: Live Agent

- Web agent can continuously plan and request tools.
- Live input sending may be enabled by explicit user opt-in.
- UI must clearly disclose when text is being sent.
- Native applies rate limits, cancellation, policy checks, and confirmation rules.
- Automatic tool execution is allowed only for tools explicitly marked safe for the current mode.

Mode 3 changes the privacy expectations and should not be enabled by default.

## Bridge Contract

The bridge should be versioned from the start.

Suggested envelope for Web-to-native messages:

```json
{
  "version": 1,
  "id": "request-uuid",
  "type": "tool.call",
  "tool": "llm.stream",
  "payload": {}
}
```

Suggested success response:

```json
{
  "version": 1,
  "id": "request-uuid",
  "type": "tool.result",
  "ok": true,
  "payload": {}
}
```

Suggested error response:

```json
{
  "version": 1,
  "id": "request-uuid",
  "type": "tool.result",
  "ok": false,
  "error": {
    "code": "permission_denied",
    "message": "This tool is not allowed in the current mode.",
    "field": null,
    "retryable": false
  }
}
```

Suggested native-to-web event:

```json
{
  "version": 1,
  "type": "event",
  "event": "llm.delta",
  "requestID": "request-uuid",
  "payload": {
    "text": "partial output"
  }
}
```

### Required Message Families

Composer state:

- `app.snapshot`
- `app.hideComposer`
- `composer.getState`
- `composer.setDraft`
- `composer.setInstruction`
- `composer.selectRecipe`
- `composer.clear`

LLM:

- `llm.chat`
- `llm.stream`
- `llm.cancel`

Clipboard:

- `clipboard.copyGeneratedOutput`

App anchors:

- `appAnchors.list`
- `appAnchors.activate`

Settings:

- `settings.open`
- `settings.summary`

Permissions:

- `permissions.status`
- `permissions.request`

Files:

- `files.pickReadable`
- `files.readText`
- `files.pickWritable`
- `files.writeText`

Network:

- `network.fetch`

Agent and tools:

- `tools.list`
- `tool.call`
- `tool.cancel`
- `tool.approve`
- `tool.reject`

### Bridge Rules

- Every command must be allowlisted.
- Every command must have Codable DTOs on the native side.
- Every command should have fixture examples.
- Every side-effecting command must be policy checked.
- Every request that can outlive a single event loop turn must support cancellation.
- Errors must be safe to display.
- Provider and tool errors must not leak secrets.
- API keys must never appear in bridge state snapshots.
- Web storage must not persist user input or generated output history by default.

## Streaming Contract

Streaming output is a first-class requirement.

Native executor should:

- start the provider or tool stream
- assign a request id
- coalesce small deltas before crossing the bridge
- send progress events
- send final completion or failure
- update authoritative state
- support cancellation

Suggested events:

- `llm.started`
- `llm.delta`
- `llm.completed`
- `llm.failed`
- `llm.cancelled`
- `tool.started`
- `tool.progress`
- `tool.resultDelta`
- `tool.completed`
- `tool.failed`
- `tool.cancelled`

Native should avoid sending one bridge event per token if the provider emits tiny deltas. A small buffer flushed every 30-80 ms is usually enough for responsive UI without bridge churn.

## State Ownership

Native owns authoritative capability state:

- provider config summary
- API key presence, not API key value
- current recipes
- current output
- current tool activity lifecycle
- current app anchors
- current permission status
- current agent mode
- current generation id

Web owns local presentation state:

- focus
- editor layout
- expanded/collapsed panels
- visible activity timeline rendering
- local draft before syncing
- optimistic button states, when safe

For important actions, native state wins. If Web and native disagree, Web should re-render from the latest native state snapshot.

## Security And Privacy Requirements

If a web surface is introduced:

- Load only bundled local assets.
- Do not load remote JavaScript.
- Use a restrictive Content Security Policy.
- Prefer non-persistent `WKWebsiteDataStore`.
- Disable or intercept arbitrary navigation.
- Do not expose API keys to JavaScript.
- Do not allow generic native APIs across the bridge.
- Do not allow default direct browser network access for agent tools.
- Do not expose arbitrary filesystem paths or broad file read/write APIs to Web.
- Do not persist user input or generated output in web storage by default.
- Keep v1 defaults: no automatic paste, no saved input history, no saved generation history, no screenshots, no window-title capture, and no default tool execution.
- Make higher agent modes explicit and user-visible.

## Packaging Direction

The first implementation should not make the Xcode build depend on Node.

Preferred initial packaging:

- bundle static web assets with the app
- keep the web surface small enough to start without a framework if practical
- commit any static assets needed by Xcode
- avoid network downloads during Xcode build

Later packaging, if a framework is introduced:

- keep source under a dedicated web workspace
- generate static assets for the app bundle
- let CI verify generated assets match source
- keep Xcode able to build from checked-in assets

## Frontend Stack Decision

The recommended web stack is **React + TypeScript + Vite**.

This should be a small embedded single-page app, not a Next.js, Remix, SSR, or server-components application. Inputo's web surface runs inside `WKWebView` on macOS and future WebView2 on Windows. It should load bundled static assets and communicate with native through the bridge.

Recommended stack:

- React for component UI
- TypeScript for bridge DTOs, tool manifests, and agent state
- Vite for local development and static production builds
- CSS variables for theme tokens shared with native
- CSS Modules or plain scoped CSS for component styling
- a first-class bridge client module
- a framework-agnostic tool manifest and renderer registry

Avoid by default:

- Next.js, Remix, SSR, or server components
- remote JavaScript
- browser-side provider fetch
- storing user input or generated output in browser storage
- large state libraries before the bridge and agent model need them
- routing libraries before the surface has real multi-page navigation

Reasons for choosing React:

- It has the broadest contributor pool among the candidate frameworks.
- It has a mature TypeScript ecosystem for typed UI and agent state.
- It fits a componentized tool-card, result-renderer, activity-timeline, and composer architecture.
- It is familiar to many open-source contributors who may not know Swift.
- It works well as a static bundled app inside `WKWebView` and future WebView2.
- It keeps Windows reuse straightforward because the UI is not coupled to macOS UI primitives.

Vue and Svelte are both viable alternatives, but they are not the recommended default.

Vue has excellent Single-File Components and a friendly template model, but React has a larger open-source contributor base for agent UI, renderer ecosystems, and TypeScript-heavy tool surfaces.

Svelte has an attractive compiler model and can produce lean embedded UI, but its contributor pool and ecosystem are smaller for the kind of extensible agent platform Inputo may become.

The architecture should still avoid hard-binding core contracts to React. Bridge DTOs, tool manifests, native executor APIs, and pure tool schemas should remain framework-agnostic. React is the product surface runtime, not the system contract.

Initial state management should stay simple:

- bridge client owns request/response plumbing
- React state or `useReducer` owns local composer state
- native snapshots remain authoritative for capability state
- a small store can be introduced when the agent activity model becomes complex

The first React implementation should prioritize a stable bridge boundary and native executor integration over a large frontend framework stack.

## Windows Reuse

The reusable cross-platform layer should be:

- web agent UI
- bridge DTOs
- tool manifests
- web-side renderers
- pure JS/WASM tools
- language-neutral contracts

The platform-specific layer should be:

- macOS shell with WKWebView
- Windows shell with WebView2
- Keychain vs Windows Credential Manager
- AppKit app activation vs Win32 activation
- macOS permissions vs Windows permissions
- native executor implementations

Future Rust or C++ shared core can move pure provider, prompt, and tool contract logic below both native hosts. It should not move platform permissions or secrets into Web.

## Development Plan

The priority is to build fixed native capability foundations first, then bridge contracts, then web surfaces. This lets web development move quickly later without repeatedly redefining security boundaries.

### Phase 0: Finish Native v0.1

Goal: keep the current SwiftUI app reliable before introducing a web runtime.

Tasks:

- verify the current text transform loop
- verify manual Copy behavior
- verify app-anchor activation
- verify hotkey and menu-bar entry
- keep settings native and stable
- preserve existing unit coverage

Exit criteria:

- native app passes package tests and Xcode build
- provider transform works locally
- privacy defaults remain intact

### Phase 1: Define Native Capability Interfaces

Goal: identify the stable executor capabilities before Web depends on them.

Tasks:

- define native tool ids and DTOs
- define error codes
- define cancellation model
- define permission policy model
- define streaming lifecycle model
- separate capability state from SwiftUI presentation state where needed
- add tests around executor behavior using fake services

Likely package location:

- `InputoCore` for cross-platform DTOs and contracts
- `InputoComposerFeature` or a future feature target for orchestration
- `InputoMacPlatform` for macOS adapters

Initial landing:

- `InputoCore/Models/NativeExecutorContract.swift` defines the first versioned DTOs for tool ids, bridge messages, errors, cancellation, streaming events, permissions, and native executor snapshots.
- File read/write is represented as grant-based contract-only tools that require assisted workflow mode, explicit user action, and per-call confirmation.
- `InputoComposerFeature.AppState` exposes `nativeExecutorSnapshot(agentMode:)` and `cancelActiveGeneration()` as the current adapter over the native v0.1 state.
- This is not yet the bridge host. JSON dispatch, event emission, streaming coalescing, and request-id cancellation belong to Phase 2.
- Native executor DTOs remain framework-agnostic; React/Vite source tooling starts only after the bridge dispatcher and minimal WKWebView host are proven.

### Phase 2: Build Bridge Host Without Web UI

Goal: prove the bridge contract against native state before building the final web product surface.

Tasks:

- implement Codable bridge envelopes
- implement command dispatcher
- implement event emitter abstraction
- test command handling with fake services
- test error redaction
- test streaming delta coalescing
- test cancellation

This phase can be tested without `WKWebView` by sending JSON fixtures into the dispatcher.

Initial landing:

- `InputoComposerFeature/Bridge/InputoNativeBridgeDispatcher.swift` accepts versioned `tool.call` JSON envelopes and returns `tool.result` envelopes.
- The dispatcher now executes Phase 2A-D native executor tools: app snapshot/hide, composer draft/instruction/recipe/clear, LLM chat/stream/cancel, clipboard copy, app anchors, settings open, permission status/request, and grant-based file picker/read/write.
- Side-effecting tools require policy context such as explicit user action and, where needed, per-call confirmation.
- `llm.stream` uses OpenAI-compatible server-sent event streaming through `AIProviderClient.streamTransform`.
- `InputoNativeBridgeMessageHandling` and `InputoNativeBridgeHost` are the host-facing boundary used by the WKWebView adapter.
- Unsupported versions, unknown tools, deferred network fetch, and policy violations return display-safe error envelopes.
- Request fixtures live in `Contracts/examples/bridge-readonly-tool-calls.v1.json` and `Contracts/examples/bridge-side-effect-tool-calls.v1.json`.
- Event emission, request-id cancellation, and streaming delta coalescing are covered by package tests.
- `network.fetch`, connector tools, and MCP tools remain disabled until their manifest, review, credential, cancellation, and audit policies exist.

### Phase 3: Add Minimal WKWebView Host

Goal: embed a local web composer body while keeping native ownership of the shell, settings, Jump anchors, and panel behavior.

Tasks:

- add a small `WKWebView` composer body
- load only bundled local assets
- configure restrictive navigation and data-store behavior
- connect Web messages to `InputoNativeBridgeHost`
- deliver `InputoBridgeEventEmitter` events back into Web
- verify focus, IME, Escape, keyboard shortcuts, dark mode, and panel sizing
- keep Jump anchors native

The first web UI should be intentionally small and use the existing native executor. It should not introduce agent tools yet.

Initial landing:

- `InputoComposerFeature` now contains the minimal `WKWebView` host and checked-in static composer assets.
- `Docs/WEB_COMPOSER.md` documents the current implementation details, Phase 3 manual QA coverage, and Phase 4 direction.
- The app target remains thin; `ComposerView` hosts the Web composer body directly below the native header and Jump anchors.
- Static assets are copied by SwiftPM resources; there is no React, Vite, Node, or remote asset dependency.
- The web asset CSP blocks direct browser network access with `connect-src 'none'`.
- The host uses a non-persistent `WKWebsiteDataStore`, restricts navigation to the bundled asset directory, and installs a content rule list that blocks `http`/`https` resource loads.
- Web-to-native messages go through `InputoNativeBridgeHost`.
- Native-to-Web streaming events go through `InputoBridgeEventEmitter`.
- Native forwards the current light/dark color scheme into Web.
- Settings, Jump anchors, panel positioning, Escape handling, and app activation remain native.
- Manual QA has covered the critical Phase 3 runtime path: initial focus, draft retention, Chinese IME composition, IME-aware Escape handling, Command-Return generation, basic editing shortcuts, dark/light theme propagation, provider-backed generation preview, privacy posture, and native material fit. Panel sizing across displays and Spaces should remain part of normal regression QA.

### Phase 4: Add React TypeScript Vite Web Workspace

Goal: replace the hand-authored Phase 3 static assets with a maintainable React + TypeScript + Vite composer workspace while preserving the same native shell, bridge boundary, bundled-asset loading model, and v1 privacy defaults.

Tasks:

- create a small frontend source workspace for the existing composer body
- keep the production output as bundled local static assets loaded by the existing `WKWebView` host
- keep Xcode app builds independent of network access and frontend dependency installation
- add a typed Web bridge client that only calls `InputoNativeBridgeHost` tools
- mirror bridge DTOs and composer state types in TypeScript without making React part of the native executor contract
- preserve native Settings, Jump anchors, panel sizing/placement, app activation, Keychain, clipboard, provider networking, file grants, and permissions
- preserve WebView restrictions: non-persistent data store, bundled-file navigation, CSP, remote content blocking, no browser-side provider fetch, and no browser storage for input/output history
- port the current preview, recipe picker, instruction, editor, actions, status, streaming output, focus, IME, Escape, shortcut, and theme behavior into React
- add frontend unit tests where practical for bridge client behavior, reducer/state transitions, keyboard handling, and theme handling
- keep the generated static output reviewable and CI-checkable against the React source
- document frontend contribution patterns

Exit criteria:

- the app continues to load bundled local static assets through the existing `WKWebView` host
- `swift test --package-path InputoModules` and the Xcode Debug build pass without running `npm install` or downloading dependencies
- the React/Vite production build can regenerate the bundled assets deterministically
- the Web composer behavior matches the accepted Phase 3 composer body
- native shell ownership remains intact
- privacy defaults are unchanged

### Phase 5: Introduce Web Agent Planner

Goal: let Web orchestrate workflows while native executes tools.

Tasks:

- add agent activity model
- add tool registry listing
- add tool call proposal UI
- add approval UI
- support `llm.stream` as a native-hosted tool
- support safe web-sandbox tools
- support manifest-defined network tools only after policy is ready

This is the point where Web becomes more than UI. It can plan and coordinate, but it still cannot bypass native executor policy.

### Phase 6: Expand Tool Ecosystem

Goal: create a contribution-friendly tool system.

Tasks:

- define tool package layout
- define manifest schema
- define renderer API
- add examples
- add review guidelines
- add CI validation for tool manifests
- add native adapters for approved capability classes

Privileged tools should remain harder to add than pure Web tools. That is intentional.

## Open Questions

- Should the first web composer be hidden behind a compile-time flag, debug setting, or user setting?
- Should bridge DTOs live in the existing `Contracts` schema or a new `Contracts/inputo.bridge.v1.schema.json`?
- How much prompt assembly belongs in the web planner versus native/core?
- What exact UI should disclose Mode 3 live sending?
- What is the smallest useful manifest-defined network tool?
- Should settings ever move to Web, or stay native permanently?
