# Inputo

Inputo is a native macOS MVP for a system-wide AI input source. It behaves like a Spotlight-style floating composer: open it with a user-defined shortcut or menu bar item, transform text with an OpenAI-compatible provider, copy the preview manually, then jump back to another app through app anchors.

## Run

Open `apps/macos/Inputo.xcodeproj` in Xcode and run the `Inputo` scheme, or build from the command line:

```bash
xcodebuild -project apps/macos/Inputo.xcodeproj -scheme Inputo -configuration Debug -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build
```

On first launch, open **Inputo > Settings** from the menu bar item, add an OpenAI-compatible base URL, model, API key, and record a shortcut.

## MVP Scope

- Native macOS SwiftUI/AppKit implementation
- Menu bar resident app
- Spotlight-like floating composer
- App-level jump anchors
- Manual clipboard copy
- OpenAI-compatible `/v1/chat/completions` provider
- Built-in and custom transform presets
- No automatic paste
- No input or generation history
- No MCP/tool execution in v1

## Shared Contracts

Cross-platform contracts live in `contracts/inputo.v1.schema.json`. The future Windows app should implement the same provider, recipe, and app-anchor concepts with WinUI 3 and Win32 interop.

## Documentation

- `docs/ARCHITECTURE.md`: architecture, module boundaries, and future shared-core path.
- `docs/DEVELOPMENT.md`: current roadmap, todo list, verification commands, and manual QA checklist.
- `docs/HANDOVER.md`: concise project state for future conversations or contributors.
- `docs/HANDOVER_WEB_UI_DISCUSSION.md`: handover prompt for Phase 4 Web composer engineering and later Web UI discussions.
- `docs/NATIVE_EXECUTOR_CONTRACT.md`: Phase 0/1 native executor contract status, DTOs, tool registry, and bridge boundary.
- `docs/WEB_COMPOSER.md`: current WKWebView composer body implementation, React/Vite source workspace, security boundary, and packaging model.
- `docs/WEB_UI_ARCHITECTURE.md`: planned web-agent/native-executor architecture, bridge boundary, streaming model, and tool ecosystem direction.

## Project Layout

- `apps/macos/Inputo.xcodeproj`: thin macOS app target.
- `apps/macos/Inputo/App`: app lifecycle, window hosting, and menu bar shell.
- `apps/macos/InputoModules`: local Swift package for macOS product modules.
- `packages/web-composer`: React, TypeScript, and Vite source workspace that regenerates the bundled Web composer assets.
- `packages/bridge-contracts-ts`: reserved package for generated or hand-maintained TypeScript bridge contract helpers.
- `apps/windows`: reserved location for the future WinUI/WebView2 shell.
- `contracts`: language-neutral schemas and fixtures.
- `docs`: architecture, development, and handover notes.
- `tools`: reserved location for repository automation scripts.

## SwiftPM Package Targets

- `InputoCore`: Foundation-only core contracts and OpenAI-compatible provider logic.
- `InputoMacPlatform`: macOS services such as app anchors, shortcuts, clipboard, Keychain, and settings storage.
- `InputoComposerFeature`: composer UI, settings UI, and feature orchestration.

## Development Policy

Inputo uses Swift Package Manager as the module and dependency baseline. The Xcode project owns only the thin macOS app target and consumes local package products from `apps/macos/InputoModules`. Do not add CocoaPods, Carthage, XcodeGen, or other project generators unless this policy is explicitly changed.

Every macOS change should keep these commands working:

```bash
swift test --package-path apps/macos/InputoModules
xcodebuild -project apps/macos/Inputo.xcodeproj -scheme Inputo -configuration Debug -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build
```
