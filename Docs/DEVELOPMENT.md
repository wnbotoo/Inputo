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
- The composer is a compact single-column native SwiftUI panel: target app anchors, preview, preset/instruction controls, input, and actions.
- Settings window sizing has been stabilized with explicit SwiftUI/AppKit hosting dimensions.
- Phase 1 native executor DTOs now exist in `InputoCore` for tool ids, tool descriptors, bridge envelopes, streaming events, cancellation, safe errors, grant-based file access payloads, permission snapshots, and native executor state snapshots.
- `InputoComposerFeature.AppState` can now produce a typed native executor snapshot and expose explicit generation cancellation without moving product behavior into the Xcode app target.

## Phase 0/1 Status

Phase 0 remains the native v0.1 baseline. The app still needs real-device/provider manual QA for the full transform, Copy, app-anchor, menu-bar, hotkey, multi-display, and full-screen Space loops before any web surface replaces native UI.

Phase 1 has started with the smallest stable contract surface:

- `InputoCore` owns Foundation-only executor contracts in `NativeExecutorContract.swift`.
- Native tools are allowlisted and carry policy metadata: side-effect class, minimum agent mode, explicit-action requirement, per-call confirmation, cancellation support, and streaming support.
- File tools are contract-only and grant-based: future reads/writes must go through native picker/save-panel grants rather than arbitrary Web-provided paths.
- A first read-only JSON bridge dispatcher exists in `InputoComposerFeature` for `tools.list`, `composer.getState`, `settings.summary`, and `permissions.status`.
- `AppState.nativeExecutorSnapshot(agentMode:)` separates capability state from SwiftUI presentation enough for a future bridge host to read state without importing SwiftUI.
- Tests cover contract encoding, conservative tool policy, provider-error mapping, snapshot privacy, bridge read-only dispatch, bridge error envelopes, and cancellation.
- React, Vite, WKWebView hosting, and Web agent planner work remain intentionally unstarted.

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

4. Build the bridge host before adding frontend tooling.
   - Keep the native shell and service boundaries intact.
   - Expand the JSON dispatcher over the typed executor DTOs.
   - Test allowlisting, safe errors, cancellation, and streaming event coalescing with fake services.
   - Implement grant-based file tools only after dispatcher policy and confirmation UI are in place.
   - Do not start React/Vite or a WKWebView surface until the dispatcher is proven.

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
- Explore a `WKWebView` renderer for composer/settings after v0.1 is reliable.
- Add bridge contract tests if a web UI is introduced.

## Deferred Until After MVP

- Windows WinUI 3 implementation.
- Hybrid web UI implementation.
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
swift test --package-path InputoModules
xcodebuild -project Inputo.xcodeproj -scheme Inputo -configuration Debug -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build
```

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
