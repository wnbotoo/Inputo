# Inputo Development Plan

This document tracks the next engineering slices for the macOS MVP and keeps future work aligned with the long-term native architecture.

## Current Product Shape

Inputo is a menu-bar resident, Spotlight-like AI input source for macOS. The user opens it with a custom shortcut or status-bar menu, writes or pastes text, asks for a transform, manually copies the generated result, then jumps back to a target app through app anchors.

The app intentionally avoids automatic paste, input history, generated history, screenshots, window titles, MCP execution, and external tools in v1.

## Current Implementation Status

- The app target is thin and hosts the menu bar app, floating composer panel, and settings window.
- `AppState` uses small service protocols with live and fake services, so feature flows can be tested without real OS services.
- Unit coverage exists for generate, copy, reset, anchor activation, provider validation, provider request shape, error redaction, and the neutral provider connection test.
- Provider configuration supports OpenAI-compatible chat completions endpoints, including base origins, `/v1`, and full `/v1/chat/completions` URLs.
- The app sandbox includes the network client entitlement required for provider requests.
- Settings has a neutral "Save & Test Connection" action that does not use translation as the smoke test.
- The composer is a compact single-column native shell with native header, native Jump anchors, and a bundled `WKWebView` body for preview, preset/instruction controls, input, and actions.
- Settings window sizing has been stabilized with explicit SwiftUI/AppKit hosting dimensions.
- Phase 1 native executor DTOs now exist in `InputoCore` for tool ids, tool descriptors, bridge envelopes, streaming events, cancellation, safe errors, grant-based file access payloads, permission snapshots, and native executor state snapshots.
- `InputoComposerFeature.AppState` can now produce a typed native executor snapshot and expose explicit generation cancellation without moving product behavior into the Xcode app target.

## Phase 0/1 Status

Phase 0 remains the native v0.1 baseline. The app still needs ongoing real-device/provider regression QA for the full transform, Copy, app-anchor, menu-bar, hotkey, multi-display, and full-screen Space loops.

Phase 1 has started with the smallest stable contract surface:

- `InputoCore` owns Foundation-only executor contracts in `NativeExecutorContract.swift`.
- Native tools are allowlisted and carry policy metadata: side-effect class, minimum agent mode, explicit-action requirement, per-call confirmation, cancellation support, and streaming support.
- File tools are contract-only and grant-based: future reads/writes must go through native picker/save-panel grants rather than arbitrary Web-provided paths.
- The JSON bridge dispatcher in `InputoComposerFeature` now executes the Phase 2A-D native executor tools: app snapshot/hide, composer draft/instruction/recipe/clear, LLM chat/stream/cancel, clipboard copy, app anchors, settings open, permission status/request, and grant-based file picker/read/write.
- `AIProviderClient.streamTransform` parses OpenAI-compatible SSE chunks, and `AppState.streamGenerate` updates native composer state incrementally for `llm.stream`.
- `InputoNativeBridgeMessageHandling` and `InputoNativeBridgeHost` define the host-facing protocol used by the WKWebView adapter.
- `network.fetch` remains explicitly policy-denied until manifest-governed network policy exists.
- `AppState.nativeExecutorSnapshot(agentMode:)` separates capability state from SwiftUI presentation enough for a future bridge host to read state without importing SwiftUI.
- Tests cover contract encoding, conservative tool policy, provider-error mapping, snapshot privacy, bridge dispatch, bridge error envelopes, user-action policy, request-id cancellation, event emission, streaming delta coalescing, and grant-based file tools.
- Phase 3 now has a minimal `WKWebView` composer body host in `InputoComposerFeature` that loads bundled static assets, uses a non-persistent data store, restricts navigation to the asset bundle, routes Web-to-native messages through `InputoNativeBridgeHost`, and forwards native events through `InputoBridgeEventEmitter`.
- `Docs/WEB_COMPOSER.md` records the current Web composer implementation, React/Vite source workspace, security boundary, packaging decision, and Phase 4 status.
- Phase 4 has an initial React + TypeScript + Vite `WebComposer` workspace that regenerates the bundled Web composer assets while keeping Xcode builds independent of Node. Web agent planner work remains intentionally unstarted.

## Development Principles

- Keep `Inputo` as a thin Xcode app target for lifecycle, menu-bar integration, and AppKit window hosting.
- Put product behavior in local SwiftPM modules under `InputoModules`.
- Keep `InputoCore` pure Foundation and Codable/Sendable-friendly so it can later be mirrored or replaced by a Rust/C++ core.
- Keep OS APIs behind platform services in `InputoMacPlatform`.
- Prefer small feature targets over growing the app target when new product areas appear.
- Do not introduce CocoaPods, Carthage, XcodeGen, or project generators.
- Preserve the v1 privacy posture: no input history, no generated history, no window-title capture, no screenshots.

## Immediate Priorities

1. Prove the native v0.1 loop.
   - Run a real provider transform such as translation or polish from the floating composer.
   - Confirm clipboard is unchanged before Copy and correct after Copy.
   - Confirm app-anchor activation returns to the selected target app and clears transient state.
   - Verify status-bar opening and hotkey opening across common apps, Spaces, and multiple displays.

2. Tighten composer ergonomics.
   - Keep the panel compact, single-column, and no taller than roughly one third of the visible screen where possible.
   - Improve keyboard navigation between anchors, preview, preset, instruction, input, generate, clear, and copy.
   - Decide whether Copy should keep the composer open, hide it, or offer both actions.
   - Continue visual QA for top/bottom margins and titlebar safe-area behavior.

3. Improve first-run and settings UX.
   - Guide the user to set provider, model, API key, and hotkey before first generation.
   - Keep provider validation and connection-test diagnostics clear without leaking secrets.
   - Add more explicit permission/status indicators for shortcut and app-anchor behavior.

4. Continue Phase 4 Web composer engineering.
   - Keep the React + TypeScript + Vite `WebComposer` source workspace aligned with the existing Web composer body.
   - Treat the repository as a gradual monorepo: keep current macOS paths stable, add a top-level Web composer workspace, and defer broader `apps/`/`packages/` reshuffling until Windows work has real shape.
   - Keep the production output as bundled local static assets loaded by the current `WKWebView` host.
   - Keep Xcode app builds independent of `npm install`, network access, or frontend dev servers.
   - Use `npm run verify` in `WebComposer` to typecheck, test, regenerate, and confirm bundled asset consistency when changing the Web source.
   - Keep Web-to-native calls behind `InputoNativeBridgeHost` / `InputoNativeBridgeMessageHandling`.
   - Keep native-to-Web events behind `InputoBridgeEventEmitter`.
   - Port the accepted Phase 3 focus, IME, Escape, keyboard shortcut, dark-mode, streaming, and visual behavior without expanding Web privileges.

5. Preserve the native boundary while frontend tooling lands.
   - Native keeps the shell, Settings, Jump anchors, panel behavior, app activation, Keychain, clipboard, provider networking, file grants, and permissions.
   - WebView remains non-persistent, bundled-only, and network-blocked.
   - Do not add browser storage for input/output history.
   - Do not enable `network.fetch`, connector tools, MCP tools, or a Web agent planner during Phase 4.
   - Keep panel sizing across displays and Spaces in regression QA.

## Backlog

- Add `InputoSettingsFeature` if settings grows beyond a small view.
- Add `InputoProviderFeature` if provider configuration becomes multi-provider.
- Add `InputoToolsFeature` only after v1 text workflows are stable.
- Add contract examples under `Contracts/examples`.
- Add JSON schema validation tests for shared contracts.
- Add macOS UI smoke tests for launch, show composer, open settings, and copy flow.
- Add manual QA checklist for multi-display and full-screen spaces.
- Add app icon and refined status-bar icon.
- Add optional "copy and hide" command after the basic copy flow is proven.
- Add optional "last target app" quick action once anchor tracking is stable.
- Keep Settings native unless a later phase explicitly scopes a Web settings surface.
- Add bridge contract tests if a web UI is introduced.

## Deferred Until After MVP

- Windows WinUI 3 implementation.
- Full hybrid web UI implementation beyond the minimal composer host.
- MCP connector execution.
- Tool execution.
- Automatic paste.
- Referenced-source retrieval.
- Image input and attachments.
- User input or generation history.
- Window thumbnails or title capture.
- Rust/C++ shared core.

## Verification Commands

Run these before handing off meaningful changes:

```bash
cd WebComposer && npm run verify && cd ..
swift test --package-path InputoModules
xcodebuild -project Inputo.xcodeproj -scheme Inputo -configuration Debug -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build
```

## Continuous Integration

GitHub Actions runs the same verification split by responsibility:

- `web-composer`: installs `WebComposer` dependencies with `npm ci` and runs `npm run verify`.
- `macos`: runs `swift test --package-path InputoModules` and the Xcode Debug build.

The CI split preserves the local build policy: Xcode and SwiftPM do not run Node during normal macOS builds, while pull requests still verify that checked-in bundled Web assets match the React/Vite source.

## Manual QA Checklist

- Launch Inputo from Xcode.
- Open from the status-bar menu while Xcode is frontmost.
- Open from the status-bar menu while Safari, Chrome, Notes, Messages, and Finder are frontmost.
- Open from the custom hotkey while another app is focused.
- Verify the composer appears near the bottom center of the active display.
- Verify text input receives focus after opening.
- Generate with missing API key and confirm a clear error.
- Generate with a valid OpenAI-compatible provider.
- Confirm clipboard is unchanged until Copy is clicked.
- Click Copy and confirm clipboard contains the generated text.
- Click an app anchor and confirm Inputo hides after successful activation.
- Try activation when a target app quits between refresh and click.
- Repeat on another display and in a full-screen Space.
