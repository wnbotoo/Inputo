# Inputo Development Plan

This document tracks the next engineering slices for the macOS MVP and keeps future work aligned with the long-term native architecture.

## Current Product Shape

Inputo is a menu-bar resident, Spotlight-like AI input source for macOS. The user opens it with a custom shortcut or status-bar menu, writes or pastes text, asks for a transform, manually copies the generated result, then jumps back to a target app through app anchors.

The app intentionally avoids automatic paste, input history, generated history, screenshots, window titles, MCP execution, and external tools in v1.

## Development Principles

- Keep `Inputo` as a thin Xcode app target for lifecycle, menu-bar integration, and AppKit window hosting.
- Put product behavior in local SwiftPM modules under `InputoModules`.
- Keep `InputoCore` pure Foundation and Codable/Sendable-friendly so it can later be mirrored or replaced by a Rust/C++ core.
- Keep OS APIs behind platform services in `InputoMacPlatform`.
- Prefer small feature targets over growing the app target when new product areas appear.
- Do not introduce CocoaPods, Carthage, XcodeGen, or project generators.
- Preserve the v1 privacy posture: no input history, no generated history, no window-title capture, no screenshots.

## Immediate Priorities

1. Stabilize the app shell.
   - Verify status-bar opening when Xcode, Safari, Notes, Chrome, Finder, and full-screen apps are frontmost.
   - Verify custom hotkey show/hide behavior across Spaces and multiple displays.
   - Add Escape-to-hide behavior for the floating composer.
   - Decide whether Copy should keep the composer open, hide it, or offer both actions.
   - Make anchor activation failures visible but calm.

2. Make state and services testable.
   - Introduce small service protocols consumed by `AppState`.
   - Inject default live services from the app composition root.
   - Add fakes for provider, clipboard, settings, keychain, and anchors.
   - Add tests for generate/copy/reset/anchor flows without touching real OS services.

3. Tighten provider behavior.
   - Validate `baseURL`, `model`, timeout, and headers before generation.
   - Redact API keys and sensitive headers from all errors and logs.
   - Add request-shape tests for OpenAI-compatible `/v1/chat/completions`.
   - Add cancellation support for in-flight generation.
   - Consider streaming only after non-streaming behavior is reliable.

4. Improve first-run and settings UX.
   - Guide the user to set provider, model, API key, and hotkey before first generation.
   - Show provider validation errors inline.
   - Add custom preset CRUD with stable IDs.
   - Add permission/status indicators for shortcuts and app-anchor behavior.

5. Polish the composer.
   - Make the bottom-center panel feel closer to Spotlight while keeping the two-panel workflow.
   - Improve keyboard navigation between recipe, instruction, input, generate, copy, and anchors.
   - Add empty, loading, success, error, and activation-failed states.
   - Keep controls dense, calm, and task-focused.

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

## Deferred Until After MVP

- Windows WinUI 3 implementation.
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
