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

## Hybrid Web UI Exploration

The current v1 direction remains native until the first end-to-end text transform loop is reliable. A future hybrid UI can be explored after that without changing the platform and privacy boundaries.

If web UI is introduced, the intended shape is a native shell with web-rendered product surfaces, not a full rewrite:

- Native app shell still owns app lifecycle, menu bar, global hotkey, floating/settings window hosting, app anchors, clipboard writes, Keychain, sandbox entitlements, and OS permissions.
- `InputoCore` remains Foundation-only and continues to own provider validation, request/response models, prompt assembly, and cross-platform DTOs.
- `InputoMacPlatform` remains the only macOS service adapter layer.
- Web UI, likely hosted in `WKWebView`, may render composer/settings screens and communicate with Swift through a narrow message bridge.
- The bridge should expose explicit feature commands such as generate, copy, reset, refresh anchors, activate anchor, load settings, and save settings. It should not expose arbitrary tool execution or unrestricted native APIs.
- v1 privacy constraints still apply: no automatic paste, no input/generated history, no screenshots, no window title capture, and no MCP/tool execution.

Open questions for the hybrid design discussion:

- Whether web UI should cover only the composer first, or composer and settings together.
- Whether the web bundle should be built from a local frontend workspace or checked in as static assets.
- How to type the Swift-to-web bridge so it stays testable and compatible with future Windows UI work.
- How to handle keyboard focus, IME behavior, accessibility, and latency inside a Spotlight-like floating panel.
- Whether provider streaming changes the bridge contract.

## Development Standards

Inputo uses Swift Package Manager as the module and dependency-management baseline. Do not introduce CocoaPods, Carthage, XcodeGen, or other project generators unless the project owner explicitly changes this policy.

The Xcode project owns only the thin macOS app target. Product code lives in the local Swift package at `InputoModules`, which Xcode consumes through local package products. Keep package tests and the Xcode app build working for every change.

Future macOS code should follow current Apple platform conventions: SwiftUI for declarative app UI, AppKit only for macOS system integration that SwiftUI does not cover, structured concurrency for asynchronous work, actor isolation for UI state, and platform credential stores for secrets.

## Project Layout

- `Inputo.xcodeproj`: thin macOS app target, app bundle settings, signing, Info.plist generation, and local package product links.
- `Inputo/App`: app lifecycle and shell code only: `InputoApp`, `AppDelegate`, floating/settings window controllers, and menu bar controller.
- `InputoModules`: local Swift package for core, platform, and feature modules.
- `Contracts`: language-neutral schemas for concepts that future Windows and native-core implementations must preserve.

## Repository Direction

Inputo should remain a monorepo as the product grows to include the SwiftUI macOS app, the shared Web composer/agent surface, and the future WinUI app. These parts are one product with shared contracts and privacy boundaries, not three unrelated applications.

The preferred near-term layout is evolutionary:

- keep the current macOS app and `InputoModules` paths stable while Phase 4 lands
- add a dedicated `WebComposer` workspace for the React, TypeScript, and Vite source
- add a future `Windows` directory when WinUI work begins
- keep `Contracts` as the shared language-neutral boundary across Swift, TypeScript, and future C#
- keep docs and verification guidance in the same repository so platform behavior stays aligned

If the repository is reorganized later, a more standard shape is acceptable:

- `apps/macos` for the SwiftUI/AppKit shell
- `apps/windows` for the WinUI/WebView2 shell
- `packages/web-composer` for the shared React surface
- `packages/bridge-contracts-ts` for TypeScript bridge types if it becomes useful
- `contracts` for language-neutral schemas, examples, and compatibility fixtures
- `tools` for build, sync, and verification scripts

Do not treat this as permission to tightly couple the builds. The macOS Xcode build and Swift package tests must keep working from checked-in sources without `npm install`, network access, or a frontend dev server. The Web workspace can regenerate bundled assets through an explicit developer or CI command, but Xcode should not require Node as part of its normal build.

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
