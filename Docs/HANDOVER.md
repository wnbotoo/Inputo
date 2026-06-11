# Inputo Handover

This handover summarizes the current state for a future conversation or engineer.

## Goal

Inputo is a macOS-native MVP for a system-wide AI input source. It sits between the user's existing input method and target applications. The user opens a Spotlight-like floating composer, transforms text through an OpenAI-compatible provider, manually copies the result, and returns to another app through app anchors.

## Current Decisions

- macOS first; Windows WinUI 3 comes later.
- Xcode owns a thin `Inputo` app target.
- Swift Package Manager owns product modules in `InputoModules`.
- No CocoaPods, Carthage, XcodeGen, or generator-managed project files.
- v1 is text-only and does not execute MCP/tools.
- v1 copies only on explicit user action and does not auto-paste.
- v1 does not store user input history or generated history.
- v1 does not read window titles, capture screenshots, or request screen recording for app anchors.
- API keys use Keychain on macOS.
- Cross-platform contracts live in `Contracts/inputo.v1.schema.json`.
- The product should first prove a native v0.1 loop before any web UI implementation.
- Hybrid web UI can be discussed next, but the intended direction is native shell plus optional web-rendered product surfaces, not a full rewrite.

## Project Layout

- `Inputo.xcodeproj`: app target, signing/build settings, local package product links.
- `Inputo/App`: app lifecycle, menu bar, floating panel, settings window hosting.
- `InputoModules/Package.swift`: local SwiftPM package.
- `InputoModules/Sources/InputoCore`: Foundation-only core DTOs, recipes, provider client.
- `InputoModules/Sources/InputoMacPlatform`: Keychain, clipboard, hotkey, settings, app anchors.
- `InputoModules/Sources/InputoComposerFeature`: composer UI, settings UI, feature state.
- `Contracts`: language-neutral shared schema.
- `Docs/ARCHITECTURE.md`: architecture and boundaries.
- `Docs/DEVELOPMENT.md`: roadmap, todo list, verification, manual QA.
- `Docs/HANDOVER_WEB_UI_DISCUSSION.md`: prompt for a new conversation about the hybrid web UI direction.

## Recent Work

- Refactored `AppState` behind small service protocols and added fake services for tests.
- Added unit tests for generate, copy, reset, anchor activation, provider validation, provider request shape, error redaction, cancellation, and neutral provider connection testing.
- Hardened provider setup:
  - validates base URL, model, timeout, and headers;
  - accepts base origins, `/v1`, and full `/v1/chat/completions` URLs;
  - redacts sensitive provider errors;
  - maps common network errors to more useful messages.
- Added macOS app sandbox network client entitlement so provider calls can work from the app.
- Replaced translation-based connection testing with a neutral "ping/ok" provider test.
- Stabilized settings window sizing by using explicit `NSHostingController` sizing.
- Tightened the composer UI into a compact single-column panel:
  - top app header and horizontal app anchors;
  - preview above input;
  - preset and instruction controls between preview and input;
  - explicit Copy button only for clipboard writes.

## Known State

- `swift test --package-path InputoModules` passes.
- `xcodebuild -project Inputo.xcodeproj -scheme Inputo -configuration Debug -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build` passes.
- A configured OpenAI-compatible provider can complete at least one real text transform in local use.
- Settings includes provider config, API key editing, neutral connection test, hotkey recording, custom presets, and privacy status.
- Composer UI is still native SwiftUI.
- There is no committed Windows project and no web UI implementation yet.
- Localization has not started; most UI strings are English.

## Important Constraints

- Keep the app target thin. Avoid adding product logic under `Inputo/App`.
- Keep `InputoCore` free of AppKit, SwiftUI, Security, Carbon, and CoreGraphics.
- Do not log API keys or serialize them into settings/contracts.
- Do not add automatic paste unless the product direction explicitly changes.
- Do not request screen recording permission for v1 app anchors.
- Do not read or display window titles for v1 app anchors.
- Treat generated `.build`, `.swiftpm`, DerivedData, and `xcuserdata` as untracked local state.
- Any future web UI should communicate with Swift through narrow, typed bridge commands instead of arbitrary native access.

## Suggested Next Slice

Discuss and document the hybrid web UI direction before implementing it:

1. Decide whether web UI is for composer only or composer plus settings.
2. Decide whether to use `WKWebView` with static bundled assets or a frontend workspace with a build step.
3. Define the Swift-to-web bridge commands and data models.
4. Decide how the bridge preserves v1 privacy constraints.
5. Evaluate keyboard focus, IME behavior, accessibility, startup latency, and open-source contributor ergonomics.

Keep implementation paused until the architecture and tradeoffs are clear.

## Handoff Prompt

Use this prompt when starting a general development conversation:

```text
We are continuing development of Inputo in /Users/wnbot/Projects/Inputo.

Inputo is a macOS-native, Spotlight-like AI input source. It opens from a custom hotkey or menu-bar item, lets the user transform text with an OpenAI-compatible provider, copies only when the user clicks Copy, and then lets the user jump back to target apps through app anchors. v1 does not auto-paste, does not save input/generated history, does not execute MCP/tools, does not use screenshots/window titles, and should stay privacy-conservative.

Current state:
- The Xcode app target is thin and hosts lifecycle/menu/window code.
- Product code lives in `InputoModules`.
- `AppState` already uses small service protocols with live and fake services.
- Provider validation, request-shape tests, error redaction, cancellation, neutral connection testing, and macOS network entitlement are in place.
- The native composer is compact and single-column: anchors, preview, preset/instruction, input, actions.
- Settings window sizing has been stabilized.
- The next discussion is about whether and how to add a hybrid web UI later, while keeping native shell and platform services.

Architecture rules:
- Use the existing Xcode app + local SwiftPM package structure.
- The Xcode `Inputo` target must stay thin and only own lifecycle/menu/window hosting.
- Product code lives in `InputoModules`.
- `InputoCore` must stay Foundation-only and cross-platform-friendly.
- `InputoMacPlatform` owns macOS services.
- `InputoComposerFeature` owns composer/settings UI and feature orchestration for now.
- No CocoaPods, Carthage, XcodeGen, or project generators.
- Follow current Apple SwiftUI/AppKit conventions.

Please read README.md, Docs/ARCHITECTURE.md, Docs/DEVELOPMENT.md, Docs/HANDOVER.md, and Docs/HANDOVER_WEB_UI_DISCUSSION.md first. Then inspect relevant code before making changes.

For implementation changes, verify with:
`swift test --package-path InputoModules`
`xcodebuild -project Inputo.xcodeproj -scheme Inputo -configuration Debug -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build`
```
