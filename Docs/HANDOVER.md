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
- API keys use Keychain on macOS.
- Cross-platform contracts live in `Contracts/inputo.v1.schema.json`.

## Project Layout

- `Inputo.xcodeproj`: app target, signing/build settings, local package product links.
- `Inputo/App`: app lifecycle, menu bar, floating panel, settings window hosting.
- `InputoModules/Package.swift`: local SwiftPM package.
- `InputoModules/Sources/InputoCore`: core DTOs, recipes, provider client.
- `InputoModules/Sources/InputoMacPlatform`: Keychain, clipboard, hotkey, settings, app anchors.
- `InputoModules/Sources/InputoComposerFeature`: composer UI, settings UI, feature state.
- `Contracts`: language-neutral shared schema.
- `Docs/ARCHITECTURE.md`: architecture and boundaries.
- `Docs/DEVELOPMENT.md`: roadmap, todo list, verification, manual QA.
- `Docs/HANDOVER.md`: current project state and new-conversation prompt.

## Recent Fixes

- Renamed the local package from `AppPackages` to `InputoModules`.
- Wired the Xcode app target to package products:
  - `InputoCore`
  - `InputoMacPlatform`
  - `InputoComposerFeature`
- Added a repository-level `.gitignore` for generated build and Xcode user files.
- Removed tracked Xcode `xcuserdata` because it only contained local scheme ordering.
- Fixed status-bar menu opening reliability by deferring menu item actions until after menu tracking and making the floating panel order to front more explicitly.

## Known State

- `swift test --package-path InputoModules` passes.
- `xcodebuild -project Inputo.xcodeproj -scheme Inputo -configuration Debug -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build` passes.
- The app has a working scaffold for provider config, built-in recipes, custom presets storage, Keychain API key storage, clipboard copy, app anchors, global hotkey registration, and settings.
- `AppState` currently constructs its own concrete services. The next useful refactor is dependency injection through small protocols so feature flows can be unit-tested.
- The composer currently uses English UI strings. Localization has not started.
- There is no committed Windows project yet.

## Important Constraints

- Keep the app target thin. Avoid adding product logic under `Inputo/App`.
- Keep `InputoCore` free of AppKit, SwiftUI, Security, Carbon, and CoreGraphics.
- Do not log API keys or serialize them into settings/contracts.
- Do not add automatic paste unless the product direction explicitly changes.
- Do not request screen recording permission for v1 app anchors.
- Do not read or display window titles for v1 app anchors.
- Treat generated `.build`, `.swiftpm`, DerivedData, and `xcuserdata` as untracked local state.

## Suggested Next Slice

Start with testability and shell reliability:

1. Introduce service protocols for `AppState`.
2. Inject live services from the app composition root.
3. Add fake services for unit tests.
4. Add tests for missing input, missing API key, successful generation, copy-only-on-click, reset, and activation failure.
5. Add Escape-to-hide behavior and manually verify status-bar/hotkey opening across frontmost apps.

This slice improves confidence before adding larger UX or provider features.

## Handoff Prompt

Use this prompt when starting a new conversation:

```text
We are continuing development of Inputo in /Users/wnbot/Projects/Inputo.

Inputo is a macOS-native, Spotlight-like AI input source. It opens from a custom hotkey or menu-bar item, lets the user transform text with an OpenAI-compatible provider, copies only when the user clicks Copy, and then lets the user jump back to target apps through app anchors. v1 does not auto-paste, does not save input/generated history, does not execute MCP/tools, does not use screenshots/window titles, and should stay privacy-conservative.

Architecture rules:
- Use the existing Xcode app + local SwiftPM package structure.
- The Xcode `Inputo` target must stay thin and only own lifecycle/menu/window hosting.
- Product code lives in `InputoModules`.
- `InputoCore` must stay Foundation-only and cross-platform-friendly.
- `InputoMacPlatform` owns macOS services.
- `InputoComposerFeature` owns composer/settings UI and feature orchestration.
- No CocoaPods, Carthage, XcodeGen, or project generators.
- Follow current Apple SwiftUI/AppKit conventions.

Please read README.md, Docs/ARCHITECTURE.md, Docs/DEVELOPMENT.md, and Docs/HANDOVER.md first. Then inspect the relevant code before making changes.

Recommended next task: refactor `AppState` for dependency injection through small service protocols, add fake services, and add unit tests for generate/copy/reset/anchor flows. Keep behavior unchanged unless a bug is found. Verify with:
`swift test --package-path InputoModules`
`xcodebuild -project Inputo.xcodeproj -scheme Inputo -configuration Debug -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build`
```
