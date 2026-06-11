# Inputo Architecture

Inputo is a system-level AI input source that sits between the user's preferred input method and the target application. The app does not replace the input method and does not write directly into target controls in v1.

## MVP Behavior

1. The user opens Inputo from a custom global shortcut or the menu bar.
2. Inputo appears as a Spotlight-like floating composer near the bottom center of the screen.
3. The user enters text, optionally chooses a recipe, and generates an AI-transformed preview.
4. Inputo writes to the clipboard only when the user clicks Copy.
5. The user clicks an app anchor to switch to the target app.
6. Inputo hides itself and clears the transient composer session.

## Native Contract Strategy

The macOS and future Windows apps share contracts, not runtime code. The shared contract covers provider configuration, transform recipes, and app anchors. Platform-specific UI, key storage, app activation, and clipboard behavior stay native.

- macOS: SwiftUI for UI, AppKit for menu bar, floating panel, clipboard, app activation, and visible-app discovery.
- Windows later: WinUI 3 for UI, Win32 interop for window enumeration and activation, Credential Manager for API keys.

## Development Standards

Inputo uses Swift Package Manager as the module and dependency-management baseline. Do not introduce CocoaPods, Carthage, XcodeGen, or other project generators unless the project owner explicitly changes this policy.

The Xcode project owns only the thin macOS app target. Product code lives in the local Swift package at `InputoModules`, which Xcode consumes through local package products. Keep package tests and the Xcode app build working for every change.

Future macOS code should follow current Apple platform conventions: SwiftUI for declarative app UI, AppKit only for macOS system integration that SwiftUI does not cover, structured concurrency for asynchronous work, actor isolation for UI state, and platform credential stores for secrets.

## Project Layout

- `Inputo.xcodeproj`: thin macOS app target, app bundle settings, signing, Info.plist generation, and local package product links.
- `Inputo/App`: app lifecycle and shell code only: `InputoApp`, `AppDelegate`, floating/settings window controllers, and menu bar controller.
- `InputoModules`: local Swift package for core, platform, and feature modules.
- `Contracts`: language-neutral schemas for concepts that future Windows and native-core implementations must preserve.

## SwiftPM Package Targets

- `InputoCore`: Foundation-only core contracts and provider logic. It owns provider configuration, transform recipes, OpenAI-compatible request/response handling, and prompt assembly.
- `InputoMacPlatform`: macOS platform adapter. It owns app anchors, global shortcuts, clipboard writes, Keychain access, settings persistence, and app activation. It may import AppKit, Carbon, CoreGraphics, Security, and `InputoCore`.
- `InputoComposerFeature`: first feature target. It owns composer UI, settings UI, feature state, and orchestration between core and macOS platform services.

Future feature work should prefer new package targets, for example `InputoSettingsFeature`, `InputoProviderFeature`, or `InputoToolsFeature`, instead of adding more code to the Xcode app target.

## Responsibility Boundaries

- The Xcode app target should not own product behavior. It should launch the app, host windows, connect menu/status items, and call package APIs.
- UI should not directly own provider calls, keychain access, clipboard writes, or app activation policy.
- Platform services should hide OS APIs behind small Swift types that can later be mirrored on Windows.
- Core types should stay Codable, Sendable where possible, and free of AppKit/SwiftUI dependencies.
- `AppState` in `InputoComposerFeature` is the current feature composition root: it binds UI intent to core logic and platform services.

## Future Shared Core Path

The current implementation intentionally keeps core concepts in `InputoCore`, platform APIs in `InputoMacPlatform`, and UI/product flow in feature targets so core behavior can later move into a C++ or Rust library.

Candidate shared-core responsibilities:

- transform recipe evaluation and prompt assembly
- OpenAI-compatible provider request/response models
- provider config validation
- non-secret settings serialization
- tool and connector registry contracts

Responsibilities that should stay platform-native:

- SwiftUI and WinUI presentation
- Keychain and Windows Credential Manager access
- clipboard operations
- global hotkeys
- app/window enumeration and activation
- OS permission prompts and privacy-state reporting

If a native core is introduced later, expose it through a small C ABI or generated bindings and keep `InputoMacPlatform` and the future Windows platform layer as adapters. Swift and C# should call the core through explicit DTOs that match `Contracts/inputo.v1.schema.json`.

## Privacy Defaults

Inputo v1 does not save input history, generated text history, screenshots, window titles, or target-control contents. API keys are stored in the platform credential store.

The macOS MVP uses application-level anchors and avoids screen recording. It approximates "apps with windows" from on-screen window ownership without displaying window titles or thumbnails.
