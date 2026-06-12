# Inputo Handover

This handover summarizes the current state for a future conversation or engineer.

## Goal

Inputo is a macOS-native MVP for a system-wide AI input source. It sits between the user's existing input method and target applications. The user opens a Spotlight-like floating composer, transforms text through an OpenAI-compatible provider, manually copies the result, and returns to another app through app anchors.

## Current Decisions

- macOS first; Windows WinUI 3 comes later.
- Xcode owns a thin `Inputo` app target.
- Swift Package Manager owns macOS product modules in `apps/macos/InputoModules`.
- No CocoaPods, Carthage, XcodeGen, or generator-managed project files.
- v1 is text-only and does not execute MCP/tools.
- v1 copies only on explicit user action and does not auto-paste.
- v1 does not store user input history or generated history.
- v1 does not read window titles, capture screenshots, or request screen recording for app anchors.
- API keys use Keychain on macOS.
- Cross-platform contracts live in `contracts/inputo.v1.schema.json`.
- The product proved the initial native v0.1 loop before introducing Web.
- The current hybrid direction is native shell plus a bundled Web composer body, not a full rewrite.

## Project Layout

- `apps/macos/Inputo.xcodeproj`: app target, signing/build settings, local package product links.
- `apps/macos/Inputo/App`: app lifecycle, menu bar, floating panel, settings window hosting.
- `apps/macos/InputoModules/Package.swift`: local SwiftPM package.
- `apps/macos/InputoModules/Sources/InputoCore`: Foundation-only core DTOs, recipes, provider client.
- `apps/macos/InputoModules/Sources/InputoMacPlatform`: Keychain, clipboard, hotkey, settings, app anchors.
- `apps/macos/InputoModules/Sources/InputoComposerFeature`: Web composer host/assets, settings UI, feature state.
- `contracts`: language-neutral shared schema.
- `docs/ARCHITECTURE.md`: architecture and boundaries.
- `docs/DEVELOPMENT.md`: roadmap, todo list, verification, manual QA.
- `docs/WEB_COMPOSER.md`: current WKWebView composer body implementation, security boundary, packaging, and Phase 3 status.
- `docs/HANDOVER_WEB_UI_DISCUSSION.md`: prompt for a new conversation about future Web UI direction.

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
- Landed a minimal bundled `WKWebView` composer body:
  - native keeps the top app header, horizontal app anchors, Settings, panel behavior, and platform services;
  - Web renders preview, preset/instruction controls, draft input, and composer actions;
  - Web-to-native messages go through `InputoNativeBridgeHost`;
  - native-to-Web events go through `InputoBridgeEventEmitter`;
  - Web uses a non-persistent data store and bundled local static assets only.

## Known State

- `swift test --package-path apps/macos/InputoModules` passes.
- `xcodebuild -project apps/macos/Inputo.xcodeproj -scheme Inputo -configuration Debug -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build` passes.
- A configured OpenAI-compatible provider can complete at least one real text transform in local use.
- Settings includes provider config, API key editing, neutral connection test, hotkey recording, custom presets, and privacy status.
- Composer body is now Web-rendered inside the native shell.
- React, TypeScript, and Vite are implemented for the Web composer source workspace. Windows and the Web agent planner are not implemented yet.
- Localization has not started; most UI strings are English.

## Important Constraints

- Keep the app target thin. Avoid adding product logic under `apps/macos/Inputo/App`.
- Keep `InputoCore` free of AppKit, SwiftUI, Security, Carbon, and CoreGraphics.
- Do not log API keys or serialize them into settings/contracts.
- Do not add automatic paste unless the product direction explicitly changes.
- Do not request screen recording permission for v1 app anchors.
- Do not read or display window titles for v1 app anchors.
- Treat generated `.build`, `.swiftpm`, DerivedData, and `xcuserdata` as untracked local state.
- Web UI must communicate with Swift through narrow, typed bridge commands instead of arbitrary native access.

## Suggested Next Slice

Continue Phase 4: harden the React + TypeScript + Vite Web composer workspace and runtime QA.

1. Keep the existing `WKWebView` host and native shell.
2. Keep bundled local static assets checked in for production and keep Xcode builds independent of frontend dependency installation.
3. Preserve the current bridge boundary: Web-to-native through `InputoNativeBridgeHost` / `InputoNativeBridgeMessageHandling`, native-to-Web through `InputoBridgeEventEmitter`.
4. Continue runtime QA for focus, IME, Escape, Command-Return, streaming, Clear, Copy, and native theme propagation.
5. Keep Settings, Jump anchors, panel behavior, provider networking, clipboard, Keychain, file grants, and permissions native.

## Handoff Prompt

Use this prompt when starting a general development conversation:

```text
We are continuing development of Inputo in /Users/wnbot/Projects/Inputo.

Inputo is a macOS-native, Spotlight-like AI input source. It opens from a custom hotkey or menu-bar item, lets the user transform text with an OpenAI-compatible provider, copies only when the user clicks Copy, and then lets the user jump back to target apps through app anchors. v1 does not auto-paste, does not save input/generated history, does not execute MCP/tools, does not use screenshots/window titles, and should stay privacy-conservative.

Current state:
- The Xcode app target is thin and hosts lifecycle/menu/window code.
- Product code lives in `apps/macos/InputoModules`.
- `AppState` already uses small service protocols with live and fake services.
- Provider validation, request-shape tests, error redaction, cancellation, neutral connection testing, and macOS network entitlement are in place.
- Composer is a native shell with native header and Jump anchors plus a bundled `WKWebView` body for preview, preset/instruction, input, and actions.
- Settings window sizing has been stabilized.
- Phase 4 has React, TypeScript, and Vite frontend source tooling under `packages/web-composer` while keeping bundled local assets as the app runtime. Windows and the Web agent planner are not implemented yet.

Architecture rules:
- Use the current monorepo structure.
- The Xcode `Inputo` target must stay thin and only own lifecycle/menu/window hosting.
- Product code lives in `apps/macos/InputoModules`.
- `InputoCore` must stay Foundation-only and cross-platform-friendly.
- `InputoMacPlatform` owns macOS services.
- `InputoComposerFeature` owns the Web composer host/assets, native settings UI, and feature orchestration for now.
- No CocoaPods, Carthage, XcodeGen, or project generators.
- Follow current Apple SwiftUI/AppKit conventions.

Please read README.md, docs/ARCHITECTURE.md, docs/DEVELOPMENT.md, docs/HANDOVER.md, docs/WEB_COMPOSER.md, and docs/HANDOVER_WEB_UI_DISCUSSION.md first. Then inspect relevant code before making changes.

For implementation changes, verify with:
`swift test --package-path apps/macos/InputoModules`
`xcodebuild -project apps/macos/Inputo.xcodeproj -scheme Inputo -configuration Debug -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build`
```
